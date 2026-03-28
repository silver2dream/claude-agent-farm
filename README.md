# 🪐 Claude Agent Farm

**Run always-on Claude Code AI agents on your own machine. Talk to them from Discord or Telegram. Powered by K3s.**

One bot. Multiple agents. Each with its own role, its own chat channel, its own isolated environment.
Your files and credentials stay on your machine. AI inference goes through Anthropic, conversations through Discord or Telegram — nothing else touches your data. Zero third-party code in the critical path.

<!-- TODO: Add demo GIF here -->
<!-- ![demo](docs/demo.gif) -->

---

## What is this?

Claude Agent Farm deploys [Claude Code Channels](https://code.claude.com/docs/en/channels) (Anthropic's official Discord/Telegram plugin) inside lightweight Kubernetes pods on your machine using [K3s](https://k3s.io). Each agent:

- Runs in an **isolated Pod** (separate filesystem, network, resources)
- Connects to a **dedicated Discord channel or Telegram chat** (one channel = one agent)
- **Auto-restarts** if it crashes (K8s liveness probes)
- Stays on **your machine** (files and credentials local; only Anthropic API and Discord API are external)
- Consumes **zero Anthropic quota** when idle

Think of it as a team of AI coworkers, each with a specialty, all reachable from your phone via Discord or Telegram.

---

## Quick Start

### Prerequisites

| Requirement | How to get it |
|---|---|
| Linux machine (VPS, home server, or WSL2) | Ubuntu 22.04+, 2 CPU, 4GB RAM minimum |
| Claude Pro or Max subscription | [claude.ai/pricing](https://claude.ai/pricing) |
| Claude Code CLI (authenticated) | `npm install -g @anthropic-ai/claude-code` then `claude login` |
| Discord or Telegram account | [discord.com](https://discord.com) / [telegram.org](https://telegram.org) |

### One-command setup (Discord)

```bash
git clone https://github.com/silver2dream/claude-agent-farm.git
cd claude-agent-farm
bash setup.sh
```

### One-command setup (Telegram)

```bash
git clone https://github.com/silver2dream/claude-agent-farm.git
cd claude-agent-farm
bash setup-telegram.sh
```

Both setup scripts walk you through everything interactively:

1. **Installs K3s** (if not already installed)
2. **Asks for your bot token** (Discord or Telegram)
3. **Asks for your server/chat ID**
4. **Names your first agent**
5. **Finds your Claude credentials** (from `~/.claude/`)
6. **Builds the container image**
7. **Deploys everything to K3s**

The only thing left after the script finishes is [first-time pairing](#first-time-pairing) — one command to link the agent to your chat platform.

<details>
<summary><b>Manual setup — Discord (step-by-step)</b></summary>

#### 1. Install K3s

```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
```

#### 2. Configure

```bash
cp config.example.env config.env
# Edit config.env with your Discord bot token, guild ID, and agent name
```

#### 3. Deploy

```bash
make setup
```

</details>

<details>
<summary><b>Manual setup — Telegram (step-by-step)</b></summary>

#### 1. Install K3s

```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
```

#### 2. Configure

```bash
cp config.example.telegram.env config.telegram.env
# Edit config.telegram.env with your Telegram bot token, user ID, and agent name
```

#### 3. Deploy

```bash
make -f Makefile.telegram setup
```

</details>

---

## Create a Discord Bot

You only need **one bot** for all your agents.

1. Go to [Discord Developer Portal](https://discord.com/developers/applications) → **New Application**
2. **Bot** tab → **Reset Token** → copy and save the token
3. Enable **Message Content Intent** under Privileged Gateway Intents
4. **OAuth2 → URL Generator**: scope `bot`, permissions: Send Messages, Manage Channels, Embed Links, Add Reactions, Read Message History
5. Open the generated URL to add the bot to your private Discord server

> ⚠️ **Keep the bot token secret.** It will be stored as a K8s Secret — never commit it to Git.

---

## Create a Telegram Bot

You only need **one bot** for all your agents.

1. Open Telegram and search for **@BotFather**
2. Send `/newbot` and follow the prompts to name your bot
3. Copy the bot token that BotFather gives you
4. To get your **User ID**: send a message to **@userinfobot** or **@RawDataBot**
5. To get a **Chat ID** for group chats: add the bot to a group, send a message, then visit `https://api.telegram.org/bot<TOKEN>/getUpdates`

> ⚠️ **Keep the bot token secret.** It will be stored as a K8s Secret — never commit it to Git.

---

## First-time Pairing

Each agent needs to be paired with its chat platform once. After that, the config persists across restarts.

**Discord:**

```bash
# Exec into the running agent pod
make shell AGENT=my-first-agent

# In the pod: DM your bot on Discord, get a pairing code, then:
/discord:access pair <pairing-code>
/discord:access policy allowlist
/discord:access channel add <channel-id>

# Exit the pod
exit
```

**Telegram:**

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

Now message the agent in its channel/chat. It will respond.

---

## Add More Agents

Each agent is a YAML file. Copy the example and customize:

```bash
# Create a second agent
cp examples/agent-template.yaml manifests/agents/ci-fix-agent.yaml

# Edit the file: change AGENT_NAME, CHANNEL_NAME
# Then apply:
make apply
```

Or use the helper:

```bash
# Discord
make new-agent NAME=ci-fix CHANNEL_ID=123456
make apply

# Telegram
make -f Makefile.telegram new-agent NAME=ci-fix CHAT_ID=123456
make -f Makefile.telegram apply
```

Each agent gets:
- Its own Pod (isolated filesystem and resources)
- Its own PVC (persistent config across restarts)
- Its own Discord channel or Telegram chat

They all share one bot token and one Claude subscription. No bot proliferation.

---

## Project Structure

```
claude-agent-farm/
├── README.md
├── setup.sh                         # One-command setup (Discord)
├── setup-telegram.sh                # One-command setup (Telegram)
├── Makefile                         # Discord commands: deploy, shell, logs, new-agent
├── Makefile.telegram                # Telegram commands: deploy, shell, logs, new-agent
├── config.example.env               # Discord template — copy to config.env
├── config.example.telegram.env      # Telegram template — copy to config.telegram.env
├── docker/
│   ├── Dockerfile                   # Claude Code + Discord plugin
│   ├── Dockerfile.telegram          # Claude Code + Telegram plugin
│   ├── entrypoint.sh               # Discord credential restore + startup
│   └── entrypoint-telegram.sh      # Telegram credential restore + startup
├── manifests/
│   ├── namespace.yaml               # claude-agents namespace
│   ├── base/
│   │   ├── network-policy.yaml      # Discord egress policy
│   │   └── network-policy-telegram.yaml # Telegram egress policy
│   └── agents/
│       └── (generated agent YAMLs)
├── scripts/
│   ├── create-agent.sh              # Generate Discord agent YAML
│   └── create-agent-telegram.sh     # Generate Telegram agent YAML
├── examples/
│   ├── agent-template.yaml          # Discord agent template
│   └── agent-template-telegram.yaml # Telegram agent template
└── docs/
    └── UPGRADE.md                   # Path from K3s → EKS/GKE/AKS
```

---

## Commands

### Discord

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

### Telegram

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
| `make -f Makefile.telegram new-agent NAME=x CHAT_ID=y` | Generate a new agent YAML |
| `make -f Makefile.telegram destroy` | Remove everything |

---

## How It Works

```
Discord #channel  ◄──► Claude Code Pod (in K3s)
Telegram chat     ◄──► Claude Code Pod (in K3s)
                         │
                         ├── Reads events from Discord/Telegram via official plugin
                         ├── Processes with full filesystem + git access
                         ├── Replies back through the same channel/chat
                         └── Runs in isolated Pod with resource limits
```

- **You message a channel/chat** → the official Anthropic plugin polls it → Claude Code processes your request → reply appears in the channel/chat
- **External webhooks** (GitHub, CI, monitoring) can POST directly to channel webhook URLs → agents react automatically
- **Idle agents cost nothing** — only active token processing counts toward your Anthropic quota
- **Crashed agents auto-restart** — K8s liveness probes detect failures and restart the Pod

---

## Resource Usage

Each agent pod is lightweight — the AI inference runs on Anthropic's servers, not yours:

| Agents | CPU | RAM | Suggested machine |
|---|---|---|---|
| 1–2 | 2 cores | 4 GB | $20–30/mo VPS or old laptop |
| 3–5 | 4 cores | 8 GB | $40–60/mo VPS |
| 6–10 | 8 cores | 16 GB | $80–100/mo dedicated |

K3s control plane adds ~500MB RAM overhead.

---

## Anthropic Usage & Cost

All agents share one Claude subscription. Idle agents consume zero quota.

| Plan | Price | Approx. prompts / 5hr | Best for |
|---|---|---|---|
| Pro | $20/mo | ~45 | 1–2 light agents |
| Max 5x | $100/mo | ~200 | 2–3 moderate agents |
| Max 20x | $200/mo | ~800 | 3+ parallel agents |

Enable **extra usage** in your Claude settings to avoid being throttled during bursts — overflow is billed at API rates.

---

## Security

Even on a single machine, K3s gives you real isolation:

- **Pod isolation** — each agent has its own filesystem namespace; one agent cannot access another's data
- **K8s Secrets** — Discord token and Claude credentials are stored encrypted, not as plain files
- **NetworkPolicy** — each agent's egress is restricted to Discord/Telegram API + Anthropic API + DNS only
- **No third-party code** — only Anthropic's official plugin + K8s-native components

For advanced hardening (RBAC, KMS encryption at rest, audit logging), see the Enterprise documentation.

---

## Upgrade Path

Your K3s manifests are standard Kubernetes. When you outgrow a single machine:

```
K3s (single machine) → EKS / GKE / AKS (cloud)
```

Same Deployments, same PVCs, same NetworkPolicies, same Secrets. Add ArgoCD for GitOps. No rewrites needed. See [docs/UPGRADE.md](docs/UPGRADE.md) for details.

---

## FAQ

**Can I use both Discord and Telegram?**
Yes. You can run Discord agents and Telegram agents in the same K3s cluster. They share the same namespace and Claude credentials. Use `make` for Discord agents and `make -f Makefile.telegram` for Telegram agents.

**Does this work on macOS / Windows?**  
K3s is Linux-only. On macOS/Windows, use the [Quick Start with tmux](docs/QUICKSTART-TMUX.md) approach instead, or run K3s inside a Linux VM.

**Can I run this on a Raspberry Pi?**  
K3s supports ARM64. A Raspberry Pi 4 (4GB+) can comfortably host 1–2 agents.

**Do I need to keep my machine on 24/7?**  
Agents only work while the machine is on and K3s is running. If the machine reboots, K3s auto-starts and all agent Pods come back up automatically.

**What happens when Claude Code Channels exits research preview?**  
The `--channels` flag syntax may change. Watch this repo for updates — we'll track Anthropic's changes.

---

## Contributing

Issues and PRs welcome. If you have a use case we haven't covered, open a discussion.

---

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

---

<p align="center">
  <sub>Architecture by <a href="https://github.com/silver2dream">HAN LIN</a> · Built for developers who want AI agents on their own terms.</sub>
</p>
