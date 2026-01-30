#!/bin/bash
# -*- coding: utf-8 -*-

# Git 自動化 PR 工具 - 提供完整的 GitHub Flow 工作流程自動化
# 使用方式：./git-auto-pr.sh 或 ./git-auto-pr.sh --help
# 作者：Lazy Jerry | 版本：v2.6.0 | 授權：MIT License

# ==============================================
# AI 提示詞配置區域 - 管理所有 AI 工具的提示詞模板函數
# ==============================================

# 生成 AI 分支名稱提示詞
generate_ai_branch_prompt() {
    local username="$1"
    local branch_type="$2"
    local issue_key="$3"
    local description_hint="$4"
    
    # 如果描述為空，使用更通用的提示詞
    if [ -z "$description_hint" ]; then
        printf '%s' "Generate a Git branch name. Format: $username/$branch_type/$issue_key-description. Use only lowercase, numbers, hyphens. Max 50 chars. Example: jerry/feature/issue-001-add-login"
    else
        printf '%s' "Generate branch name for: $description_hint. Username: $username, Type: $branch_type, Issue: $issue_key. Format: $username/$branch_type/$issue_key-description. Use only lowercase, numbers, hyphens. Max 50 chars. Example: jerry/feature/jira-456-add-auth"
    fi
}

# 生成 AI PR 內容提示詞（實際數據透過臨時檔案傳遞）
generate_ai_pr_prompt() {
    local issue_key="$1"
    local branch_name="$2"
    
    # 注意：Prompt 只包含指令和格式說明，不包含實際的 commits 和 file_changes
    # 實際數據會透過 content 參數（臨時檔案）傳遞
    cat <<EOF
根據以下 commit 訊息摘要生成 PR 內容。

Issue Key: $issue_key
分支名稱: $branch_name

格式要求：
1) 使用繁體中文撰寫
2) 第一句話為簡潔標題（10-20字），必須以句號（。）結尾
3) 接續的內容為詳細功能變更說明
4) 基於 commit 訊息整理功能要點
5) 不要描述技術細節或 diff

輸出範例：
優化 AI 工具整合功能。本次更新改善了 AI 工具的調用流程，提升了分支名稱生成的準確性，並調整了工具優先順序以獲得更好的效能表現。

請參考下方提供的 Commit 訊息摘要和檔案變更資訊。
EOF
}

# AI 工具優先順序配置（依陣列順序調用，失敗時自動嘗試下一個）
readonly AI_TOOLS=(
    "gemini"
    "codex"
    "claude"
)

# ==============================================
# 分支配置區域
# ==============================================

# 主分支候選清單（依陣列順序檢測第一個存在的遠端分支）
readonly -a DEFAULT_MAIN_BRANCHES=("uat" "main" "master")

# 預設使用者名稱（用於生成分支名稱前綴：username/type/issue-description）
readonly DEFAULT_USERNAME="jerry"

# PR 合併後分支刪除策略（true=自動刪除，false=保留分支）
readonly AUTO_DELETE_BRANCH_AFTER_MERGE=false

# ==============================================
# 訊息輸出函數區域 - ANSI 彩色格式化輸出至 stderr
# ==============================================

# 輸出紅色錯誤訊息至 stderr
error_msg() {
    printf "\033[0;31m%s\033[0m\n" "$1" >&2
}

# 輸出錯誤訊息並終止執行（退出碼 1）
handle_error() {
    error_msg "錯誤: $1"
    exit 1
}

# 輸出綠色成功訊息至 stderr
success_msg() {
    printf "\033[0;32m%s\033[0m\n" "$1" >&2
}

# 輸出黃色警告訊息至 stderr
warning_msg() {
    printf "\033[1;33m%s\033[0m\n" "$1" >&2
}

# 輸出藍色資訊訊息至 stderr
info_msg() {
    printf "\033[0;34m%s\033[0m\n" "$1" >&2
}

# 輸出灰色調試訊息至 stderr
debug_msg() {
    printf "\033[0;90m%s\033[0m\n" "$1" >&2
}

# 輸出粗體洋紅色訊息至 stderr
magenta_msg() {
    printf "\033[1;35m%s\033[0m\n" "$1" >&2
}

# 輸出紫色訊息至 stderr
purple_msg() {
    printf "\033[0;35m%s\033[0m\n" "$1" >&2
}

# 輸出青色訊息至 stderr
cyan_msg() {
    printf "\033[0;36m%s\033[0m\n" "$1" >&2
}

# 輸出白色訊息至 stderr
white_msg() {
    printf "\033[1;37m%s\033[0m\n" "$1" >&2
}

# 輸出亮綠色高亮成功訊息至 stderr
highlight_success_msg() {
    printf "\033[1;32m%s\033[0m\n" "$1" >&2
}

# 顯示 AI 工具的調試資訊（工具名稱、輸入、輸出）
show_ai_debug_info() {
    local tool_name="$1"
    local prompt="$2"
    local content="$3"
    local output="$4"
    
    debug_msg "📥 AI 輸入（prompt）："
    echo "$prompt" | sed 's/^/  /' >&2
    debug_msg "📥 AI 輸入（content，前 10 行）："
    echo "$content" | head -n 10 | sed 's/^/  /' >&2
    
    if [ -n "$output" ]; then
        debug_msg "💬 $tool_name 輸出："
        echo "$output" | sed 's/^/  /' >&2
    fi
}

