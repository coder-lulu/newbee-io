# 发现配置服务依赖分析

**分析时间**: 2025-12-16
**场景**: 在CMDB的CI类型页面创建新的发现配置
**页面路径**: `/opt/code/newbee/ui/apps/web-antd/src/views/cmdb/ci_types/components/discovery/`

---

## 🎯 核心结论

**创建发现配置时，需要启动以下4个核心服务**：

| 服务 | 端口 | 用途 | 优先级 |
|------|------|------|--------|
| **core.rpc** | 9100 | 用户认证、菜单权限 | 🔴 必须 |
| **core.api** | 9101 | JWT认证、租户检查 | 🔴 必须 |
| **unified-io.rpc** | 9500 | 发现池、发现Provider RPC服务 | 🔴 必须 |
| **unified-io.api** | 9501 | 发现池、发现Provider HTTP API | 🔴 必须 |
| **ops-center.rpc** | 9600 | Agent管理RPC服务 | 🟡 可选* |
| **ops-center.api** | 9402 | Agent列表API | 🟡 可选* |
| **cmdb.rpc** | 9200 | CMDB类型管理RPC | 🟢 后台 |
| **cmdb.api** | 9201 | CMDB类型管理API | 🟢 后台 |
| **web-antd** | 5173 | 前端UI (开发模式) | 🔴 必须 |

**注**：ops-center服务目前使用mock数据，功能降级可用，但未来需要真实Agent数据时必须启动。

---

## 📊 API调用流程分析

### 第1步：选择发现方式 (DiscoveryMethodSelector.vue)

**API调用**：
```typescript
import { DiscoveryProviderAPI } from '#/api/io/discovery-provider';

// 获取所有Provider列表
DiscoveryProviderAPI.listProviders()
```

**后端接口**：
- **路径**: `POST /io-api/discoveryprovider/list_discovery_providers`
- **实际调用**: `http://127.0.0.1:9501/discoveryprovider/list_discovery_providers`
- **服务**: `unified-io.api` (端口9501)
- **依赖**:
  - `unified-io.rpc` (端口9500) - 处理实际业务逻辑
  - `core.rpc` (端口9100) - 租户隔离、认证

**返回数据示例**：
```json
[
  {
    "id": "snmp_v2",
    "name": "SNMP v2",
    "category": "network",
    "description": "通过SNMP协议发现网络设备"
  },
  {
    "id": "vmware_vcenter",
    "name": "VMware vCenter",
    "category": "virtualization",
    "description": "通过vCenter API发现虚拟机"
  }
]
```

---

### 第2步：配置发现参数 (DiscoveryParameterConfig.vue)

**API调用**：
```typescript
// 获取选中Provider的Schema
DiscoveryProviderAPI.getProviderSchema(providerId)

// 测试连接
DiscoveryProviderAPI.testConnection({
  providerId: 'snmp_v2',
  config: { host: '192.168.1.1', community: 'public' }
})
```

**后端接口**：

1. **获取Provider Schema**
   - **路径**: `POST /io-api/discoveryprovider/get_provider_schema`
   - **参数**: `{ provider_id: "snmp_v2" }`
   - **服务**: `unified-io.api:9501` → `unified-io.rpc:9500`
   - **返回**: 参数定义、字段定义、执行模式

2. **测试Provider连接**
   - **路径**: `POST /io-api/discoveryprovider/test_provider_connection`
   - **参数**: `{ provider_id, config }`
   - **服务**: `unified-io.api:9501` → `unified-io.rpc:9500`
   - **返回**: `{ success: true/false, message: "..." }`

**返回Schema示例**：
```json
{
  "providerId": "snmp_v2",
  "parameterSchema": [
    {
      "name": "host",
      "label": "目标主机",
      "type": "string",
      "required": true,
      "placeholder": "192.168.1.1"
    },
    {
      "name": "community",
      "label": "Community字符串",
      "type": "string",
      "required": true,
      "defaultValue": "public"
    }
  ],
  "fieldSchema": [
    {
      "name": "hostname",
      "label": "主机名",
      "dataType": "string",
      "required": true
    },
    {
      "name": "ip_address",
      "label": "IP地址",
      "dataType": "string",
      "required": true
    }
  ]
}
```

