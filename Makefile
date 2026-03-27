.PHONY: setup deploy apply status logs shell restart new-agent destroy build

include config.env
export

NAMESPACE := claude-agents
IMAGE := $(IMAGE_NAME):$(IMAGE_TAG)

# ──────────────────────────────────────────────
# First-time setup
# ──────────────────────────────────────────────

setup: build secrets deploy
	@echo ""
	@echo "✅ Claude Agent Farm is running!"
	@echo "   DM your bot or message it in the configured channel — it will respond."
	@echo ""

# ──────────────────────────────────────────────
# Build container image
# ──────────────────────────────────────────────

build:
	@echo "🔨 Building container image..."
	docker build -t $(IMAGE) docker/
	@echo "📦 Importing into K3s..."
	sudo k3s ctr images rm docker.io/library/$(IMAGE) 2>/dev/null || true
	docker save $(IMAGE) | sudo k3s ctr images import -
	@echo "✅ Image ready: $(IMAGE)"

# ──────────────────────────────────────────────
# Create K8s secrets
# ──────────────────────────────────────────────

secrets:
	@echo "🔐 Creating namespace and secrets..."
	kubectl apply -f manifests/namespace.yaml
	kubectl create secret generic discord-bot-token \
		--from-literal=DISCORD_BOT_TOKEN=$(DISCORD_BOT_TOKEN) \
		--from-literal=DISCORD_USER_ID=$(DISCORD_USER_ID) \
		-n $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@if [ -d "$(CLAUDE_CONFIG_DIR)" ]; then \
		echo "📋 Importing Claude credentials from $(CLAUDE_CONFIG_DIR)..."; \
		FROM_FILES=""; \
		for f in credentials.json .credentials.json settings.json statsig.json; do \
			if [ -f "$(CLAUDE_CONFIG_DIR)/$$f" ]; then \
				FROM_FILES="$$FROM_FILES --from-file=$$f=$(CLAUDE_CONFIG_DIR)/$$f"; \
			fi; \
		done; \
		if [ -f "$$HOME/.claude.json" ]; then \
			FROM_FILES="$$FROM_FILES --from-file=claude.json=$$HOME/.claude.json"; \
		fi; \
		if [ -n "$$FROM_FILES" ]; then \
			eval kubectl create secret generic claude-config \
				$$FROM_FILES \
				-n $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -; \
		else \
			echo "⚠️  No credential files found. Run 'claude login' first."; \
		fi; \
	else \
		echo "⚠️  Claude config dir not found at $(CLAUDE_CONFIG_DIR). Set CLAUDE_CONFIG_DIR in config.env"; \
	fi
	@echo "✅ Secrets created"

# ──────────────────────────────────────────────
# Deploy / apply manifests
# ──────────────────────────────────────────────

deploy:
	@echo "🚀 Deploying..."
	kubectl apply -f manifests/namespace.yaml
	kubectl apply -f manifests/base/
	kubectl apply -f manifests/agents/
	@echo "✅ Deployed. Run 'make status' to check."

apply: deploy

# ──────────────────────────────────────────────
# Operations
# ──────────────────────────────────────────────

status:
	@kubectl get pods -n $(NAMESPACE) -o wide

logs:
ifndef AGENT
	$(error Usage: make logs AGENT=agent-name)
endif
	kubectl logs -f deploy/$(AGENT) -n $(NAMESPACE)

shell:
ifndef AGENT
	$(error Usage: make shell AGENT=agent-name)
endif
	kubectl exec -it deploy/$(AGENT) -n $(NAMESPACE) -- /bin/bash

restart:
ifndef AGENT
	$(error Usage: make restart AGENT=agent-name)
endif
	kubectl rollout restart deploy/$(AGENT) -n $(NAMESPACE)
	@echo "♻️  Restarting $(AGENT)..."

# ──────────────────────────────────────────────
# Create a new agent
# ──────────────────────────────────────────────

new-agent:
ifndef NAME
	$(error Usage: make new-agent NAME=agent-name CHANNEL_ID=discord-channel-id PROMPT="system prompt")
endif
ifndef CHANNEL_ID
	$(error CHANNEL_ID is required. Right-click a Discord text channel → Copy Channel ID)
endif
	@bash scripts/create-agent.sh $(NAME) $(CHANNEL_ID) $(IMAGE) "$(PROMPT)"
	@echo "   Run 'make apply' to deploy it."

# ──────────────────────────────────────────────
# Cleanup
# ──────────────────────────────────────────────

destroy:
	@echo "🗑️  Removing all Claude Agent Farm resources..."
	kubectl delete namespace $(NAMESPACE) --ignore-not-found
	@echo "✅ Cleaned up."
