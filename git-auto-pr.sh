#!/bin/bash
# -*- coding: utf-8 -*-
#
# Git 自動建立 Pull Request 工具
#
# 此腳本實現 GitHub Flow 開發者提交 PR 流程：
# 1. 建立功能分支 (feature/issue-123-description)
# 2. 開發與測試環境準備
# 3. 提交與推送變更
# 4. 建立 Pull Request
# 5. 支援 AI 工具自動生成分支名稱、commit message、PR 標題與內容
# 6. 完整的錯誤處理和信號中斷處理
#
# 使用方法：
#   ./git-auto-pr.sh        # 互動式選擇模式
#   ./git-auto-pr.sh --auto # 直接執行全自動模式
#   ./git-auto-pr.sh -a     # 全自動模式的簡短參數
#
# 作者: Lazy Jerry
# 版本: 1.0
# 參考: docs/github-flow.md
#

# 錯誤處理函數
handle_error() {
    printf "\033[0;31m錯誤: %s\033[0m\n" "$1" >&2
    exit 1
}

# 成功訊息函數
success_msg() {
    printf "\033[0;32m%s\033[0m\n" "$1" >&2
}

# 警告訊息函數
warning_msg() {
    printf "\033[1;33m%s\033[0m\n" "$1" >&2
}

# 資訊訊息函數
info_msg() {
    printf "\033[0;34m%s\033[0m\n" "$1" >&2
}

