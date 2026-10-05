# 端到端测试：Unified-IO → CMDB 数据流

## 测试目标

验证从 Unified-IO 发现数据，经过转换后，成功写入 CMDB 的完整流程。

## 前置条件

### 1. 服务启动

```bash
# 启动 CMDB RPC 服务
cd /opt/code/newbee/cmdb/rpc
./rpc -f etc/cmdb.yaml

# 启动 Unified-IO RPC 服务
cd /opt/code/newbee/unified-io/rpc
./rpc -f etc/io.yaml
```

### 2. 数据库准备

确保以下表存在并且有基础数据：
- `cmdb_ci_types` - CI 类型定义
- `cmdb_ci_type_attributes` - CI 类型属性
- `cmdb_attributes` - 属性定义
- `io_discovery_pools` - 发现池配置
- `io_field_mappings` - 字段映射规则
- `io_input_tasks` - 输入任务
- `io_output_tasks` - 输出任务

### 3. CMDB 配置检查

```bash
# 检查 CMDB RPC 端点
curl http://localhost:9300/health
```

### 4. Unified-IO 配置检查

```bash
# 检查 Unified-IO RPC 端点
curl http://localhost:9500/health

# 验证 CmdbRpc 配置
grep -A 3 "CmdbRpc:" /opt/code/newbee/unified-io/rpc/etc/io.yaml
```

## 测试场景 1：文件导入 → CMDB

### 步骤 1：准备测试数据文件

创建测试数据文件 `/tmp/test_servers.csv`:

```csv
hostname,ip_address,cpu_cores,memory_gb,os_type
server-01,192.168.1.10,16,64,Linux
server-02,192.168.1.11,8,32,Linux
server-03,192.168.1.12,32,128,Linux
```

### 步骤 2：创建 CI 类型（在 CMDB 中）

```sql
-- 创建服务器 CI 类型
INSERT INTO cmdb_ci_types (id, name, code, description, status, tenant_id)
VALUES (1, 'Linux服务器', 'linux_server', '测试用服务器类型', 1, 1);

-- 创建属性定义
INSERT INTO cmdb_attributes (id, name, alias, value_type, status)
VALUES
  (1, 'hostname', '主机名', 'string', 1),
  (2, 'ip_address', 'IP地址', 'string', 1),
  (3, 'cpu_cores', 'CPU核数', 'integer', 1),
  (4, 'memory_gb', '内存(GB)', 'integer', 1),
  (5, 'os_type', '操作系统', 'string', 1);

-- 关联属性到 CI 类型
INSERT INTO cmdb_ci_type_attributes (type_id, attribute_id, is_required, status)
VALUES
  (1, 1, 1, 1),
  (1, 2, 1, 1),
  (1, 3, 0, 1),
  (1, 4, 0, 1),
  (1, 5, 0, 1);
```

### 步骤 3：创建输入任务

使用 gRPC 客户端（grpcurl）创建 InputTask:

```bash
grpcurl -plaintext -d '{
  "task_name": "Import Test Servers",
  "task_type": "file_import",
  "input_source": "file",
  "source_config": "{\"file_path\":\"/tmp/test_servers.csv\",\"file_type\":\"csv\"}",
  "task_status": "pending"
}' localhost:9500 io.Io/createInputTask
```

记录返回的任务 ID，例如：`{"id": 1}`

### 步骤 4：创建字段映射

