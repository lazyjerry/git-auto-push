#!/bin/bash
# -*- coding: utf-8 -*-
#
# ==============================================================================
# GitHub Flow PR 流程自動化工具 (git-auto-pr.sh)
# ==============================================================================
#
# 描述：提供完整的 GitHub Flow 工作流程自動化，從分支建立到 PR 合併
#      支援 AI 輔助功能和企業級安全機制，適用於團隊協作開發
#
# 主要功能：
# ├── GitHub Flow 完整流程：分支建立 → 開發 → PR 建立 → 審查 → 合併
# ├── 5 種操作模式：建立分支、建立 PR、撤銷 PR、審查合併、刪除分支
# ├── AI 智慧功能：自動生成分支名、commit 訊息、PR 內容
# ├── 安全機制：主分支保護、多重確認、PR 狀態檢查
# ├── 智慧撤銷：支援開放 PR 關閉和已合併 PR 的 revert
# ├── 分支管理：安全的本地/遠端分支刪除功能
# └── 錯誤處理：企業級錯誤偵測與智慧修復建議
#
# 使用方法：
#   互動式模式：  ./git-auto-pr.sh          # 顯示選單選擇操作
#   相容模式：    ./git-auto-pr.sh --auto   # 已廈用，提示使用互動模式
#   全域使用：    git-auto-pr               # 全域安裝後
#
# 系統需求：
#   - Bash 4.0+
#   - Git 2.0+
#   - GitHub CLI (gh) - 必需，用於 PR 操作
#   - 選用：AI CLI 工具 (codex/gemini/claude) 用於智慧功能
#
# 作者：Lazy Jerry
# 版本：v1.4.0  
# 最後更新：2025-09-21
# 授權：MIT License
# 倉庫：https://github.com/lazyjerry/git-auto-push
# 文檔：docs/github-flow.md
#
# ==============================================================================
#

# ==============================================
# AI 提示詞配置區域
# ==============================================
# 
# 說明：此區域包含所有 AI 工具使用的提示詞模板
# 修改這些函數可以調整 AI 生成的內容品質和格式
# 支援的 AI 工具：codex, gemini, claude
#
# 注意事項：
# 1. 提示詞應保持簡潔明確，避免過長導致超時
# 2. 使用統一的輸出格式便於後處理
# 3. 修改後請測試各種場景確保相容性
# ==============================================

# AI 分支名稱生成提示詞模板
# 參數：$1=issue_key, $2=description_hint
# 輸出：符合 Git 規範的分支名稱 (feature/xxx-xxx 格式)
generate_ai_branch_prompt() {
    local issue_key="$1"
    local description_hint="$2"
    LC_ALL=zh_TW.UTF-8 printf '%s' "Generate branch name: feature/$issue_key-description. Issue: $issue_key, Description: $description_hint. Use only lowercase, numbers, hyphens. Max 40 chars. Example: feature/jira-456-add-auth"
}

# AI Commit 訊息生成提示詞模板  
# 輸出：符合 Conventional Commits 規範的中文訊息
# 注意：實際的 git diff 內容會通過 content 參數傳遞，不包含在 prompt 中
# AI PR 內容生成提示詞模板
# 參數：$1=issue_key, $2=branch_name, $3=commits, $4=file_changes  
# 輸出：PR標題|||PR內容 格式，使用 ||| 分隔標題和內容
generate_ai_pr_prompt() {
    local issue_key="$1"
    local branch_name="$2"
    local commits="$3"
    local file_changes="$4"
    
    # 使用 printf 確保 UTF-8 編碼輸出
    LC_ALL=zh_TW.UTF-8 printf '%s' "根據以下 commit 訊息摘要生成 PR 標題和內容。格式：標題|||內容（使用 ||| 分隔）。Issue: $issue_key, 分支: $branch_name。要求：1) 標題10-20字簡潔描述主要功能；2) 內容基於 commit 訊息整理功能變更要點；3) 使用繁體中文；4) 不要描述技術細節或 diff。Commits: $commits。檔案變更參考: $file_changes"
}

# AI 工具優先順序配置
# 說明：定義 AI 工具的調用順序，當前一個工具失敗時會自動嘗試下一個
# 修改此陣列可以調整工具優先級或新增其他 AI 工具
# readonly AI_TOOLS=( "codex" "gemini" "claude")
# codex 會有語系的問題取得的 commit 訊息變成亂碼造成失敗
readonly AI_TOOLS=( "gemini" "claude")

# ==============================================
# 分支配置區域
# ==============================================
#
# 主分支候選清單：依優先順序自動檢測
# 可自行添加更多分支名稱，腳本會按順序檢測第一個存在的分支
# 格式：("分支1" "分支2" "分支3" ...)
readonly -a DEFAULT_MAIN_BRANCHES=("main" "master")

# ==============================================
# 工具函數區域
# ==============================================

# ============================================
# 錯誤處理函數
# 功能：顯示紅色錯誤訊息並終止腳本執行
# 參數：$1 - 錯誤訊息內容
# 返回：無（直接退出程式，exit code 1）
# 使用：handle_error "發生嚴重錯誤"
# ============================================
handle_error() {
    printf "\033[0;31m錯誤: %s\033[0m\n" "$1" >&2
    exit 1
}

# ============================================
# 成功訊息函數
# 功能：顯示綠色成功訊息
# 參數：$1 - 成功訊息內容
# 返回：0 (總是成功)
# 使用：success_msg "操作完成！"
# ============================================
success_msg() {
    printf "\033[0;32m%s\033[0m\n" "$1" >&2
}

# ============================================
# 警告訊息函數
# 功能：顯示黃色警告訊息
# 參數：$1 - 警告訊息內容
# 返回：0 (總是成功)
# 使用：warning_msg "注意：檔案已存在"
# ============================================
warning_msg() {
    printf "\033[1;33m%s\033[0m\n" "$1" >&2
}

# ============================================
# 資訊訊息函數
# 功能：顯示藍色資訊訊息
# 參數：$1 - 資訊訊息內容
# 返回：0 (總是成功)
# 使用：info_msg "正在執行操作..."
# ============================================
info_msg() {
    printf "\033[0;34m%s\033[0m\n" "$1" >&2
}

