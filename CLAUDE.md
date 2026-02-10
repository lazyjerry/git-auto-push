# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

這是一個 **Git 工作流程自動化工具集**，包含兩個核心 Bash 腳本，整合 AI 驅動的內容產生系統，提供傳統 Git 操作和 GitHub Flow PR 流程的完整自動化。

- **git-auto-push.sh** (2,552 行) - 傳統 Git 操作自動化（add/commit/push）
- **git-auto-pr.sh** (2,769 行) - GitHub Flow PR 流程自動化（分支/PR/審查/合併）
- **install.sh** (689 行) - POSIX Shell 相容安裝腳本

版本：v2.8.0

## 核心架構設計

### 1. 配置驅動架構

**三級配置優先級系統**（由高到低）：
1. `$PWD/.git-auto-push-config/.env` - 專案級配置
2. `$HOME/.git-auto-push-config/.env` - 使用者級配置
3. `[script_dir]/.git-auto-push-config/.env` - 全域預設配置

**關鍵配置變數**：
- `AI_TOOLS` - AI 工具優先順序陣列（例：`("copilot" "gemini" "codex" "claude")`）
- `DEFAULT_MAIN_BRANCHES` - 主分支偵測順序（git-auto-pr.sh，例：`("uat" "main" "master")`）
- `DEFAULT_USERNAME` - 預設使用者名稱（git-auto-pr.sh）
- `AUTO_CHECK_COMMIT_QUALITY` - Commit 品質自動檢查（git-auto-push.sh，true/false）
- `AUTO_DELETE_BRANCH_AFTER_MERGE` - PR 合併後分支刪除策略（git-auto-pr.sh，true/false）
- `IS_DEBUG` - 調試模式（true/false）

配置載入邏輯位於兩個腳本的開頭（`load_config()` 函數）。

### 2. AI 工具整合系統

**容錯鏈設計**：AI 工具按 `AI_TOOLS` 陣列順序依次調用，當一個工具失敗時自動嘗試下一個。

**核心函數**：
- `run_codex_command()` - Codex/Copilot CLI 調用
- `run_stdin_ai_command()` - 支援 stdin 的 AI 工具調用（gemini/claude）
- `clean_ai_message()` - 清理 AI 輸出（移除元數據和技術雜訊）
- `generate_ai_commit_prompt()` - Commit 訊息提示詞生成（git-auto-push.sh）
- `generate_ai_pr_prompt()` - PR 內容提示詞生成（git-auto-pr.sh）

**超時機制**：45 秒超時，防止 AI 工具卡死。

### 3. Conventional Commits 支援

**前綴類型清單**（`COMMIT_PREFIXES` 陣列）：
- feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert

**實作方式**：
- 手動選擇：互動式選單
- AI 自動判斷：基於 git diff 分析
- 跳過選項：不使用前綴

### 4. 任務編號整合系統

**自動偵測**：從分支名稱解析 issue key（支援 JIRA `PROJ-123`、GitHub Issue `feat-001` 等格式）

**整合範圍**：所有 commit 操作（選項 1、2、4、5、7）

**重複檢測**：避免重複加入任務編號

### 5. 模組化函數設計

**通用工具函數**：
- `error_msg()`, `success_msg()`, `warning_msg()` - 彩色格式化輸出
- `run_command()` - 統一的指令執行介面
- `show_loading()` - Loading 動畫顯示

**Git 操作函數**：
- `check_git_repository()` - Git 倉庫驗證
- `get_git_status()` - Git 狀態檢查
- `add_all_files()` - Git add 操作封裝
- `get_main_branch()` - 主分支自動偵測（git-auto-pr.sh）

**錯誤處理**：
- 自動偵測特定錯誤（`401 Unauthorized`, `token_expired`, `stream error`）
- 提供具體修復命令和操作步驟
- 優雅降級（AI 工具全部失效時切換至手動輸入模式）

## 常用開發命令

### 語法檢查與測試

```bash
# 語法檢查
bash -n git-auto-push/git-auto-push.sh
bash -n git-auto-push/git-auto-pr.sh
bash -n git-auto-push/install.sh

# 功能測試
cd git-auto-push
./git-auto-push.sh --help
./git-auto-pr.sh --help

# AI 工具可用性測試
for tool in "${AI_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 && echo "✅ $tool 可用" || echo "⚠️ $tool 未安裝"
done
```

### 行數統計

```bash
# 統計腳本行數（更新 README.md 時需要）
wc -l git-auto-push/git-auto-push.sh git-auto-push/git-auto-pr.sh git-auto-push/install.sh
```

### 調試模式

```bash
# 啟用調試模式（查看 AI 工具執行詳情）
export IS_DEBUG=true
./git-auto-push.sh 4

# 或透過配置文件設定
echo 'IS_DEBUG=true' >> ~/.git-auto-push-config/.env
```

## 開發修改指導

### 修改 AI 相關功能

**注意**：修改 AI 工具時，必須同時更新兩個腳本檔案（git-auto-push.sh 和 git-auto-pr.sh）。