# 隨機感謝訊息函數
show_random_thanks() {
    local messages=(
        "感謝 Jerry 製作此工具，讓 GitHub Flow 更簡單！"
        "感謝 Jerry，他讓 PR 流程變得如此優雅。"
        "感謝 Jerry，這個工具讓團隊協作更順暢。請去打星星 https://github.com/lazyjerry/git-auto-push"
        "感謝 Jerry，他簡化了複雜的 Git 工作流程。"
        "感謝 Jerry，這些實用工具讓開發者生活更美好。"
    )
    
    # 使用當前時間的秒數作為隨機種子
    local random_index=$(( $(date +%s) % ${#messages[@]} ))
    local selected_message="${messages[$random_index]}"
    
    echo >&2
    printf "\033[1;35m💝 %s\033[0m\n" "$selected_message" >&2
}

# 執行命令並檢查結果
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

# 檢查當前目錄是否為 Git 倉庫
check_git_repository() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# 檢查是否安裝 gh CLI 工具
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

# 獲取當前分支名稱
get_current_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    # 清理可能的特殊字符和空白
    echo "$branch" | tr -d '\r\n' | xargs
}

# 獲取主分支名稱（自動檢測 main 或 master）
get_main_branch() {
    local branch
    
    # 優先檢查遠端分支
    if git ls-remote --heads origin main 2>/dev/null | grep -q 'refs/heads/main'; then
        branch="main"
    elif git ls-remote --heads origin master 2>/dev/null | grep -q 'refs/heads/master'; then
        branch="master"
    else
        # 如果遠端檢查失敗，檢查本地分支
        if git show-ref --verify --quiet refs/heads/main; then
            branch="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            branch="master"
        else
            # 預設返回 main（現代標準）
            branch="main"
        fi
    fi
    
    # 清理可能的特殊字符和空白
    echo "$branch" | tr -d '\r\n' | xargs
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
        exit_code=$(cat "${temp_file}.exit_code" 2>/dev/null)
    else
        exit_code=1
    fi
    
    # 清理臨時檔案
    rm -f "$temp_file" "${temp_file}.exit_code"
    
    # 輸出結果
    if [ -n "$output" ]; then
        echo "$output"
    fi
    
    return "$exit_code"
}

# 執行 codex 命令並處理輸出
run_codex_command() {
    local prompt="$1"
    local timeout=45  # 增加超時時間到 45 秒
    
    info_msg "正在調用 codex..." >&2
    
    # 首先檢查 codex 是否可用
    if ! command -v codex >/dev/null 2>&1; then
        warning_msg "codex 工具未安裝" >&2
        return 1
    fi
    
    # 使用 printf 安全地處理 prompt，避免特殊字符問題
    local escaped_prompt
    # 將 prompt 中的單引號替換為安全的格式
    escaped_prompt=$(printf '%s' "$prompt" | sed "s/'/'\\\\''/g")
    
    local output
    local exit_code
    
    # 使用 codex exec 命令
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "timeout $timeout codex exec '$escaped_prompt'" "正在等待 codex 回應" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "codex exec '$escaped_prompt'" "正在等待 codex 回應" "$timeout")
        exit_code=$?
    fi
    
    # 檢查認證相關錯誤 (從完整輸出中檢查)
    if [[ "$output" == *"401 Unauthorized"* ]] || [[ "$output" == *"token_expired"* ]] || [[ "$output" == *"authentication token is expired"* ]]; then
        printf "\033[0;31m❌ codex 認證錯誤: 認證令牌已過期\033[0m\n" >&2
        printf "\033[1;33m💡 請執行以下命令重新登入 codex:\033[0m\n" >&2
        printf "\033[0;36m   codex auth login\033[0m\n" >&2
        return 1
    fi
    
    # 檢查其他網路或串流錯誤
    if [[ "$output" == *"stream error"* ]] || [[ "$output" == *"connection"* ]] || [[ "$output" == *"network"* ]]; then
        printf "\033[0;31m❌ codex 網路錯誤: %s\033[0m\n" "$(echo "$output" | grep -E "(stream error|connection|network)" | head -n 1)" >&2
        printf "\033[1;33m💡 請檢查網路連接或稍後重試\033[0m\n" >&2
        return 1
    fi
    
    if [ $exit_code -eq 124 ]; then
        warning_msg "codex 執行超時（${timeout}秒）" >&2
        return 1
    elif [ $exit_code -ne 0 ]; then
        # 檢查輸出中是否包含錯誤訊息
        local error_line
        error_line=$(echo "$output" | grep -E "(error|Error|ERROR)" | head -n 1)
        if [ -n "$error_line" ]; then
            printf "\033[0;31mcodex 執行失敗: %s\033[0m\n" "$error_line" >&2
        else
            warning_msg "codex 執行失敗（退出碼: $exit_code）" >&2
        fi
        return 1
    fi
    
    if [ -z "$output" ]; then
        warning_msg "codex 沒有返回內容" >&2
        return 1
    fi
    
    success_msg "codex 回應完成" >&2
    echo "$output"
    return 0
}

# 執行其他 AI 工具命令 (gemini, claude)
run_ai_tool_command() {
    local tool_name="$1"
    local prompt="$2"
    local timeout=45  # 45 秒超時
    
    info_msg "正在調用 $tool_name..." >&2
    
    # 首先檢查工具是否可用
    if ! command -v "$tool_name" >/dev/null 2>&1; then
        warning_msg "$tool_name 工具未安裝" >&2
        return 1
    fi
    
    local output
    local exit_code
    
    # 使用帶 loading 的命令執行
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "timeout $timeout echo '$prompt' | $tool_name 2>/dev/null" "正在等待 $tool_name 回應" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "echo '$prompt' | $tool_name 2>/dev/null" "正在等待 $tool_name 回應" "$timeout")
        exit_code=$?
    fi
    
    if [ $exit_code -eq 124 ]; then
        warning_msg "$tool_name 執行超時（${timeout}秒）" >&2
        return 1
    elif [ $exit_code -ne 0 ]; then
        warning_msg "$tool_name 執行失敗（退出碼: $exit_code）" >&2
        return 1
    fi
    
    if [ -z "$output" ]; then
        warning_msg "$tool_name 沒有返回內容" >&2
        return 1
    fi
    
    success_msg "$tool_name 回應完成" >&2
    echo "$output"
    return 0
}