# ============================================
# 隨機感謝訊息函數
# 功能：從預定的訊息列表中隨機選擇一個感謝訊息並顯示
# 參數：無
# 返回：0 (總是成功)
# 使用：show_random_thanks  # 在操作完成後顯示感謝
# 行為：
#   - 內建 10 種不同的中文感謝訊息
#   - 使用 $RANDOM 產生隨機數
#   - 以紫色 + 愛心表情符號顯示
# ============================================
show_random_thanks() {
    local messages=(
        "感謝 Jerry 製作此工具，讓 GitHub Flow 更簡單！"
        "感謝 Jerry，他讓 PR 流程變得如此優雅。"
        "感謝 Jerry，這個工具讓團隊協作更順暢。請去打星星 https://github.com/lazyjerry/git-auto-push"
        "感謝 Jerry，他簡化了複雜的 Git 工作流程。甘啊捏？"
        "感謝 Jerry，這些實用工具讓開發者生活更美好，只有我獨自承擔。"
        "感謝 Jerry，雖然生活依然艱難，但至少 Git 不再是問題，最後剩下你是最大的問題。"
        "感謝 Jerry，這工具雖然不能改變世界，但能少掉一些麻煩，多了一些 Bug。"
    )
    
    # 使用當前時間的秒數作為隨機種子
    local random_index=$(( $(date +%s) % ${#messages[@]} ))
    local selected_message="${messages[$random_index]}"
    
    echo >&2
    printf "\033[1;35m💝 %s\033[0m\n" "$selected_message" >&2
}

# ============================================
# 命令執行函數
# 功能：執行系統命令並檢查執行結果，失敗時顯示錯誤並終止
# 參數：$1 - 要執行的命令字串
#      $2 - 可選的自訂錯誤訊息
# 返回：命令成功時返回 0，失敗時終止程式
# 使用：run_command "git status" "無法獲取 Git 狀態"
# 注意：使用 eval 執行命令，需注意命令注入風險
# ============================================
run_command() {
    local cmd="$1"
    local error_msg="$2"
    
    if ! eval "$cmd"; then
        if [ -n "$error_msg" ]; then
            handle_error "$error_msg"
        else
            handle_error "執行命令失敗: $cmd"
        fi
    fi
}

# ============================================
# Git 倉庫檢查函數
# 功能：檢查當前目錄是否為有效的 Git 倉庫
# 參數：無
# 返回：0 - 是 Git 倉庫，1 - 不是 Git 倉庫
# 使用：if check_git_repository; then echo "是 Git 倉庫"; fi
# 實作：使用 git rev-parse --git-dir 命令檢測
# ============================================
check_git_repository() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# ============================================
# GitHub CLI 工具檢查函數
# 功能：檢查 GitHub CLI (gh) 是否安裝並已驗證登入
# 參數：無
# 返回：0 - 已安裝且已登入，1 - 未安裝，2 - 已安裝但未登入
# 使用：
#   case $(check_gh_cli) in
#     0) echo "正常" ;;
#     1) echo "未安裝 gh" ;;
#     2) echo "未登入 gh" ;;
#   esac
# ============================================
check_gh_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        return 1
    fi
    
    # 檢查是否已登入
    if ! gh auth status >/dev/null 2>&1; then
        return 2
    fi
    
    return 0
}

# ============================================
# 當前分支獲取函數
# 功能：獲取 Git 倉庫的當前活躍分支名稱
# 參數：無
# 返回：當前分支名稱（字串）
# 使用：current=$(get_current_branch)
# 行為：
#   - 使用 git branch --show-current 獲取分支名
#   - 自動清理回車符和首尾空白
#   - 失敗時返回空字串
# ============================================
get_current_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    # 清理可能的特殊字符和空白
    echo "$branch" | tr -d '\r\n' | xargs
}

# ============================================
# 主分支智慧檢測函數
# 功能：從配置陣列 DEFAULT_MAIN_BRANCHES 中自動檢測第一個存在的主分支
# 參數：無
# 返回：主分支名稱（字串），找不到時返回空字串
# 使用：main_branch=$(get_main_branch)
# 檢測後備：
#   1. 優先檢查遠端分支 (origin/main, origin/master)
#   2. 備選檢查本地分支 (main, master)
#   3. 按 DEFAULT_MAIN_BRANCHES 陣列順序檢測
# 配置：可修改 DEFAULT_MAIN_BRANCHES 陣列新增更多候選
# ============================================
get_main_branch() {
    local branch_candidate
    local found_branch=""
    
    # 依照配置陣列的順序檢測分支
    for branch_candidate in "${DEFAULT_MAIN_BRANCHES[@]}"; do
        # 優先檢查遠端分支
        if git ls-remote --heads origin "$branch_candidate" 2>/dev/null | grep -q "refs/heads/$branch_candidate"; then
            found_branch="$branch_candidate"
            break
        # 如果遠端檢查失敗，檢查本地分支
        elif git show-ref --verify --quiet "refs/heads/$branch_candidate"; then
            found_branch="$branch_candidate"
            break
        fi
    done
    
    # 如果都沒找到，顯示錯誤訊息並退出程式
    if [ -z "$found_branch" ]; then
        printf "\033[0;31m❌ 錯誤：找不到任何配置的主分支\033[0m\n" >&2
        printf "\033[0;33m📋 配置的主分支候選清單: %s\033[0m\n" "${DEFAULT_MAIN_BRANCHES[*]}" >&2
        printf "\033[0;36m💡 解決方法：\033[0m\n" >&2
        printf "   1. 檢查 Git 倉庫是否已初始化\n" >&2
        printf "   2. 創建其中一個主分支：\n" >&2
        for branch_candidate in "${DEFAULT_MAIN_BRANCHES[@]}"; do
            printf "      \033[0;32mgit checkout -b %s\033[0m\n" "$branch_candidate" >&2
        done
        printf "   3. 或修改腳本頂部的 DEFAULT_MAIN_BRANCHES 陣列\n" >&2
        printf "      \033[0;90m位置: %s (第 78 行)\033[0m\n" "${BASH_SOURCE[0]}" >&2
        exit 1
    fi
    
    # 清理可能的特殊字符和空白
    echo "$found_branch" | tr -d '\r\n' | xargs
}

# 檢查是否在主分支
check_main_branch() {
    local current_branch
    local main_branch
    current_branch=$(get_current_branch)
    main_branch=$(get_main_branch)
    
    if [ "$current_branch" = "$main_branch" ]; then
        return 0
    fi
    return 1
}

# 顯示 loading 動畫
show_loading() {
    local message="$1"
    local timeout="${2:-30}"
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    local start_time
    start_time=$(date +%s)
    
    # 隱藏游標
    printf "\033[?25l" >&2
    
    # 設置信號處理
    trap 'printf "\r\033[K\033[?25h" >&2; return' INT TERM
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        # 顯示旋轉動畫和進度
        printf "\r\033[0;34m%s %s (%d/%d秒)\033[0m" "${spinner:$i:1}" "$message" "$elapsed" "$timeout" >&2
        
        i=$(( (i + 1) % ${#spinner} ))
        sleep 0.1
    done
    
    # 清除 loading 行並顯示游標
    printf "\r\033[K\033[?25h" >&2
    
    # 清理信號處理
    trap - INT TERM
}

# 執行帶有 loading 動畫的命令
run_command_with_loading() {
    local command="$1"
    local loading_message="$2"
    local timeout="$3"
    local temp_file
    temp_file=$(mktemp)
    
    # 設置信號處理函數
    cleanup_and_exit() {
        # 停止 loading 動畫
        if [ -n "$loading_pid" ]; then
            kill "$loading_pid" 2>/dev/null
            wait "$loading_pid" 2>/dev/null
        fi
        
        # 終止命令進程
        if [ -n "$cmd_pid" ]; then
            kill -TERM "$cmd_pid" 2>/dev/null
            sleep 0.5
            kill -KILL "$cmd_pid" 2>/dev/null
            wait "$cmd_pid" 2>/dev/null
        fi
        
        # 清理臨時檔案
        rm -f "$temp_file" "${temp_file}.exit_code"
        
        # 顯示游標並清理終端
        printf "\r\033[K\033[?25h" >&2
        warning_msg "操作已被用戶中斷" >&2
        exit 130  # SIGINT 的標準退出碼
    }
    
    # 設置中斷信號處理
    trap cleanup_and_exit INT TERM
    
    # 在背景啟動 loading 動畫
    show_loading "$loading_message" "$timeout" &
    local loading_pid=$!
    
    # 在背景執行命令，將輸出重定向到臨時檔案
    (
        eval "$command" > "$temp_file" 2>&1
        echo $? > "${temp_file}.exit_code"
    ) &
    
    local cmd_pid=$!
    
    # 等待命令執行完成
    wait $cmd_pid 2>/dev/null
    
    # 停止 loading 動畫
    kill "$loading_pid" 2>/dev/null
    wait "$loading_pid" 2>/dev/null
    
    # 清理終端
    printf "\r\033[K\033[?25h" >&2
    
    # 讀取輸出和退出碼
    local output
    local exit_code=0
    
    if [ -f "$temp_file" ]; then
        output=$(cat "$temp_file" 2>/dev/null)
    fi
    
    if [ -f "${temp_file}.exit_code" ]; then
        exit_code=$(cat "${temp_file}.exit_code" 2>/dev/null | xargs)
        # 驗證退出碼是否為數字
        if ! [[ "$exit_code" =~ ^[0-9]+$ ]]; then
            exit_code=1
        fi
    else
        exit_code=1
    fi
    
    # 清理臨時檔案
    rm -f "$temp_file" "${temp_file}.exit_code"
    
    # 輸出結果
    if [ -n "$output" ]; then
        echo "$output"
    fi
    
    # 確保 exit_code 是整數再返回
    exit_code=$((exit_code + 0))
    return $exit_code
}

# 執行 codex 命令並處理輸出
# 參數：
#   $1 - prompt 提示詞
#   $2 - content 要分析的內容（透過臨時文件傳遞）
#   $3 - timeout 超時時間（可選，預設 60 秒）
run_codex_command() {
    local prompt="$1"
    local content="$2"
    local timeout="${3:-60}"
    
    info_msg "正在調用 codex..." >&2
    
    # 檢查 codex 是否可用
    if ! command -v codex >/dev/null 2>&1; then
        warning_msg "codex 工具未安裝" >&2
        return 1
    fi
    
    # 檢查內容是否為空
    if [ -z "$content" ]; then
        warning_msg "沒有內容可供分析" >&2
        return 1
    fi
    
    # 創建臨時檔案傳遞提示詞和內容
    # 確保使用 UTF-8 編碼以避免編碼轉換問題
    local temp_prompt
    temp_prompt=$(mktemp)
    
    # 使用 printf 確保 UTF-8 編碼，並設置環境變數保證編碼一致
    {
        LC_ALL=zh_TW.UTF-8 printf '%s\n\n%s' "$prompt" "$content"
    } > "$temp_prompt" || {
        rm -f "$temp_prompt"
        warning_msg "寫入臨時檔案失敗" >&2
        return 1
    }
    
    # 驗證臨時檔案是否為有效的 UTF-8
    if ! file "$temp_prompt" | grep -q "UTF-8\|ASCII"; then
        info_msg "⚠️  臨時檔案編碼檢查：$(file -b "$temp_prompt")" >&2
    fi
    
    # 🔍 調試輸出：印出即將傳遞給 codex 的內容
    info_msg "🔍 調試: run_codex_command() - 即將傳遞給 codex 的內容" >&2
    printf "\033[0;90m" >&2
    printf "─────────────────────────────────────────\n" >&2
    printf "📄 文件內容（編碼: UTF-8）:\n" >&2
    printf "─────────────────────────────────────────\n" >&2
    file -b "$temp_prompt" >&2
    printf "\n📊 內容統計:\n" >&2
    printf "   - 總行數: $(wc -l < "$temp_prompt") 行\n" >&2
    printf "   - 總位元組: $(wc -c < "$temp_prompt") 位元組\n" >&2
    printf "   - 檔案大小: $(du -h "$temp_prompt" | cut -f1)\n" >&2
    printf "\n📝 前 500 個位元組內容:\n" >&2
    printf "─────────────────────────────────────────\n" >&2
    head -c 500 "$temp_prompt" | cat -v >&2
    printf "\n─────────────────────────────────────────\033[0m\n" >&2
    echo >&2
    
    # 執行 codex 命令，設定 UTF-8 環境變數
    local output exit_code
    if command -v timeout >/dev/null 2>&1; then
        output=$(LC_ALL=zh_TW.UTF-8 run_command_with_loading "timeout $timeout codex exec < '$temp_prompt'" "正在等待 codex 分析內容" "$timeout")
        exit_code=$?
    else
        output=$(LC_ALL=zh_TW.UTF-8 run_command_with_loading "codex exec < '$temp_prompt'" "正在等待 codex 分析內容" "$timeout")
        exit_code=$?
    fi
    
    # 清理臨時檔案
    rm -f "$temp_prompt"
    
    # 處理執行結果
    case $exit_code in
        0)
            # 成功執行，處理輸出
            if [ -n "$output" ]; then
                local filtered_output
                
                # 方法1：精確提取 "codex" 和 "tokens used" 之間的內容
                filtered_output=$(echo "$output" | \
                    sed -n '/^codex$/,/^tokens used/p' | \
                    sed '1d;$d' | \
                    grep -E ".+" | \
                    xargs)
                
                # 方法2：如果方法1沒有結果，使用備用過濾邏輯
                if [ -z "$filtered_output" ]; then
                    filtered_output=$(echo "$output" | \
                        grep -v -E "^(\[|workdir:|model:|provider:|approval:|sandbox:|reasoning|tokens used:|-------|User instructions:|codex$|^$|OpenAI Codex|effort:|summaries:)" | \
                        grep -E ".+" | \
                        tail -n 1 | \
                        xargs)
                fi
                
                if [ -n "$filtered_output" ] && [ ${#filtered_output} -gt 3 ]; then
                    success_msg "codex 回應完成" >&2
                    echo "$filtered_output"
                    return 0
                fi
            fi
            warning_msg "codex 沒有返回有效內容" >&2
            ;;
        124)
            printf "\033[0;31m❌ codex 執行超時（${timeout}秒）\033[0m\n" >&2
            printf "\033[1;33m💡 建議：檢查網路連接或稍後重試\033[0m\n" >&2
            ;;
        *)
            # 檢查特定錯誤類型
            if [[ "$output" == *"401 Unauthorized"* ]] || [[ "$output" == *"token_expired"* ]]; then
                printf "\033[0;31m❌ codex 認證錯誤\033[0m\n" >&2
                printf "\033[1;33m💡 請執行：codex auth login\033[0m\n" >&2
            elif [[ "$output" == *"stream error"* ]] || [[ "$output" == *"connection"* ]] || [[ "$output" == *"network"* ]]; then
                printf "\033[0;31m❌ codex 網路錯誤\033[0m\n" >&2
                printf "\033[1;33m💡 請檢查網路連接\033[0m\n" >&2
            else
                warning_msg "codex 執行失敗（退出碼: $exit_code）" >&2
            fi
            ;;
    esac
    
    return 1
}

# 執行基於 stdin 的 AI 命令
# 參數：
#   $1 - tool_name AI 工具名稱 (gemini/claude)
#   $2 - prompt 提示詞
#   $3 - content 要分析的內容（透過臨時文件傳遞）
#   $4 - timeout 超時時間（可選，預設 45 秒）
run_stdin_ai_command() {
    local tool_name="$1"
    local prompt="$2"
    local content="$3"
    local timeout="${4:-45}"
    
    info_msg "正在調用 $tool_name..." >&2
    
    # 首先檢查工具是否可用
    if ! command -v "$tool_name" >/dev/null 2>&1; then
        warning_msg "$tool_name 工具未安裝" >&2
        return 1
    fi
    
    # 檢查內容是否為空
    if [ -z "$content" ]; then
        warning_msg "沒有內容可供 $tool_name 分析" >&2
        return 1
    fi
    
    local output
    local exit_code
    
    # 創建臨時檔案存儲內容
    local temp_content
    temp_content=$(mktemp)
    echo "$content" > "$temp_content"
    
    # 使用帶 loading 的命令執行
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "timeout $timeout $tool_name -p '$prompt' < '$temp_content' 2>/dev/null" "正在等待 $tool_name 回應" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "$tool_name -p '$prompt' < '$temp_content' 2>/dev/null" "正在等待 $tool_name 回應" "$timeout")
        exit_code=$?
    fi
    
    # 清理臨時檔案
    rm -f "$temp_content"
    
    if [ $exit_code -eq 124 ]; then
        printf "\033[0;31m❌ %s 執行超時（%d秒）\033[0m\n" "$tool_name" "$timeout" >&2
        
        # 顯示調試信息
        printf "\n\033[0;90m🔍 調試信息（%s 超時錯誤）:\033[0m\n" "$tool_name" >&2
        printf "\033[0;90m執行的指令: %s -p '%s' < [content_file]\033[0m\n" "$tool_name" "$prompt" >&2
        printf "\033[0;90m超時設定: %d 秒\033[0m\n" "$timeout" >&2
        printf "\033[0;90m內容大小: %d 行\033[0m\n" "$(echo "$content" | wc -l)" >&2
        if [ -n "$output" ]; then
            printf "\033[0;90m部分輸出內容:\033[0m\n" >&2
            echo "$output" | head -n 5 | sed 's/^/  /' >&2
        else
            printf "\033[0;90m輸出內容: (無)\033[0m\n" >&2
        fi
        printf "\n" >&2
        return 1
    elif [ $exit_code -ne 0 ]; then
        printf "\033[0;31m❌ %s 執行失敗（退出碼: %d）\033[0m\n" "$tool_name" "$exit_code" >&2
        
        # 顯示調試信息
        printf "\n\033[0;90m🔍 調試信息（%s 執行失敗）:\033[0m\n" "$tool_name" >&2
        printf "\033[0;90m執行的指令: %s -p '%s' < [content_file]\033[0m\n" "$tool_name" "$prompt" >&2
        printf "\033[0;90m退出碼: %d\033[0m\n" "$exit_code" >&2
        if [ -n "$output" ]; then
            printf "\033[0;90m完整輸出內容:\033[0m\n" >&2
            echo "$output" | sed 's/^/  /' >&2
        else
            printf "\033[0;90m輸出內容: (無)\033[0m\n" >&2
        fi
        printf "\n" >&2
        return 1
    fi
    
    if [ -z "$output" ]; then
        printf "\033[0;31m❌ %s 沒有返回內容\033[0m\n" "$tool_name" >&2
        
        # 顯示調試信息
        printf "\n\033[0;90m🔍 調試信息（%s 無輸出）:\033[0m\n" "$tool_name" >&2
        printf "\033[0;90m執行的指令: %s -p '%s' < [content_file]\033[0m\n" "$tool_name" "$prompt" >&2
        printf "\033[0;90m退出碼: %d\033[0m\n" "$exit_code" >&2
        printf "\033[0;90m內容預覽:\033[0m\n" >&2
        echo "$content" | head -n 5 | sed 's/^/  /' >&2
        printf "\n" >&2
        return 1
    fi
    
    success_msg "$tool_name 回應完成" >&2
    echo "$output"
    return 0
}

# 清理 AI 生成的訊息
clean_ai_message() {
    local message="$1"
    
    # 顯示原始訊息
    printf "\033[0;90m🔍 AI 原始輸出: '%s'\033[0m\n" "$message" >&2
    
    # 最簡化處理：只移除前後空白，保留完整內容
    message=$(echo "$message" | xargs)
    
    # 顯示清理結果
    printf "\033[0;90m🧹 清理後輸出: '%s'\033[0m\n" "$message" >&2
    
    echo "$message"
}

# 驗證和標準化 issue key 的函數
validate_and_standardize_issue_key() {
    local input="$1"
    
    # 移除前後空白
    input=$(echo "$input" | xargs)
    
    # 轉換為大寫
    input=$(echo "$input" | tr '[:lower:]' '[:upper:]')
    
    # 檢查格式：只允許英文字母、數字和連字號/底線
    if [[ ! "$input" =~ ^[A-Z0-9_-]+$ ]]; then
        return 1  # 格式不正確
    fi
    
    # 檢查是否符合 issue key 的基本模式（字母開頭）
    if [[ ! "$input" =~ ^[A-Z] ]]; then
        return 2  # 必須以字母開頭
    fi
    
    # 建議的格式：至少包含一個連字號或底線分隔的數字部分
    if [[ "$input" =~ ^[A-Z][A-Z0-9]*[-_][0-9]+$ ]]; then
        echo "$input"
        return 0  # 標準格式
    elif [[ "$input" =~ ^[A-Z][A-Z0-9_-]*$ ]]; then
        echo "$input"
        return 3  # 可接受但不是標準格式
    else
        return 1  # 格式不正確
    fi
}

# 格式化 PR 標題和內容的函數，提升可讀性
format_pr_content() {
    local title="$1"
    local body="$2"
    
    # 格式化標題：移除多餘空白，確保首字母大寫
    title=$(echo "$title" | xargs)
    # 只將第一個字母轉大寫，而不是整個首字符
    title=$(echo "${title:0:1}" | tr '[:lower:]' '[:upper:]')$(echo "${title:1}")
    
    # 格式化內容：處理轉義的換行符
    body=$(echo "$body" | sed 's/\\n/\n/g')
    
    # 如果已經包含 Markdown 標題，保持原格式
    if [[ "$body" =~ ^#.*$ ]]; then
        # 已有 Markdown 格式，進行基本清理
        body=$(echo "$body" | sed 's/\n\n\n*/\n\n/g')
    else
        # 處理中文句號分隔的內容
        if [[ "$body" == *"。"* ]] && [[ ${#body} -gt 80 ]]; then
            # 在句號後添加換行，創建段落
            body=$(echo "$body" | sed 's/。/。\n\n/g' | sed '/^[[:space:]]*$/d')
            body=$(echo "$body" | sed 's/\n\n\n*/\n\n/g')
        fi
        
        # 添加簡化的 PR 結構
        if [ ${#body} -lt 30 ]; then
            body="## 📝 功能變更
$body

## 🔧 技術實作
- [ ] 功能測試通過"
        else
            # 為較長內容添加簡化結構
            if [[ ! "$body" =~ (功能變更|技術實作) ]]; then
                body="## 📝 功能變更

$body

## 🔧 技術實作
- 實作方式：[補充技術細節]"
            else
                # 已包含結構化內容，僅添加標題
                body="## 📝 功能變更

$body"
            fi
        fi
    fi
    
    # 返回格式化後的內容，使用特殊分隔符
    echo "${title}|||${body}"
}

# ============================================
# 分支名稱清理與驗證函數
# 功能：清理 AI 生成的分支名稱，確保符合 Git 分支命名規範
# 參數：$1 - 待清理的分支名稱（通常來自 AI 輸出）
# 返回：清理後的分支名稱，失敗時返回空字串並 exit code 1
# 使用：clean_name=$(clean_branch_name "$ai_generated_name")
# 清理規則：
#   1. 移除 AI 輸出的描述性前綴（如「分支名稱：」）
#   2. 確保以 feature/ 開頭的格式
#   3. 移除 Git 不允許的特殊字符
#   4. 處理多餘的連字號和點號
#   5. 驗證最終結果的有效性
# 容錯機制：如果 AI 輸出不包含有效分支名，返回失敗讓系統使用後備方案
# ============================================
clean_branch_name() {
    local branch_name="$1"
    
    # 先進行基本的 AI 輸出清理
    branch_name=$(clean_ai_message "$branch_name")
    
    # 移除分支名稱中的描述性前綴
    branch_name=$(echo "$branch_name" | sed 's/^分支名稱[：:][[:space:]]*//')
    branch_name=$(echo "$branch_name" | sed 's/^建議[的]*分支名稱[：:][[:space:]]*//')
    branch_name=$(echo "$branch_name" | sed 's/^功能描述[：:][[:space:]]*//')
    
    # 如果不是以 feature/ 開頭，檢查是否包含有效的分支名稱
    if [[ ! "$branch_name" =~ ^feature/ ]]; then
        # 嘗試提取看起來像分支名稱的部分
        local extracted
        extracted=$(echo "$branch_name" | grep -o 'feature/[a-zA-Z0-9][a-zA-Z0-9._/-]*' | head -n 1)
        if [ -n "$extracted" ]; then
            branch_name="$extracted"
        else
            # 如果沒有找到標準格式，返回空值讓系統使用後備方案
            echo ""
            return 1
        fi
    fi
    
    # 清理分支名稱中的無效字符
    branch_name=$(echo "$branch_name" | sed 's/[^a-zA-Z0-9._/-]//g')
    
    # 移除多餘的連字號和點
    branch_name=$(echo "$branch_name" | sed 's/--*/-/g' | sed 's/\.\.*/\./g')
    
    # 移除開頭和結尾的連字號或點
    branch_name=$(echo "$branch_name" | sed 's/^[-\.]*//; s/[-\.]*$//')
    
    # 標準化為小寫以符合 Git 慣例
    branch_name=$(echo "$branch_name" | tr '[:upper:]' '[:lower:]')
    
    # 驗證分支名稱是否符合 Git 規範
    if [[ "$branch_name" =~ ^feature/[a-zA-Z0-9][a-zA-Z0-9._/-]*[a-zA-Z0-9]$ ]] && [ ${#branch_name} -le 50 ]; then
        echo "$branch_name"
        return 0
    else
        # 分支名稱無效
        echo ""
        return 1
    fi
}

# 使用 AI 生成分支名稱
generate_branch_name_with_ai() {
    local issue_key="$1"
    local description_hint="$2"
    
    local prompt
    prompt=$(generate_ai_branch_prompt "$issue_key" "$description_hint")
    
    # 準備分支生成的上下文內容
    local content="Issue Key: ${issue_key}\nDescription: ${description_hint}"
    
    info_msg "🤖 使用 AI 生成分支名稱..." >&2
    
    # 嘗試使用不同的 AI 工具
    for tool in "${AI_TOOLS[@]}"; do
        printf "\033[1;34m🤖 嘗試使用 AI 工具: %s\033[0m\n" "$tool" >&2
        
        local result
        case "$tool" in
            "codex")
                # 為分支名稱生成使用較短的超時時間（30秒）
                if result=$(run_codex_command "$prompt" "$content" 30); then
                    result=$(clean_branch_name "$result")
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成分支名稱成功: $result" >&2
                        echo "$result"
                        return 0
                    fi
                fi
                ;;
            "gemini"|"claude")
                # 為分支名稱生成使用較短的超時時間（30秒）
                if result=$(run_stdin_ai_command "$tool" "$prompt" "$content" 30); then
                    result=$(clean_branch_name "$result")
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成分支名稱成功: $result" >&2
                        echo "$result"
                        return 0
                    fi
                fi
                ;;
        esac
        
        warning_msg "⚠️  $tool 無法生成分支名稱，嘗試下一個工具..." >&2
    done
    
    warning_msg "所有 AI 工具都無法生成分支名稱" >&2
    return 1
}

# 使用 AI 生成 PR 標題和內容
generate_pr_content_with_ai() {
    local issue_key="$1"
    local branch_name="$2"
    
    # 獲取分支的 commit 歷史（完整訊息）
    local commits
    local main_branch
    main_branch=$(get_main_branch)
    
    # 獲取完整的 commit 訊息（不只是 oneline）
    # 使用 LC_ALL=zh_TW.UTF-8 確保 git 輸出為 UTF-8 編碼
    commits=$(LC_ALL=zh_TW.UTF-8 git log --pretty=format:"- %s" "$main_branch".."$branch_name" 2>/dev/null)
    
    if [ -z "$commits" ]; then
        warning_msg "分支 '$branch_name' 沒有新的 commit" >&2
        return 1
    fi
    
    # 獲取檔案變更摘要（僅用於參考）
    local file_changes
    # 使用 LC_ALL=zh_TW.UTF-8 確保 git 輸出為 UTF-8 編碼
    file_changes=$(LC_ALL=zh_TW.UTF-8 git diff --name-status "$main_branch".."$branch_name" 2>/dev/null | head -20)
    
    # 計算 commit 數量
    local commit_count
    commit_count=$(echo "$commits" | wc -l | xargs)
    
    info_msg "📊 分析分支資訊：" >&2
    info_msg "   - Issue Key: $issue_key" >&2
    info_msg "   - 分支名稱: $branch_name" >&2
    info_msg "   - Commit 數量: $commit_count" >&2
    info_msg "   - 檔案變更: $(echo "$file_changes" | wc -l | xargs) 個檔案" >&2
    echo >&2
    
    # 使用提示詞模板生成 prompt
    local prompt
    prompt=$(generate_ai_pr_prompt "$issue_key" "$branch_name" "$commits" "$file_changes")
    
    info_msg "🤖 使用 AI 根據 commit 訊息生成 PR 內容..." >&2
    
    # 創建臨時檔案存儲 commit 訊息和檔案變更
    local temp_content
    temp_content=$(mktemp)
    {
        LC_ALL=zh_TW.UTF-8 printf "Issue Key: %s\n" "$issue_key"
        LC_ALL=zh_TW.UTF-8 printf "分支名稱: %s\n" "$branch_name"
        LC_ALL=zh_TW.UTF-8 printf "Commit 數量: %s\n\n" "$commit_count"
        LC_ALL=zh_TW.UTF-8 printf "Commit 訊息摘要:\n"
        LC_ALL=zh_TW.UTF-8 printf "%s" "$commits"
        LC_ALL=zh_TW.UTF-8 printf "\n\n檔案變更摘要:\n"
        LC_ALL=zh_TW.UTF-8 printf "%s" "$file_changes"
        LC_ALL=zh_TW.UTF-8 printf "\n"
    } > "$temp_content"
    
    # 嘗試使用不同的 AI 工具
    for tool in "${AI_TOOLS[@]}"; do
        printf "\033[1;34m🤖 嘗試使用 AI 工具: %s\033[0m\n" "$tool" >&2
        
        local result
        local output
        local exit_code
        local timeout=60
        
        case "$tool" in
            "codex")
                # 檢查 codex 是否可用
                if ! command -v codex >/dev/null 2>&1; then
                    warning_msg "codex 工具未安裝" >&2
                    continue
                fi
                
                # 創建包含 prompt 和內容的臨時文件
                local temp_prompt
                temp_prompt=$(mktemp)
                
                # 確保使用 UTF-8 編碼寫入
                {
                    LC_ALL=zh_TW.UTF-8 printf "%s\n\n" "$prompt"
                    cat "$temp_content"
                } > "$temp_prompt" 2>/dev/null || {
                    warning_msg "無法寫入臨時文件" >&2
                    rm -f "$temp_prompt"
                    continue
                }
                
                # 🔍 調試輸出：印出即將傳遞給 codex 的內容
                info_msg "🔍 調試: 即將傳遞給 codex 的內容" >&2
                printf "\033[0;90m" >&2
                printf "─────────────────────────────────────────\n" >&2
                printf "📄 文件內容（編碼: UTF-8）:\n" >&2
                printf "─────────────────────────────────────────\n" >&2
                file -b "$temp_prompt" >&2
                printf "\n📊 內容統計:\n" >&2
                printf "   - 總行數: $(wc -l < "$temp_prompt") 行\n" >&2
                printf "   - 總位元組: $(wc -c < "$temp_prompt") 位元組\n" >&2
                printf "   - 檔案大小: $(du -h "$temp_prompt" | cut -f1)\n" >&2
                printf "\n📝 前 500 個位元組內容:\n" >&2
                printf "─────────────────────────────────────────\n" >&2
                head -c 500 "$temp_prompt" | cat -v >&2
                printf "\n─────────────────────────────────────────\033[0m\n" >&2
                echo >&2
                
                # 執行 codex（確保 UTF-8 編碼）
                if command -v timeout >/dev/null 2>&1; then
                    output=$(LC_ALL=zh_TW.UTF-8 run_command_with_loading "timeout $timeout codex exec < '$temp_prompt'" "正在等待 codex 分析 commit 訊息" "$timeout")
                else
                    output=$(LC_ALL=zh_TW.UTF-8 run_command_with_loading "codex exec < '$temp_prompt'" "正在等待 codex 分析 commit 訊息" "$timeout")
                fi
                exit_code=$?
                
                # 確保 exit_code 是有效的整數
                if ! [[ "$exit_code" =~ ^[0-9]+$ ]]; then
                    exit_code=1
                fi
                
                rm -f "$temp_prompt"
                
                if [ $exit_code -eq 0 ] && [ -n "$output" ]; then
                    # 清理 codex 輸出
                    result=$(echo "$output" | \
                        sed -n '/^codex$/,/^tokens used/p' | \
                        sed '1d;$d' | \
                        grep -E ".+" | \
                        xargs)
                    
                    if [ -z "$result" ]; then
                        result=$(echo "$output" | \
                            grep -v -E "^(\[|workdir:|model:|provider:|approval:|sandbox:|reasoning|tokens used:|-------|User instructions:|codex$|^$|OpenAI Codex|effort:|summaries:)" | \
                            grep -E ".+" | \
                            tail -n 1 | \
                            xargs)
                    fi
                    
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成 PR 內容成功" >&2
                        rm -f "$temp_content"
                        echo "$result"
                        return 0
                    else
                        warning_msg "codex 輸出解析後為空（退出碼: $exit_code，輸出長度: ${#output}）" >&2
                    fi
                else
                    if [ $exit_code -ne 0 ]; then
                        warning_msg "codex 執行失敗（退出碼: $exit_code）" >&2
                        if [ -n "$output" ]; then
                            printf "\033[0;90m💬 codex 輸出：\033[0m\n" >&2
                            echo "$output" | sed 's/^/  /' >&2
                        fi
                    elif [ -z "$output" ]; then
                        warning_msg "codex 沒有產生輸出" >&2
                    fi
                fi
                ;;
            "gemini"|"claude")
                # 檢查工具是否可用
                if ! command -v "$tool" >/dev/null 2>&1; then
                    warning_msg "$tool 工具未安裝" >&2
                    continue
                fi
                
                # 使用帶 loading 的命令執行
                if command -v timeout >/dev/null 2>&1; then
                    output=$(run_command_with_loading "timeout $timeout $tool -p '$prompt' < '$temp_content' 2>/dev/null" "正在等待 $tool 分析 commit 訊息" "$timeout")
                else
                    output=$(run_command_with_loading "$tool -p '$prompt' < '$temp_content' 2>/dev/null" "正在等待 $tool 分析 commit 訊息" "$timeout")
                fi
                exit_code=$?
                
                # 確保 exit_code 是有效的整數
                if ! [[ "$exit_code" =~ ^[0-9]+$ ]]; then
                    exit_code=1
                fi
                
                if [ $exit_code -eq 0 ] && [ -n "$output" ]; then
                    success_msg "✅ $tool 生成 PR 內容成功" >&2
                    rm -f "$temp_content"
                    echo "$output"
                    return 0
                else
                    if [ $exit_code -eq 124 ]; then
                        warning_msg "$tool 執行超時（${timeout}秒）" >&2
                        if [ -n "$output" ]; then
                            printf "\033[0;90m💬 $tool 部分輸出：\033[0m\n" >&2
                            echo "$output" | head -n 10 | sed 's/^/  /' >&2
                        fi
                    elif [ $exit_code -ne 0 ]; then
                        warning_msg "$tool 執行失敗（退出碼: $exit_code）" >&2
                        if [ -n "$output" ]; then
                            printf "\033[0;90m💬 $tool 輸出：\033[0m\n" >&2
                            echo "$output" | sed 's/^/  /' >&2
                        fi
                    elif [ -z "$output" ]; then
                        warning_msg "$tool 沒有產生輸出" >&2
                    fi
                fi
                ;;
        esac
        
        warning_msg "⚠️  $tool 無法生成 PR 內容，嘗試下一個工具..." >&2
    done
    
    # 清理臨時文件
    rm -f "$temp_content"
    
    warning_msg "所有 AI 工具都無法生成 PR 內容" >&2
    return 1
}

# 配置變數（無預設選項，必須選擇）

# 顯示操作選單
show_operation_menu() {
    local main_branch
    main_branch=$(get_main_branch)
    
    echo >&2
    echo "==================================================" >&2
    info_msg "請選擇要執行的 GitHub Flow PR 操作:" >&2
    printf "\033[0;36m📋 偵測到的主分支: %s\033[0m\n" "$main_branch" >&2
    
    # 顯示當前分支資訊
    local current_branch
    current_branch=$(get_current_branch)
    if [ -n "$current_branch" ]; then
        printf "\033[0;35m🌿 當前所在分支: %s\033[0m\n" "$current_branch" >&2
    else
        printf "\033[0;31m⚠️  無法偵測當前分支\033[0m\n" >&2
    fi
    echo "==================================================" >&2
    printf "\033[1;33m1.\033[0m 🌿 建立功能分支\n" >&2
    printf "\033[1;32m2.\033[0m 🔄 建立 Pull Request\n" >&2
    printf "\033[1;31m3.\033[0m ❌ 撤銷當前 PR\n" >&2
    printf "\033[1;35m4.\033[0m 👑 審查與合併 PR (專案擁有者)\n" >&2
    printf "\033[1;36m5.\033[0m 🗑️ 刪除分支\n" >&2
    echo "==================================================" >&2
    printf "請輸入選項 [1-5]: " >&2
}

# 獲取用戶選擇的操作
get_operation_choice() {
    while true; do
        show_operation_menu
        read -r choice
        choice=$(echo "$choice" | xargs)  # 去除前後空白
        
        # 如果用戶直接按 Enter，要求重新輸入
        if [ -z "$choice" ]; then
            warning_msg "請選擇一個選項，不能為空" >&2
            continue
        fi
        
        # 驗證輸入是否有效
        case "$choice" in
            1)
                info_msg "✅ 已選擇：建立功能分支" >&2
                echo "$choice"
                return 0
                ;;
            2)
                info_msg "✅ 已選擇：建立 Pull Request" >&2
                echo "$choice"
                return 0
                ;;
            3)
                info_msg "✅ 已選擇：撤銷當前 PR" >&2
                echo "$choice"
                return 0
                ;;
            4)
                info_msg "✅ 已選擇：審查與合併 PR (專案擁有者)" >&2
                echo "$choice"
                return 0
                ;;
            5)
                info_msg "✅ 已選擇：刪除分支" >&2
                echo "$choice"
                return 0
                ;;
            *)
                warning_msg "無效選項：$choice，請輸入 1、2、3、4 或 5" >&2
                echo >&2
                ;;
        esac
    done
}

# ============================================
# 主函數 - GitHub Flow PR 自動化流程完整執行引擎
# 功能：統一入口，處理命令行參數、環境檢查、信號處理和流程調度
# 參數：$1 - 可選的命令行參數（--auto 或 -a，已廢棄但向下相容）
# 返回：根據具體操作結果
# 
# 執行流程：
#   1. 全域信號處理設置（Ctrl+C 中斷處理）
#   2. 命令行參數處理和相容性檢查  
#   3. 環境驗證（Git 倉庫、GitHub CLI、分支檢查）
#   4. 互動式選單系統啟動
#   5. 根據用戶選擇調度對應的執行函數
# 
# 安全機制：
#   - 全域 trap 處理中斷信號
#   - 多層環境檢查和錯誤提示
#   - 統一的錯誤處理和清理機制
# 
# 支援操作：
#   1. 建立功能分支 - execute_create_branch()
#   2. 建立 Pull Request - execute_create_pr()  
#   3. 撤銷當前 PR - execute_cancel_pr()
#   4. 審查與合併 PR - execute_review_and_merge()
#   5. 刪除分支 - execute_delete_branch()
# ============================================
main() {
    # 設置全局信號處理
    global_cleanup() {
        printf "\r\033[K\033[?25h" >&2  # 清理終端並顯示游標
        warning_msg "程序被用戶中斷，正在清理..." >&2
        exit 130  # SIGINT 的標準退出碼
    }
    
    # 設置中斷信號處理
    trap global_cleanup INT TERM

    warning_msg "使用前請確認 git 指令、gh CLI 與 AI CLI 工具能夠在您的命令提示視窗中執行。" >&2
    
    # 檢查命令行參數（移除自動模式支援）
    if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
        warning_msg "⚠️  全自動模式已移除，請使用互動式選單操作" >&2
        echo >&2
    fi
    
    # 顯示工具標題
    info_msg "Git 自動建立 Pull Request 工具（GitHub Flow）"
    echo "=================================================="
    
    # 步驟 1: 檢查是否為 Git 倉庫
    if ! check_git_repository; then
        handle_error "當前目錄不是 Git 倉庫！請在 Git 倉庫目錄中執行此腳本。"
    fi
    
    # 步驟 2: 檢查 gh CLI 工具
    local gh_status
    gh_status=$(check_gh_cli; echo $?)
    
    case "$gh_status" in
        1)
            handle_error "未安裝 gh CLI 工具！請執行：brew install gh"
            ;;
        2)
            handle_error "gh CLI 未登入！請執行：gh auth login"
            ;;
        0)
            success_msg "✅ gh CLI 已就緒"
            ;;
    esac
    
    # 獲取用戶選擇並執行
    local choice
    choice=$(get_operation_choice)
    
    echo >&2
    info_msg "🚀 執行 GitHub Flow PR 操作..."
    
    case "$choice" in
        1)
            execute_create_branch
            ;;
        2)
            execute_create_pr
            ;;
        3)
            execute_cancel_pr
            ;;
        4)
            execute_review_and_merge
            ;;
        5)
            execute_delete_branch
            ;;
    esac
    
    show_random_thanks
}

