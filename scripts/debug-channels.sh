#!/bin/bash
# Debug script: run inside the container to test channels
set -x

echo "=== Restoring credentials ==="
cp /secrets/claude-config/* ~/.claude/ 2>/dev/null
cp /secrets/claude-config/.* ~/.claude/ 2>/dev/null

echo "=== Restoring plugins ==="
cp -r /home/agent/.claude-plugins-backup/plugins ~/.claude/plugins 2>/dev/null
cp /home/agent/.claude-plugins-backup/settings.json ~/.claude/settings.json 2>/dev/null

echo "=== Writing discord token ==="
mkdir -p ~/.claude/channels/discord
echo "DISCORD_BOT_TOKEN=$DISCORD_BOT_TOKEN" > ~/.claude/channels/discord/.env

echo "=== Files in ~/.claude/ ==="
ls -la ~/.claude/

echo "=== Plugin list ==="
claude plugin list 2>&1

echo "=== Testing --channels ==="
claude --channels plugin:discord@claude-plugins-official --dangerously-skip-permissions 2>&1 &
PID=$!
sleep 10
kill $PID 2>/dev/null
