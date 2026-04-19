#!/bin/bash
# -*- coding: utf-8 -*-

# Git 自動化推送工具 - 提供完整的 Git 傳統工作流程自動化（add/commit/push）
# 使用方式：./git-auto-push.sh 或 ./git-auto-push.sh --help 或 ./git-auto-push.sh -a
# 作者：Lazy Jerry | 版本：v2.8.0 | 授權：MIT License

readonly VERSION="v2.8.0"

# ==============================================
# 配置文件加載區域
# ==============================================

# 配置文件目錄與檔案名稱
readonly CONFIG_DIR_NAME=".git-auto-push-config"
readonly CONFIG_FILE_NAME=".env"

# 獲取腳本所在目錄（解析符號連結）
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -L "$source" ]; do
        local dir
        dir=$(cd -P "$(dirname "$source")" && pwd)
        source=$(readlink "$source")
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

# 加載配置文件（如果存在）
# 參數：$1 - 配置文件路徑
# 返回：0=成功加載，1=文件不存在或加載失敗
load_config_file() {
    local config_path="$1"
    if [ -f "$config_path" ]; then
        # shellcheck source=/dev/null
        if source "$config_path" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# 加載配置文件（按優先級）
# 優先級：當前工作目錄 > 用戶 Home > 腳本所在目錄
load_config() {
    local script_dir
    script_dir=$(get_script_dir)
    local config_loaded=false
    local loaded_from=""
    local config_path=""
    
    # 優先級 1：當前工作目錄（與腳本執行位置無關）
    config_path="$PWD/$CONFIG_DIR_NAME/$CONFIG_FILE_NAME"
    if load_config_file "$config_path"; then
        config_loaded=true
        loaded_from="$config_path"
    fi
    
    # 優先級 2：用戶 Home 目錄
    if [ "$config_loaded" = false ]; then
        config_path="$HOME/$CONFIG_DIR_NAME/$CONFIG_FILE_NAME"
        if load_config_file "$config_path"; then
            config_loaded=true
            loaded_from="$config_path"
        fi
    fi
    
    # 優先級 3：腳本所在目錄（主要用於全域安裝時的預設配置）
    if [ "$config_loaded" = false ]; then
        config_path="$script_dir/$CONFIG_DIR_NAME/$CONFIG_FILE_NAME"
        if load_config_file "$config_path"; then
            config_loaded=true
            loaded_from="$config_path"
        fi
    fi
    
    # 如果有加載配置文件，在調試模式下顯示訊息
    if [ "$config_loaded" = true ]; then
        # 注意：此時 IS_DEBUG 可能已被配置文件覆蓋
        if [ "${IS_DEBUG:-false}" = true ]; then
            printf "\033[0;90m📁 已加載配置文件: %s\033[0m\n" "$loaded_from" >&2
            # 顯示 AI_TOOLS 配置（如果已設定）
            if [ ${#AI_TOOLS[@]} -gt 0 ]; then
                printf "\033[0;90m   AI_TOOLS=(%s)\033[0m\n" "${AI_TOOLS[*]}" >&2
            fi
        fi
    fi
}

# 在設定預設值之前先加載配置文件
load_config

# ==============================================
# AI 工具配置區域
# ==============================================

# AI 工具優先順序配置（預設值，可被配置文件覆蓋）
# 說明：定義 AI 工具的調用順序，當前一個工具失敗時會自動嘗試下一個。
#       腳本會依陣列順序逐一調用，直到成功或全部失敗。
# 修改方式：調整陣列元素順序或新增其他 AI CLI 工具名稱（需系統已安裝）
# 工具特性：
#   - copilot：GitHub Copilot CLI，需要 Copilot 訂閱，支援 programmatic mode
#   - codex：通常較穩定，建議優先使用
#   - gemini：可能有網路或認證問題，需配置 API key
#   - claude：需要登入認證或 API 設定
# 範例：
#   AI_TOOLS=("codex")                    # 僅使用 codex
#   AI_TOOLS=("copilot" "gemini" "codex") # 調整優先順序
: "${AI_TOOLS:=}"
if [ ${#AI_TOOLS[@]} -eq 0 ]; then
    AI_TOOLS=(
        "copilot"
        "gemini"
        "codex"
        "claude"
    )
fi

# AI 提示詞配置
# 說明：用於 commit 訊息生成的統一提示詞模板。
#       此提示詞會與 git diff 內容一起傳遞給 AI 工具。
# 修改重點：
#   - 應強調描述功能變更、需求實現、行為改變
#   - 避免要求技術細節或實作方式
#   - 指定輸出語言（此處為中文）與格式（一行標題）
# 輸出範例：新增用戶登入功能、修正檔案上傳錯誤、改善搜尋效能
readonly AI_COMMIT_PROMPT="根據以下 git 變更生成一行中文 commit 標題，格式如：新增用戶登入功能、修正檔案上傳錯誤、改善搜尋效能。只輸出標題："

# Conventional Commits 前綴類型清單
# 說明：基於 Conventional Commits 規範的 commit 訊息前綴類型。
#       用於手動選擇和 AI 自動判斷，提升 commit 訊息的一致性和可讀性。
# 格式："前綴:說明|前綴:說明|..."
# 參考：https://www.conventionalcommits.org/
readonly -a COMMIT_PREFIXES=(
    "feat:新功能"
    "fix:錯誤修復"
    "docs:文件變更"
    "style:程式碼格式"
    "refactor:重構"
    "perf:效能改進"
    "test:測試相關"
    "build:建置系統"
    "ci:CI 配置"
    "chore:雜項維護"
    "revert:回退提交"
)

# AI 前綴選擇提示詞
# 說明：用於讓 AI 根據 git diff 自動選擇最適合的 Conventional Commits 前綴。
# 要求：
#   - 只輸出前綴關鍵字（如：feat、fix、docs 等）
#   - 不包含冒號、說明文字或其他內容
#   - 必須從預定義的前綴清單中選擇
readonly AI_PREFIX_PROMPT="根據以下 git 變更，選擇最適合的 Conventional Commits 前綴類型。可用前綴：feat(新功能)、fix(錯誤修復)、docs(文件)、style(格式)、refactor(重構)、perf(效能)、test(測試)、build(建置)、ci(CI)、chore(維護)、revert(回退)。只輸出前綴關鍵字(例如:feat)，不要包含冒號或說明："

# 任務編號自動帶入設定（預設值，可被配置文件覆蓋）
# 說明：控制是否在 commit 訊息前自動加入任務編號（從分支名稱偵測）。
#       任務編號格式如：JIRA-123、PROJ-456、feat-001 等。
# 效果：
#   - true：自動在 commit 訊息前加上 [任務編號] 前綴
#   - false：保持原始 commit 訊息，不加任務編號
# 範例：
#   啟用時：[feat-001] 新增用戶登入功能
#   停用時：新增用戶登入功能
# 適用場景：
#   - 團隊要求 commit 關聯任務編號時啟用
#   - 個人專案或不需要任務編號時停用
: "${AUTO_INCLUDE_TICKET:=true}"

# Commit 訊息品質檢查設定（預設值，可被配置文件覆蓋）
# 說明：在 commit 前使用 AI 檢查訊息是否具有明確的目的和功能性。
#       確保 commit 訊息清楚描述變更內容，避免無意義或模糊的訊息。
# 效果：
#   - true：自動使用 AI 檢查 commit 訊息品質，若意義不明則警告
#   - false：提示是否要檢查，預設不檢查（按 Enter 跳過）
# 檢查標準：
#   - 訊息是否描述了具體的變更內容
#   - 是否有明確的目的（新增功能、修復問題、改善效能等）
#   - 避免過於簡短或模糊的描述（如「update」、「fix」、「changes」）
# 範例：
#   ✅ 良好：「新增使用者登入功能」、「修復檔案上傳時的記憶體洩漏」
#   ❌ 不良：「update」、「修改」、「調整程式碼」、「fix bug」
# 適用場景：
#   - 團隊要求高品質 commit 訊息時啟用
#   - 個人專案或快速提交時可停用
: "${AUTO_CHECK_COMMIT_QUALITY:=true}"

# 調試模式設定（預設值，可被配置文件覆蓋）
# 說明：控制是否顯示調試訊息（debug_msg）和 AI 輸入輸出詳情（show_ai_debug_info）。
#       調試訊息包含 AI 工具執行細節、錯誤追蹤、輸入輸出內容等技術資訊。
# 效果：
#   - true：顯示所有調試訊息，用於問題排查和開發測試
#   - false：隱藏調試訊息，保持輸出簡潔（預設，建議一般使用者）
# 使用場景：
#   - 開發或測試時啟用，可查看完整的執行流程
#   - 一般使用時停用，避免過多技術細節干擾
#   - 遇到 AI 工具執行問題時，可臨時啟用以診斷錯誤
# 注意：
#   - 調試訊息可能包含敏感資訊（如 API 回應、diff 內容）
#   - 啟用後會大幅增加輸出內容，建議僅在需要時開啟
: "${IS_DEBUG:=false}"

# ==============================================
# 訊息輸出函數區域
# ==============================================

# 輸出紅色錯誤訊息至 stderr（不終止程式）
error_msg() {
    printf "\033[0;31m%s\033[0m\n" "$1" >&2  # 紅色 ANSI 碼輸出
}

# 輸出錯誤訊息並終止腳本（exit 1）
handle_error() {
    error_msg "錯誤: $1"  # 加上前綴輸出錯誤
    exit 1                 # 終止程式
}

# 輸出綠色成功訊息至 stderr
success_msg() {
    printf "\033[0;32m%s\033[0m\n" "$1" >&2  # 綠色 ANSI 碼輸出
}

# 輸出黃色警告訊息至 stderr
warning_msg() {
    printf "\033[1;33m%s\033[0m\n" "$1" >&2  # 粗體黃色 ANSI 碼輸出
}

# 輸出藍色資訊訊息至 stderr
info_msg() {
    printf "\033[0;34m%s\033[0m\n" "$1" >&2  # 藍色 ANSI 碼輸出
}

# 輸出亮紫色訊息至 stderr（用於感謝訊息）
purple_msg() {
    printf "\033[1;35m%s\033[0m\n" "$1" >&2  # 亮紫色 ANSI 碼輸出
}

# 輸出青色訊息至 stderr（用於特殊狀態提示）
cyan_msg() {
    printf "\033[1;36m%s\033[0m\n" "$1" >&2  # 青色 ANSI 碼輸出
}

# 輸出黃色訊息至 stderr（用於重要提示）
yellow_msg() {
    printf "\033[1;33m%s\033[0m\n" "$1" >&2  # 粗體黃色 ANSI 碼輸出
}

# 輸出灰色調試訊息至 stderr（受 IS_DEBUG 控制）
debug_msg() {
    [[ "$IS_DEBUG" != "true" ]] && return 0  # 非調試模式則跳過
    printf "\033[0;90m%s\033[0m\n" "$1" >&2  # 灰色 ANSI 碼輸出
}

# 輸出亮綠色高亮成功訊息至 stderr
highlight_success_msg() {
    printf "\033[1;32m%s\033[0m\n" "$1" >&2  # 亮綠色 ANSI 碼輸出
}

# 輸出亮白色訊息至 stderr（用於選單選項）
white_msg() {
    printf "\033[1;37m%s\033[0m\n" "$1" >&2  # 亮白色 ANSI 碼輸出
}

# 輸出青色標籤+一般文字至 stderr（用於資訊標籤）
cyan_label_msg() {
    printf "\033[1;36m%s\033[0m %s\n" "$1" "$2" >&2  # 標籤青色，內容一般
}

# 隨機顯示感謝訊息（內建 13 種訊息）
show_random_thanks() {
    local messages=(
        "讓我們感謝 Jerry，他心情不太好。"
        "讓我們感謝 Jerry，他最近可能有點窮。"
        "讓我們感謝 Jerry，他需要一些鼓勵。請去打星星 https://github.com/lazyjerry/git-auto-push"
        "讓我們感謝 Jerry，他可能在思考一些深奧的問題。"
        "讓我們感謝 Jerry，這些奇怪的結語，可能是他看了《幼女戰記》才會有這個無聊的結尾語。"
        "讓我們感謝 Jerry，他可能正在尋找人生的 11。"
        "讓我們感謝 Jerry，他可能正在尋找 0 感。"
        "讓我們感謝 Jerry，他可能在豬圈裡面找雞會。"
        "讓我們感謝 Jerry，他可能在深奧一些思考的問題。"
        "讓我們感謝 Jerry，他可能在敲碎舊的靈感。"
        "讓我們感謝 Jerry，他最近可能吃太胖，請督促他減肥。"
        "讓我們感謝 Jerry，他可能在尋找新的生活方式。"
        "讓我們感謝 Jerry，好玩一直玩。"
    )
    
    local random_index=$(( $(date +%s) % ${#messages[@]} ))  # 用當前時間選取隨機索引
    local selected_message="${messages[$random_index]}"
    
    echo >&2
    purple_msg "💝 $selected_message"  # 輸出紫色感謝訊息
}

# 執行命令並檢查結果，失敗時顯示錯誤並終止
run_command() {
    local cmd="$1"          # 要執行的命令
    local error_msg="$2"    # 可選的自訂錯誤訊息
    
    if ! eval "$cmd"; then  # 使用 eval 執行命令
        if [ -n "$error_msg" ]; then
            handle_error "$error_msg"
        else
            handle_error "執行命令失敗: $cmd"
        fi
    fi
}

# 檢查當前目錄是否為 Git 倉庫（回傳 0=是，1=否）
check_git_repository() {
    git rev-parse --git-dir >/dev/null 2>&1  # 用 git rev-parse 檢測
}

# 獲取 Git 倉庫狀態（簡潔格式，前兩字元為狀態標記）
get_git_status() {
    git status --porcelain 2>/dev/null  # --porcelain 輸出機器可讀格式
}

# 顯示 Conventional Commits 前綴選單，返回選擇的前綴或 "AUTO"
select_commit_prefix() {
    echo >&2
    echo "==================================================" >&2
    highlight_success_msg "📋 請選擇 Commit 訊息前綴 (Conventional Commits)"
    echo "==================================================" >&2
    
    # 顯示所有可用的前綴選項
    local index=1
    for item in "${COMMIT_PREFIXES[@]}"; do
        local prefix="${item%%:*}"   # 提取前綴
        local desc="${item#*:}"      # 提取說明
        printf "  %2d. %-12s - %s\n" "$index" "$prefix:" "$desc" >&2
        ((index++))
    done
    printf "  %2d. %-12s - %s\n" "$index" "(無前綴)" "跳過前綴選擇" >&2
    
    echo >&2
    cyan_msg "💡 直接按 Enter = AI 自動生成前綴 + commit message"
    echo >&2
    printf "請選擇前綴編號 [1-%d] 或直接 Enter: " "$index" >&2
    read -r choice
    choice=$(echo "$choice" | xargs)
    
    # 直接按 Enter，觸發 AI 自動生成
    if [ -z "$choice" ]; then
        info_msg "🤖 將使用 AI 自動生成前綴和 commit message"
        echo "AUTO"
        return 0
    fi
    
    # 驗證輸入
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$index" ]; then
        warning_msg "❌ 無效的選擇，請輸入 1-$index 之間的數字"
        return 1
    fi
    
    # 選擇「無前綴」
    if [ "$choice" -eq "$index" ]; then
        info_msg "✅ 已跳過前綴選擇"
        echo ""
        return 0
    fi
    
    # 返回選擇的前綴
    local selected_item="${COMMIT_PREFIXES[$((choice-1))]}"
    local selected_prefix="${selected_item%%:*}"
    local selected_desc="${selected_item#*:}"
    
    success_msg "✅ 已選擇前綴: $selected_prefix ($selected_desc)"
    echo "$selected_prefix"
    return 0
}

# 全域變數：記錄最後成功使用的 AI 工具名稱
LAST_AI_TOOL=""

# 依序嘗試多個 AI 工具執行任務，支援容錯機制（返回 0=成功，1=全部失敗）
run_ai_with_fallback() {
    local prompt="$1"                # 提示詞內容
    local show_hints="${2:-false}"   # 是否顯示工具提示
    
    local result=""
    LAST_AI_TOOL=""
    
    for tool_name in "${AI_TOOLS[@]}"; do
        if ! command -v "$tool_name" >/dev/null 2>&1; then
            debug_msg "AI 工具 $tool_name 未安裝，跳過..."
            continue
        fi
        
        # 顯示工具提示（如果啟用）
        if [ "$show_hints" = "true" ]; then
            echo >&2
            info_msg "🤖 即將嘗試使用 AI 工具: $tool_name"
            case "$tool_name" in
                "copilot")
                    info_msg "💡 提醒: Copilot CLI 需要 GitHub Copilot 訂閱，使用 programmatic mode"
                    ;;
                "gemini")
                    warning_msg "💡 提醒: Gemini 除了登入之外，如遇到頻率限制請稍後再試"
                    ;;
                "claude")
                    warning_msg "💡 提醒: Claude 需要登入付費帳號或 API 參數設定"
                    ;;
                "codex")
                    info_msg "💡 提醒: Codex 如果無法連線，請確認登入或 API 參數設定"
                    ;;
            esac
        fi
        
        debug_msg "🔄 正在使用 AI 工具: $tool_name"
        
        case "$tool_name" in
            "copilot")
                if result=$(run_copilot_command "$prompt"); then
                    LAST_AI_TOOL="$tool_name"
                    echo "$result"
                    return 0
                fi
                ;;
            "codex")
                if result=$(run_codex_command "$prompt"); then
                    LAST_AI_TOOL="$tool_name"
                    echo "$result"
                    return 0
                fi
                ;;
            "gemini"|"claude")
                if result=$(run_stdin_ai_command "$tool_name" "$prompt"); then
                    LAST_AI_TOOL="$tool_name"
                    echo "$result"
                    return 0
                fi
                ;;
        esac
        
        debug_msg "$tool_name 執行失敗，嘗試下一個工具..."
    done
    
    return 1
}

# 使用 AI 根據 git diff 自動選擇最適合的 Conventional Commits 前綴
generate_commit_prefix_by_ai() {
    info_msg "🤖 正在使用 AI 工具分析變更並選擇前綴..."
    
    # 取得當前的 git diff
    local diff_content
    diff_content=$(git diff --cached 2>/dev/null)
    
    if [ -z "$diff_content" ]; then
        warning_msg "無法取得 git diff，將跳過前綴選擇"
        echo ""
        return 1
    fi
    
    # 組合 prompt：指令 + diff 內容
    local prompt="${AI_PREFIX_PROMPT}

以下是 git diff 內容：
${diff_content}"
    
    local generated_prefix
    
    # 使用統一的 AI 工具調用
    if generated_prefix=$(run_ai_with_fallback "$prompt" "false"); then
        # 清理 AI 回應：取第一行、移除冒號和多餘空白
        local cleaned_response
        cleaned_response=$(echo "$generated_prefix" | head -n 1 | tr -d ':' | tr '[:upper:]' '[:lower:]' | xargs)
        
        debug_msg "AI 原始回應: '$generated_prefix'"
        debug_msg "清理後回應: '$cleaned_response'"
        
        # 從 COMMIT_PREFIXES 提取前綴並按長度排序（長到短，避免短前綴誤匹配）
        local -a all_prefixes=()
        for item in "${COMMIT_PREFIXES[@]}"; do
            all_prefixes+=("${item%%:*}")
        done
        # 按長度排序：長的優先
        local -a sorted_prefixes
        IFS=$'\n' sorted_prefixes=($(printf '%s\n' "${all_prefixes[@]}" | awk '{print length, $0}' | sort -rn | cut -d' ' -f2-))
        unset IFS
        
        # 比對：檢查清理後的回應是否包含有效前綴
        for prefix in "${sorted_prefixes[@]}"; do
            if [[ "$cleaned_response" == *"$prefix"* ]]; then
                success_msg "✅ AI ($LAST_AI_TOOL) 選擇的前綴: $prefix"
                echo "$prefix"
                return 0
            fi
        done
        
        warning_msg "AI 生成的前綴無效: '$cleaned_response'，將跳過前綴選擇"
    fi
    
    # 如果所有 AI 工具都不可用或失敗
    debug_msg "所有 AI 工具都執行失敗或未生成有效的前綴"
    echo ""
    return 1
}

# 添加所有變更的檔案到 Git 暫存區（回傳 0=成功，1=失敗）
add_all_files() {
    info_msg "正在添加變更的檔案..."
    
    # 檢查是否有變更
    local git_status_output
    git_status_output=$(get_git_status)
    if [[ -z "$git_status_output" ]]; then
        warning_msg "沒有變更的檔案需要添加"
        return 1
    fi
    
    # 執行 git add
    if git add .; then
        success_msg "✅ 成功添加所有變更檔案"
        return 0
    else
        error_msg "❌ 添加檔案時發生錯誤"
        return 1
    fi
}

# 顯示 AI 工具的調試資訊（受 IS_DEBUG 控制）
show_ai_debug_info() {
    [[ "$IS_DEBUG" != "true" ]] && return 0  # 非調試模式則跳過
    
    local tool_name="$1"  # AI 工具名稱
    local prompt="$2"     # 提示詞內容
    local content="$3"    # 實際資料內容（可選）
    local output="$4"     # AI 輸出內容（可選）
    
    debug_msg "📥 AI 輸入（prompt）："
    echo "$prompt" | sed 's/^/  /' >&2
    
    if [ -n "$content" ]; then
        debug_msg "📥 AI 輸入（content，前 10 行）："
        echo "$content" | head -n 10 | sed 's/^/  /' >&2
    fi
    
    if [ -n "$output" ]; then
        debug_msg "💬 $tool_name 輸出："
        echo "$output" | sed 's/^/  /' >&2
    fi
}

# 清理 AI 生成的訊息，移除技術雜訊行
clean_ai_message() {
    local message="$1"
    
    debug_msg "🔍 AI 原始輸出: '$message'"
    
    # 使用管道過濾技術雜訊行（Node.js 警告、認證訊息等）
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
    
    # 對於 codex exec 的輸出，提取有效內容
    if [[ "$message" =~ codex.*tokens\ used ]]; then
        local extracted
        extracted=$(echo "$message" | sed -n '/^codex$/,/^tokens used/p' | sed '1d;$d' | grep -E ".+" | xargs)
        [ -n "$extracted" ] && message="$extracted"
    fi
    
    message=$(echo "$message" | xargs)  # 移除前後空白
    
    debug_msg "🧹 清理後輸出: '$message'"
    
    echo "$message"
}

# 顯示 loading 動畫效果（旋轉動畫+計時）
show_loading() {
    local message="$1"   # 顯示訊息
    local timeout="$2"   # 超時秒數
    local pid="$3"       # 要監控的進程 ID
    
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"  # 旋轉動畫字元
    local i=0
    local start_time=$(date +%s)
    
    printf "\033[?25l" >&2  # 隱藏游標
    
    # 中斷信號處理：清除 loading 行並顯示游標
    loading_cleanup() {
        printf "\r\033[K\033[?25h" >&2
        exit 0
    }
    trap loading_cleanup INT TERM
    
    # 循環顯示動畫直到目標進程結束
    while kill -0 "$pid" 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        printf "\r\033[0;34m%s %s (%d/%d秒)\033[0m" "${spinner:$i:1}" "$message" "$elapsed" "$timeout" >&2
        i=$(( (i + 1) % ${#spinner} ))
        sleep 0.1
    done
    
    printf "\r\033[K\033[?25h" >&2  # 清除 loading 行並顯示游標
    trap - INT TERM
}

# 執行命令並顯示 loading 動畫，支援超時控制與中斷處理
run_command_with_loading() {
    local command="$1"          # 要執行的命令
    local loading_message="$2"  # loading 顯示訊息
    local timeout="$3"          # 超時秒數
    local temp_file
    temp_file=$(mktemp)          # 建立臨時檔儲存輸出
    
    # 中斷清理函數：停止動畫、終止命令、刪除臨時檔、exit 130
    cleanup_and_exit() {
        [ -n "$loading_pid" ] && { kill "$loading_pid" 2>/dev/null; wait "$loading_pid" 2>/dev/null; }  # 停止 loading
        if [ -n "$cmd_pid" ]; then  # 終止命令
            kill -TERM "$cmd_pid" 2>/dev/null
            sleep 0.5
            kill -KILL "$cmd_pid" 2>/dev/null
            wait "$cmd_pid" 2>/dev/null
        fi
        rm -f "$temp_file" "${temp_file}.exit_code"  # 清理臨時檔
        printf "\r\033[K\033[?25h" >&2  # 顯示游標並清理終端
        warning_msg "操作已被用戶中斷"
        exit 130  # SIGINT 標準退出碼
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

# ==============================================
# AI 工具核心執行函數（統一底層邏輯）
# ==============================================

# 執行 AI 工具的核心函數（統一超時、錯誤處理、NODE_OPTIONS 設定）
# 參數：
#   $1 - tool_name: AI 工具名稱 (gemini/claude/codex)
#   $2 - input_file: 輸入檔案路徑
#   $3 - timeout: 超時秒數（預設 45）
#   $4 - use_loading: 是否使用 loading 動畫 (true/false，預設 false)
#   $5 - loading_message: loading 訊息（可選）
# 返回：0=成功，1=失敗
# 輸出：AI 工具的原始輸出（成功時）
_execute_ai_tool() {
    local tool_name="$1"
    local input_file="$2"
    local timeout="${3:-45}"
    local use_loading="${4:-false}"
    local loading_message="${5:-正在等待 $tool_name 回應}"
    
    local output=""
    local exit_code=0
    
    # 根據不同工具使用不同的調用方式
    case "$tool_name" in
        "copilot")
            # copilot 使用 -p (programmatic mode) 參數，-s (silent) 隱藏統計資訊
            # 讀取輸入檔案內容作為 prompt
            local copilot_prompt
            copilot_prompt=$(cat "$input_file")
            if [[ "$use_loading" == "true" ]]; then
                if command -v timeout >/dev/null 2>&1; then
                    output=$(run_command_with_loading "LC_ALL=en_US.UTF-8 timeout ${timeout}s copilot -s -p \"$copilot_prompt\" 2>&1" "$loading_message" "$timeout")
                    exit_code=$?
                else
                    output=$(run_command_with_loading "LC_ALL=en_US.UTF-8 copilot -s -p \"$copilot_prompt\" 2>&1" "$loading_message" "$timeout")
                    exit_code=$?
                fi
            else
                if command -v timeout >/dev/null 2>&1; then
                    output=$(LC_ALL=en_US.UTF-8 timeout ${timeout}s copilot -s -p "$copilot_prompt" 2>&1)
                    exit_code=$?
                else
                    output=$(LC_ALL=en_US.UTF-8 copilot -s -p "$copilot_prompt" 2>&1)
                    exit_code=$?
                fi
            fi
            ;;
        "codex")
            # codex 使用 exec 子命令
            if [[ "$use_loading" == "true" ]]; then
                if command -v timeout >/dev/null 2>&1; then
                    output=$(run_command_with_loading "LC_ALL=en_US.UTF-8 timeout ${timeout}s codex exec < '$input_file' 2>&1" "$loading_message" "$timeout")
                    exit_code=$?
                else
                    output=$(run_command_with_loading "LC_ALL=en_US.UTF-8 codex exec < '$input_file' 2>&1" "$loading_message" "$timeout")
                    exit_code=$?
                fi
            else
                if command -v timeout >/dev/null 2>&1; then
                    output=$(LC_ALL=en_US.UTF-8 timeout ${timeout}s codex exec < "$input_file" 2>&1)
                    exit_code=$?
                else
                    output=$(LC_ALL=en_US.UTF-8 codex exec < "$input_file" 2>&1)
                    exit_code=$?
                fi
            fi
            ;;
        "gemini"|"claude")
            # gemini 和 claude 使用 stdin
            # 使用 NODE_OPTIONS='--no-deprecation' 隱藏 Node.js 棄用警告
            if [[ "$use_loading" == "true" ]]; then
                if command -v timeout >/dev/null 2>&1; then
                    output=$(run_command_with_loading "LC_ALL=en_US.UTF-8 NODE_OPTIONS='--no-deprecation' timeout ${timeout}s $tool_name < '$input_file'" "$loading_message" "$timeout")
                    exit_code=$?
                else
                    output=$(run_command_with_loading "LC_ALL=en_US.UTF-8 NODE_OPTIONS='--no-deprecation' $tool_name < '$input_file'" "$loading_message" "$timeout")
                    exit_code=$?
                fi
            else
                if command -v timeout >/dev/null 2>&1; then
                    output=$(LC_ALL=en_US.UTF-8 NODE_OPTIONS='--no-deprecation' timeout ${timeout}s "$tool_name" < "$input_file" 2>&1)
                    exit_code=$?
                else
                    output=$(LC_ALL=en_US.UTF-8 NODE_OPTIONS='--no-deprecation' "$tool_name" < "$input_file" 2>&1)
                    exit_code=$?
                fi
            fi
            ;;
        *)
            debug_msg "不支援的 AI 工具: $tool_name"
            return 1
            ;;
    esac
    
    # 輸出結果供調用者處理
    echo "$output"
    return $exit_code
}

# 處理 AI 工具執行結果（統一錯誤處理和調試輸出）
# 參數：
#   $1 - tool_name: AI 工具名稱
#   $2 - exit_code: 執行退出碼
#   $3 - output: 執行輸出
#   $4 - prompt: 原始提示詞（用於調試）
#   $5 - timeout: 超時設定（用於調試）
# 返回：0=成功，1=失敗
_handle_ai_result() {
    local tool_name="$1"
    local exit_code="$2"
    local output="$3"
    local prompt="$4"
    local timeout="${5:-45}"
    
    # 確保 exit_code 是有效數字
    if ! [[ "$exit_code" =~ ^[0-9]+$ ]]; then
        exit_code=1
    fi
    
    # 檢查執行結果
    if [ $exit_code -eq 124 ]; then
        error_msg "❌ $tool_name 執行超時（${timeout}秒）"
        
        echo >&2
        debug_msg "🔍 調試信息（$tool_name 超時錯誤）:"
        debug_msg "執行的指令: $tool_name < [input_file]"
        debug_msg "超時設定: $timeout 秒"
        
        if [ -n "$output" ]; then
            show_ai_debug_info "$tool_name" "$prompt" "" "$(echo "$output" | head -n 5)"
        else
            show_ai_debug_info "$tool_name" "$prompt"
            debug_msg "輸出內容: (無)"
        fi
        echo >&2
        return 1
        
    elif [ $exit_code -ne 0 ]; then
        local display_code="${exit_code:-未知}"
        error_msg "❌ $tool_name 執行失敗（退出碼: ${display_code}）"
        
        # 檢查特定錯誤訊息
        if [[ "$output" == *"stdout is not a terminal"* ]] && [[ "$tool_name" == "codex" ]]; then
            warning_msg "💡 codex 需要互動式終端環境"
            warning_msg "💡 已自動使用 'codex exec' 模式，如仍有問題請檢查終端設定"
        elif [[ "$output" == *"401 Unauthorized"* ]] || [[ "$output" == *"token_expired"* ]]; then
            warning_msg "💡 請執行：$tool_name auth login"
        elif [[ "$output" == *"rate limit"* ]] || [[ "$output" == *"quota"* ]]; then
            warning_msg "💡 API 配額已用盡，請稍後再試或檢查訂閱狀態"
        elif [[ "$output" == *"stream error"* ]] || [[ "$output" == *"connection"* ]] || [[ "$output" == *"network"* ]]; then
            warning_msg "💡 請檢查網路連接"
        fi
        
        echo >&2
        debug_msg "🔍 調試信息（$tool_name 執行失敗）:"
        debug_msg "執行的指令: $tool_name < [input_file]"
        debug_msg "退出碼: ${display_code}"
        
        if [ -n "$output" ]; then
            show_ai_debug_info "$tool_name" "$prompt" "" "$output"
        else
            show_ai_debug_info "$tool_name" "$prompt"
            debug_msg "輸出內容: (無)"
        fi
        echo >&2
        return 1
    fi
    
    if [ -z "$output" ]; then
        error_msg "❌ $tool_name 沒有返回內容"
        
        echo >&2
        debug_msg "🔍 調試信息（$tool_name 無輸出）:"
        debug_msg "執行的指令: $tool_name < [input_file]"
        debug_msg "退出碼: $exit_code"
        show_ai_debug_info "$tool_name" "$prompt"
        echo >&2
        return 1
    fi
    
    return 0
}

# 執行 GitHub Copilot CLI 命令（使用 programmatic mode）
# 參數：
#   $1 - prompt: 提示詞內容
# 返回：0=成功，1=失敗
# 輸出：AI 生成的內容（成功時）
run_copilot_command() {
    local prompt="$1"
    local timeout=60
    
    info_msg "正在調用 copilot..."
    
    # 檢查 copilot 是否可用
    if ! command -v copilot >/dev/null 2>&1; then
        warning_msg "copilot 工具未安裝"
        warning_msg "💡 安裝方式: brew install copilot-cli 或 npm install -g @github/copilot"
        return 1
    fi
    
    # 檢查 git diff 大小並調整超時
    local diff_size
    diff_size=$(git diff --cached 2>/dev/null | wc -l)
    if [ "$diff_size" -gt 500 ]; then
        timeout=90
        info_msg "檢測到大型變更（$diff_size 行），增加處理時間到 ${timeout} 秒..."
    fi
    
    # 準備 git diff 內容
    local git_diff
    git_diff=$(git diff --cached 2>/dev/null || git diff 2>/dev/null)
    if [ -z "$git_diff" ]; then
        warning_msg "沒有檢測到任何變更內容"
        return 1
    fi
    
    # 創建臨時檔案存放 prompt（避免 shell 特殊字符問題）
    local temp_prompt
    temp_prompt=$(mktemp)
    printf '%s\n\nGit 變更內容:\n%s' "$prompt" "$git_diff" > "$temp_prompt"
    
    # 使用 run_command_with_loading 執行 copilot 並顯示動態 loading 動畫
    local output=""
    local exit_code=0
    
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "LC_ALL=en_US.UTF-8 timeout ${timeout}s copilot -s -p \"\$(cat '$temp_prompt')\" 2>&1" "正在等待 copilot 分析變更" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "LC_ALL=en_US.UTF-8 copilot -s -p \"\$(cat '$temp_prompt')\" 2>&1" "正在等待 copilot 分析變更" "$timeout")
        exit_code=$?
    fi
    
    # 清理臨時檔案
    rm -f "$temp_prompt"
    
    # 處理執行結果
    case $exit_code in
        0)
            # 成功執行，檢查輸出
            # 清理輸出（移除可能的 ANSI 色碼和多餘空白）
            output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | xargs)
            
            if [ -n "$output" ] && [ ${#output} -gt 3 ]; then
                success_msg "copilot 回應完成"
                echo "$output"
                return 0
            fi
            
            # 沒有有效內容
            warning_msg "copilot 沒有返回有效內容"
            echo >&2
            debug_msg "🔍 調試信息（copilot 無有效輸出）:"
            debug_msg "執行的指令: copilot -p [prompt]"
            debug_msg "退出碼: $exit_code"
            debug_msg "diff 內容大小: $(echo "$git_diff" | wc -l) 行"
            printf "\n" >&2
            ;;
        124)
            error_msg "❌ copilot 執行超時（${timeout}秒）"
            
            echo >&2
            debug_msg "🔍 調試信息（copilot 超時錯誤）:"
            debug_msg "執行的指令: copilot -p [prompt]"
            debug_msg "超時設定: $timeout 秒"
            debug_msg "diff 內容大小: $(echo "$git_diff" | wc -l) 行"
            warning_msg "💡 建議：檢查網路連接或稍後重試"
            printf "\n" >&2
            ;;
        *)
            echo >&2
            debug_msg "🔍 調試信息（copilot 執行失敗）:"
            debug_msg "執行的指令: copilot -p [prompt]"
            debug_msg "退出碼: $exit_code"
            debug_msg "diff 內容大小: $(echo "$git_diff" | wc -l) 行"
            
            if [[ "$output" == *"not logged in"* ]] || [[ "$output" == *"authentication"* ]] || [[ "$output" == *"unauthorized"* ]]; then
                error_msg "❌ copilot 認證錯誤"
                warning_msg "💡 請執行：copilot /login"
            elif [[ "$output" == *"subscription"* ]] || [[ "$output" == *"Copilot"* && "$output" == *"access"* ]]; then
                error_msg "❌ copilot 訂閱問題"
                warning_msg "💡 請確認您的 GitHub Copilot 訂閱狀態"
            elif [[ "$output" == *"rate limit"* ]] || [[ "$output" == *"quota"* ]] || [[ "$output" == *"premium"* ]]; then
                error_msg "❌ copilot 配額限制"
                warning_msg "💡 您的 premium requests 配額可能已用盡，請稍後再試"
            elif [[ "$output" == *"network"* ]] || [[ "$output" == *"connection"* ]]; then
                error_msg "❌ copilot 網路錯誤"
                warning_msg "💡 請檢查網路連接"
            else
                warning_msg "copilot 執行失敗（退出碼: $exit_code）"
                if [ -n "$output" ]; then
                    debug_msg "完整輸出內容:"
                    echo "$output" | sed 's/^/  /' >&2
                fi
            fi
            printf "\n" >&2
            ;;
    esac
    
    return 1
}