# 隨機顯示一則感謝訊息
show_random_thanks() {
    local messages=(
        "讓我們感謝 Jerry，讓 GitHub Flow 更簡單！"
        "讓我們感謝 Jerry，他讓 PR 流程變得如此優雅。你以為我要說三上優雅這樣的諧音大叔笑話嗎？"
        "讓我們感謝 Jerry，這個工具讓團隊協作更順暢。請去打星星 https://github.com/lazyjerry/git-auto-push"
        "讓我們感謝 Jerry，他簡化了複雜的 Git 工作流程。甘啊捏？"
        "讓我們感謝 Jerry，這些實用工具讓開發者生活更美好，只有我獨自承擔。"
        "讓我們感謝 Jerry，雖然生活依然艱難，但至少 Git 不再是問題，最後剩下你是最大的問題。"
        "讓我們感謝 Jerry，這工具雖然不能改變世界，但能少掉一些麻煩，多了一些 Bug。"
        "讓我們感謝 Jerry，這個工具讓我們的 GitHub Flow 更加高效，雖然還是會有 Bug，但至少少了一些。"
        "讓我們感謝 Jerry，他的工具讓我們的工作流程更順暢，雖然人生依然坎坷，但至少 Git 不再是其中之一。"
        "讓我們感謝 Jerry，這個工具讓我們的 GitHub Flow 更加高效，雖然人生依然艱難，但至少少了一些麻煩。"
        "讓我們感謝 Jerry，這些奇怪的結語，可能是他看了《幼女戰記》才會有這個無聊的結尾語。"
        "讓我們感謝 Jerry，好玩一直玩。"
    )
    
    # 使用當前時間的秒數作為隨機種子
    local random_index=$(( $(date +%s) % ${#messages[@]} ))
    local selected_message="${messages[$random_index]}"
    
    echo >&2
    magenta_msg "💝 $selected_message"
}

# 執行系統命令並檢查結果（失敗時終止執行）
run_command() {
    local cmd="$1"
    local error_msg="$2"
    
    # 印出將要執行的指令
    cyan_msg "→ 執行指令: $cmd"
    
    if ! eval "$cmd"; then
        if [ -n "$error_msg" ]; then
            handle_error "$error_msg"
        else
            handle_error "執行命令失敗: $cmd"
        fi
    fi
}

# 檢查當前目錄是否為 Git 倉庫（返回 0=是，1=否）
check_git_repository() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# 檢查 GitHub CLI 是否安裝並已登入（0=正常，1=未安裝，2=未登入）
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

# 獲取當前 Git 分支名稱
get_current_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    # 清理可能的特殊字符和空白
    echo "$branch" | tr -d '\r\n' | xargs
}

# 自動檢測主分支（依 DEFAULT_MAIN_BRANCHES 順序檢測第一個存在的遠端分支）
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
        error_msg "❌ 錯誤：找不到任何配置的主分支"
        warning_msg "📋 配置的主分支候選清單: ${DEFAULT_MAIN_BRANCHES[*]}"
        cyan_msg "💡 解決方法："
        printf "   1. 檢查 Git 倉庫是否已初始化\n" >&2
        printf "   2. 創建其中一個主分支：\n" >&2
        for branch_candidate in "${DEFAULT_MAIN_BRANCHES[@]}"; do
            success_msg "      git checkout -b $branch_candidate"
        done
        printf "   3. 或修改腳本頂部的 DEFAULT_MAIN_BRANCHES 陣列\n" >&2
        debug_msg "      位置: ${BASH_SOURCE[0]} (第 78 行)"
        exit 1
    fi
    
    # 清理可能的特殊字符和空白
    echo "$found_branch" | tr -d '\r\n' | xargs
}

# 檢查當前是否在主分支上（0=是，1=否）
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

# 顯示 loading 旋轉動畫
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

# 執行命令並顯示 loading 動畫（支援超時控制）
run_command_with_loading() {
    local command="$1"
    local loading_message="$2"
    local timeout="$3"
    local temp_file
    temp_file=$(mktemp)
    
    # 清理與中斷處理函數
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
        warning_msg "操作已被用戶中斷"
        exit 130  # SIGINT 的標準退出碼
    }
    
    # 設置中斷信號處理
    trap cleanup_and_exit INT TERM
    
    # 在背景執行命令並將結果寫入臨時檔案
    (
        eval "$command" > "$temp_file" 2>&1
        echo $? > "${temp_file}.exit_code"
    ) &
    
    local cmd_pid=$!
    
    # 顯示 loading 動畫
    show_loading "$loading_message" "$timeout" "$cmd_pid" &
    local loading_pid=$!
    
    # 等待命令完成或超時
    local count=0
    while [ $count -lt $((timeout * 10)) ] && kill -0 "$cmd_pid" 2>/dev/null; do
        sleep 0.1
        count=$((count + 1))
    done
    
    # 停止 loading 動畫
    kill "$loading_pid" 2>/dev/null
    wait "$loading_pid" 2>/dev/null
    
    # 如果命令仍在運行，則超時殺死它
    if kill -0 "$cmd_pid" 2>/dev/null; then
        kill -TERM "$cmd_pid" 2>/dev/null
        sleep 1
        kill -KILL "$cmd_pid" 2>/dev/null
        wait "$cmd_pid" 2>/dev/null
        warning_msg "命令執行超時"
        rm -f "$temp_file" "${temp_file}.exit_code"
        trap - INT TERM  # 清理信號處理
        return 124  # timeout 的標準退出碼
    fi
    
    # 等待背景程序完成
    wait "$cmd_pid" 2>/dev/null
    
    # 清理信號處理
    trap - INT TERM
    
    # 讀取結果
    local output
    local exit_code
    
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
    
    info_msg "正在調用 codex..."
    
    # 檢查 codex 是否可用
    if ! command -v codex >/dev/null 2>&1; then
        warning_msg "codex 工具未安裝"
        return 1
    fi
    
    # 檢查內容是否為空
    if [ -z "$content" ]; then
        warning_msg "沒有內容可供分析"
        return 1
    fi
    
    # 創建臨時檔案傳遞提示詞和內容
    local temp_prompt
    temp_prompt=$(mktemp)
    printf '%s\n\n%s' "$prompt" "$content" > "$temp_prompt"
    
    # 創建臨時檔案接收乾淨的輸出
    local temp_output
    temp_output=$(mktemp)
    
    # 🔍 調試輸出：印出即將傳遞給 codex 的內容
    debug_msg "🔍 調試: run_codex_command() - 即將傳遞給 codex 的內容"
    debug_msg "─────────────────────────────────────────"
    debug_msg "📊 內容統計:"
    debug_msg "   - 總行數: $(wc -l < "$temp_prompt") 行"
    debug_msg "   - 總位元組: $(wc -c < "$temp_prompt") 位元組"
    debug_msg ""
    debug_msg "📝 前 20 行內容:"
    debug_msg "─────────────────────────────────────────"
    head -n 20 "$temp_prompt" | sed 's/^/  /' >&2
    debug_msg "─────────────────────────────────────────"
    echo >&2
    
    # 執行 codex 命令（使用 --output-last-message 獲取乾淨輸出）
    local raw_output exit_code
    if command -v timeout >/dev/null 2>&1; then
        raw_output=$(run_command_with_loading "timeout $timeout codex exec --output-last-message '$temp_output' < '$temp_prompt' 2>/dev/null" "正在等待 codex 分析內容" "$timeout")
        exit_code=$?
    else
        raw_output=$(run_command_with_loading "codex exec --output-last-message '$temp_output' < '$temp_prompt' 2>/dev/null" "正在等待 codex 分析內容" "$timeout")
        exit_code=$?
    fi
    
    # 讀取乾淨的輸出
    local output=""
    if [ -f "$temp_output" ]; then
        output=$(cat "$temp_output" | xargs)
    fi
    
    # 🔍 調試：顯示退出碼和輸出
    debug_msg "🔍 調試: codex 退出碼 exit_code='$exit_code'"
    debug_msg "🔍 調試: 乾淨輸出 output='$output'"
    
    # 清理臨時檔案
    rm -f "$temp_prompt" "$temp_output"
    
    # 處理執行結果
    case $exit_code in
        0)
            # 成功執行，檢查輸出
            if [ -n "$output" ] && [ ${#output} -gt 3 ]; then
                success_msg "codex 回應完成"
                echo "$output"
                return 0
            fi
            warning_msg "codex 沒有返回有效內容"
            debug_msg "🔍 調試: codex 原始輸出（前 500 字符）"
            echo "$raw_output" | head -c 500 | sed 's/^/  /' >&2
            ;;
        124)
            error_msg "❌ codex 執行超時（${timeout}秒）"
            warning_msg "💡 建議：檢查網路連接或稍後重試"
            ;;
        *)
            # 檢查特定錯誤類型
            if [[ "$raw_output" == *"401 Unauthorized"* ]] || [[ "$raw_output" == *"token_expired"* ]]; then
                error_msg "❌ codex 認證錯誤"
                warning_msg "💡 請執行：codex auth login"
                show_ai_debug_info "codex" "$prompt" "$content" "$raw_output"
            elif [[ "$raw_output" == *"stream error"* ]] || [[ "$raw_output" == *"connection"* ]] || [[ "$raw_output" == *"network"* ]]; then
                error_msg "❌ codex 網路錯誤"
                warning_msg "💡 請檢查網路連接"
                show_ai_debug_info "codex" "$prompt" "$content" "$raw_output"
            else
                warning_msg "codex 執行失敗（退出碼: $exit_code）"
                show_ai_debug_info "codex" "$prompt" "$content" "$raw_output"
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
    
    info_msg "正在調用 $tool_name..."
    
    # 首先檢查工具是否可用
    if ! command -v "$tool_name" >/dev/null 2>&1; then
        warning_msg "$tool_name 工具未安裝"
        return 1
    fi
    
    # 檢查內容是否為空
    if [ -z "$content" ]; then
        warning_msg "沒有內容可供 $tool_name 分析"
        return 1
    fi
    
    local output
    local exit_code
    
    # 創建臨時檔案存儲內容
    local temp_content
    temp_content=$(mktemp)
    echo "$content" > "$temp_content"
    
    # 創建臨時檔案存儲 prompt 內容（避免引號解析問題）
    local temp_prompt
    temp_prompt=$(mktemp)
    printf '%s' "$prompt" > "$temp_prompt"
    
    # 使用帶 loading 的命令執行
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "timeout $timeout $tool_name -p \"\$(cat '$temp_prompt')\" < '$temp_content' 2>/dev/null" "正在等待 $tool_name 回應" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "$tool_name -p \"\$(cat '$temp_prompt')\" < '$temp_content' 2>/dev/null" "正在等待 $tool_name 回應" "$timeout")
        exit_code=$?
    fi
    
    # 清理臨時檔案
    rm -f "$temp_content" "$temp_prompt"
    
    if [ $exit_code -eq 124 ]; then
        error_msg "❌ $tool_name 執行超時（${timeout}秒）"
        
        # 顯示調試信息
        echo >&2
        debug_msg "🔍 調試信息（$tool_name 超時錯誤）:"
        debug_msg "執行的指令: $tool_name -p '$prompt' < [content_file]"
        debug_msg "超時設定: $timeout 秒"
        
        # 使用統一函數顯示 AI 輸入輸出
        if [ -n "$output" ]; then
            show_ai_debug_info "$tool_name" "$prompt" "$content" "$(echo "$output" | head -n 5)"
        else
            show_ai_debug_info "$tool_name" "$prompt" "$content"
            debug_msg "輸出內容: (無)"
        fi
        echo >&2
        return 1
    elif [ $exit_code -ne 0 ]; then
        error_msg "❌ $tool_name 執行失敗"
        
        # 顯示調試信息
        echo >&2
        debug_msg "🔍 調試信息（$tool_name 執行失敗）:"
        debug_msg "執行的指令: $tool_name -p '$prompt' < [content_file]"
        
        # 使用統一函數顯示 AI 輸入輸出
        if [ -n "$output" ]; then
            show_ai_debug_info "$tool_name" "$prompt" "$content" "$output"
        else
            show_ai_debug_info "$tool_name" "$prompt" "$content"
            debug_msg "輸出內容: (無)"
        fi
        echo >&2
        return 1
    fi
    
    if [ -z "$output" ]; then
        error_msg "❌ $tool_name 沒有返回內容"
        
        # 顯示調試信息
        echo >&2
        debug_msg "🔍 調試信息（$tool_name 無輸出）:"
        debug_msg "執行的指令: $tool_name -p '$prompt' < [content_file]"
        
        # 使用統一函數顯示 AI 輸入
        show_ai_debug_info "$tool_name" "$prompt" "$content"
        echo >&2
        return 1
    fi
    
    success_msg "$tool_name 回應完成"
    echo "$output"
    return 0
}

