# Git 工作流程自動化工具集

Git 工作流程自動化解決方案，包含傳統 Git 操作自動化和 GitHub Flow PR 流程。整合 AI 驅動的內容產生功能和錯誤處理機制。

版本：v2.3.0

## 專案簡介

### TODO

#### git-auto-push

- [x] commit 檢測 issue key 帶在前面，檢測到的話帶入前綴。
- [x] 檢測 commit 是否有功能性，沒有的話提出警告。（✅ v2.2.0 已實作 AI 品質檢查）
- [ ] add 時自動忽略已經設定的檔案，檔案清單可由變數設定或由外部列表提供

### 主要功能亮點

- 傳統 Git 工作流程自動化（新增、提交、推送）
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
├── git-auto-push.sh      # 傳統 Git 工作流程自動化（2184 行，註解與流程說明）
├── git-auto-pr.sh        # GitHub Flow PR 流程自動化（2896 行，程式碼文件與流程註解）
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
│   ├── github-flow.md                    # GitHub Flow 流程說明
│   ├── pr-cancel-feature.md              # PR 撤銷功能說明
│   ├── git-info-feature.md               # Git 倉庫資訊顯示功能說明
│   ├── git-usage.md                      # Git 使用說明
│   ├── FEATURE-AMEND.md                  # 變更 commit 訊息功能說明 🆕
│   ├── FEATURE-COMMIT-QUALITY.md         # Commit 品質檢查功能說明 🆕
│   ├── COMMIT-QUALITY-SUMMARY.md         # Commit 品質檢查摘要 🆕
│   ├── COMMIT-QUALITY-QUICKREF.md        # Commit 品質快速參考 🆕
│   ├── AI-QUALITY-CHECK-IMPROVEMENT.md   # AI 品質檢查改進說明 🆕
│   └── reports/
│       └── 選項7-變更commit訊息功能開發報告.md  # 選項 7 開發報告 🆕
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

**內容產生與品質檢查**

- commit 訊息：分析 git diff 自動產生符合 Conventional Commits 規範的訊息
- 品質檢查 🆕：AI 檢查 commit 訊息是否明確描述變更內容和目的
  - 可配置自動檢查或詢問模式
  - 檢查不良時提供警告和改進建議
  - 容錯設計，AI 失敗不影響提交流程
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

- 6 種操作模式滿足不同開發場景
- Git 倉庫資訊查看：快速瀏覽分支、遠端、同步狀態、提交歷史
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

````bash
❌ 當前分支沒有找到相關的 PR
```bash
⚠️ PR 已經合併，執行 revert 會影響到後續變更
````

````

PR 撤銷功能的常見情況處理：

- **找不到 PR**：確認在正確的功能分支上，或手動檢查其他分支
- **已合併 PR**：系統會顯示影響範圍，revert 操作預設為否需明確確認
- **revert 衝突**：按提示手動解決衝突後完成操作
- **權限不足**：確保有關閉 PR 或推送到主分支的權限

主分支自動偵測

工具自動偵測主分支名稱：

- 優先偵測遠端 `origin/main` 分支
- 備選偵測 `origin/master` 分支
- 本地分支作為最後選項
- 同時支援現代儲存庫（main）和傳統儲存庫（master）

AI 工具網路錯誤

```bash
❌ codex 網路錯誤: stream error: unexpected status
💡 請檢查網路連線或稍後重試
```

網路問題會自動偵測並提供具體建議。

AI 工具無法使用

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

### v2.2.1 - 使用者體驗優化 (2025-11-08)

**🔧 改進**

- **AI 訊息確認提示優化**：改善「是否使用此訊息？」的使用者引導
  - 新增「💡 下一步動作：」明確說明
  - 根據 `AUTO_CHECK_COMMIT_QUALITY` 配置動態顯示下一步流程
  - 清楚標示按 Enter 或 y 的行為（使用訊息並檢查品質 vs 稍後詢問）
  - 統一提示格式，提升操作透明度

**📊 行數統計更新**

- `git-auto-push.sh`：2701 行（+17 行使用者體驗改進）

**🎯 改進效果**

- ✅ 使用者更清楚接受訊息後的下一步流程
- ✅ 減少操作意外和疑惑
- ✅ 根據配置提供精確的操作預期

---

### v2.2.0 - Commit 訊息品質檢查功能 (2025-11-08)

**🆕 新功能**

- **AI 驅動的品質檢查** 🆕：新增 commit 訊息品質檢查功能
  - 智慧分析：使用 AI 檢查訊息是否明確描述變更內容和目的
  - 彈性配置：支援自動檢查（預設）和詢問模式
  - 容錯設計：AI 工具失敗時自動跳過，不影響提交流程
  - 友善提示：品質不良時提供警告和改進建議
- **配置變數** 🆕：新增 `AUTO_CHECK_COMMIT_QUALITY` 變數控制檢查行為
  - `true`（預設）：每次 commit 前自動檢查
  - `false`：提交前詢問是否檢查（預設為否）

**🔧 改進**

- 品質標準定義：區分良好和不良的 commit 訊息範例
- 操作流程優化：自然整合至現有提交流程
- 說明文件完善：新增詳細的功能說明和使用指導

**📁 新增文檔**

- `docs/FEATURE-COMMIT-QUALITY.md` - Commit 品質檢查功能詳細說明
- `docs/COMMIT-QUALITY-SUMMARY.md` - 品質檢查功能摘要
- `docs/COMMIT-QUALITY-QUICKREF.md` - 快速參考指南
- `docs/AI-QUALITY-CHECK-IMPROVEMENT.md` - AI 品質檢查改進說明

**📊 行數統計**

- `git-auto-push.sh`：維持 2184 行（功能整合優化）

**🎯 使用場景**

- ✅ 確保 commit 訊息清晰描述變更內容
- ✅ 培養團隊良好的提交習慣
- ✅ 維護高品質的專案提交歷史
- ✅ 避免模糊或無意義的 commit 訊息

**⚙️ 配置方式**

```bash
# 修改 git-auto-push.sh 約 149 行
# 自動檢查模式（預設）
AUTO_CHECK_COMMIT_QUALITY=true

