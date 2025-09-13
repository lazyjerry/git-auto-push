# Git 工作流程自動化工具集

完整的 Git 工作流程自動化解決方案，包含傳統 Git 操作自動化和現代 GitHub Flow PR 流程。整合 AI 驅動的智慧生成功能和企業級錯誤處理機制。

## 專案簡介

一句話價值主張：**讓 Git 工作流程變得像按一個按鈕一樣簡單**

主要功能亮點：

- 傳統 Git 工作流程完全自動化（添加、提交、推送）
- GitHub Flow PR 流程端到端自動化（分支建立到 PR 建立）
- AI 驅動的智慧內容生成（commit 訊息、分支名稱、PR 內容）
- 企業級錯誤處理與智慧修復建議
- 多 AI 工具整合與自動容錯機制
- 中斷恢復和信號處理機制

## 系統結構

### 核心組件架構

```
├── git-auto-push.sh      # 傳統 Git 工作流程自動化（1045 行）
├── git-auto-pr.sh        # GitHub Flow PR 流程自動化（1335 行）
├── AI 工具整合模組        # 支援 codex、gemini、claude
│   ├── 智慧錯誤檢測      # 認證過期、網路錯誤自動識別
│   ├── 友善錯誤提示      # 提供具體解決方案
│   ├── 多工具容錯機制    # AI 工具失效時的備援機制
│   └── 輸出清理系統      # 過濾 AI 工具元數據和技術雜訊
├── 互動式選單系統        # 直覺的操作選項與使用者體驗
├── Loading 動畫系統      # 美觀的等待提示與進度顯示
├── 信號處理機制          # 多層級 trap cleanup 與中斷恢復
└── 錯誤處理系統          # 完整的異常處理與修復引導
```

### 專案結構

```
├── git-auto-push.sh      # 傳統 Git 自動化工具
├── git-auto-pr.sh        # GitHub Flow PR 自動化工具
├── LICENSE              # MIT 授權條款
├── README.md            # 專案說明文件
├── .github/             # GitHub 相關配置
│   ├── copilot-instructions.md    # AI 代理開發指導
│   └── instructions/              # 代碼生成規範
│       └── copilot-readme.instructions.md
├── docs/                # 文件目錄
│   └── github-flow.md   # GitHub Flow 流程說明
└── screenshots/         # 介面展示圖片
    ├── ai-commit-generation.png
    ├── auto-mode.png
    └── main-menu.png
```

## 安裝與啟動

### 1. 複製專案

```bash
git clone https://github.com/lazyjerry/git-auto-push.git
cd git-auto-push
```

### 2. 設置執行權限

```bash
chmod +x git-auto-push.sh
chmod +x git-auto-pr.sh
```

### 3. 全域安裝（選擇性）

```bash
# 安裝兩個工具到系統路徑
sudo cp git-auto-push.sh /usr/local/bin/git-auto-push
sudo cp git-auto-pr.sh /usr/local/bin/git-auto-pr
sudo chmod +x /usr/local/bin/git-auto-push
sudo chmod +x /usr/local/bin/git-auto-pr
```

### 4. 依賴工具安裝

#### GitHub CLI（git-auto-pr.sh 必需）

```bash
# macOS
brew install gh
gh auth login  # 選擇 GitHub.com → HTTPS → Browser 登入
```

#### AI CLI 工具（可選，推薦）

安裝任一或多個 AI CLI 工具以啟用智慧生成功能：

- `codex` - GitHub Copilot CLI
- `gemini` - Google Gemini CLI
- `claude` - Anthropic Claude CLI

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

| 模式          | 功能描述                     | 使用情境           |
| ------------- | ---------------------------- | ------------------ |
| 1. 完整流程   | add → 互動輸入 commit → push | 日常開發提交       |
| 2. 本地提交   | add → 互動輸入 commit        | 離線開發或測試提交 |
| 3. 僅添加檔案 | add                          | 暫存檔案變更       |
| 4. 全自動模式 | add → AI 生成 commit → push  | CI/CD 或快速提交   |
| 5. 僅提交     | commit                       | 提交已暫存的檔案   |

