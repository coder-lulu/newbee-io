-- ================================================
-- IO服务菜单初始化SQL
-- 生成时间: 2025-12-16
-- 服务名称: unified-io
-- ================================================

-- 说明：
-- 1. 菜单ID从203开始（当前最大ID是202）
-- 2. parent_id=201 表示挂载在"输入输出"模块下
-- 3. menu_type: 0=目录, 1=菜单页面, 2=按钮权限
-- 4. service_name: 'unified-io' 标识所属服务
-- 5. tenant_id=1 为默认租户

-- ================================================
-- 1. 输出任务管理 (Output Task)
-- ================================================

-- 1.1 输出任务管理主菜单 (ID: 203)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    203, NOW(), NOW(), 2, 1, 2, 1,
    'output-task', '输出任务', '', 'io/output-task/index', 0, 'unified-io',
    '输出任务', 'ant-design:export-outlined', 0, 201
);

-- 1.2 输出任务权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name) VALUES
(204, NOW(), NOW(), 1, 1, 3, 2, '/io/output_task/list', '查询输出任务', '查询输出任务', '', 203, 'unified-io'),
(205, NOW(), NOW(), 2, 1, 3, 2, '/io/output_task/create', '创建输出任务', '创建输出任务', '', 203, 'unified-io'),
(206, NOW(), NOW(), 3, 1, 3, 2, '/io/output_task/update', '更新输出任务', '更新输出任务', '', 203, 'unified-io'),
(207, NOW(), NOW(), 4, 1, 3, 2, '/io/output_task/delete', '删除输出任务', '删除输出任务', '', 203, 'unified-io'),
(208, NOW(), NOW(), 5, 1, 3, 2, '/io/output_task/start', '启动输出任务', '启动输出任务', '', 203, 'unified-io'),
(209, NOW(), NOW(), 6, 1, 3, 2, '/io/output_task/pause', '暂停输出任务', '暂停输出任务', '', 203, 'unified-io'),
(210, NOW(), NOW(), 7, 1, 3, 2, '/io/output_task/cancel', '取消输出任务', '取消输出任务', '', 203, 'unified-io');

-- ================================================
-- 2. 发现池管理 (Discovery Pool)
-- ================================================

-- 2.1 发现池管理主菜单 (ID: 211)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    211, NOW(), NOW(), 3, 1, 2, 1,
    'discovery-pool', '发现池管理', '', 'io/discovery-pool/index', 0, 'unified-io',
    '发现池管理', 'ant-design:cluster-outlined', 0, 201
);

-- 2.2 发现池权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name) VALUES
(212, NOW(), NOW(), 1, 1, 3, 2, '/io/discovery_pool/list', '查询发现池', '查询发现池', '', 211, 'unified-io'),
(213, NOW(), NOW(), 2, 1, 3, 2, '/io/discovery_pool/create', '创建发现池', '创建发现池', '', 211, 'unified-io'),
(214, NOW(), NOW(), 3, 1, 3, 2, '/io/discovery_pool/update', '更新发现池', '更新发现池', '', 211, 'unified-io'),
(215, NOW(), NOW(), 4, 1, 3, 2, '/io/discovery_pool/delete', '删除发现池', '删除发现池', '', 211, 'unified-io'),
(216, NOW(), NOW(), 5, 1, 3, 2, '/io/discovery_pool/enable', '启用发现池', '启用发现池', '', 211, 'unified-io'),
(217, NOW(), NOW(), 6, 1, 3, 2, '/io/discovery_pool/disable', '禁用发现池', '禁用发现池', '', 211, 'unified-io'),
(218, NOW(), NOW(), 7, 1, 3, 2, '/io/discovery_pool/trigger', '手动触发发现池', '手动触发', '', 211, 'unified-io'),
(219, NOW(), NOW(), 8, 1, 3, 2, '/io/discovery_pool/stats/:id', '查看发现池统计', '查看统计', '', 211, 'unified-io'),
(220, NOW(), NOW(), 9, 1, 3, 2, '/io/discovery_pool/approve', '审核发现池', '审核发现池', '', 211, 'unified-io');

-- ================================================
-- 3. 发现模板管理 (Discovery Template)
-- ================================================

-- 3.1 发现模板管理主菜单 (ID: 221)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    221, NOW(), NOW(), 4, 1, 2, 1,
    'discovery-template', '发现模板', '', 'io/discovery-template/index', 0, 'unified-io',
    '发现模板', 'ant-design:file-text-outlined', 0, 201
);

