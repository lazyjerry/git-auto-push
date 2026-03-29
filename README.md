🌐 [English](README_EN.md) | [简体中文](README_CN.md) | 繁體中文 | [日本語](README_JP.md) | [한국어](README_KR.md)

---

# Git 工作流程自動化工具集

兩支 Bash 腳本，分別處理傳統 Git 操作（add/commit/push）和 GitHub Flow PR 流程。支援多種 AI CLI 工具產生 commit 訊息與 PR 內容，也提供 Conventional Commits 前綴、訊息品質檢查、任務編號自動帶入等功能。

版本：v2.8.0

## 專案簡介

### 主要功能

- 傳統 Git 工作流程自動化（add、commit、push）
- Conventional Commits 前綴支援（手動選擇或 AI 自動判斷）
- 命令列直接執行（`./git-auto-push.sh 1-7` 跳過選單）
- Git 倉庫資訊查看（分支狀態、遠端、同步狀態、提交歷史）
- Commit 訊息修改（安全修改最後一次 commit，支援任務編號）
- Commit 訊息品質檢查（AI 分析品質，可設定自動或詢問模式）
- GitHub Flow PR 流程（從建立分支到建立 PR）
- PR 生命週期管理（建立、撤銷、審查、合併）
- 分支管理（安全刪除、主分支保護、多重確認）
- AI 產生 commit 訊息、分支名稱、PR 內容
- 多 AI 工具容錯（一個失敗自動切換下一個）
- 錯誤處理與修復建議
- 中斷復原和信號處理

## 系統架構

### 核心元件

```
├── git-auto-push.sh         # 傳統 Git 操作自動化（2552 行）
├── git-auto-pr.sh           # GitHub Flow PR 流程自動化（2769 行）
├── Conventional Commits      # 前綴支援：手動選擇、AI 判斷、跳過
├── AI 工具模組               # copilot / gemini / codex / claude
│   ├── 容錯機制             # 工具失敗自動切換
│   ├── 輸出清理             # 過濾 AI 中繼資料
│   └── 品質檢查             # 分析 commit 訊息品質
├── 任務編號                  # 從分支名稱解析 issue key（JIRA、GitHub Issue）
├── Commit 訊息修改           # 安全修改最後一次 commit，二次確認
├── 互動式選單               # 操作選項與使用者介面
├── 調試模式                  # AI 工具執行詳情追蹤
├── 信號處理                  # trap cleanup 與中斷復原
└── 錯誤處理                  # 異常偵測與修復建議
```

### 專案結構

```
├── git-auto-push.sh      # 傳統 Git 自動化工具
├── git-auto-pr.sh        # GitHub Flow PR 自動化工具
├── LICENSE              # MIT 授權條款
├── README.md            # 專案說明文件
├── .github/             # GitHub 相關設定
│   └── copilot-instructions.md    # AI 代理開發指導
├── docs/                # 文件目錄
│   ├── git-auto-push.mermaid             # Git 自動化流程圖
│   ├── git-auto-pr.mermaid               # PR 流程圖
│   ├── git_auto_push_workflow.png        # Git 工作流程圖
│   ├── git_pr_automation.png             # PR 自動化圖
│   └── reports/                          # 詳細文件報告
│       ├── FEATURE-AMEND.md              # 變更 commit 訊息功能說明
│       ├── FEATURE-COMMIT-QUALITY.md     # Commit 品質檢查功能說明
│       ├── COMMIT-QUALITY-SUMMARY.md     # Commit 品質檢查摘要
│       ├── COMMIT-QUALITY-QUICKREF.md    # Commit 品質快速參考
│       ├── AI-QUALITY-CHECK-IMPROVEMENT.md # AI 品質檢查改進說明
│       └── 選項7-變更commit訊息功能開發報告.md # 選項 7 開發報告
└── screenshots/         # 介面展示圖片
    ├── ai-commit-generation.png
    ├── auto-mode.png
    ├── main-menu.png
    ├── pr-screenshot-cli.png
    └── pr-screenshot-web.png
```

## 安裝與啟動

