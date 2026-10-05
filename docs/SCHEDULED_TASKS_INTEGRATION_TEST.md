# Scheduled Tasks 集成测试计划

## 测试目标

验证 unified-io 服务中的定时任务功能在生产环境中的完整工作流程，包括：
- API 创建定时任务
- TaskWorker 自动调度执行
- 任务状态正确更新
- 多租户隔离
- 错误处理和边界条件

## 测试环境

### 环境要求
- MySQL/PostgreSQL 数据库
- Redis（如果需要）
- unified-io RPC 服务运行中
- 测试客户端工具（grpcurl 或自定义客户端）

### 配置检查
```yaml
# etc/io.yaml 配置确认
DatabaseConf:
  Type: mysql
  Host: localhost:3306
  DBName: newbee_io

TaskWorker:
  Enabled: true
  PullInterval: 10s  # 手动任务检查间隔
  MaxConcurrent: 5   # 最大并发数
  BatchSize: 10      # 每次拉取数量
```

## 测试用例

### TC-001: 基础定时任务创建和执行

**测试目的**: 验证定时任务从创建到执行的完整流程

**前置条件**:
- unified-io RPC 服务已启动
- TaskWorker 正在运行
- 数据库连接正常

**测试步骤**:

1. 创建一个 2 分钟后执行的定时任务
```bash
# 计算未来时间戳（2分钟后）
SCHEDULED_TIME=$(date -d "+2 minutes" +%s)000

# 使用 grpcurl 创建任务
grpcurl -plaintext \
  -d '{
    "taskName": "集成测试-定时任务",
    "taskType": "scheduled",
    "scheduledAt": '$SCHEDULED_TIME',
    "inputSource": "test_source",
    "sourceConfig": "{\"test\": true}",
    "taskStatus": "pending",
    "tenantId": 1
  }' \
  localhost:9102 io.Io/CreateInputTask
```

2. 记录返回的 task_id

3. 查询任务状态（应为 pending）
```bash
grpcurl -plaintext \
  -d '{"id": <task_id>}' \
  localhost:9102 io.Io/GetInputTaskById
```

4. 等待 2-3 分钟

5. 再次查询任务状态（应为 completed）

**预期结果**:
- ✅ 任务创建成功，返回 task_id
- ✅ 初始状态为 `pending`
- ✅ 2分钟后任务自动执行
- ✅ 最终状态为 `completed`
- ✅ `started_at` 和 `completed_at` 字段已填充

**验证查询**:
```sql
SELECT
    id, task_name, task_type, task_status,
    scheduled_at, started_at, completed_at,
    TIMESTAMPDIFF(SECOND, scheduled_at, started_at) as delay_seconds
FROM io_input_tasks
WHERE id = <task_id>;
```

### TC-002: 验证参数验证

**测试目的**: 验证 API 层参数验证逻辑

**测试步骤**:

1. **测试缺少 scheduledAt**
```bash
grpcurl -plaintext \
  -d '{
    "taskName": "无scheduledAt的任务",
    "taskType": "scheduled",
    "inputSource": "test",
    "tenantId": 1
  }' \
  localhost:9102 io.Io/CreateInputTask
```
**预期**: 返回错误 "scheduled任务必须提供ScheduledAt时间"

2. **测试过去时间**
```bash
PAST_TIME=$(date -d "-1 hour" +%s)000

grpcurl -plaintext \
  -d '{
    "taskName": "过去时间任务",
    "taskType": "scheduled",
    "scheduledAt": '$PAST_TIME',
    "inputSource": "test",
    "tenantId": 1
  }' \
  localhost:9102 io.Io/CreateInputTask
```
**预期**: 返回错误 "ScheduledAt不能是过去的时间"

### TC-003: 任务类型隔离

**测试目的**: 验证 scheduled 任务不会被 processOnce() 处理

**测试步骤**:

1. 创建一个 5 分钟后执行的定时任务
```bash
SCHEDULED_TIME=$(date -d "+5 minutes" +%s)000

grpcurl -plaintext \
  -d '{
    "taskName": "未来定时任务",
    "taskType": "scheduled",
    "scheduledAt": '$SCHEDULED_TIME',
    "inputSource": "test",
    "tenantId": 1
  }' \
  localhost:9102 io.Io/CreateInputTask
```

2. 创建一个手动任务
```bash
grpcurl -plaintext \
  -d '{
    "taskName": "手动任务",
    "taskType": "manual",
    "inputSource": "test",
    "taskStatus": "pending",
    "tenantId": 1
  }' \
  localhost:9102 io.Io/CreateInputTask
```

3. 等待 30 秒，查看日志

**预期结果**:
- ✅ 手动任务在 10-20 秒内被 processOnce() 处理
- ✅ 定时任务在 5 分钟内保持 pending 状态
- ✅ 日志显示 processOnce() 只拉取了手动任务

**日志验证**:
```bash
# 查看 TaskWorker 日志
tail -f /path/to/unified-io.log | grep -E "Pulled pending tasks|Pulled scheduled tasks"
```

期望看到:
```json
{"content":"Pulled pending tasks (manual/triggered)","count":1}
{"content":"Pulled scheduled tasks","count":0}
```

### TC-004: 并发限制测试

**测试目的**: 验证 MaxConcurrent 限制对定时任务生效

**测试步骤**:

1. 配置 `MaxConcurrent: 2`（重启服务）

2. 创建 5 个相同时间到期的定时任务
```bash
SCHEDULED_TIME=$(date -d "+1 minutes" +%s)000

for i in {1..5}; do
  grpcurl -plaintext \
    -d '{
      "taskName": "并发测试-'$i'",
      "taskType": "scheduled",
      "scheduledAt": '$SCHEDULED_TIME',
      "inputSource": "test",
      "tenantId": 1
    }' \
    localhost:9102 io.Io/CreateInputTask
done
```

3. 等待任务到期（1-2 分钟）

4. 观察日志中的 `current_processing` 计数

**预期结果**:
- ✅ 第一批只有 2 个任务同时执行（MaxConcurrent=2）
- ✅ 剩余 3 个任务在第一批完成后陆续执行
- ✅ `current_processing` 永远不超过 2

**日志验证**:
```bash
tail -f unified-io.log | grep "current_processing"
```

### TC-005: 多租户隔离

**测试目的**: 验证不同租户的定时任务正确隔离

**测试步骤**:

1. 为租户 1 创建定时任务
```bash
SCHEDULED_TIME=$(date -d "+1 minutes" +%s)000

grpcurl -plaintext \
  -d '{
    "taskName": "租户1任务",
    "taskType": "scheduled",
    "scheduledAt": '$SCHEDULED_TIME',
    "inputSource": "test",
    "tenantId": 1
  }' \
  localhost:9102 io.Io/CreateInputTask
```

2. 为租户 2 创建定时任务
```bash
grpcurl -plaintext \
  -d '{
    "taskName": "租户2任务",
    "taskType": "scheduled",
    "scheduledAt": '$SCHEDULED_TIME',
    "inputSource": "test",
    "tenantId": 2
  }' \
  localhost:9102 io.Io/CreateInputTask
```

3. 等待任务执行

4. 验证两个租户的任务都正常执行

**预期结果**:
- ✅ 两个租户的任务都被 processScheduledTasks() 拉取（使用 SystemContext）
- ✅ 任务执行时正确关联到各自的租户
- ✅ 租户间数据完全隔离

**验证查询**:
```sql
SELECT tenant_id, task_name, task_status, started_at
FROM io_input_tasks
WHERE task_type = 'scheduled'
ORDER BY tenant_id, id;
```

### TC-006: 任务堆积场景

**测试目的**: 验证大量任务同时到期时的处理行为

**测试步骤**:

1. 创建 20 个相同时间到期的定时任务
```bash
SCHEDULED_TIME=$(date -d "+1 minutes" +%s)000

for i in {1..20}; do
  grpcurl -plaintext \
    -d '{
      "taskName": "堆积测试-'$i'",
      "taskType": "scheduled",
      "scheduledAt": '$SCHEDULED_TIME',
      "inputSource": "test",
      "tenantId": 1
    }' \
    localhost:9102 io.Io/CreateInputTask &
done
wait
```

2. 等待任务到期

3. 观察任务处理时间跨度

**预期结果**:
- ✅ 第一分钟拉取 BatchSize (10) 个任务
- ✅ 按 MaxConcurrent 限制并发执行
- ✅ 第二分钟拉取剩余 10 个任务
- ✅ 所有任务最终都成功执行

**性能指标**:
```sql
SELECT
    COUNT(*) as total_tasks,
    MIN(started_at) as first_start,
    MAX(completed_at) as last_complete,
    TIMESTAMPDIFF(SECOND, MIN(started_at), MAX(completed_at)) as total_duration_sec
FROM io_input_tasks
WHERE task_name LIKE '堆积测试-%';
```

### TC-007: 错误任务处理

**测试目的**: 验证任务执行失败时的状态更新

**测试步骤**:

1. 创建一个会失败的定时任务（无效的 inputSource）
```bash
SCHEDULED_TIME=$(date -d "+1 minutes" +%s)000

grpcurl -plaintext \
  -d '{
    "taskName": "失败测试任务",
    "taskType": "scheduled",
    "scheduledAt": '$SCHEDULED_TIME',
    "inputSource": "invalid_source_will_fail",
    "tenantId": 1
  }' \
  localhost:9102 io.Io/CreateInputTask
```

2. 等待任务执行

3. 查询任务状态

**预期结果**:
- ✅ 任务状态更新为 `failed`
- ✅ `error_message` 字段记录错误信息
- ✅ `started_at` 已记录，`completed_at` 为空或记录失败时间

**验证查询**:
```sql
SELECT id, task_name, task_status, error_message, started_at, completed_at
FROM io_input_tasks
WHERE task_name = '失败测试任务';
```

## 监控验证

### 日志关键点检查

在测试过程中，应观察以下日志：

**1. 定时任务拉取**
```json
{
  "caller": "worker/task_worker.go:363",
  "content": "Pulled scheduled tasks",
  "count": 3,
  "current_processing": 0,
  "level": "info"
}
```

**2. 任务开始执行**
```json
{
  "caller": "worker/task_worker.go:404",
  "content": "Processing task started",
  "task_id": 123,
  "task_name": "集成测试-定时任务",
  "task_type": "scheduled",
  "level": "info"
}
```

**3. 任务完成**
```json
{
  "caller": "worker/task_worker.go:481",
  "content": "Task completed successfully",
  "task_id": 123,
  "duration": "2.5s",
  "level": "info"
}
```

**4. 并发控制**
```json
{
  "caller": "worker/task_worker.go:357",
  "content": "Max concurrent tasks reached, skipping scheduled task pull",
  "current": 5,
  "max": 5,
  "level": "debug"
}
```

### 性能指标收集

```bash
# 统计不同状态的任务数
SELECT task_status, COUNT(*)
FROM io_input_tasks
WHERE task_type = 'scheduled'
GROUP BY task_status;

# 统计执行延迟（实际执行时间 vs 计划时间）
SELECT
    AVG(TIMESTAMPDIFF(SECOND, scheduled_at, started_at)) as avg_delay_sec,
    MIN(TIMESTAMPDIFF(SECOND, scheduled_at, started_at)) as min_delay_sec,
    MAX(TIMESTAMPDIFF(SECOND, scheduled_at, started_at)) as max_delay_sec
FROM io_input_tasks
WHERE task_type = 'scheduled'
  AND started_at IS NOT NULL;

# 统计任务执行时长
SELECT
    AVG(TIMESTAMPDIFF(SECOND, started_at, completed_at)) as avg_duration_sec,
    MAX(TIMESTAMPDIFF(SECOND, started_at, completed_at)) as max_duration_sec
FROM io_input_tasks
WHERE task_type = 'scheduled'
  AND task_status = 'completed';
```

