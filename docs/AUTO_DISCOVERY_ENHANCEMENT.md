# 统一输入输出服务 - 自动发现功能增强方案

## 📋 文档信息

- **文档版本**: v1.0.0
- **创建日期**: 2025-10-01
- **最后更新**: 2025-10-01
- **负责人**: NewBee Team
- **状态**: 实施中

## 🎯 改进目标

基于与 CMDB 服务的对比分析，优化 unified-io 的自动发现功能，使其更加完善、易用和企业级。

## 📊 对比分析总结

### Unified-IO 当前优势
- ✅ 灵活的 Worker 执行架构
- ✅ 独立的 FieldMapping 实体
- ✅ 双向数据流 (Input/Output)
- ✅ 调度和并发控制

### CMDB 服务优势
- ✅ 结构化元数据模型 (CI类型+属性)
- ✅ 丰富的导入模板配置
- ✅ 4种导入模式 (create/update/upsert/merge)
- ✅ 完善的数据清洗和验证
- ✅ 审核流程

### 识别的差距
- ⚠️ 缺少明确的数据目标模型
- ⚠️ 缺少导入模式配置
- ⚠️ 数据清洗和转换能力不足
- ⚠️ 缺少审核和权限控制
- ⚠️ Worker 实体设计过重

## 🔧 架构改进方案

### 阶段 1: 核心功能增强 (高优先级)

#### 1.1 增加导入模式支持
**目标**: 支持 create_only、update_only、upsert、merge 四种导入模式

**Schema 变更**:
```go
// InputTask 增加字段
field.Enum("import_mode").
    Comment("导入模式").
    Values("create_only", "update_only", "upsert", "merge").
    Default("upsert")

field.Enum("conflict_strategy").
    Comment("冲突策略").
    Values("skip", "overwrite", "merge", "error").
    Default("skip")

field.JSON("unique_keys", []string{}).
    Comment("唯一键字段列表").
    Optional()
```

**影响范围**:
- Schema: `input_task.go`
- Proto: `io.proto`
- Logic: `input_task_logic.go`

#### 1.2 增加审核流程
**目标**: 支持任务审核，提高数据质量保证

**Schema 变更**:
```go
// DiscoveryPool 增加字段
field.Enum("approval_status").
    Comment("审核状态").
    Values("pending", "approved", "rejected").
    Default("pending")

field.Uint64("approved_by").
    Comment("审核人ID").
    Optional()

field.Time("approved_at").
    Comment("审核时间").
    Optional()

field.String("rejection_reason").
    Comment("拒绝原因").
    MaxLen(500).
    Optional()

// InputTask 增加相同字段
```

**影响范围**:
- Schema: `discovery_pool.go`, `input_task.go`
- Proto: `io.proto`
- Logic: 新增审核相关 RPC 方法

#### 1.3 增强数据清洗能力
**目标**: 提供预定义的数据清洗器

**Schema 变更**:
```go
// FieldMapping 增加字段
field.Enum("cleaner_type").
    Comment("清洗器类型").
    Values("none", "trim", "normalize", "sanitize", "deduplicate", "format").
    Default("none")

field.JSON("cleaner_config", map[string]interface{}{}).
    Comment("清洗器配置JSON").
    Optional()

field.Int("execution_order").
    Comment("执行顺序").
    Default(100).
    Positive()
```

**影响范围**:
- Schema: `field_mapping.go`
- Proto: `io.proto`
- Logic: 新增数据清洗引擎

### 阶段 2: 模板管理 (中优先级)

#### 2.1 新增 DiscoveryTemplate 实体
**目标**: 支持发现配置模板化和复用

**新增 Schema**:
```go
// DiscoveryTemplate 发现模板实体
type DiscoveryTemplate struct {
    ent.Schema
}

func (DiscoveryTemplate) Fields() []ent.Field {
    return []ent.Field{
        field.String("template_name").
            Comment("模板名称").
            MaxLen(100).
            NotEmpty(),
        
        field.String("template_code").
            Comment("模板编码").
            MaxLen(64).
            NotEmpty().
            Unique(),
        
        field.String("description").
            Comment("模板描述").
            MaxLen(500).
            Optional(),
        
        field.String("version").
            Comment("模板版本").
            MaxLen(20).
            Default("1.0.0"),
        
        field.Enum("template_type").
            Comment("模板类型").
            Values("file", "api", "sdk", "builtin").
            Default("file"),
        
        field.JSON("discovery_config", map[string]interface{}{}).
            Comment("发现配置模板").
            Optional(),
        
        field.JSON("field_mapping_templates", []interface{}{}).
            Comment("字段映射模板").
            Optional(),
        
        field.JSON("validation_rules", []interface{}{}).
            Comment("验证规则模板").
            Optional(),
        
        field.Bool("is_public").
            Comment("是否公开").
            Default(false),
        
        field.Bool("is_system").
            Comment("是否系统模板").
            Default(false),
        
        field.Int("usage_count").
            Comment("使用次数").
            Default(0).
            NonNegative(),
        
        field.JSON("tags", []string{}).
            Comment("模板标签").
            Optional(),
        
        field.JSON("metadata", map[string]interface{}{}).
            Comment("扩展元数据").
            Optional(),
    }
}
```