> 完整安裝指南請查看 [INSTALLATION.md](INSTALLATION.md)

### 一鍵安裝

```bash
# 互動式安裝（選擇本地或全域）
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh

# 直接全域安裝（需要 sudo）
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh -s -- --global
```

### 快速安裝

```bash
# 複製專案
git clone https://github.com/lazyjerry/git-auto-push.git
cd git-auto-push

# 設定執行權限
chmod +x git-auto-push.sh git-auto-pr.sh

# 測試執行
./git-auto-push.sh --help
```

### 全域安裝（選擇性）

```bash
# 安裝到系統路徑，可在任意目錄直接呼叫
sudo install -m 755 git-auto-push.sh /usr/local/bin/git-auto-push
sudo install -m 755 git-auto-pr.sh /usr/local/bin/git-auto-pr
```

### 相依工具

| 工具 | 用途 | 必要性 |
|-----|------|--------|
| **GitHub CLI** | PR 流程操作 | `git-auto-pr.sh` 必需 |
| **AI CLI 工具** | 內容自動產生 | 選擇性（建議安裝） |

```bash
# 安裝 GitHub CLI (macOS)
brew install gh && gh auth login
```

### 個人化配置

支援外部配置文件自訂設定，不用改腳本：

```bash
# 建立配置目錄並複製配置範例
mkdir -p ~/.git-auto-push-config
cp .git-auto-push-config/.env.example ~/.git-auto-push-config/.env

# 編輯配置
nano ~/.git-auto-push-config/.env
```

**配置文件優先級**：當前工作目錄 → Home 目錄 → 腳本目錄

常用配置選項：

```bash
# AI 工具優先順序
AI_TOOLS=("copilot" "claude" "gemini" "codex")

# 預設使用者名稱
DEFAULT_USERNAME="your-name"

# 調試模式
IS_DEBUG=false
```

> 更多安裝選項和 AI 工具安裝請參閱 [INSTALLATION.md](INSTALLATION.md)

## 使用方法

> 完整操作指南請查看 [USAGE.md](USAGE.md)

### 功能總覽

| 工具 | 用途 | 核心功能 |
|-----|------|----------|
| **git-auto-push.sh** | 傳統 Git 自動化 | Add, Commit, Push, 變更訊息, 倉庫資訊 |
| **git-auto-pr.sh** | GitHub Flow 自動化 | 建立分支, 建立 PR, 審查 PR, 撤銷 PR, 刪除分支 |

### 常用指令速查

#### git-auto-push.sh

```bash
# 互動式選單（推薦）
./git-auto-push.sh

# 快速執行指定功能
./git-auto-push.sh 1    # 完整流程 (add → commit → push)
./git-auto-push.sh 4    # 全自動模式 (AI 生成內容)
./git-auto-push.sh 7    # 修改最後一次 commit 訊息
```

#### git-auto-pr.sh

```bash
# 互動式選單
./git-auto-pr.sh

# 根據提示選擇：
# 1. 建立功能分支 (jerry/feature/issue-123)
# 2. 建立 Pull Request (AI 生成內容)
# 4. 審查與合併 PR
```

> 支援 Conventional Commits 前綴、AI 內容產生、品質檢查、任務編號自動帶入等功能。詳細說明請見 [使用指南](USAGE.md)。

## 特色功能

### AI 內容產生

支援 copilot、gemini、codex、claude 四種 AI CLI 工具，一個失敗自動嘗試下一個。輸出會自動清理 AI 工具的中繼資料。開啟 `IS_DEBUG=true` 可以看到提示詞、diff 內容、輸出結果，方便除錯。

**產生的內容**

- commit 訊息：分析 git diff 產生符合 Conventional Commits 的訊息
- 品質檢查：AI 檢查 commit 訊息是否描述清楚，可設定自動檢查或詢問模式；AI 失敗不影響提交
- 任務編號：從分支名稱解析 issue key（支援 JIRA `PROJ-123`、GitHub Issue `feat-001`），自動加到 commit 前綴，涵蓋選項 1、2、4、5、7
- 分支名稱：根據 issue key、擁有者、類型產生格式化名稱（如 `username/type/issue-key`）
- PR 內容：根據分支變更歷史產生標題和描述

