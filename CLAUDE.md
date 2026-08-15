# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

Git 工作流程自動化工具集（目前版本 v2.11.0），包含兩個核心 Bash 腳本，整合 AI 驅動的內容產生系統，提供傳統 Git 操作和 GitHub Flow PR 流程的完整自動化。

- **git-auto-push.sh**（2,838 行）- 傳統 Git 操作自動化（add/commit/push）
- **git-auto-pr.sh**（2,916 行）- GitHub Flow PR 流程自動化（分支/PR/審查/合併）
- **install.sh**（782 行）- POSIX Shell 相容安裝腳本

本專案無建置系統，開發驗證以 `bash -n` 語法檢查與 `tests/` 自動化測試為主。

## 常用開發命令

```bash
# 語法檢查（修改後必跑）
bash -n git-auto-push.sh
bash -n git-auto-pr.sh
bash -n install.sh

# 自動化測試（對應腳本修改後必跑；隔離環境、離線、不觸發 AI 與 GitHub）
./tests/test-git-auto-push.sh
./tests/test-git-auto-pr.sh

# 功能測試
./git-auto-push.sh --help
./git-auto-pr.sh --help
./git-auto-push.sh --version

# 行數統計（更新 README.md 統計時需要）
wc -l git-auto-push.sh git-auto-pr.sh install.sh

# 調試模式（查看 AI 工具執行詳情，輸出可能含敏感資訊）
export IS_DEBUG=true
./git-auto-push.sh 4
```

## 核心架構設計

### 1. 配置驅動架構

**三級配置優先級系統**（由高到低，載入第一個存在的即停止）：
1. `$PWD/.git-auto-push-config/.env` - 專案級配置
2. `$HOME/.git-auto-push-config/.env` - 使用者級配置
3. `[script_dir]/.git-auto-push-config/.env` - 全域預設配置

配置載入邏輯位於兩個腳本開頭的 `load_config()`。腳本內部使用 `: "${VAR:=default}"` 條件賦值，讓配置文件的值優先於內建預設。範本檔為倉庫內的 `.git-auto-push-config/.env.example`。

**關鍵配置變數**：
- `AI_TOOLS` - AI 工具優先順序陣列，預設 `("opencode" "copilot" "agy" "codex" "claude")`
- `IS_DEBUG` - 調試模式（true/false）
- `AUTO_INCLUDE_TICKET` - 任務編號自動帶入 commit 訊息（git-auto-push.sh）
- `AUTO_CHECK_COMMIT_QUALITY` - Commit 品質自動檢查（git-auto-push.sh）
- `AI_COMMIT_PROMPT`、`AI_PREFIX_PROMPT` - AI 提示詞（git-auto-push.sh，可覆蓋）
- `DEFAULT_MAIN_BRANCHES` - 主分支偵測順序，預設 `("uat" "main" "master")`（git-auto-pr.sh）
- `DEFAULT_USERNAME` - 分支命名前綴用使用者名稱（git-auto-pr.sh）
- `AUTO_DELETE_BRANCH_AFTER_MERGE` - PR 合併後分支刪除策略（git-auto-pr.sh）

### 2. AI 工具整合系統

**容錯鏈設計**：`run_ai_with_fallback()` 按 `AI_TOOLS` 陣列順序依次調用，一個工具失敗（未安裝、超時、錯誤）時自動嘗試下一個；全部失敗時降級至手動輸入。成功時全域變數 `LAST_AI_TOOL` 記錄實際使用的工具。

**各工具的調用函數**（兩個腳本各有一套）：
- `run_copilot_command()` - GitHub Copilot CLI（`copilot -s -p`，programmatic mode）
- `run_codex_command()` - Codex CLI（`codex exec --output-last-message` 取乾淨輸出）
- `run_opencode_command()` - opencode CLI（`--format json` 輸出，優先用 jq 解析 `part.text`）
- `run_stdin_ai_command()` - stdin 型工具（agy/claude）
- `resolve_ai_command()` - 工具名稱映射；**gemini 已停用**，視為 agy（Antigravity）的 alias，舊配置中的 `"gemini"` 會自動映射為 `agy` 執行

**共用底層**（git-auto-push.sh）：`_execute_ai_tool()` 統一超時與調用方式、`_handle_ai_result()` 統一錯誤處理與調試輸出、`clean_ai_message()` 清理輸出雜訊（Node.js 警告、認證訊息等）。

**超時機制**：stdin 型工具 45 秒；copilot/codex/opencode 60 秒；偵測到大型 diff（>500 行）時延長至 90 秒。