# 執行 codex 命令並處理輸出
run_codex_command() {
    local prompt="$1"
    local timeout=60
    
    info_msg "正在調用 codex..."
    
    # 檢查 codex 是否可用
    if ! command -v codex >/dev/null 2>&1; then
        warning_msg "codex 工具未安裝"
        return 1
    fi
    
    # 檢查 git diff 大小並調整超時
    local diff_size
    diff_size=$(git diff --cached 2>/dev/null | wc -l)
    if [ "$diff_size" -gt 500 ]; then
        timeout=90
        info_msg "檢測到大型變更（$diff_size 行），增加處理時間到 ${timeout} 秒..."
    fi
    
    # 準備 git diff 內容
    local git_diff
    git_diff=$(git diff --cached 2>/dev/null || git diff 2>/dev/null)
    if [ -z "$git_diff" ]; then
        warning_msg "沒有檢測到任何變更內容"
        return 1
    fi
    
    # 創建臨時檔案傳遞提示詞
    local temp_prompt
    temp_prompt=$(mktemp)
    printf '%s\n\nGit 變更內容:\n%s' "$prompt" "$git_diff" > "$temp_prompt"
    
    # 創建臨時檔案接收乾淨的輸出
    local temp_output
    temp_output=$(mktemp)
    
    # 執行 codex 命令（使用 --output-last-message 獲取乾淨輸出）
    local raw_output exit_code
    if command -v timeout >/dev/null 2>&1; then
        raw_output=$(run_command_with_loading "timeout $timeout codex exec --output-last-message '$temp_output' < '$temp_prompt' 2>/dev/null" "正在等待 codex 分析變更" "$timeout")
        exit_code=$?
    else
        raw_output=$(run_command_with_loading "codex exec --output-last-message '$temp_output' < '$temp_prompt' 2>/dev/null" "正在等待 codex 分析變更" "$timeout")
        exit_code=$?
    fi
    
    # 讀取乾淨的輸出
    local output=""
    if [ -f "$temp_output" ]; then
        output=$(cat "$temp_output" | xargs)
    fi
    
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
            
            # 沒有有效內容，顯示調試信息
            warning_msg "codex 沒有返回有效內容"
            echo >&2
            debug_msg "🔍 調試信息（codex 無有效輸出）:"
            debug_msg "執行的指令: codex exec --output-last-message [output_file] < [prompt_file]"
            debug_msg "退出碼: $exit_code"
            if [ -n "$raw_output" ]; then
                debug_msg "原始輸出內容:"
                echo "$raw_output" | sed 's/^/  /' >&2
            else
                debug_msg "輸出內容: (無)"
            fi
            debug_msg "diff 內容大小: $(echo "$git_diff" | wc -l) 行"
            printf "\n" >&2
            ;;
        124)
            error_msg "❌ codex 執行超時（${timeout}秒）"
            
            # 顯示調試信息
            echo >&2
            debug_msg "🔍 調試信息（codex 超時錯誤）:"
            debug_msg "執行的指令: codex exec --output-last-message [output_file] < [prompt_file]"
            debug_msg "超時設定: $timeout 秒"
            debug_msg "diff 內容大小: $(echo "$git_diff" | wc -l) 行"
            if [ -n "$raw_output" ]; then
                debug_msg "部分輸出內容:"
                echo "$raw_output" | head -n 5 | sed 's/^/  /' >&2
            else
                debug_msg "輸出內容: (無)"
            fi
            warning_msg "💡 建議：檢查網路連接或稍後重試"
            printf "\n" >&2
            ;;
        *)
            # 檢查特定錯誤類型
            echo >&2
            debug_msg "🔍 調試信息（codex 執行失敗）:"
            debug_msg "執行的指令: codex exec --output-last-message [output_file] < [prompt_file]"
            debug_msg "退出碼: $exit_code"
            debug_msg "diff 內容大小: $(echo "$git_diff" | wc -l) 行"
            
            if [[ "$raw_output" == *"401 Unauthorized"* ]] || [[ "$raw_output" == *"token_expired"* ]]; then
                error_msg "❌ codex 認證錯誤"
                warning_msg "💡 請執行：codex auth login"
                if [ -n "$raw_output" ]; then
                    debug_msg "錯誤輸出:"
                    echo "$raw_output" | sed 's/^/  /' >&2
                fi
            elif [[ "$raw_output" == *"stream error"* ]] || [[ "$raw_output" == *"connection"* ]] || [[ "$raw_output" == *"network"* ]]; then
                error_msg "❌ codex 網路錯誤"
                warning_msg "💡 請檢查網路連接"
                if [ -n "$raw_output" ]; then
                    debug_msg "錯誤輸出:"
                    echo "$raw_output" | sed 's/^/  /' >&2
                fi
            else
                warning_msg "codex 執行失敗（退出碼: $exit_code）"
                if [ -n "$raw_output" ]; then
                    debug_msg "完整輸出內容:"
                    echo "$raw_output" | sed 's/^/  /' >&2
                else
                    debug_msg "輸出內容: (無)"
                fi
            fi
            printf "\n" >&2
            ;;
    esac
    
    return 1
}

