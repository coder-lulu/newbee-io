# IO服务菜单初始化总结

**生成时间**: 2025-12-16
**服务名称**: unified-io
**SQL文件**: `/opt/code/newbee/unified-io/migrations/io_menus.sql`

---

## 一、执行结果

✅ **执行成功** - 所有菜单已成功插入数据库

### 菜单统计
- **菜单页面 (menu_type=1)**: 9个
- **权限按钮 (menu_type=2)**: 51个
- **总计**: 60条菜单记录

---

## 二、菜单层级结构

```
输入输出 (ID: 201) - 父目录
├── 输入任务 (ID: 202) - 已存在
│   ├── 查询输入任务 (255)
│   ├── 创建输入任务 (256)
│   ├── 更新输入任务 (257)
│   ├── 删除输入任务 (258)
│   ├── 启动输入任务 (259)
│   ├── 暂停输入任务 (260)
│   ├── 取消输入任务 (261)
│   └── 审核输入任务 (262)
│
├── 输出任务 (ID: 203) - 新增
│   ├── 查询输出任务 (204)
│   ├── 创建输出任务 (205)
│   ├── 更新输出任务 (206)
│   ├── 删除输出任务 (207)
│   ├── 启动输出任务 (208)
│   ├── 暂停输出任务 (209)
│   └── 取消输出任务 (210)
│
├── 发现池管理 (ID: 211) - 新增
│   ├── 查询发现池 (212)
│   ├── 创建发现池 (213)
│   ├── 更新发现池 (214)
│   ├── 删除发现池 (215)
│   ├── 启用发现池 (216)
│   ├── 禁用发现池 (217)
│   ├── 手动触发 (218)
│   ├── 查看统计 (219)
│   └── 审核发现池 (220)
│
├── 发现模板 (ID: 221) - 新增
│   ├── 查询模板 (222)
│   ├── 创建模板 (223)
│   ├── 更新模板 (224)
│   ├── 删除模板 (225)
│   └── 查看发现模板详情 (226)
│
├── Provider管理 (ID: 227) - 新增
│   ├── 查询Provider (228)
│   ├── 获取Schema (229)
│   └── 测试连接 (230)
│
├── 数据目标 (ID: 231) - 新增
│   ├── 查询目标 (232)
│   ├── 创建目标 (233)
│   ├── 更新目标 (234)
│   ├── 删除目标 (235)
│   └── 查看数据目标详情 (236)
│
├── 字段映射 (ID: 237) - 新增
│   ├── 查询映射 (238)
│   ├── 创建映射 (239)
│   ├── 更新映射 (240)
│   ├── 删除映射 (241)
│   └── 查看字段映射详情 (242)
│
├── 任务日志 (ID: 243) - 新增
│   ├── 查询日志 (244)
│   ├── 查看任务日志详情 (245)
│   └── 删除日志 (246)
│
├── 映射日志 (ID: 247) - 新增
│   ├── 查询日志 (248)
│   ├── 查看映射日志详情 (249)
│   └── 删除日志 (250)
│
└── Worker监控 (ID: 251) - 新增
    ├── 查询指标 (252)
    ├── 上报指标 (253)
    └── 查看Worker监控详情 (254)
```

---

## 三、API接口与菜单映射

### 3.1 输入任务 (Input Task)
| 接口路径 | 方法 | 菜单权限ID | 权限名称 |
|---------|------|-----------|---------|
| `/io/input_task/list` | POST | 255 | 查询输入任务 |
| `/io/input_task/create` | POST | 256 | 创建输入任务 |
| `/io/input_task/update` | POST | 257 | 更新输入任务 |
| `/io/input_task/delete` | POST | 258 | 删除输入任务 |
| `/io/input_task/start` | POST | 259 | 启动输入任务 |
| `/io/input_task/pause` | POST | 260 | 暂停输入任务 |
| `/io/input_task/cancel` | POST | 261 | 取消输入任务 |
| `/io/input_task/approve` | POST | 262 | 审核输入任务 |

### 3.2 输出任务 (Output Task)
| 接口路径 | 方法 | 菜单权限ID | 权限名称 |
|---------|------|-----------|---------|
| `/io/output_task/list` | POST | 204 | 查询输出任务 |
| `/io/output_task/create` | POST | 205 | 创建输出任务 |
| `/io/output_task/update` | POST | 206 | 更新输出任务 |
| `/io/output_task/delete` | POST | 207 | 删除输出任务 |
| `/io/output_task/start` | POST | 208 | 启动输出任务 |
| `/io/output_task/pause` | POST | 209 | 暂停输出任务 |
| `/io/output_task/cancel` | POST | 210 | 取消输出任务 |

