-- ================================================
-- IO服务菜单Component路径修正SQL
-- 生成时间: 2025-12-16
-- 目的: 修正菜单component字段，使其与实际前端文件路径匹配
-- ================================================

-- 说明：
-- 1. 前端大部分模块使用 list.vue 作为列表页，而非 index.vue
-- 2. 只有 logs 和 monitor 使用 index.vue
-- 3. 任务日志和映射日志共用 io/logs/index 页面（通过Tab切换）

-- ================================================
-- 修正已实现前端页面的component路径
-- ================================================

-- 1. 修正输出任务（已实现：io/output-task/list.vue）
UPDATE sys_menus
SET component = 'io/output-task/list'
WHERE id = 203 AND tenant_id = 1;

-- 2. 修正发现池管理（已实现：io/discovery-pool/list.vue）
UPDATE sys_menus
SET component = 'io/discovery-pool/list'
WHERE id = 211 AND tenant_id = 1;

-- 3. 修正字段映射（已实现：io/field-mapping/list.vue）
UPDATE sys_menus
SET component = 'io/field-mapping/list'
WHERE id = 237 AND tenant_id = 1;

-- 4. 修正任务日志（已实现：io/logs/index.vue）
UPDATE sys_menus
SET component = 'io/logs/index'
WHERE id = 243 AND tenant_id = 1;

-- 5. 修正映射日志（已实现：io/logs/index.vue，与任务日志共用）
UPDATE sys_menus
SET component = 'io/logs/index'
WHERE id = 247 AND tenant_id = 1;

-- 6. 修正Worker监控（已实现：io/monitor/index.vue）
UPDATE sys_menus
SET component = 'io/monitor/index'
WHERE id = 251 AND tenant_id = 1;

-- ================================================
-- 未实现页面的处理方案
-- ================================================

-- 方案A：保持占位配置，等待前端开发（推荐）
-- 发现模板 (ID: 221) - component: io/discovery-template/index
-- Provider管理 (ID: 227) - component: io/discovery-provider/index
-- 数据目标 (ID: 231) - component: io/data-target/index
-- 以上三个菜单保持原配置不变，待前端开发完成

-- 方案B：临时隐藏未实现的菜单（可选）
-- 取消注释以下SQL以隐藏未实现的菜单
/*
UPDATE sys_menus
SET hide_menu = 1
WHERE id IN (221, 227, 231) AND tenant_id = 1
  AND menu_type = 1;
*/

-- ================================================
-- 验证修正结果
-- ================================================

-- 查看修正后的配置
SELECT
    id,
    name,
    path,
    component,
    hide_menu,
    menu_type
FROM sys_menus
WHERE parent_id = 201 AND menu_type = 1 AND tenant_id = 1
ORDER BY id;

-- ================================================
-- 修正后的配置总览
-- ================================================
--
-- ID  | 菜单名称      | Component路径              | 前端文件状态
-- ----|-------------|--------------------------|-------------
-- 202 | 输入任务      | io/input-task/list       | ✅ 已实现
-- 203 | 输出任务      | io/output-task/list      | ✅ 已实现（已修正）
-- 211 | 发现池管理    | io/discovery-pool/list   | ✅ 已实现（已修正）
-- 221 | 发现模板      | io/discovery-template/index | ❌ 待开发
-- 227 | Provider管理 | io/discovery-provider/index | ❌ 待开发
-- 231 | 数据目标      | io/data-target/index     | ❌ 待开发
-- 237 | 字段映射      | io/field-mapping/list    | ✅ 已实现（已修正）
-- 243 | 任务日志      | io/logs/index           | ✅ 已实现（已修正）
-- 247 | 映射日志      | io/logs/index           | ✅ 已实现（已修正）
-- 251 | Worker监控    | io/monitor/index        | ✅ 已实现（已修正）
--
-- ================================================
