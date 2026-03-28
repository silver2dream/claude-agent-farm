[English](DISCORD.md) | [简体中文](DISCORD.zh-CN.md) | **繁體中文**

# Discord 部署指南

## 建立 Discord Bot

你只需要**一個 Bot** 即可服務所有智能體。一個 Bot 可以服務多個頻道。

1. 前往 [Discord 開發者入口](https://discord.com/developers/applications) → **New Application**
2. **Bot** 標籤頁 → **Reset Token** → 複製並保存 token
3. 在 Privileged Gateway Intents 下啟用 **Message Content Intent**
4. **OAuth2 → URL Generator**：scope 選 `bot`，權限：Send Messages、Manage Channels、Embed Links、Add Reactions、Read Message History
5. 開啟產生的 URL，將 Bot 加到你的私有 Discord 伺服器

> ⚠️ **妥善保管 Bot token。** 它將以 K8s Secret 形式儲存 — 切勿提交到 Git。

---

## 一鍵安裝

```bash
bash setup.sh
```

腳本會引導你完成所有步驟：K3s 安裝、Bot token、Guild ID、映像建置、部署。

<details>
<summary><b>手動安裝（分步操作）</b></summary>

### 1. 安裝 K3s

```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
```

### 2. 設定

```bash
cp config.example.env config.env
# 編輯 config.env，填入你的 Discord Bot token、Guild ID 和智能體名稱
```

### 3. 部署

```bash
make setup
```

### 4. 首次配對

```bash
# 進入運行中的智能體 Pod
make shell AGENT=my-first-agent

# 在 Pod 中：在 Discord 上私訊你的 Bot，取得配對碼，然後：
/discord:access pair <配對碼>
/discord:access policy allowlist
/discord:access channel add <頻道ID>

# 退出 Pod
exit
```

</details>

---

## 新增更多智能體

所有 Discord 智能體共享一個 Bot token — 只需將每個智能體指向不同的頻道。

```bash
make new-agent NAME=ci-fix CHANNEL_ID=123456
make apply
```

或手動複製範本：

```bash
cp examples/agent-template.yaml manifests/agents/ci-fix-agent.yaml
# 編輯：修改 AGENT_NAME、CHANNEL_ID
make apply
```

---

## 指令參考

| 指令 | 說明 |
|---|---|
| `bash setup.sh` | 互動式一鍵安裝（安裝所有元件） |
| `make setup` | 非互動式安裝（需要 config.env） |
| `make deploy` | 將所有清單套用到 K3s |
| `make apply` | 新增/修改智能體後重新套用 |
| `make status` | 檢視所有智能體 Pod 及其狀態 |
| `make logs AGENT=名稱` | 檢視指定智能體的日誌 |
| `make shell AGENT=名稱` | 進入智能體 Pod |
| `make restart AGENT=名稱` | 重啟智能體（清除上下文） |
| `make new-agent NAME=x CHANNEL_ID=y` | 產生新的智能體 YAML |
| `make destroy` | 移除所有資源 |
