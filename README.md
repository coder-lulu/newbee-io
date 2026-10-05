# 新蜂资产管理平台 — 统一 I/O 工作区与 Provider 接口

组织统一数据接入模块，提供 Go Provider 公共接口及注册机制，并通过 Git 子模块关联 API 和 RPC 服务。Proxy 和统一 I/O RPC 共用此处的 Provider 定义。

仓库：[coder-lulu/newbee-io](https://github.com/coder-lulu/newbee-io) · [平台工作区](https://github.com/coder-lulu/newbee)

## 获取代码

推荐通过完整工作区开发，保留兄弟模块目录及本地 `replace` 依赖。以下命令使用 Bash；Go 工作区要求 Go 1.25.1 或更高版本。

```bash
git clone --recurse-submodules https://github.com/coder-lulu/newbee.git
cd newbee/unified-io
```

已有工作区执行 `git submodule update --init --recursive`。单独克隆模块时，需要自行补齐 `go.mod` 中的本地依赖路径。

## 仓库组成

| 路径 | 用途 |
| --- | --- |
| `provider/` | Provider 元数据、参数、字段、发现接口及注册机制 |
| `api/` | [统一 I/O API](https://github.com/coder-lulu/newbee-io-api)，Git 子模块 |
| `rpc/` | [统一 I/O RPC](https://github.com/coder-lulu/newbee-io-rpc)，Git 子模块 |
| `docs/` | 方案与模块说明 |
| `examples/` | 调度等示例 |
| `migrations/`、`scripts/` | 数据库和维护辅助资料 |

## 开发与验证

顶层 Go 模块为 `github.com/coder-lulu/newbee-io`，它是共享接口库，没有独立可启动的主程序。检查 Provider 包：

```bash
go test ./provider/...
go vet ./provider/...
go build ./provider/...
```

API 和 RPC 是独立模块，应分别在其目录执行构建、配置和运行命令。完整工作区的 `go.work` 已关联它们；不要仅在顶层执行 `go test ./...` 就认为覆盖了所有子模块。示例程序可能需要额外服务和各自依赖。

## 配置和服务启动

先准备数据库、Redis 与 Core/CMDB/Ops 服务，再根据 [RPC README](https://github.com/coder-lulu/newbee-io-rpc#readme) 启动 RPC，随后按 [API README](https://github.com/coder-lulu/newbee-io-api#readme) 启动 API。两者分别使用 `etc/io.yaml.example`，示例端口为 RPC `9500`、API `9501`。公共 Provider 包自身不需要运行配置。

## 文档

- [统一 I/O 文档索引](docs/README.md)
- [定时任务索引](SCHEDULED_TASKS_INDEX.md)
- [示例说明](examples/README.md)

历史设计文档中的路径、能力规划和运行状态应结合当前代码核对。

## 许可证与来源

本仓库采用 [MIT](LICENSE)。API、RPC 子模块分别保留 Apache-2.0，以各自仓库 LICENSE 为准。第三方依赖遵循各自许可证，保留原有版权与许可声明。
