**English** | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md)

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

## Quick Start (from zero)

Follow these steps in order. Everything is copy-paste — no prior experience required.

### Step 0: Get a Linux environment

Claude Agent Farm runs on Linux. Pick the option that matches your situation:

<details>
<summary><b>I'm on Windows</b> → Install WSL2</summary>

1. Press `Win` key, type **PowerShell**, right-click → **Run as Administrator**
2. Run this command:
   ```powershell
   wsl --install -d Ubuntu
   ```
3. Wait for it to finish, then **restart your computer**
4. After reboot, a black window titled **Ubuntu** will pop up automatically. If it doesn't, click the Start menu and search for **Ubuntu**, then click to open it
5. It will ask you to create a **username** and **password** — type them in (the password won't show characters while typing, that's normal). Remember these
6. You should now see a prompt like `yourname@DESKTOP:~$` — this means you're inside Linux

**Every time you want to use Claude Agent Farm after this**, just open a terminal (PowerShell, Command Prompt, or Windows Terminal) and type:

```
wsl
```

You'll see the `yourname@DESKTOP:~$` prompt again. All remaining steps run here.

</details>

<details>
<summary><b>I'm on macOS</b> → Install OrbStack</summary>

K3s doesn't run natively on macOS, but [OrbStack](https://orbstack.dev/) gives you a seamless Linux environment with zero config:

```bash
brew install orbstack
```

After install, open OrbStack, then type `orb` in your terminal to enter a Linux shell. All remaining steps run inside this shell — it works exactly like native Linux.

> **Alternatives:** [Colima](https://github.com/abiosoft/colima) (`brew install colima && colima start`) or a cloud VPS ([DigitalOcean](https://www.digitalocean.com/), [Vultr](https://www.vultr.com/), [Hetzner](https://www.hetzner.com/) from ~$5/mo).

</details>

<details>
<summary><b>I'm already on Linux</b></summary>

You're good. Make sure you're on Ubuntu 22.04+ (or Debian-based) with at least 2 CPU cores and 4GB RAM.

</details>

### Step 1: Install Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

Verify:
```bash
node --version   # should show v22.x.x
```

### Step 2: Install Claude Code and log in

```bash
sudo npm install -g @anthropic-ai/claude-code
claude login
```

> **Don't have a Claude account?** Go to [claude.ai](https://claude.ai) and sign up. You need a **Pro** ($20/mo) or **Max** ($100/mo) subscription. Free tier won't work.

`claude login` will open a browser link. Click it, log in, and authorize. If you're on a headless server (no browser), it will show a URL — copy it to your local browser, authorize, then paste the code back.

Verify:
```bash
claude --version   # should show a version number
```

### Step 3: Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

**Important:** Log out and log back in (or run `newgrp docker`) for the group change to take effect.

Verify:
```bash
docker run hello-world   # should show "Hello from Docker!"
```

### Step 4: Create your bot

Choose your platform and create a bot:

<details>
<summary><b>Discord</b></summary>

1. Go to [discord.com/developers/applications](https://discord.com/developers/applications) → click **New Application** → name it anything
2. Go to the **Bot** tab on the left → click **Reset Token** → copy the token (save it somewhere safe)
3. Scroll down → turn on **Message Content Intent**
4. Go to **OAuth2 → URL Generator** on the left → check `bot` under scopes → check these permissions: Send Messages, Embed Links, Add Reactions, Read Message History
5. Copy the **Generated URL** at the bottom → open it in your browser → add the bot to your Discord server

You'll also need:
- **Server ID**: Right-click your server name in Discord → Copy Server ID (enable Developer Mode in Discord Settings → Advanced first)
- **Channel ID**: Right-click a text channel → Copy Channel ID

</details>

<details>
<summary><b>Telegram</b></summary>

1. Open Telegram and search for **@BotFather**
2. Send `/newbot`
3. Follow the prompts — give your bot a name and username
4. BotFather will reply with a **bot token** — copy it (save it somewhere safe)

You'll also need:
- **Your User ID**: Send any message to **@userinfobot** on Telegram — it will reply with your ID

</details>

### Step 5: Run the setup

```bash
git clone https://github.com/silver2dream/claude-agent-farm.git
cd claude-agent-farm

# Discord
bash setup.sh

# OR Telegram
bash setup-telegram.sh
```

The script will ask you for the bot token and IDs you saved in Step 4. Paste them in when prompted.

**That's it.** When the script finishes, send a message to your bot — it will respond.

---

## Adding Agents

```bash
# Discord — all agents share one bot
make new-agent NAME=ci-fix CHANNEL_ID=123456
make apply

# Telegram — each agent needs its own bot (@BotFather, free & instant)
make -f Makefile.telegram new-agent NAME=ci-fix BOT_TOKEN=<token>
```

> **Discord vs Telegram:** Discord agents share one bot token (the bot joins multiple channels). Telegram agents each need their own bot — Telegram only allows one `getUpdates` consumer per token. Creating extra bots via @BotFather is free and instant.

> Full platform guides: [Discord](docs/DISCORD.md) | [Telegram](docs/TELEGRAM.md)

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
Yes. They coexist in the same K3s cluster. Run both setup scripts.

**Why does Telegram need one bot per agent?**
Telegram only allows one `getUpdates` consumer per bot token. Discord doesn't have this limitation. Creating extra Telegram bots via @BotFather is free and has no limit.

**Does this work on macOS / Windows?**
K3s is Linux-only. On Windows, use WSL2 (see Step 0). On macOS, use OrbStack — just `brew install orbstack` then `orb` to get a Linux shell.

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