# 建立功能分支
execute_create_branch() {
    info_msg "🌿 建立功能分支流程..."
    
    # 確保在主分支 - 先獲取所有需要的變數
    local main_branch
    local current_branch
    main_branch=$(get_main_branch)
    current_branch=$(get_current_branch)
    
    # 確保變數內容乾淨，移除可能的特殊字符
    current_branch=$(echo "$current_branch" | tr -d '\r\n' | xargs)
    main_branch=$(echo "$main_branch" | tr -d '\r\n' | xargs)
    
    # 顯示當前分支狀態
    echo >&2
    # 顯示目前分支狀態資訊，使用彩色輸出提升可讀性
    printf "\033[0;35m🌿 當前分支: %s\033[0m\n" "$current_branch" >&2
    printf "\033[0;36m📋 主分支: %s\033[0m\n" "$main_branch" >&2
    echo >&2
    
    # 檢查是否在主分支上，如果不在主分支則需要切換
    if ! check_main_branch; then
        # 提示使用者目前不在主分支，詢問是否要切換
        printf "\033[1;33m當前不在主分支（當前: %s，主分支: %s）\033[0m\n" "$current_branch" "$main_branch" >&2
        printf "是否切換到 %s 分支？[Y/n]: " "$main_branch" >&2
        read -r switch_confirm
        # 標準化使用者輸入（移除空白、轉換為小寫）
        switch_confirm=$(echo "$switch_confirm" | xargs | tr '[:upper:]' '[:lower:]')
        
        # 如果使用者同意切換（空輸入或 y/yes/是/確定）
        if [[ -z "$switch_confirm" ]] || [[ "$switch_confirm" =~ ^(y|yes|是|確定)$ ]]; then
            info_msg "切換到 $main_branch 分支並更新..."
            # 切換到主分支
            run_command "git checkout $main_branch" "切換到 $main_branch 分支失敗"
            # 使用 fast-forward only 模式更新主分支，確保不會產生合併提交
            run_command "git pull --ff-only origin $main_branch" "更新 $main_branch 分支失敗"
        else
            # 使用者拒絕切換，取消操作
            warning_msg "已取消操作"
            return 1
        fi
    else
        # 已在主分支上，直接更新
        info_msg "更新 $main_branch 分支..."
        # 使用 fast-forward only 模式確保主分支更新不會產生衝突
        run_command "git pull --ff-only origin $main_branch" "更新 $main_branch 分支失敗"
    fi
    
    # 獲取和驗證 issue key
    local issue_key=""
    while [ -z "$issue_key" ]; do
        printf "\n請輸入 issue key (例: ISSUE-123, JIRA-456, PROJ_001): " >&2
        read -r user_input
        user_input=$(echo "$user_input" | xargs)
        
        if [ -z "$user_input" ]; then
            warning_msg "⚠️  Issue key 不能為空" >&2
            continue
        fi
        
        # 驗證和標準化 issue key
        local validated_key
        local validation_result
        validated_key=$(validate_and_standardize_issue_key "$user_input")
        validation_result=$?
        
        case $validation_result in
            0)
                issue_key="$validated_key"
                info_msg "✅ 使用標準格式 issue key: $issue_key" >&2
                ;;
            1)
                warning_msg "❌ Issue key 格式不正確！只能包含英文字母、數字、連字號(-)和底線(_)" >&2
                warning_msg "   範例：ISSUE-123, JIRA_456, PROJ-001" >&2
                ;;
            2)
                warning_msg "❌ Issue key 必須以英文字母開頭" >&2
                warning_msg "   範例：ISSUE-123, JIRA_456, PROJ-001" >&2
                ;;
            3)
                issue_key="$validated_key"
                warning_msg "⚠️  接受的 issue key: $issue_key" >&2
                warning_msg "   建議格式：{字母}{字母數字}-{數字} 或 {字母}{字母數字}_{數字}" >&2
                ;;
        esac
    done

    # 確保 issue_key 為大寫格式（標準化）
    issue_key=$(echo "$issue_key" | tr '[:lower:]' '[:upper:]')
    info_msg "📝 最終 issue key: $issue_key" >&2
    
    # 獲取功能描述
    printf "請輸入功能簡短描述 (例: add user authentication): " >&2
    read -r description
    description=$(echo "$description" | xargs)
    
    # 生成分支名稱（可選擇使用 AI）
    local branch_name
    printf "\n是否使用 AI 自動生成分支名稱？[Y/n]: " >&2
    read -r use_ai
    use_ai=$(echo "$use_ai" | xargs | tr '[:upper:]' '[:lower:]')
    
    if [[ -z "$use_ai" ]] || [[ "$use_ai" =~ ^(y|yes|是|確定)$ ]]; then
        if branch_name=$(generate_branch_name_with_ai "$issue_key" "$description"); then
            info_msg "AI 生成的分支名稱: $branch_name"
            printf "是否使用此分支名稱？[Y/n]: " >&2
            read -r confirm_branch
            confirm_branch=$(echo "$confirm_branch" | xargs | tr '[:upper:]' '[:lower:]')
            
            if [[ -n "$confirm_branch" ]] && [[ ! "$confirm_branch" =~ ^(y|yes|是|確定)$ ]]; then
                branch_name=""
            fi
        else
            warning_msg "AI 生成分支名稱失敗，將使用建議的名稱"
        fi
    fi
    
    # 如果 AI 生成失敗或用戶不採用，手動輸入
    if [ -z "$branch_name" ]; then
        if [ -n "$description" ]; then
            # 自動生成建議的分支名稱
            local suggested_branch
            suggested_branch="feature/${issue_key}-$(echo "$description" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')"
            printf "建議的分支名稱: %s\n" "$suggested_branch" >&2
            printf "請輸入分支名稱 (英文。直接按 Enter 使用建議): " >&2
            read -r branch_input
            branch_input=$(echo "$branch_input" | xargs)
            
            if [ -z "$branch_input" ]; then
                branch_name="$suggested_branch"
            else
                branch_name="$branch_input"
            fi
        else
            printf "請輸入完整分支名稱 (格式: feature/%s-description): " "$issue_key" >&2
            read -r branch_name
            branch_name=$(echo "$branch_name" | xargs)
        fi
    fi
    
    if [ -z "$branch_name" ]; then
        handle_error "分支名稱不能為空"
    fi
    
    # 檢查分支是否已存在
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        warning_msg "分支 '$branch_name' 已存在"
        printf "是否切換到現有分支？[Y/n]: " >&2
        read -r switch_existing
        switch_existing=$(echo "$switch_existing" | xargs | tr '[:upper:]' '[:lower:]')
        
        if [[ -z "$switch_existing" ]] || [[ "$switch_existing" =~ ^(y|yes|是|確定)$ ]]; then
            run_command "git checkout '$branch_name'" "切換到分支失敗"
            success_msg "✅ 已切換到現有分支: $branch_name"
        else
            warning_msg "已取消操作"
            return 1
        fi
    else
        
        # 標準化分支名稱：轉換為小寫以符合 Git 慣例
        branch_name=$(echo "$branch_name" | tr '[:upper:]' '[:lower:]')

        # 建立新分支
        info_msg "建立並切換到新分支: $branch_name"
        run_command "git checkout -b '$branch_name'" "建立分支失敗"
        success_msg "✅ 成功建立功能分支: $branch_name"
    fi
    
    # 提示開發流程
    echo >&2
    info_msg "📝 接下來您可以："
    printf "   1. 在 VS Code 中開始開發: \033[0;36mcode .\033[0m\n" >&2
    printf "   2. 執行測試: \033[0;36mnpm test\033[0m 或 \033[0;36mphp artisan test\033[0m\n" >&2
    printf "   3. 完成開發後運行: \033[0;36m./git-auto-pr.sh\033[0m (選擇選項 2)\n" >&2
    echo >&2
}