### 錯誤處理

- 自動偵測 `401 Unauthorized`、`token_expired`、`stream error` 等錯誤，提供對應的修復命令
- 偵測 PR 自我批准限制並提供替代方案
- 彩色格式化的錯誤訊息
- 支援 Ctrl+C 中斷退出，自動清理暫存資源

### 工作流程

**git-auto-push.sh**

- 7 種操作模式，支援分階段（add → commit → push）或一鍵完成
- 查看倉庫資訊：分支、遠端、同步狀態、提交歷史
- 修改最後一次 commit 訊息（選項 7）
- 從分支名稱自動帶入任務編號

**git-auto-pr.sh**

- 從建立分支到建立 PR 的流程
- PR 撤銷：偵測 PR 狀態，安全處理開放或已合併的 PR
- 主分支自動偵測，找不到時給出修復建議
- 偵測用戶身份避免自我批准，提供團隊審查或直接合併選項
- revert 操作預設為否，顯示影響分析
- 分支安全刪除，主分支保護

## 錯誤排除

### 常見問題及解決方案

**錯誤：`目前目錄不是 Git 儲存庫！`**

```bash
# 確認在 Git 儲存庫根目錄執行
git init  # 或移動到正確的 Git 儲存庫目錄
```

**錯誤：`沒有需要提交的變更`**

- 檢查是否有檔案變更：`git status`
- 或選擇推送現有提交到遠端

AI 工具認證錯誤

```bash
❌ codex 認證錯誤: 認證令牌已過期
💡 請執行以下命令重新登入 codex:
   codex auth login
```

當出現 `401 Unauthorized` 或 `token_expired` 錯誤時，按提示重新認證。

GitHub CLI 相關錯誤（git-auto-pr.sh）

```bash
❌ 未安裝 gh CLI 工具！請執行：brew install gh
❌ gh CLI 未登入！請執行：gh auth login
```

確保已安裝並登入 GitHub CLI。

**分支狀態錯誤**

```bash
❌ 無法從主分支 (master) 建立 PR
❌ 分支尚未推送到遠端
```

確保在功能分支上操作，並已推送到 GitHub。

**PR 審查權限錯誤**

```bash
❌ Can not approve your own pull request
⚠️  無法批准自己的 Pull Request
```

GitHub 安全政策不允許開發者批准自己的 PR。可以請團隊成員審查，或在有權限時直接合併。

**PR 撤銷相關錯誤**

```bash
❌ 當前分支沒有找到相關的 PR
⚠️ PR 已經合併，執行 revert 會影響到後續變更
```

PR 撤銷的常見情況：

- 找不到 PR：確認在正確的功能分支上
- 已合併 PR：系統會顯示影響範圍，revert 按預設需明確確認
- revert 衝突：按提示手動解決
- 權限不足：確保有關閉 PR 或推送到主分支的權限

**主分支自動偵測**

工具會依序嘗試遠端 `origin/main`、`origin/master`，最後才看本地分支。同時支援 main 和 master 兩種命名。

**AI 工具網路錯誤**

```bash
❌ codex 網路錯誤: stream error: unexpected status
💡 請檢查網路連線或稍後重試
```

網路問題會自動偵測並給出建議。

**AI 工具無法使用**

```bash
# 檢查 AI CLI 工具是否已安裝並可執行
which codex
which gemini
which claude
```

權限不足錯誤

```bash
# 確認腳本具有執行權限
chmod +x git-auto-push.sh
chmod +x git-auto-pr.sh
```

**推送失敗**

- 檢查遠端倉庫連接：`git remote -v`
- 確認網路連線和認證設定

## 進階使用

### GitHub Flow 最佳實踐

兩支腳本支援 [GitHub Flow](docs/github-flow.md) 工作流程：

**工具選擇**

- **git-auto-push.sh**: 個人開發、實驗專案、快速原型
- **git-auto-pr.sh**: 團隊協作、正式功能開發

### 實際工作流程範例

**個人開發流程**

