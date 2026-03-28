[English](README.md) | [简体中文](README.zh-CN.md) | **繁體中文**

# 🪐 Claude Agent Farm

**在你自己的機器上運行常駐 Claude Code AI 智能體，透過 Discord 或 Telegram 與它們對話。基於 K3s 構建。**

一個 Bot，多個智能體。每個智能體擁有獨立角色、獨立聊天頻道、獨立運行環境。
檔案和憑證留在你的機器上，AI 推論走 Anthropic 伺服器，對話走 Discord 或 Telegram — 沒有第三方程式碼接觸你的資料。

<!-- TODO: 新增示範 GIF -->
<!-- ![demo](docs/demo.gif) -->

---

## 這是什麼？

Claude Agent Farm 使用 [K3s](https://k3s.io) 將 [Claude Code Channels](https://code.claude.com/docs/en/channels)（Anthropic 官方聊天外掛）部署到你機器上的輕量級 Kubernetes Pod 中。每個智能體：

- 運行在**隔離的 Pod** 中（獨立檔案系統、網路、資源）
- 連接到**專屬的 Discord 頻道或 Telegram 聊天**（一個頻道 = 一個智能體）
- 當機後**自動重啟**（K8s 存活探針）
- 資料留在**你的機器上**（檔案和憑證在本機；僅 Anthropic API 和聊天平台 API 是外部連線）
- 閒置時**零 Anthropic 配額消耗**

可以把它想像成一個 AI 同事團隊，每人各有專長，都能透過手機上的 Discord 或 Telegram 隨時聯繫。

---

## 從零開始（Quick Start）

按順序一步步來，所有指令都可以直接複製貼上。

### 第 0 步：準備 Linux 環境

Claude Agent Farm 運行在 Linux 上。根據你的情況選擇：

<details>
<summary><b>我用的是 Windows</b> → 安裝 WSL2</summary>

1. 按 `Win` 鍵，輸入 **PowerShell**，右鍵 → **以系統管理員身分執行**
2. 輸入以下指令：
   ```powershell
   wsl --install -d Ubuntu
   ```
3. 等它跑完，然後**重新啟動電腦**
4. 重啟後，會自動彈出一個黑色視窗，標題是 **Ubuntu**。如果沒有彈出，點開始功能表搜尋 **Ubuntu**，點擊開啟
5. 它會要你建立**使用者名稱**和**密碼** — 輸入即可（輸入密碼時看不到字元，這是正常的）。記住它們
6. 你應該會看到類似 `yourname@DESKTOP:~$` 的提示符 — 這表示你已經進入 Linux 了

**以後每次要用 Claude Agent Farm**，開啟任意終端機（PowerShell、命令提示字元或 Windows Terminal），輸入：

```
wsl
```

看到 `yourname@DESKTOP:~$` 提示符就表示進來了。後面所有步驟都在這裡執行。

</details>

<details>
<summary><b>我用的是 macOS</b> → 安裝 OrbStack</summary>

K3s 無法直接在 macOS 上運行，但 [OrbStack](https://orbstack.dev/) 可以零設定提供 Linux 環境：

```bash
brew install orbstack
```

安裝後開啟 OrbStack，然後在終端機輸入 `orb` 進入 Linux shell。後面所有步驟都在這個 shell 裡執行 — 跟原生 Linux 一模一樣。

> **其他方案：** [Colima](https://github.com/abiosoft/colima)（`brew install colima && colima start`）或雲端伺服器（[DigitalOcean](https://www.digitalocean.com/)、[Vultr](https://www.vultr.com/)、[Hetzner](https://www.hetzner.com/)，約 $5/月起）。

</details>

<details>
<summary><b>我已經在 Linux 上了</b></summary>

直接開始。確保你的系統是 Ubuntu 22.04+（或基於 Debian），至少 2 核 CPU、4GB 記憶體。

</details>

### 第 1 步：安裝 Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

驗證：
```bash
node --version   # 應該顯示 v22.x.x
```

### 第 2 步：安裝 Claude Code 並登入

```bash
sudo npm install -g @anthropic-ai/claude-code
claude login
```

> **還沒有 Claude 帳號？** 前往 [claude.ai](https://claude.ai) 註冊。你需要 **Pro**（$20/月）或 **Max**（$100/月）訂閱，免費版無法使用。

`claude login` 會開啟一個瀏覽器連結。點擊連結，登入並授權。如果你在沒有瀏覽器的伺服器上，它會顯示一個 URL — 複製到你本機瀏覽器開啟，授權後把驗證碼貼回來。

驗證：
```bash
claude --version   # 應該顯示版本號
```

### 第 3 步：安裝 Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

**重要：** 需要登出並重新登入（或執行 `newgrp docker`）才能讓權限生效。

驗證：
```bash
docker run hello-world   # 應該顯示 "Hello from Docker!"
```

### 第 4 步：建立你的 Bot

選擇你的平台，建立一個 Bot：

<details>
<summary><b>Discord</b></summary>

1. 前往 [discord.com/developers/applications](https://discord.com/developers/applications) → 點擊 **New Application** → 隨便取個名字
2. 左側點 **Bot** 標籤頁 → 點 **Reset Token** → 複製 token（妥善保存）
3. 往下捲 → 開啟 **Message Content Intent**
4. 左側點 **OAuth2 → URL Generator** → scopes 勾選 `bot` → 權限勾選：Send Messages、Embed Links、Add Reactions、Read Message History
5. 複製底部的 **Generated URL** → 瀏覽器開啟 → 把 Bot 加到你的 Discord 伺服器

你還需要：
- **伺服器 ID**：右鍵點擊 Discord 伺服器名稱 → 複製伺服器 ID（需要先在 Discord 設定 → 進階 中啟用開發者模式）
- **頻道 ID**：右鍵點擊一個文字頻道 → 複製頻道 ID

</details>

<details>
<summary><b>Telegram</b></summary>

1. 開啟 Telegram，搜尋 **@BotFather**
2. 傳送 `/newbot`
3. 按提示給你的 Bot 取名字和使用者名稱
4. BotFather 會回覆一個 **Bot token** — 複製它（妥善保存）

你還需要：
- **你的 User ID**：在 Telegram 上給 **@userinfobot** 傳任意訊息 — 它會回覆你的 ID

</details>

### 第 5 步：執行安裝腳本

```bash
git clone https://github.com/silver2dream/claude-agent-farm.git
cd claude-agent-farm

# Discord
bash setup.sh

# 或者 Telegram
bash setup-telegram.sh
```

腳本會問你第 4 步保存的 Bot token 和 ID，貼進去就行。

**搞定了。** 腳本跑完後，給你的 Bot 傳條訊息 — 它會回覆。

---

## 新增智能體

```bash
# Discord — 所有智能體共享一個 Bot
make new-agent NAME=ci-fix CHANNEL_ID=123456
make apply

# Telegram — 每個智能體需要獨立的 Bot（@BotFather 建立，免費且即時）
make -f Makefile.telegram new-agent NAME=ci-fix BOT_TOKEN=<token>
```

> **Discord vs Telegram：** Discord 智能體共享一個 Bot token（Bot 加入多個頻道）。Telegram 智能體各需獨立 Bot — Telegram 每個 token 只允許一個 `getUpdates` 消費者。透過 @BotFather 建立額外 Bot 免費且即時。

> 各平台完整指南：[Discord](docs/DISCORD.zh-TW.md) | [Telegram](docs/TELEGRAM.zh-TW.md)

---

## 工作原理

```
Discord #頻道     ◄──► Claude Code Pod（在 K3s 中）
Telegram 聊天     ◄──► Claude Code Pod（在 K3s 中）
                         │
                         ├── 透過官方外掛讀取聊天平台事件
                         ├── 擁有完整檔案系統 + git 存取權限
                         ├── 透過同一頻道/聊天回覆
                         └── 在資源受限的隔離 Pod 中運行
```

- **你在頻道/聊天中傳訊息** → Anthropic 官方外掛輪詢訊息 → Claude Code 處理請求 → 回覆出現在頻道/聊天中
- **外部 Webhook**（GitHub、CI、監控）可以直接 POST 到頻道 Webhook URL → 智能體自動回應
- **閒置智能體零消耗** — 只有活躍的 token 處理才計入 Anthropic 配額
- **當機自動重啟** — K8s 存活探針偵測故障並重啟 Pod

---

## 專案結構

```
claude-agent-farm/
├── setup.sh / setup-telegram.sh     # 一鍵互動式安裝
├── Makefile / Makefile.telegram      # 所有維運指令
├── config.example[.telegram].env    # 設定範本
├── docker/
│   ├── Dockerfile[.telegram]        # 各平台容器映像
│   └── entrypoint[-telegram].sh     # 憑證還原 + 啟動
├── manifests/
│   ├── namespace.yaml               # claude-agents 命名空間
│   ├── base/                        # 網路原則
│   └── agents/                      # 產生的智能體 YAML
├── scripts/                         # 智能體 YAML 產生器
├── examples/                        # 各平台智能體範本
└── docs/
    ├── DISCORD[.zh-TW].md           # Discord 完整指南
    ├── TELEGRAM[.zh-TW].md          # Telegram 完整指南
    └── UPGRADE.md                   # K3s → EKS/GKE/AKS 遷移
```

---

## 資源使用量

每個智能體 Pod 非常輕量 — AI 推論運行在 Anthropic 的伺服器上，不佔用你的機器：

| 智能體數量 | CPU | 記憶體 | 建議機器 |
|---|---|---|---|
| 1–2 個 | 2 核 | 4 GB | $20–30/月 VPS 或舊筆電 |
| 3–5 個 | 4 核 | 8 GB | $40–60/月 VPS |
| 6–10 個 | 8 核 | 16 GB | $80–100/月 獨立伺服器 |

K3s 控制面額外佔用約 500MB 記憶體。

---

## Anthropic 用量與費用

所有智能體共享一個 Claude 訂閱。閒置智能體消耗為零。

| 方案 | 價格 | 約每 5 小時提示數 | 適合 |
|---|---|---|---|
| Pro | $20/月 | ~45 | 1–2 個輕量智能體 |
| Max 5x | $100/月 | ~200 | 2–3 個中等負載智能體 |
| Max 20x | $200/月 | ~800 | 3+ 個並行智能體 |

在 Claude 設定中啟用**額外用量**以避免突發時被限流 — 超出部分按 API 費率計費。

---

## 安全性

即使在單台機器上，K3s 也能提供真正的隔離：

- **Pod 隔離** — 每個智能體擁有獨立的檔案系統命名空間；一個智能體無法存取另一個的資料
- **K8s Secrets** — Bot token 和 Claude 憑證加密儲存，而非明文檔案
- **NetworkPolicy** — 每個智能體的出站流量僅限聊天平台 API + Anthropic API + DNS
- **無第三方程式碼** — 僅使用 Anthropic 官方外掛 + K8s 原生元件

如需進階強化（RBAC、KMS 靜態加密、稽核日誌），請參閱企業版文件。

---

## 升級路徑

你的 K3s 清單檔是標準 Kubernetes 格式。當單台機器不夠用時：

```
K3s（單機） → EKS / GKE / AKS（雲端）
```

相同的 Deployment、PVC、NetworkPolicy、Secret。加上 ArgoCD 實現 GitOps。無需重寫。詳見 [docs/UPGRADE.zh-TW.md](docs/UPGRADE.zh-TW.md)。

---

## 常見問題

**可以同時使用 Discord 和 Telegram 嗎？**
可以。它們共存於同一個 K3s 叢集。分別執行兩個安裝腳本即可。

**為什麼 Telegram 每個智能體需要一個 Bot？**
Telegram 每個 Bot token 只允許一個 `getUpdates` 消費者。Discord 沒有這個限制。透過 @BotFather 建立額外的 Telegram Bot 是免費的且沒有數量限制。

**支援 macOS / Windows 嗎？**
K3s 僅支援 Linux。Windows 用 WSL2（見第 0 步），macOS 用 OrbStack — `brew install orbstack` 然後 `orb` 進入 Linux shell。

**可以在樹莓派上運行嗎？**
K3s 支援 ARM64。樹莓派 4（4GB+）可以輕鬆運行 1–2 個智能體。

**需要 24 小時開機嗎？**
智能體僅在機器運行時工作。重啟後，K3s 自動啟動，所有 Pod 會自動恢復。

**Claude Code Channels 結束研究預覽後會怎樣？**
`--channels` 參數語法可能會變化。關注本儲存庫取得更新。

---

## 貢獻

歡迎提交 Issue 和 PR。如果你有我們未涵蓋的使用情境，請發起討論。

---

## 授權條款

Apache License 2.0 — 詳見 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。

---

<p align="center">
  <sub>架構設計 <a href="https://github.com/silver2dream">HAN LIN</a> · 為希望按自己方式使用 AI 智能體的開發者而構建。</sub>
</p>
