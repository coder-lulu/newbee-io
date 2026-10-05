# Outbox模式设计文档

**创建日期**: 2025-10-22
**版本**: v1.0
**负责人**: Claude Code

---

## 📋 目录

- [1. 背景与目标](#1-背景与目标)
- [2. Outbox模式原理](#2-outbox模式原理)
- [3. 数据库设计](#3-数据库设计)
- [4. 核心组件](#4-核心组件)
- [5. 工作流程](#5-工作流程)
- [6. 使用示例](#6-使用示例)
- [7. 性能优化](#7-性能优化)
- [8. 监控与运维](#8-监控与运维)

---

## 1. 背景与目标

### 1.1 问题背景

在分布式系统中，业务操作和消息发送通常分属两个不同的系统：
- **数据库事务** - 保证数据一致性
- **Kafka消息** - 异步通知下游服务

这会导致**数据一致性问题**：
```
场景1：提交了数据库事务，但Kafka发送失败 → 数据不一致
场景2：Kafka发送成功，但数据库事务回滚 → 数据不一致
场景3：网络分区导致发送超时 → 不确定状态
```

### 1.2 解决目标

✅ **事务一致性** - 业务操作和消息发送在同一事务
✅ **消息不丢失** - 失败可重试，最终一定发送成功
✅ **幂等性保证** - 避免重复发送
✅ **租户隔离** - 多租户环境下的安全性
✅ **可观测性** - 完整的监控和审计

---

## 2. Outbox模式原理

### 2.1 核心思想

**将消息发送转换为数据库操作**，利用数据库事务的ACID特性保证一致性。

```
传统方案：
┌─────────────┐       ┌─────────────┐
│ 业务操作    │ ─────>│ 数据库事务  │ (可能成功)
└─────────────┘       └─────────────┘
       │
       └─────────────> Kafka发送 (可能失败) ❌ 数据不一致

Outbox方案：
┌─────────────────────────────────────────────┐
│         数据库事务 (原子性保证)              │
│  ┌─────────────┐    ┌──────────────────┐  │
│  │ 业务操作    │ +  │ 保存消息到Outbox │  │
│  └─────────────┘    └──────────────────┘  │
└─────────────────────────────────────────────┘
              │
              ▼
       ┌─────────────────┐
       │ 后台Relay任务   │ ──> Kafka发送 (异步重试) ✅ 最终一致
       └─────────────────┘
```

### 2.2 工作流程

```
1. 业务逻辑执行
   ├── 插入/更新业务数据 (input_tasks)
   └── 插入消息到outbox_messages (同一事务)

2. 数据库事务提交
   └── 业务数据和Outbox消息都持久化 ✅

3. 后台Relay扫描
   ├── 查询 send_status='pending' 的消息
   ├── 发送到Kafka
   │   ├── 成功 → 更新 send_status='sent'
   │   └── 失败 → retry_count++, 计算下次重试时间
   └── 循环执行 (例如每5秒一次)

4. 消息最终发送成功
   └── send_status='sent', sent_at=NOW()
```

---

## 3. 数据库设计

### 3.1 表结构

**表名**: `outbox_messages`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | BIGINT | 主键 |
| `tenant_id` | BIGINT | 租户ID（隔离） |
| `aggregate_type` | VARCHAR(100) | 聚合类型（InputTask, OutputTask） |
| `aggregate_id` | VARCHAR(100) | 聚合ID（业务实体ID） |
| `topic` | VARCHAR(200) | Kafka Topic |
| `message_key` | VARCHAR(500) | 消息Key |
| `message_value` | BLOB | 消息体（JSON） |
| `message_headers` | JSON | 消息Headers |
| `event_type` | VARCHAR(100) | 事件类型（TaskCreated） |
| `send_status` | VARCHAR(20) | pending/sent/failed |
| `retry_count` | INT | 重试次数 |
| `max_retries` | INT | 最大重试次数（默认3） |
| `sent_at` | TIMESTAMP | 发送时间 |
| `next_retry_at` | TIMESTAMP | 下次重试时间 |
| `error_message` | TEXT | 错误信息 |
| `priority` | INT | 优先级（1-10） |
| `metadata` | JSON | 扩展元数据 |
| `created_at` | TIMESTAMP | 创建时间 |
| `updated_at` | TIMESTAMP | 更新时间 |

### 3.2 核心索引

#### 索引1：`idx_tenant_send_status` ⭐⭐⭐⭐⭐
```sql
INDEX (tenant_id, send_status)
```
**用途**: Relay查询待发送消息
**查询**: `WHERE tenant_id=? AND send_status='pending'`
**重要性**: 最高优先级

#### 索引2：`idx_status_retry_at` ⭐⭐⭐⭐
```sql
INDEX (send_status, next_retry_at)
```
**用途**: 查询需要重试的消息
**查询**: `WHERE send_status='pending' AND next_retry_at <= NOW()`

#### 索引3：`idx_tenant_aggregate` ⭐⭐⭐⭐
```sql
INDEX (tenant_id, aggregate_type, aggregate_id)
```
**用途**: 查询某个业务实体的所有消息
**查询**: `WHERE tenant_id=? AND aggregate_type='InputTask' AND aggregate_id='123'`

---

## 4. 核心组件

### 4.1 OutboxPublisher（消息保存）

**职责**: 在业务事务中保存消息到Outbox表

```go
type OutboxPublisher struct {
    db *ent.Client
}

// SaveToOutbox 在事务中保存消息
func (p *OutboxPublisher) SaveToOutbox(ctx context.Context, tx *ent.Tx, msg *OutboxMessage) error {
    _, err := tx.OutboxMessage.Create().
        SetTenantID(msg.TenantID).
        SetAggregateType(msg.AggregateType).
        SetAggregateID(msg.AggregateID).
        SetTopic(msg.Topic).
        SetMessageKey(msg.MessageKey).
        SetMessageValue(msg.MessageValue).
        SetEventType(msg.EventType).
        SetSendStatus("pending").
        Save(ctx)
    return err
}
```

### 4.2 OutboxRelay（消息发送）

**职责**: 定时扫描Outbox表，发送消息到Kafka

```go
type OutboxRelay struct {
    db       *ent.Client
    producer *producer.SecureProducer
    interval time.Duration
}

// Start 启动Relay定时任务
func (r *OutboxRelay) Start(ctx context.Context) {
    ticker := time.NewTicker(r.interval) // 例如5秒
    defer ticker.Stop()

    for {
        select {
        case <-ticker.C:
            r.processPendingMessages(ctx)
        case <-ctx.Done():
            return
        }
    }
}

// processPendingMessages 处理待发送消息
func (r *OutboxRelay) processPendingMessages(ctx context.Context) {
    // 1. 查询待发送消息（批量，例如100条）
    messages, err := r.db.OutboxMessage.Query().
        Where(
            outboxmessage.SendStatusEQ("pending"),
            outboxmessage.Or(
                outboxmessage.NextRetryAtIsNil(),
                outboxmessage.NextRetryAtLTE(time.Now()),
            ),
        ).
        Order(ent.Desc("priority"), ent.Asc("created_at")).
        Limit(100).
        All(ctx)

    // 2. 逐条发送到Kafka
    for _, msg := range messages {
        if err := r.sendMessage(ctx, msg); err != nil {
            r.handleSendFailure(ctx, msg, err)
        } else {
            r.markAsSent(ctx, msg)
        }
    }
}

// sendMessage 发送单条消息
func (r *OutboxRelay) sendMessage(ctx context.Context, msg *ent.OutboxMessage) error {
    return r.producer.Publish(ctx, msg.Topic, msg.MessageKey, msg.MessageValue, msg.MessageHeaders)
}

// markAsSent 标记为已发送
func (r *OutboxRelay) markAsSent(ctx context.Context, msg *ent.OutboxMessage) error {
    return msg.Update().
        SetSendStatus("sent").
        SetSentAt(time.Now()).
        Exec(ctx)
}

// handleSendFailure 处理发送失败
func (r *OutboxRelay) handleSendFailure(ctx context.Context, msg *ent.OutboxMessage, err error) {
    retryCount := msg.RetryCount + 1

    if retryCount >= msg.MaxRetries {
        // 超过最大重试次数，标记为failed
        msg.Update().
            SetSendStatus("failed").
            SetRetryCount(retryCount).
            SetLastError(err.Error()).
            Exec(ctx)
        return
    }

    // 指数退避：下次重试时间 = 当前时间 + 2^retryCount 秒
    backoff := time.Duration(math.Pow(2, float64(retryCount))) * time.Second
    nextRetry := time.Now().Add(backoff)

    msg.Update().
        SetRetryCount(retryCount).
        SetLastError(err.Error()).
        SetNextRetryAt(nextRetry).
        Exec(ctx)
}
```

---

## 5. 工作流程

### 5.1 消息发送流程

```
                    业务层
                      │
                      ▼
        ┌─────────────────────────────┐
        │ 开始数据库事务 (BEGIN)       │
        └─────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
┌─────────────────┐     ┌─────────────────────┐
│ 业务数据操作    │     │ 保存消息到Outbox    │
│ INSERT/UPDATE   │     │ (OutboxPublisher)   │
└─────────────────┘     └─────────────────────┘
        │                           │
        └─────────────┬─────────────┘
                      ▼
        ┌─────────────────────────────┐
        │ 提交事务 (COMMIT)            │
        │ ✅ 业务数据和消息都持久化    │
        └─────────────────────────────┘
                      │
                      ▼
              (后台异步处理)
                      │
        ┌─────────────────────────────┐
        │ OutboxRelay定时扫描         │
        │ (例如每5秒执行一次)          │
        └─────────────────────────────┘
                      │
                      ▼
        ┌─────────────────────────────┐
        │ 查询 send_status='pending'  │
        │ LIMIT 100                   │
        └─────────────────────────────┘
                      │
                      ▼
        ┌─────────────────────────────┐
        │ 发送到Kafka                 │
        └─────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
 ┌────────────┐            ┌──────────────┐
 │ 发送成功   │            │ 发送失败     │
 │ status=sent│            │ retry_count++│
 │ sent_at=NOW│            │ 计划重试时间  │
 └────────────┘            └──────────────┘
```

### 5.2 重试机制

**指数退避策略**：
```
重试次数  |  等待时间  |  累计时间
---------|-----------|----------
0        |  -        |  0
1        |  2秒      |  2秒
2        |  4秒      |  6秒
3        |  8秒      |  14秒
4        |  16秒     |  30秒
5        |  标记失败  |  -
```

**失败处理**：
- 重试次数 < 最大重试次数 → 计算下次重试时间，继续重试
- 重试次数 >= 最大重试次数 → 标记为`failed`，发送告警

---

## 6. 使用示例

### 6.1 基础用法

```go
// 业务逻辑：创建任务并发送消息
func (l *CreateInputTaskLogic) CreateInputTask(in *io.InputTaskInfo) (*io.BaseIDResp, error) {
    // 使用事务
    err := entx.WithTx(l.ctx, l.svcCtx.DB, func(tx *ent.Tx) error {
        // 1. 创建任务
        task, err := tx.InputTask.Create().
            SetTaskName(in.TaskName).
            SetTaskType(in.TaskType).
            Save(l.ctx)
        if err != nil {
            return err
        }

        // 2. 准备消息
        messageValue, _ := json.Marshal(map[string]interface{}{
            "task_id":   task.ID,
            "task_name": task.TaskName,
            "tenant_id": l.tenantID,
        })

        // 3. 保存到Outbox（同一事务）
        _, err = tx.OutboxMessage.Create().
            SetTenantID(l.tenantID).
            SetAggregateType("InputTask").
            SetAggregateID(fmt.Sprintf("%d", task.ID)).
            SetTopic("io.input.jobs").
            SetMessageKey(fmt.Sprintf("%d:%d", l.tenantID, task.ID)).
            SetMessageValue(messageValue).
            SetMessageHeaders(map[string]string{
                "X-Tenant-ID": fmt.Sprintf("%d", l.tenantID),
                "X-Event-Type": "TaskCreated",
            }).
            SetEventType("TaskCreated").
            SetSendStatus("pending").
            Save(l.ctx)

        return err
    })

    return &io.BaseIDResp{Id: task.ID}, err
}
```

### 6.2 使用OutboxPublisher（推荐）

```go
// 创建Publisher
publisher := outbox.NewOutboxPublisher(l.svcCtx.DB)

// 在事务中使用
err := entx.WithTx(l.ctx, l.svcCtx.DB, func(tx *ent.Tx) error {
    // 业务操作
    task, err := tx.InputTask.Create().SetTaskName("test").Save(l.ctx)
    if err != nil {
        return err
    }

    // 保存消息（封装好的方法）
    return publisher.SaveTaskCreatedMessage(l.ctx, tx, task)
})
```

---

## 7. 性能优化

### 7.1 批量发送

```go
// 批量查询待发送消息
messages, _ := r.db.OutboxMessage.Query().
    Where(outboxmessage.SendStatusEQ("pending")).
    Limit(100). // 批量处理100条
    All(ctx)

// 批量发送（使用Kafka批量API）
batch := r.producer.NewBatch()
for _, msg := range messages {
    batch.Add(msg.Topic, msg.MessageKey, msg.MessageValue)
}
batch.Send()
```

### 7.2 优先级队列

```go
// 按优先级排序
messages, _ := r.db.OutboxMessage.Query().
    Where(outboxmessage.SendStatusEQ("pending")).
    Order(ent.Desc("priority"), ent.Asc("created_at")). // 高优先级优先
    Limit(100).
    All(ctx)
```

### 7.3 定期清理

```go
// 清理已发送的旧消息（保留7天）
func (r *OutboxRelay) CleanupSentMessages(ctx context.Context) {
    cutoffTime := time.Now().Add(-7 * 24 * time.Hour)

    _, err := r.db.OutboxMessage.Delete().
        Where(
            outboxmessage.SendStatusEQ("sent"),
            outboxmessage.CreatedAtLT(cutoffTime),
        ).
        Exec(ctx)
}
```

---

## 8. 监控与运维

### 8.1 关键指标

| 指标 | 说明 | 告警阈值 |
|------|------|----------|
| **pending_count** | 待发送消息数量 | > 1000 |
| **failed_count** | 失败消息数量 | > 10 |
| **avg_send_latency** | 平均发送延迟 | > 60s |
| **relay_run_interval** | Relay执行间隔 | > 10s |
| **oldest_pending_age** | 最老待发送消息年龄 | > 5min |

### 8.2 监控查询

```sql
-- 待发送消息数量（按租户）
SELECT tenant_id, COUNT(*) as pending_count
FROM outbox_messages
WHERE send_status = 'pending'
GROUP BY tenant_id;

-- 失败消息列表
SELECT id, tenant_id, aggregate_type, aggregate_id, retry_count, last_error
FROM outbox_messages
WHERE send_status = 'failed'
ORDER BY created_at DESC
LIMIT 100;

-- 平均发送延迟
SELECT AVG(TIMESTAMPDIFF(SECOND, created_at, sent_at)) as avg_latency_seconds
FROM outbox_messages
WHERE send_status = 'sent'
AND sent_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR);

-- 最老待发送消息
SELECT MIN(created_at) as oldest_pending
FROM outbox_messages
WHERE send_status = 'pending';
```

### 8.3 告警规则

```yaml
# Prometheus告警规则
groups:
  - name: outbox_alerts
    rules:
      - alert: OutboxPendingMessagesHigh
        expr: outbox_pending_count > 1000
        for: 5m
        annotations:
          summary: "Outbox待发送消息过多"

      - alert: OutboxFailedMessagesHigh
        expr: outbox_failed_count > 10
        for: 1m
        annotations:
          summary: "Outbox失败消息过多"

      - alert: OutboxSendLatencyHigh
        expr: outbox_avg_send_latency_seconds > 60
        for: 5m
        annotations:
          summary: "Outbox发送延迟过高"
```

---

## 9. 最佳实践

### 9.1 DO's ✅

1. **总是在事务中保存Outbox消息**
   ```go
   entx.WithTx(ctx, db, func(tx *ent.Tx) error {
       // 业务操作 + Outbox保存
   })
   ```

2. **设置合理的优先级**
   - 实时任务：priority=8-10
   - 普通任务：priority=4-6
   - 低优先级任务：priority=1-3

3. **记录完整的元数据**
   ```go
   SetMetadata(map[string]interface{}{
       "correlation_id": uuid.New().String(),
       "user_id": userID,
       "request_id": requestID,
   })
   ```

4. **定期清理已发送消息**
   - 生产环境：保留7天
   - 测试环境：保留1天

### 9.2 DON'Ts ❌

1. **不要直接修改send_status为'sent'**
   - 应该通过Relay自动更新

2. **不要在Outbox表上执行复杂查询**
   - 影响Relay性能

3. **不要无限重试**
   - 设置max_retries上限

4. **不要在高频操作中使用Outbox**
   - 适用于业务操作，不适用于日志记录

---

## 10. 故障排查

### 10.1 消息未发送

**症状**: 消息一直处于pending状态

**排查步骤**:
1. 检查OutboxRelay是否运行
   ```bash
   ps aux | grep relay
   ```

2. 检查消息状态
   ```sql
   SELECT * FROM outbox_messages WHERE id=? AND send_status='pending';
   ```

3. 检查next_retry_at
   ```sql
   SELECT id, next_retry_at, NOW() FROM outbox_messages WHERE id=?;
   ```

4. 检查Kafka连接
   ```bash
   telnet kafka-broker 9092
   ```

### 10.2 消息重复发送

**症状**: 下游收到重复消息

**原因**:
- Relay发送成功但未更新状态（网络超时）
- 数据库更新失败但消息已发送

**解决**:
- 下游实现幂等性检查（推荐）
- 增加事务超时时间
- 监控重复发送指标

---

**文档版本**: v1.0
**创建日期**: 2025-10-22
**最后更新**: 2025-10-22
**审核状态**: ✅ 已审核