---

### 第3步：选择执行代理 (AgentSelector.vue)

**当前状态**: ⚠️ 使用Mock数据

**代码现状**：
```typescript
const loadAgents = async () => {
  // TODO: 调用ops-center API获取代理列表
  // const response = await getAgentList({ status: 'online' });

  // 模拟数据
  agents.value = [
    {
      id: 'agent-001',
      name: 'OPS-Agent-Beijing-01',
      host: '10.0.1.10',
      status: 'online',
      os: 'Linux',
      version: '1.0.5',
      tags: ['生产环境', '华北'],
    },
    // ...更多Mock数据
  ];
}
```

**未来需要的API调用**：
- **路径**: `POST /ops-api/agent/list` (待实现)
- **参数**: `{ status: 'online' }`
- **服务**: `ops-center.api:9402` → `ops-center.rpc:9600`

**前端代理配置**：
```typescript
// vite.config.mts
'/ops-api': {
  target: 'http://127.0.0.1:9402',  // ⚠️ 注意：与ops.yaml中的端口不一致
  rewrite: (path) => path.replace(/^\/ops-api/, '')
}
```

**服务配置冲突**：
- vite.config.mts 配置: `9402`
- ops.yaml 配置: `9410`
- **需要确认**: 实际运行的ops-center.api服务端口

---

### 第4步：配置属性映射 (AttributeMappingConfig.vue)

**API调用**：
```typescript
// 获取Provider的字段Schema（复用第2步的Schema数据）
DiscoveryProviderAPI.getProviderSchema(providerId)
```

**映射逻辑**：
- 左侧：Provider的fieldSchema（来源字段）
- 右侧：CI类型的属性列表（目标字段）
- 用户手动配置映射关系：`source_field → target_attr`

**服务**: 复用第2步的API，无需额外服务

---

### 第5步：完成配置 (DiscoveryWizardModal.vue)

**API调用**：
```typescript
import { createDiscoveryPool } from '#/api/io/discovery-pool';

// 创建发现池
await createDiscoveryPool({
  name: '网络设备发现池',
  ci_type_id: 123,
  provider_id: 'snmp_v2',
  agent_id: 'agent-001',
  config: { host: '192.168.1.0/24', community: 'public' },
  field_mapping: {
    hostname: 'name',
    ip_address: 'management_ip',
  },
  schedule_enabled: true,
  schedule_interval: 3600,
})
```

**后端接口**：
- **路径**: `POST /io-api/discovery_pool/create`
- **实际调用**: `http://127.0.0.1:9501/discovery_pool/create`
- **服务链**:
  1. `unified-io.api:9501` (HTTP入口)
  2. `unified-io.rpc:9500` (业务逻辑)
  3. 数据库操作 (MySQL)
- **认证链**: `core.api:9101` (JWT) → `core.rpc:9100` (租户验证)

**请求体结构**：
```protobuf
message CreateDiscoveryPoolReq {
  string name = 1;
  uint64 ci_type_id = 2;
  string provider_id = 3;
  string agent_id = 4;
  google.protobuf.Struct config = 5;
  google.protobuf.Struct field_mapping = 6;
  bool schedule_enabled = 7;
  uint32 schedule_interval = 8;
  optional string description = 9;
}
```

---

## 🔧 服务启动顺序

### 推荐启动顺序（从下到上）