1. **調整 AI 工具優先順序**：
   - 修改 `AI_TOOLS` 陣列（位於檔案頂部預設值區域，約第 120-130 行）
   - 或透過配置文件覆蓋

2. **修改 AI 提示詞**：
   - git-auto-push.sh：`AI_COMMIT_PROMPT` 常數、`generate_ai_prefix_prompt()` 函數
   - git-auto-pr.sh：`generate_ai_pr_prompt()` 函數

3. **新增 AI 工具支援**：
   - 在 `AI_TOOLS` 陣列中添加工具名稱
   - 實作對應的 `run_*_command()` 函數
   - 新增錯誤偵測和處理邏輯

### 修改分支管理配置（git-auto-pr.sh）

位於檔案頂部預設值區域（約第 140-180 行）：

```bash
# 主分支偵測順序
DEFAULT_MAIN_BRANCHES=("uat" "main" "master")

# 預設使用者名稱
DEFAULT_USERNAME="jerry"

# PR 合併後分支刪除策略
AUTO_DELETE_BRANCH_AFTER_MERGE=false
```

**或透過配置文件覆蓋**：
```bash
# ~/.git-auto-push-config/.env
DEFAULT_MAIN_BRANCHES=("develop" "main" "master")
DEFAULT_USERNAME="your-name"
AUTO_DELETE_BRANCH_AFTER_MERGE=true
```

### 修改 Commit 品質檢查（git-auto-push.sh）

位於檔案頂部配置區域（約第 149 行）：

```bash
# 自動檢查模式（預設，每次 commit 前自動檢查）
AUTO_CHECK_COMMIT_QUALITY=true

# 詢問模式（提交前詢問是否檢查）
AUTO_CHECK_COMMIT_QUALITY=false
```

### 錯誤處理擴展

在現有錯誤偵測函數中添加新的錯誤模式，保持一致的錯誤輸出格式：
- 識別錯誤特徵
- 提供具體修復命令
- 使用彩色格式化輸出

## 程式碼文檔標準

所有主要函數都採用統一的註解格式：

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

## 版本管理與文檔維護

### Commit 訊息規範

遵循 [Conventional Commits](https://www.conventionalcommits.org/) 格式：
- 使用標準前綴（feat, fix, docs, refactor 等）
- 簡潔描述變更內容和目的
- 避免技術細節

### 行數統計維護

修改程式碼後必須更新 README.md 中的行數統計（約第 623 行）：
- git-auto-push.sh：當前 2,552 行
- git-auto-pr.sh：當前 2,769 行
- install.sh：當前 689 行

### 文檔同步更新

**版本發布時的檢核清單**：
1. 更新 [CHANGELOG.md](git-auto-push/CHANGELOG.md) - 詳細版本記錄
2. 更新 [README.md](git-auto-push/README.md) - 版本號、發布日期、行數統計
3. 驗證兩個文件中的版本號一致
4. 檢查所有文檔連結的有效性

**README.md 撰寫原則**：
- 僅包含版本摘要統計（最新版本號、總版本數、開發期間、行數統計）
- 詳細變更記錄放在 CHANGELOG.md
- 保持結構清晰、簡潔

**CHANGELOG.md 撰寫原則**：
- 按時間倒序排列（最新在上）
- 使用標準分類（🆕 新功能、🔧 改進、🐛 修復）
- 包含精確的行數變化統計
- 提供具體的使用範例和配置說明

## 安全考量

### 操作安全
- 主分支保護：絕對禁止刪除 `DEFAULT_MAIN_BRANCHES` 中定義的分支
- 多重確認機制：刪除未合併分支需要二次確認
- 中斷處理：支援 Ctrl+C 優雅退出，自動清理暫存資源

### 資料保護
- 所有使用者輸入都會經過清理和驗證
- 調試模式輸出可能包含敏感資訊（git diff、API 回應），僅在必要時啟用

### 權限管理
- 腳本不需要 root 權限
- 全域安裝時需要 sudo（僅複製檔案到 /usr/local/bin）

## 相依工具

| 工具 | 用途 | 必要性 | 安裝命令 |
|-----|------|--------|---------|
| **GitHub CLI (gh)** | PR 流程操作 | git-auto-pr.sh 必需 | `brew install gh && gh auth login` |
| **AI CLI 工具** | 內容自動產生 | 選擇性（建議安裝） | 參考 [INSTALLATION.md](git-auto-push/INSTALLATION.md) |

## 參考文檔

- [README.md](git-auto-push/README.md) - 專案說明與使用方法
- [CHANGELOG.md](git-auto-push/CHANGELOG.md) - 完整版本歷史
- [INSTALLATION.md](git-auto-push/INSTALLATION.md) - 詳細安裝指南
- [USAGE.md](git-auto-push/USAGE.md) - 詳細使用指南
- [.github/copilot-instructions.md](git-auto-push/.github/copilot-instructions.md) - AI 代理開發指導
- [docs/reports/](git-auto-push/docs/reports/) - 功能詳細說明文件
