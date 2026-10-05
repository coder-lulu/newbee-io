# Kafka Producer 使用指南

## 概述

本文档介绍如何使用统一输入输出平台的 Kafka Producer 组件。该组件提供了安全、可靠的消息发布能力，支持多租户隔离、消息脱敏、幂等性保证等企业级功能。

## 快速开始

### 1. 基础用法

```go
package main

import (
	"context"
	"time"

	"github.com/coder-lulu/newbee-io-rpc/internal/queue/producer"
)

func main() {
	// 1. 创建Producer配置
	config := &producer.Config{
		Brokers:      []string{"192.168.26.130:9092"},
		WriteTimeout: 10 * time.Second,
		ReadTimeout:  10 * time.Second,
		BatchSize:    100,
		MaxAttempts:  3,
		Compression:  "snappy",
	}

	// 2. 创建Producer
	producer, err := producer.NewProducer(config)
	if err != nil {
		panic(err)
	}
	defer producer.Close()

	// 3. 发送消息
	ctx := context.Background()
	topic := "io.input.jobs"
	key := []byte("tenant-1:connector-1")
	value := []byte(`{"task_type":"sync_users","tenant_id":1}`)
	headers := map[string]string{
		"X-Tenant-ID": "1",
		"X-Trace-ID":  "trace-123",
	}

	err = producer.Publish(ctx, topic, key, value, headers)
	if err != nil {
		panic(err)
	}
}
```

### 2. 使用安全Producer（推荐）

```go
package main

import (
	"context"
	"time"

	"github.com/coder-lulu/newbee-io-rpc/internal/queue/producer"
	"github.com/coder-lulu/newbee-io-rpc/internal/queue/types"
)

func main() {
	// 1. 创建基础Producer
	config := producer.DefaultConfig([]string{"192.168.26.130:9092"})
	baseProducer, err := producer.NewProducer(config)
	if err != nil {
		panic(err)
	}
	defer baseProducer.Close()

	// 2. 创建安全Producer（启用严格模式）
	secureProducer := producer.NewSecureProducer(baseProducer, true)

	// 3. 构建任务消息
	taskMsg := &types.TaskMessage{
		TenantID:        1,
		TaskRunID:       12345,
		TaskType:        "sync_users",
		ProviderID:      "ldap-provider",
		CredentialRefID: "cred-001", // 使用凭证引用，不传递实际密码
		UserID:          100,
		CreatedAt:       time.Now(),
		MappingRules: []types.FieldMapping{
			{
				SourceField: "uid",
				TargetField: "username",
			},
			{
				SourceField: "mail",
				TargetField: "email",
			},
		},
	}

	// 4. 发送消息（自动添加租户隔离Header、消息脱敏检测）
	ctx := context.Background()
	err = secureProducer.PublishTaskMessage(ctx, "io.input.jobs", taskMsg, 1, "ldap-provider")
	if err != nil {
		panic(err)
	}
}
```

### 3. 发送带幂等性的消息

```go
package main

import (
	"context"

	"github.com/coder-lulu/newbee-io-rpc/internal/queue/producer"
)

func main() {
	// 创建安全Producer
	config := producer.DefaultConfig([]string{"192.168.26.130:9092"})
	baseProducer, _ := producer.NewProducer(config)
	defer baseProducer.Close()

	secureProducer := producer.NewSecureProducer(baseProducer, false)

	// 构建输出任务消息
	taskResult := map[string]interface{}{
		"tenant_id":   uint64(1),
		"task_run_id": uint64(12345),
		"task_type":   "write_users",
		"result": map[string]interface{}{
			"created": 10,
			"updated": 5,
			"failed":  1,
		},
	}

	// 发送带幂等性的消息（自动生成idempotency_key）
	ctx := context.Background()
	err := secureProducer.PublishWithIdempotency(ctx, "io.output.jobs", taskResult, 1, 12345)
	if err != nil {
		panic(err)
	}
}
```

## 核心功能

### 1. 多租户隔离

安全Producer会自动在消息Header中添加 `X-Tenant-ID`，确保租户隔离：