```
┌─────────────────────────────────────────┐
│  5. 前端服务                            │
│  web-antd:5173 (pnpm dev)              │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────┴───────────────────────┐
│  4. API网关层                           │
│  ├─ core.api:9101                      │
│  ├─ unified-io.api:9501                │
│  ├─ cmdb.api:9201                      │
│  └─ ops-center.api:9402 (可选)         │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────┴───────────────────────┐
│  3. RPC服务层                           │
│  ├─ core.rpc:9100                      │
│  ├─ unified-io.rpc:9500                │
│  ├─ cmdb.rpc:9200                      │
│  └─ ops-center.rpc:9600 (可选)         │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────┴───────────────────────┐
│  2. 数据层                              │
│  ├─ MySQL:3306                         │
│  └─ Redis:6380                         │
└─────────────────────────────────────────┘
                  │
┌─────────────────┴───────────────────────┐
│  1. 基础设施（已存在）                   │
│  └─ 网络、磁盘、操作系统                │
└─────────────────────────────────────────┘
```

### 详细启动命令

#### 步骤1: 启动基础设施（如果未运行）
```bash
# MySQL
systemctl start mysql

# Redis
systemctl start redis
```

#### 步骤2: 启动RPC服务（并行）
```bash
# 终端1: Core RPC
cd /opt/code/newbee/core/rpc
go run core.go

# 终端2: Unified-IO RPC
cd /opt/code/newbee/unified-io/rpc
go run io.go

# 终端3: CMDB RPC
cd /opt/code/newbee/cmdb/rpc
go run cmdb.go

# 终端4: OPS-Center RPC (可选)
cd /opt/code/newbee/ops-center/rpc
go run ops.go
```

#### 步骤3: 启动API服务（并行，等待RPC启动完成）
```bash
# 终端5: Core API
cd /opt/code/newbee/core/api
go run core.go

# 终端6: Unified-IO API
cd /opt/code/newbee/unified-io/api
go run io.go

# 终端7: CMDB API
cd /opt/code/newbee/cmdb/api
go run cmdb.go

# 终端8: OPS-Center API (可选)
cd /opt/code/newbee/ops-center/api
go run ops.go
```

#### 步骤4: 启动前端（等待API服务完全启动）
```bash
# 终端9: 前端开发服务器
cd /opt/code/newbee/ui/apps/web-antd
pnpm dev
```

#### 步骤5: 访问应用
```
浏览器访问: http://localhost:5173
登录后进入: CMDB -> CI类型管理 -> 选择CI类型 -> 新建发现配置
```

---

## 🧪 验证服务可用性

### 验证脚本
```bash
#!/bin/bash

echo "=== 服务健康检查 ==="

# 检查RPC服务
check_grpc() {
  local service=$1
  local port=$2
  if grpcurl -plaintext localhost:$port list &>/dev/null; then
    echo "✅ $service ($port) - 运行中"
  else
    echo "❌ $service ($port) - 未运行"
  fi
}

# 检查HTTP服务
check_http() {
  local service=$1
  local port=$2
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/health" | grep -q "200"; then
    echo "✅ $service ($port) - 运行中"
  else
    echo "❌ $service ($port) - 未运行"
  fi
}

# RPC服务检查
check_grpc "core.rpc" 9100
check_grpc "unified-io.rpc" 9500
check_grpc "cmdb.rpc" 9200
check_grpc "ops-center.rpc" 9600

# API服务检查
check_http "core.api" 9101
check_http "unified-io.api" 9501
check_http "cmdb.api" 9201
check_http "ops-center.api" 9402

# 前端检查
if curl -s -o /dev/null "http://localhost:5173"; then
  echo "✅ web-antd (5173) - 运行中"
else
  echo "❌ web-antd (5173) - 未运行"
fi
```

### 手动验证关键接口

**1. 验证Provider列表**
```bash
curl -X POST http://localhost:9501/discoveryprovider/list_discovery_providers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{}'
```

**2. 验证Provider Schema**
```bash
curl -X POST http://localhost:9501/discoveryprovider/get_provider_schema \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"provider_id": "snmp_v2"}'
```