```bash
# 映射 hostname
grpcurl -plaintext -d '{
  "input_task_id": 1,
  "source_field": "hostname",
  "target_field": "hostname",
  "target_data_type": "string",
  "transform_type": "direct",
  "is_required": true,
  "field_priority": 1,
  "is_active": true
}' localhost:9500 io.Io/createFieldMapping

# 映射 ip_address
grpcurl -plaintext -d '{
  "input_task_id": 1,
  "source_field": "ip_address",
  "target_field": "ip_address",
  "target_data_type": "string",
  "transform_type": "direct",
  "is_required": true,
  "field_priority": 2,
  "is_active": true
}' localhost:9500 io.Io/createFieldMapping

# 映射 cpu_cores
grpcurl -plaintext -d '{
  "input_task_id": 1,
  "source_field": "cpu_cores",
  "target_field": "cpu_cores",
  "target_data_type": "integer",
  "transform_type": "int",
  "is_required": false,
  "field_priority": 3,
  "is_active": true
}' localhost:9500 io.Io/createFieldMapping

# 映射 memory_gb
grpcurl -plaintext -d '{
  "input_task_id": 1,
  "source_field": "memory_gb",
  "target_field": "memory_gb",
  "target_data_type": "integer",
  "transform_type": "int",
  "is_required": false,
  "field_priority": 4,
  "is_active": true
}' localhost:9500 io.Io/createFieldMapping

# 映射 os_type
grpcurl -plaintext -d '{
  "input_task_id": 1,
  "source_field": "os_type",
  "target_field": "os_type",
  "target_data_type": "string",
  "transform_type": "direct",
  "is_required": false,
  "field_priority": 5,
  "is_active": true
}' localhost:9500 io.Io/createFieldMapping
```

### 步骤 5：审批输入任务

```bash
grpcurl -plaintext -d '{
  "id": 1,
  "action": "approve"
}' localhost:9500 io.Io/approveInputTask
```

### 步骤 6：启动输入任务

```bash
grpcurl -plaintext -d '{
  "id": 1
}' localhost:9500 io.Io/startInputTask
```

### 步骤 7：等待任务完成，检查结果

```bash
# 查询任务状态
grpcurl -plaintext -d '{
  "id": 1
}' localhost:9500 io.Io/getInputTaskById

# 预期输出：
# {
#   "id": 1,
#   "task_status": "completed",
#   "total_records": 3,
#   "success_records": 3,
#   "failed_records": 0
# }
```

### 步骤 8：创建输出任务

```bash
grpcurl -plaintext -d '{
  "task_name": "Export to CMDB",
  "task_type": "manual",
  "output_target": "cmdb",
  "target_config": "{\"ci_type_id\":1,\"unique_key_field\":\"hostname\",\"auto_create\":true,\"auto_update\":true,\"conflict_resolution\":\"merge\"}",
  "task_status": "pending"
}' localhost:9500 io.Io/createOutputTask
```

记录返回的任务 ID，例如：`{"id": 1}`

### 步骤 9：关联字段映射到输出任务

```bash
# 更新字段映射，关联到 OutputTask
grpcurl -plaintext -d '{
  "id": 1,
  "output_task_id": 1
}' localhost:9500 io.Io/updateFieldMapping
# ... 对其他字段映射重复操作
```

### 步骤 10：审批输出任务

```bash
grpcurl -plaintext -d '{
  "id": 1,
  "action": "approve"
}' localhost:9500 io.Io/approveOutputTask
```

### 步骤 11：启动输出任务

```bash
grpcurl -plaintext -d '{
  "id": 1
}' localhost:9500 io.Io/startOutputTask
```

### 步骤 12：验证数据写入 CMDB

```sql
-- 查询 CMDB 中是否有新创建的 CI
SELECT * FROM cmdb_cis WHERE type_id = 1;

-- 查询 CI 属性值
SELECT c.id, c.metadata, vit.value as hostname, vit2.value as ip_address
FROM cmdb_cis c
LEFT JOIN cmdb_value_index_text vit ON vit.ci_id = c.id AND vit.attribute_id = 1
LEFT JOIN cmdb_value_index_text vit2 ON vit2.ci_id = c.id AND vit2.attribute_id = 2
WHERE c.type_id = 1;

-- 预期结果：3 条记录
-- CI metadata 应包含 unique_key、discovery_source、discovered_at
```

### 步骤 13：验证日志

```bash
# Unified-IO 日志
tail -100 /home/data/logs/io/rpc/info.log | grep "Output processing completed"

# CMDB 日志
tail -100 /home/data/logs/cmdb/rpc/info.log | grep "Successfully wrote CI"
```

## 测试场景 2：数据更新（增量同步）

### 修改测试数据文件

