# Git 工作流程自動化工具集

Git 工作流程自動化解決方案，包含傳統 Git 操作自動化和 GitHub Flow PR 流程。整合 AI 驅動的內容產生功能、檔案過濾系統、Commit 訊息品質檢查、任務編號自動帶入、調試模式和錯誤處理機制。

版本：v2.5.0

## 專案簡介

### 主要功能亮點

- 傳統 Git 工作流程自動化（新增、提交、推送）
- **檔案過濾功能** 🆕（選擇性 git add，支援 glob pattern 過濾規則）
- Git 倉庫資訊查看（分支狀態、遠端配置、同步狀態、提交歷史）
- Commit 訊息修改功能（安全修改最後一次 commit 訊息，支援任務編號）
- Commit 訊息品質檢查 🆕（AI 驅動的提交品質檢測，可配置自動檢查或詢問模式）
- GitHub Flow PR 流程自動化（分支建立到 PR 建立）
- PR 生命週期管理（建立、撤銷、審查、合併）
- 分支管理系統（安全刪除、主分支保護、多重確認）
- AI 驅動的內容產生（commit 訊息、分支名稱、PR 內容）
- 錯誤處理與修復建議
- 多 AI 工具整合與自動容錯機制
- 程式碼文件（為所有主要函數加入註解標準）
- 中斷復原和信號處理機制

## 系統架構

### 核心元件架構

```
├── git-auto-push.sh      # 傳統 Git 工作流程自動化（3065 行，註解與流程說明）
├── git-auto-pr.sh        # GitHub Flow PR 流程自動化（3135 行，程式碼文件與流程註解）
├── 檔案過濾系統 🆕        # 選擇性 git add 機制
│   ├── 過濾規則檔案      # git-auto-push-ignore.txt（可選）
│   ├── Glob Pattern 支援 # 支援 * 和 **，格式同 .gitignore
│   ├── 路徑處理          # 相對/絕對路徑自動識別
│   ├── 權限檢查          # 檔案建立與讀取權限驗證
│   └── 動態回饋          # 顯示過濾與添加的檔案清單
├── AI 工具整合模組        # 支援 codex、gemini、claude
│   ├── 錯誤偵測          # 認證過期、網路錯誤自動識別
│   ├── 錯誤提示          # 提供具體解決方案
│   ├── 多工具容錯機制    # AI 工具失效時的備援機制
│   ├── 輸出清理系統      # 過濾 AI 工具中繼資料和技術雜訊
│   └── 品質檢查系統 🆕    # AI 驅動的 commit 訊息品質分析
├── 任務編號整合系統 🆕    # 自動偵測並加入 issue key
│   ├── 分支名稱解析      # 支援 JIRA/GitHub Issue 等格式
│   ├── 自動/詢問模式     # 可配置的任務編號帶入策略
│   └── 重複檢測          # 避免重複加入任務編號
├── Commit 訊息修改系統 🆕 # 安全修改最後一次 commit
│   ├── 智慧安全檢查      # 未提交變更檢測與警告
│   ├── 參考訊息顯示      # 顯示目前 commit 內容
│   └── 二次確認機制      # 防止誤操作
├── 互動式選單系統        # 操作選項與使用者介面
├── Loading 動畫系統      # 等待提示與進度顯示
├── 調試模式系統 🆕        # AI 工具執行詳情追蹤
├── 信號處理機制          # 多層級 trap cleanup 與中斷復原
├── 錯誤處理系統          # 異常處理與修復引導
└── 程式碼文件            # 統一函數註解、詳細使用說明、安全機制文件
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
│   ├── git-auto-push.mermaid             # Git 自動化流程圖 🆕
│   ├── git-auto-pr.mermaid               # PR 流程圖 🆕
│   ├── git_auto_push_workflow.png        # Git 工作流程圖 🆕
│   ├── git_pr_automation.png             # PR 自動化圖 🆕
│   └── reports/                          # 詳細文件報告 🆕
│       ├── FEATURE-AMEND.md              # 變更 commit 訊息功能說明
│       ├── FEATURE-COMMIT-QUALITY.md     # Commit 品質檢查功能說明
│       ├── COMMIT-QUALITY-SUMMARY.md     # Commit 品質檢查摘要
│       ├── COMMIT-QUALITY-QUICKREF.md    # Commit 品質快速參考
│       ├── AI-QUALITY-CHECK-IMPROVEMENT.md # AI 品質檢查改進說明
│       ├── 檔案過濾功能開發報告.md        # 檔案過濾功能詳細報告 🆕
│       ├── 添加過濾檔案.md               # 過濾檔案使用說明 🆕
│       └── 選項7-變更commit訊息功能開發報告.md # 選項 7 開發報告
└── screenshots/         # 介面展示圖片
    ├── ai-commit-generation.png
    ├── auto-mode.png
    ├── main-menu.png
    ├── pr-screenshot-cli.png
    └── pr-screenshot-web.png
```

