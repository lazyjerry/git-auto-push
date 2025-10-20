# Git 指令功能與情境操作指南

## 📚 目錄

- [Git 核心指令功能說明](#git-核心指令功能說明)
- [情境操作指南](#情境操作指南)
- [進階技巧與最佳實踐](#進階技巧與最佳實踐)

---

## Git 核心指令功能說明

### 1. 倉庫初始化與配置

```bash
# 初始化新倉庫
git init                              # 在當前目錄創建 Git 倉庫

# 克隆遠端倉庫
git clone <url>                       # 克隆完整倉庫
git clone --depth 1 <url>             # 淺克隆（只下載最新版本）

# 配置用戶資訊
git config --global user.name "名字"   # 設定全域使用者名稱
git config --global user.email "email" # 設定全域 email
git config --list                      # 查看所有配置
```

### 2. 基本工作流程

```bash
# 查看狀態
git status                            # 查看工作區狀態（詳細）
git status -s                         # 簡潔狀態顯示
git status --porcelain                # 機器可讀格式（腳本用）

# 添加變更到暫存區
git add <file>                        # 添加特定檔案
git add .                             # 添加所有變更
git add -p                            # 互動式添加（部分變更）
git add -u                            # 只添加已追蹤的檔案

# 提交變更
git commit -m "訊息"                  # 提交並附上訊息
git commit -am "訊息"                 # 添加並提交（已追蹤檔案）
git commit --amend                    # 修改最後一次提交
git commit --amend --no-edit          # 修改最後提交但保持訊息不變

# 查看變更
git diff                              # 工作區 vs 暫存區
git diff --cached                     # 暫存區 vs 最後提交
git diff HEAD                         # 工作區 vs 最後提交
git diff <branch1>..<branch2>         # 比較兩個分支
```

### 3. 分支管理

```bash
# 查看分支
git branch                            # 列出本地分支
git branch -r                         # 列出遠端分支
git branch -a                         # 列出所有分支
git branch -v                         # 顯示分支和最後提交

# 創建與切換分支
git branch <branch>                   # 創建分支
git checkout <branch>                 # 切換分支
git checkout -b <branch>              # 創建並切換分支
git switch <branch>                   # 切換分支（新語法）
git switch -c <branch>                # 創建並切換（新語法）

# 刪除分支
git branch -d <branch>                # 刪除已合併分支（安全）
git branch -D <branch>                # 強制刪除分支
git push origin --delete <branch>     # 刪除遠端分支

# 重命名分支
git branch -m <old> <new>             # 重命名分支
git branch -M <new>                   # 重命名當前分支
```

### 4. 遠端操作

```bash
# 遠端倉庫管理
git remote                            # 列出遠端倉庫
git remote -v                         # 顯示遠端 URL
git remote add <name> <url>           # 添加遠端倉庫
git remote remove <name>              # 移除遠端倉庫
git remote rename <old> <new>         # 重命名遠端

# 推送（Push）
git push                              # 推送到預設遠端
git push origin <branch>              # 推送到指定分支
git push -u origin <branch>           # 推送並設定上游
git push --force                      # 強制推送（危險！）
git push --force-with-lease           # 較安全的強制推送

# 拉取（Pull/Fetch）
git fetch                             # 獲取遠端更新（不合併）
git fetch origin                      # 從指定遠端獲取
git pull                              # 獲取並合併
git pull --rebase                     # 獲取並 rebase
git pull --ff-only                    # 只允許快轉合併
```

### 5. 合併與 Rebase

```bash
# 合併（Merge）
git merge <branch>                    # 合併指定分支
git merge --no-ff <branch>            # 禁用快轉合併
git merge --squash <branch>           # 壓縮合併（不創建合併提交）
git merge --abort                     # 取消合併

# Rebase
git rebase <branch>                   # 將當前分支 rebase 到指定分支
git rebase -i HEAD~3                  # 互動式 rebase 最近 3 個提交
git rebase --continue                 # 解決衝突後繼續
git rebase --abort                    # 取消 rebase
```

### 6. 歷史記錄查詢

```bash
# 查看提交歷史
git log                               # 查看提交歷史
git log --oneline                     # 單行顯示
git log --graph                       # 圖形化顯示
git log --all --decorate --oneline --graph  # 完整視覺化
git log -p                            # 顯示每次提交的差異
git log --since="2 weeks ago"         # 時間範圍
git log --author="名字"               # 特定作者

# 查看特定提交
git show <commit>                     # 查看提交詳情
git show <commit>:<file>              # 查看特定提交的檔案

# 檔案歷史
git log -- <file>                     # 查看檔案的提交歷史
git blame <file>                      # 查看每行的最後修改者
```

### 7. 撤銷與重置

```bash
# 撤銷工作區變更
git checkout -- <file>                # 撤銷檔案變更（舊語法）
git restore <file>                    # 撤銷檔案變更（新語法）

# 撤銷暫存區
git reset HEAD <file>                 # 取消暫存（舊語法）
git restore --staged <file>           # 取消暫存（新語法）

# 重置提交
git reset --soft HEAD~1               # 撤銷提交，保留變更在暫存區
git reset --mixed HEAD~1              # 撤銷提交，保留變更在工作區（預設）
git reset --hard HEAD~1               # 撤銷提交，丟棄所有變更（危險！）

# Revert（安全的撤銷）
git revert <commit>                   # 創建新提交來撤銷指定提交
git revert HEAD                       # 撤銷最後一次提交
git revert --no-commit <commit>       # 撤銷但不自動提交
```

### 8. 暫存（Stash）

```bash
# 暫存變更
git stash                             # 暫存當前變更
git stash save "描述"                 # 暫存並添加描述
git stash -u                          # 包含未追蹤的檔案

# 查看與恢復
git stash list                        # 列出所有暫存
git stash show                        # 顯示最新暫存的變更
git stash show -p                     # 顯示詳細差異
git stash apply                       # 應用最新暫存（保留）
git stash pop                         # 應用並刪除最新暫存
git stash drop                        # 刪除最新暫存
git stash clear                       # 清除所有暫存
```

### 9. 標籤（Tag）

```bash
# 創建標籤
git tag <tagname>                     # 輕量標籤
git tag -a <tagname> -m "訊息"        # 附註標籤

# 查看標籤
git tag                               # 列出所有標籤
git show <tagname>                    # 顯示標籤詳情

# 推送標籤
git push origin <tagname>             # 推送特定標籤
git push origin --tags                # 推送所有標籤

# 刪除標籤
git tag -d <tagname>                  # 刪除本地標籤
git push origin --delete <tagname>    # 刪除遠端標籤
```

### 10. GitHub CLI (gh) 常用指令

```bash
# 認證
gh auth login                         # 登入 GitHub
gh auth status                        # 查看認證狀態

# Pull Request
gh pr create                          # 創建 PR
gh pr create --fill                   # 自動填充標題和內容
gh pr list                            # 列出 PR
gh pr view <number>                   # 查看 PR 詳情
gh pr checkout <number>               # 切換到 PR 分支
gh pr merge <number> --squash         # Squash 合併 PR
gh pr close <number>                  # 關閉 PR

# Repository
gh repo view                          # 查看倉庫資訊
gh repo view --web                    # 在瀏覽器打開倉庫
gh repo clone <repo>                  # 克隆倉庫

# Issues
gh issue create                       # 創建 Issue
gh issue list                         # 列出 Issues
gh issue view <number>                # 查看 Issue 詳情
```

---

## 情境操作指南

### 情境 1：開始新專案

```bash
# 本地創建專案並推送到 GitHub
mkdir my-project
cd my-project
git init
echo "# My Project" > README.md
git add README.md
git commit -m "Initial commit"

# 在 GitHub 創建倉庫後
git remote add origin https://github.com/username/my-project.git
git branch -M main
git push -u origin main
```

### 情境 2：日常開發流程

```bash
# 1. 確保在最新版本
git checkout main
git pull --ff-only origin main

# 2. 創建功能分支
git checkout -b feature/new-feature

# 3. 開發並提交
# ... 修改檔案 ...
git add .
git status                            # 檢查變更
git commit -m "feat: add new feature"

# 4. 推送到遠端
git push -u origin feature/new-feature

# 5. 創建 PR
gh pr create --fill
```

### 情境 3：修復 Bug（Hotfix）

```bash
# 1. 從主分支創建 hotfix 分支
git checkout main
git pull --ff-only origin main
git checkout -b hotfix/fix-critical-bug

# 2. 修復並測試
# ... 修改檔案 ...
git add .
git commit -m "fix: resolve critical bug in production"

# 3. 快速合併回 main
git checkout main
git merge hotfix/fix-critical-bug
git push origin main

# 4. 標記版本
git tag -a v1.0.1 -m "Hotfix: critical bug fix"
git push origin v1.0.1

# 5. 刪除 hotfix 分支
git branch -d hotfix/fix-critical-bug
git push origin --delete hotfix/fix-critical-bug
```

### 情境 4：處理合併衝突

```bash
# 1. 嘗試合併時發生衝突
git merge feature-branch
# Auto-merging file.txt
# CONFLICT (content): Merge conflict in file.txt

# 2. 查看衝突檔案
git status                            # 列出有衝突的檔案

# 3. 手動解決衝突
# 編輯有 <<<<<<<, =======, >>>>>>> 標記的檔案
# 決定保留哪些變更

# 4. 標記為已解決
git add <conflicted-file>

# 5. 完成合併
git commit                            # 使用預設合併訊息
# 或
git merge --continue

# 如果想放棄合併
git merge --abort
```

### 情境 5：撤銷錯誤的提交

```bash
# 情況 A：尚未推送，撤銷最後一次提交
git reset --soft HEAD~1               # 保留變更在暫存區
# 或
git reset --mixed HEAD~1              # 保留變更在工作區
# 或
git reset --hard HEAD~1               # 完全丟棄變更（危險！）

# 情況 B：已經推送，需要創建新提交來撤銷
git revert HEAD                       # 撤銷最後一次提交
git push origin main

# 情況 C：想修改最後一次提交的訊息
git commit --amend -m "修正後的訊息"
git push --force-with-lease           # 如果已推送
```

### 情境 6：同步 Fork 的倉庫

```bash
# 1. 添加上游倉庫（只需做一次）
git remote add upstream https://github.com/original/repo.git
git remote -v                         # 確認遠端設定

# 2. 獲取上游更新
git fetch upstream

# 3. 合併到本地主分支
git checkout main
git merge upstream/main

# 4. 推送到自己的 Fork
git push origin main
```

### 情境 7：功能分支的 Rebase 工作流程

```bash
# 1. 在功能分支上工作
git checkout feature-branch

# 2. 定期更新主分支變更
git fetch origin
git rebase origin/main

# 3. 如果有衝突，逐個解決
# ... 解決衝突 ...
git add <resolved-file>
git rebase --continue

# 4. 強制推送（因為歷史改變了）
git push --force-with-lease origin feature-branch

# 5. 功能完成後，squash 提交
git rebase -i HEAD~5                  # 互動式 rebase 最近 5 個提交
# 在編輯器中，將除第一個外的 pick 改為 squash 或 fixup
```

### 情境 8：暫存當前工作切換任務

```bash
# 1. 正在開發時需要緊急處理其他任務
git stash save "WIP: working on feature X"

# 2. 切換到其他分支處理緊急任務
git checkout main
git checkout -b hotfix/urgent-fix
# ... 處理緊急任務 ...
git add .
git commit -m "fix: urgent fix"
git push origin hotfix/urgent-fix

# 3. 回到原本的工作
git checkout feature-branch
git stash list                        # 查看暫存列表
git stash pop                         # 恢復最新暫存

# 如果有衝突
# ... 解決衝突 ...
git add <resolved-file>
git stash drop                        # 手動刪除暫存
```

### 情境 9：清理本地分支

```bash
# 1. 查看已合併的分支
git branch --merged main              # 列出已合併到 main 的分支

# 2. 刪除已合併的本地分支
git branch -d feature-branch-1
git branch -d feature-branch-2

# 3. 批次刪除已合併分支（小心使用）
git branch --merged main | grep -v "\* main" | xargs -n 1 git branch -d

# 4. 清理遠端已刪除的分支參考
git fetch --prune                     # 或 git fetch -p

# 5. 刪除所有本地不在遠端的分支
git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -D
```

### 情境 10：檢查與修復問題

```bash
# 1. 找出引入 Bug 的提交（二分搜尋）
git bisect start
git bisect bad                        # 當前版本有 bug
git bisect good <commit>              # 已知正常的提交
# Git 會自動切換到中間版本
# 測試後標記
git bisect good                       # 或 git bisect bad
# 重複直到找到問題提交
git bisect reset                      # 結束並回到原分支

# 2. 查看檔案的修改歷史
git log -p -- path/to/file            # 顯示檔案的所有變更
git log --follow -- path/to/file      # 追蹤重命名

# 3. 找出特定程式碼的作者
git blame path/to/file                # 顯示每行最後修改者
git blame -L 10,20 path/to/file       # 只看 10-20 行

# 4. 恢復已刪除的檔案
git log --diff-filter=D --summary     # 找出刪除檔案的提交
git checkout <commit>~1 -- path/to/file  # 恢復檔案
```

### 情境 11：多人協作衝突預防

```bash
# 1. 開始工作前先更新
git checkout main
git pull --rebase origin main         # 使用 rebase 保持線性歷史

# 2. 創建功能分支
git checkout -b feature/my-feature

# 3. 定期同步主分支變更（每天或每次提交前）
git fetch origin
git rebase origin/main                # 將你的提交放在最新變更之上

# 4. 提交前檢查
git fetch origin
git log origin/main..HEAD             # 查看即將推送的提交
git diff origin/main..HEAD            # 查看所有變更

# 5. 推送前最後確認
git pull --rebase origin main         # 最後一次同步
git push -u origin feature/my-feature
```

### 情境 12：傳統 Git 操作 vs 自動化工具比較

本節展示如何使用純 Git 指令完成常見任務，以及如何使用本專案工具簡化這些操作。

---

#### 情境 A：快速日常提交（完整流程）

**使用傳統 Git 指令：**

```bash
# 1. 檢查當前狀態
git status

# 2. 查看變更內容
git diff

# 3. 添加所有變更
git add .

# 4. 再次確認暫存區
git status

# 5. 撰寫並提交 commit 訊息
git commit -m "feat: add user authentication feature"

# 6. 獲取當前分支名稱
BRANCH=$(git branch --show-current)

# 7. 推送到遠端
git push origin $BRANCH
```

**使用 git-auto-push.sh（簡化版）：**

```bash
# 一鍵完成所有步驟
./git-auto-push.sh

# 選擇選項 1（完整流程）
# - 自動檢查變更並添加
# - 可手動輸入或讓 AI 生成 commit 訊息
# - 確認後自動推送
```

---

#### 情境 B：離線開發（只提交不推送）

**使用傳統 Git 指令：**

```bash
# 1. 添加變更
git add .

# 2. 查看即將提交的內容
git diff --cached

# 3. 提交到本地
git commit -m "feat: implement offline sync logic"

# 稍後有網路時再推送
git push origin $(git branch --show-current)
```

**使用 git-auto-push.sh（簡化版）：**

```bash
./git-auto-push.sh

# 選擇選項 2（本地提交）
# - 自動 add 並提交
# - 不執行 push 操作
# - 保留變更在本地倉庫
```

---

#### 情境 C：查看 Git 倉庫詳細資訊

**使用傳統 Git 指令：**

```bash
# 1. 查看當前分支
git branch --show-current

# 2. 查看倉庫路徑
git rev-parse --show-toplevel

# 3. 查看遠端倉庫
git remote -v

# 4. 查看追蹤分支
git rev-parse --abbrev-ref --symbolic-full-name @{u}

# 5. 檢查同步狀態
git rev-list --count @{u}..HEAD    # 領先提交數
git rev-list --count HEAD..@{u}    # 落後提交數

# 6. 查看分支來源
git merge-base $(git branch --show-current) main

# 7. 查看最近提交
git log --oneline -5 --decorate --color=always

# 8. 查看工作區狀態
git status --short
```

**使用 git-auto-push.sh（簡化版）：**

```bash
./git-auto-push.sh

# 選擇選項 6（顯示倉庫資訊）
# 自動顯示：
# - 當前分支和路徑
# - 所有遠端倉庫 URL
# - 追蹤分支資訊
# - 同步狀態（領先/落後）
# - 分支來源分析
# - 最近 5 筆 commit
# - 工作區狀態
```

---

#### 情境 D：CI/CD 全自動提交

**使用傳統 Git 指令（需要額外腳本）：**

```bash
# 需要自己撰寫腳本來：
# 1. 檢查是否有變更
if [ -n "$(git status --porcelain)" ]; then
    # 2. 添加所有變更
    git add .

    # 3. 生成 commit 訊息（需要整合 AI 工具）
    # 這部分需要額外呼叫 AI CLI 工具
    # 並處理輸出、錯誤、超時等問題

    # 4. 提交
    git commit -m "$COMMIT_MSG"

    # 5. 推送
    git push origin $(git branch --show-current)
fi
```

**使用 git-auto-push.sh（簡化版）：**

```bash
# 一行指令完成所有操作
./git-auto-push.sh --auto

# 自動執行：
# - 檢查變更
# - 自動 add
# - AI 生成 commit 訊息（多工具鏈容錯）
# - 自動提交
# - 自動推送
# 無需任何人工介入
```

---

#### 情境 E：開始新功能開發（GitHub Flow）

**使用傳統 Git 指令：**

```bash
# 1. 確保在最新的 main 分支
git checkout main
git pull --ff-only origin main

# 2. 手動構思分支名稱（需符合規範）
# 格式：feature/<issue-id>-<description>
BRANCH_NAME="feature/JIRA-123-user-authentication"

# 3. 創建並切換分支
git checkout -b $BRANCH_NAME

# 4. 推送到遠端並設定追蹤
git push -u origin $BRANCH_NAME
```

**使用 git-auto-pr.sh（簡化版）：**

```bash
./git-auto-pr.sh

# 選擇選項 1（建立功能分支）
# 輸入：JIRA-123
# 輸入：簡短功能描述
# AI 自動生成：feature/JIRA-123-user-authentication
# 自動驗證分支名稱格式
# 自動創建並推送分支
```

---

#### 情境 F：功能完成，創建 Pull Request

**使用傳統 Git 指令：**

```bash
# 1. 確保所有變更已提交
git add .
git commit -m "feat(auth): complete user authentication"

# 2. 推送到遠端
git push origin $(git branch --show-current)

# 3. 收集 PR 所需資訊
ISSUE_KEY="JIRA-123"
BRANCH=$(git branch --show-current)

# 4. 查看 commit 歷史（準備 PR 描述）
git log main..HEAD --oneline

# 5. 查看檔案變更（準備 PR 描述）
git diff main..HEAD --stat

# 6. 手動撰寫 PR 標題和內容
# 7. 使用 gh CLI 創建 PR
gh pr create \
  --base main \
  --head $BRANCH \
  --title "[$ISSUE_KEY] 實作使用者認證功能" \
  --body "## 功能說明
  實作 JWT 認證系統...

  ## 變更內容
  - 新增登入 API
  - 新增 token 驗證

  ## 測試
  - 單元測試通過
  - 整合測試通過"
```

**使用 git-auto-pr.sh（簡化版）：**

```bash
./git-auto-pr.sh

# 選擇選項 2（建立 PR）
# AI 自動分析：
# - 自動抓取 issue key
# - 分析分支名稱
# - 分析 commit 歷史
# - 分析檔案變更
# AI 自動生成：
# - PR 標題（簡潔專業）
# - PR 內容（包含功能說明和技術細節）
# 自動創建 PR
```

---

#### 情境 G：撤銷錯誤的 Pull Request

**使用傳統 Git 指令（開放中的 PR）：**

```bash
# 1. 查詢當前分支的 PR 編號
gh pr list --head $(git branch --show-current)

# 2. 查看 PR 詳細資訊
gh pr view <PR_NUMBER>

# 3. 關閉 PR
gh pr close <PR_NUMBER>

# 4. 可選：刪除遠端分支
git push origin --delete $(git branch --show-current)
```

**使用傳統 Git 指令（已合併的 PR）：**

```bash
# 1. 找到 PR 合併的 commit
gh pr view <PR_NUMBER> --json mergeCommit

# 2. 切換到 main 分支
git checkout main
git pull origin main

# 3. 查看即將 revert 的變更範圍
MERGE_COMMIT="<commit-hash>"
git show $MERGE_COMMIT

# 4. 評估影響範圍（查看之後的 commits）
git log $MERGE_COMMIT..HEAD --oneline

# 5. 執行 revert（需要推送權限）
git revert -m 1 $MERGE_COMMIT

# 6. 推送 revert commit
git push origin main
```

**使用 git-auto-pr.sh（簡化版）：**

```bash
./git-auto-pr.sh

# 選擇選項 3（撤銷當前 PR）
# 智慧檢測 PR 狀態：
#
# 如果 PR 還在開放中：
# - 顯示 PR 資訊
# - 確認後自動關閉
# - 可選同時刪除分支
#
# 如果 PR 已經合併：
# - 顯示合併資訊
# - 顯示影響的 commit 數量
# - 顯示詳細影響範圍
# - revert 選項預設為「否」（安全）
# - 需明確確認才執行 revert
```

---

#### 情境 H：審查並合併 Pull Request（專案擁有者）

**使用傳統 Git 指令：**

```bash
# 1. 列出所有待審查的 PR
gh pr list --state open

# 2. 查看特定 PR 的詳細資訊
gh pr view <PR_NUMBER>

# 3. 檢查 CI 狀態
gh pr checks <PR_NUMBER>

# 4. 檢視 PR 的變更內容
gh pr diff <PR_NUMBER>

# 5. 切換到 PR 分支進行本地測試（可選）
gh pr checkout <PR_NUMBER>
# 執行測試...
git checkout main

# 6. 檢查是否為自己的 PR（避免自我批准）
PR_AUTHOR=$(gh pr view <PR_NUMBER> --json author -q '.author.login')
CURRENT_USER=$(gh api user -q '.login')

if [ "$PR_AUTHOR" = "$CURRENT_USER" ]; then
    echo "無法批准自己的 PR，需要其他人審查"
else
    # 7. 批准 PR
    gh pr review <PR_NUMBER> --approve
fi

# 8. 確認 CI 全部通過
gh pr checks <PR_NUMBER>

# 9. 使用 squash 方式合併
gh pr merge <PR_NUMBER> --squash --delete-branch

# 10. 更新本地 main 分支
git checkout main
git pull --ff-only origin main
```

**使用 git-auto-pr.sh（簡化版）：**

```bash
./git-auto-pr.sh

# 選擇選項 4（審查與合併 PR）
# 自動執行完整流程：
# - 列出所有待審查 PR
# - 選擇 PR 後顯示詳細資訊
# - 顯示 CI 狀態（警告未通過的檢查）
# - 智慧檢測用戶身份：
#   * 如果是自己的 PR：提示無法自我批准
#   * 如果是他人的 PR：提供審查選項
# - 提供操作選項：
#   * 批准並合併（自動 squash）
#   * 添加評論
#   * 請求變更
# - 自動刪除已合併的遠端分支
# - 自動更新本地 main 分支
```

---

#### 情境 I：清理已合併的功能分支

**使用傳統 Git 指令：**

```bash
# 1. 切換到 main 分支
git checkout main
git pull origin main

# 2. 列出所有本地分支
git branch

# 3. 檢查分支是否已合併
git branch --merged main

# 4. 檢查當前分支（避免刪除）
CURRENT_BRANCH=$(git branch --show-current)

# 5. 確認要刪除的分支
echo "即將刪除以下分支："
git branch --merged main | grep -v "\* main" | grep -v "master"

# 6. 逐個刪除本地分支（安全）
git branch -d feature/JIRA-123-old-feature

# 7. 檢查對應的遠端分支是否存在
git ls-remote --heads origin feature/JIRA-123-old-feature

# 8. 刪除遠端分支（需要仔細確認）
git push origin --delete feature/JIRA-123-old-feature

# 9. 清理已刪除遠端分支的本地引用
git fetch --prune

# 10. 對於未合併的分支需要強制刪除（危險）
git branch -D feature/experimental-feature
```

**使用 git-auto-pr.sh（簡化版）：**

```bash
./git-auto-pr.sh

# 選擇選項 5（刪除分支）
# 智慧安全機制：
# - 自動列出所有可刪除分支
# - 標記當前分支（禁止刪除）
# - 標記主分支（絕對禁止刪除）
# - 顯示分支合併狀態
# - 已合併分支：安全刪除（-d）
# - 未合併分支：警告並需要明確確認（-D）
# - 詢問是否同時刪除遠端分支
# - 多重確認機制防止誤刪
# - 自動清理遠端引用
```

---

#### 情境 J：完整的 GitHub Flow 工作流程對比

**使用傳統 Git + gh CLI（完整流程）：**

```bash
# === 階段 1：開始功能開發 ===
git checkout main
git pull --ff-only origin main
git checkout -b feature/JIRA-123-new-api
git push -u origin feature/JIRA-123-new-api

# === 階段 2：開發過程 ===
# ... 編寫程式碼 ...
git add .
git commit -m "feat(api): add new endpoint"
git push origin feature/JIRA-123-new-api

# === 階段 3：創建 PR ===
gh pr create \
  --base main \
  --title "[JIRA-123] 新增 API 端點" \
  --body "實作新的 API 端點功能..."

# === 階段 4：審查與合併（專案擁有者）===
gh pr list
gh pr view 123
gh pr checks 123
gh pr review 123 --approve
gh pr merge 123 --squash --delete-branch

# === 階段 5：清理本地環境 ===
git checkout main
git pull origin main
git branch -d feature/JIRA-123-new-api

# 總計約 15+ 個指令
```

**使用 git-auto-push.sh + git-auto-pr.sh（完整流程）：**

```bash
# === 階段 1：開始功能開發 ===
./git-auto-pr.sh
# 選項 1 → 輸入 JIRA-123 → AI 生成分支名 → 完成

# === 階段 2：開發過程 ===
# ... 編寫程式碼 ...
./git-auto-push.sh
# 選項 1 → AI 生成 commit → 自動推送 → 完成

# === 階段 3：創建 PR ===
./git-auto-pr.sh
# 選項 2 → AI 生成 PR 內容 → 完成

# === 階段 4：審查與合併（專案擁有者）===
./git-auto-pr.sh
# 選項 4 → 選擇 PR → 批准 → 自動 squash 合併 → 完成

# === 階段 5：清理（如需要）===
./git-auto-pr.sh
# 選項 5 → 選擇分支 → 安全刪除 → 完成

# 總計 5 次工具調用，大幅減少手動操作
```

---

### 總結對比

| 操作項目 | 傳統 Git 指令         | 使用自動化工具      | 時間節省 |
| -------- | --------------------- | ------------------- | -------- |
| 日常提交 | 7 個指令              | 1 次互動            | ~80%     |
| 創建分支 | 4 個指令 + 思考命名   | 1 次互動 + AI 生成  | ~70%     |
| 創建 PR  | 6 個指令 + 撰寫內容   | 1 次互動 + AI 生成  | ~85%     |
| 撤銷 PR  | 5-8 個指令 + 風險評估 | 1 次互動 + 智慧檢測 | ~75%     |
| 審查合併 | 10 個指令             | 1 次互動            | ~80%     |
| 清理分支 | 10 個指令 + 安全檢查  | 1 次互動 + 自動保護 | ~85%     |

**工具的核心優勢：**

1. **AI 輔助**：自動生成符合規範的內容
2. **安全機制**：內建保護措施防止危險操作
3. **錯誤處理**：智慧偵測並提供解決建議
4. **工作流程整合**：一次操作完成多個步驟
5. **降低門檻**：新手也能遵循最佳實踐

---

## 進階技巧與最佳實踐

### 1. Git Alias（別名）設定

```bash
# 在 ~/.gitconfig 中添加
[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = log --all --decorate --oneline --graph
    undo = reset --soft HEAD~1
    amend = commit --amend --no-edit

# 或使用指令設定
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
```

### 2. .gitignore 最佳實踐

```bash
# 系統檔案
.DS_Store
Thumbs.db

# 編輯器
.vscode/
.idea/
*.swp
*.swo

# 依賴
node_modules/
vendor/
venv/

# 編譯輸出
*.o
*.pyc
__pycache__/
dist/
build/

# 環境變數
.env
.env.local

# 日誌
*.log
logs/

# 臨時檔案
*.tmp
*.temp
.cache/
```

### 3. Commit Message 規範（Conventional Commits）

```
<type>(<scope>): <subject>

<body>

<footer>

類型（type）：
- feat: 新功能
- fix: 修復 Bug
- docs: 文檔變更
- style: 格式調整（不影響程式碼）
- refactor: 重構
- test: 測試相關
- chore: 建置工具或輔助工具變更

範例：
feat(auth): add user login functionality

Implement JWT-based authentication system with refresh tokens.

Closes #123
```

### 4. 分支命名規範

```
# 功能分支
feature/<jira-id>-<short-description>
feature/JIRA-123-user-authentication

# Bug 修復
fix/<jira-id>-<short-description>
fix/JIRA-456-login-error

# Hotfix
hotfix/<version>-<description>
hotfix/v1.2.1-security-patch

# 發布分支
release/<version>
release/v2.0.0

# 實驗性功能
experiment/<description>
experiment/new-ui-framework
```

### 5. 保持乾淨的提交歷史

```bash
# 在 PR 前整理提交
git rebase -i HEAD~5                  # 互動式 rebase

# 在編輯器中：
# pick 1234567 First commit
# squash 2345678 Fix typo            # 合併到上一個
# fixup 3456789 Add test             # 合併且丟棄訊息
# reword 4567890 Update feature      # 修改訊息
# drop 5678901 Temporary debug       # 刪除提交

# 強制推送更新遠端
git push --force-with-lease origin feature-branch
```

### 6. 避免常見錯誤

```bash
# ❌ 不好的做法
git add .
git commit -m "updates"
git push --force                      # 危險！可能覆蓋他人變更

# ✅ 好的做法
git add -p                            # 選擇性添加
git commit -m "feat(api): add user endpoint"
git push --force-with-lease           # 較安全的強制推送

# ❌ 不要在公共分支上 rebase
git checkout main
git rebase feature-branch             # 不要這樣做

# ✅ 使用 merge 合併到公共分支
git checkout main
git merge --no-ff feature-branch

# ❌ 提交敏感資訊
git add .env                          # 危險！
git commit -m "config"

# ✅ 使用 .gitignore
echo ".env" >> .gitignore
git add .gitignore
git commit -m "chore: ignore environment files"
```

### 7. Git Hooks 自動化

```bash
# .git/hooks/pre-commit
#!/bin/bash
# 提交前自動格式化程式碼
echo "Running linter..."
npm run lint
if [ $? -ne 0 ]; then
    echo "Linting failed. Please fix errors before committing."
    exit 1
fi

# .git/hooks/commit-msg
#!/bin/bash
# 驗證 commit 訊息格式
commit_msg=$(cat "$1")
if ! echo "$commit_msg" | grep -qE "^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .+"; then
    echo "Invalid commit message format."
    echo "Use: <type>(<scope>): <subject>"
    exit 1
fi

# 設定執行權限
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/commit-msg
```

### 8. 效能優化

```bash
# 加速 git status
git config --global core.fsmonitor true
git config --global core.untrackedcache true

# 啟用並行處理
git config --global fetch.parallel 10
git config --global submodule.fetchJobs 10

# 減少網路傳輸
git config --global core.compression 9
git config --global pack.compression 9

# 清理與優化倉庫
git gc --aggressive --prune=now       # 清理並優化
git prune                             # 清理無用物件
```

### 9. 安全性最佳實踐

```bash
# 簽署提交（需設定 GPG）
git config --global user.signingkey <key-id>
git config --global commit.gpgsign true
git commit -S -m "signed commit"

# 驗證簽署
git log --show-signature

# 移除已提交的敏感資訊
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/sensitive/file" \
  --prune-empty --tag-name-filter cat -- --all

# 更好的方式：使用 BFG Repo-Cleaner
bfg --delete-files sensitive.txt
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

### 10. 疑難排解

```bash
# 問題：Push 被拒絕
# 解決：先拉取再推送
git pull --rebase origin main
git push origin main

# 問題：忘記切換分支就開始修改
# 解決：暫存變更後切換
git stash
git checkout correct-branch
git stash pop

# 問題：不小心刪除了分支
# 解決：使用 reflog 恢復
git reflog
git checkout -b recovered-branch <commit-hash>

# 問題：提交到錯誤的分支
# 解決：Cherry-pick 到正確分支
git checkout correct-branch
git cherry-pick <commit-hash>
git checkout wrong-branch
git reset --hard HEAD~1

# 問題：倉庫太大
# 解決：清理大檔案
git rev-list --objects --all | grep "$(git verify-pack -v .git/objects/pack/*.idx | sort -k 3 -n | tail -10 | awk '{print$1}')"
```

---

## 總結

本指南涵蓋了從基礎到進階的 Git 操作，以及本專案工具的使用情境。記住以下原則：

1. **經常提交**：小步快跑，頻繁提交
2. **清晰訊息**：遵循 Conventional Commits 規範
3. **保持同步**：定期拉取最新變更
4. **分支隔離**：功能開發使用獨立分支
5. **審慎操作**：使用 `--force-with-lease` 而非 `--force`
6. **善用工具**：使用 git-auto-push.sh 和 git-auto-pr.sh 提升效率

更多資訊請參考：

- [Git 官方文檔](https://git-scm.com/doc)
- [GitHub Flow](../docs/github-flow.md)
- [專案 README](../README.md)