## 测试清理

测试完成后，清理测试数据：

```sql
-- 删除测试任务
DELETE FROM io_input_tasks
WHERE task_name LIKE '集成测试-%'
   OR task_name LIKE '并发测试-%'
   OR task_name LIKE '堆积测试-%'
   OR task_name LIKE '%测试任务%';

-- 验证清理
SELECT COUNT(*) FROM io_input_tasks WHERE task_name LIKE '%测试%';
```

## 通过标准

所有测试用例必须满足以下条件才算通过：

- ✅ **TC-001**: 定时任务在指定时间执行，延迟 < 60 秒
- ✅ **TC-002**: 所有参数验证正确返回错误
- ✅ **TC-003**: 任务类型完全隔离，无交叉处理
- ✅ **TC-004**: MaxConcurrent 限制严格生效
- ✅ **TC-005**: 多租户数据完全隔离
- ✅ **TC-006**: 批量任务无丢失，全部执行
- ✅ **TC-007**: 失败任务状态正确更新

## 故障排查

### 问题：定时任务未执行

**排查步骤**:
1. 检查 TaskWorker 是否启动: `ps aux | grep unified-io`
2. 检查配置: `cat etc/io.yaml | grep -A5 TaskWorker`
3. 查看日志: `tail -100 unified-io.log | grep TaskWorker`
4. 检查数据库: `SELECT * FROM io_input_tasks WHERE task_type='scheduled' AND task_status='pending';`

### 问题：任务执行延迟过大

**排查步骤**:
1. 检查并发配置是否过小
2. 查看是否有大量任务堆积
3. 检查数据库性能
4. 查看系统资源使用情况

## 自动化测试脚本

创建自动化测试脚本 `/opt/code/newbee/unified-io/test/integration/test_scheduled_tasks.sh`:

```bash
#!/bin/bash

set -e

echo "=== Scheduled Tasks Integration Test ==="
echo ""

# 配置
RPC_HOST="localhost:9102"
TENANT_ID=1

# 辅助函数
create_scheduled_task() {
    local task_name=$1
    local minutes_ahead=$2
    local scheduled_time=$(date -d "+${minutes_ahead} minutes" +%s)000

    grpcurl -plaintext \
      -d '{
        "taskName": "'$task_name'",
        "taskType": "scheduled",
        "scheduledAt": '$scheduled_time',
        "inputSource": "test_source",
        "sourceConfig": "{\"test\": true}",
        "taskStatus": "pending",
        "tenantId": '$TENANT_ID'
      }' \
      $RPC_HOST io.Io/CreateInputTask
}

get_task_status() {
    local task_id=$1
    grpcurl -plaintext \
      -d '{"id": '$task_id'}' \
      $RPC_HOST io.Io/GetInputTaskById
}

echo "Test 1: Create scheduled task..."
RESULT=$(create_scheduled_task "auto-test-scheduled-1" 2)
TASK_ID=$(echo $RESULT | jq -r '.id')
echo "Created task ID: $TASK_ID"

echo ""
echo "Test 2: Verify initial status is pending..."
STATUS=$(get_task_status $TASK_ID | jq -r '.taskStatus')
if [ "$STATUS" == "pending" ]; then
    echo "✅ Status is pending"
else
    echo "❌ Expected pending, got: $STATUS"
    exit 1
fi

echo ""
echo "Test 3: Wait for task execution (130 seconds)..."
sleep 130

echo ""
echo "Test 4: Verify task is completed..."
STATUS=$(get_task_status $TASK_ID | jq -r '.taskStatus')
if [ "$STATUS" == "completed" ]; then
    echo "✅ Task completed successfully"
else
    echo "❌ Expected completed, got: $STATUS"
    exit 1
fi

echo ""
echo "=== All tests passed! ==="
```

---

**最后更新**: 2025-12-24
**版本**: v1.0
**状态**: 待执行