## 安裝與啟動

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

### 3. 全域安裝（選擇性）

```bash
# 安裝 git-auto-push 到系統路徑
sudo install -m 755 git-auto-push.sh /usr/local/bin/git-auto-push

# 安裝 git-auto-pr 到系統路徑
sudo install -m 755 git-auto-pr.sh /usr/local/bin/git-auto-pr
```

安裝完之後能夠直接呼叫 git-auto-push 或 git-auto-pr 啟動腳本。

### 4. 相依工具安裝

#### GitHub CLI（git-auto-pr.sh 必需）

```bash
# macOS
brew install gh
gh auth login  # 選擇 GitHub.com → HTTPS → Browser 登入
```

#### AI CLI 工具（可選，建議）

安裝任一或多個 AI CLI 工具以啟用內容產生功能：

```bash
# GitHub Copilot CLI (建議)
gh extension install github/gh-copilot

# Google Gemini CLI (需要 API Key)
# 安裝方式請參考 Google AI Studio 官方文件

# Anthropic Claude CLI (需要 API Key)
# 安裝方式請參考 Anthropic Console 官方文件

# 或其他相容的 AI CLI 工具
# 工具會自動偵測可用的 AI 命令
```

**注意**：AI 工具需要相應的 API 金鑰或訂閱服務。如未安裝，工具仍可使用，僅會跳過 AI 輔助功能。

## 使用方法

### git-auto-push.sh - 傳統 Git 自動化

```bash
# 互動式模式（預設）
./git-auto-push.sh

# 全自動模式
./git-auto-push.sh --auto
./git-auto-push.sh -a

# 全域安裝後使用
git-auto-push
git-auto-push --auto
```

#### git-auto-push.sh 操作模式

1. 完整流程：add → 互動輸入 commit → push（日常開發提交）
2. 本機提交：add → 互動輸入 commit（離線開發或測試提交）
3. 僅新增檔案：add（暫存檔案變更）
4. 全自動模式：add → AI 產生 commit → push（CI/CD 或快速提交）
5. 僅提交：commit（提交已暫存的檔案）
6. 顯示倉庫資訊：顯示 Git 倉庫詳細資訊（查看倉庫狀態與配置）
7. 變更最後一次 commit 訊息：修改最近一次提交的訊息內容（修正錯誤或補充說明）

**智慧品質檢查** 🆕：
- 模式 1-5 支援可配置的 AI commit 訊息品質檢查
- 檢測訊息是否清楚描述變更內容和目的
- 可設定自動檢查（預設）或詢問模式

### git-auto-pr.sh - GitHub Flow PR 自動化

```bash
# 互動式模式（預設）
./git-auto-pr.sh

# 全域安裝後使用
git-auto-pr
```

#### git-auto-pr.sh 操作模式

1. 建立功能分支：輸入 issue key、擁有者、類型，自動生成分支（開始新功能開發）
2. 建立 PR：基於目前分支建立 Pull Request（提交程式碼審查）
3. 撤銷目前 PR：關閉開放 PR / Revert 已合併 PR（PR 錯誤修正）
4. 審查與合併 PR：審查 → 批准/請求變更 → 合併（專案擁有者 PR 管理）
5. 刪除分支：安全刪除本地/遠端功能分支（分支清理與維護）

#### GitHub Flow 工作流程特色