# 提交並推送變更
# 函式：execute_commit_and_push
# 功能說明：此函式已移除。請使用 git-auto-push.sh 來提交並推送變更。
# 注意事項：建立 PR 前必須先推送分支變更到遠端。

# 建立 Pull Request
execute_create_pr() {
    info_msg "🔄 建立 Pull Request 流程..."
    
    # 檢查當前分支
    local current_branch
    current_branch=$(get_current_branch)
    
    local main_branch
    main_branch=$(get_main_branch)
    
    # 顯示分支資訊
    echo >&2
    printf "\033[0;35m🌿 當前分支: %s\033[0m\n" "$current_branch" >&2
    printf "\033[0;36m🎯 目標分支: %s\033[0m\n" "$main_branch" >&2
    echo >&2
    
    if [ "$current_branch" = "$main_branch" ]; then
        handle_error "無法從主分支 ($main_branch) 建立 PR"
    fi
    
    # 檢查分支是否已推送
    if ! git ls-remote --heads origin "$current_branch" | grep -q "$current_branch"; then
        handle_error "分支 '$current_branch' 尚未推送到遠端，請先使用 git-auto-push.sh 推送變更"
    fi
    
    # 獲取 issue key（從分支名稱提取或手動輸入）
    local issue_key=""
    local suggested_key=""
    
    # 1. 嘗試從分支名稱中提取 issue key（支援多種格式）
    # 支援的格式：
    # - feature/JIRA-123 或 feature/jira-123
    # - feature/ISSUE-001 或 feature/issue-001  
    # - feature/PROJ-456 或 feature/proj-456
    # - 任何 {字詞}-{數字} 的組合
    
    # 優先匹配 feature/ 後面的格式
    if [[ "$current_branch" =~ feature/([a-zA-Z][a-zA-Z0-9]*-[0-9]+) ]]; then
        suggested_key="${BASH_REMATCH[1]}"
        # 轉換為大寫格式（標準化）
        suggested_key=$(echo "$suggested_key" | tr '[:lower:]' '[:upper:]')
        info_msg "從分支名稱 '$current_branch' 提取到 issue key: $suggested_key"
    else
        # 嘗試匹配分支名稱中任何位置的 {字詞}-{數字} 格式
        if [[ "$current_branch" =~ ([a-zA-Z][a-zA-Z0-9]*-[0-9]+) ]]; then
            suggested_key="${BASH_REMATCH[1]}"
            # 轉換為大寫格式（標準化）
            suggested_key=$(echo "$suggested_key" | tr '[:lower:]' '[:upper:]')
            info_msg "從分支名稱 '$current_branch' 提取到 issue key: $suggested_key"
        else
            # 嘗試更寬鬆的匹配：任何字母開頭後跟連字號和數字
            local possible_keys
            possible_keys=$(echo "$current_branch" | grep -oE '[a-zA-Z][a-zA-Z0-9]*-[0-9]+' | head -1)
            if [ -n "$possible_keys" ]; then
                suggested_key=$(echo "$possible_keys" | tr '[:lower:]' '[:upper:]')
                info_msg "從分支名稱 '$current_branch' 提取到可能的 issue key: $suggested_key"
            fi
        fi
    fi
    
    # 2. 顯示分支名稱作為參考並要求手動輸入
    echo >&2
    info_msg "當前分支名稱: $current_branch"
    if [ -n "$suggested_key" ]; then
        printf "請輸入 issue key (建議: %s): " "$suggested_key" >&2
    else
        printf "請輸入 issue key (例: ISSUE-123, JIRA-456, PROJ-001, TASK-789): " >&2
    fi
    
    # 3. 強制手動輸入，重複提示直到獲得有效輸入
    while [ -z "$issue_key" ]; do
        read -r user_input
        user_input=$(echo "$user_input" | xargs)
        
        if [ -n "$user_input" ]; then
            # 驗證和標準化 issue key
            local validated_key
            local validation_result
            validated_key=$(validate_and_standardize_issue_key "$user_input")
            validation_result=$?
            
            case $validation_result in
                0)
                    issue_key="$validated_key"
                    info_msg "✅ 使用標準格式 issue key: $issue_key"
                    ;;
                1)
                    warning_msg "❌ Issue key 格式不正確！只能包含英文字母、數字、連字號(-)和底線(_)" >&2
                    warning_msg "   範例：ISSUE-123, JIRA_456, PROJ-001" >&2
                    if [ -n "$suggested_key" ]; then
                        printf "請輸入 issue key (建議: %s): " "$suggested_key" >&2
                    else
                        printf "請輸入 issue key (例: ISSUE-123, JIRA_456, PROJ-001): " >&2
                    fi
                    ;;
                2)
                    warning_msg "❌ Issue key 必須以英文字母開頭" >&2
                    warning_msg "   範例：ISSUE-123, JIRA_456, PROJ-001" >&2
                    if [ -n "$suggested_key" ]; then
                        printf "請輸入 issue key (建議: %s): " "$suggested_key" >&2
                    else
                        printf "請輸入 issue key (例: ISSUE-123, JIRA_456, PROJ-001): " >&2
                    fi
                    ;;
                3)
                    issue_key="$validated_key"
                    warning_msg "⚠️  接受的 issue key: $issue_key" >&2
                    warning_msg "   建議格式：{字母}{字母數字}-{數字} 或 {字母}{字母數字}_{數字}" >&2
                    ;;
            esac
        else
            # 強制用戶輸入，不接受空輸入
            warning_msg "⚠️  Issue key 不能為空，請輸入有效的 issue key" >&2
            if [ -n "$suggested_key" ]; then
                printf "請輸入 issue key (建議: %s): " "$suggested_key" >&2
            else
                printf "請輸入 issue key (例: ISSUE-123, JIRA_456, PROJ-001): " >&2
            fi
        fi
    done  
    
    # 生成 PR 標題和內容
    local pr_title
    local pr_body
    
    printf "\n是否使用 AI 自動生成 PR 標題和內容？[Y/n]: " >&2
    read -r use_ai
    use_ai=$(echo "$use_ai" | xargs | tr '[:upper:]' '[:lower:]')
    
    if [[ -z "$use_ai" ]] || [[ "$use_ai" =~ ^(y|yes|是|確定)$ ]]; then
        info_msg "🤖 使用 AI 生成 PR 內容..."
        
        if pr_content=$(generate_pr_content_with_ai "$issue_key" "$current_branch"); then
            # 解析 AI 生成的內容（格式為 "標題|||內容"）
            if [[ "$pr_content" == *"|||"* ]]; then
                # 正確分割標題和內容：標題是第一行 ||| 之前的部分
                pr_title=$(echo "$pr_content" | sed -n '1s/|||.*//p' | xargs)
                # 內容是第一行 ||| 之後的部分，加上其餘行
                if echo "$pr_content" | head -n 1 | grep -q '|||'; then
                    pr_body=$(echo "$pr_content" | sed '1s/^[^|]*|||\s*//')
                else
                    pr_body=$(echo "$pr_content" | sed '1d')
                fi
            else
                pr_title="$pr_content"
                pr_body="Issue: $issue_key\nSummary: Implement feature as described in $issue_key"
            fi
            
            # 應用格式化處理
            local formatted_content
            formatted_content=$(format_pr_content "$pr_title" "$pr_body")
            pr_title=$(echo "$formatted_content" | sed -n '1s/|||.*//p')
            if echo "$formatted_content" | head -n 1 | grep -q '|||'; then
                pr_body=$(echo "$formatted_content" | sed '1s/^[^|]*|||\s*//')
            else
                pr_body=$(echo "$formatted_content" | sed '1d')
            fi
            
            echo >&2
            info_msg "🎯 格式化後的 PR 標題:"
            printf "\033[1;32m   %s\033[0m\n" "$pr_title" >&2
            echo >&2
            info_msg "📝 格式化後的 PR 內容:"
            echo >&2
            printf "%s\n" "$pr_body" | sed 's/^/   /' >&2
            echo >&2
            
            printf "是否使用此 PR 內容？[Y/n]: " >&2
            read -r confirm_pr
            confirm_pr=$(echo "$confirm_pr" | xargs | tr '[:upper:]' '[:lower:]')
            
            if [[ -n "$confirm_pr" ]] && [[ ! "$confirm_pr" =~ ^(y|yes|是|確定)$ ]]; then
                pr_title=""
                pr_body=""
            fi
        else
            warning_msg "AI 生成失敗，將使用手動輸入"
        fi
    fi
    
    # 手動輸入 PR 內容（如果 AI 失敗或用戶不採用）
    if [ -z "$pr_title" ]; then
        printf "請輸入 PR 標題 (建議10-20字簡潔描述): " >&2
        read -r pr_title
        pr_title=$(echo "$pr_title" | xargs)
        
        if [ -z "$pr_title" ]; then
            # 使用預設標題
            pr_title="[$issue_key] 實作功能"
        fi
    fi
    
    if [ -z "$pr_body" ]; then
        echo >&2
        info_msg "💡 建議包含：功能變更、技術實作細節" >&2
        printf "請輸入 PR 描述 (可選，直接按 Enter 跳過): " >&2
        read -r pr_body_input
        if [ -n "$pr_body_input" ]; then
            pr_body="$pr_body_input"
        else
            pr_body="Issue: $issue_key

