# Scheduled Tasks 部署指南

## 部署前检查

### 环境要求

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| Go | ≥ 1.21 | 支持泛型和新特性 |
| MySQL/PostgreSQL | ≥ 5.7 / ≥ 12 | 主数据库 |
| Redis | ≥ 6.0 | 可选，用于缓存 |

### 依赖检查

```bash
# 检查 Go 版本
go version

# 检查数据库连接
mysql -h <host> -u <user> -p -e "SELECT VERSION();"

# 检查 newbee-common 版本
cd /opt/code/newbee/unified-io/rpc
grep "newbee-common/v2" go.mod
```

## 数据库迁移

### Schema 变更

Phase 1 **不需要修改现有表结构**，已有的 `io_input_tasks` 表完全兼容。

验证表结构：

```sql
-- 检查必要字段
DESCRIBE io_input_tasks;

-- 确认字段存在
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'io_input_tasks'
  AND COLUMN_NAME IN ('task_type', 'scheduled_at');
```

预期结果：
```
+-------------+----------+-------------+---------------+
| COLUMN_NAME | DATA_TYPE| IS_NULLABLE | COLUMN_DEFAULT|
+-------------+----------+-------------+---------------+
| task_type   | varchar  | YES         | manual        |
| scheduled_at| datetime | YES         | NULL          |
+-------------+----------+-------------+---------------+
```

### 索引优化（可选）

为提升查询性能，建议添加索引：

```sql
-- 定时任务查询索引
CREATE INDEX idx_task_type_status_scheduled
ON io_input_tasks(task_type, task_status, scheduled_at)
WHERE task_type = 'scheduled';

-- 验证索引
SHOW INDEX FROM io_input_tasks;
```

## 配置更新

### 1. 修改 `etc/io.yaml`

```yaml
Name: io-rpc
ListenOn: 0.0.0.0:9102

# 数据库配置
DatabaseConf:
  Type: mysql
  Host: localhost:3306
  DBName: newbee_io
  Username: root
  Password: ${DB_PASSWORD}  # 从环境变量读取
  MaxIdleConns: 10
  MaxOpenConns: 100

# TaskWorker 配置（新增）
TaskWorker:
  Enabled: true              # 是否启用 TaskWorker
  PullInterval: 10s          # 手动任务拉取间隔
  MaxConcurrent: 5           # 最大并发任务数
  BatchSize: 10              # 每次拉取任务数
  TaskTimeout: 5m            # 单个任务超时时间
  StaleThreshold: 1h         # 任务过期阈值
  StaleCheckInterval: 5m     # 过期任务检查间隔

# 日志配置
Log:
  Mode: file
  Path: logs
  Level: info
  Compress: true
  KeepDays: 7
```

### 2. 环境变量

```bash
# 生产环境变量
export DB_PASSWORD="your_secure_password"
export REDIS_PASSWORD="your_redis_password"
export ENV="production"
```

### 3. 配置验证

```bash
# 验证配置文件语法
go run io.go -f etc/io.yaml --validate

# 测试数据库连接
go run io.go -f etc/io.yaml --test-db
```

## 编译部署

### 开发环境

```bash
cd /opt/code/newbee/unified-io/rpc

# 1. 清理旧的构建产物
go clean

# 2. 下载依赖
go mod download

# 3. 编译
go build -v -o io-rpc .

# 4. 运行
./io-rpc -f etc/io.yaml
```

### 生产环境

```bash
# 1. 编译（包含版本信息）
VERSION=$(git describe --tags --always)
BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')

go build -v \
  -ldflags "-X main.Version=${VERSION} -X main.BuildTime=${BUILD_TIME}" \
  -o io-rpc .

# 2. 测试编译产物
./io-rpc --version

# 3. 创建部署包
tar -czf io-rpc-${VERSION}.tar.gz \
  io-rpc \
  etc/io.yaml.template \
  README.md
```

## 启动服务

### 方式1: 直接启动

```bash
# 前台运行（开发环境）
./io-rpc -f etc/io.yaml

# 后台运行（生产环境）
nohup ./io-rpc -f etc/io.yaml > logs/io-rpc.log 2>&1 &

# 查看进程
ps aux | grep io-rpc
```

### 方式2: Systemd 服务

创建 `/etc/systemd/system/io-rpc.service`：