- Issue 整合：支援 JIRA、GitHub Issue 等多種編號格式
- 分支類型分類：提供 issue、bug、feature、enhancement、blocker 五種分支類型
- 自動分支命名：基於 `{username}/{type}/{issue-key}` 格式自動生成標準分支名
- AI 內容產生：commit message、PR 標題和內容可由 AI 輔助生成
- PR 生命週期管理：建立 → 撤銷 → 審查 → 合併，涵蓋 PR 各階段操作
- 撤銷機制：自動偵測 PR 狀態，提供安全的關閉或 revert 選項
- 驗證機制：檢查 Git 儲存庫、gh CLI 登入狀態、分支狀態
- 錯誤處理：錯誤偵測與修復建議
- 中斷復原：支援 Ctrl+C 中斷與優雅清理
- 多分支支援：自動偵測 main/master 主分支

## 使用情境

### git-auto-push.sh 使用情境

#### 日常開發流程

```bash
# 修改程式碼後，執行流程
./git-auto-push.sh
# 選擇選項 1，輸入 commit message，自動推送
```

#### 快速自動提交

```bash
# AI 自動生成 commit message 並推送
./git-auto-push.sh --auto
```

#### 離線開發

```bash
# 只提交到本地，不推送
./git-auto-push.sh
# 選擇選項 2
```

#### 分階段操作

```bash
# 先新增檔案
./git-auto-push.sh  # 選擇選項 3

# 稍後提交
./git-auto-push.sh  # 選擇選項 5
```

#### 檔案過濾功能 🆕

```bash
# 使用檔案過濾進行選擇性 add
./git-auto-push.sh
# 選擇選項 1-4 任一操作

# 功能特色：
# - 自動建立 git-auto-push-ignore.txt 過濾檔案（首次使用）
# - 支援 glob pattern：* 和 **（格式同 .gitignore）
# - 相對路徑以執行目錄為基準
# - 顯示被忽略的檔案清單
# - 顯示實際過濾檔案的完整路徑

# 過濾檔案範例（git-auto-push-ignore.txt）：
# *.log                    # 忽略所有 log 檔
# test-*.sh                # 忽略測試腳本
# docs/draft/              # 忽略草稿目錄
# **/temp/*                # 忽略所有 temp 目錄下的檔案
# config/local.*.json      # 忽略本地配置檔

# 使用情境：
# ✅ 臨時檔案：不想加入 .gitignore，但也不想每次都 add
# ✅ 實驗性修改：保持在 unstaged 方便隨時丟棄
# ✅ 敏感配置：開發環境的設定檔

# 配置位置：
# 腳本頂部 IGNORE_FILE_PATH 變數（約 185 行）
# 預設：git-auto-push-ignore.txt（相對路徑）
```

#### 查看 Git 倉庫資訊

```bash
# 快速查看倉庫狀態、分支、遠端配置等資訊
./git-auto-push.sh
# 選擇選項 6
# 顯示內容包括：
# - 當前分支和追蹤狀態
# - 遠端倉庫 URL
# - 最近 5 筆 commit
# - 分支來源分析
# - 同步狀態（領先/落後）
# - 工作區狀態
```

#### 修改最後一次 commit 訊息

```bash
# 修正 commit 訊息錯誤或補充說明
./git-auto-push.sh
# 選擇選項 7
# 功能特色：
# - 自動檢查是否有未提交的變更（有則警告並中止）
# - 顯示目前的 commit 訊息供參考
# - 支援任務編號自動帶入
# - 二次確認機制
# - 安全執行 git commit --amend
# ⚠️ 注意：僅適用於尚未推送的本地 commit
```

#### Commit 訊息品質檢查 🆕

```bash
# 自動檢查模式（預設）
# 每次 commit 前自動使用 AI 檢查訊息品質
./git-auto-push.sh
# 選擇選項 1-5 任一操作
# 功能特色：
# - AI 分析訊息是否明確描述變更內容和目的
# - 檢查不良時提供警告和改進建議
# - AI 失敗時自動跳過，不影響提交流程
# - 可配置為詢問模式（false），每次詢問是否檢查
# - 設定位置：腳本頂部 AUTO_CHECK_COMMIT_QUALITY 變數（約 149 行）

# 檢查標準：
# ✅ 良好：「新增用戶登入功能，支援 OAuth 2.0 驗證」
# ❌ 不良：「fix bug」、「update」、「修改程式碼」
```