```go
// 自动添加的Headers:
// - X-Tenant-ID: "1"
// - X-Trace-ID: "uuid-trace-id"
// - X-Message-ID: "uuid-message-id"
// - X-Timestamp: "2025-10-21T15:30:00Z"

err := secureProducer.PublishTaskMessage(ctx, topic, msg, tenantID, connectorID)
```

### 2. 消息脱敏

安全Producer会自动检测并脱敏消息中的敏感信息：

**严格模式**（推荐）：
```go
// 启用严格模式：检测到敏感信息时拒绝发送
secureProducer := producer.NewSecureProducer(baseProducer, true)

// ❌ 这条消息会被拒绝
msg := map[string]interface{}{
	"username": "admin",
	"password": "secret123", // 检测到密码字段
}
err := secureProducer.PublishTaskMessage(ctx, topic, msg, 1, "test")
// 返回错误: "message contains sensitive fields: [password]"
```

**宽松模式**：
```go
// 宽松模式：自动脱敏后发送
secureProducer := producer.NewSecureProducer(baseProducer, false)

// ✅ 这条消息会被自动脱敏
msg := map[string]interface{}{
	"username": "admin",
	"password": "secret123",
}
err := secureProducer.PublishTaskMessage(ctx, topic, msg, 1, "test")
// 发送的消息: {"username":"admin","password":"***REDACTED***"}
```

**敏感字段列表**：
- `password`
- `api_key`
- `secret`
- `token`
- `private_key`
- `access_key`
- `secret_key`

### 3. 幂等性保证

使用 `PublishWithIdempotency` 方法可以自动生成幂等性Key：

```go
err := secureProducer.PublishWithIdempotency(ctx, topic, msg, tenantID, taskRunID)

// 自动添加的Headers:
// - X-Idempotency-Key: "md5(tenantID:taskRunID:timestamp)"
// - X-Task-Run-ID: "12345"

// 消息体中也会注入 idempotency_key 字段
```

### 4. 分区策略

**输入任务**（io.input.jobs）：
- 分区Key: `tenantID:connectorID`
- 保证同一租户的同一connector的消息发送到同一分区

**输出任务**（io.output.jobs）：
- 分区Key: `tenantID:taskRunID`
- 保证同一任务的结果消息发送到同一分区

### 5. 消息压缩

支持多种压缩算法：

```go
config := &producer.Config{
	Compression: "snappy", // 支持: snappy, lz4, gzip, zstd
}
```

**压缩算法选择**：
- **snappy**（推荐）：平衡压缩率和性能，CPU占用低
- **lz4**：压缩速度最快，适合高吞吐场景
- **gzip**：压缩率最高，适合带宽受限场景
- **zstd**：新一代压缩算法，平衡性能和压缩率

## 配置参数

### Producer.Config

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `Brokers` | `[]string` | 无 | Kafka broker地址列表（必填） |
| `WriteTimeout` | `time.Duration` | 10s | 写入超时时间 |
| `ReadTimeout` | `time.Duration` | 10s | 读取超时时间 |
| `BatchSize` | `int` | 100 | 批量大小（消息数） |
| `MaxAttempts` | `int` | 3 | 最大重试次数 |
| `Compression` | `string` | "snappy" | 压缩算法 |

### SecureProducer

| 参数 | 类型 | 说明 |
|------|------|------|
| `inner` | `Producer` | 基础Producer实例 |
| `strictMode` | `bool` | 严格模式：true=拒绝敏感信息，false=自动脱敏 |

## 运行测试

### 单元测试

```bash
# 运行所有单元测试
go test -v ./internal/queue/producer

# 运行特定测试
go test -v ./internal/queue/producer -run TestSecureProducer
```

### 集成测试

**前提条件**：Kafka服务必须运行在 `192.168.26.130:9092`

```bash
# 运行集成测试
go test -tags=integration -v ./internal/queue/producer

# 运行性能测试
go test -tags=integration -v ./internal/queue/producer -run TestIntegration_PerformanceTest
```

### 性能测试结果示例

```
Performance test results:
  Messages sent: 1000
  Time elapsed: 1.234s
  Throughput: 810.37 msg/s
```

