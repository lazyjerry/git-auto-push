# Git 自動化工具測試套件

完整的 Python 自動化測試套件，用於測試 `git-auto-push.sh` 和 `git-auto-pr.sh` 腳本的功能與整合。

## 📋 測試檔案結構

```
test/
├── test_helpers.py           # 測試輔助工具類和函數
├── test_git_auto_push.py     # git-auto-push.sh 測試
├── test_git_auto_pr.py       # git-auto-pr.sh 測試
├── test_integration.py       # 整合測試
├── run_all_tests.py          # 測試執行器
├── 測試檢查清單.md           # 測試需求清單
└── README.md                 # 本文件
```

## 🚀 快速開始

### 環境需求

- Python 3.7+
- Git 2.0+
- Bash 4.0+

### 執行所有測試

```bash
# 執行完整測試套件
python3 test/run_all_tests.py

# 或使用 chmod +x 後直接執行
chmod +x test/run_all_tests.py
./test/run_all_tests.py
```

### 執行特定測試

```bash
# 只測試 git-auto-push.sh
python3 test/run_all_tests.py --push

# 只測試 git-auto-pr.sh
python3 test/run_all_tests.py --pr

# 只執行整合測試
python3 test/run_all_tests.py --integration

# 詳細輸出模式
python3 test/run_all_tests.py --verbose

# 快速測試（跳過耗時測試）
python3 test/run_all_tests.py --quick

# 遇到失敗就停止
python3 test/run_all_tests.py --failfast
```

### 執行單一測試檔案

```bash
# 測試 git-auto-push.sh
python3 test/test_git_auto_push.py

# 測試 git-auto-pr.sh
python3 test/test_git_auto_pr.py

# 整合測試
python3 test/test_integration.py
```

## 📊 測試覆蓋範圍

### test_git_auto_push.py（7 個測試類別）

#### 1. TestGitAutoPushConfiguration

- ✅ 腳本存在性和可執行權限
- ✅ AI 工具配置讀取
- ✅ AI commit 提示詞配置
- ✅ --help 選項顯示

#### 2. TestGitAutoPushGitStatus

- ✅ 非 Git 倉庫錯誤處理
- ✅ 無變更時的提示訊息
- ✅ 有未提交變更的檢測
- ✅ 已暫存變更的檢測

#### 3. TestGitAutoPushAITools

- ✅ AI 工具優先順序（codex 優先）
- ✅ AI 工具失敗時的降級邏輯
- ✅ 所有 AI 工具失敗時降級到手動輸入

#### 4. TestGitAutoPushCommitMessage

- ✅ 手動輸入 commit message
- ✅ Commit message 格式驗證
- ✅ 空 commit message 拒絕
- ✅ 中文 commit message 要求

#### 5. TestGitAutoPushErrorHandling

- ✅ 無遠端倉庫警告
- ✅ 用戶取消操作

#### 6. TestGitAutoPushWorkflows

- ✅ 模式 1：完整流程 (add → commit → push)
- ✅ 模式 2：本地提交 (add → commit)
- ✅ 模式 3：僅添加 (add)
- ✅ 模式 4：全自動 (add → AI commit → push)
- ✅ 模式 5：僅提交（已暫存檔案）
- ✅ 模式 6：顯示 Git 資訊

#### 7. TestGitAutoPushInteraction

- ✅ 選單顯示
- ✅ Commit 確認提示
- ✅ AI 生成提示

### test_git_auto_pr.py（9 個測試類別）

#### 1. TestGitAutoPRConfiguration

- ✅ 腳本存在性和可執行權限
- ✅ AI 工具配置存在
- ✅ 預設主分支配置
- ✅ 預設使用者名稱配置

#### 2. TestGitAutoPRBranchOperations

- ✅ 建立功能分支
- ✅ 分支名稱格式驗證
- ✅ 非主分支上建立功能分支防護
- ✅ 分支刪除安全機制
- ✅ 無法刪除當前分支

#### 3. TestGitAutoPRAIGeneration

- ✅ AI 生成分支名稱
- ✅ AI 生成 PR 標題
- ✅ AI 生成 PR 描述
- ✅ PR 格式驗證
- ✅ PR 分隔符格式（| 分隔）

#### 4. TestGitAutoPRCreation

- ✅ 建立 PR 需要在功能分支上
- ✅ 建立 PR 需要有變更
- ✅ 有有效變更時可建立 PR

#### 5. TestGitAutoPRCancellation

- ✅ 撤銷 OPEN 狀態的 PR（關閉）
- ✅ 撤銷 MERGED 狀態的 PR（revert）
- ✅ Revert 操作需要確認
- ✅ 顯示 commit 影響範圍

#### 6. TestGitAutoPRReview

- ✅ 合併需要審查批准
- ✅ 限制自我批准
- ✅ Squash 合併策略
- ✅ CI 狀態檢查

#### 7. TestGitAutoPRSafetyMechanisms

- ✅ 主分支保護
- ✅ 防止刪除主分支
- ✅ 防止刪除當前分支
- ✅ 分支刪除多重確認

#### 8. TestGitAutoPRErrorHandling

- ✅ 非 Git 倉庫錯誤
- ✅ GitHub CLI 未安裝錯誤
- ✅ 無遠端倉庫錯誤
- ✅ 網路錯誤處理
- ✅ 無效分支名稱錯誤

#### 9. TestGitAutoPRIntegration

- ✅ 完整的 GitHub Flow 流程
- ✅ 多個功能分支並行開發

### test_integration.py（5 個測試類別）