```bash
# 快速提交和推送
git-auto-push --auto
```

**團隊協作流程**

```bash
# 1. 建立功能分支
git-auto-pr                    # 選擇選項 1

# 2. 開發完成後
git-auto-pr                    # 選擇選項 2（提交推送）

# 3. 建立 PR 供審查
git-auto-pr                    # 選擇選項 3（建立 PR）
```

## 開發修改注意事項

### 程式碼架構說明

專案採用模組化設計，主要組件包括：

#### 設定區域總覽

- **位置**：兩個腳本檔案的開頭部分
- **git-auto-push.sh**：第 28-52 行 - AI 工具優先順序和提示詞配置
- **git-auto-pr.sh**：第 25-125 行 - AI 提示詞模板、工具設定、分支設定和使用者設定
- **修改原則**：所有設定都集中在檔案上方，便於維護和修改

#### 分支設定

**git-auto-pr.sh** 的分支設定功能：

- **主分支陣列設定**：`DEFAULT_MAIN_BRANCHES=("main" "master")`
- **預設使用者設定**：`DEFAULT_USERNAME="jerry"` - 可自訂擁有者名字
- **自動偵測**：按順序偵測第一個存在的分支
- **錯誤處理**：找不到分支時提供解決建議
- 可添加 `develop`、`dev` 等分支選項

#### 統一變數管理

- **AI_TOOLS 變數**：統一的 AI 工具優先順序陣列
- **條件賦值**：使用 `: "${VAR:=default}"` 語法，配置文件優先於預設值
- **預設調用順序**：copilot → gemini → codex → claude（可透過配置文件覆蓋）

### 程式碼文檔標準

所有主要函數都採用這個格式：

```bash
# ============================================
# 函數名稱
# 功能：詳細描述函數用途和行為
# 參數：$1 - 參數說明，$2 - 參數說明
# 返回：返回值含義和錯誤程式碼
# 使用：具體的調用範例
# 注意：安全考量和特殊情況
# ============================================
```

**文件涵蓋範圍**：工具函數、核心邏輯、安全機制、使用範例

### 修改指導原則

#### 1. AI 提示詞修改

```bash
# 修改位置：檔案開頭的 AI 提示詞配置區域
generate_ai_commit_prompt() {
    # 修改 commit 訊息生成邏輯
}

generate_ai_pr_prompt() {
    # 修改 PR 內容生成邏輯
}
```

**注意**：分支名稱現已改為自動生成，不再使用 AI 產生。

#### 2. AI 工具順序調整

```bash
# 方式一：透過配置文件覆蓋（推薦）
# ~/.git-auto-push-config/.env
AI_TOOLS=("copilot" "codex" "gemini" "claude")

# 方式二：修改腳本預設值（進階）
# 找到 AI_TOOLS 預設值區塊，修改陣列內容
AI_TOOLS=(
    "copilot"   # 第一優先
    "codex"     # 第二優先
    "gemini"    # 第三優先
    "claude"    # 第四優先
)
```

#### 3. 新增 AI 工具

1. 在 `AI_TOOLS` 陣列中添加新工具名稱
2. 在對應函數中添加 case 分支處理
3. 實現對應的 `run_*_command()` 函數

#### 4. Commit 品質檢查配置

```bash
# git-auto-push.sh Commit 品質檢查配置（約 149 行）
AUTO_CHECK_COMMIT_QUALITY=true

# 自動檢查模式（預設）- 每次 commit 前自動檢查
AUTO_CHECK_COMMIT_QUALITY=true

# 詢問模式 - 提交前詢問是否檢查（預設為否）
AUTO_CHECK_COMMIT_QUALITY=false
```

**配置說明**：

- **自動檢查模式（true）**：每次 commit 前自動檢查，適合團隊規範嚴格的專案
- **詢問模式（false）**：提交前問你要不要檢查，適合快速提交場景
- AI 工具失敗時自動跳過檢查，不影響提交

#### 5. 分支配置自定義

