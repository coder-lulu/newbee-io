# 文件保护快速参考卡 🛡️

## 🚨 3秒检查法

```bash
# 检查文件是否可以修改
head -5 <文件路径> | grep -E "Code generated|DO NOT EDIT"
```

- **有输出** = ❌ **禁止修改**
- **无输出** = ✅ **可以修改**

---

## 📋 常见文件速查表

| 文件 | 能否修改？ | 说明 |
|------|-----------|------|
| `service_context.go` | ✅ **可以** | 永远安全 |
| `io_server.go` | ❌ **禁止** | 每次make覆盖 |
| `routes.go` | ❌ **禁止** | 每次make覆盖 |
| `*_logic.go` | ✅ **可以** | 业务逻辑 |
| `*.pb.go` | ❌ **禁止** | protobuf生成 |
| `config.go` | ✅ **可以** | 配置定义 |
| `ent/schema/*.go` | ✅ **可以** | 数据模型 |
| `ent/*.go` (其他) | ❌ **禁止** | ORM生成 |

---

## 🎯 记住这个架构

```
HTTP/gRPC Request
       ↓
❌ io_server.go/routes.go (自动生成 - 不要改)
       ↓
✅ *_logic.go (业务逻辑 - 放心改)
       ↓
✅ service_context.go (依赖注入 - 放心改)
```

---

## ⚠️ 最常见错误

### 错误1: 在io_server.go添加验证

```go
// ❌ 错误 - 会被覆盖
func (s *IoServer) CreateXXX(...) {
    if input == nil { return error }
    ...
}
```

**✅ 正确做法**: 在 `internal/logic/xxx/create_xxx_logic.go` 中添加

---

### 错误2: 修改routes.go添加中间件

```go
// ❌ 错误 - routes.go会被覆盖
server.Use(MyMiddleware)
```

**✅ 正确做法**: 在 `service_context.go` 中配置中间件

---

## 🔧 Make命令前后必做

### 执行make前
```bash
git add . && git commit -m "make前备份"
```

### 执行make后
```bash
git diff                                    # 检查所有变更
git diff rpc/internal/svc/service_context.go  # 确认未被修改
git diff rpc/internal/logic/                  # 确认logic未被覆盖
go build -v .                               # 确保编译通过
```

---

## 💡 需要扩展功能？

| 需求 | 正确位置 |
|------|---------|
| 添加验证逻辑 | `*_logic.go` |
| 添加统一拦截器 | `service_context.go` |
| 添加自定义服务 | `service_context.go` |
| 修改数据模型 | `ent/schema/*.go` |
| 添加新接口 | 修改 `.proto` 或 `.api`，然后 `make gen-*` |

---

## 📚 详细文档

- 完整清单: `AUTO_GENERATED_FILES_LIST.md`
- 安全分析: `MAKE_COMMAND_SAFETY_ANALYSIS.md`
- 编码准则: `/opt/code/newbee/CLAUDE.md`

---

**记住**: 看到 `DO NOT EDIT`，就不要动！
