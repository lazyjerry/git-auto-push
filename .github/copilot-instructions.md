# Git 工作流程自動化工具集 - AI 開發指南

## Git Auto-Push 專案 AI 指導說明

## 🎯 專案概述

雙腳本 Bash 工具集，整合 **傳統 Git** 與 **GitHub Flow** 工作流程，自動執行從 `git add` 到 PR 管理的步驟，並串連多套 AI 工具鏈生成內容。專案無外部腳本依賴，所有邏輯自包含於兩個主腳本中。

## 🏗️ 專案架構總覽

- `git-auto-push.sh`（約 1372 行）：傳統 Git 工作流程（add / commit / push）與倉庫資訊檢視。
- `git-auto-pr.sh`（約 2263 行）：GitHub Flow 操作（分支 / PR / 審查 / 合併 / 刪除）。

### 核心組件

- **配置區**：集中管理 AI 工具與提示詞（`AI_TOOLS`、`AI_COMMIT_PROMPT`、`DEFAULT_MAIN_BRANCHES` 等）。
- **AI 工具整合**：以 `run_*_command()` 函數封裝各 AI 工具。
- **操作模式**：`execute_*_workflow()` 函數群涵蓋多種工作流程（push 端 6 種、PR 端 5 種）。
- **Loading 動畫系統**：`show_loading()` 與背景進程協作展示執行狀態。
- **信號處理機制**：多層級 `trap` 保證長任務中斷時的清理。
- **同步點**：`generate_auto_commit_message()` 與 `generate_auto_commit_message_silent()` 必須同步維護。

## 🤖 AI 工具鏈整合架構

### 關鍵函數

- `generate_auto_commit_message()`（互動模式，約 444 行）。
- `generate_auto_commit_message_silent()`（自動模式，約 377 行）。

兩者皆依 `AI_TOOLS` 順序遍歷，屬於硬編碼優先權邏輯；調整工具順序時務必同步修改。

### 統一配置模式（修改入口）

```bash
# 調用順序：codex → gemini → claude → fallback
readonly AI_TOOLS=("codex" "gemini" "claude")

# Prompt 生成函數（調整 AI 行為）
generate_ai_commit_prompt()   # commit 訊息（兩腳本）
generate_ai_branch_prompt()   # 分支名稱（僅 git-auto-pr.sh）
generate_ai_pr_prompt()       # PR 標題與內容（僅 git-auto-pr.sh）
```

### AI 調用模式差異

- `run_codex_command()`：使用 `codex exec "$prompt"`，需額外的輸出清理與統一 45 秒超時機制。
- `run_ai_tool_command()`：以 `echo "$prompt" | $tool_name` 管道呼叫 Gemini／Claude，重用相同結構。
- `clean_ai_message()`：標準化所有 AI 輸出格式。

> **重要**：任何 AI 工具優先順序或遍歷邏輯更新，都必須同步修改兩個 `generate_*_commit_message*()` 函數。

## ⚙️ 關鍵配置點

### 🚨 開發協作規則

**重要**：涉及兩個主腳本的修改必須遵循以下隔離原則：

- **`git-auto-push.sh` 為穩定版本，除非特別需求，否則不應隨意修改**

  - 僅允許在 bug 修復或架構調整時修改
  - 任何新增功能或實驗應優先在 `git-auto-pr.sh` 中進行
  - 若必須修改，需明確理由並更新版本號與 CHANGELOG

- **`git-auto-pr.sh` 為開發版本，新功能和測試優先集中於此**
  - 新增 AI 工具、提示詞調整、工作流程改進都在此進行
  - 功能驗證完成且穩定後，方可複製至 `git-auto-push.sh`
  - 保持與 `git-auto-push.sh` 的一致性（相同配置區間、AI 工具優先順序）

### git-auto-push.sh

- `AI_TOOLS` 與 `AI_COMMIT_PROMPT` 定義於檔案開頭（約 28–52 行）。
- `DEFAULT_OPTION=1`（約 674 行）控制互動介面預設執行模式。
- 超時策略：基準 45 秒，可依 diff 大小調整；在 `run_codex_command()` 中設置。
- Loading 動畫：`show_loading()` 以背景進程顯示 spinner，需配合 `trap` 清理。
- ⚠️ **限制事項**：涉及 UTF-8 編碼、檔案寫入等底層操作時，需確保與 `git-auto-pr.sh` 同步。

### git-auto-pr.sh

