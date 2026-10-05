# Kafka Consumer 使用文档

## 目录

- [快速开始](#快速开始)
- [基础消费者](#基础消费者)
- [安全消费者](#安全消费者)
- [幂等性机制](#幂等性机制)
- [配置参数](#配置参数)
- [最佳实践](#最佳实践)
- [集成测试](#集成测试)
- [常见问题](#常见问题)

---

## 快速开始

### 1. 创建简单消费者

```go
package main

import (
    "context"
    "fmt"
    "time"

    "github.com/coder-lulu/newbee-io-rpc/internal/queue/consumer"
    "github.com/segmentio/kafka-go"
)

// SimpleHandler 简单的消息处理器
type SimpleHandler struct{}

func (h *SimpleHandler) Handle(ctx context.Context, msg *kafka.Message) error {
    fmt.Printf("Received: topic=%s, partition=%d, offset=%d, value=%s\n",
        msg.Topic, msg.Partition, msg.Offset, string(msg.Value))
    return nil
}

func main() {
    // 1. 创建消费者配置
    config := consumer.DefaultConfig(
        []string{"192.168.26.130:9092"},
        "io.input.jobs",
        "unified-io-worker",
    )

    // 2. 创建消费者
    c, err := consumer.NewConsumer(config, &SimpleHandler{})
    if err != nil {
        panic(err)
    }
    defer c.Close()

    // 3. 启动消费者（阻塞）
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := c.Start(ctx); err != nil {
        if err != context.DeadlineExceeded {
            panic(err)
        }
    }

    fmt.Println("Consumer stopped")
}
```

---

## 基础消费者

### 核心接口

#### MessageHandler 接口

所有消息处理器必须实现此接口：

```go
type MessageHandler interface {
    Handle(ctx context.Context, msg *kafka.Message) error
}
```

#### Consumer 接口

```go
type Consumer interface {
    Start(ctx context.Context) error  // 启动消费者（阻塞）
    Close() error                     // 关闭消费者
}
```

### 配置结构

```go
type Config struct {
    Brokers        []string      // Kafka broker地址列表
    Topic          string        // Topic名称
    GroupID        string        // Consumer Group ID
    Partition      int           // 分区号（-1表示自动分配）
    MinBytes       int           // 每次拉取最小字节数
    MaxBytes       int           // 每次拉取最大字节数
    MaxWait        time.Duration // 最大等待时间
    CommitInterval time.Duration // 自动提交间隔
    StartOffset    int64         // 起始偏移量
}
```

### 默认配置

```go
config := consumer.DefaultConfig(
    []string{"192.168.26.130:9092"},
    "io.input.jobs",
    "unified-io-worker",
)

// 默认值：
// - Partition: -1 (自动分配)
// - MinBytes: 1
// - MaxBytes: 10MB
// - MaxWait: 500ms
// - CommitInterval: 1s
// - StartOffset: kafka.LastOffset
```

### 自定义Handler示例

```go
type MyTaskHandler struct {
    db    *ent.Client
    cache redis.UniversalClient
}

func (h *MyTaskHandler) Handle(ctx context.Context, msg *kafka.Message) error {
    // 1. 解析消息
    var task Task
    if err := json.Unmarshal(msg.Value, &task); err != nil {
        return fmt.Errorf("unmarshal failed: %w", err)
    }

    // 2. 参数验证
    if task.ID == 0 {
        return fmt.Errorf("invalid task ID")
    }

    // 3. 执行业务逻辑
    if err := h.processTask(ctx, &task); err != nil {
        return err
    }

    // 4. 更新缓存
    h.updateCache(ctx, &task)

    return nil
}
```

---

## 安全消费者

### 功能概述

`SecureConsumer` 提供以下安全特性：

1. **租户隔离** - Header + Body 双重验证
2. **幂等性保证** - Redis + DB 两层去重
3. **安全审计** - 详细的安全违规日志
4. **错误处理** - 区分业务错误和安全错误

### 创建安全消费者

```go
import (
    "github.com/coder-lulu/newbee-io-rpc/internal/idempotency"
    "github.com/coder-lulu/newbee-io-rpc/internal/queue/consumer"
    "github.com/coder-lulu/newbee-io-rpc/internal/queue/types"
    "github.com/redis/go-redis/v9"
)

func createSecureConsumer() error {
    // 1. 创建Redis客户端
    rds := redis.NewClient(&redis.Options{
        Addr: "localhost:6379",
    })

    // 2. 创建幂等性守护者
    idempotencyGuard := idempotency.NewGuard(rds, &idempotency.Config{
        WindowTime: 1 * time.Hour, // 幂等性窗口时间
    })

    // 3. 创建任务处理器
    taskHandler := &MyTaskHandler{
        db:    entClient,
        cache: rds,
    }

    // 4. 创建安全消费者
    secureConsumer := consumer.NewSecureConsumer(
        1,                  // allowedTenantID - 仅处理租户1的消息
        "unified-io-worker", // groupID
        taskHandler,
        idempotencyGuard,
    )

    // 5. 创建基础消费者
    config := consumer.DefaultConfig(
        []string{"192.168.26.130:9092"},
        "io.input.jobs",
        "unified-io-worker",
    )

    c, err := consumer.NewConsumer(config, secureConsumer)
    if err != nil {
        return err
    }
    defer c.Close()

    // 6. 启动消费者
    ctx := context.Background()
    return c.Start(ctx)
}
```

### 任务处理器接口

安全消费者使用 `TaskHandler` 接口：

```go
type TaskHandler interface {
    HandleTask(ctx context.Context, msg *types.TaskMessage) error
}
```

### TaskMessage 结构

```go
type TaskMessage struct {
    TenantID   uint64    `json:"tenant_id"`   // 租户ID
    TaskRunID  uint64    `json:"task_run_id"` // 任务运行ID（幂等性Key）
    TaskType   string    `json:"task_type"`   // 任务类型
    ProviderID string    `json:"provider_id"` // 提供商ID
    UserID     uint64    `json:"user_id"`     // 用户ID
    Params     string    `json:"params"`      // 参数（JSON）
    CreatedAt  time.Time `json:"created_at"`  // 创建时间
}
```

### 租户验证工作原理

```
┌─────────────────────────────────────────────┐
│  1. 从Kafka Header提取租户ID                 │
│     X-Tenant-ID: "1"                        │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  2. 验证Header租户ID == allowedTenantID      │
│     如果不匹配 → 🚨 安全违规 → 拒绝处理      │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  3. 解析消息体中的租户ID                     │
│     taskMsg.TenantID                        │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  4. 双重验证：Header == Body                │
│     如果不匹配 → 🚨 安全违规 → 拒绝处理      │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  5. 幂等性检查（可选）                       │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  6. 执行业务逻辑                            │
└─────────────────────────────────────────────┘
```

### 安全日志示例

**正常处理**：
```json
{
  "@timestamp": "2025-10-21T23:37:24.116+08:00",
  "level": "info",
  "content": "processing task message",
  "tenant_id": 1,
  "task_run_id": 100,
  "task_type": "sync_users",
  "partition": 0,
  "offset": 100
}
```

**租户隔离违规**：
```json
{
  "@timestamp": "2025-10-21T23:37:24.116+08:00",
  "level": "error",
  "content": "🚨 Tenant isolation violation!",
  "expected_tenant": 1,
  "actual_tenant": 2,
  "consumer_group": "unified-io-worker",
  "partition": 0,
  "offset": 0
}
```

**幂等性检测**：
```json
{
  "@timestamp": "2025-10-21T23:37:24.116+08:00",
  "level": "info",
  "content": "skipping duplicate message",
  "tenant_id": 1,
  "task_run_id": 200,
  "partition": 0,
  "offset": 0
}
```

---

## 幂等性机制

### 工作原理

```
┌─────────────────────────────────────────────┐
│  消息到达 (tenant_id=1, task_run_id=100)    │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  第一层：Redis快速检查                       │
│  Key: idempotency:1:100                     │
│  使用 SETNX + EXPIRE                        │
└────────────────┬────────────────────────────┘
                 │
       ┌─────────┴─────────┐
       │                   │
   已存在(false)        不存在(true)
       │                   │
       ▼                   ▼
   ┌────────┐      ┌──────────────────┐
   │ 拒绝   │      │ 第二层：DB检查    │
   │ 重复消息│      │ (可选)           │
   └────────┘      └────────┬─────────┘
                            │
                  ┌─────────┴─────────┐
                  │                   │
              已存在(false)        不存在(true)
                  │                   │
                  ▼                   ▼
              ┌────────┐         ┌─────────┐
              │ 拒绝   │         │ 处理消息 │
              │ 重复消息│         └─────────┘
              └────────┘
```

### 幂等性Guard配置

```go
import "github.com/coder-lulu/newbee-io-rpc/internal/idempotency"

// 默认配置（窗口时间：1小时）
guard := idempotency.NewGuard(rds, nil)

// 自定义配置
guard := idempotency.NewGuard(rds, &idempotency.Config{
    WindowTime: 30 * time.Minute, // 自定义窗口时间
})
```

### 手动控制幂等性

```go
// 检查并标记
isNew, err := guard.CheckAndMark(ctx, tenantID, taskRunID)
if err != nil {
    return err
}

if !isNew {
    // 重复消息，跳过处理
    return nil
}

// 处理消息...

// 如果处理失败，可以移除标记以允许重试
if err := processMessage(); err != nil {
    guard.Remove(ctx, tenantID, taskRunID)
    return err
}
```

### 幂等性Key设计

**Redis Key 格式**：
```
idempotency:{tenant_id}:{task_run_id}
```

**示例**：
```
idempotency:1:100
idempotency:1:101
idempotency:2:100  // 不同租户，不同Key
```

---

## 配置参数

### Consumer配置详解

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `Brokers` | `[]string` | 必填 | Kafka broker地址列表 |
| `Topic` | `string` | 必填 | Topic名称 |
| `GroupID` | `string` | 必填 | Consumer Group ID |
| `Partition` | `int` | `-1` | 分区号（-1表示自动分配） |
| `MinBytes` | `int` | `1` | 每次拉取最小字节数 |
| `MaxBytes` | `int` | `10485760` | 每次拉取最大字节数（10MB） |
| `MaxWait` | `time.Duration` | `500ms` | 等待最大时长 |
| `CommitInterval` | `time.Duration` | `1s` | 自动提交间隔 |
| `StartOffset` | `int64` | `kafka.LastOffset` | 起始偏移量 |

### StartOffset 选项

```go
// 从最新位置开始（默认）
config.StartOffset = kafka.LastOffset

// 从最早位置开始（适用于历史数据重放）
config.StartOffset = kafka.FirstOffset
```

### 幂等性配置详解

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `WindowTime` | `time.Duration` | `1h` | 幂等性窗口时间 |

---

## 最佳实践

### 1. 错误处理策略

```go
func (h *MyHandler) Handle(ctx context.Context, msg *kafka.Message) error {
    // 1. 临时性错误：返回error，消息不提交，会重试
    if err := h.checkNetwork(); err != nil {
        return fmt.Errorf("network unavailable: %w", err)
    }

    // 2. 永久性错误：记录日志，返回nil，消息提交（避免阻塞）
    var task Task
    if err := json.Unmarshal(msg.Value, &task); err != nil {
        logx.Errorw("invalid message format", logx.Field("error", err))
        return nil // 返回nil，让消息提交
    }

    // 3. 业务错误：根据业务规则决定
    if err := h.processTask(ctx, &task); err != nil {
        if isRetryable(err) {
            return err // 临时性业务错误，重试
        }
        logx.Errorw("permanent business error", logx.Field("error", err))
        return nil // 永久性业务错误，不重试
    }

    return nil
}

func isRetryable(err error) bool {
    // 定义可重试的错误类型
    return errors.Is(err, context.DeadlineExceeded) ||
           errors.Is(err, syscall.ECONNREFUSED)
}
```

### 2. 优雅关闭

```go
func main() {
    // 创建可取消的Context
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    // 监听系统信号
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

    // 创建Consumer
    c, err := consumer.NewConsumer(config, handler)
    if err != nil {
        panic(err)
    }

    // 启动Consumer（后台）
    errChan := make(chan error, 1)
    go func() {
        errChan <- c.Start(ctx)
    }()

    // 等待信号或错误
    select {
    case sig := <-sigChan:
        fmt.Printf("Received signal: %v\n", sig)
        cancel() // 触发优雅关闭
        time.Sleep(5 * time.Second) // 等待消息处理完成
    case err := <-errChan:
        fmt.Printf("Consumer error: %v\n", err)
    }

    // 关闭Consumer
    c.Close()
    fmt.Println("Consumer closed gracefully")
}
```

### 3. 性能优化

```go
// 高吞吐量配置
config := consumer.DefaultConfig(brokers, topic, groupID)
config.MinBytes = 10e3      // 10KB
config.MaxBytes = 10e6      // 10MB
config.MaxWait = 500 * time.Millisecond
config.CommitInterval = 5 * time.Second

// 低延迟配置
config := consumer.DefaultConfig(brokers, topic, groupID)
config.MinBytes = 1         // 最小字节数
config.MaxWait = 100 * time.Millisecond
config.CommitInterval = 1 * time.Second
```

### 4. 监控指标

```go
type MonitoredHandler struct {
    handler       consumer.MessageHandler
    processedMsgs prometheus.Counter
    errorMsgs     prometheus.Counter
    processingTime prometheus.Histogram
}

func (h *MonitoredHandler) Handle(ctx context.Context, msg *kafka.Message) error {
    start := time.Now()
    defer func() {
        h.processingTime.Observe(time.Since(start).Seconds())
    }()

    err := h.handler.Handle(ctx, msg)
    if err != nil {
        h.errorMsgs.Inc()
    } else {
        h.processedMsgs.Inc()
    }
    return err
}
```

### 5. 租户隔离最佳实践

```go
// ✅ 推荐：为每个租户创建独立的Consumer Group
secureConsumer1 := consumer.NewSecureConsumer(
    1,                      // 租户1
    "unified-io-tenant-1",  // 独立的GroupID
    handler,
    guard,
)

secureConsumer2 := consumer.NewSecureConsumer(
    2,                      // 租户2
    "unified-io-tenant-2",  // 独立的GroupID
    handler,
    guard,
)

// ❌ 不推荐：多个租户共享Consumer Group（需要额外的分区规划）
```

---

## 集成测试

### 完整的Producer → Consumer测试

```go
// +build integration

package consumer

import (
    "context"
    "testing"
    "time"

    "github.com/coder-lulu/newbee-io-rpc/internal/idempotency"
    "github.com/coder-lulu/newbee-io-rpc/internal/queue/producer"
    "github.com/coder-lulu/newbee-io-rpc/internal/queue/types"
    "github.com/redis/go-redis/v9"
    "github.com/segmentio/kafka-go"
    "github.com/stretchr/testify/require"
)

func TestIntegration_ProducerConsumer(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test in short mode")
    }

    // 1. 创建Redis客户端
    rds := redis.NewClient(&redis.Options{
        Addr: "localhost:6379",
        DB:   1, // 使用测试数据库
    })
    defer rds.Close()

    // 2. 创建幂等性守护者
    idempotencyGuard := idempotency.NewGuard(rds, &idempotency.Config{
        WindowTime: 5 * time.Minute,
    })

    // 3. 创建测试任务处理器
    taskHandler := &testTaskHandler{
        received: make(chan *types.TaskMessage, 10),
    }

    // 4. 创建安全Consumer
    secureConsumer := NewSecureConsumer(
        1, // tenantID
        "test-consumer-group",
        taskHandler,
        idempotencyGuard,
    )

    // 5. 创建Consumer配置
    consumerConfig := DefaultConfig(
        []string{"192.168.26.130:9092"},
        "io.input.jobs",
        "test-consumer-group",
    )
    consumerConfig.StartOffset = kafka.FirstOffset // 从头开始读取

    // 6. 创建Consumer
    consumer, err := NewConsumer(consumerConfig, secureConsumer)
    require.NoError(t, err)
    defer consumer.Close()

    // 7. 启动Consumer（后台）
    consumerCtx, consumerCancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer consumerCancel()

    consumerDone := make(chan error, 1)
    go func() {
        consumerDone <- consumer.Start(consumerCtx)
    }()

    // 8. 创建Producer
    producerConfig := producer.DefaultConfig([]string{"192.168.26.130:9092"})
    baseProducer, err := producer.NewProducer(producerConfig)
    require.NoError(t, err)
    defer baseProducer.Close()

    secureProducer := producer.NewSecureProducer(baseProducer, false)

    // 9. 发送测试消息
    taskMsg := &types.TaskMessage{
        TenantID:   1,
        TaskRunID:  uint64(time.Now().Unix()),
        TaskType:   "integration_test",
        ProviderID: "test-provider",
        UserID:     100,
        CreatedAt:  time.Now(),
    }

    err = secureProducer.PublishTaskMessage(
        context.Background(),
        "io.input.jobs",
        taskMsg,
        taskMsg.TenantID,
        taskMsg.ProviderID,
    )
    require.NoError(t, err)

    t.Logf("Message sent: tenant_id=%d, task_run_id=%d", taskMsg.TenantID, taskMsg.TaskRunID)

    // 10. 等待接收消息（最多10秒）
    select {
    case receivedMsg := <-taskHandler.received:
        t.Logf("Message received: tenant_id=%d, task_run_id=%d", receivedMsg.TenantID, receivedMsg.TaskRunID)
        require.Equal(t, taskMsg.TenantID, receivedMsg.TenantID)
        require.Equal(t, taskMsg.TaskRunID, receivedMsg.TaskRunID)
        require.Equal(t, taskMsg.TaskType, receivedMsg.TaskType)

    case <-time.After(10 * time.Second):
        t.Fatal("timeout waiting for message")
    }

    t.Log("Integration test passed")
}

// testTaskHandler 测试用的任务处理器
type testTaskHandler struct {
    received chan *types.TaskMessage
}

func (h *testTaskHandler) HandleTask(ctx context.Context, msg *types.TaskMessage) error {
    select {
    case h.received <- msg:
    default:
    }
    return nil
}
```

### 运行集成测试

```bash
# 运行所有集成测试
go test -tags=integration -v ./internal/queue/consumer

# 运行特定集成测试
go test -tags=integration -v ./internal/queue/consumer -run TestIntegration_ProducerConsumer

# 前提条件：
# 1. Kafka服务运行在 192.168.26.130:9092
# 2. Redis服务运行在 localhost:6379
```

---

## 常见问题

### Q1: Consumer无法连接到Kafka

**症状**：
```
failed to dial: failed to open connection to localhost:9092:
dial tcp 127.0.0.1:9092: connect: connection refused
```

**解决方法**：
1. 检查Kafka服务是否运行：`netstat -an | grep 9092`
2. 验证broker地址配置是否正确
3. 检查网络防火墙规则

### Q2: 消息重复处理

**症状**：同一条消息被处理多次

**可能原因**：
1. 未启用幂等性检查
2. Redis连接失败
3. 消息处理时间超过CommitInterval

**解决方法**：
```go
// 1. 启用幂等性
secureConsumer := consumer.NewSecureConsumer(
    tenantID,
    groupID,
    handler,
    idempotencyGuard, // 必须提供
)

// 2. 检查Redis连接
if err := rds.Ping(ctx).Err(); err != nil {
    panic("redis connection failed")
}

// 3. 调整CommitInterval
config.CommitInterval = 5 * time.Second // 增加提交间隔
```

### Q3: 租户隔离违规

**症状**：
```
🚨 Tenant isolation violation! expected_tenant=1 actual_tenant=2
```

**原因**：收到了其他租户的消息

**检查**：
1. Producer是否正确设置租户Header
2. 是否多个租户共享同一个Consumer Group
3. Kafka分区分配策略

**解决方法**：
```go
// 为每个租户创建独立的Consumer Group
secureConsumer1 := consumer.NewSecureConsumer(
    1,
    "unified-io-tenant-1", // 租户1专用GroupID
    handler1,
    guard1,
)

secureConsumer2 := consumer.NewSecureConsumer(
    2,
    "unified-io-tenant-2", // 租户2专用GroupID
    handler2,
    guard2,
)
```

### Q4: Consumer性能问题

**症状**：消息消费速度慢

**优化策略**：

1. **增加并发消费者**：
```go
// 启动多个Consumer实例（不同进程或容器）
// Kafka会自动分配分区
```

2. **优化配置参数**：
```go
config.MinBytes = 10e3      // 增加批量大小
config.MaxBytes = 10e6
config.MaxWait = 500 * time.Millisecond
config.CommitInterval = 5 * time.Second
```

3. **优化Handler性能**：
```go
func (h *MyHandler) Handle(ctx context.Context, msg *kafka.Message) error {
    // 使用goroutine异步处理（注意：需要自己管理offset提交）
    go h.processAsync(ctx, msg)
    return nil
}
```

### Q5: Context取消后消息丢失

**症状**：关闭Consumer时正在处理的消息丢失

**解决方法**：
```go
// 使用优雅关闭模式
ctx, cancel := context.WithCancel(context.Background())

go func() {
    consumer.Start(ctx)
}()

// 收到关闭信号
signal.Notify(sigChan, syscall.SIGTERM)
<-sigChan

cancel()                              // 停止接收新消息
time.Sleep(10 * time.Second)          // 等待当前消息处理完成
consumer.Close()                      // 提交offset并关闭
```

### Q6: 幂等性窗口时间如何设置？

**建议**：

- **实时任务**：`WindowTime: 5-30分钟`（快速过期，节省Redis内存）
- **定时任务**：`WindowTime: 1-24小时`（根据任务执行频率）
- **历史数据导入**：`WindowTime: 24-72小时`（防止重复导入）

```go
// 实时任务
guard := idempotency.NewGuard(rds, &idempotency.Config{
    WindowTime: 30 * time.Minute,
})

// 定时任务
guard := idempotency.NewGuard(rds, &idempotency.Config{
    WindowTime: 24 * time.Hour,
})
```

---

## 参考资料

- [Kafka Consumer官方文档](https://kafka.apache.org/documentation/#consumerapi)
- [kafka-go库文档](https://github.com/segmentio/kafka-go)
- [Kafka Producer使用文档](./KAFKA_PRODUCER_USAGE.md)
- [NewBee编码准则](../CLAUDE.md)

---

**最后更新**: 2025-10-21
**版本**: v1.0.0
**维护者**: Unified-IO Team
