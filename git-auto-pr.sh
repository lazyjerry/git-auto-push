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
    echo "Generate branch name: feature/$issue_key-description. Issue: $issue_key, Description: $description_hint. Use only lowercase, numbers, hyphens. Max 40 chars. Example: feature/jira-456-add-auth"
}

# AI Commit 訊息生成提示詞模板  
# 參數：$1=short_diff (截斷的變更內容)
# 輸出：符合 Conventional Commits 規範的中文訊息
generate_ai_commit_prompt() {
    local short_diff="$1"
    echo "根據以下變更生成簡潔的中文 commit 訊息（格式：feat/fix/docs: 描述）：$short_diff"
}

# AI PR 內容生成提示詞模板
# 參數：$1=issue_key, $2=branch_name, $3=commits, $4=file_changes  
# 輸出：PR標題|||PR內容 格式，使用 ||| 分隔標題和內容
generate_ai_pr_prompt() {
    local issue_key="$1"
    local branch_name="$2"
    local commits="$3"
    local file_changes="$4"
    echo "生成PR標題和內容，格式：標題|||內容。Issue: $issue_key, 分支: $branch_name, 變更: $commits $file_changes。使用繁體中文，標題25字內，內容包含功能說明和主要變更。"
}

# AI 工具優先順序配置
# 說明：定義 AI 工具的調用順序，當前一個工具失敗時會自動嘗試下一個
# 修改此陣列可以調整工具優先級或新增其他 AI 工具
readonly AI_TOOLS=( "gemini" "codex" "claude")

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

# 獲取主分支名稱（從配置陣列中自動檢測）
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
    message=$(echo "$message" | grep -v "^請分析以下" | grep -v "^變更內容：" | grep -v "^要求：" | grep -v "^專案資訊：" | grep -v "^請為.*生成" | grep -v "^Issue:" | grep -v "^分支:" | grep -v "^提交記錄:" | grep -v "^檔案變更:" | grep -v "^功能描述:")
    
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
        
        # 添加基本的 PR 結構
        if [ ${#body} -lt 30 ]; then
            body="## 📝 變更說明
$body

## 🔍 測試說明
- [ ] 功能測試通過
- [ ] 無破壞性變更"
        else
            # 為較長內容添加標題結構
            body="## 📝 變更說明

$body"
        fi
    fi
    
    # 返回格式化後的內容，使用特殊分隔符
    echo "${title}|||${body}"
}

# 專門清理和驗證分支名稱的函數
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
    
    info_msg "🤖 使用 AI 生成分支名稱..." >&2
    
    # 嘗試使用不同的 AI 工具
    for tool in "${AI_TOOLS[@]}"; do
        printf "\033[1;34m🤖 嘗試使用 AI 工具: %s\033[0m\n" "$tool" >&2
        
        local result
        case "$tool" in
            "codex")
                if result=$(run_codex_command "$prompt"); then
                    result=$(clean_branch_name "$result")
                    if [ -n "$result" ]; then
                        success_msg "✅ $tool 生成分支名稱成功: $result" >&2
                        echo "$result"
                        return 0
                    fi
                fi
                ;;
            *)
                if result=$(run_ai_tool_command "$tool" "$prompt"); then
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
    local prompt
    prompt=$(generate_ai_commit_prompt "$short_diff")
    
    info_msg "🤖 使用 AI 生成 commit message..." >&2
    
    # 嘗試使用不同的 AI 工具
    for tool in "${AI_TOOLS[@]}"; do
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
    
    # 使用提示詞模板生成 prompt
    local prompt
    prompt=$(generate_ai_pr_prompt "$issue_key" "$branch_name" "$commits" "$file_changes")
    
    info_msg "🤖 使用 AI 生成 PR 內容..." >&2
    
    # 嘗試使用不同的 AI 工具
    for tool in "${AI_TOOLS[@]}"; do
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
    printf "\033[1;35m2.\033[0m � 建立 Pull Request\n" >&2
    printf "\033[1;32m3.\033[0m � 完整 PR 流程 (建立分支 → 開發 → 提交 → PR)\n" >&2
    printf "\033[1;31m4.\033[0m 👑 審查與合併 PR (專案擁有者)\n" >&2
    echo "==================================================" >&2
    printf "請輸入選項 [1-4]: " >&2
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
                info_msg "✅ 已選擇：完整 PR 流程" >&2
                echo "$choice"
                return 0
                ;;
            4)
                info_msg "✅ 已選擇：審查與合併 PR (專案擁有者)" >&2
                echo "$choice"
                return 0
                ;;
            *)
                warning_msg "無效選項：$choice，請輸入 1、2、3 或 4" >&2
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
            execute_full_pr_workflow
            ;;
        4)
            execute_review_and_merge
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
    printf "\033[0;35m🌿 當前分支: %s\033[0m\n" "$current_branch" >&2
    printf "\033[0;36m📋 主分支: %s\033[0m\n" "$main_branch" >&2
    echo >&2
    
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
    printf "   3. 完成開發後運行: \033[0;36m./git-auto-pr.sh\033[0m (選擇選項 2 或 1)\n" >&2
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
    printf "   1. 建立 Pull Request: \033[0;36m./git-auto-pr.sh\033[0m (選擇選項 2 或 1)\n" >&2
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
            # 解析 AI 生成的內容（假設格式為 "標題|||內容"）
            if [[ "$pr_content" == *"|||"* ]]; then
                pr_title=$(echo "$pr_content" | cut -d'|' -f1 | xargs)
                pr_body=$(echo "$pr_content" | cut -d'|' -f2- | sed 's/^||*//')
            else
                pr_title="$pr_content"
                pr_body="Issue: $issue_key\nSummary: Implement feature as described in $issue_key"
            fi
            
            # 應用格式化處理
            local formatted_content
            formatted_content=$(format_pr_content "$pr_title" "$pr_body")
            pr_title=$(echo "$formatted_content" | cut -d'|' -f1)
            pr_body=$(echo "$formatted_content" | cut -d'|' -f2- | sed 's/^||*//')
            
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
    
    # 對最終的 PR 內容應用格式化處理
    local final_formatted_content
    final_formatted_content=$(format_pr_content "$pr_title" "$pr_body")
    pr_title=$(echo "$final_formatted_content" | cut -d'|' -f1)
    pr_body=$(echo "$final_formatted_content" | cut -d'|' -f2- | sed 's/^||*//')
    
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

# 完整 PR 流程
execute_full_pr_workflow() {
    info_msg "🚀 執行完整 GitHub Flow PR 流程..."
    
    # 顯示當前分支狀態
    local current_branch
    local main_branch
    current_branch=$(get_current_branch)
    main_branch=$(get_main_branch)
    
    echo >&2
    printf "\033[0;35m🌿 當前分支: %s\033[0m\n" "$current_branch" >&2
    printf "\033[0;36m📋 主分支: %s\033[0m\n" "$main_branch" >&2
    echo >&2
    
    info_msg "步驟 1: 建立功能分支"
    if ! execute_create_branch; then
        handle_error "建立分支步驟失敗"
    fi
    
    echo >&2
    success_msg "✅ 分支建立完成，請開始開發..."
    warning_msg "⏸️  開發完成後，請再次執行此腳本選擇「完整 PR 流程」"
    
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

# 腳本入口點
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