# 清理 AI 生成的訊息
clean_ai_message() {
    local message="$1"
    
    # 顯示原始訊息
    debug_msg "🔍 AI 原始輸出: '$message'"
    
    # 使用管道逐行過濾，移除技術雜訊行
    message=$(echo "$message" | grep -v -E \
        -e '^\(node:[0-9]+\)' \
        -e 'DeprecationWarning' \
        -e 'trace-deprecation' \
        -e '\[ERROR\].*\[IDEClient\]' \
        -e 'IDE companion extension' \
        -e 'overriding the built-in skill' \
        -e '^Hook registry' \
        -e '^Loaded cached' \
        -e '^Loading credentials' \
        -e '^Authentication successful' \
        -e '^Skill.*SKILL\.md' \
        -e 'punycode' \
        -e 'userland alternative' \
        -e '/ide install' \
        2>/dev/null || echo "$message")
    
    # 移除前後空白和多餘空格
    message=$(echo "$message" | xargs)
    
    # 顯示清理結果
    debug_msg "🧹 清理後輸出: '$message'"
    
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
    
    # 格式化內容：處理轉義的換行符（使用 LC_ALL=C 避免編碼問題）
    body=$(LC_ALL=C echo "$body" | sed 's/\\n/\n/g')
    
    # 如果已經包含 Markdown 標題，保持原格式
    if [[ "$body" =~ ^#.*$ ]]; then
        # 已有 Markdown 格式，進行基本清理
        body=$(LC_ALL=C echo "$body" | sed 's/\n\n\n*/\n\n/g')
    else
        # 處理中文句號分隔的內容
        if [[ "$body" == *"。"* ]] && [[ ${#body} -gt 80 ]]; then
            # 在句號後添加換行，創建段落（使用 LC_ALL=C）
            body=$(LC_ALL=C echo "$body" | sed 's/。/。\n\n/g' | sed '/^[[:space:]]*$/d')
            body=$(LC_ALL=C echo "$body" | sed 's/\n\n\n*/\n\n/g')
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

# 格式化 PR body（新版本，不使用 ||| 分隔符）
format_pr_body() {
    local body="$1"
    
    # 處理轉義的換行符
    body=$(echo "$body" | sed 's/\\n/\n/g')
    
    # 如果已經包含 Markdown 標題，保持原格式
    if [[ "$body" =~ ^#.*$ ]]; then
        # 已有 Markdown 格式，進行基本清理
        body=$(echo "$body" | sed 's/\n\n\n*/\n\n/g')
    else
        # 處理中文句號分隔的內容，在句號後添加換行創建段落
        if [[ "$body" == *"。"* ]] && [[ ${#body} -gt 80 ]]; then
            body=$(echo "$body" | sed 's/。/。\n\n/g' | sed '/^[[:space:]]*$/d')
            body=$(echo "$body" | sed 's/\n\n\n*/\n\n/g')
        fi
        
        # 添加簡化的 PR 結構
        if [ ${#body} -lt 50 ]; then
            body="## 📝 功能變更

$body

## 🔧 技術實作
- [ ] 功能測試通過"
        else
            # 為較長內容添加結構
            if [[ ! "$body" =~ (功能變更|技術實作) ]]; then
                body="## 📝 功能變更

$body"
            fi
        fi
    fi
    
    echo "$body"
}

# 清理 AI 生成的分支名稱，確保符合 Git 分支命名規範
clean_branch_name() {
    local branch_name="$1"
    
    # 先進行基本的 AI 輸出清理
    branch_name=$(clean_ai_message "$branch_name")
    
    # 移除分支名稱中的描述性前綴（使用 LC_ALL=C 避免編碼問題）
    branch_name=$(LC_ALL=C echo "$branch_name" | sed 's/^分支名稱[：:][[:space:]]*//')
    branch_name=$(LC_ALL=C echo "$branch_name" | sed 's/^建議[的]*分支名稱[：:][[:space:]]*//')
    branch_name=$(LC_ALL=C echo "$branch_name" | sed 's/^功能描述[：:][[:space:]]*//')
    
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
    
    # 清理分支名稱中的無效字符（使用 LC_ALL=C）
    branch_name=$(LC_ALL=C echo "$branch_name" | sed 's/[^a-zA-Z0-9._/-]//g')
    
    # 移除多餘的連字號和點
    branch_name=$(LC_ALL=C echo "$branch_name" | sed 's/--*/-/g' | sed 's/\.\.*/\./g')
    
    # 移除開頭和結尾的連字號或點
    branch_name=$(LC_ALL=C echo "$branch_name" | sed 's/^[-\.]*//; s/[-\.]*$//')
    
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

# 使用 AI 生成符合規範的分支名稱
generate_branch_name_with_ai() {
    local username="$1"
    local branch_type="$2"
    local issue_key="$3"
    local description_hint="$4"
    
    local prompt
    prompt=$(generate_ai_branch_prompt "$username" "$branch_type" "$issue_key" "$description_hint")
    
    # 準備分支生成的上下文內容
    local content
    if [ -z "$description_hint" ]; then
        content="Username: ${username}
Branch Type: ${branch_type}
Issue Key: ${issue_key}
Task: Generate a meaningful branch name based on the issue key.
Requirements: Use format ${username}/${branch_type}/${issue_key}-description, lowercase only, max 50 chars."
    else
        content="Username: ${username}
Branch Type: ${branch_type}
Issue Key: ${issue_key}
Description: ${description_hint}
Task: Generate a branch name that captures the essence of this feature.
Requirements: Use format ${username}/${branch_type}/${issue_key}-description, lowercase only, max 50 chars."
    fi
    
    info_msg "🤖 使用 AI 生成分支名稱..."
    
    # 嘗試使用不同的 AI 工具
    for tool in "${AI_TOOLS[@]}"; do
        info_msg "🤖 嘗試使用 AI 工具: $tool"
        
        local result
        case "$tool" in
            "codex")
                # 為分支名稱生成使用較短的超時時間（30秒）
                if result=$(run_codex_command "$prompt" "$content" 30); then
                    debug_msg "🔍 調試: codex 原始輸出 result='$result'"
                    result=$(clean_branch_name "$result")
                    debug_msg "🔍 調試: 清理後的 result='$result'"
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成分支名稱成功: $result"
                        echo "$result"
                        return 0
                    else
                        warning_msg "⚠️  clean_branch_name 清理後結果為空"
                    fi
                else
                    warning_msg "⚠️  run_codex_command 執行失敗或返回空結果"
                fi
                ;;
            "gemini"|"claude")
                # 為分支名稱生成使用較短的超時時間（30秒）
                if result=$(run_stdin_ai_command "$tool" "$prompt" "$content" 30); then
                    debug_msg "🔍 調試: $tool 原始輸出 result='$result'"
                    result=$(clean_branch_name "$result")
                    debug_msg "🔍 調試: 清理後的 result='$result'"
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成分支名稱成功: $result"
                        echo "$result"
                        return 0
                    else
                        warning_msg "⚠️  clean_branch_name 清理後結果為空"
                    fi
                else
                    warning_msg "⚠️  run_stdin_ai_command 執行失敗或返回空結果"
                fi
                ;;
        esac
        
        warning_msg "⚠️  $tool 無法生成分支名稱，嘗試下一個工具..."
    done
    
    warning_msg "所有 AI 工具都無法生成分支名稱"
    return 1
}

# 使用 AI 根據 commit 訊息生成 PR 標題和內容
generate_pr_content_with_ai() {
    local issue_key="$1"
    local branch_name="$2"
    
    # 獲取分支的 commit 歷史（完整訊息）
    local commits
    local main_branch
    main_branch=$(get_main_branch)
    
    # 獲取完整的 commit 訊息（不只是 oneline）
    # 確保 git 輸出為 UTF-8 編碼
    commits=$(git log --pretty=format:"- %s" "$main_branch".."$branch_name" 2>/dev/null)
    
    if [ -z "$commits" ]; then
        warning_msg "分支 '$branch_name' 沒有新的 commit"
        return 1
    fi
    
    # 獲取檔案變更摘要（僅用於參考）
    local file_changes
    # 確保 git 輸出為 UTF-8 編碼
    file_changes=$(git diff --name-status "$main_branch".."$branch_name" 2>/dev/null | head -20)
    
    # 計算 commit 數量
    local commit_count
    commit_count=$(echo "$commits" | wc -l | xargs)
    
    info_msg "📊 分析分支資訊："
    info_msg "   - Issue Key: $issue_key"
    info_msg "   - 分支名稱: $branch_name"
    info_msg "   - Commit 數量: $commit_count"
    info_msg "   - 檔案變更: $(echo "$file_changes" | wc -l | xargs) 個檔案"
    echo >&2
    
    # 使用提示詞模板生成 prompt（只包含指令，不包含實際數據）
    local prompt
    prompt=$(generate_ai_pr_prompt "$issue_key" "$branch_name")
    
    info_msg "🤖 使用 AI 根據 commit 訊息生成 PR 內容..."
    
    # 創建臨時檔案存儲 commit 訊息和檔案變更
    local temp_content
    temp_content=$(mktemp)
    {
        printf "Issue Key: %s\n" "$issue_key"
        printf "分支名稱: %s\n" "$branch_name"
        printf "Commit 數量: %s\n\n" "$commit_count"
        printf "Commit 訊息摘要:\n"
        printf "%s" "$commits"
        printf "\n\n檔案變更摘要:\n"
        printf "%s" "$file_changes"
        printf "\n"
    } > "$temp_content"
    
    # 嘗試使用不同的 AI 工具
    for tool in "${AI_TOOLS[@]}"; do
        info_msg "🤖 嘗試使用 AI 工具: $tool"
        
        local result
        local output
        local exit_code
        local timeout=60
        
        case "$tool" in
            "codex")
                # 檢查 codex 是否可用
                if ! command -v codex >/dev/null 2>&1; then
                    warning_msg "codex 工具未安裝"
                    continue
                fi
                
                # 讀取臨時文件內容
                local content_text
                content_text=$(cat "$temp_content")
                
                # 調用統一的 run_codex_command 函數
                if result=$(run_codex_command "$prompt" "$content_text" "$timeout"); then
                    debug_msg "🔍 調試: codex PR 內容原始輸出 result='$result'"
                    success_msg "✅ $tool 生成 PR 內容成功"
                    rm -f "$temp_content"
                    echo "$result"
                    return 0
                else
                    warning_msg "$tool 無法生成 PR 內容"
                fi
                ;;
            "gemini"|"claude")
                # 檢查工具是否可用
                if ! command -v "$tool" >/dev/null 2>&1; then
                    warning_msg "$tool 工具未安裝"
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
                    debug_msg "🔍 調試: $tool PR 內容原始輸出 output='$output'"
                    success_msg "✅ $tool 生成 PR 內容成功"
                    rm -f "$temp_content"
                    echo "$output"
                    return 0
                else
                    if [ $exit_code -eq 124 ]; then
                        warning_msg "$tool 執行超時（${timeout}秒）"
                        if [ -n "$output" ]; then
                            debug_msg "💬 $tool 部分輸出："
                            echo "$output" | head -n 10 | sed 's/^/  /' >&2
                        fi
                    elif [ $exit_code -ne 0 ]; then
                        warning_msg "$tool 執行失敗"
                        if [ -n "$output" ]; then
                            debug_msg "💬 $tool 輸出："
                            echo "$output" | sed 's/^/  /' >&2
                        fi
                    elif [ -z "$output" ]; then
                        warning_msg "$tool 沒有產生輸出"
                    fi
                fi
                ;;
        esac
        
        warning_msg "⚠️  $tool 無法生成 PR 內容，嘗試下一個工具..."
    done
    
    # 清理臨時文件
    rm -f "$temp_content"
    
    warning_msg "所有 AI 工具都無法生成 PR 內容"
    return 1
}

# 配置變數（無預設選項，必須選擇）

# 顯示 GitHub Flow 操作選單
show_operation_menu() {
    local main_branch
    main_branch=$(get_main_branch)
    
    echo >&2
    echo "==================================================" >&2
    info_msg "請選擇要執行的 GitHub Flow PR 操作:"
    cyan_msg "📋 偵測到的主分支: $main_branch"
    
    # 顯示當前分支資訊
    local current_branch
    current_branch=$(get_current_branch)
    if [ -n "$current_branch" ]; then
        purple_msg "🌿 當前所在分支: $current_branch"
    else
        handle_error "⚠️  無法偵測當前分支"
    fi
    echo "==================================================" >&2
    warning_msg "1. 🌿 建立功能分支"
    success_msg "2. 🔄 建立 Pull Request"
    error_msg "3. ❌ 撤銷當前 PR"
    magenta_msg "4. 👑 審查與合併 PR (專案擁有者)"
    cyan_msg "5. 🗑️ 刪除分支"
    echo "==================================================" >&2
    printf "請輸入選項 [1-5]: " >&2
}

# 獲取用戶選擇的操作（返回 1-5）
get_operation_choice() {
    while true; do
        show_operation_menu
        read -r choice
        
        # 清理輸入：移除非 ASCII 字符和前後空白，只保留數字
        choice=$(echo "$choice" | LC_ALL=C tr -cd '0-9' | xargs)
        
        # 如果用戶直接按 Enter 或輸入無效字符，要求重新輸入
        if [ -z "$choice" ]; then
            warning_msg "⚠️  請選擇一個有效選項（1-5）"
            echo >&2
            continue
        fi
        
        # 驗證輸入是否有效
        case "$choice" in
            1)
                info_msg "✅ 已選擇：建立功能分支"
                echo "$choice"
                return 0
                ;;
            2)
                info_msg "✅ 已選擇：建立 Pull Request"
                echo "$choice"
                return 0
                ;;
            3)
                info_msg "✅ 已選擇：撤銷當前 PR"
                echo "$choice"
                return 0
                ;;
            4)
                info_msg "✅ 已選擇：審查與合併 PR (專案擁有者)"
                echo "$choice"
                return 0
                ;;
            5)
                info_msg "✅ 已選擇：刪除分支"
                echo "$choice"
                return 0
                ;;
            *)
                warning_msg "⚠️  無效選項，請輸入 1、2、3、4 或 5"
                echo >&2
                ;;
        esac
    done
}

# 主函數 - GitHub Flow PR 自動化執行引擎

# 顯示腳本使用說明與完整幫助資訊
show_help() {
    # 讀取當前配置值
    local ai_tools_list="${AI_TOOLS[*]}"
    local main_branches_list="${DEFAULT_MAIN_BRANCHES[*]}"
    local username="$DEFAULT_USERNAME"
    local auto_delete="$AUTO_DELETE_BRANCH_AFTER_MERGE"
    
    echo >&2
    cyan_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    highlight_success_msg "  Git 自動 Pull Request 工具（GitHub Flow）v2.0.0"
    cyan_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo >&2
    
    purple_msg "📝 用途說明："
    white_msg "  提供完整的 GitHub Flow 工作流程自動化，從分支建立到 PR 合併。"
    white_msg "  支援 AI 輔助生成分支名稱、PR 內容，並整合企業級安全機制。"
    white_msg "  適用於團隊協作開發環境，涵蓋分支管理、PR 審查、合併與撤銷等完整流程。"
    echo >&2
    
    purple_msg "🚀 使用方式："
    cyan_msg "  互動模式：    ./git-auto-pr.sh"
    cyan_msg "  顯示說明：    ./git-auto-pr.sh -h"
    cyan_msg "                ./git-auto-pr.sh --help"
    cyan_msg "  全域使用：    git-auto-pr"
    cyan_msg "                git-auto-pr --help"
    echo >&2
    
    purple_msg "📋 五種操作模式："
    echo >&2
    
    warning_msg "  1️⃣  建立功能分支"
    white_msg "      • 基於主分支建立新的功能分支"
    white_msg "      • 支援 AI 智慧生成分支名稱"
    white_msg "      • 自動檢測並切換至主分支"
    white_msg "      • 分支格式：username/type/issue-key-description"
    white_msg "      • 分支類型：issue、bug、feature、enhancement、blocker"
    echo >&2
    
    highlight_success_msg "  2️⃣  建立 Pull Request"
    white_msg "      • 基於當前分支建立 PR"
    white_msg "      • AI 自動生成 PR 標題與詳細內容"
    white_msg "      • 自動收集 commit 訊息與檔案變更"
    white_msg "      • 支援多種 AI 工具（目前設定：${ai_tools_list}）"
    white_msg "      • 建立後自動顯示 PR 連結"
    echo >&2
    
    error_msg "  3️⃣  撤銷 PR（智慧模式）"
    white_msg "      • 關閉開放中的 PR"
    white_msg "      • Revert 已合併的 PR（需明確確認）"
    white_msg "      • 自動檢測 PR 狀態並提供對應操作"
    white_msg "      • 顯示受影響的 commit 範圍"
    white_msg "      • 安全確認機制避免誤操作"
    echo >&2
    
    purple_msg "  4️⃣  審查並合併 PR"
    white_msg "      • 互動式 PR 審查流程"
    white_msg "      • 檢視 PR 詳情、diff 與 CI 狀態"
    white_msg "      • 支援雙向審查（approve/comment/request-changes）"
    white_msg "      • 使用 squash merge 策略合併"
    white_msg "      • 合併後分支刪除：$([ "$auto_delete" = "true" ] && echo "自動刪除" || echo "保留分支")"
    echo >&2
    
    cyan_msg "  5️⃣  刪除分支（安全模式）"
    white_msg "      • 同時刪除本地與遠端分支"
    white_msg "      • 主分支保護機制"
    white_msg "      • 多重確認避免誤刪"
    white_msg "      • 禁止刪除當前所在分支"
    white_msg "      • 自動檢查分支合併狀態"
    echo >&2
    
    purple_msg "🔧 相依工具："
    highlight_success_msg "  必需："
    white_msg "    • bash >= 4.0       腳本執行環境"
    white_msg "    • git >= 2.0        版本控制操作"
    white_msg "    • gh >= 2.0         GitHub CLI，用於 PR 操作"
    echo >&2
    
    cyan_msg "  支援 AI 工具（可設定選項）："
    white_msg "    • codex             OpenAI Codex CLI"
    white_msg "    • gemini            Google Gemini CLI"
    white_msg "    • claude            Anthropic Claude CLI"
    echo >&2
    
    info_msg "  安裝方式："
    cyan_msg "    brew install gh                    # GitHub CLI"
    cyan_msg "    gh auth login                      # GitHub 認證"
    white_msg "    # AI 工具請參考各自的安裝文檔"
    echo >&2
    
    purple_msg "⚙️  目前配置："
    cyan_msg "  主分支候選："
    white_msg "    檢測順序：${main_branches_list}"
    white_msg "    修改方式：腳本頂部 DEFAULT_MAIN_BRANCHES 陣列"
    echo >&2
    
    cyan_msg "  預設使用者："
    white_msg "    當前設定：${username}"
    white_msg "    修改方式：腳本頂部 DEFAULT_USERNAME 變數"
    white_msg "    用途說明：用於生成分支名稱前綴"
    echo >&2
    
    cyan_msg "  AI 工具順序："
    white_msg "    當前設定：${ai_tools_list}"
    white_msg "    修改方式：腳本頂部 AI_TOOLS 陣列"
    white_msg "    執行邏輯：依序嘗試，失敗時自動切換下一個"
    echo >&2
    
    cyan_msg "  分支刪除策略："
    white_msg "    當前設定：AUTO_DELETE_BRANCH_AFTER_MERGE=${auto_delete}"
    white_msg "    修改方式：腳本頂部 AUTO_DELETE_BRANCH_AFTER_MERGE 變數"
    white_msg "    說明：設為 true 時合併 PR 後自動刪除遠端分支"
    echo >&2
    
    purple_msg "🔐 安全機制："
    white_msg "  • 主分支保護：無法在主分支上建立 PR 或執行危險操作"
    white_msg "  • CI 狀態檢查：合併前檢查 CI 通過狀態"
    white_msg "  • 多重確認：危險操作需多次確認"
    white_msg "  • 中斷處理：Ctrl+C 安全中斷並清理資源"
    white_msg "  • 超時控制：AI 工具調用有 45 秒超時機制"
    echo >&2
    
    purple_msg "📤 退出碼："
    highlight_success_msg "  0     成功完成操作"
    error_msg "  1     一般錯誤（參數錯誤、操作失敗、使用者取消）"
    warning_msg "  2     相依工具不足（git 或 gh 未安裝）"
    warning_msg "  130   使用者中斷（Ctrl+C）"
    echo >&2
    
    purple_msg "📚 參考文檔："
    cyan_msg "  • GitHub Flow：      docs/github-flow.md"
    cyan_msg "  • PR 撤銷功能：      docs/pr-cancel-feature.md"
    cyan_msg "  • Git 倉庫資訊：     docs/git-info-feature.md"
    cyan_msg "  • 專案 README：      README.md"
    cyan_msg "  • GitHub CLI 文檔：  https://cli.github.com/manual/"
    echo >&2
    
    purple_msg "💡 使用範例："
    white_msg "  # 互動式執行（推薦）"
    cyan_msg "  ./git-auto-pr.sh"
    echo >&2
    white_msg "  # 顯示幫助"
    cyan_msg "  ./git-auto-pr.sh --help"
    echo >&2
    white_msg "  # 安裝為全域命令"
    cyan_msg "  sudo install -m 755 git-auto-pr.sh /usr/local/bin/git-auto-pr"
    cyan_msg "  git-auto-pr"
    echo >&2
    
    purple_msg "📧 作者：Lazy Jerry"
    purple_msg "🔗 倉庫：https://github.com/lazyjerry/git-auto-push"
    purple_msg "📜 授權：MIT License"
    echo >&2
    
    cyan_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo >&2
}

main() {
    # 設置全局信號處理
    global_cleanup() {
        printf "\r\033[K\033[?25h" >&2  # 清理終端並顯示游標
        warning_msg "程序被用戶中斷，正在清理..."
        exit 130  # SIGINT 的標準退出碼
    }
    
    # 設置中斷信號處理
    trap global_cleanup INT TERM

    # 檢查命令行參數
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi
    
    # 檢查命令行參數（移除自動模式支援）
    if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
        warning_msg "⚠️  全自動模式已移除，請使用互動式選單操作"
        echo >&2
    fi

    warning_msg "使用前請確認 git 指令、gh CLI 與 AI CLI 工具能夠在您的命令提示視窗中執行。"
    
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

# 執行功能分支建立流程（基於主分支建立標準化命名的功能分支）
execute_create_branch() {
    info_msg "🌿 建立功能分支流程..."
    
    # 檢測當前分支與主分支狀態
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
    purple_msg "🌿 當前分支: $current_branch"
    cyan_msg "📋 主分支: $main_branch"
    echo >&2
    
    # 檢查是否在主分支上，如果不在主分支則需要切換
    if ! check_main_branch; then
        # 提示使用者目前不在主分支，詢問是否要切換
        warning_msg "當前不在主分支（當前: $current_branch，主分支: $main_branch）"
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
            warning_msg "⚠️  Issue key 不能為空"
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
                info_msg "✅ 使用標準格式 issue key: $issue_key"
                ;;
            1)
                warning_msg "❌ Issue key 格式不正確！只能包含英文字母、數字、連字號(-)和底線(_)"
                warning_msg "   範例：ISSUE-123, JIRA_456, PROJ-001"
                ;;
            2)
                warning_msg "❌ Issue key 必須以英文字母開頭"
                warning_msg "   範例：ISSUE-123, JIRA_456, PROJ-001"
                ;;
            3)
                issue_key="$validated_key"
                warning_msg "⚠️  接受的 issue key: $issue_key"
                warning_msg "   建議格式：{字母}{字母數字}-{數字} 或 {字母}{字母數字}_{數字}"
                ;;
        esac
    done

    # 確保 issue_key 為大寫格式（標準化）
    issue_key=$(echo "$issue_key" | tr '[:lower:]' '[:upper:]')
    info_msg "📝 最終 issue key: $issue_key"
    
    # 輸入擁有者名字
    echo >&2
    printf "請輸入擁有者名字 [預設: %s]: " "$DEFAULT_USERNAME"
    read -r username
    username=$(echo "$username" | xargs | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$username" ]; then
        username="$DEFAULT_USERNAME"
    fi
    
    info_msg "👤 使用者名稱: $username"
    
    # 選擇分支類型
    echo >&2
    info_msg "📋 分支類型說明："
    echo >&2
    cyan_msg "1. issue - 問題 (Issue)"
    printf "   定義：專案過程中遇到的任何障礙、延誤或突發狀況，不一定是系統性的錯誤。\n" >&2
    printf "   範例：需求變動、人力不足、進度落後等。\n" >&2
    printf "   解決方式：通常透過調整資源與計劃來解決。\n" >&2
    echo >&2
    cyan_msg "2. bug - 錯誤 (Bug)"
    printf "   定義：軟體或系統中明確的錯誤，會影響最終產品的品質或功能。\n" >&2
    printf "   範例：程式碼中的邏輯錯誤、流程錯誤，或 UI 介面問題。\n" >&2
    printf "   解決方式：需要進行技術性修正。\n" >&2
    echo >&2
    cyan_msg "3. feature - 功能請求 (Feature Request)"
    printf "   定義：使用者或團隊希望在現有產品中新增或修改的功能。\n" >&2
    printf "   範例：使用者希望增加一個「匯出成 CSV」的功能。\n" >&2
    printf "   解決方式：將其納入未來的開發計劃中。\n" >&2
    echo >&2
    cyan_msg "4. enhancement - 增強 (Enhancement)"
    printf "   定義：對現有功能的改進，讓產品變得更好用或更有效率，但不是必須的修正。\n" >&2
    printf "   範例：將按鈕的顏色從綠色改為藍色，或者優化某個流程的速度。\n" >&2
    printf "   解決方式：通常被視為較不緊急的問題，可以安排在後續的開發階段處理。\n" >&2
    echo >&2
    cyan_msg "5. blocker - 阻礙 (Blocker)"
    printf "   定義：一種會完全阻止專案繼續進行的關鍵問題。\n" >&2
    printf "   範例：伺服器當機，導致所有開發工作都無法進行。\n" >&2
    printf "   解決方式：需要立即解決，以解除阻礙。\n" >&2
    echo >&2
    
    local branch_type=""
    while [ -z "$branch_type" ]; do
        printf "請選擇分支類型 [1-5]: " >&2
        read -r type_choice
        type_choice=$(echo "$type_choice" | xargs)
        
        case "$type_choice" in
            1|issue)
                branch_type="issue"
                ;;
            2|bug)
                branch_type="bug"
                ;;
            3|feature)
                branch_type="feature"
                ;;
            4|enhancement)
                branch_type="enhancement"
                ;;
            5|blocker)
                branch_type="blocker"
                ;;
            *)
                warning_msg "❌ 無效的選擇，請輸入 1-5"
                ;;
        esac
    done
    
    info_msg "🏷️  分支類型: $branch_type"
    
    # 自動生成分支名稱
    echo >&2
    local branch_name="${username}/${branch_type}/${issue_key}"
    
    # 標準化分支名稱：轉換為小寫
    branch_name=$(echo "$branch_name" | tr '[:upper:]' '[:lower:]')
    
    info_msg "📝 將建立分支: $branch_name"
    
    if [ -z "$branch_name" ]; then
        handle_error "分支名稱不能為空"
    fi
    
    # 檢查分支是否已存在
    echo >&2
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
    printf "   1. 在 VS Code 中開始開發: " >&2
    cyan_msg "code ."
    printf "   2. 執行測試: " >&2
    cyan_msg "npm test 或 php artisan test"
    printf "   3. 完成開發後運行: " >&2
    cyan_msg "./git-auto-pr.sh (選擇選項 2)"
    echo >&2
}

