# DLQ (Dead Letter Queue) 路由机制设计文档

## 1. 概述

DLQ（死信队列）路由机制是Outbox Pattern的重要补充，用于处理发送失败且超过最大重试次数的消息。

### 1.1 设计目标

- **失败隔离** - 将永久失败的消息从正常流程中隔离
- **问题诊断** - 保留完整的失败信息，便于问题定位
- **手动恢复** - 支持人工审查和重新入队机制
- **自动归档** - 定期归档和清理历史数据
- **租户隔离** - 确保DLQ消息的租户隔离

### 1.2 架构组件

```
┌──────────────────────────────────────────────────────────────┐
│                    Outbox Pattern + DLQ                      │
└──────────────────────────────────────────────────────────────┘

业务逻辑 (Logic层)
    │
    │ 1. 创建Outbox消息
    ▼
┌──────────────────────┐
│  OutboxPublisher     │
│  - SaveToOutbox()    │
└──────────────────────┘
    │
    │ 2. 保存到数据库（事务保证）
    ▼
┌──────────────────────┐
│  io_outbox_messages  │ (pending状态)
└──────────────────────┘
    │
    │ 3. OutboxRelay定时扫描
    ▼
┌──────────────────────┐
│   OutboxRelay        │
│   - processOnce()    │
│   - sendMessage()    │
│   - handleFailure()  │
└──────────────────────┘
    │
    ├─ 成功 ──────────────────────────┐
    │                                  ▼
    │                          (更新为sent状态)
    │
    └─ 失败 → 重试次数 < max_retries
            │
            ├─ 是 ──→ 指数退避重试
            │
            └─ 否 ──→ 4. 路由到DLQ
                      ▼
                 ┌──────────────────────┐
                 │    DlqRouter         │
                 │  - RouteToDLQ()      │
                 │  - RequeueToOutbox() │
                 └──────────────────────┘
                      │
                      │ 5. 保存到DLQ表
                      ▼
                 ┌──────────────────────┐
                 │  io_dlq_messages     │ (pending状态)
                 └──────────────────────┘
                      │
                      ├─ 6a. 手动重新入队 ──→ 回到Outbox
                      │
                      ├─ 6b. 标记为resolved
                      │
                      ├─ 6c. 归档(archived)
                      │
                      └─ 6d. 定期清理
```

## 2. 数据模型

### 2.1 DlqMessage Schema

**表名**: `io_dlq_messages`

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `id` | uint64 | 主键ID |
| `tenant_id` | uint64 | 租户ID（租户隔离） |
| `original_message_id` | uint64 | 原始Outbox消息ID |
| `aggregate_type` | string | 聚合类型（如：InputTask） |
| `aggregate_id` | string | 聚合ID |
| `topic` | string | DLQ Topic（格式：`dlq.{original_topic}`） |
| `message_key` | string | Kafka消息Key |
| `message_value` | bytes | Kafka消息内容（JSON） |
| `message_headers` | json | Kafka消息Headers |
| `event_type` | string | 事件类型 |
| `retry_count` | int | 失败前的重试次数 |
| `failure_reason` | string | 失败原因 |
| `failed_at` | timestamp | 失败时间 |
| `metadata` | json | 元数据 |
| `status` | enum | 处理状态（pending, processing, resolved, archived） |
| `requeued_at` | timestamp | 重新入队时间 |
| `requeued_message_id` | uint64 | 重新入队后的新Outbox消息ID |
| `archived_at` | timestamp | 归档时间 |
| `resolution_notes` | string | 处理说明 |
| `created_at` | timestamp | 创建时间 |
| `updated_at` | timestamp | 更新时间 |

### 2.2 Status状态枚举

- **pending** - 待处理（新路由的消息）
- **processing** - 处理中（正在被人工审查）
- **resolved** - 已解决（已重新入队或手动处理）
- **archived** - 已归档（长期存储，可定期清理）

### 2.3 索引设计

```go
Indexes:
  - tenant_id (租户隔离)
  - status (状态查询)
  - aggregate_type, aggregate_id (业务实体查询)
  - topic (Topic统计)
  - failed_at (时间范围查询)
  - tenant_id, status (复合索引，最常用)
```