**影响范围**:
- Schema: 新增 `discovery_template.go`
- Proto: `io.proto` 新增模板管理方法
- Logic: 新增模板 CRUD 逻辑

### 阶段 3: 高级功能 (低优先级)

#### 3.1 新增 DataTarget 实体
**目标**: 定义数据输出的目标结构和约束

**新增 Schema**:
```go
// DataTarget 数据目标实体
type DataTarget struct {
    ent.Schema
}

func (DataTarget) Fields() []ent.Field {
    return []ent.Field{
        field.String("target_name").
            Comment("目标名称").
            MaxLen(100).
            NotEmpty(),
        
        field.Enum("target_type").
            Comment("目标类型").
            Values("database_table", "api_endpoint", "message_queue", "file_system").
            Default("database_table"),
        
        field.JSON("target_schema", map[string]interface{}{}).
            Comment("目标结构定义").
            Optional(),
        
        field.JSON("validation_rules", []interface{}{}).
            Comment("验证规则").
            Optional(),
        
        field.JSON("unique_keys", []string{}).
            Comment("唯一键字段列表").
            Optional(),
        
        field.JSON("connection_config", map[string]interface{}{}).
            Comment("连接配置").
            Optional(),
    }
}
```

#### 3.2 优化 Worker 监控
**目标**: 将实时指标移到独立时序表

**新增 Schema**:
```go
// WorkerMetrics Worker监控指标 (时序数据)
type WorkerMetrics struct {
    ent.Schema
}

func (WorkerMetrics) Fields() []ent.Field {
    return []ent.Field{
        field.String("worker_id").
            Comment("Worker ID").
            MaxLen(50).
            NotEmpty(),
        
        field.Float("cpu_usage_percent").
            Comment("CPU使用率").
            Default(0).
            Range(0, 100),
        
        field.Float("memory_usage_percent").
            Comment("内存使用率").
            Default(0).
            Range(0, 100),
        
        field.Int("current_task_count").
            Comment("当前任务数").
            Default(0).
            NonNegative(),
        
        field.Float("throughput_rate").
            Comment("吞吐率").
            Default(0),
        
        field.Time("metric_time").
            Comment("指标时间").
            Default(time.Now),
    }
}
```

**Worker Schema 简化**:
```go
// 移除实时指标字段，仅保留配置字段
// 删除: cpu_usage_percent, memory_usage_percent, throughput_rate
// 删除: current_task_count, avg_processing_time
```

## 📝 实施计划

### 原子任务清单

#### Phase 1: 导入模式和审核流程 (2-3天)

**任务 1.1: 修改 InputTask Schema**
- [ ] 在 `input_task.go` 增加 `import_mode` 字段
- [ ] 在 `input_task.go` 增加 `conflict_strategy` 字段
- [ ] 在 `input_task.go` 增加 `unique_keys` 字段
- [ ] 在 `input_task.go` 增加审核相关字段 (approval_status, approved_by, approved_at, rejection_reason)

**任务 1.2: 修改 DiscoveryPool Schema**
- [ ] 在 `discovery_pool.go` 增加审核相关字段 (approval_status, approved_by, approved_at, rejection_reason)

**任务 1.3: 修改 FieldMapping Schema**
- [ ] 在 `field_mapping.go` 增加 `cleaner_type` 字段
- [ ] 在 `field_mapping.go` 增加 `cleaner_config` 字段
- [ ] 在 `field_mapping.go` 增加 `execution_order` 字段

**任务 1.4: 生成代码**
- [ ] 运行 `make gen-rpc` 生成 ent 和 proto 代码
- [ ] 检查生成的代码是否正确

**任务 1.5: 更新 API 定义**
- [ ] 更新 `input_task.api` 添加新字段
- [ ] 更新 `discovery_pool.api` 添加审核接口
- [ ] 新增审核相关的 handler 定义
- [ ] 运行 `make gen-api` 生成 API 代码

