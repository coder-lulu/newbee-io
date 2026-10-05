# ChangeRecorder 实现文档

## 概述

ChangeRecorder（变更记录器）是unified-io CMDB自动发现系统的核心组件之一，负责记录所有CI（配置项）的变更历史，包括创建、更新、删除和批量操作。它将变更记录持久化到数据库表 `ci_change_history`，支持完整的审计追踪、变更回滚和合规性审查。

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                   CI Operation Flow                         │
│                                                             │
│  Operation Context  →  Execute Operation  →  Record Change │
│   (Before/After)         (Result)            (History)     │
└─────────────────────────────────────────────────────────────┘
                                    ↓
                    ┌───────────────────────────────┐
                    │    ChangeRecorder             │
                    │                               │
                    │  • RecordCreate()             │
                    │  • RecordUpdate()             │
                    │  • RecordDelete()             │
                    │  • RecordBatch()              │
                    │  • QueryChangeHistory()       │
                    └───────────────────────────────┘
                                    ↓
                    ┌───────────────────────────────┐
                    │  Database: ci_change_history  │
                    │                               │
                    │  30+ fields including:        │
                    │  - Operation metadata         │
                    │  - Before/after values        │
                    │  - Changed fields             │
                    │  - Approval workflow          │
                    │  - Rollback support           │
                    └───────────────────────────────┘
```

## 核心功能

### 1. 创建操作记录 (RecordCreate)

记录CI创建操作，保存新数据的完整快照。

```go
record, err := changeRecorder.RecordCreate(ctx, operation, result)
if err != nil {
    log.Error("Failed to record create operation", err)
    return err
}
```

**记录内容**:
- 操作ID、CI类型、操作人
- 新数据完整JSON (new_values)
- 数据来源（手动、自动发现、导入等）
- IP地址、User Agent
- 审批状态（如果需要审批）

### 2. 更新操作记录 (RecordUpdate)

记录CI更新操作，**自动计算变更字段**并保存前后对比。

```go
record, err := changeRecorder.RecordUpdate(ctx, operation, result)
if err != nil {
    log.Error("Failed to record update operation", err)
    return err
}
```

**记录内容**:
- 操作ID、CI ID、CI类型
- 旧数据JSON (old_values)
- 新数据JSON (new_values)
- **变更字段列表** (changed_fields) - 自动计算
  ```json
  [
    {"field": "name", "old_value": "server01", "new_value": "server02"},
    {"field": "status", "old_value": 1, "new_value": 2},
    {"field": "ip_address", "old_value": "192.168.1.10", "new_value": "192.168.1.20"}
  ]
  ```

### 3. 删除操作记录 (RecordDelete)

记录CI删除操作，保存删除前的完整数据以支持回滚。

```go
record, err := changeRecorder.RecordDelete(ctx, operation, result)
if err != nil {
    log.Error("Failed to record delete operation", err)
    return err
}
```

**记录内容**:
- 操作ID、CI ID
- 删除前的完整数据 (old_values)
- 标记为可回滚 (can_rollback = true)
- 删除原因

### 4. 批量操作记录 (RecordBatch)

记录批量操作，为每个受影响的CI创建独立记录。

```go
records, err := changeRecorder.RecordBatch(ctx, operation, result)
if err != nil {
    log.Error("Failed to record batch operation", err)
    return err
}
```

**特点**:
- 每个CI一条记录
- 共享同一个 operation_id（便于追踪整个批量操作）
- 记录总影响数量 (affected_count)

### 5. 查询变更历史 (QueryChangeHistory)

查询指定CI的变更历史，支持分页。

```go
records, err := changeRecorder.QueryChangeHistory(ctx, ciID, limit, offset)
if err != nil {
    log.Error("Failed to query change history", err)
    return err
}
```

**查询结果**:
- 按时间倒序排列（最新的在前）
- 包含完整的变更信息
- 自动解析JSON字段
- 审批状态自动映射

## 数据库Schema

### ci_change_history 表结构

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | uint64 | 主键ID |
| `operation_id` | string | 操作ID（全局唯一） |
| `ci_id` | uint64 | CI实例ID |
| `ci_type_id` | uint64 | CI类型ID |
| `operation_type` | string | 操作类型 (create/update/delete) |
| `operator_id` | uint64 | 操作人用户ID |
| `operator_name` | string | 操作人用户名 |
| `old_values` | text | 变更前完整数据JSON |
| `new_values` | text | 变更后完整数据JSON |
| `changed_fields` | text | 变更字段JSON数组 |
| `change_reason` | string | 变更原因 |
| `source` | string | 数据来源 |
| `source_detail` | string | 来源详情 |
| `ip_address` | string | 操作IP地址 |
| `user_agent` | string | 用户代理 |
| `needs_approval` | bool | 是否需要审批 |
| `is_approved` | bool | 是否已审批 |
| `approved_by` | uint64 | 审批人ID |
| `approved_at` | time | 审批时间 |
| `status` | string | 记录状态 |
| `can_rollback` | bool | 是否可回滚 |
| `is_rollback` | bool | 是否为回滚操作 |
| `rollback_from_id` | uint64 | 回滚来源记录ID |
| `affected_count` | int | 影响的记录数 |
| `duration_ms` | int | 操作耗时（毫秒） |
| `tenant_id` | uint64 | 租户ID（多租户隔离） |
| `department_id` | uint64 | 部门ID（数据权限） |
| `created_at` | time | 创建时间 |
| `updated_at` | time | 更新时间 |

### 索引设计

```sql
-- 1. 按租户和CI ID查询历史（最常用）
INDEX idx_tenant_ci_id (tenant_id, ci_id, created_at DESC)

