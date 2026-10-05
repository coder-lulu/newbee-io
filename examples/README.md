# Scheduled Tasks 使用示例

本目录包含 Scheduled Tasks（定时任务）功能的使用示例和最佳实践。

## 示例列表

### 1. scheduled_task_example.go

完整的客户端示例，演示如何：
- 创建简单的定时任务
- 批量创建定时任务
- 查询和监控任务状态

## 运行示例

### 前置条件

1. **服务已启动**：unified-io RPC 服务运行在 `localhost:9102`
2. **Go 环境**：Go ≥ 1.21
3. **依赖安装**：

```bash
cd /opt/code/newbee/unified-io/examples

# 安装依赖
go mod init examples 2>/dev/null || true
go get google.golang.org/grpc
go get github.com/coder-lulu/newbee-io-rpc/types/io
```

### 运行示例

```bash
# 运行完整示例
go run scheduled_task_example.go

# 输出示例：
# === Scheduled Tasks 使用示例 ===
#
# 示例1: 创建一个5分钟后执行的定时任务
# ✅ 任务创建成功
#    任务ID: 123
#    任务名称: 数据发现任务-示例1
#    执行时间: 2025-12-24 10:50:00
#    距离执行: 5 分钟
# ...
```

## 快速开始

### 最简单的定时任务

```go
package main

import (
    "context"
    "log"
    "time"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials/insecure"

    io "github.com/coder-lulu/newbee-io-rpc/types/io"
)

func main() {
    // 1. 连接服务
    conn, _ := grpc.Dial("localhost:9102",
        grpc.WithTransportCredentials(insecure.NewCredentials()))
    defer conn.Close()

    client := io.NewIoClient(conn)
    ctx := context.Background()

    // 2. 设置执行时间（1小时后）
    scheduledTime := time.Now().Add(1 * time.Hour)
    scheduledAtMs := scheduledTime.UnixMilli()

    // 3. 创建任务
    taskName := "我的第一个定时任务"
    taskType := "scheduled"
    inputSource := "vmware_vcenter"
    sourceConfig := `{"host": "vcenter.example.com"}`
    taskStatus := "pending"
    tenantId := uint64(1)

    req := &io.InputTaskInfo{
        TaskName:     &taskName,
        TaskType:     &taskType,
        ScheduledAt:  &scheduledAtMs,
        InputSource:  &inputSource,
        SourceConfig: &sourceConfig,
        TaskStatus:   &taskStatus,
        TenantId:     &tenantId,
    }

    resp, err := client.CreateInputTask(ctx, req)
    if err != nil {
        log.Fatalf("创建失败: %v", err)
    }

    log.Printf("✅ 任务创建成功，ID=%d", *resp.Id)
}
```

## 使用 grpcurl 测试

如果不想编写代码，可以使用 `grpcurl` 命令行工具：

```bash
# 安装 grpcurl
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

# 创建定时任务
SCHEDULED_TIME=$(($(date +%s) + 3600))000  # 1小时后

grpcurl -plaintext \
  -d '{
    "taskName": "grpcurl测试任务",
    "taskType": "scheduled",
    "scheduledAt": '$SCHEDULED_TIME',
    "inputSource": "test",
    "sourceConfig": "{\"test\": true}",
    "taskStatus": "pending",
    "tenantId": 1
  }' \
  localhost:9102 io.Io/CreateInputTask

# 查询任务状态
grpcurl -plaintext \
  -d '{"id": 123}' \
  localhost:9102 io.Io/GetInputTaskById
```

## 常见使用场景

### 场景1: 每日定时数据发现

```go
// 明天凌晨3点执行
tomorrow := time.Now().AddDate(0, 0, 1)
scheduledTime := time.Date(
    tomorrow.Year(), tomorrow.Month(), tomorrow.Day(),
    3, 0, 0, 0, time.Local)

scheduledAtMs := scheduledTime.UnixMilli()
// ... 创建任务
```

### 场景2: 延迟执行任务

```go
// 30分钟后执行
scheduledTime := time.Now().Add(30 * time.Minute)
scheduledAtMs := scheduledTime.UnixMilli()
// ... 创建任务
```

### 场景3: 批量创建定时任务

```go
for i := 0; i < 10; i++ {
    // 错开10分钟避免堆积
    scheduledTime := baseTime.Add(time.Duration(i*10) * time.Minute)
    scheduledAtMs := scheduledTime.UnixMilli()

    // ... 创建任务
}
```

## 监控任务执行

### 方式1: 程序轮询

```go
ticker := time.NewTicker(10 * time.Second)
for range ticker.C {
    task, _ := client.GetInputTaskById(ctx, &io.IDReq{Id: taskId})

    switch *task.TaskStatus {
    case "pending":
        log.Println("等待执行...")
    case "processing":
        log.Println("执行中...")
    case "completed":
        log.Println("✅ 已完成")
        return
    case "failed":
        log.Println("❌ 执行失败")
        return
    }
}
```

### 方式2: 数据库查询