**任务 1.6: 实现业务逻辑**
- [ ] 实现 InputTask 导入模式逻辑
- [ ] 实现 DiscoveryPool 审核流程逻辑
- [ ] 实现 FieldMapping 数据清洗引擎
- [ ] 实现冲突策略处理逻辑

**任务 1.7: 单元测试**
- [ ] 编写导入模式测试用例
- [ ] 编写审核流程测试用例
- [ ] 编写数据清洗测试用例

#### Phase 2: 模板管理 (2-3天)

**任务 2.1: 创建 DiscoveryTemplate Schema**
- [ ] 创建 `discovery_template.go` 文件
- [ ] 定义 Mixin, Fields, Edges, Indexes
- [ ] 添加表注解

**任务 2.2: 更新关联关系**
- [ ] 在 DiscoveryPool 增加 template_id 字段
- [ ] 添加 DiscoveryPool -> DiscoveryTemplate 的 edge
- [ ] 更新索引

**任务 2.3: 生成代码和 API**
- [ ] 运行 `make gen-rpc` 生成代码
- [ ] 创建 `discovery_template.api` 文件
- [ ] 定义模板 CRUD 接口
- [ ] 运行 `make gen-api` 生成 API 代码

**任务 2.4: 实现模板逻辑**
- [ ] 实现模板创建、更新、删除、查询
- [ ] 实现从模板创建 DiscoveryPool
- [ ] 实现模板版本控制

**任务 2.5: 单元测试**
- [ ] 编写模板 CRUD 测试
- [ ] 编写模板复用测试

#### Phase 3: 高级功能 (3-4天)

**任务 3.1: 创建 DataTarget Schema**
- [ ] 创建 `data_target.go` 文件
- [ ] 定义完整的实体结构
- [ ] 添加关联关系

**任务 3.2: 创建 WorkerMetrics Schema**
- [ ] 创建 `worker_metrics.go` 文件
- [ ] 定义时序数据结构
- [ ] 配置时序索引

**任务 3.3: 简化 Worker Schema**
- [ ] 移除实时指标字段
- [ ] 保留配置字段
- [ ] 更新关联关系

**任务 3.4: 生成代码和 API**
- [ ] 运行 `make gen-rpc` 生成代码
- [ ] 更新相关 API 定义
- [ ] 运行 `make gen-api` 生成 API 代码

**任务 3.5: 实现业务逻辑**
- [ ] 实现 DataTarget CRUD
- [ ] 实现 WorkerMetrics 写入和查询
- [ ] 实现监控数据聚合

**任务 3.6: 单元测试**
- [ ] 编写 DataTarget 测试
- [ ] 编写 WorkerMetrics 测试

## 📋 验收标准

### 功能验收
- [ ] 导入模式功能正常 (create_only, update_only, upsert, merge)
- [ ] 审核流程完整 (提交审核、审核通过、审核拒绝)
- [ ] 数据清洗引擎可用 (trim, normalize, sanitize, deduplicate)
- [ ] 模板管理功能完整 (CRUD、复用、版本控制)
- [ ] 数据目标管理可用
- [ ] Worker 监控优化完成

### 性能验收
- [ ] 导入性能无明显下降
- [ ] Worker 监控数据写入延迟 < 100ms
- [ ] 审核查询响应时间 < 50ms

### 安全验收
- [ ] 所有新实体包含 TenantMixin (多租户隔离)
- [ ] 审核权限控制正确
- [ ] 敏感配置加密存储

### 代码质量
- [ ] 遵循 CLAUDE.md 编码规范
- [ ] 使用 `make gen-rpc` 和 `make gen-api` 生成代码
- [ ] 单元测试覆盖率 > 80%
- [ ] 无 lint 错误

## 🔄 回滚计划

如果实施过程中出现严重问题，按以下步骤回滚：

1. **数据库回滚**: 恢复 schema 变更前的数据库备份
2. **代码回滚**: 回退到实施前的 git commit
3. **服务重启**: 重启 RPC 和 API 服务
4. **验证功能**: 确认原有功能正常

## 📚 参考文档

- [NewBee 编码准则](../CLAUDE.md)
- [项目架构文档](./ARCHITECTURE.md)
- [API 文档](./API.md)
- [CMDB 服务文档](../../cmdb/docs/)

## 📞 联系方式

- **负责人**: NewBee Team
- **问题反馈**: GitHub Issues

---

**更新日志**:
- 2025-10-01: 初始版本，完成对比分析和改进方案设计
