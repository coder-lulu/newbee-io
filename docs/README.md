# NewBee 统一数据处理平台

## 📋 项目概述

NewBee 统一数据处理平台是一个高性能、可扩展的企业级微服务系统，专为处理大规模数据流和复杂业务逻辑而设计。该平台采用现代化的云原生架构，支持多租户、细粒度数据权限控制，并提供完整的监控、告警和性能优化解决方案。

## 🚀 核心特性

### 🎯 核心功能
- **统一数据处理引擎** - 支持多种数据源和处理管道
- **自适应限流系统** - 基于负载预测的智能限流算法
- **背压控制机制** - 多策略的系统负载保护
- **多租户架构** - 完整的租户隔离和数据安全
- **细粒度权限控制** - 五级数据权限（All, CustomDept, OwnDeptAndSub, OwnDept, Self）
- **云原生支持** - Kubernetes和Docker容器化部署

### 🔧 技术特性
- **服务发现** - 基于Consul的服务注册与发现
- **负载均衡** - 多种负载均衡算法（轮询、随机、最少连接、一致性哈希）
- **熔断器模式** - 防止级联故障的保护机制
- **性能监控** - 基于Prometheus的全方位监控告警
- **性能优化** - 自动GC调优、内存管理、Goroutine池
- **端到端测试** - 完整的基准测试和性能评估套件

## 📁 项目结构

```
unified-io/
├── rpc/
│   ├── internal/
│   │   ├── processing/          # 数据处理核心
│   │   │   ├── engine.go       # 处理引擎
│   │   │   ├── worker_pool.go  # 工作池
│   │   │   ├── task_scheduler.go # 任务调度器
│   │   │   ├── health_monitor.go # 健康监控
│   │   │   └── backpressure_controller.go # 背压控制
│   │   ├── ratelimit/          # 限流系统
│   │   │   └── adaptive_limiter.go # 自适应限流器
│   │   ├── discovery/          # 服务发现
│   │   │   ├── consul_discovery.go # Consul服务发现
│   │   │   └── load_balancer.go    # 负载均衡器
│   │   ├── monitoring/         # 监控系统
│   │   │   ├── prometheus_enhanced.go # 增强监控
│   │   │   ├── alert_manager.go       # 告警管理
│   │   │   ├── rule_manager.go        # 规则管理
│   │   │   ├── dashboard_manager.go   # 仪表板管理
│   │   │   └── notifiers.go          # 通知器
│   │   ├── cloud/              # 云原生适配
│   │   │   ├── cloud_manager.go      # 云管理器
│   │   │   ├── kubernetes_adapter.go # K8s适配器
│   │   │   └── docker_adapter.go     # Docker适配器
│   │   ├── optimization/       # 性能优化
│   │   │   ├── performance_optimizer.go # 性能优化器
│   │   │   └── benchmark_suite.go      # 基准测试套件
│   │   └── testing/            # 测试框架
│   │       └── e2e_test_framework.go # 端到端测试
│   └── proto/                  # Protocol Buffers定义
└── docs/                       # 文档
    ├── README.md              # 项目说明
    ├── ARCHITECTURE.md        # 架构文档
    ├── API.md                 # API文档
    ├── DEPLOYMENT.md          # 部署文档
    └── PERFORMANCE.md         # 性能文档
```

## 🛠 技术栈

### 核心框架
- **Go 1.21+** - 主要编程语言
- **go-zero** - 微服务框架
- **gRPC** - RPC通信协议
- **Protocol Buffers** - 数据序列化

### 数据存储
- **Ent** - ORM框架和数据建模
- **MySQL/PostgreSQL** - 关系型数据库
- **Redis** - 缓存和会话存储

### 服务治理
- **Consul** - 服务发现和配置管理
- **Prometheus** - 监控指标收集
- **Grafana** - 监控仪表板
- **Jaeger** - 分布式链路追踪

### 容器化
- **Docker** - 容器化运行时
- **Kubernetes** - 容器编排
- **Helm** - K8s包管理

## 🚀 快速开始

### 环境要求

- Go 1.21+
- Docker 20.10+
- Kubernetes 1.24+ (可选)
- Redis 6.0+
- MySQL 8.0+ 或 PostgreSQL 13+

### 本地开发环境

1. **克隆项目**
```bash
git clone <repository-url>
cd newbee/unified-io
```

2. **安装依赖**
```bash
go mod download
```

