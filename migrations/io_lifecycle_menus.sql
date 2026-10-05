-- ================================================
-- IO服务生命周期和变更历史菜单初始化SQL
-- 生成时间: 2025-12-26
-- 服务名称: unified-io
-- 功能: 添加CI变更历史和生命周期状态管理页面
-- ================================================

-- 说明：
-- 1. 菜单ID从350开始（当前最大ID是347）
-- 2. parent_id=201 表示挂载在"输入输出"模块下
-- 3. menu_type: 0=目录, 1=菜单页面, 2=按钮权限
-- 4. service_name: 'unified-io' 标识所属服务
-- 5. tenant_id=1 为默认租户
-- 6. sort顺序: 11=变更历史, 12=生命周期状态

-- ================================================
-- 1. CI变更历史管理 (Change History)
-- ================================================

-- 1.1 CI变更历史主菜单 (ID: 350)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    350, NOW(), NOW(), 11, 1, 2, 1,
    'change-history', 'CI变更历史', '', 'io/change-history/list', 0, 'unified-io',
    'CI变更历史', 'lucide:history', 0, 201
);

-- 1.2 CI变更历史权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name, hide_menu) VALUES
-- 基本操作权限
(351, NOW(), NOW(), 1, 1, 3, 2, '/io/change_history/list', '查询变更历史', '查询变更历史', '', 350, 'unified-io', 1),
(352, NOW(), NOW(), 2, 1, 3, 2, '/io/change_history/info', '查看变更详情', '查看变更详情', '', 350, 'unified-io', 1),
(353, NOW(), NOW(), 3, 1, 3, 2, '/io/change_history/compare', '对比变更数据', '对比变更数据', '', 350, 'unified-io', 1),
(354, NOW(), NOW(), 4, 1, 3, 2, '/io/change_history/timeline', '查看变更时间线', '查看时间线', '', 350, 'unified-io', 1),
(355, NOW(), NOW(), 5, 1, 3, 2, '/io/change_history/rollback', '回滚变更', '回滚变更', '', 350, 'unified-io', 1),
-- 审批相关权限
(356, NOW(), NOW(), 6, 1, 3, 2, '/io/change_history/approve', '审批变更', '审批变更', '', 350, 'unified-io', 1),
(357, NOW(), NOW(), 7, 1, 3, 2, '/io/change_history/export', '导出变更记录', '导出记录', '', 350, 'unified-io', 1);

-- 1.3 CI变更历史详情页面 (hidden menu - ID: 360)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    360, NOW(), NOW(), 1, 1, 3, 1,
    'change-history/:id', '变更详情', '', 'io/change-history/detail', 0, 'unified-io',
    '变更详情', '', 1, 350
);

-- 1.4 CI变更时间线页面 (hidden menu - ID: 361)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    361, NOW(), NOW(), 2, 1, 3, 1,
    'change-history/timeline/:ciId', '变更时间线', '', 'io/change-history/timeline', 0, 'unified-io',
    '变更时间线', '', 1, 350
);

-- ================================================
-- 2. CI生命周期状态管理 (Lifecycle State)
-- ================================================

-- 2.1 CI生命周期状态主菜单 (ID: 370)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    370, NOW(), NOW(), 12, 1, 2, 1,
    'lifecycle-state', 'CI生命周期', '', 'io/lifecycle-state/list', 0, 'unified-io',
    'CI生命周期', 'lucide:git-branch', 0, 201
);

