# 使用指南与場景

本文件詳細說明 `git-auto-push.sh` 和 `git-auto-pr.sh` 的使用方法、操作模式以及常見的使用情境。

## 快速導航

- [使用指南与場景](#使用指南与場景)
  - [快速導航](#快速導航)
  - [git-auto-push.sh - 傳統 Git 自動化](#git-auto-pushsh---傳統-git-自動化)
    - [基本指令](#基本指令)
    - [git-auto-push.sh 操作模式](#git-auto-pushsh-操作模式)
    - [git-auto-push.sh 使用情境](#git-auto-pushsh-使用情境)
      - [情境 1：日常開發流程（含前綴選擇）🆕](#情境-1日常開發流程含前綴選擇)
      - [情境 2：快速自動提交](#情境-2快速自動提交)
      - [情境 3：修改最後一次 commit 訊息](#情境-3修改最後一次-commit-訊息)
      - [Conventional Commits 前綴支援 🆕](#conventional-commits-前綴支援-)
      - [智慧品質檢查 🆕](#智慧品質檢查-)
  - [git-auto-pr.sh - GitHub Flow PR 自動化](#git-auto-prsh---github-flow-pr-自動化)
    - [基本指令](#基本指令-1)
    - [git-auto-pr.sh 操作模式](#git-auto-prsh-操作模式)
    - [git-auto-pr.sh 使用情境](#git-auto-prsh-使用情境)
      - [情境 1：開始新功能開發](#情境-1開始新功能開發)
      - [情境 2：開發完成建立 PR](#情境-2開發完成建立-pr)
      - [情境 3：專案擁有者審查 PR](#情境-3專案擁有者審查-pr)
      - [GitHub Flow 工作流程特色](#github-flow-工作流程特色)

---

## git-auto-push.sh - 傳統 Git 自動化

此腳本專注於簡化日常的 Git 操作（add, commit, push）。

### 基本指令

```bash
# 互動式選單模式（推薦新手使用）
./git-auto-push.sh

# 全自動模式（跳過所有互動，直接使用 AI 生成並推送）
./git-auto-push.sh --auto
./git-auto-push.sh -a

# 命令列快速執行指定選項（熟手必備）
./git-auto-push.sh 1    # 完整流程 (add → commit → push)
./git-auto-push.sh 2    # 本地提交 (add → commit)
./git-auto-push.sh 3    # 僅添加檔案 (add)
./git-auto-push.sh 4    # 全自動模式 (add → AI commit → push)
./git-auto-push.sh 5    # 僅提交 (commit)
./git-auto-push.sh 6    # 顯示倉庫資訊
./git-auto-push.sh 7    # 變更最後一次 commit 訊息
```

> **提示**：如果是全域安裝，直接使用 `git-auto-push` 代替 `./git-auto-push.sh`。

### git-auto-push.sh 操作模式

1.  **完整流程 (Option 1)**
    -   流程：`git add` → 選擇 Conventional Commits 前綴 → 輸入 Commit 訊息 → `git push`
    -   適用：日常開發完成後的標準提交。

2.  **本機提交 (Option 2)**
    -   流程：`git add` → 選擇前綴 → 輸入 Commit 訊息
    -   適用：離線開發、頻繁提交但暫不推送、或需要 squash commits 時。

3.  **僅新增檔案 (Option 3)**
    -   流程：`git add .`
    -   適用：只想暫存變更，稍後再決定如何提交。

4.  **全自動模式 (Option 4)**
    -   流程：`git add` → AI 分析 Diff 自動選擇前綴 → AI 生成 Commit 訊息 → `git push`
    -   適用：CI/CD 環境、小修改快速提交、或懶得想 Commit 訊息時。

5.  **僅提交 (Option 5)**
    -   流程：`git commit`
    -   適用：已經手動 add 檔案，只想進行提交步驟。

6.  **顯示倉庫資訊 (Option 6)**
    -   流程：顯示分支狀態、遠端倉庫、同步狀態、最近 Commits。
    -   適用：快速檢查當前 Git 狀態，確認是否同步。

7.  **變更 commit 訊息 (Option 7)**
    -   流程：檢查工作區狀態 → 顯示原訊息 → 輸入新訊息/任務編號 → `git commit --amend`
    -   適用：打錯字、漏加 Issue 編號、想補充說明時（**僅限尚未 Push 的 Commit**）。

### git-auto-push.sh 使用情境

#### 情境 1：日常開發流程（含前綴選擇）🆕

這是最常用的模式。當你完成一個功能或修復一個 Bug 後：

```bash
./git-auto-push.sh 1
```

**操作流程**：
1.  系統執行 `git add .`
2.  顯示 Conventional Commits 前綴選單（feat, fix, docs...），選擇合適的類型。
3.  輸入 Commit 訊息（例如：新增使用者登入功能）。
4.  系統自動整合任務編號（若有設定）與前綴。
5.  **範例輸出**：`[issue-123] feat: 新增使用者登入功能`

#### 情境 2：快速自動提交

當你做了一些瑣碎的修改，不想花時間想 Commit 訊息：

```bash
./git-auto-push.sh --auto
```

AI 會分析你的程式碼變更，自動產生如 `[issue-123] feat: 新增使用者設定頁面` 的訊息並推送。

#### 情境 3：修改最後一次 commit 訊息

如果你發現剛提交的 Commit 訊息有誤，或者忘了加 Issue 編號：

```bash
./git-auto-push.sh 7
```

系統會引導你輸入新的訊息，並安全地使用 `--amend` 修改它。
**注意**：如果有未提交的變更（Uncommitted changes），系統會警告並阻止，以免不小心將這些變更混入上一個 Commit。

#### Conventional Commits 前綴支援 🆕

支援以下標準前綴：
-   `feat`: 新功能
-   `fix`: 錯誤修復
-   `docs`: 文件變更
-   `style`: 程式碼格式（不影響運行）
-   `refactor`: 重構（不改變功能）
-   `perf`: 效能改進
-   `test`: 測試相關
-   `build`: 建置系統
-   `ci`: CI 配置
-   `chore`: 雜項維護
-   `revert`: 回退提交

#### 智慧品質檢查 🆕
-   **自動模式**：每次 Commit 前，AI 會檢查你的訊息是否足夠清楚。
    -   ✅ 良好：「新增用戶登入功能，支援 OAuth 2.0 驗證」
    -   ❌ 不良：「fix bug」、「update」、「修改程式碼」
-   若檢查不通過，會給出建議，你可以選擇修改或強制提交。

---

## git-auto-pr.sh - GitHub Flow PR 自動化

此腳本專注於 GitHub Flow 工作流程（分支、PR、合併）。

### 基本指令

```bash
# 互動式選單模式
./git-auto-pr.sh
```

### git-auto-pr.sh 操作模式

1.  **建立功能分支 (Option 1)**
    -   輸入 Issue Key、擁有者、類型，自動生成標準化分支名稱。
    -   例如：`jerry/feature/proj-123-login-page`

2.  **建立 Pull Request (Option 2)**
    -   基於當前分支與主分支的差異，使用 AI 生成 PR 標題與內容，並呼叫 GitHub CLI 建立 PR。

3.  **撤銷目前 PR (Option 3)**
    -   若是開放中的 PR：關閉它。
    -   若是已合併的 PR：執行 Revert 操作（需確認）。

4.  **審查與合併 PR (Option 4)**
    -   列出待審查 PR，選擇後可進行批准、請求變更或直接合併。
    -   支援 Squash 合併並自動刪除遠端分支。

5.  **刪除分支 (Option 5)**
    -   列出可刪除的分支（已合併/未合併），提供安全刪除功能。

### git-auto-pr.sh 使用情境

#### 情境 1：開始新功能開發

```bash
./git-auto-pr.sh  # 選擇選項 1
```

1.  輸入 Issue Key：`PROJ-123`
2.  輸入擁有者名字：`tom`
3.  選擇分支類型：`feature`
4.  **結果**：建立並切換到 `tom/feature/proj-123` 分支。

#### 情境 2：開發完成建立 PR

```bash
./git-auto-pr.sh  # 選擇選項 2
```

AI 會讀取你的 Commits，自動生成一份包含標題、摘要、變更清單的 PR 內容。

#### 情境 3：專案擁有者審查 PR

```bash
./git-auto-pr.sh  # 選擇選項 4
```

1.  系統列出所有 Open PR。
2.  選擇一個 PR 查看詳情。
3.  選擇「批准並合併」。
4.  系統執行 Squash Merge，刪除遠端分支，並更新本地主分支。

#### GitHub Flow 工作流程特色

-   **分支命名規範**：`{username}/{type}/{issue-key}`
-   **AI 輔助內容**：Commit Message、PR Title、PR Body 均可由 AI 生成。
-   **安全性**：防止自我批准 PR，Revert 操作有多重確認。
-   **自動分支管理**：自動偵測主分支（main/master/uat），合併後自動清理分支。
