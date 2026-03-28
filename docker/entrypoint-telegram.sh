#!/bin/bash
set -e

echo "🪐 Claude Agent Farm — starting Telegram agent..."

# ── 1. Restore credentials from K8s Secret mount ──
SECRETS_DIR="/secrets/claude-config"
if [ -d "$SECRETS_DIR" ] && [ "$(ls -A $SECRETS_DIR 2>/dev/null)" ]; then
  echo "📋 Restoring Claude credentials..."
  mkdir -p ~/.claude
  for f in "$SECRETS_DIR"/* "$SECRETS_DIR"/.*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      claude.json) cp "$f" ~/.claude.json ;;
      *)           cp "$f" ~/.claude/ ;;
    esac
  done
fi

# ── 2. Restore plugin files (PVC mount over ~/.claude wipes them) ──
PLUGIN_BACKUP="/home/agent/.claude-plugins-backup"
if [ -d "$PLUGIN_BACKUP" ] && [ ! -d ~/.claude/plugins ]; then
  echo "📦 Restoring plugins..."
  cp -r "$PLUGIN_BACKUP/plugins" ~/.claude/plugins
fi

# ── 3. Telegram: bot token + access control ──
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  mkdir -p ~/.claude/channels/telegram
  echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" > ~/.claude/channels/telegram/.env

  # Build access.json: pre-pair user + bind chat
  if [ ! -f ~/.claude/channels/telegram/access.json ]; then
    node -e "
      const fs = require('fs');
      const access = {
        dmPolicy: 'allowlist',
        allowFrom: [],
        groups: {},
        pending: {}
      };
      const uid = process.env.TELEGRAM_USER_ID;
      if (uid) access.allowFrom.push(uid);
      const chatId = process.env.TELEGRAM_CHAT_ID;
      if (chatId) {
        access.groups[chatId] = { requireMention: false, allowFrom: uid ? [uid] : [] };
      }
      const f = process.env.HOME + '/.claude/channels/telegram/access.json';
      fs.writeFileSync(f, JSON.stringify(access, null, 2));
    "
    echo "🔗 Telegram access control configured"
  fi
fi

# ── 4. Merge settings + config (plugins, trust, onboarding) ──
node -e "
  const fs = require('fs');

  // settings.json: merge plugin backup + skip permission prompt
  const sf = process.env.HOME + '/.claude/settings.json';
  let settings = {};
  try { settings = JSON.parse(fs.readFileSync(sf, 'utf8')); } catch {}
  const bf = process.env.HOME + '/.claude-plugins-backup/settings.json';
  try {
    const backup = JSON.parse(fs.readFileSync(bf, 'utf8'));
    settings = { ...backup, ...settings };
  } catch {}
  settings.skipDangerousModePermissionPrompt = true;
  fs.writeFileSync(sf, JSON.stringify(settings));

  // .claude.json: workspace trust + bypass + onboarding
  const cf = process.env.HOME + '/.claude.json';
  let config = {};
  try { config = JSON.parse(fs.readFileSync(cf, 'utf8')); } catch {}
  const ws = '/home/agent/workspace';
  config.projects = config.projects || {};
  config.projects[ws] = config.projects[ws] || {};
  config.projects[ws].hasTrustDialogAccepted = true;
  config.bypassPermissionsModeAccepted = true;
  config.hasCompletedOnboarding = true;
  fs.writeFileSync(cf, JSON.stringify(config));
" 2>/dev/null || true

# ── 5. Launch Claude Code ──
echo "✅ Starting Claude Code with Telegram channel..."
CLAUDE_ARGS=(
  --channels plugin:telegram@claude-plugins-official
  --permission-mode bypassPermissions
)

if [ -n "$AGENT_SYSTEM_PROMPT" ]; then
  CLAUDE_ARGS+=(--append-system-prompt "$AGENT_SYSTEM_PROMPT")
fi

exec claude "${CLAUDE_ARGS[@]}"
