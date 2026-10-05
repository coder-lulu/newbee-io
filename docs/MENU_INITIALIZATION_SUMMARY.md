# CI变更历史和生命周期状态菜单初始化总结

## 执行时间
2025-12-26

## 数据库连接信息
- **Host**: 192.168.26.130
- **Port**: 3306
- **Database**: newbee
- **Table**: sys_menus

## 执行结果 ✅ 成功

### 插入的菜单记录统计
- **总计**: 21条菜单记录
- **主菜单**: 2个（显示在侧边栏）
- **隐藏子页面**: 4个（用于详情和时间线）
- **权限按钮**: 15个（用于权限控制）

### 菜单ID分配

#### 主菜单（显示在侧边栏）
| ID | 名称 | 路径 | 图标 | Sort |
|----|------|------|------|------|
| 350 | CI变更历史 | change-history | lucide:history | 11 |
| 370 | CI生命周期 | lifecycle-state | lucide:git-branch | 12 |

#### 隐藏子页面（详情和时间线）
| ID | 名称 | 路径 | 父菜单ID |
|----|------|------|----------|
| 360 | 变更详情 | change-history/:id | 350 |
| 361 | 变更时间线 | change-history/timeline/:ciId | 350 |
| 380 | 生命周期详情 | lifecycle-state/:id | 370 |
| 381 | 生命周期时间线 | lifecycle-state/timeline/:ciId | 370 |

#### 权限按钮（CI变更历史）
| ID | 名称 | 权限标识 | 父菜单ID |
|----|------|----------|----------|
| 351 | 查询变更历史 | io:change_history:list | 350 |
| 352 | 查看变更详情 | io:change_history:info | 350 |
| 353 | 对比变更数据 | io:change_history:compare | 350 |
| 354 | 查看变更时间线 | io:change_history:timeline | 350 |
| 355 | 回滚变更 | io:change_history:rollback | 350 |
| 356 | 审批变更 | io:change_history:approve | 350 |
| 357 | 导出变更记录 | io:change_history:export | 350 |

#### 权限按钮（CI生命周期）
| ID | 名称 | 权限标识 | 父菜单ID |
|----|------|----------|----------|
| 371 | 查询生命周期状态 | io:lifecycle_state:list | 370 |
| 372 | 查看状态详情 | io:lifecycle_state:info | 370 |
| 373 | 查看状态时间线 | io:lifecycle_state:timeline | 370 |
| 374 | 执行状态转换 | io:lifecycle_state:transition | 370 |
| 375 | 重试失败状态 | io:lifecycle_state:retry | 370 |
| 376 | 取消执行中状态 | io:lifecycle_state:cancel | 370 |
| 377 | 检查超时状态 | io:lifecycle_state:check_timeout | 370 |
| 378 | 导出状态记录 | io:lifecycle_state:export | 370 |

## 菜单层级结构

```
输入输出 (201)
  ├── CI变更历史 (350) [主菜单，sort=11]
  │   ├── 变更详情 (360) [隐藏子页面]
  │   ├── 变更时间线 (361) [隐藏子页面]
  │   └── 权限按钮 (351-357) [7个按钮，隐藏]
  └── CI生命周期 (370) [主菜单，sort=12]
      ├── 生命周期详情 (380) [隐藏子页面]
      ├── 生命周期时间线 (381) [隐藏子页面]
      └── 权限按钮 (371-378) [8个按钮，隐藏]
```

## 前后端映射关系

| 后端组件 | 前端页面路径 | 菜单ID | 组件路径 |
|---------|-------------|--------|----------|
| ChangeRecorder | change-history | 350 | io/change-history/list.vue |
| ChangeRecorder | change-history/:id | 360 | io/change-history/detail.vue |
| ChangeRecorder | change-history/timeline/:ciId | 361 | io/change-history/timeline.vue |
| StateManager | lifecycle-state | 370 | io/lifecycle-state/list.vue |
| StateManager | lifecycle-state/:id | 380 | io/lifecycle-state/detail.vue |
| StateManager | lifecycle-state/timeline/:ciId | 381 | io/lifecycle-state/timeline.vue |

## 相关文件

### SQL脚本
- `/opt/code/newbee/unified-io/migrations/io_lifecycle_menus.sql` - 菜单初始化SQL脚本

### Go代码
- `/opt/code/newbee/unified-io/rpc/internal/logic/base/init_database_menu_data.go` - Go菜单初始化代码
- `/opt/code/newbee/unified-io/rpc/internal/logic/base/init_database_logic.go` - 数据库初始化入口