# 詢問模式
AUTO_CHECK_COMMIT_QUALITY=false
```

---

### v2.1.0 - Commit 訊息修改功能 (2025-11-02)

**🆕 新功能**

- **變更最後一次 commit 訊息** 🆕：新增選項 7，安全修改最近一次提交的訊息
  - 智慧安全檢查：自動偵測未提交的變更並警告
  - 參考訊息顯示：修改前顯示目前的 commit 訊息
  - 任務編號整合：支援自動帶入或詢問加入任務編號前綴
  - 二次確認機制：顯示完整新訊息並要求確認
  - 清楚反饋：成功後顯示修改結果
- **快速選項** 🆕：無變更時提供 p/7/6 快速選項（推送/修改/查看）
- **黃色訊息函數** 🆕：新增 `yellow_msg()` 用於重要提示

**🔧 改進**

- 操作模式擴展：從 6 選項擴展為 7 選項
- 選單更新：輸入提示範圍更新為 `[1-7]`
- 說明文件完善：新增「7️⃣ 變更最後一次 commit 訊息」完整說明
- 無變更流程優化：提供更多操作選項而非僅推送

**📁 新增文檔**

- `docs/FEATURE-AMEND.md` - 變更 commit 訊息功能詳細說明

**📊 行數統計更新**

- `git-auto-push.sh`：2184 行（+129 行新功能）

**⚠️ 使用注意**

- ✅ 適用於尚未推送的本地 commit
- ⚠️ 避免修改已推送至遠端的 commit
- 💡 團隊協作時建議使用新 commit 而非 amend

---

### v2.3.0 - 任務編號整合與調試模式 (2025-11-09)

**🆕 新功能**

- **任務編號自動帶入** 🆕：從分支名稱自動偵測並加入 issue key 前綴
  - 智慧解析：支援 JIRA、GitHub Issue 等多種編號格式（如 `PROJ-123`、`feat-001`）
  - 靈活配置：支援自動模式（預設）和詢問模式
  - 重複檢測：避免重複加入任務編號
  - 整合範圍：涵蓋所有 commit 操作（包括選項 1、2、4、5、7）
  - 分支命名：自動從分支名稱（如 `jerry/feature/feat-001`）提取任務編號

- **調試模式** 🆕：開發階段的 AI 工具執行詳情追蹤
  - 完整日誌：記錄 AI 工具的輸入提示詞、diff 內容、輸出結果
  - 錯誤診斷：超時、執行失敗、無輸出等情況的詳細資訊
  - 可配置：透過 `IS_DEBUG` 變數開關（預設關閉）
  - 開發友善：協助問題排查和 AI 提示詞優化

**🔧 改進**

- Commit 訊息流程優化：所有 commit 輸入點統一支援任務編號
- 使用者提示增強：清楚顯示任務編號偵測狀態和帶入模式
- 配置變數整合：統一的 `AUTO_INCLUDE_TICKET` 配置管理

**⚙️ 配置方式**

```bash
# 任務編號配置（git-auto-push.sh 約第 131 行）
AUTO_INCLUDE_TICKET=true   # 自動加入（預設）
AUTO_INCLUDE_TICKET=false  # 詢問模式