## 📝 功能變更
根據 $issue_key 實作相關功能

## 🔧 技術實作
- [ ] 功能測試通過"
        fi
    fi
    
    # 對最終的 PR 內容應用格式化處理
    local final_formatted_content
    final_formatted_content=$(format_pr_content "$pr_title" "$pr_body")
    pr_title=$(echo "$final_formatted_content" | sed -n '1s/|||.*//p')
    if echo "$final_formatted_content" | head -n 1 | grep -q '|||'; then
        pr_body=$(echo "$final_formatted_content" | sed '1s/^[^|]*|||\s*//')
    else
        pr_body=$(echo "$final_formatted_content" | sed '1d')
    fi
    
    # 顯示最終格式化的 PR 預覽
    echo >&2
    echo "==================================================" >&2
    info_msg "📋 最終 PR 預覽:" >&2
    echo "==================================================" >&2
    printf "\033[1;36m標題:\033[0m %s\n" "$pr_title" >&2
    echo >&2
    printf "\033[1;36m內容:\033[0m\n" >&2
    printf "%s\n" "$pr_body" | sed 's/^/  /' >&2
    echo "==================================================" >&2
    echo >&2
    
    # 建立 Pull Request
    info_msg "正在建立 Pull Request..."
    
    local main_branch
    main_branch=$(get_main_branch)
    local pr_cmd="gh pr create --base $main_branch --head '$current_branch' --title '$pr_title' --body '$pr_body'"
    
    if run_command "$pr_cmd" "建立 PR 失敗"; then
        success_msg "✅ 成功建立 Pull Request"
        
        # 顯示 PR 資訊
        echo >&2
        info_msg "📋 PR 資訊:"
        gh pr view --web 2>/dev/null || gh pr view
        
        echo >&2
        info_msg "🎯 接下來您可以："
        printf "   1. 查看 PR: \033[0;36mgh pr view --web\033[0m\n" >&2
        printf "   2. 檢查 CI 狀態: \033[0;36mgh pr checks\033[0m\n" >&2
        printf "   3. 添加 reviewer: \033[0;36mgh pr edit --add-reviewer @team/leads\033[0m\n" >&2
        echo >&2
    fi
}