```sql
-- 查看所有待执行的定时任务
SELECT id, task_name, scheduled_at, task_status
FROM io_input_tasks
WHERE task_type = 'scheduled'
  AND task_status = 'pending'
ORDER BY scheduled_at;

-- 查看任务执行历史
SELECT id, task_name,
       scheduled_at,
       started_at,
       completed_at,
       TIMESTAMPDIFF(SECOND, scheduled_at, started_at) as delay_sec
FROM io_input_tasks
WHERE task_type = 'scheduled'
  AND task_status = 'completed'
ORDER BY completed_at DESC
LIMIT 10;
```

### 方式3: 日志监控

```bash
# 实时查看任务执行日志
tail -f /opt/newbee/unified-io/logs/io-rpc.log | grep -E "Pulled scheduled tasks|Processing task started|Task completed"

# 查看今天执行的定时任务
grep "Pulled scheduled tasks" logs/io-rpc.log | grep "$(date +%Y-%m-%d)"
```

## 错误处理

### 常见错误

| 错误信息 | 原因 | 解决方法 |
|---------|------|---------|
| `scheduled任务必须提供ScheduledAt时间` | 未设置 scheduledAt | 设置未来时间戳 |
| `ScheduledAt不能是过去的时间` | 时间戳是过去时间 | 使用未来时间 |
| `context deadline exceeded` | 请求超时 | 检查服务状态 |
| `connection refused` | 服务未启动 | 启动 io-rpc 服务 |

### 错误处理示例

```go
resp, err := client.CreateInputTask(ctx, req)
if err != nil {
    // 处理错误
    if strings.Contains(err.Error(), "过去的时间") {
        log.Println("❌ 错误：scheduled_at必须是未来时间")
        // 重新设置时间
        scheduledAtMs = time.Now().Add(1*time.Hour).UnixMilli()
        req.ScheduledAt = &scheduledAtMs
        // 重试
        resp, err = client.CreateInputTask(ctx, req)
    }

    if err != nil {
        log.Fatalf("创建失败: %v", err)
    }
}

log.Printf("✅ 任务创建成功，ID=%d", *resp.Id)
```

## 最佳实践

### 1. 时间设置

```go
// ✅ 推荐：使用明确的时区
loc, _ := time.LoadLocation("Asia/Shanghai")
scheduledTime := time.Date(2025, 12, 25, 3, 0, 0, 0, loc)

// ❌ 避免：使用本地时区可能导致混淆
scheduledTime := time.Now().Add(24 * time.Hour)
```

### 2. 错开执行时间

```go
// ✅ 推荐：批量任务错开执行
for i, task := range tasks {
    baseTime := tomorrow.Add(3 * time.Hour)  // 凌晨3点开始
    scheduledTime := baseTime.Add(time.Duration(i*15) * time.Minute)  // 每个错开15分钟
    // ...
}

// ❌ 避免：所有任务同一时间执行，可能造成堆积
scheduledTime := tomorrow.Add(3 * time.Hour)  // 所有任务都是3点
```

### 3. 错误恢复

```go
// ✅ 推荐：失败任务重新创建
if task.TaskStatus == "failed" {
    // 重新创建任务，延后1小时
    newScheduledTime := time.Now().Add(1 * time.Hour)
    // ... 创建新任务
}

// ✅ 推荐：设置合理的超时时间
ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
defer cancel()
```

### 4. 监控和告警

```go
// ✅ 推荐：记录任务创建信息
log.Printf("创建定时任务: ID=%d, 名称=%s, 执行时间=%s",
    taskId, taskName, scheduledTime.Format(time.RFC3339))

// ✅ 推荐：定期检查任务状态
go func() {
    ticker := time.NewTicker(5 * time.Minute)
    for range ticker.C {
        checkPendingTasks()  // 检查是否有堆积的任务
    }
}()
```

## 性能优化

### 大量任务处理

```go
// 对于数百个任务，使用并发创建
tasks := []TaskConfig{...}  // 假设有200个任务

sem := make(chan struct{}, 10)  // 限制并发数为10
var wg sync.WaitGroup

for _, task := range tasks {
    wg.Add(1)
    sem <- struct{}{}  // 获取信号量

    go func(t TaskConfig) {
        defer wg.Done()
        defer func() { <-sem }()  // 释放信号量

        createScheduledTask(client, t)
    }(task)
}

wg.Wait()
```

## 相关文档

- [功能文档](../docs/SCHEDULED_TASKS.md) - 完整功能说明
- [部署指南](../docs/DEPLOYMENT_GUIDE.md) - 部署和配置
- [测试报告](../docs/PHASE1_SUCCESS_REPORT.md) - 测试结果
- [API文档](../rpc/desc/io.proto) - Proto定义

## 问题反馈

如有问题或建议，请：
1. 查看 [故障排查指南](../docs/SCHEDULED_TASKS.md#故障排查)
2. 查看日志: `/opt/newbee/unified-io/logs/io-rpc.log`
3. 提交 Issue: [GitHub Issues](https://github.com/newbee/unified-io/issues)

---

**最后更新**: 2025-12-24
**版本**: v1.0