### git-auto-pr.sh - GitHub Flow PR 自動化 ✨

```bash
# 互動式模式（預設）
./git-auto-pr.sh

# 全自動模式
./git-auto-pr.sh --auto
./git-auto-pr.sh -a

# 全域安裝後使用
git-auto-pr
git-auto-pr --auto
```

#### git-auto-pr.sh 操作模式

| 模式             | 功能描述                             | 使用情境               |
| ---------------- | ------------------------------------ | ---------------------- |
| 1. 建立功能分支  | 基於 main 建立 feature 分支          | 開始新功能開發         |
| 2. 提交並推送    | add → commit → push                  | 功能開發完成後提交     |
| 3. 建立 PR       | 基於當前分支建立 Pull Request        | 提交代碼審查           |
| 4. 完整 PR 流程  | 建立分支 → 開發提示 → 提交 → 建立 PR | 新功能開發完整流程     |
| 5. 全自動 PR     | 自動提交 → 自動建立 PR               | 快速提交並建立審查流程 |
| 6. 審查與合併 PR | 審查 → 批准/請求變更 → 合併 → 更新   | 專案擁有者 PR 管理     |

#### GitHub Flow 工作流程特色

- **Issue 整合**: 支援 JIRA、GitHub Issue 等多種編號格式
- **AI 智慧生成**: 分支名稱、commit message、PR 標題和內容均可 AI 輔助
- **完整驗證**: 檢查 Git 倉庫、gh CLI 登入狀態、分支狀態
- **企業級錯誤處理**: 智慧錯誤檢測與友善修復建議
- **中斷恢復**: 支援 Ctrl+C 中斷與優雅清理
- **多分支支援**: 自動檢測 main/master 主分支

## 使用情境

### git-auto-push.sh 使用情境

#### 日常開發流程

```bash
# 修改程式碼後，執行完整流程
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
# 先添加檔案
./git-auto-push.sh  # 選擇選項 3

# 稍後提交
./git-auto-push.sh  # 選擇選項 5
```

### git-auto-pr.sh 使用情境 ✨

#### 完整 GitHub Flow 開發流程

```bash
# 1. 開始新功能開發
./git-auto-pr.sh
# 選擇選項 1，輸入 JIRA-123 和功能描述，AI 生成分支名稱

# 2. 開發完成後提交並建立 PR
./git-auto-pr.sh
# 選擇選項 1 繼續，或直接選項 3→4
```

#### 快速 PR 建立

```bash
# 在功能分支上快速建立 PR
./git-auto-pr.sh --auto
```

#### 分步驟操作

```bash
# 1. 建立功能分支
./git-auto-pr.sh  # 選擇選項 2
# 輸入 JIRA-123，開發完成後...

# 2. 提交變更
./git-auto-pr.sh  # 選擇選項 3
# AI 生成 commit message

# 3. 建立 PR
./git-auto-pr.sh  # 選擇選項 4
# AI 生成 PR 標題和內容
```

#### 團隊協作場景

```bash
# 開發者：基於 main 分支開始新功能
git checkout main && git pull
./git-auto-pr.sh  # 建立 feature/JIRA-123-new-feature

# 開發者：開發中途提交進度
./git-auto-pr.sh  # 選擇選項 2，持續提交

# 開發者：功能完成，建立 PR 供審查
./git-auto-pr.sh  # 選擇選項 3，建立 PR

# 專案擁有者：審查並合併 PR
./git-auto-pr.sh  # 選擇選項 6，審查 → 批准 → 合併
```

#### 專案擁有者 PR 管理

