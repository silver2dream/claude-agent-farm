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

PROJECT="${1:-}"
CHANNEL_ID="${2:-}"
CONFIG_FILE="${3:-$PROJECT_DIR/examples/game-studio-agents.json}"
IMAGE="${4:-claude-agent:latest}"

if [ -z "$PROJECT" ] || [ -z "$CHANNEL_ID" ]; then
  echo ""
  echo -e "  ${CYAN}${BOLD}🪐 Deploy Agent Team${NC}"
  echo ""
  echo "  Usage: $0 <project-codename> <discord-channel-id> [config.json] [image]"
  echo ""
  echo "  Examples:"
  echo "    $0 immortal-ascent 1487737976489381988"
  echo "    $0 shadow-realm 9999999999999 examples/custom-agents.json"
  echo ""
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  error "Config file not found: $CONFIG_FILE"
fi

echo ""
echo -e "  ${CYAN}${BOLD}🪐 Deploying team for project: $PROJECT${NC}"
echo -e "  Channel: $CHANNEL_ID"
echo -e "  Config:  $CONFIG_FILE"
echo ""

# Write the node script to a temp file to avoid bash escaping issues
TMPSCRIPT=$(mktemp /tmp/deploy-team-XXXXXX.js)
cat > "$TMPSCRIPT" << 'NODESCRIPT'
const fs = require('fs');
const path = require('path');

const [configFile, projectDir, project, channelId, image] = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
const templatePath = path.join(projectDir, 'examples', 'agent-template.yaml');
const template = fs.readFileSync(templatePath, 'utf8');
const outputDir = path.join(projectDir, 'manifests', 'agents');

// Get orchestrator bot ID from config (first agent with requireMention=false)
const orchestrator = config.agents.find(a => !a.requireMention);
const orchestratorBotId = orchestrator?.discordBotId || '(configure-after-deploy)';

for (const agent of config.agents) {
  const fullName = project + '-' + agent.name;
  const outFile = path.join(outputDir, fullName + '.yaml');
  if (fs.existsSync(outFile)) {
    console.log('SKIP|' + fullName + '|' + agent.role);
    continue;
  }

  // Escape prompt for YAML double-quoted string
  const escapedPrompt = agent.prompt
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n');

  const yaml = template
    .replace(/__PROJECT__/g, project)
    .replace(/__AGENT_NAME__/g, agent.name)
    .replace(/__CHANNEL_ID__/g, channelId)
    .replace(/__IMAGE__/g, image)
    .replace(/__SYSTEM_PROMPT__/g, escapedPrompt)
    .replace(/__REQUIRE_MENTION__/g, agent.requireMention ? 'true' : 'false')
    .replace(/__ORCHESTRATOR_BOT_ID__/g, orchestratorBotId);

  fs.writeFileSync(outFile, yaml);
  console.log('OK|' + fullName + '|' + agent.role);
}
NODESCRIPT

node "$TMPSCRIPT" "$CONFIG_FILE" "$PROJECT_DIR" "$PROJECT" "$CHANNEL_ID" "$IMAGE" | while IFS='|' read -r status name role; do
  case "$status" in
    OK)   info "Created $name ($role)" ;;
    SKIP) warn "Skipped $name — already exists" ;;
  esac
done

rm -f "$TMPSCRIPT"

AGENT_COUNT=$(ls "$PROJECT_DIR/manifests/agents/${PROJECT}-"*.yaml 2>/dev/null | wc -l)
echo ""
echo -e "  ${GREEN}✓${NC} $AGENT_COUNT agent manifests ready for project ${BOLD}$PROJECT${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    ${CYAN}kubectl apply -f manifests/agents/${NC}    — deploy"
echo -e "    ${CYAN}make status${NC}                          — check pods"
echo ""
