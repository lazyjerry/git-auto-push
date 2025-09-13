下列流程可直接套用到你的私有 repo、gh CLI、JIRA、VSCode 環境。

# 概念性檢查清單

1. 主線  `main`  受保護並啟用必備檢查與審核。
2. 分支與提交含 JIRA issue key（例：`JIRA-123`）。
3. 本機已登入  `gh`，且具 repo 權限。
4. PR 模板、CODEOWNERS、CI 工作流程存在且可執行。
5. 以 PR 驅動整合，禁止直接 push 到  `main`。
6. 以  `squash`  合併，保留線性歷史。
7. 合併後自動刪除功能分支並標記對應 JIRA 狀態。

---

# 1) 建立 GitHub Flow 開發環境

## 1.1 安裝與登入

```bash
# macOS (示例)
brew install git gh
gh auth login           # 選 GitHub.com → HTTPS → Browser 登入
code --install-extension GitHub.copilot
code --install-extension GitHub.vscode-pull-request-github
```

## 1.2 取得私有專案

```bash
gh repo clone <org>/<repo>
cd <repo>
gh repo view --web      # 快速打開確認權限
```

## 1.3 連結 JIRA（命名與提交規範）

- 分支：`feature/JIRA-123-short-desc`
- 提交訊息前綴：`[JIRA-123] <what & why>`
- PR 標題：`[JIRA-123] <feature title>`
- 若啟用 JIRA Smart Commits（已安裝 DVCS 連接器）：
  ```
  [JIRA-123] implement X
  #comment add validator
  #time 1h
  #in-progress
  ```

## 1.4 保護 main 與必備檢查（可用 gh api）

```bash
# 需 repo admin 權限；最小化範例：要求 PR、1 次核准、禁止直接推送
OWNER="<org>"; REPO="<repo>"
gh api -X PUT \
  repos/$OWNER/$REPO/branches/main/protection \
  -f required_pull_request_reviews='{"required_approving_review_count":1}' \
  -f enforce_admins=true \
  -f restrictions='null' \
  -f required_status_checks='{"strict":true,"checks":[{"context":"build"},{"context":"test"}]}' \
  -H "Accept: application/vnd.github+json"
```

## 1.5 最低限度專案檔