# 清理 AI 工具返回的訊息格式
clean_ai_message() {
    local message="$1"
    
    # 移除 codex 的日誌輸出行
    message=$(echo "$message" | grep -v "^\[.*\] OpenAI Codex" | grep -v "^--------" | grep -v "^workdir:" | grep -v "^model:" | grep -v "^provider:" | grep -v "^approval:" | grep -v "^sandbox:" | grep -v "^reasoning" | grep -v "^\[.*\] User instructions:" | grep -v "^\[.*\] codex$" | grep -v "^\[.*\] tokens used:")
    
    # 移除 prompt 回音（AI 工具有時會重複 prompt 內容）
    message=$(echo "$message" | grep -v "^請分析以下" | grep -v "^變更內容：" | grep -v "^要求：" | grep -v "^專案資訊：" | grep -v "^請為.*生成" | grep -v "^Issue:" | grep -v "^分支:" | grep -v "^提交記錄:" | grep -v "^檔案變更:")
    
    # 移除空行和只有空格的行
    message=$(echo "$message" | sed '/^[[:space:]]*$/d')
    
    # 移除常見的 AI 工具前綴和後綴
    message=$(echo "$message" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    message=$(echo "$message" | sed 's/^[「『"'"'"']//' | sed 's/[」』"'"'"']$//')
    
    # 移除 diff 輸出和其他技術細節
    message=$(echo "$message" | sed 's/diff:.*$//' | sed 's/。diff.*$//')
    message=$(echo "$message" | grep -v "^- " | grep -v "^\* ")
    
    # 只取第一個看起來像實際回應的行，並限制長度
    message=$(echo "$message" | grep -v "^$" | head -n 1 | cut -c1-72)
    
    # 如果結果為空，返回預設訊息
    if [ -z "$message" ]; then
        message="更新程式碼"
    fi
    
    echo "$message"
}

# 使用 AI 生成分支名稱
generate_branch_name_with_ai() {
    local issue_key="$1"
    local description_hint="$2"
    
    local prompt="請為 Git 分支生成一個符合 GitHub Flow 規範的分支名稱。
Issue: $issue_key
功能描述: $description_hint
要求：
- 格式：feature/issue-123-brief-description
- 使用英文和連字號，避免特殊字符
- 描述簡潔明確，3-5個單詞
- 只回應分支名稱，不要其他內容"
    
    info_msg "🤖 使用 AI 生成分支名稱..." >&2
    
    # 嘗試使用不同的 AI 工具
    local ai_tools=("codex" "gemini" "claude")
    
    for tool in "${ai_tools[@]}"; do
        printf "\033[1;34m🤖 嘗試使用 AI 工具: %s\033[0m\n" "$tool" >&2
        
        local result
        case "$tool" in
            "codex")
                if result=$(run_codex_command "$prompt"); then
                    result=$(clean_ai_message "$result")
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成分支名稱成功: $result" >&2
                        echo "$result"
                        return 0
                    fi
                fi
                ;;
            *)
                if result=$(run_ai_tool_command "$tool" "$prompt"); then
                    result=$(clean_ai_message "$result")
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

# 使用 AI 生成 commit message
generate_commit_message_with_ai() {
    # 獲取 git diff 內容
    local diff_content
    diff_content=$(git diff --cached 2>/dev/null)
    
    if [ -z "$diff_content" ]; then
        warning_msg "沒有暫存區變更可供 AI 分析" >&2
        return 1
    fi
    
    # 截斷過長的 diff 內容並簡化 prompt
    local short_diff
    short_diff=$(echo "$diff_content" | head -20 | tr '\n' ' ')
    local prompt="根據以下變更生成一個簡潔的中文 commit 訊息，使用 feat/fix/docs 等前綴：$short_diff"
    
    info_msg "🤖 使用 AI 生成 commit message..." >&2
    
    # 嘗試使用不同的 AI 工具
    local ai_tools=("codex" "gemini" "claude")
    
    for tool in "${ai_tools[@]}"; do
        printf "\033[1;34m🤖 嘗試使用 AI 工具: %s\033[0m\n" "$tool" >&2
        
        local result
        case "$tool" in
            "codex")
                if result=$(run_codex_command "$prompt"); then
                    result=$(clean_ai_message "$result")
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成 commit message 成功" >&2
                        echo "$result"
                        return 0
                    fi
                fi
                ;;
            *)
                if result=$(run_ai_tool_command "$tool" "$prompt"); then
                    result=$(clean_ai_message "$result")
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成 commit message 成功" >&2
                        echo "$result"
                        return 0
                    fi
                fi
                ;;
        esac
        
        warning_msg "⚠️  $tool 無法生成 commit message，嘗試下一個工具..." >&2
    done
    
    warning_msg "所有 AI 工具都無法生成 commit message" >&2
    return 1
}

