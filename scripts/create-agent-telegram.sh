#!/bin/bash
set -e

AGENT_NAME="$1"
CHAT_ID="${2:-}"
IMAGE="${3:-claude-agent-telegram:latest}"
SYSTEM_PROMPT="${4:-}"

if [ -z "$AGENT_NAME" ]; then
  echo "Usage: $0 <agent-name> <telegram-chat-id> [image] [system-prompt]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$PROJECT_DIR/examples/agent-template-telegram.yaml"
OUTPUT="$PROJECT_DIR/manifests/agents/${AGENT_NAME}.yaml"

if [ -f "$OUTPUT" ]; then
  echo "⚠️  $OUTPUT already exists. Remove it first or choose a different name."
  exit 1
fi

sed \
  -e "s|__AGENT_NAME__|${AGENT_NAME}|g" \
  -e "s|__CHAT_ID__|${CHAT_ID}|g" \
  -e "s|__IMAGE__|${IMAGE}|g" \
  -e "s|__SYSTEM_PROMPT__|${SYSTEM_PROMPT}|g" \
  "$TEMPLATE" > "$OUTPUT"

echo "✅ Created $OUTPUT"
echo "   Agent: $AGENT_NAME"
[ -n "$CHAT_ID" ] && echo "   Chat ID: $CHAT_ID"
[ -n "$SYSTEM_PROMPT" ] && echo "   Role: $SYSTEM_PROMPT"
echo "   Image: $IMAGE"