### git-auto-pr.sh 使用情境 ✨

#### GitHub Flow 開發流程

```bash
# 1. 開始新功能開發
./git-auto-pr.sh
# 選擇選項 1，輸入 issue key、擁有者名字、選擇分支類型，自動生成分支

# 2. 開發完成後建立 PR
./git-auto-pr.sh
# 選擇選項 2（建立 PR）
# AI 產生 PR 標題和內容
```

#### 撤銷 Pull Request

```bash
# 撤銷當前分支的 PR（檢測 PR 狀態）
./git-auto-pr.sh
# 選擇選項 3（撤銷當前 PR）
# 系統會自動偵測：
# - 開放中的 PR：提供關閉選項
# - 已合併的 PR：提供 revert 選項（預設為否）
# - 顯示詳細影響分析供決策參考
```

#### 分步驟操作

```bash
# 1. 建立功能分支
./git-auto-pr.sh  # 選擇選項 1
# 輸入 issue key（如 PROJ-123）、擁有者名字（預設 jerry）、選擇分支類型
# 系統自動生成分支：jerry/feature/proj-123

# 2. 建立 PR
./git-auto-pr.sh  # 選擇選項 2
# AI 產生 PR 標題和內容

# 3. 如需撤銷 PR（錯誤提交、需要重構等）
./git-auto-pr.sh  # 選擇選項 3
# 系統自動偵測並提供撤銷選項
```

#### 團隊協作場景

```bash
# 開發者：基於 main 分支開始新功能
git checkout main && git pull
./git-auto-pr.sh  # 選擇選項 1
# 輸入：issue key: PROJ-123, 擁有者: tom, 類型: feature
# 自動建立分支：tom/feature/proj-123

# 開發者：功能完成，建立 PR 供審查
./git-auto-pr.sh  # 選擇選項 2（建立 PR）

# 專案擁有者：審查並合併 PR
./git-auto-pr.sh  # 選擇選項 4，審查 → 批准 → 合併
```

#### 分支建立流程說明

```bash
# 執行分支建立
./git-auto-pr.sh  # 選擇選項 1

# 步驟 1：輸入 Issue Key
請輸入 issue key: PROJ-123
✅ 使用標準格式 issue key: PROJ-123

# 步驟 2：輸入擁有者名字（預設：jerry）
請輸入擁有者名字 [預設: jerry]: tom
👤 使用者名稱: tom

# 步驟 3：選擇分支類型
📋 分支類型說明：
1. issue - 問題（專案障礙、延誤）
2. bug - 錯誤（系統性錯誤）
3. feature - 功能請求（新功能）
4. enhancement - 增強（改進現有功能）
5. blocker - 阻礙（關鍵問題）

請選擇分支類型 [1-5]: 3
🏷️  分支類型: feature

# 自動生成分支
📝 將建立分支: tom/feature/proj-123
✅ 成功建立功能分支: tom/feature/proj-123
```

**分支命名規則**：

- 格式：`{username}/{type}/{issue-key}`
- 自動轉換為小寫
- 範例：`jerry/bug/issue-456`、`mary/enhancement/jira-789`

#### 專案擁有者 PR 管理

```bash
# 查看和審查待處理的 PR
./git-auto-pr.sh  # 選擇選項 4

# 系統會自動：
# 1. 列出所有待審查的 PR
# 2. 顯示選定 PR 的詳細資訊和 CI 狀態
# 3. 提供審查選項：批准並合併、添加評論、請求變更
# 4. 自動使用 squash 合併並刪除功能分支
# 5. 更新本地 main 分支
```

#### 分支管理與清理

```bash
# 清理不需要的功能分支
./git-auto-pr.sh  # 選擇選項 5

# 系統會自動：
# 1. 列出所有可刪除的分支（排除主分支）
# 2. 標記當前分支，防止誤刪
# 3. 提供多重安全確認機制
# 4. 處理已合併/未合併分支
# 5. 可選擇同時清理對應的遠端分支
```

## 特色功能

### AI 內容產生系統

**多 AI 工具整合**