-- 3.2 发现模板权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name) VALUES
(222, NOW(), NOW(), 1, 1, 3, 2, '/io/discovery_template/list', '查询发现模板', '查询模板', '', 221, 'unified-io'),
(223, NOW(), NOW(), 2, 1, 3, 2, '/io/discovery_template/create', '创建发现模板', '创建模板', '', 221, 'unified-io'),
(224, NOW(), NOW(), 3, 1, 3, 2, '/io/discovery_template/update', '更新发现模板', '更新模板', '', 221, 'unified-io'),
(225, NOW(), NOW(), 4, 1, 3, 2, '/io/discovery_template/delete', '删除发现模板', '删除模板', '', 221, 'unified-io'),
(226, NOW(), NOW(), 5, 1, 3, 2, '/io/discovery_template/info', '查看发现模板详情', '查看详情', '', 221, 'unified-io');

-- ================================================
-- 4. 发现Provider管理 (Discovery Provider)
-- ================================================

-- 4.1 发现Provider主菜单 (ID: 227)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    227, NOW(), NOW(), 5, 1, 2, 1,
    'discovery-provider', 'Provider管理', '', 'io/discovery-provider/index', 0, 'unified-io',
    'Provider管理', 'ant-design:api-outlined', 0, 201
);

-- 4.2 Provider权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name) VALUES
(228, NOW(), NOW(), 1, 1, 3, 2, '/io/discoveryprovider/list_discovery_providers', '查询Provider列表', '查询Provider', '', 227, 'unified-io'),
(229, NOW(), NOW(), 2, 1, 3, 2, '/io/discoveryprovider/get_provider_schema', '获取Provider Schema', '获取Schema', '', 227, 'unified-io'),
(230, NOW(), NOW(), 3, 1, 3, 2, '/io/discoveryprovider/test_provider_connection', '测试Provider连接', '测试连接', '', 227, 'unified-io');

-- ================================================
-- 5. 数据目标管理 (Data Target)
-- ================================================

-- 5.1 数据目标管理主菜单 (ID: 231)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    231, NOW(), NOW(), 6, 1, 2, 1,
    'data-target', '数据目标', '', 'io/data-target/index', 0, 'unified-io',
    '数据目标', 'ant-design:database-outlined', 0, 201
);

-- 5.2 数据目标权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name) VALUES
(232, NOW(), NOW(), 1, 1, 3, 2, '/io/data_target/list', '查询数据目标', '查询目标', '', 231, 'unified-io'),
(233, NOW(), NOW(), 2, 1, 3, 2, '/io/data_target/create', '创建数据目标', '创建目标', '', 231, 'unified-io'),
(234, NOW(), NOW(), 3, 1, 3, 2, '/io/data_target/update', '更新数据目标', '更新目标', '', 231, 'unified-io'),
(235, NOW(), NOW(), 4, 1, 3, 2, '/io/data_target/delete', '删除数据目标', '删除目标', '', 231, 'unified-io'),
(236, NOW(), NOW(), 5, 1, 3, 2, '/io/data_target/info', '查看数据目标详情', '查看详情', '', 231, 'unified-io');

-- ================================================
-- 6. 字段映射管理 (Field Mapping)
-- ================================================

-- 6.1 字段映射管理主菜单 (ID: 237)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    237, NOW(), NOW(), 7, 1, 2, 1,
    'field-mapping', '字段映射', '', 'io/field-mapping/index', 0, 'unified-io',
    '字段映射', 'ant-design:swap-outlined', 0, 201
);

-- 6.2 字段映射权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name) VALUES
(238, NOW(), NOW(), 1, 1, 3, 2, '/io/field_mapping/list', '查询字段映射', '查询映射', '', 237, 'unified-io'),
(239, NOW(), NOW(), 2, 1, 3, 2, '/io/field_mapping/create', '创建字段映射', '创建映射', '', 237, 'unified-io'),
(240, NOW(), NOW(), 3, 1, 3, 2, '/io/field_mapping/update', '更新字段映射', '更新映射', '', 237, 'unified-io'),
(241, NOW(), NOW(), 4, 1, 3, 2, '/io/field_mapping/delete', '删除字段映射', '删除映射', '', 237, 'unified-io'),
(242, NOW(), NOW(), 5, 1, 3, 2, '/io/field_mapping/:id', '查看字段映射详情', '查看详情', '', 237, 'unified-io');

-- ================================================
-- 7. 任务日志管理 (Task Log)
-- ================================================

-- 7.1 任务日志管理主菜单 (ID: 243)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    243, NOW(), NOW(), 8, 1, 2, 1,
    'task-log', '任务日志', '', 'io/task-log/index', 0, 'unified-io',
    '任务日志', 'ant-design:file-search-outlined', 0, 201
);

-- 7.2 任务日志权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name) VALUES
(244, NOW(), NOW(), 1, 1, 3, 2, '/io/task_log/list', '查询任务日志', '查询日志', '', 243, 'unified-io'),
(245, NOW(), NOW(), 2, 1, 3, 2, '/io/task_log/:id', '查看任务日志详情', '查看详情', '', 243, 'unified-io'),
(246, NOW(), NOW(), 3, 1, 3, 2, '/io/task_log/delete', '删除任务日志', '删除日志', '', 243, 'unified-io');

