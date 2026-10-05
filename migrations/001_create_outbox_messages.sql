-- =====================================================
-- Outbox Messages Table Migration
-- =====================================================
-- 用途：实现Outbox模式，确保消息发送的事务一致性
-- 创建日期：2025-10-22
-- 版本：v1.0
-- =====================================================

-- 创建outbox_messages表
CREATE TABLE IF NOT EXISTS `outbox_messages` (
    -- 主键和基础字段（来自IDMixin）
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

    -- 租户字段（来自TenantMixin）
    `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT '租户ID',

    -- 状态字段（来自StatusMixin）
    `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态: 0=删除, 1=正常',

    -- 聚合信息
    `aggregate_type` VARCHAR(100) NOT NULL COMMENT '聚合类型 (e.g., InputTask, OutputTask)',
    `aggregate_id` VARCHAR(100) NOT NULL COMMENT '聚合ID (业务实体ID)',

    -- Kafka消息信息
    `topic` VARCHAR(200) NOT NULL COMMENT 'Kafka Topic名称',
    `message_key` VARCHAR(500) DEFAULT NULL COMMENT '消息Key (用于分区)',
    `message_value` BLOB NOT NULL COMMENT '消息体 (JSON字节)',
    `message_headers` JSON DEFAULT NULL COMMENT '消息Headers (JSON格式)',

    -- 事件类型
    `event_type` VARCHAR(100) NOT NULL COMMENT '事件类型 (e.g., TaskCreated, TaskCompleted)',

    -- 发送状态
    `send_status` VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '发送状态: pending, sent, failed',

    -- 重试机制
    `retry_count` INT NOT NULL DEFAULT 0 COMMENT '重试次数',
    `max_retries` INT NOT NULL DEFAULT 3 COMMENT '最大重试次数',

    -- 时间信息
    `sent_at` TIMESTAMP NULL DEFAULT NULL COMMENT '发送时间',
    `next_retry_at` TIMESTAMP NULL DEFAULT NULL COMMENT '下次重试时间',

    -- 错误信息
    `error_message` TEXT DEFAULT NULL COMMENT '错误信息',
    `last_error` TEXT DEFAULT NULL COMMENT '最后一次错误详情',

    -- 元数据
    `metadata` JSON DEFAULT NULL COMMENT '扩展元数据',

    -- 优先级
    `priority` INT NOT NULL DEFAULT 5 COMMENT '优先级 (1-10, 数字越大越紧急)',

    -- 主键
    PRIMARY KEY (`id`),

    -- 核心索引 - 用于查询待发送消息（最重要！）
    INDEX `idx_tenant_send_status` (`tenant_id`, `send_status`),

    -- 聚合索引 - 用于查询某个业务实体的消息
    INDEX `idx_tenant_aggregate` (`tenant_id`, `aggregate_type`, `aggregate_id`),

    -- 重试索引 - 用于Relay定时任务
    INDEX `idx_status_retry_at` (`send_status`, `next_retry_at`),

    -- 时间索引 - 用于清理旧数据
    INDEX `idx_created_at` (`created_at`),

    -- Topic索引 - 用于监控和统计
    INDEX `idx_topic_status` (`topic`, `send_status`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Outbox消息表 - 事务性消息发送';

-- =====================================================
-- 索引说明
-- =====================================================
-- idx_tenant_send_status:
--   用途：OutboxRelay查询待发送消息
--   查询：SELECT * FROM outbox_messages WHERE tenant_id=? AND send_status='pending' LIMIT 100
--   重要性：⭐⭐⭐⭐⭐ (最高优先级)
--
-- idx_tenant_aggregate:
--   用途：查询某个业务实体的所有消息
--   查询：SELECT * FROM outbox_messages WHERE tenant_id=? AND aggregate_type='InputTask' AND aggregate_id='123'
--   重要性：⭐⭐⭐⭐
--
-- idx_status_retry_at:
--   用途：Relay任务查询需要重试的消息
--   查询：SELECT * FROM outbox_messages WHERE send_status='pending' AND (next_retry_at IS NULL OR next_retry_at <= NOW())
--   重要性：⭐⭐⭐⭐
--
-- idx_created_at:
--   用途：定期清理已发送的旧消息
--   查询：DELETE FROM outbox_messages WHERE send_status='sent' AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
--   重要性：⭐⭐⭐
--
-- idx_topic_status:
--   用途：监控和统计各Topic的发送情况
--   查询：SELECT topic, send_status, COUNT(*) FROM outbox_messages GROUP BY topic, send_status
--   重要性：⭐⭐
-- =====================================================

-- =====================================================
-- 使用示例
-- =====================================================
-- 1. 业务逻辑 + 消息保存（同一事务）
-- BEGIN;
-- INSERT INTO input_tasks (...) VALUES (...);
-- INSERT INTO outbox_messages (tenant_id, aggregate_type, aggregate_id, topic, message_value, event_type, send_status)
-- VALUES (1, 'InputTask', '123', 'io.input.jobs', '{"task_id":123}', 'TaskCreated', 'pending');
-- COMMIT;
--
-- 2. Relay查询待发送消息
-- SELECT * FROM outbox_messages
-- WHERE tenant_id = 1 AND send_status = 'pending'
-- ORDER BY priority DESC, created_at ASC
-- LIMIT 100;
--
-- 3. 更新发送状态
-- UPDATE outbox_messages
-- SET send_status = 'sent', sent_at = NOW()
-- WHERE id = 123;
--
-- 4. 记录失败并计划重试
-- UPDATE outbox_messages
-- SET retry_count = retry_count + 1,
--     last_error = '...',
--     next_retry_at = DATE_ADD(NOW(), INTERVAL POW(2, retry_count) SECOND)
-- WHERE id = 123;
--
-- 5. 清理已发送的旧消息（保留7天）
-- DELETE FROM outbox_messages
-- WHERE send_status = 'sent'
-- AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
-- LIMIT 1000;
-- =====================================================

-- =====================================================
-- 回滚脚本
-- =====================================================
-- DROP TABLE IF EXISTS `outbox_messages`;
-- =====================================================