- 支援 codex、gemini、claude 三種 AI CLI 工具
- 自動容錯機制：當一個 AI 工具失效時自動嘗試下一個
- 輸出清理：過濾 AI 工具的元數據和技術雜訊
- 提示優化：精簡 70%+ 提示長度，提升處理速度和準確性
- 調試模式 🆕：開發階段的 AI 工具執行詳情追蹤
  - 記錄輸入提示詞、diff 內容、輸出結果
  - 超時、執行失敗、無輸出等情況的詳細診斷資訊
  - 可透過 `IS_DEBUG` 變數開關（預設關閉）

**內容產生與品質檢查**

- commit 訊息：分析 git diff 自動產生符合 Conventional Commits 規範的訊息
- 品質檢查 🆕：AI 檢查 commit 訊息是否明確描述變更內容和目的
  - 可配置自動檢查或詢問模式
  - 檢查不良時提供警告和改進建議
  - 容錯設計，AI 失敗不影響提交流程
- 任務編號整合 🆕：從分支名稱自動偵測並加入 issue key 前綴
  - 智慧解析：支援 JIRA（`PROJ-123`）、GitHub Issue（`feat-001`）等格式
  - 靈活配置：自動模式（預設）或詢問模式
  - 重複檢測：避免重複加入任務編號
  - 整合範圍：涵蓋所有 commit 操作（選項 1、2、4、5、7）
- 分支名稱：基於 issue key、擁有者、分支類型自動生成標準格式（如 `username/type/issue-key`）
- PR 內容：基於分支變更歷史產生 PR 標題和描述
- 即時驗證：自動偵測分支名稱有效性並處理特殊字元

### 錯誤處理

**錯誤偵測與修復**

- 自動偵測 `401 Unauthorized` 和 `token_expired` 認證錯誤
- 偵測 `stream error`、網路超時等連接問題
- GitHub 政策合規：自動偵測 PR 自我批准限制並提供替代方案
- 提供具體的修復命令和操作步驟

**使用者體驗優化**

- 彩色格式化的錯誤訊息與成功提示
- Loading 動畫顯示操作進度和等待時間
- 即時停止無效重試，避免浪費時間
- 中斷恢復機制：支援 Ctrl+C 優雅退出

### 工作流程自動化

**傳統 Git 流程（git-auto-push.sh）**

- 7 種操作模式滿足不同開發場景
- Git 倉庫資訊查看：快速瀏覽分支、遠端、同步狀態、提交歷史
- Commit 訊息修改：安全修改最後一次 commit 訊息（選項 7）
- 任務編號自動帶入：從分支名稱偵測並加入 issue key
- 支援離線開發和 CI/CD 整合
- 分階段操作支援：添加 → 提交 → 推送

**GitHub Flow 流程（git-auto-pr.sh）**

- PR 流程自動化
- PR 撤銷系統：自動偵測 PR 狀態，安全處理開放和已合併 PR
- 分支設定系統：可設定主分支候選清單，按優先順序自動偵測
- 分支錯誤處理：找不到主分支時提供詳細解決建議和修復命令
- 分支狀態驗證
- PR 審查管理：自動偵測用戶身份避免自我批准，提供團隊審查或直接合併選項
- 安全保護機制：revert 操作預設為否，顯示詳細影響分析
- 分支管理：安全的分支刪除功能，主分支保護與多重確認機制
- 分支生命週期管理：分支建立、使用、清理流程，主分支保護機制

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

GitHub 安全政策不允許開發者批准自己的 PR。解決方案：

- 請其他團隊成員使用此工具進行審查
- 如有權限可選擇直接合併
- 或使用評論功能進行自我記錄

**PR 撤銷相關錯誤**

```bash
❌ 當前分支沒有找到相關的 PR
⚠️ PR 已經合併，執行 revert 會影響到後續變更
```

PR 撤銷功能的常見情況處理：

- **找不到 PR**：確認在正確的功能分支上，或手動檢查其他分支
- **已合併 PR**：系統會顯示影響範圍，revert 操作預設為否需明確確認
- **revert 衝突**：按提示手動解決衝突後完成操作
- **權限不足**：確保有關閉 PR 或推送到主分支的權限

**主分支自動偵測**

工具自動偵測主分支名稱：