-- 2.2 CI生命周期状态权限按钮
INSERT INTO sys_menus (id, created_at, updated_at, sort, tenant_id, menu_level, menu_type, path, name, title, icon, parent_id, service_name, hide_menu) VALUES
-- 基本操作权限
(371, NOW(), NOW(), 1, 1, 3, 2, '/io/lifecycle_state/list', '查询生命周期状态', '查询状态', '', 370, 'unified-io', 1),
(372, NOW(), NOW(), 2, 1, 3, 2, '/io/lifecycle_state/info', '查看状态详情', '查看详情', '', 370, 'unified-io', 1),
(373, NOW(), NOW(), 3, 1, 3, 2, '/io/lifecycle_state/timeline', '查看状态时间线', '查看时间线', '', 370, 'unified-io', 1),
-- 状态转换权限
(374, NOW(), NOW(), 4, 1, 3, 2, '/io/lifecycle_state/transition', '执行状态转换', '状态转换', '', 370, 'unified-io', 1),
(375, NOW(), NOW(), 5, 1, 3, 2, '/io/lifecycle_state/retry', '重试失败状态', '重试状态', '', 370, 'unified-io', 1),
(376, NOW(), NOW(), 6, 1, 3, 2, '/io/lifecycle_state/cancel', '取消执行中状态', '取消状态', '', 370, 'unified-io', 1),
-- 监控和管理权限
(377, NOW(), NOW(), 7, 1, 3, 2, '/io/lifecycle_state/check_timeout', '检查超时状态', '检查超时', '', 370, 'unified-io', 1),
(378, NOW(), NOW(), 8, 1, 3, 2, '/io/lifecycle_state/export', '导出状态记录', '导出记录', '', 370, 'unified-io', 1);

-- 2.3 CI生命周期详情页面 (hidden menu - ID: 380)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    380, NOW(), NOW(), 1, 1, 3, 1,
    'lifecycle-state/:id', '生命周期详情', '', 'io/lifecycle-state/detail', 0, 'unified-io',
    '生命周期详情', '', 1, 370
);

-- 2.4 CI生命周期时间线页面 (hidden menu - ID: 381)
INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    381, NOW(), NOW(), 2, 1, 3, 1,
    'lifecycle-state/timeline/:ciId', '生命周期时间线', '', 'io/lifecycle-state/timeline', 0, 'unified-io',
    '生命周期时间线', '', 1, 370
);

-- ================================================
-- 菜单汇总统计
-- ================================================
-- 父目录: 输入输出 (ID: 201) - 已存在
--
-- 新增菜单页面 (menu_type=1): 6个
--   主菜单:
--   - CI变更历史 (ID: 350) - 主菜单
--   - CI生命周期 (ID: 370) - 主菜单
--
--   隐藏子页面:
--   - 变更详情 (ID: 360) - 详情页面
--   - 变更时间线 (ID: 361) - 时间线页面
--   - 生命周期详情 (ID: 380) - 详情页面
--   - 生命周期时间线 (ID: 381) - 时间线页面
--
-- 新增权限按钮 (menu_type=2): 15个
--   - CI变更历史权限: 7个 (ID: 351-357)
--   - CI生命周期权限: 8个 (ID: 371-378)
--
-- 总计: 21条菜单记录 (6个页面 + 15个按钮权限)
--
-- 菜单层级结构:
-- 输入输出 (201)
--   ├── CI变更历史 (350) [主菜单，显示]
--   │   ├── 变更详情 (360) [子页面，隐藏]
--   │   ├── 变更时间线 (361) [子页面，隐藏]
--   │   └── 权限按钮 (351-357) [按钮权限，隐藏]
--   └── CI生命周期 (370) [主菜单，显示]
--       ├── 生命周期详情 (380) [子页面，隐藏]
--       ├── 生命周期时间线 (381) [子页面，隐藏]
--       └── 权限按钮 (371-378) [按钮权限，隐藏]
-- ================================================

-- ================================================
-- 执行说明
-- ================================================
-- 1. 此SQL脚本可以直接在数据库中执行
-- 2. 如需通过Go代码执行，参考 cmdb/rpc/internal/logic/base/init_database_menu_data.go
-- 3. 推荐通过Go初始化逻辑执行，支持增量插入和错误处理
-- 4. SQL中的created_at和updated_at使用NOW()函数自动填充
-- 5. 所有菜单都设置了tenant_id=1（默认租户）
-- 6. hide_menu=1表示在菜单中隐藏（详情页和权限按钮）
-- 7. hide_menu=0或不设置表示在菜单中显示（主菜单）
-- ================================================