# 使用 AI 生成 PR 標題和內容
generate_pr_content_with_ai() {
    local issue_key="$1"
    local branch_name="$2"
    
    # 獲取分支的 commit 歷史
    local commits
    local main_branch
    main_branch=$(get_main_branch)
    commits=$(git log --oneline "$main_branch".."$branch_name" 2>/dev/null | head -10)
    
    # 獲取檔案變更摘要
    local file_changes
    file_changes=$(git diff --name-status "$main_branch".."$branch_name" 2>/dev/null)
    
    # 簡化並清理 prompt，避免特殊字符問題
    local prompt="請為 Pull Request 生成專業的標題和內容。

專案資訊：
- Issue: $issue_key
- 分支: $branch_name
- 提交記錄: $commits
- 檔案變更: $file_changes

要求：
- 使用繁體中文
- 標題：簡潔明確，描述主要功能（30字以內）
- 內容：包含功能說明、主要變更、測試說明
- 使用 Markdown 格式
- 回應格式：標題|||內容（用三個豎線分隔）"
    
    info_msg "🤖 使用 AI 生成 PR 內容..." >&2
    
    # 嘗試使用不同的 AI 工具
    local ai_tools=("codex" "gemini" "claude")
    
    for tool in "${ai_tools[@]}"; do
        printf "\033[1;34m🤖 嘗試使用 AI 工具: %s\033[0m\n" "$tool" >&2
        
        local result
        case "$tool" in
            "codex")
                if result=$(run_codex_command "$prompt"); then
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成 PR 內容成功" >&2
                        echo "$result"
                        return 0
                    fi
                fi
                ;;
            *)
                if result=$(run_ai_tool_command "$tool" "$prompt"); then
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成 PR 內容成功" >&2
                        echo "$result"
                        return 0
                    fi
                fi
                ;;
        esac
        
        warning_msg "⚠️  $tool 無法生成 PR 內容，嘗試下一個工具..." >&2
    done
    
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
    echo "==================================================" >&2
    printf "\033[1;33m1.\033[0m 🌿 建立功能分支\n" >&2
    printf "\033[1;34m2.\033[0m 📝 提交並推送變更\n" >&2
    printf "\033[1;35m3.\033[0m � 建立 Pull Request\n" >&2
    printf "\033[1;32m4.\033[0m � 完整 PR 流程 (建立分支 → 開發 → 提交 → PR)\n" >&2
    printf "\033[1;36m5.\033[0m 🤖 全自動 PR 模式\n" >&2
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
                info_msg "✅ 已選擇：提交並推送變更" >&2
                echo "$choice"
                return 0
                ;;
            3)
                info_msg "✅ 已選擇：建立 Pull Request" >&2
                echo "$choice"
                return 0
                ;;
            4)
                info_msg "✅ 已選擇：完整 PR 流程" >&2
                echo "$choice"
                return 0
                ;;
            5)
                info_msg "✅ 已選擇：全自動 PR 模式" >&2
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

