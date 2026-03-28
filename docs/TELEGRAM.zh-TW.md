[English](TELEGRAM.md) | [简体中文](TELEGRAM.zh-CN.md) | **繁體中文**

# Telegram 部署指南

## 建立 Telegram Bot

每個 Telegram 智能體需要**獨立的 Bot**。這是 Telegram API 的限制 — 每個 Bot token 只允許一個消費者輪詢。透過 @BotFather 建立 Bot 是免費且即時的。

1. 開啟 Telegram，搜尋 **@BotFather**
2. 傳送 `/newbot`，按提示為你的 Bot 命名
3. 複製 BotFather 給你的 Bot token
4. 取得你的 **User ID**：給 **@userinfobot** 或 **@RawDataBot** 傳一則訊息
5. 取得群組的 **Chat ID**：將 Bot 加入群組，傳一則訊息，然後造訪 `https://api.telegram.org/bot<TOKEN>/getUpdates`

> ⚠️ **妥善保管 Bot token。** 它將以 K8s Secret 形式儲存 — 切勿提交到 Git。

---

## 一鍵安裝

```bash
bash setup-telegram.sh
```

腳本會引導你完成所有步驟：K3s 安裝、Bot token、User ID、映像建置、部署。

已經部署了 Discord 版？沒問題 — 直接執行即可。腳本會偵測已有的 K3s/Docker 並跳過，只執行 Telegram 相關步驟。

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
cp config.example.telegram.env config.telegram.env
# 編輯 config.telegram.env，填入你的 Telegram Bot token、User ID 和智能體名稱
```

### 3. 部署

```bash
make -f Makefile.telegram setup
```

### 4. 首次配對

```bash
# 進入運行中的智能體 Pod
make -f Makefile.telegram shell AGENT=my-first-agent

# 在 Pod 中：在 Telegram 上給你的 Bot 傳訊息，取得配對碼，然後：
/telegram:access pair <配對碼>
/telegram:access policy allowlist
/telegram:access chat add <聊天ID>

# 退出 Pod
exit
```

</details>

---

## 新增更多智能體

每個 Telegram 智能體需要獨立的 Bot（先在 @BotFather 建立一個）。一條指令搞定所有事情：

```bash
# 僅私訊模式（無需 CHAT_ID）
make -f Makefile.telegram new-agent NAME=cto BOT_TOKEN=<token>

# 綁定到群組聊天
make -f Makefile.telegram new-agent NAME=cto BOT_TOKEN=<token> CHAT_ID=123456

# 自訂系統提示詞
make -f Makefile.telegram new-agent NAME=cto BOT_TOKEN=<token> PROMPT="你是一位 CTO..."
```

`USER_ID` 預設使用 `config.telegram.env` 中的值（通常是你自己的 ID）。

---

## Discord vs Telegram：關鍵差異

| | Discord | Telegram |
|---|---|---|
| **每叢集 Bot 數** | 1 個 Bot → N 個智能體 | 1 個 Bot → 1 個智能體 |
| **原因** | Bot 獨立輪詢各自頻道 | Telegram 每個 token 只允許一個 `getUpdates` 消費者 |
| **新增智能體** | 分配新頻道即可 | 需要透過 @BotFather 建立新 Bot |
| **費用** | 免費 | 免費（Bot 數量無限制） |

---

## 指令參考

| 指令 | 說明 |
|---|---|
| `bash setup-telegram.sh` | 互動式一鍵安裝（安裝所有元件） |
| `make -f Makefile.telegram setup` | 非互動式安裝（需要 config.telegram.env） |
| `make -f Makefile.telegram deploy` | 將所有清單套用到 K3s |
| `make -f Makefile.telegram apply` | 新增/修改智能體後重新套用 |
| `make -f Makefile.telegram status` | 檢視所有智能體 Pod 及其狀態 |
| `make -f Makefile.telegram logs AGENT=名稱` | 檢視指定智能體的日誌 |
| `make -f Makefile.telegram shell AGENT=名稱` | 進入智能體 Pod |
| `make -f Makefile.telegram restart AGENT=名稱` | 重啟智能體（清除上下文） |
| `make -f Makefile.telegram new-agent NAME=x BOT_TOKEN=t [CHAT_ID=y]` | 建立 Secret + 清單 + 部署（無 CHAT_ID 則為私訊模式） |
| `make -f Makefile.telegram destroy` | 移除所有資源 |
