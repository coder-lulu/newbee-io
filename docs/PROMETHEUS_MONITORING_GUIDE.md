# Unified-IO服务 Prometheus监控集成指南

## 执行时间
2025-12-26

## 概述

本文档描述了Unified-IO服务中CI变更历史和生命周期状态功能的Prometheus监控集成实现。

## 监控架构

### 组件结构

```
unified-io/rpc/
├── internal/
│   ├── config/
│   │   └── config.go              (配置定义)
│   ├── monitoring/
│   │   ├── metrics.go              (指标定义和收集器)
│   │   └── server.go               (Prometheus HTTP服务器)
│   ├── svc/
│   │   └── service_context.go      (ServiceContext集成)
│   └── core/
│       └── component_impls.go      (业务组件集成点)
└── etc/
    └── io.yaml                     (Prometheus配置)
```

### 监控端点

- **Metrics端点**: `http://0.0.0.0:4005/metrics`
- **健康检查**: `http://0.0.0.0:4005/health`

## 指标清单

### CI变更历史指标

#### 1. `io_change_history_operations_total` (Counter)
**描述**: CI变更操作总数

**标签**:
- `tenant_id`: 租户ID
- `operation_type`: 操作类型 (create/update/delete)
- `status`: 操作状态 (success/failure)

**用途**: 统计各租户各类型变更操作的成功/失败次数

**告警规则示例**:
```yaml
# 变更失败率超过10%告警
- alert: HighChangeFailureRate
  expr: |
    (sum by (tenant_id) (rate(io_change_history_operations_total{status="failure"}[5m]))
    /
    sum by (tenant_id) (rate(io_change_history_operations_total[5m])))
    > 0.1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "租户{{ $labels.tenant_id }}变更失败率过高"
    description: "当前失败率: {{ $value | humanizePercentage }}"
```

#### 2. `io_change_history_operation_duration_seconds` (Histogram)
**描述**: CI变更操作耗时分布

**标签**:
- `tenant_id`: 租户ID
- `operation_type`: 操作类型

**Buckets**: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5, 10]秒

**用途**: 分析变更操作的性能表现

**告警规则示例**:
```yaml
# 变更操作P99耗时超过5秒告警
- alert: SlowChangeOperations
  expr: |
    histogram_quantile(0.99,
      rate(io_change_history_operation_duration_seconds_bucket[5m])
    ) > 5
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "变更操作响应缓慢"
    description: "P99耗时: {{ $value | humanizeDuration }}"
```

#### 3. `io_change_history_errors_total` (Counter)
**描述**: CI变更错误总数

**标签**:
- `tenant_id`: 租户ID
- `operation_type`: 操作类型
- `error_type`: 错误类型 (validation/permission/database/rollback)

**用途**: 定位变更失败的具体原因

#### 4. `io_change_history_rollbacks_total` (Counter)
**描述**: CI变更回滚操作总数

**用途**: 监控回滚操作频率,评估变更质量

#### 5. `io_change_history_approvals_total` (Counter)
**描述**: CI变更审批操作总数

**标签**:
- `tenant_id`: 租户ID
- `result`: 审批结果 (approved/rejected)

**用途**: 统计审批通过率

#### 6. `io_change_history_comparisons_total` (Counter)
**描述**: CI变更对比操作总数

**用途**: 监控变更审计的活跃度

---

### CI生命周期状态指标

#### 7. `io_lifecycle_state_transitions_total` (Counter)
**描述**: CI生命周期状态转换总数

**标签**:
- `tenant_id`: 租户ID
- `from_state`: 源状态
- `to_state`: 目标状态
- `status`: 转换状态 (success/failure)

**用途**: 统计状态流转路径和成功率

**告警规则示例**:
```yaml
# 状态转换失败率超过5%告警
- alert: HighStateTransitionFailureRate
  expr: |
    (sum by (tenant_id, from_state, to_state)
      (rate(io_lifecycle_state_transitions_total{status="failure"}[5m]))
    /
    sum by (tenant_id, from_state, to_state)
      (rate(io_lifecycle_state_transitions_total[5m])))
    > 0.05
  for: 10m
  labels:
    severity: critical
  annotations:
    summary: "状态转换{{ $labels.from_state }}→{{ $labels.to_state }}失败率过高"
```

#### 8. `io_lifecycle_state_duration_seconds` (Histogram)
**描述**: CI在各状态的停留时间分布

**标签**:
- `tenant_id`: 租户ID
- `state_type`: 状态类型

**Buckets**: [1, 5, 10, 30, 60, 300, 600, 1800, 3600, 7200, 14400]秒

**用途**: 分析工作流瓶颈,识别长时间停滞的状态