# 主函數 - GitHub Flow PR 流程的完整執行流程
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
    
    # 檢查命令行參數
    local auto_mode=false
    if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
        auto_mode=true
        info_msg "🤖 命令行啟用全自動 PR 模式" >&2
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
    
    # 根據模式執行
    if [ "$auto_mode" = true ]; then
        execute_auto_pr_workflow
    else
        # 獲取用戶選擇
        local choice
        choice=$(get_operation_choice)
        
        echo >&2
        info_msg "🚀 執行 GitHub Flow PR 操作..."
        
        case "$choice" in
            1)
                execute_create_branch
                ;;
            2)
                execute_commit_and_push
                ;;
            3)
                execute_create_pr
                ;;
            4)
                execute_full_pr_workflow
                ;;
            5)
                execute_auto_pr_workflow
                ;;
        esac
    fi
    
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
    
    if ! check_main_branch; then
        printf "\033[1;33m當前不在主分支（當前: %s，主分支: %s）\033[0m\n" "$current_branch" "$main_branch" >&2
        printf "是否切換到 %s 分支？[Y/n]: " "$main_branch" >&2
        read -r switch_confirm
        switch_confirm=$(echo "$switch_confirm" | xargs | tr '[:upper:]' '[:lower:]')
        
        if [[ -z "$switch_confirm" ]] || [[ "$switch_confirm" =~ ^(y|yes|是|確定)$ ]]; then
            info_msg "切換到 $main_branch 分支並更新..."
            run_command "git checkout $main_branch" "切換到 $main_branch 分支失敗"
            run_command "git pull --ff-only origin $main_branch" "更新 $main_branch 分支失敗"
        else
            warning_msg "已取消操作"
            return 1
        fi
    else
        info_msg "更新 $main_branch 分支..."
        run_command "git pull --ff-only origin $main_branch" "更新 $main_branch 分支失敗"
    fi
    
    # 獲取 issue key
    printf "\n請輸入 issue key (例: ISSUE-123, JIRA-456, 或自定義編號): " >&2
    read -r issue_key
    issue_key=$(echo "$issue_key" | xargs)
    
    if [ -z "$issue_key" ]; then
        handle_error "Issue key 不能為空"
    fi
    
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
        fi
    fi
    
    # 如果 AI 生成失敗或用戶不採用，手動輸入
    if [ -z "$branch_name" ]; then
        if [ -n "$description" ]; then
            # 自動生成建議的分支名稱
            local suggested_branch
            suggested_branch="feature/${issue_key}-$(echo "$description" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')"
            printf "建議的分支名稱: %s\n" "$suggested_branch" >&2
            printf "請輸入分支名稱 (直接按 Enter 使用建議): " >&2
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
    printf "   3. 完成開發後運行: \033[0;36m./git-auto-pr.sh\033[0m (選擇選項 3 或 1)\n" >&2
    echo >&2
}

