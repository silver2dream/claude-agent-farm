[English](TELEGRAM.md) | **简体中文**

# Telegram 部署指南

## 创建 Telegram Bot

每个 Telegram 智能体需要**独立的 Bot**。这是 Telegram API 的限制 — 每个 Bot token 只允许一个消费者轮询。通过 @BotFather 创建 Bot 是免费且即时的。

1. 打开 Telegram，搜索 **@BotFather**
2. 发送 `/newbot`，按提示为你的 Bot 命名
3. 复制 BotFather 给你的 Bot token
4. 获取你的 **User ID**：给 **@userinfobot** 或 **@RawDataBot** 发一条消息
5. 获取群组的 **Chat ID**：将 Bot 加入群组，发一条消息，然后访问 `https://api.telegram.org/bot<TOKEN>/getUpdates`

> ⚠️ **妥善保管 Bot token。** 它将以 K8s Secret 形式存储 — 切勿提交到 Git。

---

## 一键安装

```bash
bash setup-telegram.sh
```

脚本会引导你完成所有步骤：K3s 安装、Bot token、User ID、镜像构建、部署。

已经部署了 Discord 版？没问题 — 直接运行即可。脚本会检测已有的 K3s/Docker 并跳过，只执行 Telegram 相关步骤。

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
cp config.example.telegram.env config.telegram.env
# 编辑 config.telegram.env，填入你的 Telegram Bot token、User ID 和智能体名称
```

### 3. 部署

```bash
make -f Makefile.telegram setup
```

### 4. 首次配对

```bash
# 进入运行中的智能体 Pod
make -f Makefile.telegram shell AGENT=my-first-agent

# 在 Pod 中：在 Telegram 上给你的 Bot 发消息，获取配对码，然后：
/telegram:access pair <配对码>
/telegram:access policy allowlist
/telegram:access chat add <聊天ID>

# 退出 Pod
exit
```

</details>

---

## 添加更多智能体

每个 Telegram 智能体需要独立的 Bot（先在 @BotFather 创建一个）。一条命令搞定所有事情：

```bash
# 仅私信模式（无需 CHAT_ID）
make -f Makefile.telegram new-agent NAME=cto BOT_TOKEN=<token>

# 绑定到群组聊天
make -f Makefile.telegram new-agent NAME=cto BOT_TOKEN=<token> CHAT_ID=123456

# 自定义系统提示词
make -f Makefile.telegram new-agent NAME=cto BOT_TOKEN=<token> PROMPT="你是一位 CTO..."
```

`USER_ID` 默认使用 `config.telegram.env` 中的值（通常是你自己的 ID）。

---

## Discord vs Telegram：关键区别

| | Discord | Telegram |
|---|---|---|
| **每集群 Bot 数** | 1 个 Bot → N 个智能体 | 1 个 Bot → 1 个智能体 |
| **原因** | Bot 独立轮询各自频道 | Telegram 每个 token 只允许一个 `getUpdates` 消费者 |
| **添加智能体** | 分配新频道即可 | 需要通过 @BotFather 创建新 Bot |
| **费用** | 免费 | 免费（Bot 数量无限制） |

---

## 命令参考

| 命令 | 说明 |
|---|---|
| `bash setup-telegram.sh` | 交互式一键安装（安装所有组件） |
| `make -f Makefile.telegram setup` | 非交互式安装（需要 config.telegram.env） |
| `make -f Makefile.telegram deploy` | 将所有清单应用到 K3s |
| `make -f Makefile.telegram apply` | 添加/修改智能体后重新应用 |
| `make -f Makefile.telegram status` | 查看所有智能体 Pod 及其状态 |
| `make -f Makefile.telegram logs AGENT=名称` | 查看指定智能体的日志 |
| `make -f Makefile.telegram shell AGENT=名称` | 进入智能体 Pod |
| `make -f Makefile.telegram restart AGENT=名称` | 重启智能体（清除上下文） |
| `make -f Makefile.telegram new-agent NAME=x BOT_TOKEN=t [CHAT_ID=y]` | 创建 Secret + 清单 + 部署（无 CHAT_ID 则为私信模式） |
| `make -f Makefile.telegram destroy` | 移除所有资源 |