- `AI_TOOLS` 具有不同預設順序 `("gemini" "codex" "claude")`。
- `DEFAULT_MAIN_BRANCHES=("main" "master")`，可擴充例如新增 `develop`。
- 安全防護涵蓋主分支保護、CI 狀態檢查與分支刪除多重確認。
- ✅ **主要實驗場所**：新增 AI 工具、編碼修復、功能改進應優先在此進行。

## 🚀 命令列接口與操作模式

### git-auto-push.sh（6 種模式）

| 模式 | 函數                      | 流程                   | 典型場景     |
| ---- | ------------------------- | ---------------------- | ------------ |
| 1    | `execute_full_workflow()` | add → commit → push    | 日常開發     |
| 2    | `execute_local_commit()`  | add → commit           | 離線開發     |
| 3    | `execute_add_only()`      | add                    | 暫存變更     |
| 4    | `execute_auto_workflow()` | add → AI commit → push | CI/CD 整合   |
| 5    | `execute_commit_only()`   | commit（已暫存）       | 分階段提交   |
| 6    | `show_git_info()`         | 顯示倉庫資訊           | 狀態查看診斷 |

常用指令：

- `./git-auto-push.sh`：互動模式。
- `./git-auto-push.sh --auto` 或 `./git-auto-push.sh -a`：全自動模式。

### git-auto-pr.sh（5 種模式）

| 模式 | 關鍵函數         | 特殊邏輯                                    | 安全機制             |
| ---- | ---------------- | ------------------------------------------- | -------------------- | --- | ---------- | ------------ |
| 1    | 建立功能分支     | AI 生成分支名稱並驗證格式                   | 必須以 main 為基底   |
| 2    | 建立 PR          | AI 生成標題／內容，使用 `                   |                      |     | ` 分隔欄位 | 檢查 CI 狀態 |
| 3    | 撤銷 PR（智慧）  | `open→close`，`merged→revert`（預設「否」） | 顯示 commit 影響範圍 |
| 4    | 審查合併         | 雙向審查與自我批准限制                      | 採用 squash 策略     |
| 5    | 刪除分支（安全） | 主分支保護與多重確認                        | 禁止刪除當前分支     |

**模式 3（撤銷 PR）示例邏輯：**

```bash
if [[ "$pr_state" == "OPEN" ]]; then
    提供關閉選項
elif [[ "$pr_state" == "MERGED" ]]; then
    提供 revert 選項（預設為 "否"）
    顯示影響的 commit 數量與範圍
fi
```

## 🎬 背景進程與信號處理（穩定性核心）

### Loading 動畫系統

```bash
show_loading() {
    # 背景進程顯示旋轉動畫
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    while kill -0 "$pid"; do  # 檢查主進程存活
        printf "\r%s %s (%d/%ds)" "${spinner:$i:1}" "$msg" "$elapsed" "$timeout"
    done
}

run_command_with_loading() {
    eval "$command" > "$temp_file" &  # 背景執行
    show_loading "$message" "$timeout" "$!" &
    # PID 追蹤 + 超時檢測 + 結果回收
}
```

### 信號處理模式

```bash
# 模式 1：全域處理（main 函數）
trap global_cleanup INT TERM
global_cleanup() {
    printf "\r\033[K\033[?25h"  # 清理終端、顯示游標
    warning_msg "操作中斷，清理中..."
    exit 130  # SIGINT 標準退出碼
}

# 模式 2：局部處理（Loading 函數）
trap loading_cleanup INT TERM
loading_cleanup() {
    kill "$loading_pid" "$cmd_pid" 2>/dev/null
    rm -f "$temp_file"  # 清理資源
}
```

> **關鍵**：任何長時間執行函數結束前記得 `trap - INT TERM` 移除暫時性處理器。

## 🔧 實際開發場景指南

### 場景 1：新增 AI 工具（如 `gpt`）

```bash
# 步驟 1：更新配置（兩個檔案頂部）
readonly AI_TOOLS=("gpt" "codex" "gemini" "claude")

# 步驟 2：實作調用函數（依工具特性選擇模式）
run_gpt_command() {
    # stdin 模式可複用 run_ai_tool_command
    # 特殊處理可參考 run_codex_command
}

# 步驟 3：更新 git-auto-push.sh 兩個函數
generate_auto_commit_message() {
    for tool in "${AI_TOOLS[@]}"; do
        case "$tool" in
            "gpt") run_gpt_command "$prompt" && break ;;
        esac
    done
}

generate_auto_commit_message_silent() {
    # 同步添加相同邏輯
}
```