# 執行基於 stdin 的 AI 命令（用於 commit 訊息生成，自動獲取 git diff）
# 參數：
#   $1 - tool_name: AI 工具名稱 (gemini/claude)
#   $2 - prompt: 提示詞內容
# 返回：0=成功，1=失敗
# 輸出：AI 生成的內容（成功時）
run_stdin_ai_command() {
    local tool_name="$1"
    local prompt="$2"
    local timeout=45
    
    info_msg "正在調用 $tool_name..."
    
    # 首先檢查工具是否可用
    if ! command -v "$tool_name" >/dev/null 2>&1; then
        warning_msg "$tool_name 工具未安裝"
        return 1
    fi
    
    # 獲取 git diff 內容
    local diff_content
    diff_content=$(git diff --cached 2>/dev/null)
    
    if [ -z "$diff_content" ]; then
        warning_msg "沒有暫存區變更可供 $tool_name 分析"
        return 1
    fi
    
    # 創建臨時檔案：組合 prompt 和 diff 內容
    local temp_input
    temp_input=$(mktemp)
    LC_ALL=en_US.UTF-8 cat > "$temp_input" <<EOF
$prompt

Git 變更內容:
$diff_content
EOF
    
    # 使用核心函數執行 AI 工具（帶 loading 動畫）
    local output exit_code
    output=$(_execute_ai_tool "$tool_name" "$temp_input" "$timeout" "true" "正在等待 $tool_name 回應")
    exit_code=$?
    
    # 清理臨時檔案
    rm -f "$temp_input"
    
    # 使用統一的結果處理函數
    if ! _handle_ai_result "$tool_name" "$exit_code" "$output" "$prompt" "$timeout"; then
        return 1
    fi
    
    success_msg "$tool_name 回應完成"
    echo "$output"
    return 0
}