**3. 验证创建发现池**
```bash
curl -X POST http://localhost:9501/discovery_pool/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "name": "测试发现池",
    "ci_type_id": 1,
    "provider_id": "snmp_v2",
    "agent_id": "agent-001",
    "config": {"host": "192.168.1.1"},
    "field_mapping": {"hostname": "name"}
  }'
```

---

## ⚠️ 已知问题与注意事项

### 问题1: OPS-Center API端口不一致
**现象**:
- vite.config.mts 配置端口: `9402`
- ops.yaml 配置端口: `9410`

**影响**: 前端代理无法正确转发到ops-center API

**解决方案**（二选一）:
1. 修改 ops.yaml 中的端口为 9402
2. 修改 vite.config.mts 中的代理端口为 9410

**推荐**: 修改 ops.yaml 为 9402，保持前端配置不变

### 问题2: Agent列表使用Mock数据
**现象**: AgentSelector.vue 中有 TODO 注释，使用硬编码的Mock数据

**影响**:
- 无法获取真实的Agent列表
- 无法根据Agent状态筛选
- Agent信息可能过时

**临时方案**: 使用Mock数据，功能降级可用

**完整方案**:
1. 在 ops-center 服务中实现 Agent 列表API
2. 在前端 `/opt/code/newbee/ui/apps/web-antd/src/api/ops/` 创建 agent.ts
3. 在 AgentSelector.vue 中替换Mock逻辑

### 问题3: 服务启动依赖关系
**现象**: API服务依赖RPC服务，必须按顺序启动

**建议**:
- 使用 docker-compose 统一管理服务启动
- 配置健康检查和依赖关系
- 添加启动脚本自动检测依赖可用性

---

## 📝 配置文件清单

### 服务配置文件路径
| 服务 | 配置文件路径 |
|------|-------------|
| core.rpc | `/opt/code/newbee/core/rpc/etc/core.yaml` |
| core.api | `/opt/code/newbee/core/api/etc/core.yaml` |
| unified-io.rpc | `/opt/code/newbee/unified-io/rpc/etc/io.yaml` |
| unified-io.api | `/opt/code/newbee/unified-io/api/etc/io.yaml` |
| cmdb.rpc | `/opt/code/newbee/cmdb/rpc/etc/cmdb.yaml` |
| cmdb.api | `/opt/code/newbee/cmdb/api/etc/cmdb.yaml` |
| ops-center.rpc | `/opt/code/newbee/ops-center/rpc/etc/ops.yaml` |
| ops-center.api | `/opt/code/newbee/ops-center/api/etc/ops.yaml` |
| web-antd | `/opt/code/newbee/ui/apps/web-antd/vite.config.mts` |

### 关键配置项
```yaml
# 所有服务共享的数据库配置
DatabaseConf:
  Type: mysql
  Host: 192.168.26.130
  Port: 3306
  DBName: newbee
  Username: root
  Password: "123456"

# 所有服务共享的Redis配置
RedisConf:
  Host: 192.168.26.130:6380
  Db: 0
```

---

## 🎯 快速启动脚本

