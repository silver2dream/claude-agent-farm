#!/bin/bash
set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
error() { echo -e "  ${RED}✗${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CONFIG_FILE="${1:-$PROJECT_DIR/examples/game-studio-agents.json}"
CHANNEL_ID="${2:-}"
IMAGE="${3:-claude-agent:latest}"

if [ ! -f "$CONFIG_FILE" ]; then
  error "Config file not found: $CONFIG_FILE"
fi

if [ -z "$CHANNEL_ID" ]; then
  echo ""
  echo -e "  ${CYAN}${BOLD}🪐 Deploy Agent Team${NC}"
  echo ""
  echo "  Usage: $0 <config.json> <discord-channel-id> [image]"
  echo ""
  echo "  Example:"
  echo "    $0 examples/game-studio-agents.json 1485305998322172168"
  echo ""
  exit 1
fi

echo ""
echo -e "  ${CYAN}${BOLD}🪐 Deploying agent team to channel $CHANNEL_ID${NC}"
echo ""

# Write the node script to a temp file to avoid bash escaping issues
TMPSCRIPT=$(mktemp /tmp/deploy-team-XXXXXX.js)
cat > "$TMPSCRIPT" << 'NODESCRIPT'
const fs = require('fs');
const path = require('path');

const [configFile, projectDir, channelId, image] = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
const templatePath = path.join(projectDir, 'examples', 'agent-template.yaml');
const template = fs.readFileSync(templatePath, 'utf8');
const outputDir = path.join(projectDir, 'manifests', 'agents');

for (const agent of config.agents) {
  const outFile = path.join(outputDir, agent.name + '.yaml');
  if (fs.existsSync(outFile)) {
    console.log('SKIP|' + agent.name + '|' + agent.role);
    continue;
  }

  // Escape prompt for YAML double-quoted string
  const escapedPrompt = agent.prompt
    .replace(/\$\{AGENT_MENTIONS\}/g, '(will be configured after all bots are online)')
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n');

  const yaml = template
    .replace(/__AGENT_NAME__/g, agent.name)
    .replace(/__CHANNEL_ID__/g, channelId)
    .replace(/__IMAGE__/g, image)
    .replace(/__SYSTEM_PROMPT__/g, escapedPrompt)
    .replace(/__REQUIRE_MENTION__/g, agent.requireMention ? 'true' : 'false');

  fs.writeFileSync(outFile, yaml);
  console.log('OK|' + agent.name + '|' + agent.role);
}
NODESCRIPT

node "$TMPSCRIPT" "$CONFIG_FILE" "$PROJECT_DIR" "$CHANNEL_ID" "$IMAGE" | while IFS='|' read -r status name role; do
  case "$status" in
    OK)   info "Created $name ($role)" ;;
    SKIP) warn "Skipped $name — already exists" ;;
  esac
done

rm -f "$TMPSCRIPT"

AGENT_COUNT=$(ls "$PROJECT_DIR/manifests/agents/"*.yaml 2>/dev/null | wc -l)
echo ""
echo -e "  ${GREEN}✓${NC} $AGENT_COUNT agent manifests ready"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    ${CYAN}make apply${NC}    — deploy all agents to K3s"
echo -e "    ${CYAN}make status${NC}   — check pod status"
echo ""
