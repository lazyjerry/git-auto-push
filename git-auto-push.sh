#!/bin/bash
# -*- coding: utf-8 -*-
#
# Git 自動添加推送到遠端倉庫工具
#
# 此腳本提供完整的 Git 工作流程自動化：
# 1. 檢查當前目錄是否為 Git 倉庫
# 2. 顯示所有變更的檔案狀態
# 3. 自動添加所有變更到暫存區
# 4. 互動式輸入 commit message
# 5. 確認提交資訊
# 6. 提交變更到本地倉庫
# 7. 推送到遠端倉庫
#
# 作者: A Bit of Vibe Jerry
# 版本: 1.1
#

# 錯誤處理函數
handle_error() {
    printf "\033[0;31m錯誤: %s\033[0m\n" "$1" >&2
    exit 1
}

# 成功訊息函數
success_msg() {
    printf "\033[0;32m%s\033[0m\n" "$1"
}

# 警告訊息函數
warning_msg() {
    printf "\033[1;33m%s\033[0m\n" "$1"
}

# 資訊訊息函數
info_msg() {
    printf "\033[0;34m%s\033[0m\n" "$1"
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

# 獲取 Git 倉庫的當前狀態
get_git_status() {
    git status --porcelain 2>/dev/null
}

# 將所有變更的檔案添加到 Git 暫存區
add_all_files() {
    info_msg "正在添加所有變更的檔案..."
    if git add . 2>/dev/null; then
        success_msg "檔案添加成功！"
        return 0
    else
        printf "\033[0;31m添加檔案失敗\033[0m\n" >&2
        return 1
    fi
}

# 清理 AI 生成的訊息
clean_ai_message() {
    local message="$1"
    
    # 移除前後空白、換行符號
    message=$(echo "$message" | xargs)
    
    # 移除開頭和結尾的引號
    message=$(echo "$message" | sed 's/^["\'"'"'`]//;s/["\'"'"'`]$//')
    
    # 移除常見的 AI 前綴
    message=$(echo "$message" | sed 's/^[Cc]ommit [Mm]essage: *//;s/^[Tt]itle: *//;s/^[標題]: *//')
    
    # 移除多餘的空白
    message=$(echo "$message" | sed 's/  */ /g' | xargs)
    
    echo "$message"
}

# 顯示 loading 動畫效果
show_loading() {
    local message="$1"
    local timeout="$2"
    local pid="$3"
    
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    local start_time=$(date +%s)
    
    # 隱藏游標
    printf "\033[?25l" >&2
    
    while kill -0 "$pid" 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        # 顯示旋轉動畫和進度
        printf "\r\033[0;34m%s %s (%d/%d秒)\033[0m" "${spinner:$i:1}" "$message" "$elapsed" "$timeout" >&2
        
        i=$(( (i + 1) % ${#spinner} ))
        sleep 0.1
    done
    
    # 清除 loading 行並顯示游標
    printf "\r\033[K\033[?25h" >&2
}

# 執行帶有 loading 動畫的命令
run_command_with_loading() {
    local command="$1"
    local loading_message="$2"
    local timeout="$3"
    local temp_file
    temp_file=$(mktemp)
    
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
        kill "$cmd_pid" 2>/dev/null
        wait "$cmd_pid" 2>/dev/null
        warning_msg "命令執行超時" >&2
        rm -f "$temp_file" "${temp_file}.exit_code"
        return 124  # timeout 的標準退出碼
    fi
    
    # 等待背景程序完成
    wait "$cmd_pid" 2>/dev/null
    
    # 讀取結果
    local output
    local exit_code
    
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
    local timeout=30
    
    info_msg "正在調用 codex..." >&2
    
    # 使用帶 loading 的命令執行
    local output
    local exit_code
    
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "timeout $timeout codex exec '$prompt' 2>/dev/null" "正在等待 codex 回應" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "codex exec '$prompt' 2>/dev/null" "正在等待 codex 回應" "$timeout")
        exit_code=$?
    fi
    
    if [ $exit_code -eq 124 ]; then
        warning_msg "codex 執行超時" >&2
        return 1
    elif [ $exit_code -ne 0 ]; then
        warning_msg "codex 執行失敗（退出碼: $exit_code）" >&2
        return 1
    fi
    
    # 過濾 codex 的系統輸出，只保留實際的回應內容
    local filtered_output
    filtered_output=$(echo "$output" | grep -v -E "^(\[|workdir:|model:|provider:|approval:|sandbox:|reasoning|tokens used:|-------|User instructions:|codex$|^$)" | tail -n 1)
    
    if [ -z "$filtered_output" ]; then
        warning_msg "codex 沒有返回有效內容" >&2
        return 1
    fi
    
    success_msg "codex 回應完成" >&2
    echo "$filtered_output"
    return 0
}

# 執行基於 stdin 的 AI 命令
run_stdin_ai_command() {
    local tool_name="$1"
    local prompt="$2"
    local timeout=30
    
    info_msg "正在調用 $tool_name..." >&2
    
    # 獲取 git diff 內容
    local diff_content
    diff_content=$(git diff --cached 2>/dev/null)
    
    if [ -z "$diff_content" ]; then
        warning_msg "沒有暫存區變更可供 $tool_name 分析" >&2
        return 1
    fi
    
    local output
    local exit_code
    
    # 創建臨時檔案存儲 diff 內容
    local temp_diff
    temp_diff=$(mktemp)
    echo "$diff_content" > "$temp_diff"
    
    # 使用帶 loading 的命令執行
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "timeout $timeout $tool_name -p '$prompt' < '$temp_diff' 2>/dev/null" "正在等待 $tool_name 回應" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "$tool_name -p '$prompt' < '$temp_diff' 2>/dev/null" "正在等待 $tool_name 回應" "$timeout")
        exit_code=$?
    fi
    
    # 清理臨時檔案
    rm -f "$temp_diff"
    
    if [ $exit_code -eq 124 ]; then
        warning_msg "$tool_name 執行超時" >&2
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

# 使用 AI 工具自動生成 commit message
generate_auto_commit_message() {
    info_msg "正在使用 AI 工具分析變更並生成 commit message..." >&2
    
    local prompt="請分析暫存區的 git 變更內容，並生成一個簡潔的中文 commit 訊息標題。只需回應標題，不要額外說明。"
    local generated_message
    local ai_tool_used=""
    
    # 定義 AI 工具清單，按優先順序排列
    # 笑死，如果平常沒在用 gemini 你可以一天用 1000 次 commit
    local ai_tools=(
        "gemini"
        "codex"
        "claude"
    )
    
    # 依序檢查每個 AI 工具
    for tool_name in "${ai_tools[@]}"; do
        if ! command -v "$tool_name" >/dev/null 2>&1; then
            info_msg "AI 工具 $tool_name 未安裝，跳過..." >&2
            continue
        fi
        
        info_msg "嘗試使用 AI 工具: $tool_name" >&2
        ai_tool_used="$tool_name"
        
        # 根據不同工具使用不同的調用方式
        case "$tool_name" in
            "codex")
                if generated_message=$(run_codex_command "$prompt"); then
                    break
                fi
                ;;
            "gemini"|"claude")
                if generated_message=$(run_stdin_ai_command "$tool_name" "$prompt"); then
                    break
                fi
                ;;
        esac
        
        warning_msg "$tool_name 執行失敗，嘗試下一個工具..." >&2
        generated_message=""
        ai_tool_used=""
    done
    
    # 檢查是否成功生成訊息
    if [ -n "$generated_message" ] && [ -n "$ai_tool_used" ]; then
        # 清理生成的訊息
        generated_message=$(clean_ai_message "$generated_message")
        
        if [ -n "$generated_message" ] && [ ${#generated_message} -gt 3 ]; then
            info_msg "✅ 使用 $ai_tool_used 生成的 commit message:" >&2
            printf "\033[1;32m%s\033[0m\n" "🔖 $generated_message" >&2
            echo "$generated_message"
            return 0
        else
            warning_msg "AI 生成的訊息太短或無效: '$generated_message'" >&2
        fi
    fi
    
    # 如果所有 AI 工具都不可用或失敗
    warning_msg "所有 AI 工具都執行失敗或未生成有效的 commit message" >&2
    info_msg "已嘗試的工具: ${ai_tools[*]}" >&2
    return 1
}

# 獲取用戶輸入的 commit message
get_commit_message() {
    echo >&2
    echo "==================================================" >&2
    info_msg "請輸入 commit message (直接按 Enter 可使用 AI 自動生成):" >&2
    echo "==================================================" >&2
    
    read -r message
    message=$(echo "$message" | xargs)  # 去除前後空白
    
    # 如果用戶有輸入內容，直接返回
    if [ -n "$message" ]; then
        echo "$message"
        return 0
    fi
    
    # 如果用戶未輸入內容，直接使用 AI 自動生成
    echo >&2
    info_msg "未輸入 commit message，正在使用 AI 自動生成..." >&2
    
    if auto_message=$(generate_auto_commit_message); then
        echo >&2
        printf "\033[1;36m%s\033[0m\n" "🤖 AI 生成的 commit message:" >&2
        printf "\033[1;32m%s\033[0m\n" "🔖 $auto_message" >&2
        printf "是否使用此訊息？(y/n，直接按 Enter 表示同意): " >&2
        read -r confirm
        confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)
        
        # 如果用戶直接按 Enter 或輸入確認，使用 AI 生成的訊息
        if [ -z "$confirm" ] || [[ "$confirm" =~ ^(y|yes|是|確認)$ ]]; then
            echo "$auto_message"
            return 0
        fi
    fi
    
    # 如果 AI 生成失敗或用戶拒絕使用，提供手動輸入選項
    while true; do
        echo >&2
        info_msg "請手動輸入 commit message (或輸入 'q' 取消操作，輸入 'ai' 重新嘗試 AI 生成):" >&2
        read -r manual_message
        manual_message=$(echo "$manual_message" | xargs)
        
        if [ "$manual_message" = "q" ] || [ "$manual_message" = "Q" ]; then
            warning_msg "已取消操作" >&2
            return 1
        elif [ "$manual_message" = "ai" ] || [ "$manual_message" = "AI" ]; then
            # 重新嘗試 AI 生成
            if auto_message=$(generate_auto_commit_message); then
                echo >&2
                printf "\033[1;36m%s\033[0m\n" "🔄 AI 重新生成的 commit message:" >&2
                printf "\033[1;32m%s\033[0m\n" "🔖 $auto_message" >&2
                printf "是否使用此訊息？(y/n，直接按 Enter 表示同意): " >&2
                read -r confirm
                confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)
                
                if [ -z "$confirm" ] || [[ "$confirm" =~ ^(y|yes|是|確認)$ ]]; then
                    echo "$auto_message"
                    return 0
                fi
            else
                warning_msg "AI 生成仍然失敗，請手動輸入" >&2
            fi
        elif [ -n "$manual_message" ]; then
            echo "$manual_message"
            return 0
        else
            warning_msg "請輸入有效的 commit message，或輸入 'q' 取消，'ai' 重新嘗試 AI 生成" >&2
        fi
    done
}

# 確認是否要提交變更
confirm_commit() {
    local message="$1"
    
    # 清空輸入緩衝區，避免前一個 read 的 Enter 鍵影響此次輸入
    read -r -t 0.1 dummy 2>/dev/null || true
    
    echo >&2
    echo "==================================================" >&2
    info_msg "確認提交資訊:" >&2
    echo "Commit Message: $message" >&2
    echo "==================================================" >&2
    
    # 持續詢問直到獲得有效回應
    while true; do
        printf "是否確認提交？(y/n，直接按 Enter 表示同意): " >&2
        read -r confirm
        confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)
        
        # 如果用戶直接按 Enter，預設為同意
        if [ -z "$confirm" ]; then
            return 0
        # 支援多種確認方式：英文 (y, yes) 和中文 (是, 確認)
        elif [[ "$confirm" =~ ^(y|yes|是|確認)$ ]]; then
            return 0
        # 支援多種取消方式：英文 (n, no) 和中文 (否, 取消)
        elif [[ "$confirm" =~ ^(n|no|否|取消)$ ]]; then
            return 1
        else
            warning_msg "請輸入 y 或 n（或直接按 Enter 表示同意）" >&2
        fi
    done
}

# 提交變更到本地 Git 倉庫
commit_changes() {
    local message="$1"
    
    info_msg "正在提交變更..."
    if git commit -m "$message" 2>/dev/null; then
        success_msg "提交成功！"
        return 0
    else
        printf "\033[0;31m提交失敗\033[0m\n" >&2
        return 1
    fi
}

# 將本地變更推送到遠端倉庫
push_to_remote() {
    info_msg "正在推送到遠端倉庫..."
    
    # 步驟 1: 獲取當前分支名稱
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$branch" ]; then
        printf "\033[0;31m獲取分支名稱失敗\033[0m\n" >&2
        return 1
    fi
    
    # 去除分支名稱前後的空白字符
    branch=$(echo "$branch" | xargs)
    
    # 步驟 2: 推送到遠端倉庫
    if git push origin "$branch" 2>/dev/null; then
        success_msg "成功推送到遠端分支: $branch"
        return 0
    else
        printf "\033[0;31m推送失敗\033[0m\n" >&2
        return 1
    fi
}

# 主函數 - Git 工作流程的完整執行流程
main() {
    # 顯示工具標題
    info_msg "Git 自動添加推送到遠端倉庫工具"
    echo "=================================================="
    
    # 步驟 1: 檢查是否為 Git 倉庫
    if ! check_git_repository; then
        handle_error "當前目錄不是 Git 倉庫！請在 Git 倉庫目錄中執行此腳本。"
    fi
    
    # 步驟 2: 檢查是否有變更需要提交
    local status
    status=$(get_git_status)
    
    if [ -z "$status" ]; then
        info_msg "沒有需要提交的變更。"
        exit 0
    fi
    
    # 顯示檢測到的變更
    info_msg "檢測到以下變更:"
    echo "$status"
    
    # 步驟 3: 添加所有變更的檔案到暫存區
    if ! add_all_files; then
        exit 1
    fi
    
    # 步驟 4: 獲取用戶輸入的 commit message
    local message
    if ! message=$(get_commit_message); then
        exit 1
    fi
    
    # 步驟 5: 確認是否要提交
    if ! confirm_commit "$message"; then
        warning_msg "已取消提交。"
        exit 0
    fi
    
    # 步驟 6: 提交變更到本地倉庫
    if ! commit_changes "$message"; then
        exit 1
    fi
    
    # 步驟 7: 推送到遠端倉庫
    if ! push_to_remote; then
        exit 1
    fi
    
    # 完成提示
    echo
    echo "=================================================="
    success_msg "所有操作完成！"
    echo "=================================================="
}

# 當腳本直接執行時，調用主函數開始 Git 工作流程
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