### 前端页面
- `/opt/code/newbee/ui/apps/web-antd/src/views/io/change-history/list.vue`
- `/opt/code/newbee/ui/apps/web-antd/src/views/io/change-history/detail.vue`
- `/opt/code/newbee/ui/apps/web-antd/src/views/io/change-history/timeline.vue`
- `/opt/code/newbee/ui/apps/web-antd/src/views/io/lifecycle-state/list.vue`
- `/opt/code/newbee/ui/apps/web-antd/src/views/io/lifecycle-state/detail.vue`
- `/opt/code/newbee/ui/apps/web-antd/src/views/io/lifecycle-state/timeline.vue`

## 执行命令

### 方式1：直接执行SQL（已完成）
```bash
mysql -h 192.168.26.130 -P 3306 -u root -p123456 newbee < /opt/code/newbee/unified-io/migrations/io_lifecycle_menus.sql
```

### 方式2：通过Go初始化（推荐用于首次部署）
```bash
# 调用InitDatabase RPC方法
grpcurl -plaintext localhost:9500 io.Io/InitDatabase
```

## 验证结果

### 数据库验证
```sql
-- 查看所有插入的菜单
SELECT id, name, path, service_name, parent_id, menu_type, sort
FROM sys_menus
WHERE id >= 350 AND id <= 381
ORDER BY id;

-- 验证主菜单显示设置
SELECT id, name, menu_type, hide_menu, icon
FROM sys_menus
WHERE id IN (350, 360, 361, 370, 380, 381)
ORDER BY id;
```

### 验证结果截图
```
✅ 所有21条记录成功插入
✅ 主菜单 hide_menu=0（显示）
✅ 子页面 hide_menu=1（隐藏）
✅ 图标正确设置
✅ 父子关系正确
✅ 权限标识完整
```

## 权限配置说明

### CI变更历史权限
- `io:change_history:list` - 查询变更历史列表
- `io:change_history:info` - 查看变更详情
- `io:change_history:compare` - 对比变更前后数据
- `io:change_history:timeline` - 查看CI的完整变更时间线
- `io:change_history:rollback` - 回滚删除的CI
- `io:change_history:approve` - 审批变更操作
- `io:change_history:export` - 导出变更记录

### CI生命周期状态权限
- `io:lifecycle_state:list` - 查询生命周期状态列表
- `io:lifecycle_state:info` - 查看状态详情
- `io:lifecycle_state:timeline` - 查看CI的状态流转时间线
- `io:lifecycle_state:transition` - 执行状态转换（遵循状态机规则）
- `io:lifecycle_state:retry` - 重试失败的状态
- `io:lifecycle_state:cancel` - 取消执行中的状态
- `io:lifecycle_state:check_timeout` - 检查和处理超时状态
- `io:lifecycle_state:export` - 导出状态记录

## 后续步骤

### 1. 权限分配
需要在Casbin中为角色分配相应的权限：
```go
// 示例：为管理员角色分配所有权限
casbin.AddPolicy("admin", "1", "/io/change_history/*", "*")
casbin.AddPolicy("admin", "1", "/io/lifecycle_state/*", "*")
```

### 2. API实现
需要实现对应的后端API接口（目前前端页面中标记为TODO）：
- ChangeHistory API - 变更历史查询、详情、时间线、回滚等
- LifecycleState API - 状态查询、详情、时间线、转换等

### 3. 前端集成测试
- 验证菜单正确显示在侧边栏
- 验证路由跳转正常
- 验证权限控制生效
- 验证详情页和时间线页面正常隐藏

## 注意事项

1. **ID范围**: 使用350-381范围，避免与现有菜单冲突
2. **租户ID**: 所有菜单设置为tenant_id=1（默认租户）
3. **服务名称**: 统一使用service_name='unified-io'
4. **隐藏设置**: 详情页和权限按钮设置hide_menu=1
5. **Sort顺序**: 变更历史sort=11，生命周期sort=12，确保在其他IO菜单之后显示

## 问题排查

### 问题1：菜单不显示
**原因**：可能是租户ID不匹配或hide_menu设置错误
**解决**：检查tenant_id和hide_menu字段

### 问题2：权限不生效
**原因**：Casbin规则未配置
**解决**：在sys_casbin_rules表中添加对应的权限规则

### 问题3：路由404
**原因**：前端路由组件路径不匹配
**解决**：确认component字段路径与实际Vue文件路径一致

## 完成状态

- ✅ SQL脚本创建
- ✅ Go初始化代码
- ✅ 前端页面创建
- ✅ 数据库执行
- ✅ 数据验证
- ⏳ API实现（待后续完成）
- ⏳ 权限配置（待后续完成）
- ⏳ 集成测试（待后续完成）

---
**文档版本**: 1.0
**最后更新**: 2025-12-26
**维护者**: Claude Code