# 執行 Pull Request 建立流程（基於當前分支向主分支提交 PR）
execute_create_pr() {
    info_msg "🔄 建立 Pull Request 流程..."
    
    # 檢測當前分支與主分支
    local current_branch
    current_branch=$(get_current_branch)
    
    local main_branch
    main_branch=$(get_main_branch)
    
    # 顯示分支資訊
    echo >&2
    purple_msg "🌿 當前分支: $current_branch"
    cyan_msg "🎯 目標分支: $main_branch"
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
        printf "請輸入 issue key [預設: %s]: " "$suggested_key" >&2
    else
        printf "請輸入 issue key (例: ISSUE-123, JIRA-456, PROJ-001, TASK-789): " >&2
    fi
    
    # 3. 允許使用建議值或手動輸入，重複提示直到獲得有效輸入
    while [ -z "$issue_key" ]; do
        read -r user_input
        user_input=$(echo "$user_input" | xargs)
        
        # 如果使用者按 Enter 且有建議值，直接使用建議值
        if [ -z "$user_input" ] && [ -n "$suggested_key" ]; then
            user_input="$suggested_key"
            info_msg "使用建議的 issue key: $user_input"
        fi
        
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
                    warning_msg "❌ Issue key 格式不正確！只能包含英文字母、數字、連字號(-)和底線(_)"
                    warning_msg "   範例：ISSUE-123, JIRA_456, PROJ-001"
                    if [ -n "$suggested_key" ]; then
                        printf "請輸入 issue key (建議: %s): " "$suggested_key" >&2
                    else
                        printf "請輸入 issue key (例: ISSUE-123, JIRA_456, PROJ-001): " >&2
                    fi
                    ;;
                2)
                    warning_msg "❌ Issue key 必須以英文字母開頭"
                    warning_msg "   範例：ISSUE-123, JIRA_456, PROJ-001"
                    if [ -n "$suggested_key" ]; then
                        printf "請輸入 issue key (建議: %s): " "$suggested_key" >&2
                    else
                        printf "請輸入 issue key (例: ISSUE-123, JIRA_456, PROJ-001): " >&2
                    fi
                    ;;
                3)
                    issue_key="$validated_key"
                    warning_msg "⚠️  接受的 issue key: $issue_key"
                    warning_msg "   建議格式：{字母}{字母數字}-{數字} 或 {字母}{字母數字}_{數字}"
                    ;;
            esac
        else
            # 強制用戶輸入，不接受空輸入
            warning_msg "⚠️  Issue key 不能為空，請輸入有效的 issue key"
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
            # 🔍 調試：顯示 AI 生成的原始內容
            debug_msg "🔍 調試: AI 生成的 pr_content（前 300 字符）"
            echo "$pr_content" | head -c 300 | sed 's/^/  /' >&2
            echo >&2
            
            # 解析 AI 生成的內容（使用句號分割標題和內容）
            if [[ "$pr_content" == *"。"* ]]; then
                # 第一句話（第一個句號之前）作為標題
                pr_title="${pr_content%%。*}。"  # 取得第一個句號之前的部分並加上句號
                
                # 完整內容（包含標題）作為 PR body
                pr_body="$pr_content"
                
                # 清理前後空白
                pr_title=$(echo "$pr_title" | xargs)
                pr_body=$(echo "$pr_body" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                
                debug_msg "🔍 調試: 分割後 pr_title='$pr_title'"
                debug_msg "🔍 調試: 分割後 pr_body（前 200 字符）='$(echo "$pr_body" | head -c 200)'"
            else
                # 沒有句號，整個內容作為標題，body 使用預設格式
                pr_title="$pr_content"
                pr_body="$pr_content

Issue: $issue_key
Summary: Implement feature as described in $issue_key"
                warning_msg "⚠️  AI 輸出未包含句號，使用整段作為標題"
            fi
            
            # 應用格式化處理（只格式化 body，title 保持不變）
            pr_body=$(format_pr_body "$pr_body")
            
            echo >&2
            info_msg "🎯 格式化後的 PR 標題:"
            success_msg "   $pr_title"
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
        info_msg "💡 建議包含：功能變更、技術實作細節"
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
    
    # 對最終的 PR body 應用格式化處理（title 不需要格式化）
    pr_body=$(format_pr_body "$pr_body")
    
    # 顯示最終格式化的 PR 預覽
    echo >&2
    echo "==================================================" >&2
    info_msg "📋 最終 PR 預覽:"
    echo "==================================================" >&2
    cyan_msg "標題: $pr_title"
    echo >&2
    cyan_msg "內容:"
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
        printf "   1. 查看 PR: " >&2
        cyan_msg "gh pr view --web"
        printf "   2. 檢查 CI 狀態: " >&2
        cyan_msg "gh pr checks"
        printf "   3. 添加 reviewer: " >&2
        cyan_msg "gh pr edit --add-reviewer @team/leads"
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
    purple_msg "🌿 當前分支: $current_branch"
    cyan_msg "🎯 主分支: $main_branch"
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
    cyan_msg "🔗 PR 連結: $pr_url"
    warning_msg "📊 PR 狀態: $pr_state"
    
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
    warning_msg "⏰ 合併時間: $merged_at"
    
    # 獲取 PR 合併後的 commit 資訊
    info_msg "🔍 分析 PR 合併後的 commit 變更..."
    
    local merge_commit
    merge_commit=$(gh pr view "$pr_number" --json mergeCommit --jq '.mergeCommit.oid' 2>/dev/null)
    
    if [ -n "$merge_commit" ] && [ "$merge_commit" != "null" ]; then
        cyan_msg "📝 合併 commit: $merge_commit"
        
        # 獲取合併後到現在的 commit 數量
        local main_branch
        main_branch=$(get_main_branch)
        
        local commits_after_pr
        commits_after_pr=$(git rev-list --count "$merge_commit..$main_branch" 2>/dev/null || echo "0")
        
        warning_msg "📊 PR 合併後新增了 $commits_after_pr 個 commit"
        
        if [ "$commits_after_pr" -gt 0 ]; then
            echo >&2
            warning_msg "⚠️  注意: PR 合併後又有 $commits_after_pr 個新的 commit"
            printf "執行 revert 會影響到這些新的變更\n" >&2
            echo >&2
            git log --oneline "$merge_commit..$main_branch" >&2
            echo >&2
        fi
    fi
    
    echo >&2
    error_msg "是否要 revert 此 PR 的變更？[y/N]: "
    read -r revert_confirm
    revert_confirm=$(echo "$revert_confirm" | xargs | tr '[:upper:]' '[:lower:]')
    
    if [[ "$revert_confirm" =~ ^(y|yes|是|確定)$ ]]; then
        if [ -n "$merge_commit" ] && [ "$merge_commit" != "null" ]; then
            info_msg "🔄 執行 revert 操作..."
            if git revert -m 1 "$merge_commit" --no-edit; then
                success_msg "已成功 revert PR #${pr_number} 的變更"
                warning_msg "⚠️  請檢查 revert 結果並視需要推送變更"
                printf "推送命令: " >&2
                cyan_msg "git push origin $(get_main_branch)"
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
    info_msg "請選擇對開放中 PR 的處理方式:"
    echo "==================================================" >&2
    success_msg "1. 🚫 關閉 PR（保留分支）"
    warning_msg "2. 💬 添加評論後保持開放"
    cyan_msg "3. ❌ 取消操作"
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
            warning_msg "💬 關閉原因: $close_reason"
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
        warning_msg "💬 評論內容: $comment_text"
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
    purple_msg "🌿 當前分支: $current_branch"
    cyan_msg "🎯 主分支: $main_branch"
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
    success_msg "1. ✅ 批准並合併"
    warning_msg "2. 💬 添加評論但不合併"
    error_msg "3. ❌ 請求變更"
    cyan_msg "4. 📖 只查看，不進行審查"
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
                
                # 根據配置決定是否刪除分支
                local merge_result
                if [ "$AUTO_DELETE_BRANCH_AFTER_MERGE" = true ]; then
                    # 使用 squash 合併並刪除分支
                    if gh pr merge "$pr_number" --squash --delete-branch; then
                        merge_result=true
                        success_msg "🎉 PR #$pr_number 已成功合併並刪除功能分支"
                    else
                        merge_result=false
                    fi
                else
                    # 使用 squash 合併但保留分支
                    if gh pr merge "$pr_number" --squash; then
                        merge_result=true
                        success_msg "🎉 PR #$pr_number 已成功合併（功能分支已保留）"
                        info_msg "💡 提示：如需刪除分支，請執行 './git-auto-pr.sh' 並選擇選項 5"
                    else
                        merge_result=false
                    fi
                fi
                
                # 如果合併成功，更新本地 main 分支
                if [ "$merge_result" = true ]; then
                    
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

# 智慧分支刪除功能（含主分支保護和多重確認機制）
execute_delete_branch() {
    info_msg "🗑️ 刪除分支流程..."
    
    # 獲取當前分支和主分支
    local current_branch
    local main_branch
    current_branch=$(get_current_branch)
    main_branch=$(get_main_branch)
    
    echo >&2
    purple_msg "🌿 當前分支: $current_branch"
    cyan_msg "📋 主分支: $main_branch"
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
    
    # 將分支存入陣列
    local branch_array=()
    while IFS= read -r branch; do
        branch_array+=("$branch")
    done <<< "$branches"
    
    # 顯示分支列表
    local branch_num=1
    for branch in "${branch_array[@]}"; do
        if [ "$branch" = "$current_branch" ]; then
            warning_msg "$branch_num. $branch (當前分支)"
        else
            success_msg "$branch_num. $branch"
        fi
        ((branch_num++))
    done
    
    echo >&2
    printf "請輸入要刪除的分支編號 [1-%d] (或按 Enter 取消): " "${#branch_array[@]}" >&2
    read -r choice
    
    # 清理輸入：移除非數字字符
    choice=$(echo "$choice" | LC_ALL=C tr -cd '0-9' | xargs)
    
    # 如果用戶按 Enter 或輸入為空
    if [ -z "$choice" ]; then
        info_msg "已取消刪除分支操作"
        return 0
    fi
    
    # 驗證輸入範圍
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#branch_array[@]}" ]; then
        warning_msg "⚠️  無效的選項，請輸入 1 到 ${#branch_array[@]} 之間的數字"
        return 1
    fi
    
    # 獲取選中的分支名稱（陣列索引從 0 開始）
    local target_branch="${branch_array[$((choice - 1))]}"
    
    info_msg "已選擇分支: $target_branch"
    echo >&2
    info_msg "已選擇分支: $target_branch"
    echo >&2
    
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
    error_msg "⚠️  確定要刪除分支 '$target_branch'？[y/N]: "
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
