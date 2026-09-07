# ChatMock for fnOS

<p align="center">
  <img src="packaging/fnos/ICON_256.PNG" width="128" alt="ChatMock for fnOS icon">
</p>

将 [RayBytes/ChatMock](https://github.com/RayBytes/ChatMock) 封装为可在飞牛 fnOS 应用中心手动安装的 Docker FPK。

> [!IMPORTANT]
> 这是社区维护的 fnOS 打包项目，不是 RayBytes、飞牛或 OpenAI 的官方发布。FPK 不包含或修改 ChatMock 源码，运行时直接拉取上游 `storagetime/chatmock:latest` 镜像。

## 功能

- 在飞牛应用中心安装、启动、停止和卸载
- 支持 x86_64（AMD64）与 ARM64 飞牛设备
- 将认证数据持久化到 fnOS 应用数据目录
- 使用设备码完成无头 NAS OAuth 登录，无需处理 localhost 回调
- 提供健康检查、状态说明页和快捷登录脚本
- 默认在 `8000` 端口提供 OpenAI 与 Ollama 兼容 API

## 环境要求

- 飞牛 fnOS 1.2.0 或更高版本
- 已安装并启用 Docker
- NAS 能访问 Docker Hub 与 OpenAI 登录服务
- 拥有飞牛管理员和 SSH 权限
- 可用于 Codex 的 ChatGPT 账号

## 安装

1. 从 [Releases](https://github.com/youlan2333/ChatMock-fnOS/releases) 下载最新 `.fpk`。
2. 打开飞牛「应用中心」→「手动安装」。
3. 选择下载的 FPK，按向导完成安装。
4. 等待 Docker 拉取 `storagetime/chatmock:latest`。

也可以通过 SSH 安装：

```bash
sudo appcenter-cli install-fpk ChatMock-1.0.2-fnOS-all.fpk
```

## 首次登录

安装后，通过 SSH 执行：

```bash
sudo bash /var/apps/chatmock-fnos/target/login.sh
```

终端会显示 OpenAI 授权网址和设备代码。打开网址、输入代码并确认；登录成功后脚本会自动重启 ChatMock API 服务。

认证文件位于 fnOS 应用数据目录，通过以下挂载保存在容器的 `/data`：

```text
/var/apps/chatmock-fnos/var/data → /data
```

## 客户端配置

| 配置项 | 值 |
| --- | --- |
| OpenAI Base URL | `http://飞牛IP:8000/v1` |
| API Key | 任意非空值，例如 `sk-chatmock` |
| 模型 | 从 `/v1/models` 返回结果中选择 |
| Ollama 地址 | `http://飞牛IP:8000` |

检查服务：

```bash
curl http://飞牛IP:8000/health
curl http://飞牛IP:8000/v1/models
```

不要从旧文档中直接复制 `gpt-5-codex` 等固定模型名。ChatMock 会根据登录账号动态发现模型，应先读取 `/v1/models`。下面的命令会自动选择列表中的第一个模型进行测试：

```bash
MODEL=$(curl -s http://localhost:8000/v1/models | jq -r '.data[0].id')

curl -s http://localhost:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "$(jq -n \
    --arg model "$MODEL" \
    '{model:$model,messages:[{role:"user",content:"Hello world!"}]}')" | jq .
```

## 常用维护命令

查看日志：

```bash
sudo docker logs --tail 100 -f chatmock-fnos
```

重新登录：

```bash
sudo bash /var/apps/chatmock-fnos/target/login.sh
```

重启服务：

```bash
sudo docker restart chatmock-fnos
```

## 安全提示

当前 FPK 没有为入站 API 配置独立的访问令牌。建议仅在可信局域网、Tailscale 等私有网络内使用；不要直接在路由器上将 `8000` 端口转发到公网。需要公网访问时，应在前面部署带身份验证和 HTTPS 的反向代理。

OAuth 文件包含敏感凭据。不要备份到公开目录，也不要提交到 Git 仓库。

## 已知限制与上游问题

- 上游明确表示账号风险尚无确定结论；请合理使用并自行承担风险：[Issue #19](https://github.com/RayBytes/ChatMock/issues/19)。
- 显式设置 `reasoning.effort: none` 可能被重写为 `low`：[Issue #116](https://github.com/RayBytes/ChatMock/issues/116)。
- n8n 的 Agent/工具调用仍可能存在兼容问题；可暂用 HTTP Request 节点直接调用 API：[Issue #86](https://github.com/RayBytes/ChatMock/issues/86)。
- 异步 API 的结构化输出支持尚未明确：[Issue #76](https://github.com/RayBytes/ChatMock/issues/76)。
- GPT Image 生成目前不受支持：[Issue #109](https://github.com/RayBytes/ChatMock/issues/109)。
- OpenAI 上游接口变化可能暂时导致令牌失效；请先更新镜像并重新登录：[Issue #112](https://github.com/RayBytes/ChatMock/issues/112)。

上游曾出现远程 Docker OAuth 回调与认证数据持久化问题，分别见 [Issue #26](https://github.com/RayBytes/ChatMock/issues/26) 和 [Issue #68](https://github.com/RayBytes/ChatMock/issues/68)。本 FPK 使用设备码登录，并将 `/data` 映射到 fnOS 持久化目录，以规避这两类部署问题。

## 故障排查

### 镜像拉取失败

确认 NAS 可以访问 Docker Hub，然后尝试：

```bash
sudo docker pull storagetime/chatmock:latest
```

### 返回认证错误

重新运行登录脚本：

```bash
sudo bash /var/apps/chatmock-fnos/target/login.sh
```

### 端口 8000 被占用

当前 FPK 使用固定端口 `8000`。请先停止占用该端口的服务。后续版本计划加入安装向导端口配置。

### 应用显示运行但请求失败

健康检查只表示 HTTP 服务已启动，不代表 OAuth 一定有效。请查看容器日志并重新登录。

### 返回 `Upstream error`

先确认请求中的模型 ID 存在于当前账号的动态模型列表：

```bash
curl -s http://localhost:8000/v1/models | jq -r '.data[].id'
```

旧示例中的 `gpt-5-codex` 可能已经不可用。请改用上述命令实际返回的模型，例如 `gpt-5.6-sol`、`gpt-5.6-terra` 或其他当前账号可用值。

## 从源码构建

下载飞牛官方 `fnpack 1.2.3`，然后执行：

```bash
fnpack build --directory packaging/fnos
```

仓库的 GitHub Actions 会使用飞牛官方 Windows AMD64 版 `fnpack 1.2.3` 构建，并核对工具 SHA-256：

```text
D7AF4BD716B009C58F5BCD931615F39DB121E7D4B75DC759E575C4FB2879B6EE
```

FPK 结构遵循[飞牛应用开放平台文档](https://developer.fnnas.com/docs/guide)，Docker 配置参考上游的 [DOCKER.md](https://github.com/RayBytes/ChatMock/blob/main/DOCKER.md)。

## 项目结构

```text
packaging/fnos/
├── app/
│   ├── docker/docker-compose.yaml
│   ├── login.sh
│   ├── ui/
│   └── www/
├── cmd/
├── config/
├── wizard/
├── manifest
├── ICON.PNG
└── ICON_256.PNG
```

## 更新策略

FPK 当前跟随 `storagetime/chatmock:latest`。重建容器时可能拉取到新的上游版本，因此更新前建议查看 [ChatMock 提交记录](https://github.com/RayBytes/ChatMock/commits/main)和 [Issues](https://github.com/RayBytes/ChatMock/issues)。

## 许可与致谢

- ChatMock 上游由 [RayBytes](https://github.com/RayBytes) 维护，采用 MIT License。
- 本仓库仅维护 fnOS 打包、安装脚本和说明文件。
- ChatMock 与 OpenAI 没有隶属关系。
