# Unified-IO API使用文档

版本: v1.0  
更新时间: 2025-10-01  
基础URL: `http://localhost:9100`

---

## 目录

1. [概述](#概述)
2. [认证](#认证)
3. [通用说明](#通用说明)
4. [数据目标管理 (DataTarget)](#数据目标管理)
5. [Worker性能监控 (WorkerMetrics)](#worker性能监控)
6. [发现模板管理 (DiscoveryTemplate)](#发现模板管理)
7. [错误处理](#错误处理)
8. [最佳实践](#最佳实践)

---

## 概述

Unified-IO是NewBee平台的统一输入输出服务，提供自动发现、数据采集、数据转换和输出功能。本文档描述了服务的RESTful API接口。

### 核心功能模块

- **DataTarget**: 数据目标抽象，支持数据库、API、消息队列、文件系统
- **WorkerMetrics**: Worker性能监控，实时采集CPU、内存、吞吐率等指标
- **DiscoveryTemplate**: 发现模板管理，可复用的数据发现配置
- **DiscoveryPool**: 发现池管理，数据发现任务调度
- **InputTask**: 输入任务管理，数据采集任务
- **OutputTask**: 输出任务管理，数据输出任务
- **FieldMapping**: 字段映射管理，数据转换规则

---

## 认证

所有API请求都需要JWT认证（公共接口除外）。

### 获取Token

```bash
POST /user/login
Content-Type: application/json

{
  "username": "admin",
  "password": "password123"
}

# 响应
{
  "code": 0,
  "msg": "登录成功",
  "data": {
    "token": "eyJhbGc....",
    "expire": 1704067200
  }
}
```

### 使用Token

在所有需要认证的请求中添加Authorization头：

```bash
Authorization: Bearer eyJhbGc....
```

---

## 通用说明

### 请求格式

- **Content-Type**: `application/json`
- **方法**: POST（所有接口）
- **编码**: UTF-8

### 响应格式

#### 成功响应

```json
{
  "code": 0,
  "msg": "操作成功",
  "data": { ... }
}
```

#### 错误响应

```json
{
  "code": 500,
  "msg": "错误描述",
  "data": null
}
```

### 分页参数

```json
{
  "page": 1,
  "pageSize": 10
}
```

### 分页响应

```json
{
  "total": 100,
  "data": [ ... ]
}
```

---

## 数据目标管理

DataTarget是数据输出目标的抽象，支持4种目标类型。

### 1. 创建数据目标

**接口**: `POST /data_target/create`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| targetName | string | 是 | 目标名称，最长100字符 |
| targetType | string | 是 | 目标类型：database_table/api_endpoint/message_queue/file_system |
| targetSchema | string | 否 | 目标结构定义（JSON字符串） |
| validationRules | string | 否 | 验证规则（JSON字符串） |
| uniqueKeys | string | 否 | 唯一键字段列表（JSON字符串） |
| connectionConfig | string | 否 | 连接配置（JSON字符串） |
| description | string | 否 | 目标描述，最长500字符 |
| metadata | string | 否 | 扩展元数据（JSON字符串） |

**请求示例**:

```bash
curl -X POST http://localhost:9100/data_target/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "targetName": "MySQL用户表",
    "targetType": "database_table",
    "targetSchema": "{\"table\":\"users\",\"columns\":[{\"name\":\"id\",\"type\":\"int\"},{\"name\":\"name\",\"type\":\"varchar\"}]}",
    "connectionConfig": "{\"host\":\"localhost\",\"port\":3306,\"database\":\"test\"}",
    "description": "MySQL数据库用户表",
    "uniqueKeys": "[\"id\"]"
  }'
```

**响应示例**:

```json
{
  "code": 0,
  "msg": "创建成功"
}
```

---

### 2. 更新数据目标

**接口**: `POST /data_target/update`

**请求参数**: 与创建接口相同，需额外提供：

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| id | uint64 | 是 | 目标ID |

**请求示例**:

```bash
curl -X POST http://localhost:9100/data_target/update \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "id": 1,
    "targetName": "MySQL用户表（更新）",
    "description": "更新后的描述"
  }'
```

---

### 3. 删除数据目标

**接口**: `POST /data_target/delete`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| id | uint64 | 是 | 目标ID |

**请求示例**:

```bash
curl -X POST http://localhost:9100/data_target/delete \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "id": 1
  }'
```

---

### 4. 查询数据目标详情

**接口**: `POST /data_target/info`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| id | uint64 | 是 | 目标ID |

**请求示例**:

```bash
curl -X POST http://localhost:9100/data_target/info \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "id": 1
  }'
```

**响应示例**:

```json
{
  "code": 0,
  "msg": "查询成功",
  "data": {
    "id": 1,
    "createdAt": 1704067200,
    "updatedAt": 1704067200,
    "status": 1,
    "tenantId": 1,
    "targetName": "MySQL用户表",
    "targetType": "database_table",
    "targetSchema": "{...}",
    "validationRules": "[...]",
    "uniqueKeys": "[\"id\"]",
    "connectionConfig": "{...}",
    "description": "MySQL数据库用户表",
    "metadata": "{}"
  }
}
```

---

### 5. 查询数据目标列表

**接口**: `POST /data_target/list`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| page | uint64 | 是 | 页码，从1开始 |
| pageSize | uint64 | 是 | 每页数量 |
| targetType | string | 否 | 目标类型过滤 |
| keyword | string | 否 | 关键词搜索（名称/描述） |

**请求示例**:

```bash
curl -X POST http://localhost:9100/data_target/list \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "page": 1,
    "pageSize": 10,
    "targetType": "database_table"
  }'
```

**响应示例**:

```json
{
  "code": 0,
  "msg": "查询成功",
  "data": {
    "total": 25,
    "data": [
      {
        "id": 1,
        "targetName": "MySQL用户表",
        "targetType": "database_table",
        ...
      },
      ...
    ]
  }
}
```

---

## Worker性能监控

WorkerMetrics用于采集Worker的实时性能指标。

### 1. 创建性能指标

**接口**: `POST /worker_metrics/create`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| workerId | uint64 | 是 | Worker ID |
| cpuUsagePercent | float64 | 是 | CPU使用率（0-100） |
| memoryUsagePercent | float64 | 是 | 内存使用率（0-100） |
| currentTaskCount | int64 | 是 | 当前任务数 |
| throughputRate | float64 | 是 | 吞吐率（记录/秒） |
| metadata | string | 否 | 扩展元数据（JSON字符串） |

**请求示例**:

```bash
curl -X POST http://localhost:9100/worker_metrics/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "workerId": 1,
    "cpuUsagePercent": 65.5,
    "memoryUsagePercent": 78.3,
    "currentTaskCount": 15,
    "throughputRate": 250.5,
    "metadata": "{\"node\":\"worker-node-01\"}"
  }'
```

**响应示例**:

```json
{
  "code": 0,
  "msg": "创建成功"
}
```

---

### 2. 查询性能指标详情

**接口**: `POST /worker_metrics/info`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| id | uint64 | 是 | 指标ID |

**请求示例**:

```bash
curl -X POST http://localhost:9100/worker_metrics/info \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "id": 1
  }'
```

**响应示例**:

```json
{
  "code": 0,
  "msg": "查询成功",
  "data": {
    "id": 1,
    "createdAt": 1704067200,
    "updatedAt": 1704067200,
    "tenantId": 1,
    "workerId": 1,
    "cpuUsagePercent": 65.5,
    "memoryUsagePercent": 78.3,
    "currentTaskCount": 15,
    "throughputRate": 250.5,
    "metricTime": 1704067200
  }
}
```

---

### 3. 查询性能指标列表

**接口**: `POST /worker_metrics/list`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| page | uint64 | 是 | 页码 |
| pageSize | uint64 | 是 | 每页数量 |
| workerId | uint64 | 否 | Worker ID过滤 |
| startTime | int64 | 否 | 开始时间（Unix时间戳） |
| endTime | int64 | 否 | 结束时间（Unix时间戳） |

**请求示例**:

```bash
curl -X POST http://localhost:9100/worker_metrics/list \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "page": 1,
    "pageSize": 50,
    "workerId": 1,
    "startTime": 1704060000,
    "endTime": 1704067200
  }'
```

**响应示例**:

```json
{
  "code": 0,
  "msg": "查询成功",
  "data": {
    "total": 120,
    "data": [
      {
        "id": 1,
        "workerId": 1,
        "cpuUsagePercent": 65.5,
        "memoryUsagePercent": 78.3,
        ...
      },
      ...
    ]
  }
}
```

---

## 发现模板管理

DiscoveryTemplate是可复用的数据发现配置模板。

### 1. 创建发现模板

**接口**: `POST /discovery_template/create`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| templateName | string | 是 | 模板名称，最长100字符 |
| templateCode | string | 是 | 模板编码，唯一，最长64字符 |
| templateType | string | 是 | 模板类型：file/api/sdk/builtin |
| description | string | 否 | 模板描述，最长500字符 |
| version | string | 否 | 模板版本，默认1.0.0 |
| discoveryConfig | string | 否 | 发现配置模板（JSON字符串） |
| fieldMappingTemplates | string | 否 | 字段映射模板（JSON数组字符串） |
| validationRules | string | 否 | 验证规则模板（JSON数组字符串） |
| isPublic | bool | 否 | 是否公开，默认false |
| isSystem | bool | 否 | 是否系统模板，默认false |
| tags | string | 否 | 标签（JSON数组字符串） |
| metadata | string | 否 | 扩展元数据（JSON字符串） |

**请求示例**:

```bash
curl -X POST http://localhost:9100/discovery_template/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "templateName": "Excel用户导入模板",
    "templateCode": "excel_user_import_v1",
    "templateType": "file",
    "description": "从Excel文件导入用户数据",
    "version": "1.0.0",
    "discoveryConfig": "{\"fileType\":\"excel\",\"sheetName\":\"users\"}",
    "fieldMappingTemplates": "[{\"sourceField\":\"姓名\",\"targetField\":\"name\"},{\"sourceField\":\"邮箱\",\"targetField\":\"email\"}]",
    "isPublic": true,
    "tags": "[\"用户\",\"Excel\",\"导入\"]"
  }'
```

**响应示例**:

```json
{
  "code": 0,
  "msg": "创建成功"
}
```

---

### 2. 更新发现模板

**接口**: `POST /discovery_template/update`

**请求参数**: 与创建接口相同，需额外提供：

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| id | uint64 | 是 | 模板ID |

**请求示例**:

```bash
curl -X POST http://localhost:9100/discovery_template/update \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "id": 1,
    "version": "1.1.0",
    "description": "更新后的描述"
  }'
```

---

### 3. 删除发现模板

**接口**: `POST /discovery_template/delete`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| id | uint64 | 是 | 模板ID |

**请求示例**:

```bash
curl -X POST http://localhost:9100/discovery_template/delete \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "id": 1
  }'
```

---

### 4. 查询发现模板详情

**接口**: `POST /discovery_template/info`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| id | uint64 | 是 | 模板ID |

**请求示例**:

```bash
curl -X POST http://localhost:9100/discovery_template/info \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "id": 1
  }'
```

**响应示例**:

```json
{
  "code": 0,
  "msg": "查询成功",
  "data": {
    "id": 1,
    "createdAt": 1704067200,
    "updatedAt": 1704067200,
    "status": 1,
    "tenantId": 1,
    "templateName": "Excel用户导入模板",
    "templateCode": "excel_user_import_v1",
    "templateType": "file",
    "description": "从Excel文件导入用户数据",
    "version": "1.0.0",
    "discoveryConfig": "{...}",
    "fieldMappingTemplates": "[...]",
    "validationRules": "[...]",
    "isPublic": true,
    "isSystem": false,
    "usageCount": 15,
    "tags": "[\"用户\",\"Excel\",\"导入\"]",
    "metadata": "{}"
  }
}
```

---

### 5. 查询发现模板列表

**接口**: `POST /discovery_template/list`

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| page | uint64 | 是 | 页码 |
| pageSize | uint64 | 是 | 每页数量 |
| templateType | string | 否 | 模板类型过滤 |
| isPublic | bool | 否 | 是否公开过滤 |
| isSystem | bool | 否 | 是否系统模板过滤 |
| keyword | string | 否 | 关键词搜索 |

**请求示例**:

```bash
curl -X POST http://localhost:9100/discovery_template/list \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "page": 1,
    "pageSize": 10,
    "templateType": "file",
    "isPublic": true
  }'
```

**响应示例**:

```json
{
  "code": 0,
  "msg": "查询成功",
  "data": {
    "total": 8,
    "data": [
      {
        "id": 1,
        "templateName": "Excel用户导入模板",
        "templateCode": "excel_user_import_v1",
        "templateType": "file",
        "isPublic": true,
        "usageCount": 15,
        ...
      },
      ...
    ]
  }
}
```

---

## 错误处理

### HTTP状态码

- `200 OK`: 请求成功
- `400 Bad Request`: 请求参数错误
- `401 Unauthorized`: 未认证或Token过期
- `403 Forbidden`: 无权限访问
- `404 Not Found`: 资源不存在
- `500 Internal Server Error`: 服务器内部错误

### 错误码说明

| code | 说明 |
|------|------|
| 0 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未认证 |
| 403 | 无权限 |
| 404 | 资源不存在 |
| 500 | 服务器错误 |
| 1001 | 数据验证失败 |
| 1002 | 数据库操作失败 |
| 1003 | 租户隔离违规 |

### 错误响应示例

```json
{
  "code": 400,
  "msg": "目标名称不能为空",
  "data": null
}
```

---

## 最佳实践

### 1. 租户隔离

所有API自动进行租户隔离，确保数据安全：

```bash
# 租户1的用户只能访问租户1的数据
# 租户2的用户只能访问租户2的数据
```

### 2. 分页查询

建议每页数量不超过100条：

```json
{
  "page": 1,
  "pageSize": 50  // 推荐: 20-50
}
```

### 3. 性能监控采集频率

建议采集频率：
- 生产环境: 每30秒
- 开发环境: 每60秒

### 4. 模板编码规范

```
{service}_{entity}_{version}
例如: excel_user_import_v1
```

### 5. JSON字段规范

所有JSON字符串字段应使用合法的JSON格式：

```json
{
  "targetSchema": "{\"table\":\"users\",\"columns\":[{\"name\":\"id\",\"type\":\"int\"}]}"
}
```

### 6. 唯一键配置

使用JSON数组格式：

```json
{
  "uniqueKeys": "[\"id\"]"
}
```

### 7. 错误重试策略

建议使用指数退避重试：
- 第1次: 立即重试
- 第2次: 1秒后重试
- 第3次: 2秒后重试
- 第4次: 4秒后重试

### 8. Token管理

- Token有效期: 7天
- 建议提前1小时刷新Token
- 使用Token缓存减少认证请求

---

## 附录

### A. 数据类型枚举

#### TargetType（目标类型）
- `database_table`: 数据库表
- `api_endpoint`: API接口
- `message_queue`: 消息队列
- `file_system`: 文件系统

#### TemplateType（模板类型）
- `file`: 文件类型
- `api`: API类型
- `sdk`: SDK类型
- `builtin`: 内置类型

### B. 时间格式

所有时间字段使用Unix时间戳（秒）：

```json
{
  "createdAt": 1704067200,  // 2024-01-01 00:00:00 UTC
  "metricTime": 1704070800  // 2024-01-01 01:00:00 UTC
}
```

### C. 联系方式

- **技术支持**: support@newbee.com
- **API问题**: api@newbee.com
- **文档反馈**: docs@newbee.com

---

**文档版本**: v1.0  
**最后更新**: 2025-10-01  
**维护团队**: NewBee Platform Team
