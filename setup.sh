#!/bin/bash
set -e

# ──────────────────────────────────────────────
# Claude Agent Farm — One-Click Setup
# ──────────────────────────────────────────────

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

banner() {
  echo ""
  echo -e "${CYAN}${BOLD}  🪐 Claude Agent Farm${NC}"
  echo -e "  ${YELLOW}One-click setup — let's get your AI agents running${NC}"
  echo ""
}

info()    { echo -e "  ${GREEN}✓${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
error()   { echo -e "  ${RED}✗${NC} $1"; exit 1; }
step()    { echo ""; echo -e "  ${BOLD}[$1/6]${NC} $2"; echo ""; }
ask()     { echo -ne "  ${CYAN}?${NC} $1: "; read -r "$2"; }

# ──────────────────────────────────────────────
# Pre-flight checks
# ──────────────────────────────────────────────

banner

if [ "$(uname)" != "Linux" ]; then
  error "Claude Agent Farm requires Linux. On macOS/Windows, use a Linux VM or WSL2."
fi

if [ "$(id -u)" = "0" ]; then
  warn "Running as root. Recommend running as a regular user with sudo access."
fi

# ──────────────────────────────────────────────
# Step 1: Install K3s
# ──────────────────────────────────────────────

step "1" "Installing K3s (lightweight Kubernetes)..."

if command -v k3s &>/dev/null; then
  info "K3s is already installed — skipping"
else
  info "Installing K3s..."
  curl -sfL https://get.k3s.io | sh -
  info "K3s installed"
fi

# Set up kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config 2>/dev/null || true
sudo chown "$(id -u):$(id -g)" ~/.kube/config 2>/dev/null || true
export KUBECONFIG=~/.kube/config

# Verify
if kubectl get nodes &>/dev/null; then
  info "K3s is running"
else
  error "K3s failed to start. Check: sudo systemctl status k3s"
fi

# ──────────────────────────────────────────────
# Step 2: Clone repo (if not already in it)
# ──────────────────────────────────────────────

step "2" "Setting up project files..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SCRIPT_DIR/Makefile" ] && [ -f "$SCRIPT_DIR/config.example.env" ]; then
  info "Already in the project directory"
  cd "$SCRIPT_DIR"
elif [ -f "./Makefile" ] && [ -f "./config.example.env" ]; then
  info "Already in the project directory"
else
  if command -v git &>/dev/null; then
    info "Cloning claude-agent-farm..."
    git clone https://github.com/silver2dream/claude-agent-farm.git
    cd claude-agent-farm
  else
    error "git is not installed. Run: sudo apt install git"
  fi
fi

# ──────────────────────────────────────────────
# Step 3: Collect user info
# ──────────────────────────────────────────────

step "3" "Configuration — I need a few things from you..."

echo -e "  ${YELLOW}If you haven't created a Discord bot yet:${NC}"
echo "  1. Go to https://discord.com/developers/applications"
echo "  2. New Application → Bot tab → Reset Token → copy token"
echo "  3. Enable 'Message Content Intent'"
echo "  4. OAuth2 → URL Generator → scope: bot → add to your server"
echo ""

# Discord bot token
while true; do
  ask "Discord bot token" DISCORD_BOT_TOKEN
  if [ -n "$DISCORD_BOT_TOKEN" ]; then break; fi
  warn "Bot token is required"
done

# Guild ID
echo ""
echo -e "  ${YELLOW}To get your Guild ID: enable Developer Mode in Discord,${NC}"
echo -e "  ${YELLOW}right-click your server name → Copy Server ID${NC}"
echo ""

while true; do
  ask "Discord server (guild) ID" DISCORD_GUILD_ID
  if [ -n "$DISCORD_GUILD_ID" ]; then break; fi
  warn "Guild ID is required"
done

# Discord User ID (for auto-pairing)
echo ""
echo -e "  ${YELLOW}To get your User ID: enable Developer Mode in Discord,${NC}"
echo -e "  ${YELLOW}click your username → Copy User ID${NC}"
echo ""

while true; do
  ask "Your Discord user ID" DISCORD_USER_ID
  if [ -n "$DISCORD_USER_ID" ]; then break; fi
  warn "User ID is required"
done

# First agent
echo ""
ask "Name for your first agent (default: my-first-agent)" AGENT_NAME
AGENT_NAME="${AGENT_NAME:-my-first-agent}"

echo ""
echo -e "  ${YELLOW}To get a Channel ID: right-click a text channel → Copy Channel ID${NC}"
echo ""
ask "Discord channel ID for this agent (leave empty for DM only)" CHANNEL_ID

echo ""
ask "System prompt / role for this agent (leave empty for default)" SYSTEM_PROMPT

# Claude credentials
echo ""
echo -e "  ${YELLOW}Claude Code needs your login credentials.${NC}"
echo -e "  ${YELLOW}These are in ~/.claude/ on the machine where you run 'claude login'.${NC}"
echo ""

CLAUDE_CONFIG_DIR="$HOME/.claude"
if [ -d "$CLAUDE_CONFIG_DIR" ]; then
  info "Found Claude config at $CLAUDE_CONFIG_DIR"