# 撤銷當前 PR
execute_cancel_pr() {
    info_msg "❌ 撤銷當前 PR 流程..."
    
    # 檢查當前分支
    local current_branch
    current_branch=$(get_current_branch)
    
    local main_branch
    main_branch=$(get_main_branch)
    
    # 顯示分支資訊
    echo >&2
    printf "\033[0;35m🌿 當前分支: %s\033[0m\n" "$current_branch" >&2
    printf "\033[0;36m🎯 主分支: %s\033[0m\n" "$main_branch" >&2
    echo >&2
    
    if [ "$current_branch" = "$main_branch" ]; then
        handle_error "無法在主分支 ($main_branch) 上撤銷 PR"
    fi
    
    # 檢查當前分支是否有 PR
    info_msg "🔍 檢查當前分支的 PR 狀態..."
    
    local pr_info
    pr_info=$(gh pr view --json number,state,mergeable,url,title,mergedAt 2>/dev/null)
    
    if [ -z "$pr_info" ]; then
        warning_msg "當前分支 '$current_branch' 沒有找到相關的 PR"
        printf "是否要檢查其他分支的 PR？[y/N]: " >&2
        read -r check_other
        check_other=$(echo "$check_other" | xargs | tr '[:upper:]' '[:lower:]')
        
        if [[ "$check_other" =~ ^(y|yes|是|確定)$ ]]; then
            execute_review_and_merge
        else
            warning_msg "已取消操作"
        fi
        return 1
    fi
    
    # 解析 PR 資訊
    local pr_number
    local pr_state
    local pr_url
    local pr_title
    local merged_at
    
    pr_number=$(echo "$pr_info" | jq -r '.number')
    pr_state=$(echo "$pr_info" | jq -r '.state')
    pr_url=$(echo "$pr_info" | jq -r '.url')
    pr_title=$(echo "$pr_info" | jq -r '.title')
    merged_at=$(echo "$pr_info" | jq -r '.mergedAt')
    
    echo >&2
    success_msg "找到 PR #${pr_number}: $pr_title"
    printf "\033[0;36m🔗 PR 連結: %s\033[0m\n" "$pr_url" >&2
    printf "\033[0;33m📊 PR 狀態: %s\033[0m\n" "$pr_state" >&2
    
    if [ "$pr_state" = "MERGED" ]; then
        handle_merged_pr "$pr_number" "$pr_title" "$merged_at"
    elif [ "$pr_state" = "OPEN" ]; then
        handle_open_pr "$pr_number" "$pr_title" "$pr_url"
    elif [ "$pr_state" = "CLOSED" ]; then
        warning_msg "PR #${pr_number} 已經被關閉"
        printf "PR 狀態: %s\n" "$pr_state" >&2
        printf "是否要重新打開此 PR？[y/N]: " >&2
        read -r reopen_confirm
        reopen_confirm=$(echo "$reopen_confirm" | xargs | tr '[:upper:]' '[:lower:]')
        
        if [[ "$reopen_confirm" =~ ^(y|yes|是|確定)$ ]]; then
            if gh pr reopen "$pr_number"; then
                success_msg "已重新打開 PR #${pr_number}"
            else
                handle_error "無法重新打開 PR #${pr_number}"
            fi
        fi
    else
        warning_msg "未知的 PR 狀態: $pr_state"
    fi
}