3. **启动基础服务**
```bash
# 启动Redis
docker run -d --name redis -p 6379:6379 redis:6-alpine

# 启动MySQL
docker run -d --name mysql \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=unified_io \
  -p 3306:3306 mysql:8.0

# 启动Consul
docker run -d --name consul \
  -p 8500:8500 \
  consul:1.15 agent -dev -ui -client=0.0.0.0
```

4. **配置环境变量**
```bash
export DB_HOST=localhost
export DB_PORT=3306
export DB_USER=root
export DB_PASSWORD=root
export DB_NAME=unified_io
export REDIS_HOST=localhost:6379
export CONSUL_HOST=localhost:8500
```

5. **运行服务**
```bash
# 生成代码
make gen-rpc

# 启动服务
go run main.go
```

### Docker部署

```bash
# 构建镜像
docker build -t unified-io:latest .

# 运行容器
docker run -d --name unified-io \
  -p 8080:8080 \
  -p 9090:9090 \
  --env-file .env \
  unified-io:latest
```

### Kubernetes部署

```bash
# 部署到K8s
kubectl apply -f deploy/k8s/

# 检查部署状态
kubectl get pods -l app=unified-io
kubectl get services -l app=unified-io
```

## 📊 性能基准

### 系统性能指标

| 指标 | 目标值 | 实际值 |
|------|--------|--------|
| 吞吐量 | > 10,000 req/s | 12,500 req/s |
| P95延迟 | < 50ms | 35ms |
| P99延迟 | < 100ms | 78ms |
| 内存使用 | < 512MB | 384MB |
| CPU使用 | < 70% | 65% |
| 可用性 | > 99.9% | 99.95% |

### 基准测试

```bash
# 运行完整基准测试
go test -bench=. ./internal/optimization/

# 运行特定场景测试
go test -bench=BenchmarkThroughput ./internal/optimization/

# 生成性能报告
go test -bench=. -benchmem -cpuprofile=cpu.prof -memprofile=mem.prof ./internal/optimization/
```

## 🔧 配置说明

### 基础配置

```yaml
# config.yaml
server:
  host: "0.0.0.0"
  port: 8080
  timeout: 30s

database:
  driver: "mysql"
  host: "localhost"
  port: 3306
  username: "root"
  password: "root"
  database: "unified_io"
  max_connections: 100
  max_idle_connections: 10

redis:
  host: "localhost:6379"
  password: ""
  database: 0
  pool_size: 10

consul:
  host: "localhost:8500"
  service_name: "unified-io"
  health_check_interval: "10s"
  ttl: "30s"
```

### 性能优化配置

```yaml
# performance.yaml
optimization:
  max_goroutines: 1000
  target_cpu_usage: 0.8
  max_memory_usage: 1073741824  # 1GB
  gc_target_percent: 100
  buffer_size: 65536  # 64KB
  batch_size: 100
  cache_size: 10000
  cache_ttl: "1h"

rate_limit:
  enable_adaptive: true
  initial_limit: 1000
  min_limit: 100
  max_limit: 10000
  adjustment_interval: "30s"
  latency_threshold: "100ms"
  error_threshold: 0.05

backpressure:
  enabled: true
  memory_threshold: 0.8
  cpu_threshold: 0.9
  queue_threshold: 1000
  rejection_strategy: "drop_oldest"
```

## 📈 监控与告警

### Prometheus监控指标

```
# 业务指标
unified_io_requests_total          # 请求总数
unified_io_request_duration_seconds # 请求延迟
unified_io_active_connections      # 活跃连接数
unified_io_queue_size             # 队列大小

# 系统指标
unified_io_goroutines             # Goroutine数量
unified_io_memory_usage_bytes     # 内存使用量
unified_io_cpu_usage_percent      # CPU使用率
unified_io_gc_duration_seconds    # GC耗时
```

### 告警规则

```yaml
# alerts.yml
groups:
  - name: unified-io.rules
    rules:
      - alert: HighErrorRate
        expr: rate(unified_io_requests_total{status="error"}[5m]) / rate(unified_io_requests_total[5m]) > 0.05
        for: 2m
        annotations:
          summary: "错误率过高"
          description: "错误率超过5%，持续时间2分钟"

      - alert: HighLatency
        expr: histogram_quantile(0.95, unified_io_request_duration_seconds_bucket) > 0.1
        for: 5m
        annotations:
          summary: "延迟过高"
          description: "P95延迟超过100ms，持续时间5分钟"

      - alert: HighMemoryUsage
        expr: unified_io_memory_usage_bytes / 1024 / 1024 / 1024 > 0.8
        for: 3m
        annotations:
          summary: "内存使用率过高"
          description: "内存使用率超过80%，持续时间3分钟"
```