## 生产环境最佳实践

### 1. 连接池管理

```go
// ✅ 推荐：全局单例Producer
var globalProducer producer.Producer

func init() {
	config := producer.DefaultConfig([]string{"kafka-1:9092", "kafka-2:9092"})
	var err error
	globalProducer, err = producer.NewProducer(config)
	if err != nil {
		panic(err)
	}
}

// 使用全局Producer
func PublishTask(ctx context.Context, msg *types.TaskMessage) error {
	secureProducer := producer.NewSecureProducer(globalProducer, true)
	return secureProducer.PublishTaskMessage(ctx, "io.input.jobs", msg, msg.TenantID, msg.ProviderID)
}
```

### 2. 错误处理

```go
err := secureProducer.PublishTaskMessage(ctx, topic, msg, tenantID, connectorID)
if err != nil {
	// 记录审计日志
	logx.Errorw("failed to publish task",
		logx.Field("tenant_id", tenantID),
		logx.Field("connector_id", connectorID),
		logx.Field("error", err))

	// 发送告警
	alertManager.Send(ctx, Alert{
		Level:   "error",
		Title:   "Kafka发送失败",
		Message: fmt.Sprintf("租户%d的任务发送失败: %v", tenantID, err),
	})

	return err
}
```

### 3. 超时控制

```go
// 设置发送超时
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

err := secureProducer.PublishTaskMessage(ctx, topic, msg, tenantID, connectorID)
if err == context.DeadlineExceeded {
	// 处理超时
	return fmt.Errorf("publish timeout: %w", err)
}
```

### 4. 批量发送优化

```go
// 使用较大的BatchSize提升吞吐量
config := &producer.Config{
	Brokers:   []string{"kafka-1:9092"},
	BatchSize: 500, // 增加批量大小
}
```

### 5. 监控指标

建议监控以下指标：

- **发送成功率**：`kafka_publish_success_total / kafka_publish_total`
- **发送延迟**：`kafka_publish_duration_seconds`
- **消息大小**：`kafka_message_size_bytes`
- **敏感信息检测次数**：`kafka_sensitive_data_detected_total`
- **重试次数**：`kafka_publish_retries_total`

## 故障排查

### 1. 连接失败

**错误信息**：
```
failed to connect to kafka: dial tcp 192.168.26.130:9092: connect: connection refused
```

**解决方法**：
- 检查Kafka服务是否运行：`nc -zv 192.168.26.130 9092`
- 检查防火墙规则
- 检查Kafka配置中的 `advertised.listeners`

### 2. 消息发送超时

**错误信息**：
```
publish message: context deadline exceeded
```

**解决方法**：
- 增加 `WriteTimeout` 配置
- 检查网络延迟：`ping 192.168.26.130`
- 检查Kafka集群负载

### 3. 敏感信息被拒绝

**错误信息**：
```
message contains sensitive fields: [password]
```

**解决方法**：
- 使用凭证引用模式：`CredentialRefID` 而非直接传递密码
- 或者关闭严格模式（不推荐）

## 参考文档

- [Kafka集成设计文档](./unified-io-kafka-queue-design.md)
- [开发计划文档](./IMPLEMENTATION_STATUS_AND_PRIORITY.md)
- [Week 3集成测试报告](./WEEK3_PROVIDER_INTEGRATION_TEST_REPORT.md)

## 更新日志

### v1.0.0 (2025-10-21)

- ✅ 实现基础Producer接口
- ✅ 实现SecureProducer（租户隔离、消息脱敏）
- ✅ 实现幂等性支持
- ✅ 添加单元测试（覆盖率 >80%）
- ✅ 添加集成测试和性能测试
- ✅ 支持多种压缩算法（snappy, lz4, gzip, zstd）

### 下一步计划

- [ ] 实现Kafka Consumer
- [ ] 实现Outbox模式
- [ ] 添加SASL/SSL支持
- [ ] 实现大消息处理（>900KB上传对象存储）
- [ ] 集成Prometheus监控指标

---

**最后更新**: 2025-10-21
**作者**: NewBee IO Team
**版本**: v1.0.0