-- 2. 按CI类型查询
INDEX idx_ci_type_id (ci_type_id)

-- 3. 按操作类型查询
INDEX idx_operation_type (operation_type)

-- 4. 按操作人查询
INDEX idx_operator_id (operator_id)

-- 5. 按操作ID查询（追溯完整操作链）
INDEX idx_operation_id (operation_id)

-- 6. 按时间查询
INDEX idx_created_at (created_at DESC)

-- 7. 审批查询
INDEX idx_approval (needs_approval, is_approved)
```

## 变更字段自动计算

ChangeRecorder实现了智能的变更字段检测算法：

### 算法逻辑

```go
func calculateChangedFields(before, after *cmdb.CisInfo) []map[string]interface{} {
    // 1. 比较基础字段（name, description, status等）
    // 2. 比较属性值（attributes map）
    //    - 检测值变更
    //    - 检测新增属性
    //    - 检测删除属性
    // 3. 返回变更列表
}
```

### 输出格式

```json
[
  {
    "field": "name",
    "old_value": "server01",
    "new_value": "server02"
  },
  {
    "field": "ip_address",
    "old_value": null,
    "new_value": "192.168.1.100"  // 新增属性
  },
  {
    "field": "old_field",
    "old_value": "some_value",
    "new_value": null  // 删除属性
  }
]
```

## 使用示例

### 示例1: 记录创建操作

```go
// 准备操作上下文
operation := &core.CiOperationContext{
    OperationID:  "op-123456",
    Type:         core.OperationCreate,
    Source:       core.SourceManual,
    OperatorID:   userUUID,
    OperatorName: "admin",
    CiTypeID:     1,
    DataAfter:    ciData,  // 新创建的CI数据
    Reason:       "新增服务器配置",
    ClientIP:     "192.168.1.100",
    UserAgent:    "Mozilla/5.0...",
}

// 执行操作并记录
result := executeCiOperation(ctx, operation)
record, err := changeRecorder.RecordCreate(ctx, operation, result)
if err != nil {
    return err
}

log.Infof("Change recorded: %s", record.RecordID)
```

### 示例2: 记录更新操作（自动计算变更）

```go
// 准备操作上下文（包含前后数据）
operation := &core.CiOperationContext{
    OperationID:  "op-123457",
    Type:         core.OperationUpdate,
    Source:       core.SourceAPI,
    OperatorID:   userUUID,
    OperatorName: "admin",
    CiID:         &ciID,
    CiTypeID:     1,
    DataBefore:   oldData,  // 更新前的数据
    DataAfter:    newData,  // 更新后的数据
    Reason:       "修改服务器IP地址",
}

// 执行操作并记录（自动计算changed_fields）
result := executeCiOperation(ctx, operation)
record, err := changeRecorder.RecordUpdate(ctx, operation, result)
if err != nil {
    return err
}

log.Infof("Update recorded with %d changed fields", len(record.ChangedFields))
```

### 示例3: 查询变更历史

```go
// 查询CI的变更历史（分页）
ciID := uint64(12345)
limit := 20   // 每页20条
offset := 0   // 从第一页开始

records, err := changeRecorder.QueryChangeHistory(ctx, ciID, limit, offset)
if err != nil {
    return err
}

// 遍历历史记录
for _, record := range records {
    fmt.Printf("Operation: %s at %s by %s\n",
        record.OperationType,
        record.OperationTime.Format("2006-01-02 15:04:05"),
        record.OperatorName)

    // 显示变更字段
    if len(record.ChangedFields) > 0 {
        fmt.Printf("  Changed fields: %v\n", record.ChangedFields)
    }

    // 显示审批状态
    if record.RequireApproval {
        fmt.Printf("  Approval status: %s\n", record.ApprovalStatus)
    }
}
```

### 示例4: 批量操作记录

```go
// 准备批量操作上下文
operation := &core.CiOperationContext{
    OperationID:  "op-batch-001",
    Type:         core.OperationBatchUpdate,
    Source:       core.SourceAutomation,
    OperatorID:   systemUUID,
    OperatorName: "system",
    CiTypeID:     1,
    Reason:       "批量更新服务器状态",
}

// 执行批量操作
result := executeBatchOperation(ctx, operation)
// result.AffectedCiIDs = [123, 456, 789]

