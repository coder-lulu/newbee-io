-- ================================================
-- 配置中心菜单初始化SQL
-- 生成时间: 2025-12-25
-- 服务名称: unified-io
-- 功能模块: 配置中心 (Config Center)
-- ================================================

-- 说明：
-- 1. 菜单ID从263开始（当前最大ID是262）
-- 2. parent_id=201 表示挂载在"输入输出"模块下
-- 3. menu_type: 0=目录, 1=菜单页面, 2=按钮权限
-- 4. service_name: 'unified-io' 标识所属服务
-- 5. tenant_id=1 为默认租户
-- 6. sort=1 使配置中心显示在第一位（核心功能）

-- ================================================
-- 配置中心主菜单 (ID: 263)
-- ================================================

INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, redirect, component, disabled, service_name,
    title, icon, hide_menu, parent_id
) VALUES (
    263, NOW(), NOW(), 1, 1, 2, 1,
    'config-center', '配置中心', '', 'io/config/index', 0, 'unified-io',
    '配置中心', 'ant-design:setting-outlined', 0, 201
);

-- ================================================
-- 配置中心权限按钮
-- ================================================

INSERT INTO sys_menus (
    id, created_at, updated_at, sort, tenant_id, menu_level, menu_type,
    path, name, title, icon, parent_id, service_name
) VALUES
-- 1. 查询配置列表
(264, NOW(), NOW(), 1, 1, 3, 2,
    '/io/config/list', '查询配置列表', '查询配置', '', 263, 'unified-io'),

-- 2. 获取配置详情
(265, NOW(), NOW(), 2, 1, 3, 2,
    '/io/config/get', '获取配置详情', '获取配置', '', 263, 'unified-io'),

-- 3. 创建配置
(266, NOW(), NOW(), 3, 1, 3, 2,
    '/io/config/create', '创建配置', '创建配置', '', 263, 'unified-io'),

-- 4. 更新配置
(267, NOW(), NOW(), 4, 1, 3, 2,
    '/io/config/update', '更新配置', '更新配置', '', 263, 'unified-io'),

-- 5. 删除配置
(268, NOW(), NOW(), 5, 1, 3, 2,
    '/io/config/delete', '删除配置', '删除配置', '', 263, 'unified-io'),

-- 6. 查询审计日志
(269, NOW(), NOW(), 6, 1, 3, 2,
    '/io/config/audit_log/list', '查询配置审计日志', '审计日志', '', 263, 'unified-io'),

-- 7. 获取配置历史
(270, NOW(), NOW(), 7, 1, 3, 2,
    '/io/config/history/get', '获取配置变更历史', '配置历史', '', 263, 'unified-io'),

-- 8. 回滚配置
(271, NOW(), NOW(), 8, 1, 3, 2,
    '/io/config/rollback', '回滚配置', '回滚配置', '', 263, 'unified-io');

-- ================================================
-- 菜单汇总统计
-- ================================================
-- 父目录: 输入输出 (ID: 201) - 已存在
--
-- 新增菜单页面 (menu_type=1): 1个
--   - 配置中心 (ID: 263)
--
-- 新增权限按钮 (menu_type=2): 8个
--   - 查询配置列表 (ID: 264)
--   - 获取配置详情 (ID: 265)
--   - 创建配置 (ID: 266)
--   - 更新配置 (ID: 267)
--   - 删除配置 (ID: 268)
--   - 查询审计日志 (ID: 269)
--   - 获取配置历史 (ID: 270)
--   - 回滚配置 (ID: 271)
--
-- 总计: 9条菜单记录 (1个页面 + 8个按钮权限)
-- ================================================

-- ================================================
-- 角色权限关联
-- ================================================
-- 说明：为租户管理员角色(role_code='admin')自动关联配置中心权限
-- 租户ID: 1 (默认租户)

INSERT INTO role_menus (role_id, menu_id)
SELECT r.id, m.id
FROM sys_roles r, sys_menus m
WHERE r.code = 'admin'
  AND r.tenant_id = 1
  AND m.id BETWEEN 263 AND 271
  AND m.tenant_id = 1
  AND NOT EXISTS (
    SELECT 1 FROM role_menus rm
    WHERE rm.role_id = r.id AND rm.menu_id = m.id
  );

-- ================================================
-- 验证SQL
-- ================================================
-- 查询配置中心菜单是否创建成功
-- SELECT * FROM sys_menus WHERE id BETWEEN 263 AND 271 ORDER BY id;

-- 查询管理员角色是否已关联权限
-- SELECT r.name, m.title, m.path
-- FROM role_menus rm
-- JOIN sys_roles r ON rm.role_id = r.id
-- JOIN sys_menus m ON rm.menu_id = m.id
-- WHERE r.code = 'admin' AND m.id BETWEEN 263 AND 271
-- ORDER BY m.id;