# 提交並推送變更
execute_commit_and_push() {
    info_msg "📝 提交並推送變更流程..."
    
    # 檢查是否有變更
    local status
    status=$(git status --porcelain 2>/dev/null)
    
    if [ -z "$status" ]; then
        warning_msg "沒有需要提交的變更"
        return 1
    fi
    
    # 顯示變更狀態
    info_msg "檢測到以下變更:"
    git status --short
    echo
    
    # 添加所有變更
    info_msg "正在添加所有變更的檔案..."
    run_command "git add ." "添加檔案失敗"
    success_msg "檔案添加成功！"
    
    # 生成 commit message
    local commit_message
    printf "\n請輸入 commit message (直接按 Enter 可使用 AI 自動生成): " >&2
    read -r commit_input
    commit_input=$(echo "$commit_input" | xargs)
    
    if [ -z "$commit_input" ]; then
        info_msg "🤖 使用 AI 生成 commit message..."
        commit_message=$(generate_commit_message_with_ai)
        if [ $? -eq 0 ] && [ -n "$commit_message" ]; then
            info_msg "AI 生成的 commit message: $commit_message"
            printf "是否使用此 commit message？[Y/n]: " >&2
            read -r confirm_commit
            confirm_commit=$(echo "$confirm_commit" | xargs | tr '[:upper:]' '[:lower:]')
            
            if [[ -n "$confirm_commit" ]] && [[ ! "$confirm_commit" =~ ^(y|yes|是|確定)$ ]]; then
                printf "請手動輸入 commit message: " >&2
                read -r commit_message
                commit_message=$(echo "$commit_message" | xargs)
            fi
        else
            warning_msg "AI 生成失敗，請手動輸入"
            printf "請輸入 commit message: " >&2
            read -r commit_message
            commit_message=$(echo "$commit_message" | xargs)
        fi
    else
        commit_message="$commit_input"
    fi
    
    if [ -z "$commit_message" ]; then
        handle_error "Commit message 不能為空"
    fi
    
    # 提交變更
    info_msg "正在提交變更..."
    run_command "git commit -m '$commit_message'" "提交失敗"
    success_msg "提交成功！"
    
    # 推送到遠端
    local current_branch
    current_branch=$(get_current_branch)
    
    info_msg "正在推送到遠端分支: $current_branch"
    run_command "git push -u origin '$current_branch'" "推送失敗"
    success_msg "✅ 成功推送到遠端分支: $current_branch"
    
    echo >&2
    info_msg "📝 接下來您可以："
    printf "   1. 建立 Pull Request: \033[0;36m./git-auto-pr.sh\033[0m (選擇選項 4 或 1)\n" >&2
    printf "   2. 手動建立 PR: \033[0;36mgh pr create\033[0m\n" >&2
    echo >&2
}