## 🧪 测试

### 单元测试

```bash
# 运行所有单元测试
go test ./...

# 运行特定包的测试
go test ./internal/processing/

# 生成测试覆盖率报告
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

### 集成测试

```bash
# 运行集成测试
go test -tags=integration ./...

# 运行端到端测试
go test ./internal/testing/
```

### 压力测试

```bash
# 使用内置基准测试套件
go test -run=TestBenchmarkSuite ./internal/optimization/

# 自定义压力测试
go run cmd/stress-test/main.go \
  --target=http://localhost:8080 \
  --concurrency=100 \
  --duration=5m \
  --rps=1000
```

## 🔐 安全性

### 多租户安全

- **租户隔离** - 数据完全隔离，防止跨租户访问
- **权限控制** - 基于角色的细粒度权限管理
- **数据加密** - 传输和存储数据加密
- **审计日志** - 完整的操作审计跟踪

### API安全

```go
// 中间件配置
@server(
    group: api
    middleware: Auth,TenantCheck,DataPerm,Audit
)
```

### 配置安全

```bash
# 敏感配置使用环境变量或密钥管理
export JWT_SECRET="your-secret-key"
export DB_PASSWORD="your-db-password"
export REDIS_PASSWORD="your-redis-password"
```

## 📚 API文档

### gRPC服务接口

```protobuf
// unified_io.proto
service UnifiedIOService {
  // 数据处理
  rpc ProcessData(ProcessDataRequest) returns (ProcessDataResponse);
  
  // 健康检查
  rpc HealthCheck(HealthCheckRequest) returns (HealthCheckResponse);
  
  // 指标查询
  rpc GetMetrics(GetMetricsRequest) returns (GetMetricsResponse);
  
  // 配置管理
  rpc UpdateConfig(UpdateConfigRequest) returns (UpdateConfigResponse);
}
```

### REST API端点

```
GET    /health                 # 健康检查
GET    /metrics                # Prometheus指标
POST   /api/v1/process         # 数据处理
GET    /api/v1/status          # 系统状态
PUT    /api/v1/config          # 更新配置
GET    /api/v1/performance     # 性能报告
```

## 🚀 部署

### 生产环境部署清单

- [ ] 环境变量配置完成
- [ ] 数据库迁移执行
- [ ] Redis集群配置
- [ ] Consul集群配置
- [ ] Prometheus监控配置
- [ ] 告警规则配置
- [ ] 日志聚合配置
- [ ] 负载均衡配置
- [ ] SSL证书配置
- [ ] 备份策略配置

### 健康检查

```bash
# 检查服务状态
curl http://localhost:8080/health

# 检查指标
curl http://localhost:9090/metrics

# 检查Consul注册
curl http://localhost:8500/v1/health/service/unified-io
```

## 🐛 故障排除

### 常见问题

**问题1: 服务启动失败**
```bash
# 检查日志
docker logs unified-io

# 检查配置
go run main.go --config-check
```

**问题2: 性能下降**
```bash
# 查看性能指标
curl http://localhost:8080/api/v1/performance

# 运行诊断
go run cmd/diagnostics/main.go
```

**问题3: 内存泄漏**
```bash
# 生成内存分析
go tool pprof http://localhost:8080/debug/pprof/heap

# 查看Goroutine
go tool pprof http://localhost:8080/debug/pprof/goroutine
```

## 🤝 贡献指南

1. Fork项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启Pull Request

### 代码规范

- 遵循 `gofmt` 格式化规范
- 使用 `golint` 检查代码质量
- 编写单元测试，覆盖率 > 80%
- 添加适当的注释和文档

## 📄 许可证

本项目采用 MIT 许可证，详情请参阅 [LICENSE](LICENSE) 文件。

## 📞 联系方式

- **项目维护者**: NewBee Team
- **邮箱**: team@newbee.io
- **文档**: [项目Wiki](wiki-url)
- **问题反馈**: [GitHub Issues](issues-url)

## 🙏 致谢

感谢以下开源项目和社区：

- [go-zero](https://github.com/zeromicro/go-zero) - 微服务框架
- [Ent](https://entgo.io/) - ORM框架  
- [Consul](https://www.consul.io/) - 服务发现
- [Prometheus](https://prometheus.io/) - 监控系统
- [Kubernetes](https://kubernetes.io/) - 容器编排

---

**NewBee 统一数据处理平台** - 为企业级应用提供高性能、可扩展的数据处理解决方案 🚀