### 3.3 发现池管理 (Discovery Pool)
| 接口路径 | 方法 | 菜单权限ID | 权限名称 |
|---------|------|-----------|---------|
| `/io/discovery_pool/list` | POST | 212 | 查询发现池 |
| `/io/discovery_pool/create` | POST | 213 | 创建发现池 |
| `/io/discovery_pool/update` | POST | 214 | 更新发现池 |
| `/io/discovery_pool/delete` | POST | 215 | 删除发现池 |
| `/io/discovery_pool/enable` | POST | 216 | 启用发现池 |
| `/io/discovery_pool/disable` | POST | 217 | 禁用发现池 |
| `/io/discovery_pool/trigger` | POST | 218 | 手动触发发现池 |
| `/io/discovery_pool/stats/:id` | GET | 219 | 获取发现池统计信息 |
| `/io/discovery_pool/approve` | POST | 220 | 审核发现池 |

### 3.4 发现模板 (Discovery Template)
| 接口路径 | 方法 | 菜单权限ID | 权限名称 |
|---------|------|-----------|---------|
| `/io/discovery_template/list` | POST | 222 | 查询发现模板 |
| `/io/discovery_template/create` | POST | 223 | 创建发现模板 |
| `/io/discovery_template/update` | POST | 224 | 更新发现模板 |
| `/io/discovery_template/delete` | POST | 225 | 删除发现模板 |
| `/io/discovery_template/info` | POST | 226 | 查看发现模板详情 |

### 3.5 发现Provider (Discovery Provider)
| 接口路径 | 方法 | 菜单权限ID | 权限名称 |
|---------|------|-----------|---------|
| `/io/discoveryprovider/list_discovery_providers` | POST | 228 | 查询Provider列表 |
| `/io/discoveryprovider/get_provider_schema` | POST | 229 | 获取Provider Schema |
| `/io/discoveryprovider/test_provider_connection` | POST | 230 | 测试Provider连接 |

### 3.6 数据目标 (Data Target)
| 接口路径 | 方法 | 菜单权限ID | 权限名称 |
|---------|------|-----------|---------|
| `/io/data_target/list` | POST | 232 | 查询数据目标 |
| `/io/data_target/create` | POST | 233 | 创建数据目标 |
| `/io/data_target/update` | POST | 234 | 更新数据目标 |
| `/io/data_target/delete` | POST | 235 | 删除数据目标 |
| `/io/data_target/info` | POST | 236 | 查看数据目标详情 |

### 3.7 字段映射 (Field Mapping)
| 接口路径 | 方法 | 菜单权限ID | 权限名称 |
|---------|------|-----------|---------|
| `/io/field_mapping/list` | GET | 238 | 查询字段映射 |
| `/io/field_mapping/create` | POST | 239 | 创建字段映射 |
| `/io/field_mapping/update` | POST | 240 | 更新字段映射 |
| `/io/field_mapping/delete` | POST | 241 | 删除字段映射 |
| `/io/field_mapping/:id` | GET | 242 | 查看字段映射详情 |

### 3.8 任务日志 (Task Log)
| 接口路径 | 方法 | 菜单权限ID | 权限名称 |
|---------|------|-----------|---------|
| `/io/task_log/list` | GET | 244 | 查询任务日志 |
| `/io/task_log/:id` | GET | 245 | 查看任务日志详情 |
| `/io/task_log/delete` | POST | 246 | 删除任务日志 |

### 3.9 映射日志 (Mapping Log)
| 接口路径 | 方法 | 菜单权限ID | 权限名称 |
|---------|------|-----------|---------|
| `/io/mapping_log/list` | GET | 248 | 查询映射日志 |
| `/io/mapping_log/:id` | GET | 249 | 查看映射日志详情 |
| `/io/mapping_log/delete` | POST | 250 | 删除映射日志 |

### 3.10 Worker监控 (Worker Metrics)
| 接口路径 | 方法 | 菜单权限ID | 权限名称 |
|---------|------|-----------|---------|
| `/io/worker_metrics/list` | POST | 252 | 查询Worker指标 |
| `/io/worker_metrics/create` | POST | 253 | 上报Worker指标 |
| `/io/worker_metrics/info` | POST | 254 | 查看Worker监控详情 |

