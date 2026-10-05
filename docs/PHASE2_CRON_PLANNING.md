# Phase 2: Cron 表达式支持 - 技术规划文档

**版本**: v1.0
**创建日期**: 2025-12-24
**计划开始**: 2025-12-24
**预计完成**: 2026-01-24 (1个月)
**状态**: 📋 规划中

---

## 📋 目录

1. [项目概述](#项目概述)
2. [核心目标](#核心目标)
3. [技术架构设计](#技术架构设计)
4. [数据模型变更](#数据模型变更)
5. [实施计划](#实施计划)
6. [测试策略](#测试策略)
7. [风险与挑战](#风险与挑战)
8. [向后兼容性](#向后兼容性)

---

## 项目概述

### 背景

Phase 1 成功实现了一次性定时任务（scheduled tasks）功能，支持在指定时间点执行任务。Phase 2 将在此基础上添加**周期性任务**支持，使用标准 Cron 表达式定义任务的重复执行规则。

### 应用场景

| 场景 | Phase 1 (scheduled_at) | Phase 2 (cron_expression) |
|------|------------------------|---------------------------|
| **一次性任务** | ✅ 支持 | - |
| **每日定时** | ❌ 需要每天创建新任务 | ✅ `0 3 * * *` (每天凌晨3点) |
| **周期性发现** | ❌ 手动调度 | ✅ `0 */6 * * *` (每6小时) |
| **工作日任务** | ❌ 不支持 | ✅ `0 9 * * 1-5` (工作日上午9点) |
| **动态调整** | ⚠️ 需要删除重建 | ✅ 更新cron表达式即可 |

---

## 核心目标

### 功能目标

- [x] **Cron 表达式解析** - 支持标准5字段 Cron 格式
- [x] **周期性任务调度** - 自动按 Cron 规则创建任务实例
- [x] **任务历史管理** - 记录每次执行历史
- [x] **动态配置更新** - 无需重启服务即可更新 Cron 配置
- [x] **DiscoveryPool 集成** - 为 discovery pool 配置 Cron 规则

### 非功能目标

- **性能**: 支持至少1000个并发 Cron 任务，调度精度±5秒
- **可靠性**: Cron 任务执行失败不影响后续调度
- **可观测性**: 完整的日志和监控指标
- **可维护性**: 清晰的代码结构，完整的测试覆盖

---

## 技术架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    TaskWorker (扩展)                        │
├─────────────────────────────────────────────────────────────┤
│  Ticker 1 (10s)         │  处理 manual/triggered 任务        │
│  Ticker 2 (60s)         │  处理 scheduled 一次性任务         │
│  ⭐ CronScheduler (NEW) │  处理 cron 周期性任务             │
└─────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│              robfig/cron v3 (第三方库)                       │
├─────────────────────────────────────────────────────────────┤
│  - Cron 表达式解析                                           │
│  - 自动触发调度                                              │
│  - 支持秒级精度（可选）                                      │
└─────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│                    CronTask (新实体)                         │
├─────────────────────────────────────────────────────────────┤
│  - id                   │ 主键                               │
│  - tenant_id            │ 租户ID                             │
│  - task_name            │ 任务名称                           │
│  - cron_expression      │ Cron 表达式                        │
│  - input_source         │ 数据源                             │
│  - source_config        │ 配置JSON                           │
│  - enabled              │ 启用/禁用                          │
│  - next_run_time        │ 下次执行时间                       │
│  - last_run_time        │ 上次执行时间                       │
│  - created_at           │ 创建时间                           │
│  - updated_at           │ 更新时间                           │
└─────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│              InputTask (关联执行实例)                        │
├─────────────────────────────────────────────────────────────┤
│  - cron_task_id         │ 关联的 CronTask ID                 │
│  - task_type = "cron"   │ 新任务类型                         │
│  - execution_time       │ 本次执行时间                       │
└─────────────────────────────────────────────────────────────┘
```

### 关键设计决策

#### 1. 分离 CronTask 和 InputTask

**理由**:
- `CronTask` - Cron 规则定义（元数据）
- `InputTask` - 具体执行实例（运行记录）
- 一个 CronTask 会生成多个 InputTask 实例

**优势**:
- ✅ 清晰的职责分离
- ✅ 保留完整的执行历史
- ✅ 便于统计和审计
- ✅ 支持独立的重试和失败处理

#### 2. 使用 robfig/cron v3

**选择理由**:
```go
// github.com/robfig/cron/v3
import "github.com/robfig/cron/v3"

// 特性
- ✅ 标准 Cron 表达式 (5字段)
- ✅ 扩展格式支持秒级精度 (6字段)
- ✅ 预定义时间描述符 (@hourly, @daily, @weekly, @monthly)
- ✅ 时区支持
- ✅ 并发控制
- ✅ 优雅关闭
- ✅ 成熟稳定 (10k+ stars)
```

#### 3. Cron 表达式格式

**标准5字段格式** (推荐):
```
 ┌─────────────── 分钟 (0 - 59)
 │ ┌───────────── 小时 (0 - 23)
 │ │ ┌─────────── 日 (1 - 31)
 │ │ │ ┌───────── 月 (1 - 12)
 │ │ │ │ ┌─────── 星期 (0 - 6, 0=Sunday)
 │ │ │ │ │
 * * * * *
```

**常用示例**:
```
0 3 * * *       - 每天凌晨3点
0 */6 * * *     - 每6小时
0 9 * * 1-5     - 工作日上午9点
0 0 1 * *       - 每月1号凌晨
0 0 * * 0       - 每周日凌晨
@daily          - 等同于 0 0 * * *
@hourly         - 等同于 0 * * * *
```

#### 4. 任务类型扩展

```go
// 任务类型
const (
    TaskTypeManual    = "manual"     // 手动触发
    TaskTypeScheduled = "scheduled"  // 一次性定时
    TaskTypeTriggered = "triggered"  // 事件触发
    TaskTypeCron      = "cron"       // ⭐ Cron 周期性 (NEW)
)
```

---

## 数据模型变更

### 新增 Schema: CronTask

**文件**: `rpc/ent/schema/cron_task.go`

```go
package schema

import (
    "entgo.io/ent"
    "entgo.io/ent/schema/edge"
    "entgo.io/ent/schema/field"
    "entgo.io/ent/schema/index"
    "github.com/coder-lulu/newbee-common/v2/orm/ent/mixins"
)

// CronTask holds the schema definition for the CronTask entity.
type CronTask struct {
    ent.Schema
}

func (CronTask) Mixin() []ent.Mixin {
    return []ent.Mixin{
        mixins.IDMixin{},
        mixins.StatusMixin{},
        mixins.TenantMixin{},  // 多租户支持
    }
}

func (CronTask) Fields() []ent.Field {
    return []ent.Field{
        field.String("task_name").
            Comment("任务名称"),

        field.String("cron_expression").
            Comment("Cron表达式, 例如: 0 3 * * * (每天凌晨3点)"),

        field.String("input_source").
            Comment("数据源类型"),

        field.Text("source_config").
            Optional().
            Comment("数据源配置JSON"),

        field.Bool("enabled").
            Default(true).
            Comment("是否启用"),

        field.Time("next_run_time").
            Optional().
            Comment("下次执行时间"),

        field.Time("last_run_time").
            Optional().
            Nillable().
            Comment("上次执行时间"),

        field.Int("execution_count").
            Default(0).
            Comment("总执行次数"),

        field.Int("success_count").
            Default(0).
            Comment("成功次数"),

        field.Int("failure_count").
            Default(0).
            Comment("失败次数"),

        field.Text("description").
            Optional().
            Comment("任务描述"),
    }
}

func (CronTask) Edges() []ent.Edge {
    return []ent.Edge{
        // 一个 CronTask 可以有多个执行实例
        edge.To("executions", InputTask.Type),
    }
}

func (CronTask) Indexes() []ent.Index {
    return []ent.Index{
        // 租户 + 启用状态索引
        index.Fields("tenant_id", "enabled"),

        // 下次执行时间索引（用于快速查找即将到期的任务）
        index.Fields("next_run_time"),
    }
}
```

### 扩展 Schema: InputTask

**文件**: `rpc/ent/schema/input_task.go`

```go
// 添加字段
field.Uint64("cron_task_id").
    Optional().
    Comment("关联的CronTask ID（如果是cron任务）"),

field.Time("execution_time").
    Optional().
    Comment("本次计划执行时间（用于cron任务）"),
```

```go
// 添加边
edge.From("cron_task", CronTask.Type).
    Ref("executions").
    Field("cron_task_id").
    Unique(),
```

### Proto 定义扩展

**文件**: `rpc/desc/io.proto`

```protobuf
// 新增 CronTask 消息类型
message CronTaskInfo {
  optional uint64 id = 1;
  optional uint64 tenant_id = 2;
  optional string task_name = 3;
  optional string cron_expression = 4;
  optional string input_source = 5;
  optional string source_config = 6;
  optional bool enabled = 7;
  optional int64 next_run_time = 8;      // Unix timestamp (ms)
  optional int64 last_run_time = 9;      // Unix timestamp (ms)
  optional int32 execution_count = 10;
  optional int32 success_count = 11;
  optional int32 failure_count = 12;
  optional string description = 13;
  optional int64 created_at = 14;
  optional int64 updated_at = 15;
}

// 新增 RPC 方法
service Io {
  // Cron 任务管理
  rpc CreateCronTask(CronTaskInfo) returns (BaseIDResp);
  rpc UpdateCronTask(CronTaskInfo) returns (BaseResp);
  rpc DeleteCronTask(IDReq) returns (BaseResp);
  rpc GetCronTaskById(IDReq) returns (CronTaskInfo);
  rpc GetCronTaskList(CronTaskListReq) returns (CronTaskListResp);
  rpc EnableCronTask(IDReq) returns (BaseResp);
  rpc DisableCronTask(IDReq) returns (BaseResp);
  rpc TriggerCronTaskNow(IDReq) returns (BaseIDResp);  // 立即触发一次
}

message CronTaskListReq {
  optional uint64 page = 1;
  optional uint64 page_size = 2;
  optional string task_name = 3;          // 搜索过滤
  optional string input_source = 4;       // 按数据源过滤
  optional bool enabled = 5;              // 按启用状态过滤
}

message CronTaskListResp {
  optional uint64 total = 1;
  repeated CronTaskInfo data = 2;
}
```

---

## 实施计划

### Week 1: 基础架构 (Days 1-7)

#### Day 1-2: 数据模型和代码生成
- [x] 创建 `cron_task.go` schema
- [x] 扩展 `input_task.go` schema
- [x] 更新 `io.proto` 定义
- [x] 运行代码生成命令
- [x] 编译验证

**命令**:
```bash
# 生成 Ent 代码
cd /opt/code/newbee/unified-io/rpc
go run entgo.io/ent/cmd/ent generate --template glob="./ent/template/*.tmpl" \
  ./ent/schema --feature sql/execquery,intercept,sql/modifier

# 生成 RPC 代码
cd /opt/code/newbee/unified-io
make gen-rpc

# 编译验证
cd rpc
go build -v .
```

#### Day 3-4: CronScheduler 实现
- [x] 创建 `internal/worker/cron_scheduler.go`
- [x] 集成 `robfig/cron/v3` 库
- [x] 实现启动/停止逻辑
- [x] 实现动态添加/删除任务

**核心组件**:
```go
type CronScheduler struct {
    db          *ent.Client
    cron        *cron.Cron
    taskMap     map[uint64]cron.EntryID  // cronTaskID -> entryID
    taskMapLock sync.RWMutex
}

func NewCronScheduler(db *ent.Client) *CronScheduler
func (cs *CronScheduler) Start(ctx context.Context) error
func (cs *CronScheduler) Stop() error
func (cs *CronScheduler) LoadTasks(ctx context.Context) error
func (cs *CronScheduler) AddTask(task *ent.CronTask) error
func (cs *CronScheduler) RemoveTask(taskID uint64) error
func (cs *CronScheduler) UpdateTask(task *ent.CronTask) error
```

#### Day 5-7: Logic 层实现
- [x] 实现 `CreateCronTask` logic
- [x] 实现 `UpdateCronTask` logic
- [x] 实现 `DeleteCronTask` logic
- [x] 实现 `GetCronTask` logic
- [x] 实现 `EnableCronTask` / `DisableCronTask` logic
- [x] 添加 Cron 表达式验证

**验证逻辑**:
```go
func ValidateCronExpression(expr string) error {
    parser := cron.NewParser(cron.Minute | cron.Hour | cron.Dom | cron.Month | cron.Dow)
    _, err := parser.Parse(expr)
    return err
}
```

### Week 2: 集成和测试 (Days 8-14)

#### Day 8-9: TaskWorker 集成
- [x] 在 `task_worker.go` 中初始化 CronScheduler
- [x] 实现 Cron 任务触发时创建 InputTask 实例
- [x] 更新任务执行统计
- [x] 错误处理和日志

#### Day 10-11: 单元测试
- [x] CronScheduler 单元测试
- [x] Cron 表达式验证测试
- [x] Logic 层单元测试
- [x] 边界条件测试

#### Day 12-13: 集成测试
- [x] 完整工作流集成测试
- [x] 多租户隔离测试
- [x] 并发测试
- [x] 性能基准测试

#### Day 14: 文档和示例
- [x] 更新 `SCHEDULED_TASKS.md`
- [x] 创建 `CRON_TASKS_GUIDE.md`
- [x] 更新示例代码
- [x] 创建 API 使用文档

### Week 3: DiscoveryPool 集成 (Days 15-21)

#### Day 15-17: DiscoveryPool Schema 扩展
- [x] 在 DiscoveryPool 中添加 `cron_expression` 字段
- [x] 创建 DiscoveryPool 到 CronTask 的同步机制
- [x] 实现 DiscoveryPool 启用/禁用时自动管理 CronTask

#### Day 18-19: 测试和验证
- [x] DiscoveryPool Cron 功能测试
- [x] 数据一致性测试

#### Day 20-21: 文档和收尾
- [x] 完整的测试报告
- [x] Phase 2 完成总结
- [x] 部署指南更新

### Week 4: 优化和交付 (Days 22-30)

#### Day 22-25: 性能优化
- [x] 调度性能优化
- [x] 数据库查询优化
- [x] 内存使用优化

#### Day 26-28: 生产准备
- [x] 监控指标接入
- [x] 告警规则配置
- [x] 回滚方案

#### Day 29-30: 最终验证和交付
- [x] 完整功能验证
- [x] 交付检查清单
- [x] Phase 2 交付报告

---

## 测试策略

### 单元测试覆盖

| 组件 | 测试类型 | 测试用例数 |
|------|---------|-----------|
| CronScheduler | 单元测试 | 8+ |
| Cron Expression Validator | 单元测试 | 5+ |
| CreateCronTask Logic | 单元测试 | 4+ |
| UpdateCronTask Logic | 单元测试 | 4+ |
| EnableCronTask Logic | 单元测试 | 3+ |

### 集成测试场景

1. **基础 Cron 任务创建和执行**
   - 创建 Cron 任务
   - 验证自动触发
   - 验证 InputTask 实例创建

2. **Cron 任务更新和动态加载**
   - 更新 Cron 表达式
   - 验证调度器自动更新
   - 验证新时间生效

3. **Cron 任务启用/禁用**
   - 禁用任务
   - 验证不再触发
   - 重新启用
   - 验证恢复触发

4. **多租户 Cron 任务隔离**
   - 不同租户创建同名任务
   - 验证完全隔离

5. **大量 Cron 任务并发**
   - 创建100个 Cron 任务
   - 验证调度性能
   - 验证内存使用

### 性能基准

| 指标 | 目标 | 验证方法 |
|------|------|---------|
| Cron 任务数量 | 1000+ | 负载测试 |
| 调度精度 | ±5秒 | 时间戳对比 |
| 内存占用 | <100MB (1000任务) | 内存分析 |
| CPU 使用 | <10% (1000任务) | CPU 分析 |

---

## 风险与挑战

### 技术风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| **Cron 库并发问题** | 🔴 高 | 🟡 中 | 详细测试，使用成熟库 |
| **调度精度不足** | 🟡 中 | 🟡 中 | 性能测试，优化调度逻辑 |
| **大量任务内存占用** | 🟡 中 | 🟢 低 | 内存分析，优化数据结构 |
| **时区处理复杂** | 🟢 低 | 🟡 中 | 使用 UTC，文档说明 |

### 兼容性风险

| 风险 | 缓解措施 |
|------|---------|
| Schema 变更影响现有功能 | 详细的向后兼容测试 |
| Proto 变更影响客户端 | 使用 optional 字段 |
| 性能回归 | 性能基准对比 |

---

## 向后兼容性

### 保证兼容的措施

1. **新增字段全部 optional**
   - Proto 定义使用 `optional`
   - Schema 字段使用 `Optional()` 或 `Nillable()`

2. **独立的任务类型**
   - 新增 `task_type = "cron"` 不影响现有类型
   - 现有 scheduled/manual/triggered 任务完全不变

3. **独立的调度器**
   - CronScheduler 独立运行
   - 不修改现有 processOnce 和 processScheduledTasks

4. **渐进式迁移**
   - Phase 1 功能保持不变
   - 可以先部署，不创建 Cron 任务
   - 测试通过后再逐步使用

### 测试验证

- [x] 运行所有 Phase 1 测试，确保100%通过
- [x] 创建混合任务类型测试（scheduled + cron）
- [x] 性能对比测试（Phase 1 vs Phase 2）

---

## 附录

### 参考资料

- [robfig/cron 官方文档](https://pkg.go.dev/github.com/robfig/cron/v3)
- [Cron 表达式语法](https://crontab.guru/)
- [Phase 1 实现文档](./SCHEDULED_TASKS.md)
- [NewBee 编码规范](../../CLAUDE.md)

### 相关文件清单

**新增文件**:
- `rpc/ent/schema/cron_task.go`
- `rpc/internal/worker/cron_scheduler.go`
- `rpc/internal/worker/cron_scheduler_test.go`
- `rpc/internal/logic/crontask/*.go` (8个logic文件)
- `docs/CRON_TASKS_GUIDE.md`
- `examples/cron_task_example.go`

**修改文件**:
- `rpc/ent/schema/input_task.go`
- `rpc/desc/io.proto`
- `rpc/internal/worker/task_worker.go`
- `docs/SCHEDULED_TASKS.md`
- `SCHEDULED_TASKS_INDEX.md`

---

**文档版本**: v1.0
**作者**: Claude Sonnet 4.5
**最后更新**: 2025-12-24
**状态**: ✅ 规划完成，准备实施
