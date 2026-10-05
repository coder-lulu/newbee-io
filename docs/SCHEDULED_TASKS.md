# Scheduled Tasks 功能文档

## 概述

Unified-IO 服务现已支持定时任务功能，允许用户创建在指定时间自动执行的数据发现和集成任务。

## 功能特性

- ✅ **一次性定时任务** - 在指定的未来时间点执行一次
- ✅ **任务类型隔离** - 定时任务与手动任务独立处理，互不干扰
- ✅ **并发控制** - 与手动任务共享并发限制，防止资源过载
- ✅ **自动调度** - 后台 TaskWorker 每分钟自动检查并执行到期任务
- ✅ **租户隔离** - 支持多租户环境下的任务隔离

## 架构设计

### 任务类型

InputTask 支持三种任务类型：

| task_type | 说明 | 触发方式 |
|-----------|------|---------|
| `manual` | 手动任务 | API 手动触发，立即执行 |
| `scheduled` | 定时任务 | 系统自动检查，到期执行 |
| `triggered` | 事件触发任务 | 外部事件触发，立即执行 |

### TaskWorker 双 Ticker 架构

```
TaskWorker
├── Primary Ticker (可配置，默认10秒)
│   └── processOnce() - 处理 manual 和 triggered 任务
│
└── Scheduled Ticker (固定1分钟)
    └── processScheduledTasks() - 处理 scheduled 任务
```

**设计要点**：
- **任务分离** - processOnce() 使用 `TaskTypeNEQ("scheduled")` 过滤，确保不会处理定时任务
- **独立调度** - processScheduledTasks() 每分钟检查到期任务（`ScheduledAtLTE(time.Now())`）
- **共享执行** - 两种类型任务通过相同的 processTask() 执行，共享并发控制
- **SystemContext** - 使用系统上下文绕过租户隔离，处理所有租户的任务

### 数据库 Schema

```sql
-- InputTask 表中的关键字段
CREATE TABLE `io_input_tasks` (
  `task_type` varchar(20) NOT NULL DEFAULT 'manual',  -- 任务类型
  `scheduled_at` datetime DEFAULT NULL,               -- 计划执行时间
  `task_status` varchar(20) NOT NULL DEFAULT 'pending',
  -- ... 其他字段
  KEY `idx_task_type_status` (`task_type`, `task_status`),
  KEY `idx_scheduled_at` (`scheduled_at`)
);
```

## API 使用指南

### 1. 创建定时任务

**RPC 接口**: `CreateInputTask`

**请求示例**：
```json
{
  "taskName": "定时数据发现",
  "taskType": "scheduled",
  "scheduledAt": 1735041600000,  // Unix 毫秒时间戳 (2025-12-24 18:00:00)
  "inputSource": "vmware_vcenter",
  "sourceConfig": "{\"host\": \"vcenter.example.com\"}",
  "taskStatus": "pending",
  "tenantId": 1
}
```

**参数说明**：
- `taskType` - 必须设置为 `"scheduled"`
- `scheduledAt` - Unix 毫秒时间戳，必须是未来时间
- 其他参数与手动任务相同

**验证规则**：
```go
// 1. scheduled 任务必须提供 scheduledAt
if taskType == "scheduled" && scheduledAt == nil {
    return error("scheduled任务必须提供ScheduledAt时间")
}

// 2. scheduledAt 不能是过去时间
if scheduledAt.Before(time.Now()) {
    return error("ScheduledAt不能是过去的时间")
}
```

### 2. 查询定时任务

**查询所有待执行的定时任务**：
```sql
SELECT * FROM io_input_tasks
WHERE task_type = 'scheduled'
  AND task_status = 'pending'
  AND scheduled_at <= NOW()
ORDER BY scheduled_at ASC;
```

**查询某个租户的定时任务**：
```sql
SELECT * FROM io_input_tasks
WHERE task_type = 'scheduled'
  AND tenant_id = ?
ORDER BY scheduled_at DESC;
```

## 执行流程

### 定时任务生命周期

```
1. 创建任务
   ↓ API: CreateInputTask
   ↓ 验证: scheduledAt 必须是未来时间
   ↓ 保存: task_status = "pending"

2. 等待执行
   ↓ TaskWorker 每分钟检查
   ↓ 查询: scheduled_at <= NOW()

3. 开始执行
   ↓ 更新: task_status = "processing"
   ↓ 记录: started_at = NOW()

4. 执行完成
   ↓ 更新: task_status = "completed"
   ↓ 记录: completed_at = NOW()
```