## 3. 核心组件

### 3.1 DlqRouter

#### 职责
- 将失败的Outbox消息路由到DLQ
- 支持消息重新入队
- 管理DLQ消息生命周期

#### 配置

```go
type DlqConfig struct {
    Enabled         bool   // 是否启用DLQ（默认true）
    TopicPrefix     string // DLQ Topic前缀（默认"dlq."）
    PublishToKafka  bool   // 是否发布到Kafka DLQ Topic（默认false）
    AutoArchiveDays int    // 自动归档天数（默认30天）
    AutoCleanupDays int    // 自动清理天数（默认90天）
}
```

#### 核心方法

**1. RouteToDLQ - 路由到DLQ**

```go
func (r *DlqRouter) RouteToDLQ(
    ctx context.Context,
    outboxMsg *ent.OutboxMessage,
    failureReason string,
) error
```

**调用时机**：OutboxRelay的handleSendFailure中，当`retry_count >= max_retries`时

**流程**：
1. 检查DLQ是否启用
2. 复制Outbox消息数据
3. 添加DLQ元数据（路由时间、原始消息ID等）
4. 创建DlqMessage记录（状态=pending）
5. 可选：发布到Kafka DLQ Topic
6. 记录指标和日志

**2. RequeueToOutbox - 重新入队**

```go
func (r *DlqRouter) RequeueToOutbox(
    ctx context.Context,
    dlqMessageID uint64,
) (*ent.OutboxMessage, error)
```

**使用场景**：
- 问题修复后，手动重试失败的消息
- 临时网络故障导致的失败
- 需要重新发送特定消息

**流程**：
1. 查询DLQ消息
2. 验证状态（不能是resolved或archived）
3. 创建新的Outbox消息（reset retry_count=0）
4. 更新DLQ消息状态为resolved
5. 记录重新入队信息

**3. GetPendingMessages - 获取待处理消息**

```go
func (r *DlqRouter) GetPendingMessages(
    ctx context.Context,
    tenantID uint64,
    limit int,
) ([]*ent.DlqMessage, error)
```

**用途**：
- 管理界面展示待处理消息列表
- 批量重新入队
- DLQ监控告警

**4. ArchiveResolvedMessages - 归档已解决消息**

```go
func (r *DlqRouter) ArchiveResolvedMessages(
    ctx context.Context,
    olderThanDays int,
) (int, error)
```

**用途**：
- 定期任务（例如每天凌晨）
- 将resolved状态的消息归档
- 减少活跃表大小，提升查询性能

**5. DeleteArchivedMessages - 删除已归档消息**

```go
func (r *DlqRouter) DeleteArchivedMessages(
    ctx context.Context,
    olderThanDays int,
) (int, error)
```

**用途**：
- 定期清理（例如每周）
- 删除超过保留期的归档消息
- 控制数据库存储成本

### 3.2 OutboxRelay集成

#### 修改点

**handleSendFailure方法** (relay.go:283-343)

```go
// 检查是否超过最大重试次数
if retryCount >= msg.MaxRetries {
    // 🔥 NEW: 路由到DLQ
    failureReason := fmt.Sprintf("Exceeded max retries (%d): %v", msg.MaxRetries, sendErr)
    dlqErr := r.dlqRouter.RouteToDLQ(ctx, msg, failureReason)
    if dlqErr != nil {
        logx.Errorw("Failed to route message to DLQ",
            logx.Field("outbox_id", msg.ID),
            logx.Field("dlq_error", dlqErr),
            logx.Field("original_error", sendErr))
    }

    // 标记为失败
    err := msg.Update().
        SetSendStatus("failed").
        SetRetryCount(retryCount).
        SetLastError(sendErr.Error()).
        SetErrorMessage(failureReason).
        Exec(ctx)

    logx.Errorw("Outbox message marked as failed and routed to DLQ",
        logx.Field("dlq_routed", dlqErr == nil))
    return
}
```

#### 初始化