- 優先偵測遠端 `origin/main` 分支
- 備選偵測 `origin/master` 分支
- 本地分支作為最後選項
- 同時支援現代儲存庫（main）和傳統儲存庫（master）

**AI 工具網路錯誤**

```bash
❌ codex 網路錯誤: stream error: unexpected status
💡 請檢查網路連線或稍後重試
```

網路問題會自動偵測並提供具體建議。

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

### GitHub Flow 最佳實踐整合

本工具集支援 [GitHub Flow](docs/github-flow.md) 工作流程：

**工具選擇建議**

- **git-auto-push.sh**: 個人開發、實驗專案、快速原型
- **git-auto-pr.sh**: 團隊協作、企業專案、正式功能開發

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

### 🛠️ 程式碼架構說明

本專案採用模組化設計，主要組件包括：

#### 設定區域總覽

- **位置**：兩個腳本檔案的開頭部分
- **git-auto-push.sh**：第 28-52 行 - AI 工具優先順序和提示詞配置
- **git-auto-pr.sh**：第 25-125 行 - AI 提示詞模板、工具設定、分支設定和使用者設定
- **修改原則**：所有設定都集中在檔案上方，便於維護和修改

#### 分支設定系統（NEW! ✨）

**git-auto-pr.sh** 新增分支設定功能：

- **主分支陣列設定**：`DEFAULT_MAIN_BRANCHES=("main" "master")`
- **預設使用者設定**：`DEFAULT_USERNAME="jerry"` - 可自訂預設擁有者名字
- **自動偵測機制**：按順序偵測第一個存在的分支
- **錯誤處理**：找不到分支時提供詳細解決建議
- **易於擴展**：可添加 `develop`、`dev` 等更多分支選項

#### 統一變數管理

- **AI_TOOLS 變數**：統一的 AI 工具優先順序陣列
- **readonly 保護**：防止意外修改配置
- **調用順序**：codex → gemini → claude

### 📝 程式碼文檔標準

本專案採用程式碼文檔標準，所有主要函數都包含：

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

**文件涵蓋範圍**：

- ✅ 所有工具函數（錯誤處理、訊息顯示、Git 操作）
- ✅ 核心業務邏輯（分支管理、PR 處理、AI 整合）
- ✅ 安全機制說明（權限檢查、多重確認、錯誤處理）
- ✅ 使用範例和最佳實踐

