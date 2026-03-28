**English** | [简体中文](README.zh-CN.md)

# 🪐 Claude Agent Farm

**Run always-on Claude Code AI agents on your own machine. Talk to them from Discord or Telegram. Powered by K3s.**

One bot. Multiple agents. Each with its own role, its own chat channel, its own isolated environment.
Your files and credentials stay on your machine. AI inference goes through Anthropic, conversations through Discord or Telegram — nothing else touches your data. Zero third-party code in the critical path.

<!-- TODO: Add demo GIF here -->
<!-- ![demo](docs/demo.gif) -->

---

## What is this?

Claude Agent Farm deploys [Claude Code Channels](https://code.claude.com/docs/en/channels) (Anthropic's official chat plugins) inside lightweight Kubernetes pods on your machine using [K3s](https://k3s.io). Each agent:

- Runs in an **isolated Pod** (separate filesystem, network, resources)
- Connects to a **dedicated Discord channel or Telegram chat** (one channel = one agent)
- **Auto-restarts** if it crashes (K8s liveness probes)
- Stays on **your machine** (files and credentials local; only Anthropic API and chat platform APIs are external)
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

### Discord

```bash
git clone https://github.com/silver2dream/claude-agent-farm.git
cd claude-agent-farm
bash setup.sh
```

> Full guide: [docs/DISCORD.md](docs/DISCORD.md) — bot creation, pairing, commands, adding agents

### Telegram

```bash
git clone https://github.com/silver2dream/claude-agent-farm.git
cd claude-agent-farm
bash setup-telegram.sh
```

> Full guide: [docs/TELEGRAM.md](docs/TELEGRAM.md) — bot creation, pairing, commands, adding agents

### Both platforms at once

Discord and Telegram agents coexist in the same K3s cluster. Run both setup scripts — they share the namespace and Claude credentials.

---

## Adding Agents

```bash
# Discord — all agents share one bot
make new-agent NAME=ci-fix CHANNEL_ID=123456
make apply

# Telegram — each agent needs its own bot (@BotFather, free & instant)
make -f Makefile.telegram new-agent NAME=ci-fix BOT_TOKEN=<token>
```

---

## How It Works

```
Discord #channel  ◄──► Claude Code Pod (in K3s)
Telegram chat     ◄──► Claude Code Pod (in K3s)
                         │
                         ├── Reads events from chat platform via official plugin
                         ├── Processes with full filesystem + git access
                         ├── Replies back through the same channel/chat
                         └── Runs in isolated Pod with resource limits
```

- **You message a channel/chat** → the official Anthropic plugin polls it → Claude Code processes your request → reply appears in the channel/chat
- **External webhooks** (GitHub, CI, monitoring) can POST directly to channel webhook URLs → agents react automatically
- **Idle agents cost nothing** — only active token processing counts toward your Anthropic quota
- **Crashed agents auto-restart** — K8s liveness probes detect failures and restart the Pod

---

## Project Structure

```
claude-agent-farm/
├── setup.sh / setup-telegram.sh     # One-command interactive setup
├── Makefile / Makefile.telegram      # All operational commands
├── config.example[.telegram].env    # Config templates
├── docker/
│   ├── Dockerfile[.telegram]        # Container images per platform
│   └── entrypoint[-telegram].sh     # Credential restore + startup
├── manifests/
│   ├── namespace.yaml               # claude-agents namespace
│   ├── base/                        # Network policies
│   └── agents/                      # Generated agent YAMLs
├── scripts/                         # Agent YAML generators
├── examples/                        # Agent templates per platform
└── docs/
    ├── DISCORD.md                   # Discord full guide
    ├── TELEGRAM.md                  # Telegram full guide
    └── UPGRADE.md                   # K3s → EKS/GKE/AKS migration
```

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
- **K8s Secrets** — bot tokens and Claude credentials are stored encrypted, not as plain files
- **NetworkPolicy** — each agent's egress is restricted to chat platform API + Anthropic API + DNS only
- **No third-party code** — only Anthropic's official plugins + K8s-native components

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
Yes. They coexist in the same K3s cluster. Use `make` for Discord and `make -f Makefile.telegram` for Telegram.

**Why does Telegram need one bot per agent?**
Telegram only allows one `getUpdates` consumer per bot token. Discord doesn't have this limitation. Creating extra Telegram bots via @BotFather is free and has no limit.

**Does this work on macOS / Windows?**
K3s is Linux-only. On macOS/Windows, use a Linux VM or WSL2.

**Can I run this on a Raspberry Pi?**
K3s supports ARM64. A Raspberry Pi 4 (4GB+) can comfortably host 1–2 agents.

**Do I need to keep my machine on 24/7?**
Agents only work while the machine is on. If it reboots, K3s auto-starts and all Pods come back up.

**What happens when Claude Code Channels exits research preview?**
The `--channels` flag syntax may change. Watch this repo for updates.

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
