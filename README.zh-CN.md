[English](README.md) | **简体中文** | [繁體中文](README.zh-TW.md)

# 🪐 Claude Agent Farm

**在你自己的机器上运行常驻 Claude Code AI 智能体，通过 Discord 或 Telegram 与它们对话。基于 K3s 构建。**

一个 Bot，多个智能体。每个智能体拥有独立角色、独立聊天频道、独立运行环境。
文件和凭证留在你的机器上，AI 推理走 Anthropic 服务器，对话走 Discord 或 Telegram — 没有第三方代码接触你的数据。

<!-- TODO: 添加演示 GIF -->
<!-- ![demo](docs/demo.gif) -->

---

## 这是什么？

Claude Agent Farm 使用 [K3s](https://k3s.io) 将 [Claude Code Channels](https://code.claude.com/docs/en/channels)（Anthropic 官方聊天插件）部署到你机器上的轻量级 Kubernetes Pod 中。每个智能体：

- 运行在**隔离的 Pod** 中（独立文件系统、网络、资源）
- 连接到**专属的 Discord 频道或 Telegram 聊天**（一个频道 = 一个智能体）
- 崩溃后**自动重启**（K8s 存活探针）
- 数据留在**你的机器上**（文件和凭证在本地；仅 Anthropic API 和聊天平台 API 是外部连接）
- 空闲时**零 Anthropic 配额消耗**

可以把它想象成一个 AI 同事团队，每人各有专长，都能通过手机上的 Discord 或 Telegram 随时联系。

---

## 从零开始（Quick Start）

按顺序一步步来，所有命令都可以直接复制粘贴。

### 第 0 步：准备 Linux 环境

Claude Agent Farm 运行在 Linux 上。根据你的情况选择：

<details>
<summary><b>我用的是 Windows</b> → 安装 WSL2</summary>

1. 按 `Win` 键，输入 **PowerShell**，右键 → **以管理员身份运行**
2. 输入以下命令：
   ```powershell
   wsl --install -d Ubuntu
   ```
3. 等它跑完，然后**重启电脑**
4. 重启后，会自动弹出一个黑色窗口，标题是 **Ubuntu**。如果没有弹出，点开始菜单搜索 **Ubuntu**，点击打开
5. 它会让你创建**用户名**和**密码** — 输入就行（输密码时看不到字符，这是正常的）。记住它们
6. 你应该会看到类似 `yourname@DESKTOP:~$` 的提示符 — 这说明你已经进入 Linux 了

**以后每次要用 Claude Agent Farm**，打开任意终端（PowerShell、命令提示符或 Windows Terminal），输入：

```
wsl
```

看到 `yourname@DESKTOP:~$` 提示符就说明进来了。后面所有步骤都在这里执行。

</details>

<details>
<summary><b>我用的是 macOS</b> → 安装 OrbStack</summary>

K3s 不能直接在 macOS 上运行，但 [OrbStack](https://orbstack.dev/) 可以零配置提供 Linux 环境：

```bash
brew install orbstack
```

安装后打开 OrbStack，然后在终端输入 `orb` 进入 Linux shell。后面所有步骤都在这个 shell 里执行 — 跟原生 Linux 一模一样。

> **其他方案：** [Colima](https://github.com/abiosoft/colima)（`brew install colima && colima start`）或云服务器（[DigitalOcean](https://www.digitalocean.com/)、[Vultr](https://www.vultr.com/)、[Hetzner](https://www.hetzner.com/)，约 $5/月起）。

</details>

<details>
<summary><b>我已经在 Linux 上了</b></summary>

直接开始。确保你的系统是 Ubuntu 22.04+（或基于 Debian），至少 2 核 CPU、4GB 内存。

</details>

### 第 1 步：安装 Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

验证：
```bash
node --version   # 应该显示 v22.x.x
```

### 第 2 步：安装 Claude Code 并登录

```bash
sudo npm install -g @anthropic-ai/claude-code
claude login
```

> **还没有 Claude 账号？** 前往 [claude.ai](https://claude.ai) 注册。你需要 **Pro**（$20/月）或 **Max**（$100/月）订阅，免费版无法使用。

`claude login` 会打开一个浏览器链接。点击链接，登录并授权。如果你在没有浏览器的服务器上，它会显示一个 URL — 复制到你本地浏览器打开，授权后把验证码粘贴回来。

验证：
```bash
claude --version   # 应该显示版本号
```

### 第 3 步：安装 Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

**重要：** 需要注销并重新登录（或运行 `newgrp docker`）才能让权限生效。

验证：
```bash
docker run hello-world   # 应该显示 "Hello from Docker!"
```

### 第 4 步：创建你的 Bot

选择你的平台，创建一个 Bot：

<details>
<summary><b>Discord</b></summary>

1. 打开 [discord.com/developers/applications](https://discord.com/developers/applications) → 点击 **New Application** → 随便起个名字
2. 左侧点 **Bot** 标签 → 点 **Reset Token** → 复制 token（保存好）
3. 往下滚 → 打开 **Message Content Intent**
4. 左侧点 **OAuth2 → URL Generator** → scopes 勾选 `bot` → 权限勾选：Send Messages、Embed Links、Add Reactions、Read Message History
5. 复制底部的 **Generated URL** → 浏览器打开 → 把 Bot 添加到你的 Discord 服务器

你还需要：
- **服务器 ID**：右键点击 Discord 服务器名称 → 复制服务器 ID（需要先在 Discord 设置 → 高级 中启用开发者模式）
- **频道 ID**：右键点击一个文字频道 → 复制频道 ID

</details>

<details>
<summary><b>Telegram</b></summary>

1. 打开 Telegram，搜索 **@BotFather**
2. 发送 `/newbot`
3. 按提示给你的 Bot 起名字和用户名
4. BotFather 会回复一个 **Bot token** — 复制它（保存好）

你还需要：
- **你的 User ID**：在 Telegram 上给 **@userinfobot** 发任意消息 — 它会回复你的 ID

</details>

### 第 5 步：运行安装脚本

```bash
git clone https://github.com/silver2dream/claude-agent-farm.git
cd claude-agent-farm

# Discord
bash setup.sh

# 或者 Telegram
bash setup-telegram.sh
```

脚本会问你第 4 步保存的 Bot token 和 ID，粘贴进去就行。

**搞定了。** 脚本跑完后，给你的 Bot 发条消息 — 它会回复。

---

## 添加智能体

```bash
# Discord — 所有智能体共享一个 Bot
make new-agent NAME=ci-fix CHANNEL_ID=123456
make apply

# Telegram — 每个智能体需要独立的 Bot（@BotFather 创建，免费且即时）
make -f Makefile.telegram new-agent NAME=ci-fix BOT_TOKEN=<token>
```

> **Discord vs Telegram：** Discord 智能体共享一个 Bot token（Bot 加入多个频道）。Telegram 智能体各需独立 Bot — Telegram 每个 token 只允许一个 `getUpdates` 消费者。通过 @BotFather 创建额外 Bot 免费且即时。

> 各平台完整指南：[Discord](docs/DISCORD.zh-CN.md) | [Telegram](docs/TELEGRAM.zh-CN.md)

---

## 工作原理

```
Discord #频道     ◄──► Claude Code Pod（在 K3s 中）
Telegram 聊天     ◄──► Claude Code Pod（在 K3s 中）
                         │
                         ├── 通过官方插件读取聊天平台事件
                         ├── 拥有完整文件系统 + git 访问权限
                         ├── 通过同一频道/聊天回复
                         └── 在资源受限的隔离 Pod 中运行
```

- **你在频道/聊天中发消息** → Anthropic 官方插件轮询消息 → Claude Code 处理请求 → 回复出现在频道/聊天中
- **外部 Webhook**（GitHub、CI、监控）可以直接 POST 到频道 Webhook URL → 智能体自动响应
- **空闲智能体零消耗** — 只有活跃的 token 处理才计入 Anthropic 配额
- **崩溃自动重启** — K8s 存活探针检测故障并重启 Pod

---

## 项目结构

```
claude-agent-farm/
├── setup.sh / setup-telegram.sh     # 一键交互式安装
├── Makefile / Makefile.telegram      # 所有运维命令
├── config.example[.telegram].env    # 配置模板
├── docker/
│   ├── Dockerfile[.telegram]        # 各平台容器镜像
│   └── entrypoint[-telegram].sh     # 凭证恢复 + 启动
├── manifests/
│   ├── namespace.yaml               # claude-agents 命名空间
│   ├── base/                        # 网络策略
│   └── agents/                      # 生成的智能体 YAML
├── scripts/                         # 智能体 YAML 生成器
├── examples/                        # 各平台智能体模板
└── docs/
    ├── DISCORD[.zh-CN].md           # Discord 完整指南
    ├── TELEGRAM[.zh-CN].md          # Telegram 完整指南
    └── UPGRADE.md                   # K3s → EKS/GKE/AKS 迁移
```

---

## 资源占用

每个智能体 Pod 非常轻量 — AI 推理运行在 Anthropic 的服务器上，不占用你的机器：

| 智能体数量 | CPU | 内存 | 建议机器 |
|---|---|---|---|
| 1–2 个 | 2 核 | 4 GB | $20–30/月 VPS 或旧笔记本 |
| 3–5 个 | 4 核 | 8 GB | $40–60/月 VPS |
| 6–10 个 | 8 核 | 16 GB | $80–100/月 独立服务器 |

K3s 控制面额外占用约 500MB 内存。

---

## Anthropic 用量与费用

所有智能体共享一个 Claude 订阅。空闲智能体消耗为零。

| 方案 | 价格 | 约每 5 小时提示数 | 适合 |
|---|---|---|---|
| Pro | $20/月 | ~45 | 1–2 个轻量智能体 |
| Max 5x | $100/月 | ~200 | 2–3 个中等负载智能体 |
| Max 20x | $200/月 | ~800 | 3+ 个并行智能体 |

在 Claude 设置中启用**额外用量**以避免突发时被限流 — 超出部分按 API 费率计费。

---

## 安全性

即使在单台机器上，K3s 也能提供真正的隔离：

- **Pod 隔离** — 每个智能体拥有独立的文件系统命名空间；一个智能体无法访问另一个的数据
- **K8s Secrets** — Bot token 和 Claude 凭证加密存储，而非明文文件
- **NetworkPolicy** — 每个智能体的出站流量仅限聊天平台 API + Anthropic API + DNS
- **无第三方代码** — 仅使用 Anthropic 官方插件 + K8s 原生组件

如需高级加固（RBAC、KMS 静态加密、审计日志），请参阅企业版文档。

---

## 升级路径

你的 K3s 清单文件是标准 Kubernetes 格式。当单台机器不够用时：

```
K3s（单机） → EKS / GKE / AKS（云端）
```

相同的 Deployment、PVC、NetworkPolicy、Secret。加上 ArgoCD 实现 GitOps。无需重写。详见 [docs/UPGRADE.md](docs/UPGRADE.md)。

---

## 常见问题

**可以同时使用 Discord 和 Telegram 吗？**
可以。它们共存于同一个 K3s 集群。分别运行两个安装脚本即可。

**为什么 Telegram 每个智能体需要一个 Bot？**
Telegram 每个 Bot token 只允许一个 `getUpdates` 消费者。Discord 没有这个限制。通过 @BotFather 创建额外的 Telegram Bot 是免费的且没有数量限制。

**支持 macOS / Windows 吗？**
K3s 仅支持 Linux。Windows 用 WSL2（见第 0 步），macOS 用 OrbStack — `brew install orbstack` 然后 `orb` 进入 Linux shell。

**可以在树莓派上运行吗？**
K3s 支持 ARM64。树莓派 4（4GB+）可以轻松运行 1–2 个智能体。

**需要 24 小时开机吗？**
智能体仅在机器运行时工作。重启后，K3s 自动启动，所有 Pod 会自动恢复。

**Claude Code Channels 结束研究预览后会怎样？**
`--channels` 参数语法可能会变化。关注本仓库获取更新。

---

## 贡献

欢迎提交 Issue 和 PR。如果你有我们未覆盖的使用场景，请发起讨论。

---

## 许可证

Apache License 2.0 — 详见 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。

---

<p align="center">
  <sub>架构设计 <a href="https://github.com/silver2dream">HAN LIN</a> · 为希望按自己方式使用 AI 智能体的开发者而构建。</sub>
</p>