[PULL_REQUEST_TEMPLATE.md 請參考這裡](https://docs.github.com/zh/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository) 將拉取請求模板添加到倉庫後，項目貢獻者會自動在拉取請求正文中看到模板的內容。

```bash
# .github/PULL_REQUEST_TEMPLATE.md
## Summary
- Issue: JIRA-123
- Changes:
## Checklist
- [ ] Tests pass
- [ ] Docs updated
```

[CODEOWNERS](https://docs.github.com/zh/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) 定義負責倉庫代碼的個人或團隊

```bash
# .github/CODEOWNERS
# 自動指派 reviewer
*   @team/leads
```

[ci.yml](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) 工作流程是可配置的自动化过程，由一个或多个作业组成。 您必须创建 YAML 文件来定义工作流程配置。 這是 on pull_request 的工作流程。

```yaml
# .github/workflows/ci.yml
name: CI
on: [pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "build"
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "test"
```

### 驗證

```bash
gh repo view
gh workflow list
gh api repos/$OWNER/$REPO/branches/main/protection | jq
```

若失敗：確認帳號具 admin 權限；檢查  `ci.yml`  是否在  `pull_request`  觸發。

---

# 2) 開發者提交 PR 流程

## 2.1 建立功能分支

```bash
git checkout main
git pull --ff-only origin main # 僅允許 fast-forward 更新，避免產生額外 merge commit，保證 main 分支歷史線性
git checkout -b feature/JIRA-123-description # 同時建立並切換到新分支
```

## 2.2 開發與測試

```bash
# 在 VSCode 開啟並開發
code .

# 本地測試與 Lint（示例）
npm test || php artisan test
npm run lint
```

## 2.3 提交與推送

```bash
git add -A
git commit -m "[JIRA-123] Add description"
git push -u origin feature/JIRA-123-description
```

## 2.4 建立 PR 並關聯 JIRA

```bash
gh pr create \
  --base main \
  --head feature/JIRA-123-description \
  --title "[JIRA-123] Implement X" \
  --body "Link: JIRA-123\nSummary: ..."
# 可加 reviewer 與標籤
gh pr edit --add-reviewer @team/leads
gh pr edit --add-label "type:feature"
```

## 2.5 自我檢查

```bash
gh pr view --web
gh pr checks             # 檢視 CI 狀態
```

### 驗證

- PR 顯示 2 個必備檢查  `build`、`test`。
- PR 標題與描述含  `JIRA-123`。  
   若失敗：`gh pr checks`  為失敗時，點進 workflow logs 修正；命名未含 issue key 需重命名 PR 或補上描述。

---

# 3) 專案擁有者審查與合併

## 3.1 審查條件

- CI 綠燈。
- 至少 1 次批准審查。
- PR 內容對應 JIRA 需求且清楚可回溯。

```bash
gh pr view <PR#>
gh pr checks <PR#>
gh pr review <PR#> --approve    # 或 --comment / --request-changes
```

## 3.2 合併策略（建議 squash + 刪分支）

```bash
gh pr merge <PR#> --squash --delete-branch
# 或等待檢查完成自動合併
gh pr merge <PR#> --squash --auto --delete-branch
```

## 3.3 合併後動作

```bash
git checkout main
git pull --ff-only origin main
# 發版需另外依內部流程（tag、release、部署）
```

### 驗證

```bash
git log --oneline -n 5
gh release list           # 若有發版流程
```

若失敗：合併受阻多半因檢查或審查未滿足；或分支保護規則過嚴，調整  `branches/main/protection`  後重試。

---

# 速查：常用 gh 指令

```bash
gh auth status
gh repo view --web
gh pr create --fill
gh pr view
gh pr checks
gh pr review --approve
gh pr merge --squash --delete-branch
```

---

# 結束條件總驗證

- `main`  已受保護且要求 CI 與審查。
- PR 可由  `feature/JIRA-123-*`  正常建立，並通過 CI。
- 專案擁有者可使用  `gh`  完成審查與  `--squash`  合併，分支自動刪除。
- JIRA 連結清楚（分支名、提交訊息、PR 標題或 Smart Commits）。

如需補充：確認已啟用 GitHub↔JIRA 連接器以使用 Smart Commits；在 CODEOWNERS 中維護 reviewer 清單以自動指派；於 PR 模板加入「驗收標準」與「風險」欄位可提升審查效率。

---

# 推薦擴充清單（可選，但強烈建議）

> 目的：把「最小治理」升級為「可持續維運」。以下模組皆與 GitHub Flow 相容，逐項採用即可。

## 1) 協作與貢獻

```md
# CONTRIBUTING.md

## Branch & PR

- Branch: feature/JIRA-123-short-desc
- PR: [JIRA-123] concise title

## Commit

- Conventional Commits 可選

## Review

- 至少 1 reviewer；需要 CI 綠燈
```

```md
# CODE_OF_CONDUCT.md

採用 Contributor Covenant 2.1（可用模板）
```

## 2) 安全與維護

```md
# SECURITY.md

- 回報管道：security@company.tld
- SLA：高嚴重性 24h 內回應
- 支援版本：main 最新 N 個 minor
```

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
  - package-ecosystem: "npm"
    directory: "/"
    schedule: { interval: "weekly" }
```

```yaml
# .github/workflows/codeql.yml（語言依專案調整）
name: CodeQL
on: [pull_request]
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with: { languages: javascript }
      - uses: github/codeql-action/analyze@v3
```

## 3) 品質護欄

```ini
# .editorconfig
root = true
[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
indent_style
```