# 處理已合併的 PR
handle_merged_pr() {
    local pr_number="$1"
    local pr_title="$2"
    local merged_at="$3"
    
    warning_msg "PR #${pr_number} 已經合併"
    printf "\033[0;33m⏰ 合併時間: %s\033[0m\n" "$merged_at" >&2
    
    # 獲取 PR 合併後的 commit 資訊
    info_msg "🔍 分析 PR 合併後的 commit 變更..."
    
    local merge_commit
    merge_commit=$(gh pr view "$pr_number" --json mergeCommit --jq '.mergeCommit.oid' 2>/dev/null)
    
    if [ -n "$merge_commit" ] && [ "$merge_commit" != "null" ]; then
        printf "\033[0;36m📝 合併 commit: %s\033[0m\n" "$merge_commit" >&2
        
        # 獲取合併後到現在的 commit 數量
        local main_branch
        main_branch=$(get_main_branch)
        
        local commits_after_pr
        commits_after_pr=$(git rev-list --count "$merge_commit..$main_branch" 2>/dev/null || echo "0")
        
        printf "\033[0;33m📊 PR 合併後新增了 %s 個 commit\033[0m\n" "$commits_after_pr" >&2
        
        if [ "$commits_after_pr" -gt 0 ]; then
            echo >&2
            printf "\033[1;33m⚠️  注意: PR 合併後又有 %s 個新的 commit\033[0m\n" "$commits_after_pr" >&2
            printf "執行 revert 會影響到這些新的變更\n" >&2
            echo >&2
            git log --oneline "$merge_commit..$main_branch" >&2
            echo >&2
        fi
    fi
    
    echo >&2
    printf "\033[1;31m是否要 revert 此 PR 的變更？[y/N]: \033[0m" >&2
    read -r revert_confirm
    revert_confirm=$(echo "$revert_confirm" | xargs | tr '[:upper:]' '[:lower:]')
    
    if [[ "$revert_confirm" =~ ^(y|yes|是|確定)$ ]]; then
        if [ -n "$merge_commit" ] && [ "$merge_commit" != "null" ]; then
            info_msg "🔄 執行 revert 操作..."
            if git revert -m 1 "$merge_commit" --no-edit; then
                success_msg "已成功 revert PR #${pr_number} 的變更"
                printf "\033[0;33m⚠️  請檢查 revert 結果並視需要推送變更\033[0m\n" >&2
                printf "推送命令: \033[0;36mgit push origin %s\033[0m\n" "$(get_main_branch)" >&2
            else
                handle_error "revert 操作失敗，請手動處理衝突"
            fi
        else
            handle_error "無法找到 PR 的合併 commit，無法執行 revert"
        fi
    else
        info_msg "已取消 revert 操作"
    fi
}

# 處理開放中的 PR
handle_open_pr() {
    local pr_number="$1"
    local pr_title="$2"
    local pr_url="$3"
    
    warning_msg "PR #${pr_number} 目前狀態為開放中"
    
    echo >&2
    echo "==================================================" >&2
    info_msg "請選擇對開放中 PR 的處理方式:" >&2
    echo "==================================================" >&2
    printf "\033[1;32m1.\033[0m 🚫 關閉 PR（保留分支）\n" >&2
    printf "\033[1;33m2.\033[0m  添加評論後保持開放\n" >&2
    printf "\033[1;36m3.\033[0m ❌ 取消操作\n" >&2
    echo "==================================================" >&2
    printf "請輸入選項 [1-3]: " >&2
    
    local choice
    read -r choice
    choice=$(echo "$choice" | xargs)
    
    case "$choice" in
        1)
            # 關閉 PR（保留分支）
            handle_close_pr_keep_branch "$pr_number"
            ;;
        2)
            # 添加評論
            handle_add_comment "$pr_number"
            ;;
        3)
            # 取消操作
            info_msg "已取消 PR 操作"
            return 0
            ;;
        *)
            warning_msg "無效的選項: $choice"
            # 遞迴調用，重新選擇
            handle_open_pr "$pr_number" "$pr_title" "$pr_url"
            ;;
    esac
}

# 關閉 PR（保留分支）
handle_close_pr_keep_branch() {
    local pr_number="$1"
    
    # 驗證 PR 編號是否有效
    if [ -z "$pr_number" ] || [ "$pr_number" = "null" ]; then
        handle_error "無效的 PR 編號"
        return 1
    fi
    
    printf "請輸入關閉原因 (可選): " >&2
    read -r close_reason
    
    info_msg "🚫 關閉 PR #${pr_number}（保留分支）..."
    
    if [ -n "$close_reason" ]; then
        if gh pr close "$pr_number" --comment "$close_reason"; then
            success_msg "✅ 已成功關閉 PR #${pr_number}"
            printf "\033[0;33m💬 關閉原因: %s\033[0m\n" "$close_reason" >&2
            info_msg "📌 功能分支已保留，可稍後重新開啟 PR"
        else
            handle_error "無法關閉 PR #${pr_number}"
        fi
    else
        if gh pr close "$pr_number"; then
            success_msg "✅ 已成功關閉 PR #${pr_number}"
            info_msg "📌 功能分支已保留，可稍後重新開啟 PR"
        else
            handle_error "無法關閉 PR #${pr_number}"
        fi
    fi
}

# 添加評論
handle_add_comment() {
    local pr_number="$1"
    
    # 驗證 PR 編號是否有效
    if [ -z "$pr_number" ] || [ "$pr_number" = "null" ]; then
        handle_error "無效的 PR 編號"
        return 1
    fi
    
    printf "請輸入要添加的評論: " >&2
    read -r comment_text
    
    if [ -z "$comment_text" ]; then
        warning_msg "評論內容不能為空"
        return 1
    fi
    
    info_msg "💬 為 PR #${pr_number} 添加評論..."
    
    if gh pr comment "$pr_number" --body "$comment_text"; then
        success_msg "✅ 已成功添加評論到 PR #${pr_number}"
        printf "\033[0;33m💬 評論內容: %s\033[0m\n" "$comment_text" >&2
        info_msg "📌 PR 保持開放狀態，可繼續開發或等待審查"
    else
        handle_error "無法為 PR #${pr_number} 添加評論"
    fi
}

# 審查與合併 PR (專案擁有者功能)
execute_review_and_merge() {
    info_msg "👑 專案擁有者審查與合併 PR 流程..."
    
    # 顯示當前分支狀態
    local current_branch
    local main_branch
    current_branch=$(get_current_branch)
    main_branch=$(get_main_branch)
    
    echo >&2
    printf "\033[0;35m🌿 當前分支: %s\033[0m\n" "$current_branch" >&2
    printf "\033[0;36m🎯 主分支: %s\033[0m\n" "$main_branch" >&2
    echo >&2
    
    # 檢查是否有待審查的 PR
    info_msg "🔍 檢查待審查的 Pull Request..."
    local pr_list
    pr_list=$(gh pr list --limit 10 2>/dev/null)
    
    if [ -z "$pr_list" ]; then
        warning_msg "目前沒有待審查的 Pull Request"
        return 1
    fi
    
    # 顯示 PR 列表
    echo >&2
    info_msg "📋 待審查的 Pull Request:"
    echo "$pr_list" | head -10 >&2
    echo >&2
    
    # 選擇要審查的 PR
    printf "請輸入要審查的 PR 編號: " >&2
    read -r pr_number
    pr_number=$(echo "$pr_number" | xargs)
    
    if [ -z "$pr_number" ]; then
        handle_error "PR 編號不能為空"
    fi
    
    # 檢查 PR 是否存在
    if ! gh pr view "$pr_number" >/dev/null 2>&1; then
        handle_error "PR #$pr_number 不存在"
    fi
    
    # 檢查 PR 狀態
    info_msg "🔍 檢查 PR #$pr_number 的狀態..."
    local pr_state
    pr_state=$(gh pr view "$pr_number" --json state --jq '.state' 2>/dev/null)
    
    if [ "$pr_state" != "OPEN" ]; then
        # 顯示 PR 詳細資訊
        echo >&2
        warning_msg "❌ PR #$pr_number 狀態不是 OPEN，無法進行審查操作"
        echo >&2
        info_msg "📝 PR #$pr_number 詳細資訊:"
        gh pr view "$pr_number" >&2
        echo >&2
        
        case "$pr_state" in
            "CLOSED")
                warning_msg "此 PR 已被關閉，如需重新審查請先重新開啟 PR"
                ;;
            "MERGED")
                warning_msg "此 PR 已經合併完成，無需再次審查"
                ;;
            *)
                warning_msg "PR 狀態: $pr_state - 只有狀態為 OPEN 的 PR 才能進行審查"
                ;;
        esac
        
        return 1
    fi
    
    success_msg "✅ PR #$pr_number 狀態為 OPEN，可以進行審查"
    
    # 顯示 PR 詳細資訊
    echo >&2
    info_msg "📝 PR #$pr_number 詳細資訊:"
    gh pr view "$pr_number" >&2
    echo >&2
    
    # 檢查 CI 狀態
    info_msg "🔍 檢查 CI 狀態..."
    local ci_status
    ci_status=$(gh pr checks "$pr_number" 2>/dev/null)
    
    echo >&2
    info_msg "🏗️ CI 檢查狀態:"
    echo "$ci_status" >&2
    echo >&2
    
    # 檢查是否有失敗的檢查
    if echo "$ci_status" | grep -q "fail\|error\|❌"; then
        warning_msg "⚠️ 檢測到 CI 檢查失敗，建議先修復後再合併"
        printf "是否繼續進行審查？[y/N]: " >&2
        read -r continue_review
        continue_review=$(echo "$continue_review" | xargs | tr '[:upper:]' '[:lower:]')
        
        if [[ ! "$continue_review" =~ ^(y|yes|是|確定)$ ]]; then
            info_msg "已取消審查流程"
            return 1
        fi
    else
        success_msg "✅ 所有 CI 檢查通過"
    fi
    
    # 審查選項
    echo >&2
    info_msg "🔍 請選擇審查動作:"
    printf "\033[1;32m1.\033[0m ✅ 批准並合併\n" >&2
    printf "\033[1;33m2.\033[0m 💬 添加評論但不合併\n" >&2
    printf "\033[1;31m3.\033[0m ❌ 請求變更\n" >&2
    printf "\033[1;36m4.\033[0m 📖 只查看，不進行審查\n" >&2
    echo "==================================================" >&2
    printf "請選擇 [1-4]: " >&2
    read -r review_action
    review_action=$(echo "$review_action" | xargs)
    
    case "$review_action" in
        1)
            # 批准並合併
            info_msg "✅ 批准 PR #$pr_number..."
            
            # 檢查 PR 作者是否為當前用戶
            local pr_author
            local current_user
            pr_author=$(gh pr view "$pr_number" --json author --jq '.author.login' 2>/dev/null)
            current_user=$(gh api user --jq '.login' 2>/dev/null)
            
            if [ "$pr_author" = "$current_user" ]; then
                warning_msg "⚠️  無法批准自己的 Pull Request"
                info_msg "GitHub 政策不允許開發者批准自己創建的 PR"
                info_msg "請請其他團隊成員進行審查，或直接合併（如果您有權限）"
                
                printf "是否直接合併此 PR（跳過批准步驟）？[y/N]: " >&2
                read -r skip_approve
                skip_approve=$(echo "$skip_approve" | xargs | tr '[:upper:]' '[:lower:]')
                
                if [[ "$skip_approve" =~ ^(y|yes|是|確定)$ ]]; then
                    info_msg "跳過批准步驟，直接進入合併流程..."
                else
                    info_msg "已取消操作。請請其他團隊成員審查此 PR。"
                    return 1
                fi
            else
                # 先進行批准審查
                printf "請輸入審查評論 (可選，直接按 Enter 跳過): " >&2
                read -r review_comment
                
                if [ -n "$review_comment" ]; then
                    if ! gh pr review "$pr_number" --approve --body "$review_comment" 2>/dev/null; then
                        local error_output
                        error_output=$(gh pr review "$pr_number" --approve --body "$review_comment" 2>&1)
                        if [[ "$error_output" == *"Can not approve your own pull request"* ]]; then
                            warning_msg "⚠️  無法批准自己的 Pull Request"
                            info_msg "請請其他團隊成員進行審查"
                            return 1
                        else
                            handle_error "批准 PR 失敗: $error_output"
                        fi
                    fi
                else
                    if ! gh pr review "$pr_number" --approve 2>/dev/null; then
                        local error_output
                        error_output=$(gh pr review "$pr_number" --approve 2>&1)
                        if [[ "$error_output" == *"Can not approve your own pull request"* ]]; then
                            warning_msg "⚠️  無法批准自己的 Pull Request"
                            info_msg "請請其他團隊成員進行審查"
                            return 1
                        else
                            handle_error "批准 PR 失敗: $error_output"
                        fi
                    fi
                fi
                
                success_msg "✅ PR #$pr_number 已批准"
            fi
            
            # 確認是否要合併
            echo >&2
            printf "是否立即合併此 PR？[Y/n]: " >&2
            read -r merge_confirm
            merge_confirm=$(echo "$merge_confirm" | xargs | tr '[:upper:]' '[:lower:]')
            
            if [[ -z "$merge_confirm" ]] || [[ "$merge_confirm" =~ ^(y|yes|是|確定)$ ]]; then
                info_msg "🔀 合併 PR #$pr_number (使用 squash 模式)..."
                
                # 使用 squash 合併並刪除分支
                if gh pr merge "$pr_number" --squash --delete-branch; then
                    success_msg "🎉 PR #$pr_number 已成功合併並刪除功能分支"
                    
                    # 更新本地 main 分支
                    local main_branch
                    main_branch=$(get_main_branch)
                    
                    info_msg "📥 更新本地 $main_branch 分支..."
                    if git checkout "$main_branch" 2>/dev/null && git pull --ff-only origin "$main_branch"; then
                        success_msg "✅ 本地 $main_branch 分支已更新"
                        
                        # 顯示最新的提交歷史
                        echo >&2
                        info_msg "📜 最新提交歷史:"
                        git log --oneline -n 5 >&2
                    else
                        warning_msg "更新本地 $main_branch 分支時發生問題，請手動執行: git checkout $main_branch && git pull"
                    fi
                else
                    handle_error "合併 PR 失敗"
                fi
            else
                info_msg "已批准 PR，但未進行合併"
            fi
            ;;
            
        2)
            # 添加評論
            info_msg "💬 添加 PR 評論..."
            printf "請輸入評論內容: " >&2
            read -r comment_text
            
            if [ -z "$comment_text" ]; then
                handle_error "評論內容不能為空"
            fi
            
            if gh pr comment "$pr_number" --body "$comment_text"; then
                success_msg "✅ 評論已添加到 PR #$pr_number"
            else
                handle_error "添加評論失敗"
            fi
            ;;
            
        3)
            # 請求變更
            info_msg "❌ 請求變更..."
            printf "請輸入變更要求說明: " >&2
            read -r change_request
            
            if [ -z "$change_request" ]; then
                handle_error "變更要求說明不能為空"
            fi
            
            if gh pr review "$pr_number" --request-changes --body "$change_request"; then
                success_msg "✅ 已向 PR #$pr_number 請求變更"
            else
                handle_error "請求變更失敗"
            fi
            ;;
            
        4)
            # 只查看
            info_msg "📖 已查看 PR #$pr_number，無進一步動作"
            ;;
            
        *)
            warning_msg "無效選項：$review_action，已取消審查流程"
            return 1
            ;;
    esac
    
    echo >&2
    success_msg "🎉 PR 審查流程完成！"
}