# 全自動生成 commit message
# 函式：generate_auto_commit_message
# 功能說明：使用 AI 工具自動生成 commit message
# 輸入參數：
#   $1 <silent_mode> 是否為靜默模式（true=不顯示提示，失敗用預設訊息，預設 false）
# 輸出結果：
#   STDOUT 輸出生成的 commit 訊息
# 返回值：
#   0=成功，1=失敗（僅非靜默模式）
# 流程：
#   1. 根據模式顯示不同的資訊提示
#   2. 調用 run_ai_with_fallback 執行 AI 工具
#   3. 清理生成的訊息
#   4. 自動選擇前綴
#   5. 失敗時根據模式返回錯誤或預設訊息
# 副作用：輸出至 stderr（狀態訊息）
# 參考：run_ai_with_fallback()、generate_commit_prefix_by_ai()、clean_ai_message()
generate_auto_commit_message() {
    local silent_mode="${1:-false}"
    local show_hints="true"
    
    if [ "$silent_mode" = "true" ]; then
        info_msg "🤖 全自動模式：正在使用 AI 工具分析變更並生成 commit message..."
        show_hints="false"
    else
        info_msg "正在使用 AI 工具分析變更並生成 commit message..."
    fi
    
    local prompt="$AI_COMMIT_PROMPT"
    local generated_message
    
    # 使用統一的 AI 工具調用
    if generated_message=$(run_ai_with_fallback "$prompt" "$show_hints"); then
        # 清理生成的訊息
        generated_message=$(clean_ai_message "$generated_message")
        
        if [ -n "$generated_message" ] && [ ${#generated_message} -gt 3 ]; then
            # 使用 AI 自動選擇前綴
            [ "$silent_mode" != "true" ] && echo >&2
            local ai_prefix=""
            if ai_prefix=$(generate_commit_prefix_by_ai); then
                if [ -n "$ai_prefix" ]; then
                    generated_message="$ai_prefix: $generated_message"
                    if [ "$silent_mode" = "true" ]; then
                        info_msg "✅ 自動使用 $LAST_AI_TOOL 生成的 commit message (含前綴):"
                    else
                        info_msg "✅ 使用 $LAST_AI_TOOL 生成的 commit message (含前綴):"
                    fi
                else
                    if [ "$silent_mode" = "true" ]; then
                        info_msg "✅ 自動使用 $LAST_AI_TOOL 生成的 commit message:"
                    else
                        info_msg "✅ 使用 $LAST_AI_TOOL 生成的 commit message:"
                    fi
                fi
            else
                if [ "$silent_mode" = "true" ]; then
                    info_msg "✅ 自動使用 $LAST_AI_TOOL 生成的 commit message:"
                else
                    info_msg "✅ 使用 $LAST_AI_TOOL 生成的 commit message:"
                fi
            fi
            highlight_success_msg "🔖 $generated_message"
            
            # 靜默模式需要加上任務編號
            if [ "$silent_mode" = "true" ]; then
                local final_message
                final_message=$(append_ticket_number_to_message "$generated_message")
                echo "$final_message"
            else
                echo "$generated_message"
            fi
            return 0
        else
            warning_msg "⚠️  AI 生成的訊息太短或無效: '$generated_message'"
        fi
    fi
    
    # 失敗處理
    if [ "$silent_mode" = "true" ]; then
        warning_msg "⚠️  所有 AI 工具都執行失敗，使用預設 commit message"
        local default_message="自動提交：更新專案檔案"
        info_msg "🔖 使用預設訊息: $default_message"
        local final_message
        final_message=$(append_ticket_number_to_message "$default_message")
        echo "$final_message"
        return 0
    else
        warning_msg "所有 AI 工具都執行失敗或未生成有效的 commit message"
        info_msg "已嘗試的工具: ${AI_TOOLS[*]}"
        return 1
    fi
}

# 在 commit 訊息中帶入任務編號（根據 AUTO_INCLUDE_TICKET 自動或詢問）
append_ticket_number_to_message() {
    local message="$1"
    
    # 無任務編號則直接返回
    [[ -z "$TICKET_NUMBER" ]] && { echo "$message"; return 0; }
    
    # 已包含任務編號則不重複加入
    [[ "$message" =~ $TICKET_NUMBER ]] && { echo "$message"; return 0; }
    
    # 根據設定決定是否加入任務編號
    if [[ "$AUTO_INCLUDE_TICKET" == "true" ]]; then
        # 自動加入任務編號
        echo "[$TICKET_NUMBER] $message"
    else
        # 詢問使用者是否要加入任務編號
        echo >&2
        cyan_msg "🎫 偵測到任務編號: $TICKET_NUMBER"
        printf "是否在 commit 訊息中加入任務編號前綴？[Y/n]: " >&2
        read -r add_ticket
        add_ticket=$(echo "$add_ticket" | tr '[:upper:]' '[:lower:]' | xargs)
        
        # 預設為同意（直接按 Enter 或輸入確認）
        if [[ -z "$add_ticket" ]] || [[ "$add_ticket" =~ ^(y|yes|是|確認)$ ]]; then
            echo "[$TICKET_NUMBER] $message"
        else
            echo "$message"
        fi
    fi
}

# 顯示 AI 生成的訊息並詢問使用者確認（回傳 0=確認，1=拒絕）
confirm_ai_message() {
    local message="$1"
    local label="${2:-🤖 AI 生成的}"  # 顯示標籤
    
    # 顯示 AI 生成的訊息
    echo >&2
    cyan_msg "$label commit message:"
    highlight_success_msg "🔖 $message"
    
    # 顯示下一步動作選項
    echo >&2
    cyan_msg "💡 下一步動作："
    if [[ "$AUTO_CHECK_COMMIT_QUALITY" == "true" ]]; then
        white_msg "  • 按 Enter 或輸入 y - 使用此訊息並進行品質檢查"
    else
        white_msg "  • 按 Enter 或輸入 y - 使用此訊息（稍後詢問是否檢查品質）"
    fi
    white_msg "  • 輸入 n - 拒絕並手動輸入"
    echo >&2
    
    # 讀取使用者確認
    printf "是否使用此訊息？[Y/n]: " >&2
    read -r confirm
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)
    
    if [ -z "$confirm" ] || [[ "$confirm" =~ ^(y|yes|是|確認)$ ]]; then
        local final_message
        final_message=$(append_ticket_number_to_message "$message")  # 附加任務編號
        echo "$final_message"
        return 0
    fi
    
    return 1
}

# 獲取用戶輸入的 commit message（支援前綴選擇和 AI 生成）
get_commit_message() {
    # 顯示任務編號自動帶入狀態
    if [[ -n "$TICKET_NUMBER" ]]; then
        echo >&2
        if [[ "$AUTO_INCLUDE_TICKET" == "true" ]]; then
            white_msg "🎫 任務編號: $TICKET_NUMBER (將自動加入前綴)"
        else
            white_msg "🎫 任務編號: $TICKET_NUMBER (提交時詢問是否加入)"
        fi
    fi
   
    # 先讓使用者選擇前綴
    local selected_prefix=""
    while true; do
        if selected_prefix=$(select_commit_prefix); then
            break
        fi
        # 選擇失敗，重新選擇
    done
    
    # 如果選擇了 AUTO，直接跳到 AI 自動生成流程
    if [ "$selected_prefix" = "AUTO" ]; then
        info_msg "正在使用 AI 自動生成前綴和 commit message..."
        
        if auto_message=$(generate_auto_commit_message); then
            if final_message=$(confirm_ai_message "$auto_message"); then
                echo "$final_message"
                return 0
            fi
        fi
        
        # AI 生成失敗或用戶拒絕，切換到手動輸入模式
        warning_msg "切換到手動輸入模式..."
        selected_prefix=""
    fi
    
    echo >&2
    echo "==================================================" >&2
    highlight_success_msg "💬 請輸入 commit 訊息"
    echo "==================================================" >&2
    if [ -n "$selected_prefix" ]; then
        cyan_msg "輸入您的 commit 訊息（將自動加上前綴: $selected_prefix:），或直接按 Enter 使用 AI 自動生成"
    else
        cyan_msg "輸入您的 commit 訊息，或直接按 Enter 使用 AI 自動生成"
    fi
    
    echo >&2
    printf "➤ " >&2  # 提供明確的輸入提示符號
    
    read -r message
    message=$(echo "$message" | xargs)  # 去除前後空白
    
    # 如果用戶有輸入內容，加上前綴和任務編號後返回
    if [ -n "$message" ]; then
        # 加上前綴（如果有選擇）
        if [ -n "$selected_prefix" ]; then
            message="$selected_prefix: $message"
        fi
        
        local final_message
        final_message=$(append_ticket_number_to_message "$message")
        echo "$final_message"
        return 0
    fi
    
    # 如果用戶未輸入內容，直接使用 AI 自動生成
    echo >&2
    info_msg "未輸入 commit message，正在使用 AI 自動生成..."
    
    if auto_message=$(generate_auto_commit_message); then
        if final_message=$(confirm_ai_message "$auto_message"); then
            echo "$final_message"
            return 0
        fi
    fi
    
    # 如果 AI 生成失敗或用戶拒絕使用，提供手動輸入選項
    while true; do
        echo >&2
        info_msg "請手動輸入 commit message (或輸入 'q' 取消操作，輸入 'ai' 重新嘗試 AI 生成):"
        read -r manual_message
        manual_message=$(echo "$manual_message" | xargs)
        
        if [ "$manual_message" = "q" ] || [ "$manual_message" = "Q" ]; then
            warning_msg "已取消操作"
            return 1
        elif [ "$manual_message" = "ai" ] || [ "$manual_message" = "AI" ]; then
            # 重新嘗試 AI 生成
            if auto_message=$(generate_auto_commit_message); then
                if final_message=$(confirm_ai_message "$auto_message" "🔄 AI 重新生成的"); then
                    echo "$final_message"
                    return 0
                fi
            else
                warning_msg "AI 生成仍然失敗，請手動輸入"
            fi
        elif [ -n "$manual_message" ]; then
            local final_message
            final_message=$(append_ticket_number_to_message "$manual_message")
            echo "$final_message"
            return 0
        else
            warning_msg "請輸入有效的 commit message，或輸入 'q' 取消，'ai' 重新嘗試 AI 生成"
        fi
    done
}

# 執行簡單的 AI 命令（不需要 git diff），用於品質檢查等場景
# 參數：
#   $1 - tool_name: AI 工具名稱 (gemini/claude/codex)
#   $2 - prompt: 提示詞內容
# 返回：0=成功，1=失敗
# 輸出：AI 生成的內容（成功時，已清理）
run_simple_ai_command() {
    local tool_name="$1"
    local prompt="$2"
    local timeout=45
    
    # 檢查工具是否可用
    if ! command -v "$tool_name" &>/dev/null; then
        debug_msg "$tool_name 工具未安裝"
        return 1
    fi
    
    # 建立臨時檔案（確保 UTF-8 編碼）
    local temp_input
    temp_input=$(mktemp)
    LC_ALL=en_US.UTF-8 cat > "$temp_input" <<EOF
$prompt
EOF
    
    # 使用核心函數執行 AI 工具（不帶 loading 動畫，品質檢查需要快速回應）
    local output exit_code
    output=$(_execute_ai_tool "$tool_name" "$temp_input" "$timeout" "false")
    exit_code=$?
    
    # 清理臨時檔案
    rm -f "$temp_input"
    
    # 使用統一的結果處理函數
    if ! _handle_ai_result "$tool_name" "$exit_code" "$output" "$prompt" "$timeout"; then
        return 1
    fi
    
    # 清理輸出
    output=$(clean_ai_message "$output")
    
    if [ -z "$output" ]; then
        debug_msg "$tool_name 輸出清理後為空"
        return 1
    fi
    
    # 輸出結果
    echo "$output"
    return 0
}

# 使用 AI 檢查 commit 訊息品質（回傳 0=通過或繼續，1=取消）
check_commit_message_quality() {
    local message="$1"
    local should_check=false
    
    # 根據設定決定是否檢查
    if [[ "$AUTO_CHECK_COMMIT_QUALITY" == "true" ]]; then
        should_check=true
    else
        # 詢問使用者是否要檢查（預設 no）
        echo >&2
        printf "是否檢查 commit 訊息品質？[y/N]: " >&2
        read -r check_confirm
        check_confirm=$(echo "$check_confirm" | tr '[:upper:]' '[:lower:]' | xargs)
        
        if [[ "$check_confirm" =~ ^(y|yes|是)$ ]]; then
            should_check=true
        else
            info_msg "ℹ️  跳過品質檢查"
            return 0
        fi
    fi
    
    [[ "$should_check" != "true" ]] && return 0  # 不檢查則直接通過
    
    # 使用 AI 檢查訊息品質
    echo >&2
    info_msg "🔍 正在檢查 commit 訊息品質..."
    
    # 組建檢查提示詞
    local check_prompt="請分析以下 commit 訊息是否具有明確的目的和功能性。

判斷標準：
1. 是否描述了具體的變更內容（新增、修改、刪除了什麼）
2. 是否有明確的目的（為什麼要做這個變更）  
3. 避免過於簡短或模糊的描述（如 update、fix、changes、調整）

Commit 訊息內容：
$message

請只回答以下其中一項：
- 良好：訊息清楚描述了變更內容和目的
- 不良：訊息過於模糊或缺乏明確目的，並簡短說明原因（一行）"
    
    local ai_response=""
    local tool_used=""
    
    # 嘗試使用 AI 工具檢查
    for tool in "${AI_TOOLS[@]}"; do
        if ai_response=$(run_simple_ai_command "$tool" "$check_prompt"); then
            tool_used="$tool"
            success_msg "✓ 使用 $tool 完成品質檢查"
            break
        fi
    done
    
    # AI 檢查失敗則直接通過（不影響提交流程）
    if [[ -z "$ai_response" ]]; then
        warning_msg "⚠️  AI 品質檢查失敗（所有工具都無法使用），將繼續提交流程"
        return 0
    fi
    
    # 分析 AI 回應
    ai_response=$(echo "$ai_response" | xargs)
    
    # 使用更寬鬆的匹配：只要包含「良好」或「Good」即視為通過
    if [[ "$ai_response" =~ 良好 ]] || [[ "$ai_response" =~ [Gg]ood ]] || [[ "$ai_response" =~ GOOD ]]; then
        success_msg "✅ Commit 訊息品質良好"
        return 0
    # 只要包含「不良」、「Bad」或相關負面關鍵字即視為品質不佳
    elif [[ "$ai_response" =~ 不良 ]] || [[ "$ai_response" =~ [Bb]ad ]] || [[ "$ai_response" =~ BAD ]] || [[ "$ai_response" =~ 模糊 ]] || [[ "$ai_response" =~ 不明確 ]] || [[ "$ai_response" =~ 過於簡短 ]]; then
        # 顯示警告
        echo >&2
        warning_msg "⚠️  Commit 訊息品質警告"
        echo "==================================================" >&2
        error_msg "AI 分析結果："
        echo "$ai_response" >&2
        echo "==================================================" >&2
        echo >&2
        
        # 提供明確的選項說明
        cyan_msg "💡 下一步選擇："
        white_msg "  • 輸入 y - 仍然使用此訊息繼續提交"
        white_msg "  • 按 Enter 或輸入 n - 取消並重新輸入更好的訊息"
        echo >&2
        
        # 詢問是否繼續
        printf "是否仍要繼續提交？[y/N]: " >&2
        read -r continue_confirm
        continue_confirm=$(echo "$continue_confirm" | tr '[:upper:]' '[:lower:]' | xargs)
        
        if [[ "$continue_confirm" =~ ^(y|yes|是)$ ]]; then
            info_msg "使用者選擇繼續提交"
            return 0
        else
            # 返回 1 表示品質檢查不通過，主流程會重新要求輸入
            return 1
        fi
    else
        # AI 回應無法判斷，顯示內容並預設通過
        debug_msg "AI 回應內容: $ai_response"
        warning_msg "⚠️  無法判斷訊息品質，將繼續提交流程"
        return 0
    fi
}

# 確認是否要提交變更（含品質檢查），回傳 0=確認，1=取消
confirm_commit() {
    local message="$1"
    
    # 檢查 commit 訊息品質
    if ! check_commit_message_quality "$message"; then
        return 1
    fi
    
    read -r -t 0.1 dummy 2>/dev/null || true  # 清空輸入緩衝區
    
    # 顯示確認訊息
    echo >&2
    echo "==================================================" >&2
    highlight_success_msg "💬 確認提交資訊:"
    echo "Commit Message: $message" >&2
    echo "==================================================" >&2
    
    # 詢問使用者確認
    while true; do
        printf "是否確認提交？[Y/n]: " >&2
        read -r confirm
        confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)
        
        [ -z "$confirm" ] && return 0  # 預設為同意
        [[ "$confirm" =~ ^(y|yes|是|確認)$ ]] && return 0
        [[ "$confirm" =~ ^(n|no|否|取消)$ ]] && return 1
        warning_msg "請輸入 y 或 n（或直接按 Enter 表示同意）"
    done
}