#### 1. TestCompleteWorkflow

- ✅ 場景 1：傳統工作流程
- ✅ 場景 2：GitHub Flow 工作流程
- ✅ 場景 3：多次提交工作流程
- ✅ 場景 4：功能分支生命週期
- ✅ 場景 5：熱修復工作流程

#### 2. TestScriptCooperation

- ✅ Push 後 PR 工作流程
- ✅ 分支狀態一致性
- ✅ Commit 歷史完整性

#### 3. TestErrorRecovery

- ✅ 從失敗的 commit 恢復
- ✅ 從取消的操作恢復
- ✅ 處理合併衝突

#### 4. TestPerformanceAndReliability

- ✅ 處理大型 diff
- ✅ 一次提交多個檔案
- ✅ 腳本超時處理
- ✅ 並發操作限制

#### 5. TestRealWorldScenarios

- ✅ 日常開發循環
- ✅ 功能開發完整生命週期
- ✅ 緊急熱修復

## 🛠️ 測試輔助工具

### GitTestRepo 類別

模擬 Git 倉庫環境，提供：

- 臨時倉庫建立和清理
- 檔案操作（建立、修改、刪除）
- Git 命令執行（add、commit、branch、checkout 等）
- 狀態查詢（分支、狀態、變更檢測等）

### MockAITool 類別

模擬 AI 工具行為，提供：

- 可配置的回應內容
- 調用歷史記錄
- 失敗模擬

### 輔助函數

- `run_script_with_input()`: 執行腳本並提供輸入
- `assert_output_contains()`: 斷言輸出包含特定內容
- `assert_commit_message_format()`: 驗證 commit message 格式
- `assert_pr_format()`: 驗證 PR 格式

## 📝 測試範例

### 測試配置讀取

```python
def test_ai_tools_configuration(self):
    """測試：AI 工具配置是否正確讀取"""
    script_content = self.script_path.read_text(encoding="utf-8")

    self.assertIn("readonly AI_TOOLS=", script_content)
    self.assertIn("codex", script_content)
    self.assertIn("gemini", script_content)
```

### 測試 Git 狀態

```python
def test_has_uncommitted_changes(self):
    """測試：有未提交變更時的處理"""
    self.test_repo.create_file("test.txt", "initial")
    self.test_repo.add_files()
    self.test_repo.commit("initial")

    self.test_repo.modify_file("test.txt", "modified")

    self.assertTrue(self.test_repo.has_uncommitted_changes())
```

### 測試工作流程

```python
def test_mode_2_local_commit(self):
    """測試：模式 2 - 本地提交 (add → commit)"""
    self.test_repo.create_file("test.txt")

    result = run_script_with_input(
        self.script_path,
        self.test_repo.repo_path,
        input_text="本地測試 commit\ny\n",
        args=["2"],
        timeout=15
    )

    if result.returncode == 0:
        log = self.test_repo._run_git_command("log", "--oneline")
        self.assertIn("本地測試", log.stdout)
```

## 🐛 除錯技巧

### 查看測試輸出

```bash
# 詳細模式查看所有輸出
python3 test/run_all_tests.py --verbose

# 只執行特定測試類別
python3 -m unittest test.test_git_auto_push.TestGitAutoPushConfiguration
```

### 查看腳本執行結果

在測試中添加調試輸出：

```python
result = run_script_with_input(...)
print("STDOUT:", result.stdout)
print("STDERR:", result.stderr)
print("Return code:", result.returncode)
```

### 保留測試倉庫

修改測試在 `tearDown()` 中不刪除臨時倉庫：

```python
def tearDown(self):
    # self.test_repo.cleanup()  # 註解這行
    print(f"Test repo: {self.test_repo.repo_path}")
```

## ⚠️ 注意事項

1. **網路依賴**：某些測試需要網路連線（AI 工具調用、GitHub API）
2. **權限要求**：測試會建立臨時檔案和目錄
3. **超時設定**：AI 相關測試有較長的超時時間（30-60 秒）
4. **環境隔離**：每個測試使用獨立的臨時 Git 倉庫
5. **清理機制**：測試結束後會自動清理臨時資源

## 🔧 CI/CD 整合

### GitHub Actions 範例

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: "3.9"
      - name: Run tests
        run: python3 test/run_all_tests.py
```

## 📈 未來改進

- [ ] 增加代碼覆蓋率報告
- [ ] 增加效能基準測試
- [ ] 模擬更多錯誤情境
- [ ] 增加並發測試
- [ ] 增加網路模擬（mock GitHub API）
- [ ] 增加測試報告生成（HTML/XML）

## 🤝 貢獻指南

新增測試時請遵循：

1. **命名規範**：`test_<功能描述>`
2. **文檔字串**：每個測試都要有清楚的說明
3. **獨立性**：測試之間不應有依賴關係
4. **清理資源**：確保 `tearDown()` 正確清理
5. **斷言明確**：使用具體的斷言訊息

## 📚 相關文檔

- [測試檢查清單](./測試檢查清單.md)
- [Git 使用說明](../docs/git-usage.md)
- [GitHub Flow](../docs/github-flow.md)
- [主專案 README](../README.md)

## 📞 問題回報

如果測試失敗或有問題，請：

1. 檢查環境需求是否滿足
2. 使用 `--verbose` 查看詳細輸出
3. 查看測試日誌和錯誤訊息
4. 在 GitHub Issues 回報問題

---

**作者**: Lazy Jerry  
**版本**: v1.0.0  
**最後更新**: 2025-10-24