else
  ask "Path to your .claude directory" CLAUDE_CONFIG_DIR
  CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  if [ ! -d "$CLAUDE_CONFIG_DIR" ]; then
    warn "Directory not found. You can set this up later with 'make secrets'"
  fi
fi

# Write config.env
cat > config.env <<EOF
DISCORD_BOT_TOKEN=$DISCORD_BOT_TOKEN
DISCORD_GUILD_ID=$DISCORD_GUILD_ID
DISCORD_USER_ID=$DISCORD_USER_ID
AGENT_NAME=$AGENT_NAME
CHANNEL_ID=$CHANNEL_ID
CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR
IMAGE_NAME=claude-agent
IMAGE_TAG=latest
EOF

info "Config saved to config.env"

# ──────────────────────────────────────────────
# Step 4: Build container image
# ──────────────────────────────────────────────

step "4" "Building container image (this takes a few minutes)..."

if ! command -v docker &>/dev/null; then
  info "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" 2>/dev/null || true
  info "Docker installed"
fi

info "Building claude-agent image..."
docker build -t claude-agent:latest docker/

info "Importing into K3s..."
sudo k3s ctr images rm docker.io/library/claude-agent:latest 2>/dev/null || true
docker save claude-agent:latest | sudo k3s ctr images import -

info "Image ready"

# ──────────────────────────────────────────────
# Step 5: Create secrets and deploy
# ──────────────────────────────────────────────

step "5" "Deploying to K3s..."

# Namespace
kubectl apply -f manifests/namespace.yaml

# Secrets
kubectl create secret generic discord-bot-token \
  --from-literal=DISCORD_BOT_TOKEN="$DISCORD_BOT_TOKEN" \
  --from-literal=DISCORD_USER_ID="$DISCORD_USER_ID" \
  -n claude-agents --dry-run=client -o yaml | kubectl apply -f -

if [ -d "$CLAUDE_CONFIG_DIR" ]; then
  info "Importing Claude credentials..."

  # Only copy essential credential files (not cache/plugins/logs)
  # K8s Secrets have a 3MB size limit — full .claude/ often exceeds this
  TMPDIR=$(mktemp -d)
  FOUND_CREDS=false

  for f in credentials.json .credentials.json settings.json statsig.json; do
    if [ -f "$CLAUDE_CONFIG_DIR/$f" ]; then
      cp "$CLAUDE_CONFIG_DIR/$f" "$TMPDIR/"
      FOUND_CREDS=true
    fi
  done

  # ~/.claude.json (home directory, NOT inside ~/.claude/) stores feature flags
  # and user config — required for channels and other gated features
  CLAUDE_JSON="$HOME/.claude.json"
  if [ -f "$CLAUDE_JSON" ]; then
    cp "$CLAUDE_JSON" "$TMPDIR/claude.json"
    FOUND_CREDS=true
  fi

  if [ "$FOUND_CREDS" = true ]; then
    # Build --from-file args dynamically (dotglob for .credentials.json)
    FROM_FILES=""
    for f in "$TMPDIR"/* "$TMPDIR"/.*; do
      [ -f "$f" ] || continue
      FROM_FILES="$FROM_FILES --from-file=$(basename "$f")=$f"
    done

    eval kubectl create secret generic claude-config \
      $FROM_FILES \
      -n claude-agents --dry-run=client -o yaml | kubectl apply -f -
    info "Credentials imported"
  else
    warn "No credential files found in $CLAUDE_CONFIG_DIR. Run 'claude login' first."
  fi

  rm -rf "$TMPDIR"
else
  warn "Skipping Claude credentials — set up manually later with 'make secrets'"
fi

# Generate agent manifest from template
bash scripts/create-agent.sh "$AGENT_NAME" "$CHANNEL_ID" "claude-agent:latest" "$SYSTEM_PROMPT"

# Deploy base + agents
kubectl apply -f manifests/base/
kubectl apply -f manifests/agents/

info "Deployed! Waiting for pod to start..."

# Wait for pod
kubectl wait --for=condition=Ready pod \
  -l "app=$AGENT_NAME" \
  -n claude-agents \
  --timeout=120s 2>/dev/null || true

# ──────────────────────────────────────────────
# Step 6: Done!
# ──────────────────────────────────────────────

step "6" "Done!"

POD_STATUS=$(kubectl get pods -n claude-agents -l "app=$AGENT_NAME" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")

echo ""
echo -e "  ${GREEN}${BOLD}🪐 Claude Agent Farm is running!${NC}"
echo ""
echo -e "  Agent:   ${BOLD}$AGENT_NAME${NC}"
echo -e "  Status:  ${BOLD}$POD_STATUS${NC}"
echo ""
echo -e "  ${GREEN}Ready! Just message the bot in Discord — it will respond.${NC}"
echo ""
echo -e "  ${BOLD}Add another agent:${NC}"
echo -e "    ${CYAN}make new-agent NAME=cto CHANNEL_ID=123456 PROMPT=\"You are a CTO...\"${NC}"
echo -e "    ${CYAN}make apply${NC}"
echo ""
echo -e "  ${BOLD}Other commands:${NC}"
echo "    make status          — see all agents"
echo "    make logs AGENT=name — tail agent logs"
echo "    make shell AGENT=name — shell into an agent pod"
echo ""