# 提交變更到本地 Git 倉庫（回傳 0=成功，1=失敗）
commit_changes() {
    local message="$1"
    info_msg "正在提交變更..."
    if git commit -m "$message" 2>/dev/null; then
        success_msg "提交成功！"
        return 0
    else
        error_msg "提交失敗"
        return 1
    fi
}

# 將本地變更推送到遠端倉庫（回傳 0=成功，1=失敗）
push_to_remote() {
    info_msg "正在推送到遠端倉庫..."
    
    # 獲取當前分支名稱
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$branch" ]; then
        error_msg "獲取分支名稱失敗"
        return 1
    fi
    branch=$(echo "$branch" | xargs)  # 去除空白
    
    # 推送到遠端
    if git push origin "$branch" 2>/dev/null; then
        success_msg "成功推送到遠端分支: $branch"
        return 0
    else
        error_msg "推送失敗"
        return 1
    fi
}

# 修改最後一次 commit 的訊息（支援任務編號自動帶入）
amend_last_commit() {
    # 檢查是否有尚未 commit 的變更
    local uncommitted_changes
    uncommitted_changes=$(get_git_status)
    
    if [[ -n "$uncommitted_changes" ]]; then
        warning_msg "⚠️  偵測到尚未提交的變更！"
        echo >&2
        error_msg "請先提交或暫存 (stash) 目前的變更，再修改最後一次 commit 訊息。"
        echo >&2
        info_msg "未提交的變更："
        echo "$uncommitted_changes" >&2
        return 1
    fi
    
    # 取得最後一次 commit 訊息
    local last_commit_message
    last_commit_message=$(git log -1 --pretty=%B 2>/dev/null)
    
    if [[ -z "$last_commit_message" ]]; then
        error_msg "無法取得最後一次 commit 訊息，可能沒有任何 commit 歷史。"
        return 1
    fi
    
    # 顯示目前的 commit 訊息供參考
    echo >&2
    echo "==================================================" >&2
    info_msg "📝 目前的 commit 訊息："
    echo "「$last_commit_message」" >&2
    echo "==================================================" >&2
    echo >&2
    
    # 提示使用者輸入新的 commit 訊息
    cyan_msg "💬 請輸入新的 commit 訊息"
    echo "==================================================" >&2
    
    # 顯示任務編號資訊
    if [[ -n "$TICKET_NUMBER" ]]; then
        if [[ "$AUTO_INCLUDE_TICKET" == "true" ]]; then
            white_msg "🎫 任務編號: $TICKET_NUMBER (將自動加入前綴)"
        else
            white_msg "🎫 任務編號: $TICKET_NUMBER (稍後詢問是否加入)"
        fi
        echo >&2
    fi
    
    printf "➤ " >&2
    read -r new_message
    
    # 移除前後空白
    new_message=$(echo "$new_message" | xargs)
    
    if [[ -z "$new_message" ]]; then
        warning_msg "未輸入新的 commit 訊息，操作已取消。"
        return 1
    fi
    
    # 處理任務編號前綴
    local final_message
    final_message=$(append_ticket_number_to_message "$new_message")
    
    # 確認是否修改
    echo >&2
    echo "==================================================" >&2
    highlight_success_msg "🔄 將要修改為："
    echo "「$final_message」" >&2
    echo "==================================================" >&2
    
    if ! confirm_commit "$final_message"; then
        warning_msg "已取消修改 commit 訊息。"
        return 1
    fi
    
    # 執行 git commit --amend
    info_msg "正在修改最後一次 commit 訊息..."
    if git commit --amend -m "$final_message" 2>/dev/null; then
        success_msg "✅ Commit 訊息修改成功！"
        echo >&2
        info_msg "修改後的訊息："
        echo "「$final_message」" >&2
        return 0
    else
        error_msg "❌ 修改 commit 訊息失敗"
        return 1
    fi
}