# 建立 Pull Request
execute_create_pr() {
    info_msg "🔄 建立 Pull Request 流程..."
    
    # 檢查當前分支
    local current_branch
    current_branch=$(get_current_branch)
    
    local main_branch
    main_branch=$(get_main_branch)
    
    if [ "$current_branch" = "$main_branch" ]; then
        handle_error "無法從主分支 ($main_branch) 建立 PR"
    fi
    
    # 檢查分支是否已推送
    if ! git ls-remote --heads origin "$current_branch" | grep -q "$current_branch"; then
        warning_msg "分支 '$current_branch' 尚未推送到遠端"
        printf "是否先推送分支？[Y/n]: " >&2
        read -r push_confirm
        push_confirm=$(echo "$push_confirm" | xargs | tr '[:upper:]' '[:lower:]')
        
        if [[ -z "$push_confirm" ]] || [[ "$push_confirm" =~ ^(y|yes|是|確定)$ ]]; then
            execute_commit_and_push
        else
            warning_msg "已取消操作"
            return 1
        fi
    fi
    
    # 獲取 issue key（從分支名稱提取或手動輸入）
    local issue_key
    if [[ "$current_branch" =~ feature/([A-Z0-9]+-[0-9]+) ]]; then
        issue_key="${BASH_REMATCH[1]}"
        info_msg "從分支名稱提取 issue key: $issue_key"
    else
        printf "請輸入 issue key (例: ISSUE-123, JIRA-456, 或直接按 Enter 跳過): " >&2
        read -r issue_key
        issue_key=$(echo "$issue_key" | xargs)
    fi
    
    # Issue key 可以為空（可選）
    if [ -z "$issue_key" ]; then
        issue_key="FEATURE"  # 預設值
        info_msg "使用預設 issue key: $issue_key"
    fi
    
    # 生成 PR 標題和內容
    local pr_title
    local pr_body
    
    printf "\n是否使用 AI 自動生成 PR 標題和內容？[Y/n]: " >&2
    read -r use_ai
    use_ai=$(echo "$use_ai" | xargs | tr '[:upper:]' '[:lower:]')
    
    if [[ -z "$use_ai" ]] || [[ "$use_ai" =~ ^(y|yes|是|確定)$ ]]; then
        info_msg "🤖 使用 AI 生成 PR 內容..."
        
        if pr_content=$(generate_pr_content_with_ai "$issue_key" "$current_branch"); then
            # 解析 AI 生成的內容（假設格式為 "標題|||內容"）
            if [[ "$pr_content" == *"|||"* ]]; then
                pr_title=$(echo "$pr_content" | cut -d'|' -f1 | xargs)
                pr_body=$(echo "$pr_content" | cut -d'|' -f2- | sed 's/^||*//' | xargs)
            else
                pr_title="$pr_content"
                pr_body="Issue: $issue_key\nSummary: Implement feature as described in $issue_key"
            fi
            
            echo >&2
            info_msg "AI 生成的 PR 標題: $pr_title"
            info_msg "AI 生成的 PR 內容:"
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
        printf "請輸入 PR 標題: " >&2
        read -r pr_title
        pr_title=$(echo "$pr_title" | xargs)
        
        if [ -z "$pr_title" ]; then
            # 使用預設標題
            pr_title="[$issue_key] Implement feature"
        fi
    fi
    
    if [ -z "$pr_body" ]; then
        printf "請輸入 PR 描述 (可選，直接按 Enter 跳過): " >&2
        read -r pr_body_input
        if [ -n "$pr_body_input" ]; then
            pr_body="$pr_body_input"
        else
            pr_body="Issue: $issue_key\nSummary: Implement feature as described in $issue_key"
        fi
    fi
    
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

# 完整 PR 流程
execute_full_pr_workflow() {
    info_msg "🚀 執行完整 GitHub Flow PR 流程..."
    
    echo >&2
    info_msg "步驟 1: 建立功能分支"
    if ! execute_create_branch; then
        handle_error "建立分支步驟失敗"
    fi
    
    echo >&2
    success_msg "✅ 分支建立完成，請開始開發..."
    warning_msg "⏸️  開發完成後，請再次執行此腳本選擇「提交並推送變更」或「完整 PR 流程」"
    
    # 提示用戶開發完成後的操作
    printf "\n開發完成後是否繼續後續流程？[y/N]: " >&2
    read -r continue_workflow
    continue_workflow=$(echo "$continue_workflow" | xargs | tr '[:upper:]' '[:lower:]')
    
    if [[ "$continue_workflow" =~ ^(y|yes|是|確定)$ ]]; then
        echo >&2
        info_msg "步驟 2: 提交並推送變更"
        if ! execute_commit_and_push; then
            handle_error "提交推送步驟失敗"
        fi
        
        echo >&2
        info_msg "步驟 3: 建立 Pull Request"
        if ! execute_create_pr; then
            handle_error "建立 PR 步驟失敗"
        fi
        
        success_msg "🎉 完整 PR 流程執行完成！"
    else
        info_msg "👋 流程暫停，開發完成後請繼續執行後續步驟"
    fi
}

# 全自動 PR 模式
execute_auto_pr_workflow() {
    info_msg "🤖 執行全自動 PR 流程..."
    
    # 檢查當前狀態
    local current_branch
    current_branch=$(get_current_branch)
    
    # 如果在主分支，需要先建立功能分支
    local main_branch
    main_branch=$(get_main_branch)
    
    if [ "$current_branch" = "$main_branch" ]; then
        warning_msg "當前在主分支 ($main_branch)，全自動模式需要先建立功能分支"
        handle_error "請先切換到功能分支或使用互動模式建立分支"
    fi
    
    # 如果有未提交的變更，自動提交並推送
    local status
    status=$(git status --porcelain 2>/dev/null)
    
    if [ -n "$status" ]; then
        info_msg "檢測到未提交的變更，自動提交並推送..."
        if ! execute_commit_and_push; then
            handle_error "自動提交推送失敗"
        fi
    fi
    
    # 建立 Pull Request
    info_msg "自動建立 Pull Request..."
    if ! execute_create_pr; then
        handle_error "自動建立 PR 失敗"
    fi
    
    success_msg "🎉 全自動 PR 流程執行完成！"
}

# 腳本入口點
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