# 調試模式配置（git-auto-push.sh 約第 156 行）
IS_DEBUG=false  # 一般使用（預設）
IS_DEBUG=true   # 開發調試
```

**📊 行數統計**

- `git-auto-push.sh`：2184 行 → 保持（功能優化與整合）

**🎯 使用場景**

- ✅ 自動關聯 commit 與 issue tracking 系統
- ✅ 保持 commit 訊息格式一致性
- ✅ 團隊協作時快速定位相關任務
- ✅ AI 工具問題診斷與提示詞優化

---

### 最新版本亮點 (v2.3.0)

- 2184 行 git-auto-push.sh - 傳統 Git 工作流程自動化，完整註解與流程說明
- 2896 行 git-auto-pr.sh - GitHub Flow PR 自動化，程式碼文件與流程註解
- 12 種操作模式 - 涵蓋 Git 和 PR 生命週期管理（7 種 push + 5 種 PR）
- **任務編號自動帶入** 🆕 - 從分支名稱自動偵測 issue key，支援自動/詢問模式
- **調試模式** 🆕 - AI 工具執行詳情追蹤，協助開發與問題診斷
- **Commit 品質檢查** - AI 驅動的訊息品質檢測，可配置自動檢查或詢問模式
- **Commit 訊息修改功能** - 安全修改最後一次 commit 訊息（選項 7）
- Git 倉庫資訊查看 - 一鍵瀏覽倉庫狀態
- 分支管理 - 安全刪除機制，主分支保護，多重確認
- 文件標準 - 所有主要流程函數都有註解
- 流程清晰化 - 每個工作流程都有詳細的步驟說明與參考資訊
- 可配置分支刪除策略 - 合併後可選擇保留或刪除分支

---

### v2.0.0 - 程式碼品質與分支管理提升 (2025-10-24)

**新功能**

- **可配置分支刪除策略** 🆕：PR 合併後分支處理策略
  - 預設值：`false`（保守策略，保留分支）
  - 可配置：`true`（自動刪除）或 `false`（保留分支）
  - 位置：`git-auto-pr.sh` 第 217 行
  - 影響範圍：「審查與合併 PR」功能（選項 4）

**🔧 改進**

- **分支管理流程**：根據配置自動選擇合併策略
  - `AUTO_DELETE_BRANCH_AFTER_MERGE=true`：使用 `gh pr merge --squash --delete-branch`
  - `AUTO_DELETE_BRANCH_AFTER_MERGE=false`：使用 `gh pr merge --squash`（保留分支）
- **提示訊息**：合併後顯示分支保留狀態與後續操作建議
- **配置說明**：詳細的註解說明配置用途、安全考量與修改範例

**📊 行數統計更新**

- `git-auto-pr.sh`：2872 行 → 2896 行（+24 行配置與邏輯）

**🎯 使用場景**

- **保留分支（預設）**：適合需要追蹤功能分支歷史的專案
- **自動刪除**：適合短期功能分支，保持倉庫整潔

**⚙️ 配置方式**

```bash
# 修改 git-auto-pr.sh 第 217 行
# 保留分支（預設）
readonly AUTO_DELETE_BRANCH_AFTER_MERGE=false