# 配置變數
DEFAULT_OPTION=1  # 預設選項：1=完整流程, 2=add+commit, 3=僅add

TICKET_NUMBER=""  # 全域任務編號（從分支名稱自動偵測）

# 從當前分支名稱偵測任務編號，設定全域 TICKET_NUMBER 變數
initialize_ticket_number() {
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "")
    
    TICKET_NUMBER=""  # 重置任務編號
    
    # 檢查分支名稱是否包含任務編號格式（JIRA-123、feat-001 等）
    if [[ -n "$current_branch" && "$current_branch" =~ ([A-Z]+-[0-9]+)|([A-Z]{2,}-[0-9]+)|([a-zA-Z0-9]+-[0-9]+) ]]; then
        TICKET_NUMBER="${BASH_REMATCH[0]}"
    fi
}

# 顯示 Git 操作選單（含分支名稱與任務編號）
show_operation_menu() {
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "未知分支")
    
    # 組裝分支資訊
    local branch_info=""
    [[ -n "$TICKET_NUMBER" ]] && branch_info=" 🎫 任務編號: $TICKET_NUMBER"
    
    # 顯示選單
    echo >&2
    echo "==================================================" >&2
    info_msg "請選擇要執行的 Git 操作:"
    echo "==================================================" >&2
    highlight_success_msg "1. 🚀 完整流程 (add → commit → push)"
    warning_msg "2. 📝 本地提交 (add → commit)"
    info_msg "3. 📦 僅添加檔案 (add)"
    purple_msg "4. 🤖 全自動模式 (add → AI commit → push)"
    cyan_msg "5. 💾 僅提交 (commit)"
    white_msg "6. 📊 顯示 Git 倉庫資訊"
    yellow_msg "7. 🔄 變更最後一次 commit 訊息"
    echo "==================================================" >&2
    cyan_msg "🌿 目前分支: $current_branch$branch_info"
    
    # 顯示任務編號自動添加狀態
    if [[ -n "$TICKET_NUMBER" ]]; then
        if [[ "$AUTO_INCLUDE_TICKET" == "true" ]]; then
            white_msg "⚙️  目前任務編號將自動添加至 commit 訊息前綴"
        else
            white_msg "⚙️  目前提交時詢問是否添加任務編號"
        fi
    else
        white_msg "⚙️  沒有偵測到任務編號（ticket number）"
    fi
    
    printf "請輸入選項 [1-7] (直接按 Enter 使用預設選項 %d): " "$DEFAULT_OPTION" >&2
}

# 獲取用戶選擇的操作
get_operation_choice() {
    while true; do
        show_operation_menu
        read -r choice
        choice=$(echo "$choice" | xargs)  # 去除前後空白
        
        # 如果用戶直接按 Enter，使用預設選項
        if [ -z "$choice" ]; then
            choice=$DEFAULT_OPTION
        fi
        
                # 驗證輸入是否有效
        case "$choice" in
            1)
                info_msg "✅ 已選擇：完整流程 (add → commit → push)"
                echo "$choice"
                return 0
                ;;
            2)
                info_msg "✅ 已選擇：本地提交 (add → commit)"
                echo "$choice"
                return 0
                ;;
            3)
                info_msg "✅ 已選擇：僅添加檔案 (add)"
                echo "$choice"
                return 0
                ;;
            4)
                info_msg "✅ 已選擇：全自動模式 (add → AI commit → push)"
                echo "$choice"
                return 0
                ;;
            5)
                info_msg "✅ 已選擇：僅提交 (commit)"
                echo "$choice"
                return 0
                ;;
            6)
                info_msg "✅ 已選擇：顯示 Git 倉庫資訊"
                echo "$choice"
                return 0
                ;;
            7)
                info_msg "✅ 已選擇：變更最後一次 commit 訊息"
                echo "$choice"
                return 0
                ;;
            *)
                warning_msg "無效選項：$choice，請輸入 1-7"
                echo >&2
                ;;
        esac
    done
}