# ============================================
# 智慧分支刪除功能
# 功能：提供安全的分支刪除流程，包含多重確認機制和主分支保護
# 參數：無
# 返回：0 - 刪除成功，1 - 取消或失敗
# 安全機制：
#   - 主分支保護：絕對禁止刪除 DEFAULT_MAIN_BRANCHES 中的分支
#   - 當前分支處理：如選擇刪除當前分支，會自動切換到主分支
#   - 多重確認：分支選擇 → 刪除確認 → 強制確認（未合併） → 遠端確認
#   - 合併檢查：自動偵測分支是否已合併，未合併需額外確認
# 流程：
#   1. 顯示可刪除分支列表（排除主分支）
#   2. 用戶選擇要刪除的分支
#   3. 檢查分支合併狀態
#   4. 多層級確認機制
#   5. 可選的遠端分支同時刪除
# 使用：execute_delete_branch  # 在主選單中調用
# ============================================

execute_delete_branch() {
    info_msg "🗑️ 刪除分支流程..."
    
    # 獲取當前分支和主分支
    local current_branch
    local main_branch
    current_branch=$(get_current_branch)
    main_branch=$(get_main_branch)
    
    echo >&2
    printf "\033[0;35m🌿 當前分支: %s\033[0m\n" "$current_branch" >&2
    printf "\033[0;36m📋 主分支: %s\033[0m\n" "$main_branch" >&2
    echo >&2
    
    # 列出所有本地分支（排除主分支）
    info_msg "📋 列出可刪除的分支："
    echo >&2
    
    # 獲取所有本地分支，排除主分支和當前分支的標記
    local branches
    branches=$(git branch --format='%(refname:short)' | grep -v -E "^($(IFS='|'; echo "${DEFAULT_MAIN_BRANCHES[*]}"))\$")
    
    if [ -z "$branches" ]; then
        warning_msg "沒有找到可刪除的分支（排除主分支）"
        return 1
    fi
    
    # 顯示分支列表
    local branch_num=1
    echo "$branches" | while read -r branch; do
        if [ "$branch" = "$current_branch" ]; then
            printf "\033[1;33m%d. %s\033[0m \033[0;31m(當前分支)\033[0m\n" "$branch_num" "$branch" >&2
        else
            printf "\033[1;32m%d.\033[0m %s\n" "$branch_num" "$branch" >&2
        fi
        ((branch_num++))
    done
    
    echo >&2
    printf "請輸入要刪除的分支名稱 (或按 Enter 取消): " >&2
    read -r target_branch
    target_branch=$(echo "$target_branch" | xargs)  # 去除前後空白
    
    # 如果用戶按 Enter 取消操作
    if [ -z "$target_branch" ]; then
        info_msg "已取消刪除分支操作"
        return 0
    fi
    
    # 檢查輸入的分支是否存在
    if ! git branch --list "$target_branch" | grep -q "$target_branch"; then
        handle_error "分支 '$target_branch' 不存在"
        return 1
    fi
    
    # 檢查是否為主分支
    for main_branch_candidate in "${DEFAULT_MAIN_BRANCHES[@]}"; do
        if [ "$target_branch" = "$main_branch_candidate" ]; then
            echo >&2
            warning_msg "⚠️  禁止刪除主分支 '$target_branch'"
            info_msg "💡 如需修改主分支設定，請編輯腳本中的 DEFAULT_MAIN_BRANCHES 變數"
            info_msg "   當前設定: (${DEFAULT_MAIN_BRANCHES[*]})"
            return 1
        fi
    done
    
    # 檢查是否為當前分支
    if [ "$target_branch" = "$current_branch" ]; then
        echo >&2
        warning_msg "⚠️  無法刪除當前所在的分支 '$target_branch'"
        printf "是否要先切換到主分支 '$main_branch' 再刪除？[Y/n]: " >&2
        read -r switch_confirm
        switch_confirm=$(echo "$switch_confirm" | xargs | tr '[:upper:]' '[:lower:]')
        
        if [[ -z "$switch_confirm" ]] || [[ "$switch_confirm" =~ ^(y|yes|是|確定)$ ]]; then
            info_msg "正在切換到主分支 '$main_branch'..."
            if ! git checkout "$main_branch"; then
                handle_error "切換到主分支失敗"
                return 1
            fi
            success_msg "✅ 已切換到主分支 '$main_branch'"
        else
            info_msg "已取消刪除分支操作"
            return 0
        fi
    fi
    
    # 最終確認刪除
    echo >&2
    printf "\033[1;31m⚠️  確定要刪除分支 '%s'？[y/N]: \033[0m" "$target_branch" >&2
    read -r delete_confirm
    delete_confirm=$(echo "$delete_confirm" | xargs | tr '[:upper:]' '[:lower:]')
    
    if [[ "$delete_confirm" =~ ^(y|yes|是|確定)$ ]]; then
        # 執行刪除操作
        info_msg "🗑️ 正在刪除分支 '$target_branch'..."
        
        # 先嘗試安全刪除（已合併的分支）
        if git branch -d "$target_branch" 2>/dev/null; then
            success_msg "✅ 已成功刪除分支 '$target_branch'（已合併）"
        else
            # 如果安全刪除失敗，詢問是否強制刪除
            echo >&2
            warning_msg "⚠️  分支 '$target_branch' 包含未合併的變更"
            printf "是否要強制刪除？這將永久丟失未合併的變更 [y/N]: " >&2
            read -r force_confirm
            force_confirm=$(echo "$force_confirm" | xargs | tr '[:upper:]' '[:lower:]')
            
            if [[ "$force_confirm" =~ ^(y|yes|是|確定)$ ]]; then
                if git branch -D "$target_branch"; then
                    success_msg "✅ 已強制刪除分支 '$target_branch'"
                    warning_msg "⚠️  注意：未合併的變更已永久丟失"
                else
                    handle_error "強制刪除分支失敗"
                    return 1
                fi
            else
                info_msg "已取消強制刪除操作"
                return 0
            fi
        fi
        
        # 詢問是否同時刪除遠端分支
        if git ls-remote --heads origin "$target_branch" | grep -q "$target_branch"; then
            echo >&2
            printf "發現遠端分支 'origin/%s'，是否一併刪除？[Y/n]: " "$target_branch" >&2
            read -r remote_delete_confirm
            remote_delete_confirm=$(echo "$remote_delete_confirm" | xargs | tr '[:upper:]' '[:lower:]')
            
            if [[ -z "$remote_delete_confirm" ]] || [[ "$remote_delete_confirm" =~ ^(y|yes|是|確定)$ ]]; then
                info_msg "🗑️ 正在刪除遠端分支 'origin/$target_branch'..."
                if git push origin --delete "$target_branch"; then
                    success_msg "✅ 已成功刪除遠端分支 'origin/$target_branch'"
                else
                    warning_msg "⚠️  刪除遠端分支失敗，可能需要檢查權限"
                fi
            fi
        fi
        
    else
        info_msg "已取消刪除分支操作"
        return 0
    fi
    
    echo >&2
    success_msg "🎉 分支刪除流程完成！"
}

# 腳本入口點
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