-- ================================================
-- 8. 映射日志管理 (Mapping Log)
-- ================================================

-- 8.1 映射日志管理主菜单 (ID: 247)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    247, NOW(), NOW(), 9, 1, 2, 1,
    'mapping-log', '映射日志', '', 'io/mapping-log/index', 0, 'unified-io',
    '映射日志', 'ant-design:audit-outlined', 0, 201
);

-- 8.2 映射日志权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name) VALUES
(248, NOW(), NOW(), 1, 1, 3, 2, '/io/mapping_log/list', '查询映射日志', '查询日志', '', 247, 'unified-io'),
(249, NOW(), NOW(), 2, 1, 3, 2, '/io/mapping_log/:id', '查看映射日志详情', '查看详情', '', 247, 'unified-io'),
(250, NOW(), NOW(), 3, 1, 3, 2, '/io/mapping_log/delete', '删除映射日志', '删除日志', '', 247, 'unified-io');

-- ================================================
-- 9. Worker监控管理 (Worker Metrics)
-- ================================================

-- 9.1 Worker监控主菜单 (ID: 251)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    251, NOW(), NOW(), 10, 1, 2, 1,
    'worker-metrics', 'Worker监控', '', 'io/worker-metrics/index', 0, 'unified-io',
    'Worker监控', 'ant-design:dashboard-outlined', 0, 201
);

-- 9.2 Worker监控权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name) VALUES
(252, NOW(), NOW(), 1, 1, 3, 2, '/io/worker_metrics/list', '查询Worker指标', '查询指标', '', 251, 'unified-io'),
(253, NOW(), NOW(), 2, 1, 3, 2, '/io/worker_metrics/create', '上报Worker指标', '上报指标', '', 251, 'unified-io'),
(254, NOW(), NOW(), 3, 1, 3, 2, '/io/worker_metrics/info', '查看Worker监控详情', '查看详情', '', 251, 'unified-io');

-- ================================================
-- 10. 补充输入任务的权限按钮 (已有主菜单ID: 202)
-- ================================================

INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name) VALUES
(255, NOW(), NOW(), 1, 1, 3, 2, '/io/input_task/list', '查询输入任务', '查询输入任务', '', 202, 'unified-io'),
(256, NOW(), NOW(), 2, 1, 3, 2, '/io/input_task/create', '创建输入任务', '创建输入任务', '', 202, 'unified-io'),
(257, NOW(), NOW(), 3, 1, 3, 2, '/io/input_task/update', '更新输入任务', '更新输入任务', '', 202, 'unified-io'),
(258, NOW(), NOW(), 4, 1, 3, 2, '/io/input_task/delete', '删除输入任务', '删除输入任务', '', 202, 'unified-io'),
(259, NOW(), NOW(), 5, 1, 3, 2, '/io/input_task/start', '启动输入任务', '启动输入任务', '', 202, 'unified-io'),
(260, NOW(), NOW(), 6, 1, 3, 2, '/io/input_task/pause', '暂停输入任务', '暂停输入任务', '', 202, 'unified-io'),
(261, NOW(), NOW(), 7, 1, 3, 2, '/io/input_task/cancel', '取消输入任务', '取消输入任务', '', 202, 'unified-io'),
(262, NOW(), NOW(), 8, 1, 3, 2, '/io/input_task/approve', '审核输入任务', '审核输入任务', '', 202, 'unified-io');

-- ================================================
-- 菜单汇总统计
-- ================================================
-- 父目录: 输入输出 (ID: 201) - 已存在
--
-- 新增菜单页面 (menu_type=1): 9个
--   - 输入任务 (ID: 202) - 已存在
--   - 输出任务 (ID: 203)
--   - 发现池管理 (ID: 211)
--   - 发现模板 (ID: 221)
--   - Provider管理 (ID: 227)
--   - 数据目标 (ID: 231)
--   - 字段映射 (ID: 237)
--   - 任务日志 (ID: 243)
--   - 映射日志 (ID: 247)
--   - Worker监控 (ID: 251)
--
-- 新增权限按钮 (menu_type=2): 60个
--   - 输入任务权限: 8个 (ID: 255-262)
--   - 输出任务权限: 7个 (ID: 204-210)
--   - 发现池权限: 9个 (ID: 212-220)
--   - 发现模板权限: 5个 (ID: 222-226)
--   - Provider权限: 3个 (ID: 228-230)
--   - 数据目标权限: 5个 (ID: 232-236)
--   - 字段映射权限: 5个 (ID: 238-242)
--   - 任务日志权限: 3个 (ID: 244-246)
--   - 映射日志权限: 3个 (ID: 248-250)
--   - Worker监控权限: 3个 (ID: 252-254)
--
-- 总计: 69条菜单记录 (9个页面 + 60个按钮权限)
-- ================================================