```go
// 创建OutboxRelay时自动创建DlqRouter
relay := NewOutboxRelay(db, producer, secureProducer, &RelayConfig{
    Interval:  5 * time.Second,
    BatchSize: 100,
    DlqConfig: &DlqConfig{
        Enabled:         true,
        TopicPrefix:     "dlq.",
        PublishToKafka:  false,  // 仅存储到数据库
        AutoArchiveDays: 30,
        AutoCleanupDays: 90,
    },
})
```

## 4. 使用场景

### 4.1 场景1：永久性失败（推荐DLQ）

**问题**：
- 消费者服务宕机超过重试期限
- Topic不存在或配置错误
- 消息格式错误导致序列化失败

**处理流程**：
1. Outbox消息重试3次失败
2. 自动路由到DLQ（status=pending）
3. 管理员在DLQ界面查看
4. 修复问题后，点击"重新入队"
5. 消息回到Outbox，重新发送

### 4.2 场景2：临时性失败（自动重试）

**问题**：
- 网络抖动
- Kafka Broker短暂不可用
- 消费者服务重启

**处理流程**：
1. Outbox消息第1次失败 → 2秒后重试
2. 第2次失败 → 4秒后重试
3. 第3次成功 → 标记为sent

**优势**：无需人工介入，自动恢复

### 4.3 场景3：批量重新入队

**问题**：
- DLQ中积累了100条消息
- 问题已修复，需要批量重试

**处理流程**：
```go
// 查询待处理消息
dlqMessages, _ := dlqRouter.GetPendingMessages(ctx, tenantID, 100)

// 批量重新入队
for _, dlqMsg := range dlqMessages {
    _, err := dlqRouter.RequeueToOutbox(ctx, dlqMsg.ID)
    if err != nil {
        log.Printf("Failed to requeue: %v", err)
    }
}
```

### 4.4 场景4：定期维护

**Cron任务**：

```go
// 每天凌晨2点：归档30天前的resolved消息
func ArchiveJob() {
    count, err := dlqRouter.ArchiveResolvedMessages(ctx, 30)
    log.Printf("Archived %d messages", count)
}

// 每周日凌晨3点：删除90天前的archived消息
func CleanupJob() {
    count, err := dlqRouter.DeleteArchivedMessages(ctx, 90)
    log.Printf("Deleted %d archived messages", count)
}
```

## 5. 租户隔离

### 5.1 DLQ消息租户隔离

**Schema保证**：
- DlqMessage使用`mixins.TenantMixin{}`
- 自动注入tenant_id字段
- 索引包含tenant_id

**查询保证**：
```go
// 所有查询都会自动添加租户过滤
messages, _ := db.DlqMessage.Query().
    Where(dlqmessage.TenantIDEQ(tenantID)).  // 必须指定
    Where(dlqmessage.StatusEQ(dlqmessage.StatusPending)).
    All(ctx)
```

### 5.2 跨租户操作限制

**禁止**：
- ❌ 租户A重新入队租户B的DLQ消息
- ❌ 租户A查看租户B的失败原因

**允许**：
- ✅ 系统管理员查看所有租户DLQ（使用SystemContext）
- ✅ 系统管理员执行全局归档/清理任务

## 6. 指标监控

### 6.1 DlqMetrics

```go
type DlqMetrics struct {
    TotalRouted   int64 // 总路由数
    RouteFailed   int64 // 路由失败数（存储失败）
    TotalResolved int64 // 总解决数（重新入队数）
    TotalArchived int64 // 总归档数
}
```

### 6.2 关键指标

| 指标名称 | 说明 | 告警阈值 |
|---------|------|---------|
| `dlq_messages_pending_count` | 待处理DLQ消息数 | > 100 |
| `dlq_route_rate` | DLQ路由速率（条/分钟） | > 10 |
| `dlq_oldest_message_age_hours` | 最老消息的等待时间（小时） | > 24 |
| `dlq_requeue_success_rate` | 重新入队成功率 | < 95% |

### 6.3 告警策略

**P0 严重告警**：
- DLQ消息数 > 1000（可能存在系统性问题）
- 路由失败率 > 10%（DLQ机制本身故障）

**P1 高优先级**：
- 待处理消息 > 100
- 最老消息 > 24小时未处理

**P2 中优先级**：
- 待处理消息 > 50
- 重新入队失败率 > 5%