# 顯示詳細的使用說明文檔
show_help() {
    # 讀取當前配置值
    local ai_tools_list="${AI_TOOLS[*]}"
    local default_option="$DEFAULT_OPTION"
    local default_mode_name
    case "$default_option" in
        1) default_mode_name="完整流程 (add → commit → push)" ;;
        2) default_mode_name="本地提交 (add → commit)" ;;
        3) default_mode_name="僅添加檔案 (add)" ;;
        4) default_mode_name="全自動模式 (add → AI commit → push)" ;;
        5) default_mode_name="僅提交 (commit)" ;;
        6) default_mode_name="顯示倉庫資訊" ;;
        7) default_mode_name="變更最後一次 commit 訊息" ;;
        *) default_mode_name="未知" ;;
    esac
    
    echo >&2
    cyan_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    highlight_success_msg "  Git 自動推送工具（傳統工作流程）v2.0.0"
    cyan_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo >&2
    
    purple_msg "📝 用途說明："
    white_msg "  提供完整的 Git 傳統工作流程自動化，從檔案暫存（add）到遠端推送（push）。"
    white_msg "  支援 AI 輔助生成 commit 訊息，提供互動式選單與全自動模式。"
    white_msg "  適用於個人開發與小型團隊的日常 Git 操作自動化需求。"
    echo >&2
    
    purple_msg "🚀 使用方式："
    cyan_msg "  互動模式：    ./git-auto-push.sh"
    cyan_msg "  全自動模式：  ./git-auto-push.sh --auto 或 -a"
    cyan_msg "  直接執行：    ./git-auto-push.sh <1-7>"
    cyan_msg "                例如：./git-auto-push.sh 1  # 直接執行完整流程"
    cyan_msg "                例如：./git-auto-push.sh 4  # 直接執行全自動模式"
    cyan_msg "  顯示說明：    ./git-auto-push.sh -h 或 --help"
    cyan_msg "  全域使用：    git-auto-push"
    echo >&2
    
    purple_msg "📋 七種操作模式："
    echo >&2
    
    highlight_success_msg "  1️⃣  完整流程 (add → commit → push)"
    white_msg "      • 選擇性添加變更到暫存區（支援檔案過濾）"
    white_msg "      • 支援手動輸入或 AI 生成 commit 訊息"
    white_msg "      • 提交到本地倉庫後推送至遠端"
    white_msg "      • 適用場景：日常開發的標準流程"
    echo >&2
    
    info_msg "  2️⃣  本地提交 (add → commit)"
    white_msg "      • 選擇性添加變更到暫存區（支援檔案過濾）"
    white_msg "      • 支援手動輸入或 AI 生成 commit 訊息"
    white_msg "      • 僅提交到本地倉庫，不推送"
    white_msg "      • 適用場景：離線開發、需多次本地提交後再推送"
    echo >&2
    
    cyan_msg "  3️⃣  僅添加變更 (add)"
    white_msg "      • 選擇性將變更暫存（自動過濾符合規則的檔案）"
    white_msg "      • 不執行 commit 或 push"
    white_msg "      • 適用場景：暫存變更但尚未準備好提交"
    echo >&2
    
    purple_msg "  4️⃣  全自動流程 (add → AI commit → push)"
    white_msg "      • 完全無需手動輸入，AI 自動生成 commit 訊息"
    white_msg "      • 自動完成選擇性 add → commit → push 全流程（支援檔案過濾）"
    white_msg "      • 適用場景：CI/CD 整合、快速提交小型變更"
    white_msg "      • 使用方式：./git-auto-push.sh --auto"
    echo >&2
    
    warning_msg "  5️⃣  僅提交 (commit)"
    white_msg "      • 針對已暫存的變更執行提交"
    white_msg "      • 支援手動輸入或 AI 生成 commit 訊息"
    white_msg "      • 不推送至遠端"
    white_msg "      • 適用場景：分階段暫存與提交"
    echo >&2
    
    info_msg "  6️⃣  顯示倉庫資訊"
    white_msg "      • 顯示當前分支名稱"
    white_msg "      • 顯示遠端倉庫 URL 與追蹤狀態"
    white_msg "      • 顯示最近 5 次 commit 記錄"
    white_msg "      • 顯示本地與遠端的同步狀態"
    white_msg "      • 顯示工作區狀態（已修改/未追蹤檔案）"
    white_msg "      • 適用場景：檢查倉庫狀態、診斷同步問題"
    echo >&2
    
    yellow_msg "  7️⃣  變更最後一次 commit 訊息"
    white_msg "      • 修改最近一次的 commit 訊息內容"
    white_msg "      • 自動檢查是否有未提交的變更（有則警告並中止）"
    white_msg "      • 顯示目前的 commit 訊息供參考"
    white_msg "      • 支援任務編號自動帶入功能"
    white_msg "      • 使用 git commit --amend 執行修改"
    white_msg "      • 適用場景：修正 commit 訊息錯誤、補充說明"
    white_msg "      • ⚠️  注意：請勿修改已推送至遠端的 commit"
    echo >&2
    
    purple_msg "🔧 相依工具："
    highlight_success_msg "  必需："
    white_msg "    • bash >= 4.0       腳本執行環境"
    white_msg "    • git >= 2.0        版本控制操作"
    echo >&2
    
    cyan_msg "  支援 AI 工具（可設定選項）："
    white_msg "    • codex             OpenAI Codex CLI"
    white_msg "    • gemini            Google Gemini CLI"
    white_msg "    • claude            Anthropic Claude CLI"
    echo >&2
    
    info_msg "  安裝方式："
    white_msg "    # Git 通常已預裝，若無請使用套件管理器安裝"
    cyan_msg "    brew install git                   # macOS"
    echo >&2
    white_msg "    # AI 工具為可選，請參考各自的安裝文檔"
    white_msg "    # 未安裝 AI 工具時會降級至手動輸入 commit 訊息"
    echo >&2
    
    purple_msg "⚙️  目前配置："
    cyan_msg "  預設操作模式："
    white_msg "    選項編號：${default_option}"
    white_msg "    模式名稱：${default_mode_name}"
    white_msg "    修改方式：腳本中 DEFAULT_OPTION 變數（約 674 行）"
    white_msg "    說明：互動模式下直接按 Enter 會執行此模式"
    echo >&2
    
    cyan_msg "  AI 工具順序："
    white_msg "    當前設定：${ai_tools_list}"
    white_msg "    修改方式：腳本頂部 AI_TOOLS 陣列（約 28-32 行）"
    white_msg "    執行邏輯：依序嘗試，失敗時自動切換下一個"
    white_msg "    超時設定：基準 45 秒，大型 diff（>500行）延長至 90 秒"
    echo >&2
    
    cyan_msg "  AI 提示詞模板："
    white_msg "    位置：腳本頂部 AI_COMMIT_PROMPT 常數（約 118 行）"
    white_msg "    用途：定義 AI 生成 commit 訊息的風格與格式"
    white_msg "    修改：可自訂提示詞以符合團隊 commit 規範"
    white_msg "    範例輸出：新增用戶登入功能、修正檔案上傳錯誤"
    echo >&2
    
    cyan_msg "  任務編號自動帶入："
    white_msg "    當前設定：AUTO_INCLUDE_TICKET=${AUTO_INCLUDE_TICKET}"
    white_msg "    位置：腳本頂部 AUTO_INCLUDE_TICKET 變數（約 131 行）"
    white_msg "    功能說明："
    if [[ "$AUTO_INCLUDE_TICKET" == "true" ]]; then
        white_msg "      ✓ 自動模式：偵測到任務編號時自動加入 commit 訊息前綴"
        white_msg "      ✓ 格式範例：[feat-001] 新增用戶登入功能"
    else
        white_msg "      ✓ 詢問模式：偵測到任務編號時詢問是否加入前綴"
        white_msg "      ✓ 使用者可選擇加入或保持原始訊息"
    fi
    white_msg "    支援格式：JIRA-123、PROJ-456、feat-001 等"
    white_msg "    適用場景：團隊規範、專案管理工具整合"
    echo >&2
    
    cyan_msg "  Commit 訊息品質檢查："
    white_msg "    當前設定：AUTO_CHECK_COMMIT_QUALITY=${AUTO_CHECK_COMMIT_QUALITY}"
    white_msg "    位置：腳本頂部 AUTO_CHECK_COMMIT_QUALITY 變數（約 133 行）"
    white_msg "    功能說明："
    if [[ "$AUTO_CHECK_COMMIT_QUALITY" == "true" ]]; then
        white_msg "      ✓ 自動檢查模式：提交前自動使用 AI 檢查訊息品質"
        white_msg "      ✓ 檢查標準：描述具體變更、明確目的、避免模糊描述"
        white_msg "      ✓ 範例警告：'fix bug'（過於簡略）、'update'（缺乏目的）"
    else
        white_msg "      ✓ 詢問模式：提交前詢問是否使用 AI 檢查（預設 N）"
        white_msg "      ✓ 使用者可選擇檢查或跳過，不影響快速提交流程"
    fi
    white_msg "    檢查工具：依 AI_TOOLS 順序使用（copilot/gemini/codex/claude）"
    white_msg "    容錯機制：AI 失敗時不影響提交流程"
    white_msg "    適用場景：提升 commit 訊息品質、團隊規範執行"
    echo >&2
    
    purple_msg "🔐 安全機制："
    white_msg "  • 變更檢查：執行前檢查是否有待提交的變更"
    white_msg "  • 中斷處理：Ctrl+C 安全中斷並清理資源"
    white_msg "  • 超時控制：AI 工具調用有超時機制（45-90 秒）"
    white_msg "  • 品質檢查：提交前可選擇使用 AI 檢查 commit 訊息品質"
    white_msg "  • 確認機制：提交前顯示 commit 訊息供確認"
    white_msg "  • 權限控制：不需要 root 權限，僅操作當前倉庫"
    echo >&2
    
    purple_msg "📤 退出碼："
    highlight_success_msg "  0     成功完成操作"
    error_msg "  1     一般錯誤（參數錯誤、Git 操作失敗、使用者取消）"
    warning_msg "  130   使用者中斷（Ctrl+C）"
    echo >&2
    
    purple_msg "💡 使用技巧："
    white_msg "  • 離線模式：模式 2、3、5 不需要網路連線"
    white_msg "  • AI 失敗降級：所有 AI 工具失敗時自動切換手動輸入"
    white_msg "  • 空白輸入觸發 AI：在 commit 訊息提示時直接按 Enter 會調用 AI"
    white_msg "  • 全自動模式：使用 --auto 參數跳過所有互動提示"
    white_msg "  • 倉庫診斷：使用模式 6 快速檢查同步狀態與 commit 歷史"
    white_msg "  • 任務編號整合：使用符合格式的分支名稱自動關聯任務"
    white_msg "  • 彈性配置：可隨時切換任務編號自動/詢問模式"
    echo >&2
    
    purple_msg "📚 參考文檔："
    cyan_msg "  • Git 使用說明：       docs/git-usage.md"
    cyan_msg "  • Git 倉庫資訊功能：   docs/git-info-feature.md"
    cyan_msg "  • 專案 README：        README.md"
    cyan_msg "  • Conventional Commits：https://www.conventionalcommits.org/"
    echo >&2
    
    purple_msg "💡 使用範例："
    white_msg "  # 互動式執行（推薦）"
    cyan_msg "  ./git-auto-push.sh"
    echo >&2
    white_msg "  # 全自動模式（CI/CD 整合）"
    cyan_msg "  ./git-auto-push.sh --auto"
    echo >&2
    white_msg "  # 顯示幫助"
    cyan_msg "  ./git-auto-push.sh --help"
    echo >&2
    white_msg "  # 安裝為全域命令"
    cyan_msg "  sudo install -m 755 git-auto-push.sh /usr/local/bin/git-auto-push"
    cyan_msg "  git-auto-push"
    echo >&2
    
    purple_msg "📧 作者：Lazy Jerry"
    purple_msg "🔗 倉庫：https://github.com/lazyjerry/git-auto-push"
    purple_msg "📜 授權：MIT License"
    echo >&2
    
    cyan_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo >&2
}