# 自動刪除分支
readonly AUTO_DELETE_BRANCH_AFTER_MERGE=true
```

---

### v1.6.0 - 流程註解完善與文件更新 (2025-10-24)

- **1655 行** git-auto-push.sh - 傳統 Git 工作流程自動化，完整註解與流程說明
- **2872 行** git-auto-pr.sh - GitHub Flow PR 自動化，程式碼文件與流程註解
- **11 種操作模式** - 涵蓋 Git 和 PR 生命週期管理（6 種 push + 5 種 PR）
- **Git 倉庫資訊查看** 🆕 - 一鍵瀏覽倉庫狀態
- **分支管理** - 安全刪除機制，主分支保護，多重確認
- **文件標準** ✨ - 所有主要流程函數都有完整的註解
- **流程清晰化** 🆕 - 每個工作流程都有詳細的步驟說明與參考資訊

---

### v1.6.0 - 流程註解完善與文件更新 (2025-10-24)

**🔧 改進**

- 流程函數註解更新：為所有主要工作流程函數添加註解
  - `execute_full_workflow()` - Git 流程（add → commit → push）
  - `execute_local_commit()` - 本地提交流程（add → commit）
  - `execute_add_only()` - 僅添加檔案流程
  - `execute_create_branch()` - 功能分支建立流程
  - `execute_create_pr()` - Pull Request 建立流程
- 註解標準化：統一函數註解格式，包含功能、參數、流程、副作用、參考
- 步驟編號優化：流程內步驟重新編號，更清晰反映實際執行順序
- 文件更新：README 更新最新行數統計與版本資訊

行數統計更新

- `git-auto-push.sh`：1655 行（+49 行流程註解）
- `git-auto-pr.sh`：2872 行（+43 行流程註解）

---

### v1.5.0 - Git 倉庫資訊查看功能 (2025-10-21)

新功能

- Git 倉庫資訊顯示：新增選項 6，提供完整的 Git 倉庫狀態概覽
  - 當前分支名稱和倉庫路徑
  - 所有遠端倉庫 URL（fetch 和 push）
  - 追蹤分支資訊和設定狀態
  - 同步狀態分析（領先/落後提交數）
  - 分支來源追蹤（從哪個主分支分出）
  - 最近 5 筆 commit 歷史記錄
  - 工作區狀態檢查（未提交變更）

改進

- 選單擴展：從 5 選項擴展為 6 選項，新增倉庫資訊查看
- 分析功能：自動判斷分支來源和與主分支的關係
- 彩色輸出：使用顏色和 emoji 增強資訊可讀性
- 安全設計：純查詢操作，不會修改任何 Git 狀態

新增文檔

- `docs/git-info-feature.md` - Git 倉庫資訊功能詳細說明

行數統計更新

- `git-auto-push.sh`：1372 行（+78 行新功能）

---

### v1.4.1 - 分支管理系統與程式碼文件化 (2025-10-04)

**🆕 新功能**

- **分支刪除系統** 🆕：新增安全的分支刪除功能，支援本地和遠端分支清理
- **主分支保護機制**：絕對禁止刪除主分支，可設定 DEFAULT_MAIN_BRANCHES 變數
- **當前分支處理**：自動偵測當前分支，提供切換後刪除的安全流程
- **多重確認機制**：分級確認系統，防止誤刪重要分支
- **程式碼文件** ✨：為所有主要函數加入註解標準

**🔧 改進**

- 選單擴展：從 4 選項擴展為 5 選項，新增分支管理功能
- 安全設計：未合併分支需要額外確認，已合併分支可安全刪除
- 遠端同步：可選擇同時刪除對應的遠端分支
- 偵測機制：自動識別分支狀態和合併情況
- **程式碼品質提升**：
  - 統一函數註解格式（功能、參數、返回值、使用範例）
  - 檔案標頭文件（版本、作者、使用指南、系統需求）
  - 詳細的安全機制和錯誤處理說明
  - 程式碼標準實施

**📊 行數統計更新**

- `git-auto-push.sh`：1294 行（+54 行註解）
- `git-auto-pr.sh`：2263 行（+163 行註解）

### v1.3.0 - PR 撤銷功能與選單重構 (2025-09-15)

**🆕 新功能**

- **PR 撤銷系統**：新增 PR 撤銷功能，支援開放中 PR 關閉和已合併 PR 的 revert
- **安全檢查機制**：顯示合併後影響的 commit 數量，revert 操作預設為否
- **選單結構優化**：將 PR 管理子選項提升為主選項，操作更直觀

**🔧 改進**

- 選單重構：從 3 選項擴展為 4 選項，移除子選單層級
- 分析功能：檢測 PR 狀態並提供對應操作選項（關閉/revert）
- 安全設計：所有破壞性操作都需要用戶明確確認

**📁 新增文檔**

- `docs/pr-cancel-feature.md` - PR 撤銷功能詳細說明

**📊 行數統計更新**

- `git-auto-pr.sh`：1876 行（+426 行）

### v1.2.0 - 分支配置系統 (2025-09-14)

新功能

- 分支配置：git-auto-pr.sh 新增 `DEFAULT_MAIN_BRANCHES` 陣列配置
- 自動偵測機制：按優先順序自動偵測第一個存在的主分支
- 錯誤處理優化：找不到分支時提供詳細解決建議和動態修復指令

改進

- 配置集中化：所有分支相關設定移至檔案頂部
- 錯誤訊息彩色化：使用表情符號和顏色提升可讀性
- 動態建議生成：根據配置陣列自動產生對應的 Git 指令

設定位置

- `git-auto-pr.sh` 第 78 行：`readonly -a DEFAULT_MAIN_BRANCHES=("main" "master")`

### v1.1.0 - AI 配置整合 (2025-09-13)

重構

- AI 提示詞提取至檔案頂部作為配置變數
- 統一 AI_TOOLS 變數，便於維護
- 新增 README 開發修改指導說明

### 參考資源

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
````
