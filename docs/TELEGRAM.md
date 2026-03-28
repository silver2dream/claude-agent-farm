**English** | [简体中文](TELEGRAM.zh-CN.md) | [繁體中文](TELEGRAM.zh-TW.md)

# Telegram Setup Guide

## Create a Telegram Bot

Each Telegram agent needs **its own bot**. This is a Telegram API limitation — only one consumer can poll per bot token. Creating bots via @BotFather is free and instant.

1. Open Telegram and search for **@BotFather**
2. Send `/newbot` and follow the prompts to name your bot
3. Copy the bot token that BotFather gives you
4. To get your **User ID**: send a message to **@userinfobot** or **@RawDataBot**
5. To get a **Chat ID** for group chats: add the bot to a group, send a message, then visit `https://api.telegram.org/bot<TOKEN>/getUpdates`

> ⚠️ **Keep the bot token secret.** It will be stored as a K8s Secret — never commit it to Git.

---

## One-command Setup

```bash
bash setup-telegram.sh
```

The script walks you through everything: K3s install, bot token, user ID, image build, deploy.

Already have Discord deployed? No problem — just run the command. It detects existing K3s/Docker and skips to the Telegram-specific steps.

<details>
<summary><b>Manual setup (step-by-step)</b></summary>

### 1. Install K3s

```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
```

### 2. Configure

```bash
cp config.example.telegram.env config.telegram.env
# Edit config.telegram.env with your Telegram bot token, user ID, and agent name
```

### 3. Deploy

```bash
make -f Makefile.telegram setup
```

### 4. First-time Pairing

```bash
# Exec into the running agent pod
make -f Makefile.telegram shell AGENT=my-first-agent

# In the pod: send a message to your bot on Telegram, get a pairing code, then:
/telegram:access pair <pairing-code>
/telegram:access policy allowlist
/telegram:access chat add <chat-id>

# Exit the pod
exit
```

</details>

---

## Add More Agents

Each Telegram agent needs its own bot (create one via @BotFather first). One command handles everything:

```bash
# DM only (no CHAT_ID needed)
make -f Makefile.telegram new-agent NAME=cto BOT_TOKEN=<token>

# Bind to a group chat
make -f Makefile.telegram new-agent NAME=cto BOT_TOKEN=<token> CHAT_ID=123456

# With a custom system prompt
make -f Makefile.telegram new-agent NAME=cto BOT_TOKEN=<token> PROMPT="You are a CTO..."
```

`USER_ID` defaults from `config.telegram.env` (usually your own ID).

---

## Discord vs Telegram: Key Difference

| | Discord | Telegram |
|---|---|---|
| **Bots per cluster** | 1 bot → N agents | 1 bot → 1 agent |
| **Why** | Bot polls specific channels independently | Telegram allows only one `getUpdates` consumer per token |
| **Add agent** | Just assign a new channel | Create a new bot via @BotFather |
| **Cost** | Free | Free (no limit on bots) |

---

## Commands

| Command | What it does |
|---|---|
| `bash setup-telegram.sh` | Interactive one-command setup (installs everything) |
| `make -f Makefile.telegram setup` | Non-interactive setup (requires config.telegram.env) |
| `make -f Makefile.telegram deploy` | Apply all manifests to K3s |
| `make -f Makefile.telegram apply` | Re-apply after adding/changing agents |
| `make -f Makefile.telegram status` | Show all agent pods and their status |
| `make -f Makefile.telegram logs AGENT=name` | Tail logs of a specific agent |
| `make -f Makefile.telegram shell AGENT=name` | Exec into an agent pod |
| `make -f Makefile.telegram restart AGENT=name` | Restart an agent (clears context) |
| `make -f Makefile.telegram new-agent NAME=x BOT_TOKEN=t [CHAT_ID=y]` | Create secret + manifest + deploy (DM if no CHAT_ID) |
| `make -f Makefile.telegram destroy` | Remove everything |
