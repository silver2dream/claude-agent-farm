**English** | [简体中文](DISCORD.zh-CN.md)

# Discord Setup Guide

## Create a Discord Bot

You only need **one bot** for all your agents. One bot can serve multiple channels.

1. Go to [Discord Developer Portal](https://discord.com/developers/applications) → **New Application**
2. **Bot** tab → **Reset Token** → copy and save the token
3. Enable **Message Content Intent** under Privileged Gateway Intents
4. **OAuth2 → URL Generator**: scope `bot`, permissions: Send Messages, Manage Channels, Embed Links, Add Reactions, Read Message History
5. Open the generated URL to add the bot to your private Discord server

> ⚠️ **Keep the bot token secret.** It will be stored as a K8s Secret — never commit it to Git.

---

## One-command Setup

```bash
bash setup.sh
```

The script walks you through everything: K3s install, bot token, guild ID, image build, deploy.

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
cp config.example.env config.env
# Edit config.env with your Discord bot token, guild ID, and agent name
```

### 3. Deploy

```bash
make setup
```

</details>

---

## Add More Agents

All Discord agents share one bot token — you just point each to a different channel.

```bash
make new-agent NAME=ci-fix CHANNEL_ID=123456
make apply
```

Or copy the template manually:

```bash
cp examples/agent-template.yaml manifests/agents/ci-fix-agent.yaml
# Edit: change AGENT_NAME, CHANNEL_ID
make apply
```

---

## Commands

| Command | What it does |
|---|---|
| `bash setup.sh` | Interactive one-command setup (installs everything) |
| `make setup` | Non-interactive setup (requires config.env) |
| `make deploy` | Apply all manifests to K3s |
| `make apply` | Re-apply after adding/changing agents |
| `make status` | Show all agent pods and their status |
| `make logs AGENT=name` | Tail logs of a specific agent |
| `make shell AGENT=name` | Exec into an agent pod |
| `make restart AGENT=name` | Restart an agent (clears context) |
| `make new-agent NAME=x CHANNEL_ID=y` | Generate a new agent YAML |
| `make destroy` | Remove everything |