```ini
[Unit]
Description=NewBee Unified-IO RPC Service
After=network.target mysql.service

[Service]
Type=simple
User=newbee
Group=newbee
WorkingDirectory=/opt/newbee/unified-io
ExecStart=/opt/newbee/unified-io/io-rpc -f /opt/newbee/unified-io/etc/io.yaml
Restart=on-failure
RestartSec=5s

# 环境变量
Environment="DB_PASSWORD=your_password"
Environment="REDIS_PASSWORD=your_redis_password"

# 日志
StandardOutput=journal
StandardError=journal

# 资源限制
LimitNOFILE=65536
LimitNPROC=32768

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
# 重新加载 systemd
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start io-rpc

# 开机自启
sudo systemctl enable io-rpc

# 查看状态
sudo systemctl status io-rpc

# 查看日志
sudo journalctl -u io-rpc -f
```

### 方式3: Docker 部署

创建 `Dockerfile`：

```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /build
COPY . .

RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o io-rpc .

FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata
WORKDIR /app

COPY --from=builder /build/io-rpc .
COPY --from=builder /build/etc etc/

EXPOSE 9102

CMD ["./io-rpc", "-f", "etc/io.yaml"]
```

构建和运行：

```bash
# 构建镜像
docker build -t newbee/io-rpc:latest .

# 运行容器
docker run -d \
  --name io-rpc \
  -p 9102:9102 \
  -v /opt/newbee/config:/app/etc \
  -v /opt/newbee/logs:/app/logs \
  -e DB_PASSWORD=your_password \
  --restart unless-stopped \
  newbee/io-rpc:latest

# 查看日志
docker logs -f io-rpc
```

## 验证部署

### 1. 健康检查

```bash
# 检查进程
ps aux | grep io-rpc

# 检查端口
lsof -i :9102
# 或
netstat -tlnp | grep 9102

# 检查日志
tail -f logs/io-rpc.log
```

### 2. 功能验证

```bash
# 安装 grpcurl（如果没有）
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

# 测试 RPC 服务
grpcurl -plaintext localhost:9102 list

# 创建测试定时任务
SCHEDULED_TIME=$(($(date +%s) + 120))000  # 2分钟后

grpcurl -plaintext \
  -d '{
    "taskName": "部署验证测试",
    "taskType": "scheduled",
    "scheduledAt": '$SCHEDULED_TIME',
    "inputSource": "test",
    "taskStatus": "pending",
    "tenantId": 1
  }' \
  localhost:9102 io.Io/CreateInputTask
```

### 3. 监控验证

```bash
# 查看 TaskWorker 启动日志
grep "TaskWorker starting" logs/io-rpc.log

# 查看定时任务拉取日志
grep "Pulled scheduled tasks" logs/io-rpc.log

# 查看任务执行日志
grep "Processing task started" logs/io-rpc.log | grep "scheduled"

# 查看任务完成日志
grep "Task completed successfully" logs/io-rpc.log
```

### 4. 数据库验证

```sql
-- 查看测试任务
SELECT id, task_name, task_type, task_status, scheduled_at
FROM io_input_tasks
WHERE task_name = '部署验证测试';

-- 等待2分钟后再次查询
SELECT id, task_name, task_type, task_status,
       scheduled_at, started_at, completed_at
FROM io_input_tasks
WHERE task_name = '部署验证测试';

-- 预期：task_status 应该是 'completed'
```

## 监控配置

### 关键指标

```bash
# 创建监控脚本 /opt/newbee/scripts/monitor_scheduled_tasks.sh
#!/bin/bash

# 待执行的定时任务数
PENDING_COUNT=$(mysql -h localhost -u root -p${DB_PASSWORD} newbee_io \
  -se "SELECT COUNT(*) FROM io_input_tasks \
       WHERE task_type='scheduled' AND task_status='pending' \
       AND scheduled_at <= NOW()")

echo "scheduled_tasks_pending_count $PENDING_COUNT"

# 最近1小时执行的任务数
COMPLETED_COUNT=$(mysql -h localhost -u root -p${DB_PASSWORD} newbee_io \
  -se "SELECT COUNT(*) FROM io_input_tasks \
       WHERE task_type='scheduled' AND task_status='completed' \
       AND completed_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR)")

echo "scheduled_tasks_completed_1h $COMPLETED_COUNT"

# 平均执行延迟（秒）
AVG_DELAY=$(mysql -h localhost -u root -p${DB_PASSWORD} newbee_io \
  -se "SELECT AVG(TIMESTAMPDIFF(SECOND, scheduled_at, started_at)) \
       FROM io_input_tasks \
       WHERE task_type='scheduled' AND started_at IS NOT NULL \
       AND started_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR)")

echo "scheduled_tasks_avg_delay_sec ${AVG_DELAY:-0}"
```