### processScheduledTasks 工作原理

```go
func (w *TaskWorker) processScheduledTasks(ctx context.Context) {
    // 1. 检查并发数
    if currentProcessing >= MaxConcurrent {
        return // 达到并发上限，跳过本次检查
    }

    // 2. 查询到期任务
    tasks := db.InputTask.Query().
        Where(
            inputtask.TaskTypeEQ("scheduled"),     // 只查询定时任务
            inputtask.TaskStatusEQ("pending"),     // 待执行状态
            inputtask.ScheduledAtNotNil(),         // 有执行时间
            inputtask.ScheduledAtLTE(time.Now()), // 已到期
        ).
        Order(ent.Asc(inputtask.FieldScheduledAt)). // 按时间排序
        Limit(pullSize).
        All(systemCtx) // 使用系统上下文

    // 3. 分发任务执行
    for _, task := range tasks {
        go w.processTask(ctx, task)
    }
}
```

## 配置说明

### TaskWorker 配置

```go
type WorkerConfig struct {
    // 手动任务拉取间隔（建议10秒）
    PullInterval time.Duration

    // 每次拉取的任务数量
    BatchSize int

    // 最大并发处理任务数（手动和定时任务共享）
    MaxConcurrent int

    // 单个任务超时时间
    TaskTimeout time.Duration
}

// 默认配置
config := &WorkerConfig{
    PullInterval:  10 * time.Second,
    BatchSize:     10,
    MaxConcurrent: 5,
    TaskTimeout:   5 * time.Minute,
}
```

**注意事项**：
- ✅ Scheduled Ticker 固定为 1 分钟，不可配置
- ✅ MaxConcurrent 限制同时适用于 manual 和 scheduled 任务
- ⚠️ 如果到期任务过多，会分批处理（每分钟处理 BatchSize 个）

## 使用场景

### 1. 定时数据发现

```go
// 每天凌晨 3 点执行数据发现
task := CreateInputTask(&io.InputTaskInfo{
    TaskName:   "每日虚拟机发现",
    TaskType:   "scheduled",
    ScheduledAt: getNextDayAt3AM(), // 计算明天凌晨3点的时间戳
    InputSource: "vmware_vcenter",
    SourceConfig: vcenterConfig,
})
```

### 2. 延迟执行任务

```go
// 10 分钟后执行数据同步
task := CreateInputTask(&io.InputTaskInfo{
    TaskName:   "延迟数据同步",
    TaskType:   "scheduled",
    ScheduledAt: time.Now().Add(10 * time.Minute).UnixMilli(),
    InputSource: "aliyun_ecs",
})
```

### 3. 批量定时任务

```go
// 为多个数据源创建定时任务
for _, source := range dataSources {
    CreateInputTask(&io.InputTaskInfo{
        TaskName:   fmt.Sprintf("%s定时发现", source.Name),
        TaskType:   "scheduled",
        ScheduledAt: scheduleTime.UnixMilli(),
        InputSource: source.Type,
        SourceConfig: source.Config,
    })
}
```

## 监控与日志

### 关键日志

**定时任务被拉取**：
```json
{
  "caller": "worker/task_worker.go:363",
  "content": "Pulled scheduled tasks",
  "count": 3,
  "current_processing": 0,
  "level": "info"
}
```

**定时任务开始执行**：
```json
{
  "caller": "worker/task_worker.go:404",
  "content": "Processing task started",
  "task_id": 123,
  "task_name": "定时数据发现",
  "task_type": "scheduled",
  "tenant_id": 1,
  "level": "info"
}
```

**定时任务执行完成**：
```json
{
  "caller": "worker/task_worker.go:481",
  "content": "Task completed successfully",
  "task_id": 123,
  "duration": "2.5s",
  "level": "info"
}
```

### 监控指标

通过 `worker.GetMetrics()` 获取：

```go
metrics := taskWorker.GetMetrics()

// 总拉取任务数（包含手动和定时）
totalPulled := metrics.TotalPulled

// 总处理任务数
totalProcessed := metrics.TotalProcessed

// 成功任务数
totalSucceeded := metrics.TotalSucceeded

// 当前正在处理的任务数
currentProcessing := metrics.CurrentProcessing

// 上次拉取时间
lastPullTime := metrics.LastPullTime
```

## 测试

### 单元测试

```bash
# 运行所有定时任务测试
go test -v -run "TestTaskWorker_Scheduled" ./internal/worker

# 运行特定测试
go test -v -run "TestTaskWorker_ScheduledTasks$" ./internal/worker
```