## 7. 最佳实践

### 7.1 DLQ配置建议

**生产环境**：
```go
DlqConfig{
    Enabled:         true,         // 必须启用
    TopicPrefix:     "dlq.",       // 标准前缀
    PublishToKafka:  false,        // 仅存储到数据库（推荐）
    AutoArchiveDays: 30,           // 30天归档
    AutoCleanupDays: 90,           // 90天清理
}
```

**开发环境**：
```go
DlqConfig{
    Enabled:         true,
    TopicPrefix:     "dev.dlq.",
    PublishToKafka:  false,
    AutoArchiveDays: 7,            // 7天快速归档
    AutoCleanupDays: 14,           // 14天清理
}
```

### 7.2 运维建议

1. **定期检查** - 每天查看DLQ pending消息数
2. **根因分析** - 记录每次DLQ路由的根本原因
3. **趋势分析** - 按aggregate_type统计失败分布
4. **容量规划** - 预估DLQ表增长，规划存储容量

### 7.3 重新入队策略

**自动重新入队**（不推荐）：
- 风险：可能重复发送错误数据
- 适用：100%确定是临时故障

**手动重新入队**（推荐）：
- 优势：人工审查，确保数据正确性
- 流程：问题定位 → 修复 → 验证 → 重新入队

## 8. 测试策略

### 8.1 单元测试

**DlqRouter测试**：
- `TestRouteToDLQ` - 测试DLQ路由
- `TestRequeueToOutbox` - 测试重新入队
- `TestGetPendingMessages` - 测试查询
- `TestArchiveResolvedMessages` - 测试归档
- `TestDeleteArchivedMessages` - 测试清理

**OutboxRelay集成测试**：
- `TestHandleSendFailure_RouteToDLQ` - 测试失败路由

### 8.2 集成测试

**端到端测试**：
1. 创建Outbox消息
2. 模拟发送失败3次
3. 验证消息路由到DLQ
4. 验证DLQ消息字段正确
5. 重新入队
6. 验证新Outbox消息创建
7. 验证DLQ状态更新为resolved

### 8.3 压力测试

**高负载DLQ路由**：
- 并发路由1000条消息
- 验证数据一致性
- 验证无死锁
- 验证性能满足要求（< 100ms/条）

## 9. 安全考虑

### 9.1 敏感数据处理

**问题**：DLQ消息可能包含敏感数据（用户信息、订单详情等）

**解决方案**：
1. **加密存储** - 对message_value字段加密
2. **访问控制** - 限制DLQ查看权限
3. **审计日志** - 记录所有DLQ访问操作
4. **定期清理** - 严格执行清理策略，避免长期保留

### 9.2 权限控制

**角色定义**：
- **系统管理员** - 查看所有租户DLQ，执行全局操作
- **租户管理员** - 查看本租户DLQ，重新入队
- **普通用户** - 无权限访问DLQ

## 10. 未来增强

### 10.1 Phase 2计划

- [ ] **DLQ Consumer** - 自动处理特定类型的DLQ消息
- [ ] **智能重试** - 根据失败原因自动调整重试策略
- [ ] **DLQ Dashboard** - 管理界面，可视化DLQ数据
- [ ] **告警集成** - 集成Prometheus/Grafana告警

### 10.2 Phase 3计划

- [ ] **Kafka DLQ Topic** - 支持发布到Kafka DLQ Topic
- [ ] **消息转换** - 支持重新入队前修改消息内容
- [ ] **批量操作** - UI支持批量归档/删除
- [ ] **导出功能** - 导出DLQ消息到CSV/JSON

## 11. 总结

DLQ路由机制是Outbox Pattern的重要补充：

✅ **可靠性** - 确保失败消息不会丢失
✅ **可观测性** - 完整记录失败原因
✅ **可恢复性** - 支持手动重试机制
✅ **可维护性** - 自动归档和清理
✅ **租户隔离** - 保证多租户安全

**核心价值**：
- 将永久失败和临时失败分离
- 提供人工介入和问题诊断能力
- 降低运维负担，提升系统可靠性

---

**文档版本**: v1.0.0
**创建时间**: 2025-10-22
**作者**: Claude Code