### 📝 修改指導原則

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
# 修改 AI_TOOLS 陣列即可改變調用順序
readonly AI_TOOLS=(
    "codex"     # 第一優先
    "gemini"    # 第二優先
    "claude"    # 第三優先
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

- **自動檢查模式（true）**：適合團隊規範嚴格、需要確保 commit 品質的專案
- **詢問模式（false）**：適合快速提交場景、只在重要提交時檢查
- **容錯設計**：AI 工具失敗時自動跳過檢查，不影響提交流程
- **智慧分析**：檢查訊息是否明確描述變更內容和目的
- **友善提示**：品質不良時提供警告和改進建議

#### 5. 分支配置自定義

```bash
# git-auto-pr.sh 主分支配置修改（第 200 行）
readonly -a DEFAULT_MAIN_BRANCHES=("main" "master")

# 添加更多分支選項
readonly -a DEFAULT_MAIN_BRANCHES=("main" "master" "develop" "dev")

# 只使用特定分支
readonly -a DEFAULT_MAIN_BRANCHES=("main")

# 預設使用者名稱配置（第 211 行）
readonly DEFAULT_USERNAME="jerry"

# 修改為您的名字或團隊慣例
readonly DEFAULT_USERNAME="tom"

# PR 合併後分支刪除策略配置（第 217 行）
readonly AUTO_DELETE_BRANCH_AFTER_MERGE=false

# 自動刪除分支（適合短期功能分支）
readonly AUTO_DELETE_BRANCH_AFTER_MERGE=true

# 保留分支（適合需要追蹤的分支，預設值）
readonly AUTO_DELETE_BRANCH_AFTER_MERGE=false
```

**配置說明**：

- **偵測順序**：腳本會按陣列順序偵測第一個存在的分支
- **預設使用者**：分支建立時的預設擁有者名稱，可在執行時覆蓋
- **分支刪除策略**：控制 PR 合併後是否自動刪除功能分支
  - `false`（預設）：合併後保留分支，適合需要追蹤歷史的專案
  - `true`：合併後自動刪除分支，適合短期功能分支，保持倉庫整潔
- **錯誤處理**：找不到任何分支時會顯示詳細錯誤訊息和解決建議
- **動態提示**：錯誤訊息會根據配置陣列動態生成修復指令

#### 6. 錯誤處理擴展

- 在現有錯誤偵測函數中添加新的錯誤模式
- 更新錯誤訊息和修復建議
- 保持一致的錯誤輸出格式

### ⚠️ 重要注意事項

#### 同步修改要求

- **AI 工具整合**：修改 AI 工具時，需同時更新兩個腳本檔案
- **提示詞優化**：兩個檔案的提示詞風格應保持一致
- **錯誤處理**：統一的錯誤處理模式和輸出格式

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

### 🔧 常見修改場景

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

## 📋 更新日誌

> 📋 **詳細版本歷史**：查看完整的 [CHANGELOG.md](CHANGELOG.md) 瞭解所有版本更新記錄

### 最新版本 - v2.5.0 (2025-11-09)

**🔧 重構優化與專案清理**

- ✨ **程式碼重構**：統一使用 `get_git_status()` 函數，消除重複程式碼，提升維護性
- 🐛 **中文檔案名稱修復**：解決中文檔案在 Git 中的顯示問題，設定 `core.quotepath false`
- 🛠️ **Git Rename 處理**：改善 rename 操作邏輯，新增狀態碼區分（R、D、A、M）
- 🗑️ **專案清理**：移除 .DS_Store 並建立完整的 .gitignore，整理文件結構

### 主要功能特色

- 🔄 **檔案過濾系統**：選擇性 git add 機制 (v2.4.0)
- 🏷️ **任務編號整合**：自動從分支名稱偵測並加入 issue key (v2.3.0) 
- ✅ **Commit 品質檢查**：AI 驅動的訊息品質驗證 (v2.2.0)
- ✏️ **Commit 修改功能**：安全修改最後一次 commit 訊息 (v2.1.0)
- 🗑️ **分支管理系統**：安全的分支刪除與保護機制 (v1.4.1)
- 📊 **倉庫資訊查看**：完整的 Git 狀態概覽 (v1.5.0)

### 版本統計

- 📅 **最新版本**：v2.5.0 (2025-11-09)
- 📈 **總版本數**：13 個主要版本
- 🗓️ **開發期間**：2025-09-13 至今
- 📊 **代碼行數**：
  - `git-auto-push.sh`：3,065 行
  - `git-auto-pr.sh`：3,135 行

---
*完整的版本歷史和詳細功能說明請參考 [CHANGELOG.md](CHANGELOG.md)*

### 參考資源

- [CHANGELOG.md](CHANGELOG.md) - 完整版本歷史與功能變更記錄 🆕
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - AI 代理開發指導
- [docs/github-flow.md](docs/github-flow.md) - GitHub Flow 說明
- [docs/pr-cancel-feature.md](docs/pr-cancel-feature.md) - PR 撤銷功能詳細說明
- [docs/git-info-feature.md](docs/git-info-feature.md) - Git 倉庫資訊功能說明
- [docs/FEATURE-AMEND.md](docs/FEATURE-AMEND.md) - 變更 commit 訊息功能說明
- [docs/FEATURE-COMMIT-QUALITY.md](docs/FEATURE-COMMIT-QUALITY.md) - Commit 品質檢查功能說明 🆕

## 截圖展示

git-auto-pr.sh 主要操作選單：![主選單](screenshots/main-menu.png)

AI 自動生成 Git 提交訊息：![AI 提交](screenshots/ai-commit-generation.png)

git-auto-push.sh 全自動操作模式：![自動模式](screenshots/auto-mode.png)

命令列 PR 建立流程：![PR CLI](screenshots/pr-screenshot-cli.png)

GitHub 網頁 PR 建立結果：![PR Web](screenshots/pr-screenshot-web.png)

## 授權條款

本專案採用 MIT 授權條款。詳細資訊請參閱 [LICENSE](LICENSE) 檔案。

