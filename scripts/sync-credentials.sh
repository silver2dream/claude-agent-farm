#!/bin/bash
# Sync local Claude credentials to K8s Secret and restart agents
# Run via cron: */30 * * * * /projects/claude-agent-farm/scripts/sync-credentials.sh

set -e

NAMESPACE="claude-agents"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_JSON="$HOME/.claude.json"

# Build secret from local credential files
FROM_FILES=""
for f in credentials.json .credentials.json settings.json; do
  [ -f "$CLAUDE_DIR/$f" ] && FROM_FILES="$FROM_FILES --from-file=$f=$CLAUDE_DIR/$f"
done
[ -f "$CLAUDE_JSON" ] && FROM_FILES="$FROM_FILES --from-file=claude.json=$CLAUDE_JSON"

if [ -z "$FROM_FILES" ]; then
  echo "$(date): No credential files found, skipping"
  exit 0
fi

# Check if credentials actually changed (compare hash)
NEW_HASH=$(cat $CLAUDE_DIR/.credentials.json $CLAUDE_JSON 2>/dev/null | sha256sum | cut -d' ' -f1)
HASH_FILE="/tmp/claude-cred-hash"
OLD_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "none")

if [ "$NEW_HASH" = "$OLD_HASH" ]; then
  exit 0  # No change, skip silently
fi

# Update secret
eval kubectl create secret generic claude-config \
  $FROM_FILES \
  -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1

# Restart all agent pods to pick up new credentials
kubectl rollout restart deploy -n $NAMESPACE >/dev/null 2>&1

# Save hash
echo "$NEW_HASH" > "$HASH_FILE"
echo "$(date): Credentials synced and agents restarted"