### 場景 2：調整 AI Prompt 提示詞

```bash
# 修改檔案頂部的 prompt 函數即可，無需改動調用邏輯
generate_ai_commit_prompt() {
    local short_diff="$1"
    echo "NEW_PROMPT_TEMPLATE: $short_diff"
}
```

### 場景 3：新增主分支類型（git-auto-pr.sh）

```bash
# 直接更新陣列，自動套用
readonly -a DEFAULT_MAIN_BRANCHES=("main" "master" "develop" "dev")

for branch in "${DEFAULT_MAIN_BRANCHES[@]}"; do
    if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        MAIN_BRANCH="$branch"
        break
    fi
done
```

### 場景 4：修改超時策略

```bash
# run_codex_command 函數中依 diff 大小調整
local timeout=60
if [ "$diff_size" -gt 500 ]; then
    timeout=90
fi
```

## 📋 輸出格式規範（一致性）

- 一律使用專案封裝函數：`handle_error()`、`success_msg()`、`warning_msg()`、`info_msg()`。
- 禁止直接 `echo`；維持彩色輸出與語氣一致性。

```bash
success_msg "✅ 操作完成"
warning_msg "⚠️  AI 工具失敗，使用備用工具"
info_msg "🔄 正在處理..."
```

終端控制碼備忘：

- `\033[?25l`：隱藏游標（Loading 開始）。
- `\033[?25h`：顯示游標（Loading 結束）。
- `\r\033[K`：清除當前行。

## ⚠️ 常見陷阱與最佳實踐

1. **AI 工具同步**：同時更新兩個 `generate_*_commit_message*()` 函數。
2. **信號處理**：暫時性 `trap` 結束前務必還原，避免洩漏到其他流程。
3. **輸入緩衝**：長流程後使用 `read -r -t 0.1 dummy` 清空殘留輸入。
4. **路徑假設**：腳本預設從 Git 倉庫根目錄執行。
5. **主分支檢測**：依序遍歷 `DEFAULT_MAIN_BRANCHES`，不可只硬編碼 `main`。
6. **穩定版本保護**：**`git-auto-push.sh` 為穩定生產版本，禁止隨意修改**
   - 所有實驗性功能、bug 修復、編碼改進應優先在 `git-auto-pr.sh` 進行
   - 除非涉及明確的共用函數（如 `run_command_with_loading()` 等基礎工具）且兩邊需保持同步，否則禁止修改 `git-auto-push.sh`
   - 修改時需明確說明理由並同步更新 CHANGELOG

## 📋 禁止事項

- 禁止隨意修改 `git-auto-push.sh`，該檔案為穩定版本
- 禁止新增功能到 `git-auto-push.sh`，應優先在 `git-auto-pr.sh` 驗證
- 禁止未同步的修改（如只改 `git-auto-pr.sh` 而忘記同步共用函數到 `git-auto-push.sh`）
- 禁止在不清楚影響範圍的情況下修改配置區（`AI_TOOLS`、Prompt 函數等）

## 🧪 測試與驗證

### 語法檢查

```bash
bash -n git-auto-push.sh
bash -n git-auto-pr.sh
shellcheck git-auto-*.sh
```

### 功能驗證

```bash
# 測試 AI 工具可用性
for tool in codex gemini claude; do
    command -v "$tool" && echo "$tool 可用" || echo "$tool 不可用"
done

# 測試配置讀取
source git-auto-push.sh
echo "${AI_TOOLS[@]}"
```

## 📚 相關文檔位置

- `README.md`：完整使用指南。
- `docs/github-flow.md`：GitHub Flow 概念與配置。
- `docs/pr-cancel-feature.md`：PR 撤銷功能設計。
- `docs/git-info-feature.md`：Git 倉庫資訊功能。
- `.github/instructions/copilot-bash-doc-tw.instructions.md`：Bash 註解規範。
- `.github/instructions/copilot-readme.instructions.md`：README 生成規範。

## 🎓 快速上手檢查清單

- [ ] 理解雙腳本架構差異（push vs pr）。
- [ ] 熟悉配置區位置（檔案頂部）。
- [ ] 了解 AI 呼叫模式差異（`exec` vs `stdin`）。
- [ ] 同步維護兩個 AI commit 生成函數。
- [ ] 以專案輸出函數取代直接 `echo`。
- [ ] 長時間操作加入適當 `trap` 清理。
- [ ] 執行語法檢查與手動驗證關鍵流程。