// 记录批量操作（为每个CI创建记录）
records, err := changeRecorder.RecordBatch(ctx, operation, result)
if err != nil {
    return err
}

log.Infof("Batch operation recorded: %d records created", len(records))
```

## 审批工作流集成

ChangeRecorder支持与审批工作流无缝集成：

### 审批状态流转

```
pending → approved/rejected
```

### 记录审批信息

```go
operation := &core.CiOperationContext{
    // ... 其他字段
    RequireApproval: true,  // 标记需要审批
}

record, err := changeRecorder.RecordCreate(ctx, operation, result)
// 数据库记录: needs_approval = true, is_approved = null
```

### 更新审批状态（由ApprovalManager调用）

```go
// 审批通过
db.CiChangeHistory.UpdateOneID(recordID).
    SetIsApproved(true).
    SetApprovedBy(approverID).
    SetApprovedByName(approverName).
    SetApprovedAt(time.Now()).
    SetApprovalComment("审批通过").
    Save(ctx)

// 审批拒绝
db.CiChangeHistory.UpdateOneID(recordID).
    SetIsApproved(false).
    SetApprovedBy(approverID).
    SetApprovedAt(time.Now()).
    SetApprovalComment("不符合规范").
    Save(ctx)
```

## 回滚支持

### 删除操作回滚

```go
// 1. 查询删除记录
deleteRecord, err := db.CiChangeHistory.Query().
    Where(
        cichangehistory.OperationIDEQ("op-delete-123"),
        cichangehistory.CanRollbackEQ(true),
    ).
    First(ctx)

// 2. 从old_values恢复数据
var oldData cmdb.CisInfo
json.Unmarshal([]byte(*deleteRecord.OldValues), &oldData)

// 3. 重新创建CI
operation := &core.CiOperationContext{
    Type:           core.OperationCreate,
    Source:         core.SourceManual,
    OperatorID:     userUUID,
    OperatorName:   "admin",
    DataAfter:      &oldData,
    Reason:         "回滚删除操作",
    Metadata: map[string]interface{}{
        "is_rollback": true,
        "rollback_from_id": deleteRecord.ID,
    },
}

result := executeCiOperation(ctx, operation)

// 4. 记录回滚操作
rollbackRecord, err := changeRecorder.RecordCreate(ctx, operation, result)
db.CiChangeHistory.UpdateOneID(rollbackRecord.ID).
    SetIsRollback(true).
    SetRollbackFromID(deleteRecord.ID).
    Save(ctx)
```

## 性能优化

### 1. 批量操作性能

- **当前实现**: 顺序插入，失败不影响其他记录
- **优化方向**: 使用批量插入（db.CiChangeHistory.CreateBulk()）

### 2. 查询性能

- 使用复合索引加速常用查询
- 支持分页避免大结果集
- 可添加Redis缓存热点数据

### 3. JSON字段处理

- 变更字段计算在内存中完成，性能开销低
- 大数据JSON压缩存储（未来优化）

## 监控指标

建议监控以下指标：

```go
// 记录创建速率
change_record_create_rate

// 记录创建延迟
change_record_create_latency_ms

// 变更字段计算耗时
changed_fields_calculation_time_ms

// 查询历史延迟
query_history_latency_ms

// 失败记录数
change_record_failures_total
```

## 合规性审计

ChangeRecorder提供完整的审计追踪能力：

### 审计查询示例

```sql
-- 查询用户的所有操作记录
SELECT * FROM ci_change_history
WHERE operator_id = 12345
ORDER BY created_at DESC;

-- 查询需要审批但未审批的操作
SELECT * FROM ci_change_history
WHERE needs_approval = true AND is_approved IS NULL;

-- 查询某个CI的完整变更历史
SELECT * FROM ci_change_history
WHERE ci_id = 67890
ORDER BY created_at ASC;

-- 查询批量操作的所有记录
SELECT * FROM ci_change_history
WHERE operation_id = 'op-batch-001';
```

## 故障排查

### 常见问题

1. **记录保存失败**: 检查数据库连接、字段长度限制
2. **变更字段计算错误**: 验证DataBefore和DataAfter数据格式
3. **查询性能慢**: 检查索引使用情况、优化查询条件

### 日志级别

```go
// 成功记录
c.logger.Infow("Change record created", ...)

// 失败记录
c.logger.Errorw("Failed to save change record", ...)
```

## 未来扩展

### 计划功能

1. **变更分析**: 统计变更频率、变更热点
2. **异常检测**: 识别异常变更模式
3. **自动回滚**: 基于规则的自动回滚
4. **变更报告**: 生成定期变更报告
5. **集成通知**: 重要变更实时通知

## 相关文档

- [PermissionChecker实现文档](./PERMISSION_CHECKER_IMPLEMENTATION.md)
- [CI变更历史Schema设计](../rpc/ent/schema/ci_change_history.go)
- [CMDB核心组件架构](./CORE_COMPONENTS_ARCHITECTURE.md)

---

**创建时间**: 2025-01-XX
**版本**: 1.0.0
**维护者**: NewBee团队