**告警规则示例**:
```yaml
# submitted状态停留超过1小时告警
- alert: LongWaitInSubmittedState
  expr: |
    histogram_quantile(0.9,
      rate(io_lifecycle_state_duration_seconds_bucket{state_type="submitted"}[15m])
    ) > 3600
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "CI在submitted状态停留时间过长"
```

#### 9. `io_lifecycle_state_errors_total` (Counter)
**描述**: CI生命周期状态转换错误总数

**标签**:
- `tenant_id`: 租户ID
- `from_state`: 源状态
- `to_state`: 目标状态
- `error_type`: 错误类型 (invalid_transition/validation/execution)

#### 10. `io_lifecycle_state_current_count` (Gauge)
**描述**: 当前各状态的CI实例数量

**标签**:
- `tenant_id`: 租户ID
- `state_type`: 状态类型

**用途**: 实时监控工作负载分布

**告警规则示例**:
```yaml
# pending状态积压超过100告警
- alert: HighPendingCount
  expr: io_lifecycle_state_current_count{state_type="pending"} > 100
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Pending状态CI积压严重"
    description: "当前pending数量: {{ $value }}"
```

#### 11. `io_lifecycle_state_timeouts_total` (Counter)
**描述**: CI生命周期状态超时总数

**标签**:
- `tenant_id`: 租户ID
- `state_type`: 状态类型

#### 12. `io_lifecycle_state_retries_total` (Counter)
**描述**: CI生命周期状态重试总数

**标签**:
- `tenant_id`: 租户ID
- `state_type`: 状态类型

#### 13. `io_lifecycle_state_cancels_total` (Counter)
**描述**: CI生命周期状态取消总数

**标签**:
- `tenant_id`: 租户ID
- `state_type`: 状态类型

---

### 性能指标

#### 14. `io_database_query_duration_seconds` (Histogram)
**描述**: 数据库查询耗时分布

**标签**:
- `tenant_id`: 租户ID
- `operation`: 操作类型 (select/insert/update/delete)
- `table`: 表名

**Buckets**: [0.001, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1]秒

#### 15. `io_cache_hit_ratio` (Gauge)
**描述**: 缓存命中率 (0-1)

**标签**:
- `tenant_id`: 租户ID
- `cache_type`: 缓存类型

#### 16. `io_active_operations_count` (Gauge)
**描述**: 当前活跃操作数量

**标签**:
- `tenant_id`: 租户ID
- `operation_type`: 操作类型

---

### 系统指标

#### 17. `io_component_health_status` (Gauge)
**描述**: 组件健康状态 (1=healthy, 0=unhealthy)

**标签**:
- `component`: 组件名称 (database/redis/core_rpc/cmdb_rpc/ops_rpc)

**告警规则示例**:
```yaml
# 组件不健康告警
- alert: ComponentUnhealthy
  expr: io_component_health_status == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "组件{{ $labels.component }}不健康"
```

---

## 业务代码集成

### 1. ChangeRecorder集成示例

在 `component_impls.go` 的 `RecordCreate` / `RecordUpdate` / `RecordDelete` 方法中添加metrics收集:

```go
func (c *changeRecorderImpl) RecordCreate(ctx context.Context, operation *CiOperationContext, result *CiOperationResult) (*ChangeRecord, error) {
    startTime := time.Now()

    // ... 现有的变更记录逻辑 ...

    dbRecord, err := builder.Save(ctx)

    // 🎯 记录Prometheus指标
    tenantID := fmt.Sprintf("%d", operation.TenantID)
    duration := time.Since(startTime).Seconds()

    if err != nil {
        // 记录失败指标
        c.svcCtx.MetricsCollector.RecordChangeOperation(tenantID, "create", "failure", duration)
        c.svcCtx.MetricsCollector.RecordChangeError(tenantID, "create", "database")
        return nil, err
    }

    // 记录成功指标
    c.svcCtx.MetricsCollector.RecordChangeOperation(tenantID, "create", "success", duration)

    return record, nil
}
```

### 2. StateManager集成示例

在 `component_impls.go` 的 `UpdateState` 方法中添加metrics收集:

```go
func (l *lifecycleManagerImpl) UpdateState(ctx context.Context, stateID string, newStage LifecycleStage) (*LifecycleState, error) {
    startTime := time.Now()

    // 1. 查询当前状态
    currentState, err := l.svcCtx.DB.CiLifecycleState.Query().
        Where(cilifecyclestate.StateIDEQ(stateID), cilifecyclestate.IsCurrentEQ(true)).
        First(ctx)

    if err != nil {
        return nil, err
    }

    currentStage := LifecycleStage(currentState.StateType)
    tenantID := fmt.Sprintf("%d", currentState.TenantID)

    // 2. 检查状态转换是否合法
    allowed, err := l.CheckStateTransition(ctx, currentStage, newStage)
    if !allowed {
        // 🎯 记录非法转换错误
        l.svcCtx.MetricsCollector.RecordStateTransition(tenantID, string(currentStage), string(newStage), "failure")
        l.svcCtx.MetricsCollector.RecordStateError(tenantID, string(currentStage), string(newStage), "invalid_transition")
        return nil, fmt.Errorf("不允许从 %s 转换到 %s", currentStage, newStage)
    }

    // 3. 执行状态转换
    // ... 状态更新逻辑 ...

    // 4. 记录状态持续时间
    duration := time.Since(*currentState.EnteredAt).Seconds()
    l.svcCtx.MetricsCollector.RecordStateDuration(tenantID, currentState.StateType, duration)

    // 5. 记录状态转换成功
    l.svcCtx.MetricsCollector.RecordStateTransition(tenantID, string(currentStage), string(newStage), "success")

    return result, nil
}
```

### 3. 定时更新当前状态计数

在 `ServiceContext` 初始化后启动一个goroutine定期更新状态计数:

```go
// 在 service_context.go 的 NewServiceContext 函数末尾添加
go func() {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()

    for range ticker.C {
        // 查询各状态的CI数量
        ctx := context.Background()

        // 为每个租户统计各状态的CI数量
        tenants := []uint64{1} // TODO: 动态获取租户列表

        for _, tenantID := range tenants {
            for _, state := range []string{"draft", "submitted", "validated", "approved", "executed", "completed", "cancelled", "expired"} {
                count, _ := db.CiLifecycleState.Query().
                    Where(
                        cilifecyclestate.TenantIDEQ(tenantID),
                        cilifecyclestate.StateTypeEQ(state),
                        cilifecyclestate.IsCurrentEQ(true),
                    ).
                    Count(ctx)

                metricsCollector.UpdateCurrentStateCounts(fmt.Sprintf("%d", tenantID), state, float64(count))
            }
        }
    }
}()
```

---

## Prometheus配置

### scrape_configs示例

在Prometheus配置文件 (`prometheus.yml`) 中添加scrape配置:

```yaml
scrape_configs:
  - job_name: 'unified-io'
    static_configs:
      - targets: ['unified-io:4005']
    scrape_interval: 15s
    scrape_timeout: 10s
    metrics_path: /metrics
    scheme: http
```

### 告警规则文件

创建 `alerts/unified_io.yml`:

```yaml
groups:
  - name: unified_io_alerts
    interval: 30s
    rules:
      # 变更失败率告警
      - alert: HighChangeFailureRate
        expr: |
          (sum by (tenant_id) (rate(io_change_history_operations_total{status="failure"}[5m]))
          /
          sum by (tenant_id) (rate(io_change_history_operations_total[5m])))
          > 0.1
        for: 5m
        labels:
          severity: warning
          service: unified-io
        annotations:
          summary: "租户{{ $labels.tenant_id }}变更失败率过高"
          description: "当前失败率: {{ $value | humanizePercentage }}"

      # 状态转换失败率告警
      - alert: HighStateTransitionFailureRate
        expr: |
          (sum by (tenant_id, from_state, to_state)
            (rate(io_lifecycle_state_transitions_total{status="failure"}[5m]))
          /
          sum by (tenant_id, from_state, to_state)
            (rate(io_lifecycle_state_transitions_total[5m])))
          > 0.05
        for: 10m
        labels:
          severity: critical
          service: unified-io
        annotations:
          summary: "状态转换{{ $labels.from_state }}→{{ $labels.to_state }}失败率过高"

      # CI积压告警
      - alert: HighPendingCount
        expr: io_lifecycle_state_current_count{state_type="submitted"} > 100
        for: 5m
        labels:
          severity: warning
          service: unified-io
        annotations:
          summary: "Submitted状态CI积压严重"
          description: "当前积压数量: {{ $value }}"

      # 组件健康告警
      - alert: ComponentUnhealthy
        expr: io_component_health_status == 0
        for: 1m
        labels:
          severity: critical
          service: unified-io
        annotations:
          summary: "组件{{ $labels.component }}不健康"

      # 响应时间告警
      - alert: SlowChangeOperations
        expr: |
          histogram_quantile(0.99,
            rate(io_change_history_operation_duration_seconds_bucket[5m])
          ) > 5
        for: 10m
        labels:
          severity: warning
          service: unified-io
        annotations:
          summary: "变更操作响应缓慢"
          description: "P99耗时: {{ $value | humanizeDuration }}"
```

---

## Grafana仪表板

### 仪表板JSON模板

创建Grafana仪表板监控关键指标:

```json
{
  "dashboard": {
    "title": "Unified-IO CI监控",
    "panels": [
      {
        "title": "变更操作QPS",
        "targets": [
          {
            "expr": "sum by (operation_type, status) (rate(io_change_history_operations_total[1m]))"
          }
        ],
        "type": "graph"
      },
      {
        "title": "状态转换流向",
        "targets": [
          {
            "expr": "sum by (from_state, to_state) (rate(io_lifecycle_state_transitions_total[5m]))"
          }
        ],
        "type": "sankey"
      },
      {
        "title": "当前状态分布",
        "targets": [
          {
            "expr": "sum by (state_type) (io_lifecycle_state_current_count)"
          }
        ],
        "type": "pie"
      },
      {
        "title": "操作耗时P99",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, rate(io_change_history_operation_duration_seconds_bucket[5m]))"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
```

---

## 验证和测试

### 1. 验证Prometheus服务器启动

```bash
# 检查metrics端点
curl http://localhost:4005/metrics | grep io_change_history

# 检查健康状态
curl http://localhost:4005/health
```

### 2. 验证指标收集

执行一些变更操作后,查询metrics端点:

```bash
curl -s http://localhost:4005/metrics | grep -E "io_change_history|io_lifecycle_state"
```

**预期输出示例**:
```
io_change_history_operations_total{tenant_id="1",operation_type="create",status="success"} 42
io_change_history_operation_duration_seconds_bucket{tenant_id="1",operation_type="create",le="0.1"} 40
io_lifecycle_state_transitions_total{tenant_id="1",from_state="draft",to_state="submitted",status="success"} 15
io_lifecycle_state_current_count{tenant_id="1",state_type="submitted"} 8
```

### 3. 验证Prometheus抓取

在Prometheus UI中查询指标:

```promql
# 查看变更操作速率
rate(io_change_history_operations_total[5m])

# 查看状态转换成功率
sum by (from_state, to_state) (rate(io_lifecycle_state_transitions_total{status="success"}[5m]))

# 查看当前状态分布
io_lifecycle_state_current_count
```

---

## 性能影响

### 预期性能开销

- **CPU开销**: < 1% (metrics收集和聚合)
- **内存开销**: < 50MB (metrics存储)
- **网络开销**: < 1KB/s (metrics暴露)

### 优化建议

1. **标签基数控制**: 避免在标签中使用高基数字段(如IP地址、UUID)
2. **Histogram桶设计**: 根据实际业务场景调整桶边界
3. **采样策略**: 对高频操作可考虑采样收集(如只记录10%的操作)

---

## 故障排查

### 问题1: Prometheus服务器无法启动

**症状**: 日志显示 `Failed to start Prometheus server`

**原因**: 端口4005已被占用

**解决**:
```bash
# 检查端口占用
sudo lsof -i :4005

# 修改io.yaml中的Prometheus.Port配置
```

### 问题2: Metrics端点返回空

**症状**: `curl http://localhost:4005/metrics` 无任何指标

**原因**: MetricsCollector未正确初始化

**解决**: 检查ServiceContext中PrometheusServer和MetricsCollector的初始化逻辑

### 问题3: 部分指标缺失

**症状**: 只能看到部分指标,缺少lifecycle相关指标

**原因**: 业务代码中未调用metrics收集方法

**解决**: 在StateManager的UpdateState方法中添加metrics收集调用

---

## 后续改进

### Phase 1 完成 ✅
- ✅ 指标定义和收集器实现
- ✅ Prometheus HTTP服务器
- ✅ ServiceContext集成
- ✅ 配置文件更新

### Phase 2 待实现 ⏳
- ⏳ 业务代码完整集成 (ChangeRecorder, StateManager)
- ⏳ 定时任务更新状态计数
- ⏳ 缓存命中率统计

### Phase 3 待实现 ⏳
- ⏳ Grafana仪表板创建
- ⏳ 告警规则完善
- ⏳ 自动化测试

---

## 相关文件

### 实现文件
- `/opt/code/newbee/unified-io/rpc/internal/config/config.go` - Prometheus配置
- `/opt/code/newbee/unified-io/rpc/internal/monitoring/metrics.go` - 指标定义
- `/opt/code/newbee/unified-io/rpc/internal/monitoring/server.go` - Prometheus服务器
- `/opt/code/newbee/unified-io/rpc/internal/svc/service_context.go` - ServiceContext集成
- `/opt/code/newbee/unified-io/rpc/etc/io.yaml` - 配置文件

### 业务集成点
- `/opt/code/newbee/unified-io/rpc/internal/core/component_impls.go` - ChangeRecorder和StateManager集成点

---

**文档版本**: 1.0
**最后更新**: 2025-12-26
**维护者**: Claude Code