```csv
hostname,ip_address,cpu_cores,memory_gb,os_type
server-01,192.168.1.10,32,128,Linux  # 升级配置
server-02,192.168.1.11,8,32,Linux
server-04,192.168.1.13,16,64,Linux   # 新增服务器
```

### 重新执行导入流程

重复步骤 3-12，使用新的任务 ID。

### 验证结果

```sql
-- server-01 应该被更新（cpu_cores: 16→32, memory_gb: 64→128）
-- server-02 保持不变
-- server-03 不应被删除（因为 conflict_resolution="merge"）
-- server-04 应该被创建

SELECT * FROM cmdb_cis WHERE type_id = 1;
-- 预期：4 条记录
```

## 验证检查清单

### 功能验证
- [ ] InputTask 能正确读取文件数据
- [ ] FieldMapping 能正确转换数据类型
- [ ] Transform 引擎能正确应用转换规则
- [ ] OutputTask 能成功调用 CMDB RPC
- [ ] CMDB 能正确创建 CI 实例
- [ ] CMDB 能正确写入属性值
- [ ] unique_key 去重机制工作正常
- [ ] 数据更新（merge 策略）工作正常

### 错误处理验证
- [ ] 无效的 CI 类型 ID → 返回错误
- [ ] 缺少 unique_key → 跳过记录
- [ ] 字段映射失败 → 记录错误但继续
- [ ] CMDB RPC 超时 → 任务失败

### 性能验证
- [ ] 100 条记录 < 10 秒
- [ ] 1000 条记录 < 60 秒
- [ ] 内存占用稳定
- [ ] 无内存泄漏

## 故障排查

### 问题 1：OutputTask 一直处于 pending 状态
**可能原因**：
- TaskWorker 未启动
- 任务未审批

**解决方法**：
```bash
# 检查 TaskWorker 配置
grep -A 3 "TaskWorker:" /opt/code/newbee/unified-io/rpc/etc/io.yaml

# 审批任务
grpcurl -plaintext -d '{"id": 1, "action": "approve"}' localhost:9500 io.Io/approveOutputTask
```

### 问题 2：CMDB RPC 调用失败
**可能原因**：
- CMDB 服务未启动
- 网络不通
- 端口配置错误

**解决方法**：
```bash
# 测试 CMDB 连接
grpcurl -plaintext localhost:9300 list

# 检查配置
grep -A 3 "CmdbRpc:" /opt/code/newbee/unified-io/rpc/etc/io.yaml
```

### 问题 3：数据未写入 CMDB
**可能原因**：
- CI 类型 ID 不存在
- 属性定义不匹配
- 租户隔离问题

**解决方法**：
```sql
-- 验证 CI 类型存在
SELECT * FROM cmdb_ci_types WHERE id = 1;

-- 验证属性定义
SELECT * FROM cmdb_ci_type_attributes WHERE type_id = 1;

-- 检查租户 ID
SELECT tenant_id FROM cmdb_cis WHERE type_id = 1;
```

## 测试数据清理

```sql
-- 清理测试数据
DELETE FROM cmdb_value_index_text WHERE ci_id IN (SELECT id FROM cmdb_cis WHERE type_id = 1);
DELETE FROM cmdb_value_integer WHERE ci_id IN (SELECT id FROM cmdb_cis WHERE type_id = 1);
DELETE FROM cmdb_cis WHERE type_id = 1;
DELETE FROM io_field_mappings WHERE input_task_id IN (1, 2);
DELETE FROM io_output_tasks WHERE id IN (1, 2);
DELETE FROM io_input_tasks WHERE id IN (1, 2);
```

## 后续改进建议

1. **自动化测试脚本**：编写 Go 测试代码实现自动化验证
2. **性能监控**：添加 Prometheus 指标监控
3. **错误通知**：集成告警系统
4. **批量测试**：测试大量数据（10000+ 记录）
5. **并发测试**：测试多个任务同时执行

---

**测试完成标准**：
- 所有验证检查清单项目 ✅
- 无遗留错误日志
- CMDB 数据与源数据一致
- 性能指标达标