```bash
# 查看和審查待處理的 PR
./git-auto-pr.sh  # 選擇選項 6

# 系統會自動：
# 1. 列出所有待審查的 PR
# 2. 顯示選定 PR 的詳細資訊和 CI 狀態
# 3. 提供審查選項：批准並合併、添加評論、請求變更
# 4. 自動使用 squash 合併並刪除功能分支
# 5. 更新本地 main 分支
```

## 特色功能

### AI 智慧生成系統

**多 AI 工具整合**

- 支援 codex、gemini、claude 三種 AI CLI 工具
- 自動容錯機制：當一個 AI 工具失效時自動嘗試下一個
- 智慧輸出清理：過濾 AI 工具的元數據和技術雜訊

**智慧內容生成**

- commit 訊息：分析 git diff 自動生成符合 Conventional Commits 規範的訊息
- 分支名稱：根據 issue 編號和功能描述生成 GitHub Flow 標準分支名
- PR 內容：基於分支變更歷史生成專業的 PR 標題和描述

### 企業級錯誤處理

**智慧錯誤檢測與修復**

- 自動檢測 `401 Unauthorized` 和 `token_expired` 認證錯誤
- 檢測 `stream error`、網路超時等連接問題
- 提供具體的修復命令和操作步驟

**用戶體驗優化**

- 彩色格式化的錯誤訊息與成功提示
- Loading 動畫顯示操作進度和等待時間
- 即時停止無效重試，避免浪費時間
- 中斷恢復機制：支援 Ctrl+C 優雅退出

### 工作流程自動化

**傳統 Git 流程（git-auto-push.sh）**

- 5 種操作模式滿足不同開發場景
- 支援離線開發和 CI/CD 整合
- 分階段操作支援：添加 → 提交 → 推送

**GitHub Flow 流程（git-auto-pr.sh）**

- 端到端 PR 流程自動化
- 主分支自動檢測（main/master）
- 分支狀態智慧驗證

## 錯誤排除

### 常見問題及解決方案

**錯誤：`當前目錄不是 Git 倉庫！`**

```bash
# 確認在 Git 倉庫根目錄執行
git init  # 或移動到正確的 Git 倉庫目錄
```

**錯誤：`沒有需要提交的變更`**

- 檢查是否有檔案變更：`git status`
- 或選擇推送現有提交到遠端

**AI 工具認證錯誤**

```bash
❌ codex 認證錯誤: 認證令牌已過期
💡 請執行以下命令重新登入 codex:
   codex auth login
```

當出現 `401 Unauthorized` 或 `token_expired` 錯誤時，按提示重新認證。

**GitHub CLI 相關錯誤（git-auto-pr.sh）**

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

**主分支自動檢測**

工具智慧檢測主分支名稱：

- 優先檢測遠端 `origin/main` 分支
- 備選檢測 `origin/master` 分支
- 本地分支作為最後選項
- 同時支援現代倉庫（main）和傳統倉庫（master）

**AI 工具網路錯誤**

```bash
❌ codex 網路錯誤: stream error: unexpected status
💡 請檢查網路連接或稍後重試
```

網路問題會自動檢測並提供具體建議。

**AI 工具無法使用**

```bash
# 檢查 AI CLI 工具是否已安裝並可執行
which codex
which gemini
which claude
```

**權限不足錯誤**

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

本工具集完整支援 [GitHub Flow](docs/github-flow.md) 企業級工作流程：

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

### CI/CD 整合支援

兩個工具均支援 `--auto` 無互動模式，適合自動化環境：

**GitHub Actions 範例**

```yaml
name: Auto Git Workflow
on: [push]

jobs:
  auto-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Auto commit changes
        run: ./git-auto-push --auto

  auto-pr:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Auto create PR
        run: ./git-auto-pr --auto
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Docker 容器整合**

```dockerfile
# 在容器中使用工具
COPY git-auto-*.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/git-auto-*
CMD ["git-auto-push", "--auto"]
```

## 授權條款

本專案採用 MIT License 授權條款。詳細內容請參閱 [LICENSE](LICENSE) 檔案。
