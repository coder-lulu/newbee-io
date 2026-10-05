# Newbee IO 公共模块

本仓库保存 IO provider 公共接口、实现、迁移脚本、示例和设计文档。
Go 模块路径为 `github.com/coder-lulu/newbee-io`。

API 和 RPC 服务分别通过 Git 子模块引用：

- `api`：`https://github.com/coder-lulu/newbee-io-api`
- `rpc`：`https://github.com/coder-lulu/newbee-io-rpc`

```sh
git clone --recurse-submodules https://github.com/coder-lulu/newbee-io.git
```

完整本地开发工作区见 `https://github.com/coder-lulu/newbee`。
运行配置由各服务的 `etc/*.yaml.example` 复制后填写，真实凭据保留在本地。