```bash
# 方式一：透過配置文件覆蓋（推薦）
# ~/.git-auto-push-config/.env
DEFAULT_MAIN_BRANCHES=("main" "master" "develop")
DEFAULT_USERNAME="tom"
AUTO_DELETE_BRANCH_AFTER_MERGE=true

# 方式二：修改腳本預設值（進階）
# 主分支候選清單
DEFAULT_MAIN_BRANCHES=("main" "master")

# 預設使用者名稱
DEFAULT_USERNAME="jerry"

# PR 合併後分支刪除策略（true=自動刪除，false=保留）
AUTO_DELETE_BRANCH_AFTER_MERGE=false
```

**配置說明**：

- **偵測順序**：腳本按陣列順序偵測第一個存在的分支
- **預設使用者**：分支建立時的擁有者名稱，執行時可覆寫
- **分支刪除策略**：控制 PR 合併後是否自動刪除分支
  - `false`（預設）：保留分支
  - `true`：自動刪除
- 找不到分支時會顯示錯誤訊息和解決建議

#### 6. 錯誤處理擴展

- 在現有錯誤偵測函數中添加新的錯誤模式
- 更新錯誤訊息和修復建議
- 保持一致的錯誤輸出格式

### 重要注意事項

#### 同步修改要求

- **AI 工具**：修改時需同時更新兩個腳本
- **提示詞**：兩個檔案風格保持一致
- **錯誤處理**：統一處理模式和輸出格式

#### 功能測試

```bash
# 語法檢查
bash -n git-auto-push.sh
bash -n git-auto-pr.sh

# 功能測試
./git-auto-push.sh --help
./git-auto-pr.sh --help

# AI 工具測試
source git-auto-push.sh
for tool in "${AI_TOOLS[@]}"; do echo "測試 $tool"; done
```

#### 版本控制

- 修改後更新版本號
- 更新 README 中的行數統計
- 記錄重要變更到 commit message

### 常見修改場景

#### 場景 1：優化 AI 提示詞

1. 修改對應的 `generate_ai_*_prompt()` 函數
2. 測試生成效果
3. 更新相關文檔

#### 場景 2：新增錯誤處理

1. 識別新的錯誤模式
2. 在偵測函數中添加條件判斷
3. 提供具體的修復建議

#### 場景 3：調整工作流程

1. 修改 `execute_*_workflow()` 函數
2. 更新選單顯示
3. 測試流程

## 更新日誌

> 完整版本歷史請查看 [CHANGELOG.md](CHANGELOG.md)

- 最新版本：v2.8.0 (2026-02-01)
- 總版本數：16 個主要版本
- 開發期間：2025-08-21 至今
- 程式碼行數：`git-auto-push.sh` 2,552 行、`git-auto-pr.sh` 2,769 行、`install.sh` 689 行

### 參考資源

- [CHANGELOG.md](CHANGELOG.md) - 完整版本歷史與功能變更記錄
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - AI 代理開發指導
- [docs/github-flow.md](docs/github-flow.md) - GitHub Flow 說明
- [docs/pr-cancel-feature.md](docs/pr-cancel-feature.md) - PR 撤銷功能詳細說明
- [docs/git-info-feature.md](docs/git-info-feature.md) - Git 倉庫資訊功能說明
- [docs/FEATURE-AMEND.md](docs/FEATURE-AMEND.md) - 變更 commit 訊息功能說明
- [docs/FEATURE-COMMIT-QUALITY.md](docs/FEATURE-COMMIT-QUALITY.md) - Commit 品質檢查功能說明

## 截圖展示

git-auto-pr.sh 主要操作選單：![主選單](screenshots/main-menu.png)

AI 自動生成 Git 提交訊息：![AI 提交](screenshots/ai-commit-generation.png)

git-auto-push.sh 全自動操作模式：![自動模式](screenshots/auto-mode.png)

命令列 PR 建立流程：![PR CLI](screenshots/pr-screenshot-cli.png)

GitHub 網頁 PR 建立結果：![PR Web](screenshots/pr-screenshot-web.png)

## 授權條款

本專案採用 MIT 授權條款。詳細資訊請參閱 [LICENSE](LICENSE) 檔案。