# 主函數 - Git 傳統工作流程自動化執行引擎
main() {
    # 設置全局信號處理：清理終端並顯示游標
    global_cleanup() {
        printf "\r\033[K\033[?25h" >&2
        warning_msg "程序被用戶中斷，正在清理..."
        exit 130  # SIGINT 標準退出碼
    }
    trap global_cleanup INT TERM

    # 處理 version 參數
    if [ "$1" = "-v" ] || [ "$1" = "--version" ]; then
        echo "git-auto-push ${VERSION}"
        exit 0
    fi

    # 處理 help 參數
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi

    warning_msg "使用前請確認 git 指令與 AI CLI 工具能夠在您的命令提示視窗中執行。"
    
    # 解析命令行參數
    local auto_mode=false
    local direct_option=""
    
    case "$1" in
        --auto|-a)
            auto_mode=true
            info_msg "🤖 命令行啟用全自動模式"
            ;;
        1|2|3|4|5|6|7)
            direct_option="$1"
            info_msg "🎯 命令行直接執行選項 $1"
            ;;
    esac
    
    info_msg "Git 自動添加推送到遠端倉庫工具"
    echo "=================================================="
    
    # 檢查是否為 Git 倉庫
    check_git_repository || handle_error "當前目錄不是 Git 倉庫！請在 Git 倉庫目錄中執行此腳本。"
    
    # 初始化任務編號
    initialize_ticket_number
    
    # 檢查是否有變更需要提交
    local status
    status=$(get_git_status)
    
    if [ -z "$status" ]; then
        info_msg "沒有需要提交的變更。"
        
        # 非自動模式：顯示選單
        if [ "$auto_mode" != true ]; then
            echo >&2
            info_msg "您可以選擇："
            white_msg "  • 推送本地提交到遠端 (按 p)"
            white_msg "  • 修改最後一次 commit 訊息 (按 7)"
            white_msg "  • 查看倉庫資訊 (按 6)"
            white_msg "  • 或按其他鍵取消"
            echo >&2
            printf "請選擇操作 [p/7/6/取消]: " >&2
            read -r choice
            choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]' | xargs)
            
            case "$choice" in
                p|push) push_to_remote && success_msg "🎉 推送完成！" || { warning_msg "❌ 推送失敗"; exit 1; }; exit 0 ;;
                7|amend) amend_last_commit; exit 0 ;;
                6|info) show_git_info; exit 0 ;;
                *) info_msg "已取消操作。"; exit 0 ;;
            esac
        fi
        
        # 自動模式：詢問是否推送
        printf "是否嘗試將本地提交推送到遠端倉庫？[Y/n]: " >&2
        read -r push_confirm
        push_confirm=$(echo "$push_confirm" | tr '[:upper:]' '[:lower:]' | xargs)
        
        if [ -z "$push_confirm" ] || [[ "$push_confirm" =~ ^(y|yes|是|確認)$ ]]; then
            push_to_remote && success_msg "🎉 推送完成！" || { warning_msg "❌ 推送失敗"; exit 1; }
        else
            info_msg "已取消推送操作。"
        fi
        exit 0
    fi
    
    # 顯示檢測到的變更
    info_msg "檢測到以下變更:"
    echo "$status"
    
    # 添加所有變更到暫存區
    add_all_files || exit 1
    
    # 自動模式：直接執行全自動工作流程
    if [ "$auto_mode" = true ]; then
        execute_auto_workflow
        trap - INT TERM
        return
    fi
    
    # 獲取操作選擇
    local operation_choice
    if [ -n "$direct_option" ]; then
        operation_choice="$direct_option"
        info_msg "✅ 直接執行選項 $operation_choice"
    else
        operation_choice=$(get_operation_choice) || exit 1
    fi
    
    # 根據選擇執行對應操作
    case "$operation_choice" in
        1) execute_full_workflow ;;    # 完整流程
        2) execute_local_commit ;;     # 本地提交
        3) execute_add_only ;;         # 僅添加檔案
        4) execute_auto_workflow ;;    # 全自動模式
        5) execute_commit_only ;;      # 僅提交
        6) show_git_info ;;            # 顯示倉庫資訊
        7) amend_last_commit ;;        # 變更 commit 訊息
    esac
    
    trap - INT TERM  # 清理信號處理
}

# 執行完整的 Git 工作流程：add → commit → push
execute_full_workflow() {
    info_msg "🚀 執行完整 Git 工作流程..."
    
    # 獲取 commit message 並確認（支援重新輸入）
    local message
    while true; do
        message=$(get_commit_message) || exit 1
        confirm_commit "$message" && break
        
        echo >&2
        warning_msg "⚠️  已取消本次提交"
        info_msg "💡 請重新輸入 commit 訊息"
        echo >&2
    done
    
    # 提交並推送
    commit_changes "$message" || exit 1
    push_to_remote || exit 1
    
    # 完成提示
    echo >&2
    echo "==================================================" >&2
    success_msg "🎉 完整工作流程執行完成！"
    echo "==================================================" >&2
    show_random_thanks
}

# 函式：execute_local_commit
# 功能說明：執行本地 Git 提交流程，包含 add → commit，不推送到遠端。
# 輸入參數：無
# 輸出結果：
#   STDERR 輸出各階段進度訊息與結果
# 例外/失敗：
#   1=使用者取消或任一步驟失敗
# 流程：
#   1. 顯示本地提交開始訊息
#   2. 調用 get_commit_message() 獲取或生成 commit 訊息
#   3. 調用 confirm_commit() 確認使用者是否要提交
#   4. 調用 commit_changes() 提交變更到本地倉庫
#   5. 顯示完成訊息與後續操作建議
#   6. 顯示隨機感謝語
# 副作用：
#   - 修改本地 Git 倉庫狀態（commit）
#   - 不影響遠端倉庫
#   - 輸出至 stderr
# 參考：get_commit_message()、confirm_commit()、commit_changes()
execute_local_commit() {
    info_msg "📝 執行本地 Git 提交..."
    
    # 步驟 1-2: 獲取 commit message 並確認（支援重新輸入）
    local message
    while true; do
        # 步驟 1: 獲取用戶輸入的 commit message（支援互動輸入或 AI 生成）
        if ! message=$(get_commit_message); then
            exit 1
        fi
        
        # 步驟 2: 確認是否要提交（包含品質檢查）
        if confirm_commit "$message"; then
            break  # 確認成功，跳出循環繼續提交
        fi
        
        # 品質檢查失敗或使用者取消，提示重新輸入
        echo >&2
        warning_msg "⚠️  已取消本次提交"
        info_msg "💡 請重新輸入 commit 訊息"
        echo >&2
    done
    
    # 步驟 3: 提交變更到本地倉庫（執行 git commit，不執行 push）
    if ! commit_changes "$message"; then
        exit 1
    fi
    
    # 完成提示
    echo >&2
    echo "==================================================" >&2
    success_msg "📋 本地提交完成！"
    info_msg "💡 提示：如需推送到遠端，請使用 'git push' 或重新運行腳本選擇選項 1"
    echo "==================================================" >&2
    
    # 顯示隨機感謝訊息
    show_random_thanks
}

# 執行僅添加檔案操作（add 已在主流程完成）
execute_add_only() {
    info_msg "📦 僅執行檔案添加操作..."
    
    # 完成提示
    echo >&2
    echo "==================================================" >&2
    success_msg "📁 檔案添加完成！"
    info_msg "💡 提示：檔案已添加到暫存區，如需提交請使用 'git commit' 或重新運行腳本選擇選項 2"
    echo "==================================================" >&2
    
    # 顯示隨機感謝訊息
    show_random_thanks
}

# 執行僅提交操作（對已暫存的變更進行 commit）
execute_commit_only() {
    info_msg "💾 執行僅提交操作..."
    
    # 檢查是否有已暫存的變更
    local staged_changes
    staged_changes=$(git diff --cached --name-only 2>/dev/null)
    
    if [ -z "$staged_changes" ]; then
        warning_msg "沒有已暫存的變更可提交。請先使用 'git add' 添加檔案，或選擇其他選項。"
        exit 0
    fi
    
    # 顯示已暫存的變更
    info_msg "已暫存的變更:"
    git diff --cached --name-only >&2
    
    # 獲取 commit message 並確認
    local message
    while true; do
        message=$(get_commit_message) || exit 1
        confirm_commit "$message" && break
        
        echo >&2
        warning_msg "⚠️  已取消本次提交"
        info_msg "💡 請重新輸入 commit 訊息"
        echo >&2
    done
    
    # 提交變更
    commit_changes "$message" || exit 1
    
    # 完成提示
    echo >&2
    echo "==================================================" >&2
    success_msg "💾 提交完成！"
    info_msg "💡 提示：如需推送到遠端，請使用 'git push' 或重新運行腳本選擇選項 1"
    echo "==================================================" >&2
    show_random_thanks
}

# 顯示 Git 倉庫詳細資訊（分支、遠端、提交歷史等）
show_git_info() {
    info_msg "📊 正在收集 Git 倉庫資訊..."
    echo >&2
    echo "==================================================" >&2
    success_msg "📍 Git 倉庫資訊"
    echo "==================================================" >&2
    
    # 1. 當前分支
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "未知")
    cyan_label_msg "🌿 當前分支:" "$current_branch"
    
    # 2. 倉庫根目錄
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "未知")
    cyan_label_msg "📂 倉庫路徑:" "$repo_root"
    
    echo >&2
    
    # 3. 遠端倉庫資訊
    info_msg "🌐 遠端倉庫:"
    local remotes
    remotes=$(git remote -v 2>/dev/null)
    if [ -n "$remotes" ]; then
        echo "$remotes" | while IFS= read -r line; do
            printf "   %s\n" "$line" >&2
        done
    else
        warning_msg "   ⚠️  未配置遠端倉庫"
    fi
    
    echo >&2
    
    # 4. 當前分支的上游追蹤資訊
    local upstream_branch
    upstream_branch=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    if [ -n "$upstream_branch" ]; then
        cyan_label_msg "🔗 追蹤分支:" "$upstream_branch"
        
        # 檢查本地與遠端的同步狀態
        local ahead behind
        ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
        
        highlight_success_msg "📈 同步狀態:\033[0m "
        if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
            highlight_success_msg "✅ 已同步"
        else
            if [ "$ahead" -gt 0 ]; then
                warning_msg "⬆️  領先 $ahead 個提交"
            fi
            if [ "$behind" -gt 0 ]; then
                warning_msg "⬇️  落後 $behind 個提交"
            fi
        fi
    else
        warning_msg "🔗 追蹤分支: ⚠️  未設置上游分支"
    fi
    
    echo >&2
    
    # 5. 分支來源資訊（如果有的話）
    info_msg "🌳 分支歷史:"
    local branch_point
    # 嘗試找出當前分支是從哪個分支分出來的
    if [ "$current_branch" != "master" ] && [ "$current_branch" != "main" ]; then
        # 找出最近的共同祖先
        local main_branch
        if git show-ref --verify --quiet refs/heads/main; then
            main_branch="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            main_branch="master"
        fi
        
        if [ -n "$main_branch" ]; then
            branch_point=$(git merge-base "$current_branch" "$main_branch" 2>/dev/null)
            if [ -n "$branch_point" ]; then
                local branch_commit_msg
                branch_commit_msg=$(git log --oneline -1 "$branch_point" 2>/dev/null)
                highlight_success_msg "   從 $main_branch 分支分出"
                printf "   分支點: %s\n" "$branch_commit_msg" >&2
            fi
        fi
    else
        printf "   當前在主分支上\n" >&2
    fi
    
    echo >&2
    
    # 6. 最近的 commit
    info_msg "📝 最近提交:"
    local recent_commits
    recent_commits=$(git log --oneline -5 --decorate --color=always 2>/dev/null)
    if [ -n "$recent_commits" ]; then
        echo "$recent_commits" | while IFS= read -r line; do
            printf "   %s\n" "$line" >&2
        done
    else
        warning_msg "   ⚠️  尚無提交記錄"
    fi
    
    echo >&2
    
    # 7. 工作區狀態
    info_msg "📋 工作區狀態:"
    local status_output
    status_output=$(get_git_status)
    if [ -n "$status_output" ]; then
        warning_msg "   有未提交的變更:"
        echo "$status_output" | while IFS= read -r line; do
            printf "   %s\n" "$line" >&2
        done
    else
        highlight_success_msg "   ✅ 工作區乾淨"
    fi
    
    echo "==================================================" >&2
    
    # 顯示隨機感謝訊息
    show_random_thanks
}

# 執行全自動工作流程：add → AI commit → push
execute_auto_workflow() {
    info_msg "🤖 執行全自動 Git 工作流程..."
    info_msg "💡 提示：全自動模式將使用 AI 生成 commit message 並自動完成所有步驟"
    
    # 使用 AI 自動生成 commit message
    local message
    if ! message=$(generate_auto_commit_message "true"); then
        message="自動提交：更新專案檔案"
        warning_msg "⚠️  使用預設 commit message: $message"
    fi
    
    # 顯示 commit message
    echo >&2
    echo "==================================================" >&2
    info_msg "🤖 全自動提交資訊:"
    cyan_msg "📝 Commit Message: $message"
    echo "==================================================" >&2
    
    # 提交並推送
    commit_changes "$message" || exit 1
    push_to_remote || exit 1
    
    # 完成提示
    echo >&2
    echo "==================================================" >&2
    success_msg "🎉 全自動工作流程執行完成！"
    info_msg "📊 執行摘要："
    info_msg "   ✅ 檔案已添加到暫存區"
    info_msg "   ✅ 使用 AI 生成 commit message"
    info_msg "   ✅ 變更已提交到本地倉庫"
    info_msg "   ✅ 變更已推送到遠端倉庫"
    echo "==================================================" >&2
    show_random_thanks
}

# 當腳本直接執行時，調用主函數開始 Git 工作流程
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