### Prometheus 配置

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'io-rpc-scheduled-tasks'
    scrape_interval: 60s
    static_configs:
      - targets: ['localhost:9102']
    metrics_path: '/metrics'
```

### Grafana Dashboard

创建 Dashboard 监控：
- 待执行任务数量
- 任务执行成功率
- 任务执行延迟
- TaskWorker 并发数

## 告警配置

### 告警规则

```yaml
# alertmanager-rules.yml
groups:
  - name: scheduled_tasks
    interval: 1m
    rules:
      # 大量任务堆积
      - alert: ScheduledTasksBacklog
        expr: scheduled_tasks_pending_count > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "定时任务堆积 ({{ $value }} 个待执行)"
          description: "当前有 {{ $value }} 个定时任务待执行，可能存在性能问题"

      # 任务执行失败率高
      - alert: ScheduledTasksHighFailureRate
        expr: |
          (rate(scheduled_tasks_failed_total[5m]) /
           rate(scheduled_tasks_processed_total[5m])) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "定时任务失败率过高 ({{ $value | humanizePercentage }})"

      # 任务执行延迟过大
      - alert: ScheduledTasksHighLatency
        expr: scheduled_tasks_avg_delay_sec > 120
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "定时任务执行延迟过大 (平均 {{ $value }}秒)"
```

## 回滚方案

### 快速回滚步骤

```bash
# 1. 停止服务
sudo systemctl stop io-rpc
# 或
kill $(cat /var/run/io-rpc.pid)

# 2. 恢复旧版本
cd /opt/newbee/unified-io
mv io-rpc io-rpc.new
mv io-rpc.old io-rpc

# 3. 恢复配置（如果有变更）
mv etc/io.yaml etc/io.yaml.new
mv etc/io.yaml.old etc/io.yaml

# 4. 重启服务
sudo systemctl start io-rpc

# 5. 验证
sudo systemctl status io-rpc
tail -f logs/io-rpc.log
```

### 数据回滚

```sql
-- 如果需要清理已创建的定时任务
UPDATE io_input_tasks
SET task_status = 'failed',
    error_message = '回滚操作：取消定时任务'
WHERE task_type = 'scheduled'
  AND task_status = 'pending'
  AND created_at >= '2025-12-24 00:00:00';
```

## 常见问题

### Q1: 定时任务没有执行？

**检查步骤**：
```bash
# 1. 确认 TaskWorker 已启动
grep "TaskWorker starting" logs/io-rpc.log

# 2. 确认 scheduled ticker 正常
grep "Pulled scheduled tasks" logs/io-rpc.log

# 3. 检查任务状态
mysql -e "SELECT * FROM io_input_tasks WHERE task_type='scheduled' AND task_status='pending';"

# 4. 检查时间
date  # 确认服务器时间正确
```

### Q2: 任务执行延迟过大？

**优化措施**：
- 增大 `MaxConcurrent` 参数
- 增大 `BatchSize` 参数
- 错开任务的 `scheduled_at` 时间
- 检查数据库性能

### Q3: 任务重复执行？

**不会发生**：
- TaskWorker 使用 SystemContext 查询
- 任务开始执行时立即更新状态为 `processing`
- Ent ORM 的 Hook 机制确保租户隔离

### Q4: 服务重启后任务丢失？

**不会丢失**：
- 所有任务存储在数据库中
- 服务重启后自动恢复
- pending 状态的任务会继续执行

## 性能调优

### 数据库优化

```sql
-- 1. 添加索引
CREATE INDEX idx_scheduled_tasks
ON io_input_tasks(task_type, task_status, scheduled_at)
WHERE task_type = 'scheduled';

-- 2. 定期清理历史数据
DELETE FROM io_input_tasks
WHERE task_type = 'scheduled'
  AND task_status IN ('completed', 'failed')
  AND completed_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
```

### 配置优化

```yaml
# 高负载环境
TaskWorker:
  MaxConcurrent: 20      # 增大并发数
  BatchSize: 50          # 增大批量拉取
  PullInterval: 5s       # 缩短拉取间隔（慎重）
```

### 监控和告警

```bash
# 定期检查任务堆积情况
*/5 * * * * /opt/newbee/scripts/monitor_scheduled_tasks.sh >> /var/log/scheduled_tasks_metrics.log
```

## 安全建议

1. **最小权限原则** - 服务账号只有必要的数据库权限
2. **加密通信** - 使用 TLS 保护 gRPC 通信
3. **审计日志** - 记录所有任务创建和执行日志
4. **资源限制** - 使用 systemd 限制资源使用

---

**文档版本**: v1.0
**最后更新**: 2025-12-24
**适用版本**: unified-io v1.0+