**提示詞位置**：
- git-auto-push.sh：`AI_COMMIT_PROMPT`、`AI_PREFIX_PROMPT` 常數（檔案頂部配置區域）
- git-auto-pr.sh：`generate_ai_branch_prompt()`、`generate_ai_pr_prompt()` 函數

### 3. Conventional Commits 支援

`COMMIT_PREFIXES` 陣列定義前綴清單（feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert）。三種選擇方式：互動式選單手動選、AI 依 git diff 自動判斷（`generate_commit_prefix_by_ai()`）、跳過不使用。

### 4. 任務編號整合系統

`initialize_ticket_number()` 從分支名稱解析任務編號（支援 JIRA `PROJ-123`、`feat-001` 等格式），`append_ticket_number_to_message()` 依 `AUTO_INCLUDE_TICKET` 自動加入或詢問，並偵測重複避免重複加入。

### 5. 模組化函數設計

**通用工具函數**：`error_msg()` / `success_msg()` / `warning_msg()` 等彩色輸出（皆輸出至 stderr，stdout 保留給函數回傳值）、`run_command()` 統一指令執行、`run_command_with_loading()` 背景執行＋loading 動畫＋超時控制。

**Git 操作函數**：`check_git_repository()`、`get_git_status()`、`add_all_files()`、`get_main_branch()`（git-auto-pr.sh 主分支自動偵測）。

**錯誤處理**：偵測特定錯誤模式（`401 Unauthorized`、`token_expired`、`stream error`、rate limit 等）並提供具體修復命令；擴充錯誤處理時保持「識別特徵 → 給出修復命令 → 彩色輸出」的一致格式。

## 開發修改指導

### 修改 AI 相關功能

**注意**：AI 相關修改必須同時更新兩個腳本檔案（git-auto-push.sh 和 git-auto-pr.sh），兩者各有一份獨立但結構對應的 AI 函數。

新增 AI 工具支援的步驟：
1. 在 `AI_TOOLS` 陣列預設值中添加工具名稱
2. 實作對應的 `run_*_command()` 函數
3. 在 `run_ai_with_fallback()` 的 case 分支中接上
4. 新增錯誤偵測與工具提示（`show_hints` 區塊）
5. 更新 `.git-auto-push-config/.env.example` 的說明

### 重要慣例

- 互動輸出一律走 stderr，函數以 stdout echo 回傳值——新增輸出時不可污染 stdout
- 使用者輸入以 `xargs` 清理前後空白，確認類輸入轉小寫比對
- 臨時檔用 `mktemp` 建立並在所有路徑上清理（含中斷 trap）

## 程式碼文檔標準

主要函數採用統一的註解格式：

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

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：標準前綴＋簡潔描述變更目的，避免技術細節。

### 版本發布檢核清單

1. 更新兩個腳本頂部的 `VERSION` 常數（`readonly VERSION="vX.Y.Z"`）
2. 更新 [CHANGELOG.md](CHANGELOG.md) - 詳細版本記錄（倒序排列，使用 🆕 新功能／🔧 改進／🐛 修復 分類）
3. 更新 [README.md](README.md) - 版本號、發布日期、「版本歷史摘要」段落的行數統計
4. 驗證各文件版本號一致、文檔連結有效

README.md 僅放版本摘要統計，詳細變更記錄放 CHANGELOG.md。多語版 README（README_EN/CN/JP/KR.md）如有同步需求另行確認。

## 安全考量

- 主分支保護：禁止刪除 `DEFAULT_MAIN_BRANCHES` 中定義的分支；刪除未合併分支需二次確認
- 中斷處理：Ctrl+C 優雅退出（trap INT TERM），自動清理臨時檔與終端狀態
- 調試模式輸出可能包含敏感資訊（git diff、API 回應），僅在必要時啟用
- 腳本不需要 root 權限；全域安裝僅在複製到 /usr/local/bin 時需要 sudo

## 相依工具

| 工具 | 用途 | 必要性 |
|-----|------|--------|
| GitHub CLI (gh) | PR 流程操作 | git-auto-pr.sh 必需（`brew install gh && gh auth login`） |
| AI CLI 工具（opencode/copilot/agy/codex/claude） | 內容自動產生 | 選擇性，未安裝時降級手動輸入 |
| jq | opencode JSON 輸出解析 | 建議安裝（無則 fallback 至 grep/sed） |

## 參考文檔

- [README.md](README.md) - 專案說明與使用方法
- [CHANGELOG.md](CHANGELOG.md) - 完整版本歷史
- [INSTALLATION.md](INSTALLATION.md) - 詳細安裝指南
- [USAGE.md](USAGE.md) - 詳細使用指南
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - AI 代理開發指導
- [docs/reports/](docs/reports/) - 功能詳細說明文件（含 opencode 整合、commit 品質檢查等）