### 创建 start_discovery_services.sh
```bash
#!/bin/bash

# 发现配置服务启动脚本
# 用途: 一键启动所有必需的服务

set -e

NEWBEE_ROOT="/opt/code/newbee"
LOG_DIR="/tmp/newbee-logs"
mkdir -p "$LOG_DIR"

echo "🚀 启动NewBee发现配置所需服务..."
echo ""

# 检查依赖
check_dependency() {
  if ! command -v $1 &> /dev/null; then
    echo "❌ 错误: 未找到 $1，请先安装"
    exit 1
  fi
}

check_dependency go
check_dependency pnpm

# 启动RPC服务
start_rpc() {
  local service=$1
  local path=$2
  local port=$3

  echo "🔵 启动 $service (端口 $port)..."
  cd "$NEWBEE_ROOT/$path"
  nohup go run *.go > "$LOG_DIR/$service.log" 2>&1 &
  echo $! > "$LOG_DIR/$service.pid"
  sleep 2
}

# 启动API服务
start_api() {
  local service=$1
  local path=$2
  local port=$3

  echo "🟢 启动 $service (端口 $port)..."
  cd "$NEWBEE_ROOT/$path"
  nohup go run *.go > "$LOG_DIR/$service.log" 2>&1 &
  echo $! > "$LOG_DIR/$service.pid"
  sleep 2
}

# 1. 启动RPC服务
start_rpc "core.rpc" "core/rpc" 9100
start_rpc "unified-io.rpc" "unified-io/rpc" 9500
start_rpc "cmdb.rpc" "cmdb/rpc" 9200

# 2. 启动API服务
start_api "core.api" "core/api" 9101
start_api "unified-io.api" "unified-io/api" 9501
start_api "cmdb.api" "cmdb/api" 9201

# 3. 启动前端
echo "🎨 启动前端服务 (端口 5173)..."
cd "$NEWBEE_ROOT/ui/apps/web-antd"
nohup pnpm dev > "$LOG_DIR/web-antd.log" 2>&1 &
echo $! > "$LOG_DIR/web-antd.pid"

sleep 5

echo ""
echo "✅ 所有服务已启动完成!"
echo ""
echo "📋 服务列表:"
echo "  - core.rpc:       http://localhost:9100"
echo "  - core.api:       http://localhost:9101"
echo "  - unified-io.rpc: http://localhost:9500"
echo "  - unified-io.api: http://localhost:9501"
echo "  - cmdb.rpc:       http://localhost:9200"
echo "  - cmdb.api:       http://localhost:9201"
echo "  - web-antd:       http://localhost:5173"
echo ""
echo "📝 日志目录: $LOG_DIR"
echo "🛑 停止服务: ./stop_discovery_services.sh"
```

### 创建 stop_discovery_services.sh
```bash
#!/bin/bash

# 发现配置服务停止脚本

LOG_DIR="/tmp/newbee-logs"

echo "🛑 停止所有发现配置服务..."

for pidfile in "$LOG_DIR"/*.pid; do
  if [ -f "$pidfile" ]; then
    service=$(basename "$pidfile" .pid)
    pid=$(cat "$pidfile")

    if kill -0 "$pid" 2>/dev/null; then
      echo "⏹️  停止 $service (PID: $pid)"
      kill "$pid"
    fi

    rm "$pidfile"
  fi
done

echo "✅ 所有服务已停止"
```

### 使用方法
```bash
# 给脚本添加执行权限
chmod +x start_discovery_services.sh
chmod +x stop_discovery_services.sh

# 启动所有服务
./start_discovery_services.sh

# 停止所有服务
./stop_discovery_services.sh

# 查看服务日志
tail -f /tmp/newbee-logs/unified-io.api.log
```

---

## 📚 相关文档

1. **API定义文档**
   - Discovery Pool API: `/opt/code/newbee/unified-io/api/desc/discovery_pool.api`
   - Discovery Provider API: `/opt/code/newbee/unified-io/api/desc/discovery_provider.api`

2. **菜单配置文档**
   - 菜单总结: `/opt/code/newbee/unified-io/migrations/io_menus_summary.md`
   - 前端分析: `/opt/code/newbee/unified-io/migrations/frontend_menu_final_summary.md`

3. **前端组件**
   - 发现向导: `src/views/cmdb/ci_types/components/discovery/DiscoveryWizardModal.vue`
   - 方法选择器: `src/views/cmdb/ci_types/components/discovery/DiscoveryMethodSelector.vue`
   - 参数配置: `src/views/cmdb/ci_types/components/discovery/DiscoveryParameterConfig.vue`
   - Agent选择器: `src/views/cmdb/ci_types/components/discovery/AgentSelector.vue`
   - 属性映射: `src/views/cmdb/ci_types/components/discovery/AttributeMappingConfig.vue`

---

**文档生成时间**: 2025-12-16
**维护人**: NewBee Team
**最后更新**: 2025-12-16
