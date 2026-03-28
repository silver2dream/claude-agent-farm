[English](DISCORD.md) | **简体中文**

# Discord 部署指南

## 创建 Discord Bot

你只需要**一个 Bot** 即可服务所有智能体。一个 Bot 可以服务多个频道。

1. 前往 [Discord 开发者门户](https://discord.com/developers/applications) → **New Application**
2. **Bot** 标签页 → **Reset Token** → 复制并保存 token
3. 在 Privileged Gateway Intents 下启用 **Message Content Intent**
4. **OAuth2 → URL Generator**：scope 选 `bot`，权限：Send Messages、Manage Channels、Embed Links、Add Reactions、Read Message History
5. 打开生成的 URL，将 Bot 添加到你的私有 Discord 服务器

> ⚠️ **妥善保管 Bot token。** 它将以 K8s Secret 形式存储 — 切勿提交到 Git。

---

## 一键安装

```bash
bash setup.sh
```

脚本会引导你完成所有步骤：K3s 安装、Bot token、Guild ID、镜像构建、部署。

<details>
<summary><b>手动安装（分步操作）</b></summary>

### 1. 安装 K3s

```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
```

### 2. 配置

```bash
cp config.example.env config.env
# 编辑 config.env，填入你的 Discord Bot token、Guild ID 和智能体名称
```

### 3. 部署

```bash
make setup
```

</details>

---

## 首次配对

每个智能体需要与 Discord 配对一次。配对后，配置在重启后依然保留。

```bash
# 进入运行中的智能体 Pod
make shell AGENT=my-first-agent

# 在 Pod 中：在 Discord 上私信你的 Bot，获取配对码，然后：
/discord:access pair <配对码>
/discord:access policy allowlist
/discord:access channel add <频道ID>

# 退出 Pod
exit
```

现在在 Discord 频道中给智能体发消息，它会回复。

---

## 添加更多智能体

所有 Discord 智能体共享一个 Bot token — 只需将每个智能体指向不同的频道。

```bash
make new-agent NAME=ci-fix CHANNEL_ID=123456
make apply
```

或手动复制模板：

```bash
cp examples/agent-template.yaml manifests/agents/ci-fix-agent.yaml
# 编辑：修改 AGENT_NAME、CHANNEL_ID
make apply
```

---

## 命令参考

| 命令 | 说明 |
|---|---|
| `bash setup.sh` | 交互式一键安装（安装所有组件） |
| `make setup` | 非交互式安装（需要 config.env） |
| `make deploy` | 将所有清单应用到 K3s |
| `make apply` | 添加/修改智能体后重新应用 |
| `make status` | 查看所有智能体 Pod 及其状态 |
| `make logs AGENT=名称` | 查看指定智能体的日志 |
| `make shell AGENT=名称` | 进入智能体 Pod |
| `make restart AGENT=名称` | 重启智能体（清除上下文） |
| `make new-agent NAME=x CHANNEL_ID=y` | 生成新的智能体 YAML |
| `make destroy` | 移除所有资源 |
