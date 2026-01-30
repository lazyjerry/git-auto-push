# 安裝指南

本文件提供 Git 工作流程自動化工具集的完整安裝說明。

## 目錄

- [一鍵安裝](#一鍵安裝)
- [快速安裝](#快速安裝)
- [詳細安裝步驟](#詳細安裝步驟)
  - [1. 複製專案](#1-複製專案)
  - [2. 設定執行權限](#2-設定執行權限)
  - [3. 調整個人化設定](#3-調整個人化設定建議)
  - [4. 全域安裝](#4-全域安裝選擇性)
  - [5. 相依工具安裝](#5-相依工具安裝)
- [驗證安裝](#驗證安裝)
- [解除安裝](#解除安裝)

---

## 一鍵安裝

使用安裝腳本快速安裝到系統：

```bash
# 本地安裝（安裝到當前目錄）
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | bash

# 全域安裝（安裝到 /usr/local/bin，需要 sudo）
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | bash -s -- --global
```

或使用 wget：

```bash
# 本地安裝
wget -qO- https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | bash

# 全域安裝
wget -qO- https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | bash -s -- --global
```

---

## 快速安裝

```bash
# 複製專案
git clone https://github.com/lazyjerry/git-auto-push.git
cd git-auto-push

# 設定執行權限
chmod +x git-auto-push.sh git-auto-pr.sh

# 測試執行
./git-auto-push.sh --help
./git-auto-pr.sh --help
```

---

## 詳細安裝步驟

### 1. 複製專案

```bash
git clone https://github.com/lazyjerry/git-auto-push.git
cd git-auto-push
```

### 2. 設定執行權限

```bash
chmod +x git-auto-push.sh
chmod +x git-auto-pr.sh
```

### 3. 調整個人化設定（建議）

在使用前，建議先依據個人或團隊需求調整以下重要設定變數：

#### git-auto-push.sh 設定（約第 100-210 行）

```bash
# AI 工具優先順序（第 109 行）
readonly AI_TOOLS=(
    "codex"     # GitHub Copilot CLI
    "gemini"    # Google Gemini CLI  
    "claude"    # Anthropic Claude CLI
)

# Commit 品質自動檢查（第 155 行）
AUTO_CHECK_COMMIT_QUALITY=true          # 自動檢查（建議）
# AUTO_CHECK_COMMIT_QUALITY=false       # 詢問模式
```

#### git-auto-pr.sh 設定（約第 180-230 行）

```bash
# AI 工具優先順序（第 187 行）
readonly AI_TOOLS=("codex" "gemini" "claude")

# 主分支偵測順序（第 202 行）
readonly -a DEFAULT_MAIN_BRANCHES=("uat" "main" "master")
# readonly -a DEFAULT_MAIN_BRANCHES=("main" "master")     # 標準配置
# readonly -a DEFAULT_MAIN_BRANCHES=("develop" "main")    # Git Flow 風格

# 預設使用者名稱（第 212 行）
readonly DEFAULT_USERNAME="jerry"
# readonly DEFAULT_USERNAME="your-name"    # 修改為您的名字

# PR 合併後分支刪除策略（第 223 行）
readonly AUTO_DELETE_BRANCH_AFTER_MERGE=false  # 保留分支（建議）
# readonly AUTO_DELETE_BRANCH_AFTER_MERGE=true # 自動刪除
```

#### 設定建議

| 設定項目 | 說明 | 建議值 |
|---------|------|--------|
| **AI_TOOLS** | AI 工具優先順序 | 根據已安裝的工具調整順序 |
| **DEFAULT_USERNAME** | 預設使用者名稱 | 修改為您的 GitHub 使用者名稱 |
| **DEFAULT_MAIN_BRANCHES** | 主分支偵測順序 | 依專案分支策略調整 |
| **AUTO_CHECK_COMMIT_QUALITY** | Commit 品質檢查 | 團隊協作 `true`，個人開發 `false` |
| **AUTO_DELETE_BRANCH_AFTER_MERGE** | PR 合併後刪除分支 | `false`（保留分支供追溯） |

### 4. 全域安裝（選擇性）

將工具安裝到系統路徑，可在任意目錄直接呼叫：

```bash
# 安裝 git-auto-push 到系統路徑
sudo install -m 755 git-auto-push.sh /usr/local/bin/git-auto-push

# 安裝 git-auto-pr 到系統路徑
sudo install -m 755 git-auto-pr.sh /usr/local/bin/git-auto-pr
```

安裝完成後即可直接使用：

```bash
# 直接呼叫（無需 ./ 前綴）
git-auto-push
git-auto-push --auto
git-auto-pr
```

### 5. 相依工具安裝

#### GitHub CLI（git-auto-pr.sh 必需）

`git-auto-pr.sh` 需要 GitHub CLI 來執行 PR 相關操作：

**macOS**

```bash
brew install gh
gh auth login  # 選擇 GitHub.com → HTTPS → Browser 登入
```

**Linux (Debian/Ubuntu)**

```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
gh auth login
```

**Windows (使用 winget)**

```powershell
winget install GitHub.cli
gh auth login
```

#### AI CLI 工具（可選，建議）

安裝任一或多個 AI CLI 工具以啟用內容產生功能：

##### GitHub Copilot CLI（建議）

```bash
# 需要有效的 GitHub Copilot 訂閱
gh extension install github/gh-copilot

# 驗證安裝
gh copilot --version
```

##### Google Gemini CLI

```bash
# 需要 Google AI Studio API Key
# 安裝方式請參考 Google AI Studio 官方文件
# https://ai.google.dev/
```

##### Anthropic Claude CLI

```bash
# 需要 Anthropic API Key
# 安裝方式請參考 Anthropic Console 官方文件
# https://console.anthropic.com/
```

**注意事項**：
- AI 工具需要相應的 API 金鑰或訂閱服務
- 如未安裝任何 AI 工具，腳本仍可正常使用，僅會跳過 AI 輔助功能
- 工具會自動偵測可用的 AI 命令並依優先順序使用

---

## 驗證安裝

執行以下命令驗證安裝是否成功：

```bash
# 檢查腳本執行權限
ls -la git-auto-push.sh git-auto-pr.sh

# 測試語法正確性
bash -n git-auto-push.sh && echo "✅ git-auto-push.sh 語法正確"
bash -n git-auto-pr.sh && echo "✅ git-auto-pr.sh 語法正確"

# 顯示幫助訊息
./git-auto-push.sh --help
./git-auto-pr.sh --help

# 檢查 AI 工具可用性
for tool in codex gemini claude; do 
    command -v "$tool" >/dev/null 2>&1 && echo "✅ $tool 可用" || echo "⚠️ $tool 未安裝"
done

# 檢查 GitHub CLI（git-auto-pr.sh 必需）
gh --version && echo "✅ GitHub CLI 可用" || echo "❌ GitHub CLI 未安裝"
gh auth status && echo "✅ GitHub CLI 已登入" || echo "⚠️ 請執行 gh auth login"
```

---

## 解除安裝

### 移除全域安裝

```bash
# 移除系統路徑中的腳本
sudo rm -f /usr/local/bin/git-auto-push
sudo rm -f /usr/local/bin/git-auto-pr
```

### 移除專案目錄

```bash
# 移除專案資料夾
rm -rf /path/to/git-auto-push
```

---

## 相關文件

- [README.md](../README.md) - 專案說明與使用方法
- [CHANGELOG.md](../CHANGELOG.md) - 版本更新紀錄
- [reports/](reports/) - 功能詳細說明文件

---

## 問題排除

如果遇到安裝問題，請參考 [README.md](../README.md) 中的「錯誤排除」章節，或在 GitHub Issues 提出問題。