---

## 四、菜单配置说明

### 4.1 菜单字段说明
- **id**: 菜单唯一ID（203-262）
- **parent_id**: 父菜单ID（201为输入输出模块）
- **menu_level**: 菜单层级（2为主菜单，3为权限按钮）
- **menu_type**: 菜单类型（0=目录，1=菜单页面，2=按钮权限）
- **service_name**: 服务名称（unified-io）
- **tenant_id**: 租户ID（默认为1）

### 4.2 前端路由配置
所有菜单页面的前端组件路径格式：
- **输入任务**: `io/input-task/index`
- **输出任务**: `io/output-task/index`
- **发现池**: `io/discovery-pool/index`
- **发现模板**: `io/discovery-template/index`
- **Provider**: `io/discovery-provider/index`
- **数据目标**: `io/data-target/index`
- **字段映射**: `io/field-mapping/index`
- **任务日志**: `io/task-log/index`
- **映射日志**: `io/mapping-log/index`
- **Worker监控**: `io/worker-metrics/index`

### 4.3 图标配置
菜单使用的Ant Design图标：
- 输入任务: `ant-design:import-outlined`
- 输出任务: `ant-design:export-outlined`
- 发现池: `ant-design:cluster-outlined`
- 发现模板: `ant-design:file-text-outlined`
- Provider: `ant-design:api-outlined`
- 数据目标: `ant-design:database-outlined`
- 字段映射: `ant-design:swap-outlined`
- 任务日志: `ant-design:file-search-outlined`
- 映射日志: `ant-design:audit-outlined`
- Worker监控: `ant-design:dashboard-outlined`

---

## 五、后续工作

### 5.1 前端开发
需要在前端项目中创建对应的页面组件：
```
frontend/src/views/io/
├── input-task/
│   └── index.vue
├── output-task/
│   └── index.vue
├── discovery-pool/
│   └── index.vue
├── discovery-template/
│   └── index.vue
├── discovery-provider/
│   └── index.vue
├── data-target/
│   └── index.vue
├── field-mapping/
│   └── index.vue
├── task-log/
│   └── index.vue
├── mapping-log/
│   └── index.vue
└── worker-metrics/
    └── index.vue
```

### 5.2 权限配置
为管理员角色（tenant_id=1）分配这些菜单权限：
```sql
-- 为管理员角色分配IO服务菜单权限
INSERT INTO sys_role_menus (role_id, menu_id, tenant_id)
SELECT
    (SELECT id FROM sys_roles WHERE code = 'admin' AND tenant_id = 1) as role_id,
    id as menu_id,
    1 as tenant_id
FROM sys_menus
WHERE service_name = 'unified-io' AND tenant_id = 1;
```

### 5.3 Casbin规则配置
需要为API接口配置Casbin权限规则，将菜单权限与API接口关联起来。

---

## 六、验证命令

### 6.1 查询菜单数量
```sql
SELECT COUNT(*) as total_menus, menu_type, service_name
FROM sys_menus
WHERE service_name = 'unified-io' AND tenant_id = 1
GROUP BY menu_type, service_name;
```

### 6.2 查看菜单树
```sql
SELECT id, parent_id, name, title, path, menu_type
FROM sys_menus
WHERE parent_id = 201 AND tenant_id = 1
ORDER BY sort;
```

### 6.3 查看某个模块的权限按钮
```sql
-- 示例：查看发现池的权限按钮
SELECT id, parent_id, name, title
FROM sys_menus
WHERE parent_id = 211 AND tenant_id = 1
ORDER BY sort;
```

---

## 七、注意事项

1. **菜单唯一性约束**:
   - `idx_menu_name_type` - (name, menu_type, tenant_id) 必须唯一
   - `menu_path_tenant_id` - (path, tenant_id) 必须唯一

2. **权限按钮命名规范**:
   - 必须具有明确的业务含义
   - 同一tenant下不同模块的权限按钮名称需要区分（如"查看任务日志详情" vs "查看映射日志详情"）

3. **服务标识**:
   - 所有菜单的 `service_name` 字段统一设置为 `unified-io`
   - 便于后续按服务维度进行菜单管理

4. **多租户支持**:
   - 当前SQL仅为tenant_id=1（默认租户）创建菜单
   - 其他租户需要单独执行SQL或通过系统初始化流程创建

---

**文档生成时间**: 2025-12-16
**维护人**: NewBee Team