### 测试场景覆盖

- ✅ 到期任务自动执行
- ✅ 未到期任务保持 pending 状态
- ✅ 定时任务与手动任务混合执行
- ✅ MaxConcurrent 限制对定时任务生效
- ✅ 租户隔离正常工作

### 集成测试

```go
// 创建测试定时任务
task := client.InputTask.Create().
    SetTaskName("测试定时任务").
    SetTaskType("scheduled").
    SetScheduledAt(time.Now().Add(30 * time.Second)).
    SetInputSource("test").
    SetTaskStatus("pending").
    SetTenantID(1).
    Save(ctx)

// 启动 TaskWorker
worker := NewTaskWorker(db, &WorkerConfig{
    PullInterval: 10 * time.Second,
    MaxConcurrent: 5,
})
worker.Start(ctx)

// 等待任务执行
time.Sleep(90 * time.Second)

// 验证任务状态
updatedTask := client.InputTask.Get(ctx, task.ID)
assert.Equal(t, "completed", updatedTask.TaskStatus)
```

## 限制与注意事项

### 时间精度

- ⚠️ **最小调度间隔**: 1 分钟
- ⚠️ **执行延迟**: 实际执行时间可能延迟 0-60 秒（取决于 scheduled ticker 检查时间）
- ⚠️ **不适合秒级精度**: 如需秒级精度调度，建议使用外部调度系统

### 并发限制

- ⚠️ **共享并发池**: 定时任务与手动任务共享 MaxConcurrent 限制
- ⚠️ **批量处理**: 如果同时有大量任务到期，每分钟只处理 BatchSize 个

### 任务堆积

```
场景: 100 个任务在同一时间到期
配置: MaxConcurrent=5, BatchSize=10

执行计划:
- 第 1 分钟: 拉取 10 个，执行 5 个（并发限制）
- 第 2 分钟: 拉取 10 个，执行剩余 5 个 + 新拉取的 5 个
- ...
- 需要约 10-20 分钟处理完所有任务
```

**建议**：
- 避免大量任务集中在同一时间到期
- 根据业务负载调整 MaxConcurrent 和 BatchSize

## 故障排查

### 问题 1: 定时任务未执行

**检查项**：
1. TaskWorker 是否正常运行？
2. 任务的 scheduled_at 是否已到期？
3. 任务状态是否为 pending？
4. 是否达到 MaxConcurrent 并发上限？

**排查命令**：
```sql
-- 查看所有待执行的定时任务
SELECT * FROM io_input_tasks
WHERE task_type = 'scheduled'
  AND task_status = 'pending'
  AND scheduled_at <= NOW();

-- 查看正在执行的任务数
SELECT COUNT(*) FROM io_input_tasks
WHERE task_status = 'processing';
```

### 问题 2: 任务执行延迟

**原因分析**：
- Scheduled Ticker 每分钟检查一次，延迟 0-60 秒是正常现象
- 如果延迟超过 1 分钟，检查是否有任务堆积

**优化建议**：
- 增大 MaxConcurrent 值
- 增大 BatchSize 值
- 错开任务的 scheduled_at 时间

### 问题 3: 任务重复执行

**不会发生**：
- processScheduledTasks() 只拉取 `task_status = 'pending'` 的任务
- 任务开始执行后立即更新为 `processing`
- 完成后更新为 `completed`
- Ent ORM 的 Hook 机制确保租户隔离

## 未来规划

### Phase 2: Cron 表达式支持（计划中）

```go
// 支持周期性定时任务
type DiscoveryPool struct {
    Schedule string // Cron 表达式，如 "0 0 3 * * ?" (每天凌晨3点)
}

// CronScheduler 自动为每个 Pool 创建 scheduled 任务
scheduler := NewCronScheduler(db)
scheduler.Start() // 解析 Cron 表达式，自动创建任务
```

### Phase 3: 高级调度功能（远期规划）

- 任务依赖关系
- 任务失败重试策略
- 智能 Worker 选择
- 分布式任务锁
- 任务执行历史追踪

## 相关文档

- [TaskWorker 架构设计](./TASK_WORKER_ARCHITECTURE.md)
- [Unified-IO API 文档](./API_REFERENCE.md)
- [Ent Schema 定义](../rpc/ent/schema/input_task.go)
- [发现配置系统架构优化方案](../../discovery-architecture-optimization.md)

---

**最后更新**: 2025-12-24
**版本**: v1.0
**状态**: ✅ Phase 1 已完成，生产就绪
