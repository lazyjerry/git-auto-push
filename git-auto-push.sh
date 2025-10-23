#!/bin/bash
# -*- coding: utf-8 -*-

# 腳本用途：
#   提供完整的 Git 傳統工作流程自動化，從檔案暫存（add）到遠端推送（push）。
#   支援 AI 輔助生成 commit 訊息，提供互動式選單與全自動模式。
#   適用於個人開發與小型團隊的日常 Git 操作自動化需求。
#
# 使用方式：
#   互動模式：    ./git-auto-push.sh
#   全自動模式：  ./git-auto-push.sh --auto 或 -a
#   顯示說明：    ./git-auto-push.sh -h 或 --help
#   全域使用：    git-auto-push（需先將腳本連結至 PATH）
#
# 六種操作模式：
#   1. 完整流程 - add → commit → push（預設操作）
#   2. 本地提交 - add → commit（不推送至遠端）
#   3. 僅添加變更 - git add -A（僅暫存檔案）
#   4. 全自動流程 - add → AI commit → push（無互動）
#   5. 僅提交 - commit（僅針對已暫存的檔案）
#   6. 顯示倉庫資訊 - 顯示分支、遠端、狀態等詳細資訊
#
# 相依工具：
#   bash>=4.0       必需，腳本執行環境
#   git>=2.0        必需，版本控制操作
#   codex/gemini/claude  可選，AI CLI 工具，用於自動生成 commit 訊息
#
# 權限與安全：
#   - 不需要 root 權限
#   - 會讀取當前目錄的 Git 倉庫配置與狀態
#   - 會執行 git 指令進行 add、commit、push 操作
#   - 會透過網路推送至 Git 遠端倉庫（如 GitHub、GitLab）
#   - AI 工具可能透過網路呼叫 API（視工具而定）
#
# 輸入來源：
#   - CLI 參數：--auto/-a（全自動模式）、-h/--help（顯示說明）
#   - 環境變數：無特定環境變數需求，使用 Git 預設配置
#   - STDIN：互動式輸入（選單選項、commit 訊息、確認提示等）
#   - 設定檔：無外部設定檔，使用 Git 配置（~/.gitconfig、.git/config）
#
# 輸出結果：
#   - STDOUT：無資料輸出（所有訊息均輸出至 STDERR）
#   - STDERR：所有狀態訊息、錯誤訊息、互動提示、彩色輸出
#   - 格式：UTF-8 編碼，ANSI 彩色碼
#
# 退出碼表：
#   0   成功完成操作
#   1   一般錯誤（參數錯誤、Git 操作失敗、使用者取消等）
#   130 使用者中斷（Ctrl+C）
#
# 主要流程：
#   1. 初始化與環境檢查（驗證 Git 倉庫、檢查是否有變更）
#   2. 解析命令列參數（--auto/-a 進入全自動模式）
#   3. 互動模式：顯示操作選單並接收使用者選擇
#   4. 全自動模式：直接執行 add → AI commit → push
#   5. 根據選擇執行對應工作流程：
#      - 模式 1：add -A → 輸入/AI 生成 commit → commit → push
#      - 模式 2：add -A → 輸入/AI 生成 commit → commit（不 push）
#      - 模式 3：add -A（僅暫存）
#      - 模式 4：add -A → AI 生成 commit → commit → push（無互動）
#      - 模式 5：輸入 commit 訊息 → commit（針對已暫存檔案）
#      - 模式 6：顯示分支、遠端、狀態等倉庫資訊
#   6. 輸出操作結果與後續建議
#   7. 清理暫存資源並退出
#
# 注意事項：
#   - AI 工具調用有 45 秒超時機制，失敗時會自動切換至下一個工具
#   - 所有 AI 工具都失敗時，會降級至手動輸入 commit 訊息
#   - git push 操作需要遠端倉庫推送權限（SSH key 或 HTTPS 認證）
#   - diff 超過 500 行時，AI 工具超時時間會自動延長至 90 秒
#   - 全自動模式（--auto）會跳過所有確認提示，建議謹慎使用
#   - 腳本會檢測 Git 倉庫狀態，無變更時會提示並退出
#   - 時區假設：使用系統本地時區
#   - 支援離線模式：模式 2、3、5 不需要網路連線
#
# 參考：
#   - Git 使用說明：docs/git-usage.md
#   - Git 倉庫資訊功能：docs/git-info-feature.md
#   - Conventional Commits：https://www.conventionalcommits.org/
#
# 作者：Lazy Jerry
# 版本：v1.5.0
# 最後更新：2025-10-24
# 授權：MIT License
# 倉庫：https://github.com/lazyjerry/git-auto-push
#

# ==============================================
# AI 工具配置區域
# ==============================================

# AI 工具優先順序配置
# 說明：定義 AI 工具的調用順序，當前一個工具失敗時會自動嘗試下一個。
#       腳本會依陣列順序逐一調用，直到成功或全部失敗。
# 修改方式：調整陣列元素順序或新增其他 AI CLI 工具名稱（需系統已安裝）
# 工具特性：
#   - codex：通常較穩定，建議優先使用
#   - gemini：可能有網路或認證問題，需配置 API key
#   - claude：需要登入認證或 API 設定
# 範例：
#   readonly AI_TOOLS=("codex")                    # 僅使用 codex
#   readonly AI_TOOLS=("gemini" "codex" "claude")  # 調整優先順序
readonly AI_TOOLS=(
    "codex"
    "gemini" 
    "claude"
)

# AI 提示詞配置
# 說明：用於 commit 訊息生成的統一提示詞模板。
#       此提示詞會與 git diff 內容一起傳遞給 AI 工具。
# 修改重點：
#   - 應強調描述功能變更、需求實現、行為改變
#   - 避免要求技術細節或實作方式
#   - 指定輸出語言（此處為中文）與格式（一行標題）
# 輸出範例：新增用戶登入功能、修正檔案上傳錯誤、改善搜尋效能
readonly AI_COMMIT_PROMPT="根據以下 git 變更生成一行中文 commit 標題，格式如：新增用戶登入功能、修正檔案上傳錯誤、改善搜尋效能。只輸出標題："

# ==============================================
# 訊息輸出函數區域
# ==============================================

# 函式：error_msg
# 功能說明：輸出紅色錯誤訊息至 stderr，不終止程式執行。
# 輸入參數：
#   $1 <message> 錯誤訊息文字，支援 UTF-8 編碼
# 輸出結果：
#   STDERR 輸出紅色 ANSI 彩色文字，格式：\033[0;31m<message>\033[0m\n
# 例外/失敗：
#   無例外，總是返回 0
# 流程：
#   1. 使用 printf 輸出 ANSI 紅色碼（\033[0;31m）
#   2. 輸出訊息內容
#   3. 重置顏色（\033[0m）並換行
#   4. 重導向至 stderr（>&2）
# 副作用：輸出至 stderr，不影響 stdout
# 參考：handle_error() 函數會調用此函數
error_msg() {
    printf "\033[0;31m%s\033[0m\n" "$1" >&2
}

# 函式：handle_error
# 功能說明：輸出錯誤訊息並立即終止腳本執行，退出碼為 1。
# 輸入參數：
#   $1 <message> 錯誤訊息文字，會加上「錯誤: 」前綴
# 輸出結果：
#   STDERR 輸出紅色錯誤訊息，格式：「錯誤: <message>」
# 例外/失敗：
#   無返回，直接以 exit 1 終止程式
# 流程：
#   1. 呼叫 error_msg 輸出錯誤訊息
#   2. 執行 exit 1 終止腳本
# 副作用：
#   - 輸出至 stderr
#   - 終止程式執行，退出碼 1
#   - 觸發 trap EXIT 清理函數（若已設定）
# 參考：所有需要終止執行的錯誤情境都應使用此函數
handle_error() {
    error_msg "錯誤: $1"
    exit 1
}

# 函式：success_msg
# 功能說明：輸出綠色成功訊息至 stderr。
# 輸入參數：
#   $1 <message> 成功訊息文字，支援 UTF-8 編碼
# 輸出結果：
#   STDERR 輸出綠色 ANSI 彩色文字，格式：\033[0;32m<message>\033[0m\n
# 例外/失敗：
#   無例外，總是返回 0
# 流程：
#   1. 使用 printf 輸出 ANSI 綠色碼（\033[0;32m）
#   2. 輸出訊息內容
#   3. 重置顏色（\033[0m）並換行
#   4. 重導向至 stderr（>&2）
# 副作用：輸出至 stderr，不影響 stdout
# 參考：操作成功完成時使用此函數顯示結果
success_msg() {
    printf "\033[0;32m%s\033[0m\n" "$1" >&2
}

# 函式：warning_msg
# 功能說明：輸出黃色警告訊息至 stderr。
# 輸入參數：
#   $1 <message> 警告訊息文字，支援 UTF-8 編碼
# 輸出結果：
#   STDERR 輸出粗體黃色 ANSI 彩色文字，格式：\033[1;33m<message>\033[0m\n
# 例外/失敗：
#   無例外，總是返回 0
# 流程：
#   1. 使用 printf 輸出 ANSI 粗體黃色碼（\033[1;33m）
#   2. 輸出訊息內容
#   3. 重置顏色（\033[0m）並換行
#   4. 重導向至 stderr（>&2）
# 副作用：輸出至 stderr，不影響 stdout
# 參考：用於非致命錯誤或需要使用者注意的情境
warning_msg() {
    printf "\033[1;33m%s\033[0m\n" "$1" >&2
}

# 函式：info_msg
# 功能說明：輸出藍色資訊訊息至 stderr。
# 輸入參數：
#   $1 <message> 資訊訊息文字，支援 UTF-8 編碼
# 輸出結果：
#   STDERR 輸出藍色 ANSI 彩色文字，格式：\033[0;34m<message>\033[0m\n
# 例外/失敗：
#   無例外，總是返回 0
# 流程：
#   1. 使用 printf 輸出 ANSI 藍色碼（\033[0;34m）
#   2. 輸出訊息內容
#   3. 重置顏色（\033[0m）並換行
#   4. 重導向至 stderr（>&2）
# 副作用：輸出至 stderr，不影響 stdout
# 參考：用於一般資訊提示、操作狀態顯示
info_msg() {
    printf "\033[0;34m%s\033[0m\n" "$1" >&2
}

# 函式：purple_msg
# 功能說明：輸出亮紫色訊息至 stderr，用於特殊提示或感謝訊息。
# 輸入參數：
#   $1 <message> 訊息文字，支援 UTF-8 編碼
# 輸出結果：
#   STDERR 輸出亮紫色 ANSI 彩色文字，格式：\033[1;35m<message>\033[0m\n
# 例外/失敗：
#   無例外，總是返回 0
# 使用：purple_msg "💝 感謝訊息"
# ============================================
purple_msg() {
    printf "\033[1;35m%s\033[0m\n" "$1" >&2
}

# ============================================
# 流程：
#   1. 使用 printf 輸出 ANSI 粗體紫色碼（\033[1;35m）
#   2. 輸出訊息內容
#   3. 重置顏色（\033[0m）並換行
#   4. 重導向至 stderr（>&2）
# 副作用：輸出至 stderr，不影響 stdout
# 參考：用於特殊狀態提示、感謝訊息
cyan_msg() {
    printf "\033[1;36m%s\033[0m\n" "$1" >&2
}

# 函式：debug_msg
# 功能說明：輸出灰色調試訊息至 stderr，用於開發階段除錯。
# 輸入參數：
#   $1 <message> 調試訊息文字，支援 UTF-8 編碼
# 輸出結果：
#   STDERR 輸出灰色 ANSI 彩色文字，格式：\033[0;90m<message>\033[0m\n
# 例外/失敗：
#   無例外，總是返回 0
# 流程：
#   1. 使用 printf 輸出 ANSI 灰色碼（\033[0;90m）
#   2. 輸出訊息內容
#   3. 重置顏色（\033[0m）並換行
#   4. 重導向至 stderr（>&2）
# 副作用：輸出至 stderr，不影響 stdout
# 參考：用於開發階段的變數值檢查、流程追蹤
debug_msg() {
    printf "\033[0;90m%s\033[0m\n" "$1" >&2
}

# 函式：highlight_success_msg
# 功能說明：輸出亮綠色高亮成功訊息至 stderr，用於強調重要的成功結果。
# 輸入參數：
#   $1 <message> 訊息文字，支援 UTF-8 編碼
# 輸出結果：
#   STDERR 輸出亮綠色 ANSI 彩色文字，格式：\033[1;32m<message>\033[0m\n
# 例外/失敗：
#   無例外，總是返回 0
# 使用：highlight_success_msg "✅ 操作成功"
# ============================================
highlight_success_msg() {
    printf "\033[1;32m%s\033[0m\n" "$1" >&2
}

# ============================================
# 白色訊息函數
# 功能：顯示亮白色訊息（用於選單選項）
# 參數：$1 - 訊息內容
# 返回：0 (總是成功)
# 使用：white_msg "選項說明"
# ============================================
white_msg() {
    printf "\033[1;37m%s\033[0m\n" "$1" >&2
}

# ============================================
# 帶標籤的青色訊息函數
# 功能：顯示青色標籤加一般文字的格式（用於資訊標籤）
# 參數：$1 - 標籤內容（青色）
#      $2 - 標籤後的文字內容（一般顏色）
# 返回：0 (總是成功)
# 使用：cyan_label_msg "🌿 當前分支:" "main"
# ============================================
cyan_label_msg() {
    printf "\033[1;36m%s\033[0m %s\n" "$1" "$2" >&2
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
    
    # 使用當前時間的秒數作為隨機種子
    local random_index=$(( $(date +%s) % ${#messages[@]} ))
    local selected_message="${messages[$random_index]}"
    
    echo >&2
    purple_msg "💝 $selected_message"
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
# Git 狀態獲取函數
# 功能：獲取 Git 倉庫的當前狀態（簡潔格式）
# 參數：無
# 返回：輸出 Git 狀態的簡潔格式字串
# 使用：status=$(get_git_status)
# 格式：每行代表一個檔案，前兩個字元為狀態標記
#       空白 - 沒有變更，M - 修改，A - 新增，D - 刪除
# ============================================
get_git_status() {
    git status --porcelain 2>/dev/null
}

# ============================================
# Git 檔案添加函數
# 功能：將當前目錄下所有變更的檔案添加到 Git 暫存區
# 參數：無
# 返回：0 - 添加成功，1 - 添加失敗
# 使用：if add_all_files; then echo "檔案已暫存"; fi
# 行為：
#   - 顯示進度訊息
#   - 執行 git add . 命令
#   - 根據結果顯示成功或失敗訊息
# ============================================
add_all_files() {
    info_msg "正在添加所有變更的檔案..."
    if git add . 2>/dev/null; then
        success_msg "檔案添加成功！"
        return 0
    else
        error_msg "添加檔案失敗"
        return 1
    fi
}

# 清理 AI 生成的訊息
clean_ai_message() {
    local message="$1"
    
    # 顯示原始訊息
    debug_msg "🔍 AI 原始輸出: '$message'"
    
    # 最簡化處理：只移除前後空白，保留完整內容
    message=$(echo "$message" | xargs)
    
    # 顯示清理結果
    debug_msg "🧹 清理後輸出: '$message'"
    
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
    
    # 設置 loading 清理函數
    loading_cleanup() {
        # 清除 loading 行並顯示游標
        printf "\r\033[K\033[?25h" >&2
        exit 0
    }
    
    # 設置中斷信號處理
    trap loading_cleanup INT TERM
    
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
    
    # 清理信號處理
    trap - INT TERM
}

# 函式：run_command_with_loading
# 功能說明：執行命令並顯示 loading 動畫，支援超時控制與中斷處理。
# 輸入參數：
#   $1 <command> 要執行的 shell 命令字串（可含管道、重導向）
#   $2 <loading_message> loading 動畫顯示的訊息文字
#   $3 <timeout> 超時秒數，整數，命令執行超過此時間會被終止
# 輸出結果：
#   STDOUT 輸出命令的執行結果（透過臨時檔案回傳）
#   STDERR 顯示 loading 動畫（格式：旋轉符號 訊息 (已用秒數/超時秒數)）
# 例外/失敗：
#   1=命令超時；命令本身的退出碼（非零表示失敗）
# 流程：
#   1. 建立臨時檔案用於儲存命令輸出與退出碼
#   2. 定義局部 cleanup_and_exit 函數處理中斷清理
#   3. 設置 trap INT TERM 捕捉中斷信號
#   4. 在背景執行命令，輸出重導向至臨時檔案
#   5. 在背景執行 show_loading 顯示動畫
#   6. 主循環檢查命令是否完成或超時
#   7. 命令完成後停止動畫，讀取輸出與退出碼
#   8. 清理臨時檔案與 trap 設定
#   9. 返回命令的退出碼
# 副作用：
#   - 建立並自動清理臨時檔案（mktemp 建立於 /tmp）
#   - 設置與還原 trap INT TERM
#   - 背景進程（命令與動畫）會在結束時被清理
#   - 輸出至 stdout 與 stderr
# 參考：show_loading() 函數、cleanup_and_exit() 局部函數
run_command_with_loading() {
    local command="$1"
    local loading_message="$2"
    local timeout="$3"
    local temp_file
    temp_file=$(mktemp)
    
    # 局部函式：cleanup_and_exit
    # 功能說明：清理 loading 動畫、終止命令進程、刪除臨時檔案並退出。
    # 輸入參數：無
    # 輸出結果：無
    # 例外/失敗：以退出碼 130 終止腳本（SIGINT 標準退出碼）
    # 流程：
    #   1. 停止 loading 動畫背景進程（kill $loading_pid）
    #   2. 終止命令背景進程（TERM 後等待 0.5 秒再 KILL）
    #   3. 刪除臨時檔案（輸出與退出碼檔案）
    #   4. 顯示游標、清理終端、輸出中斷訊息
    #   5. 以 exit 130 終止腳本
    # 副作用：終止腳本執行、清理所有相關資源
    # 參考：由 trap INT TERM 調用
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
    
    # 執行 codex 命令
    local output exit_code
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "timeout $timeout codex exec < '$temp_prompt'" "正在等待 codex 分析變更" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "codex exec < '$temp_prompt'" "正在等待 codex 分析變更" "$timeout")
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
                    success_msg "codex 回應完成"
                    echo "$filtered_output"
                    return 0
                fi
            fi
            warning_msg "codex 沒有返回有效內容"
            ;;
        124)
            error_msg "❌ codex 執行超時（${timeout}秒）"
            warning_msg "💡 建議：檢查網路連接或稍後重試"
            ;;
        *)
            # 檢查特定錯誤類型
            if [[ "$output" == *"401 Unauthorized"* ]] || [[ "$output" == *"token_expired"* ]]; then
                error_msg "❌ codex 認證錯誤"
                warning_msg "💡 請執行：codex auth login"
            elif [[ "$output" == *"stream error"* ]] || [[ "$output" == *"connection"* ]] || [[ "$output" == *"network"* ]]; then
                error_msg "❌ codex 網路錯誤"
                warning_msg "💡 請檢查網路連接"
            else
                warning_msg "codex 執行失敗（退出碼: $exit_code）"
            fi
            ;;
    esac
    
    return 1
}

# 執行基於 stdin 的 AI 命令
run_stdin_ai_command() {
    local tool_name="$1"
    local prompt="$2"
    local timeout=45  # 增加超時時間到 45 秒
    
    info_msg "正在調用 $tool_name..."
    
    # 首先檢查工具是否可用
    if ! command -v "$tool_name" >/dev/null 2>&1; then
        warning_msg "$tool_name 工具未安裝"
        return 1
    fi
    
    # 檢查認證狀態
    # FIXED 不要檢查，因為可能需要用戶手動登入或是有發送頻率限制。
    
    # 獲取 git diff 內容
    local diff_content
    diff_content=$(git diff --cached 2>/dev/null)
    
    if [ -z "$diff_content" ]; then
        warning_msg "沒有暫存區變更可供 $tool_name 分析"
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
        error_msg "❌ $tool_name 執行超時（${timeout}秒）"
        
        # 顯示調試信息
        echo >&2
        debug_msg "🔍 調試信息（$tool_name 超時錯誤）:"
        debug_msg "執行的指令: $tool_name -p '$prompt' < [diff_file]"
        debug_msg "超時設定: $timeout 秒"
        debug_msg "diff 內容大小: $(echo "$diff_content" | wc -l) 行"
        if [ -n "$output" ]; then
            debug_msg "部分輸出內容:"
            echo "$output" | head -n 5 | sed 's/^/  /' >&2
        else
            debug_msg "輸出內容: (無)"
        fi
        printf "\n" >&2
        return 1
    elif [ $exit_code -ne 0 ]; then
        error_msg "❌ $tool_name 執行失敗（退出碼: $exit_code）"
        
        # 顯示調試信息
        echo >&2
        debug_msg "🔍 調試信息（$tool_name 執行失敗）:"
        debug_msg "執行的指令: $tool_name -p '$prompt' < [diff_file]"
        debug_msg "退出碼: $exit_code"
        if [ -n "$output" ]; then
            debug_msg "完整輸出內容:"
            echo "$output" | sed 's/^/  /' >&2
        else
            debug_msg "輸出內容: (無)"
        fi
        printf "\n" >&2
        return 1
    fi
    
    if [ -z "$output" ]; then
        error_msg "❌ $tool_name 沒有返回內容"
        
        # 顯示調試信息
        echo >&2
        debug_msg "🔍 調試信息（$tool_name 無輸出）:"
        debug_msg "執行的指令: $tool_name -p '$prompt' < [diff_file]"
        debug_msg "退出碼: $exit_code"
        debug_msg "diff 內容預覽:"
        echo "$diff_content" | head -n 5 | sed 's/^/  /' >&2
        printf "\n" >&2
        return 1
    fi
    
    success_msg "$tool_name 回應完成"
    echo "$output"
    return 0
}

# 全自動生成 commit message（不需要用戶交互）
generate_auto_commit_message_silent() {
    info_msg "🤖 全自動模式：正在使用 AI 工具分析變更並生成 commit message..."
    
    local prompt="$AI_COMMIT_PROMPT"
    local generated_message
    local ai_tool_used=""
    
    # 依序檢查每個 AI 工具
    for tool_name in "${AI_TOOLS[@]}"; do
        if ! command -v "$tool_name" >/dev/null 2>&1; then
            info_msg "🔄 AI 工具 $tool_name 未安裝，嘗試下一個..."
            continue
        fi

        info_msg "🔄 自動使用 AI 工具: $tool_name"
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
        
        warning_msg "❌ $tool_name 執行失敗，嘗試下一個工具..."
        generated_message=""
        ai_tool_used=""
    done
    
    # 檢查是否成功生成訊息
    if [ -n "$generated_message" ] && [ -n "$ai_tool_used" ]; then
        # 清理生成的訊息
        generated_message=$(clean_ai_message "$generated_message")
        
        if [ -n "$generated_message" ] && [ ${#generated_message} -gt 3 ]; then
            info_msg "✅ 自動使用 $ai_tool_used 生成的 commit message:"
            highlight_success_msg "🔖 $generated_message"
            echo "$generated_message"
            return 0
        else
            warning_msg "⚠️  AI 生成的訊息太短或無效: '$generated_message'"
        fi
    fi
    
    # 如果所有 AI 工具都不可用或失敗，使用預設訊息
    warning_msg "⚠️  所有 AI 工具都執行失敗，使用預設 commit message"
    local default_message="自動提交：更新專案檔案"
    info_msg "🔖 使用預設訊息: $default_message"
    echo "$default_message"
    return 0
}

# 使用 AI 工具自動生成 commit message
generate_auto_commit_message() {
    info_msg "正在使用 AI 工具分析變更並生成 commit message..."
    
    local prompt="$AI_COMMIT_PROMPT"
    local generated_message
    local ai_tool_used=""
    
    # 依序檢查每個 AI 工具
    for tool_name in "${AI_TOOLS[@]}"; do
        if ! command -v "$tool_name" >/dev/null 2>&1; then
            info_msg "AI 工具 $tool_name 未安裝，跳過..."
            continue
        fi

        # 提示用戶即將使用 AI 工具，並提供狀態提醒
        echo >&2
        info_msg "🤖 即將嘗試使用 AI 工具: $tool_name"
        
        # 根據不同工具提供特定的狀態提醒
        case "$tool_name" in
            "gemini")
                warning_msg "💡 提醒: Gemini 除了登入之外，如遇到頻率限制請稍後再試"
                ;;
            "claude")
                warning_msg "💡 提醒: Claude 需要登入付費帳號登入或 API 參數設定，如未登入請執行 'claude /login'"
                ;;
            "codex")
                info_msg "💡 提醒: Codex 如果無法連線，請確認登入或 API 參數設定"
                ;;
        esac
        
        info_msg "🔄 正在使用 AI 工具: $tool_name"
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
        
        warning_msg "$tool_name 執行失敗，嘗試下一個工具..."
        generated_message=""
        ai_tool_used=""
    done
    
    # 檢查是否成功生成訊息
    if [ -n "$generated_message" ] && [ -n "$ai_tool_used" ]; then
        # 清理生成的訊息
        generated_message=$(clean_ai_message "$generated_message")
        
        if [ -n "$generated_message" ] && [ ${#generated_message} -gt 3 ]; then
            info_msg "✅ 使用 $ai_tool_used 生成的 commit message:"
            highlight_success_msg "🔖 $generated_message"
            echo "$generated_message"
            return 0
        else
            warning_msg "AI 生成的訊息太短或無效: '$generated_message'"
        fi
    fi
    
    # 如果所有 AI 工具都不可用或失敗
    warning_msg "所有 AI 工具都執行失敗或未生成有效的 commit message"
    info_msg "已嘗試的工具: ${AI_TOOLS[*]}"
    return 1
}

# 獲取用戶輸入的 commit message
get_commit_message() {
    echo >&2
    echo "==================================================" >&2
    info_msg "請輸入 commit message (直接按 Enter 可使用 AI 自動生成):"
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
    info_msg "未輸入 commit message，正在使用 AI 自動生成..."
    
    if auto_message=$(generate_auto_commit_message); then
        echo >&2
        cyan_msg "🤖 AI 生成的 commit message:"
        highlight_success_msg "🔖 $auto_message"
        printf "是否使用此訊息？[Y/n]: " >&2
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
        info_msg "請手動輸入 commit message (或輸入 'q' 取消操作，輸入 'ai' 重新嘗試 AI 生成):"
        read -r manual_message
        manual_message=$(echo "$manual_message" | xargs)
        
        if [ "$manual_message" = "q" ] || [ "$manual_message" = "Q" ]; then
            warning_msg "已取消操作"
            return 1
        elif [ "$manual_message" = "ai" ] || [ "$manual_message" = "AI" ]; then
            # 重新嘗試 AI 生成
            if auto_message=$(generate_auto_commit_message); then
                echo >&2
                cyan_msg "🔄 AI 重新生成的 commit message:"
                highlight_success_msg "🔖 $auto_message"
                printf "是否使用此訊息？(y/n，直接按 Enter 表示同意): " >&2
                read -r confirm
                confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)
                
                if [ -z "$confirm" ] || [[ "$confirm" =~ ^(y|yes|是|確認)$ ]]; then
                    echo "$auto_message"
                    return 0
                fi
            else
                warning_msg "AI 生成仍然失敗，請手動輸入"
            fi
        elif [ -n "$manual_message" ]; then
            echo "$manual_message"
            return 0
        else
            warning_msg "請輸入有效的 commit message，或輸入 'q' 取消，'ai' 重新嘗試 AI 生成"
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
    info_msg "確認提交資訊:"
    echo "Commit Message: $message" >&2
    echo "==================================================" >&2
    
    # 持續詢問直到獲得有效回應
    while true; do
        printf "是否確認提交？[Y/n]: " >&2
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
            warning_msg "請輸入 y 或 n（或直接按 Enter 表示同意）"
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
        error_msg "提交失敗"
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
        error_msg "獲取分支名稱失敗"
        return 1
    fi
    
    # 去除分支名稱前後的空白字符
    branch=$(echo "$branch" | xargs)
    
    # 步驟 2: 推送到遠端倉庫
    if git push origin "$branch" 2>/dev/null; then
        success_msg "成功推送到遠端分支: $branch"
        return 0
    else
        error_msg "推送失敗"
        return 1
    fi
}

# 配置變數
DEFAULT_OPTION=1  # 預設選項：1=完整流程, 2=add+commit, 3=僅add

# 顯示操作選單
show_operation_menu() {
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
    echo "==================================================" >&2
    printf "請輸入選項 [1-6] (直接按 Enter 使用預設選項 %d): " "$DEFAULT_OPTION" >&2
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
            *)
                warning_msg "無效選項：$choice，請輸入 1、2、3、4、5 或 6"
                echo >&2
                ;;
        esac
    done
}

# ============================================
# 主函數 - Git 傳統工作流程自動化執行引擎
# 功能：統一入口，處理命令行參數、環境檢查、信號處理和工作流程調度
# 參數：$1 - 可選的命令行參數（--auto 或 -a 啟用全自動模式）
# 返回：根據具體操作結果
# 
# 執行流程：
#   1. 全域信號處理設置（Ctrl+C 中斷處理）
#   2. 命令行參數處理（自動模式檢測）
#   3. 環境驗證（Git 倉庫檢查、變更狀態檢查）
#   4. 根據模式選擇：
#      - 自動模式：直接執行全自動工作流程
#      - 互動模式：顯示選單讓用戶選擇操作
#   5. 調度對應的執行函數
# 
# 安全機制：
#   - 全域 trap 處理中斷信號
#   - Git 倉庫和變更狀態驗證
#   - 統一的錯誤處理和清理機制
# 
# 支援操作：
#   1. 完整流程 - execute_full_workflow() (add → commit → push)
#   2. 本地提交 - execute_local_commit() (add → commit) 
#   3. 僅添加檔案 - execute_add_only() (add)
#   4. 全自動模式 - execute_auto_workflow() (AI commit)
#   5. 僅提交 - execute_commit_only() (commit)
#   6. 顯示資訊 - show_git_info() (顯示 Git 倉庫資訊)
# ============================================
main() {
    # 設置全局信號處理
    global_cleanup() {
        printf "\r\033[K\033[?25h" >&2  # 清理終端並顯示游標
        warning_msg "程序被用戶中斷，正在清理..."
        exit 130  # SIGINT 的標準退出碼
    }
    
    # 設置中斷信號處理
    trap global_cleanup INT TERM

    warning_msg "使用前請確認 git 指令與 AI CLI 工具能夠在您的命令提示視窗中執行。"
    
    # 檢查命令行參數
    local auto_mode=false
    if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
        auto_mode=true
        info_msg "🤖 命令行啟用全自動模式"
    fi
    
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
        
        printf "是否嘗試將本地提交推送到遠端倉庫？[Y/n]: " >&2
        read -r push_confirm
        push_confirm=$(echo "$push_confirm" | tr '[:upper:]' '[:lower:]' | xargs)
        
        # 如果用戶確認推送（預設為是）
        if [ -z "$push_confirm" ] || [[ "$push_confirm" =~ ^(y|yes|是|確認)$ ]]; then
            if push_to_remote; then
                success_msg "🎉 推送完成！"
            else
                warning_msg "❌ 推送失敗"
                exit 1
            fi
        else
            info_msg "已取消推送操作。"
        fi
        
        exit 0
    fi
    
    # 顯示檢測到的變更
    info_msg "檢測到以下變更:"
    echo "$status"
    
    # 步驟 3: 添加所有變更的檔案到暫存區
    if ! add_all_files; then
        exit 1
    fi
    
    # 步驟 3.5: 如果是自動模式，直接執行全自動工作流程
    if [ "$auto_mode" = true ]; then
        execute_auto_workflow
        trap - INT TERM
        return
    fi
    
    # 否則獲取用戶選擇的操作模式
    local operation_choice
    if ! operation_choice=$(get_operation_choice); then
        exit 1
    fi
    
    # 根據選擇執行對應的操作
    case "$operation_choice" in
        1)
            # 完整流程：add → commit → push
            execute_full_workflow
            ;;
        2)
            # 本地提交：add → commit
            execute_local_commit
            ;;
        3)
            # 僅添加檔案：add（已經完成）
            execute_add_only
            ;;
        4)
            # 全自動模式：add → AI commit → push
            execute_auto_workflow
            ;;
        5)
            # 僅提交：commit
            execute_commit_only
            ;;
        6)
            # 顯示 Git 倉庫資訊
            show_git_info
            ;;
    esac
    
    # 清理全局信號處理
    trap - INT TERM
}

# 函式：execute_full_workflow
# 功能說明：執行完整的 Git 工作流程，包含 add → commit → push 三個步驟。
# 輸入參數：無
# 輸出結果：
#   STDERR 輸出各階段進度訊息與結果
# 例外/失敗：
#   1=使用者取消或任一步驟失敗
# 流程：
#   1. 顯示工作流程開始訊息
#   2. 調用 get_commit_message() 獲取或生成 commit 訊息（支援 AI 輔助）
#   3. 調用 confirm_commit() 確認使用者是否要提交
#   4. 調用 commit_changes() 提交變更到本地倉庫
#   5. 調用 push_to_remote() 推送到遠端倉庫
#   6. 顯示完成訊息與隨機感謝語
# 副作用：
#   - 修改 Git 倉庫狀態（commit 和 push）
#   - 輸出至 stderr
#   - 失敗時以 exit 1 終止腳本
# 參考：get_commit_message()、confirm_commit()、commit_changes()、push_to_remote()
execute_full_workflow() {
    info_msg "🚀 執行完整 Git 工作流程..."
    
    # 步驟 1: 獲取用戶輸入的 commit message（支援互動輸入或 AI 生成）
    local message
    if ! message=$(get_commit_message); then
        exit 1
    fi
    
    # 步驟 2: 確認是否要提交（顯示 commit 訊息供使用者確認）
    if ! confirm_commit "$message"; then
        warning_msg "已取消提交。"
        exit 0
    fi
    
    # 步驟 3: 提交變更到本地倉庫（執行 git commit）
    if ! commit_changes "$message"; then
        exit 1
    fi
    
    # 步驟 4: 推送到遠端倉庫（執行 git push）
    if ! push_to_remote; then
        exit 1
    fi
    
    # 完成提示
    echo >&2
    echo "==================================================" >&2
    success_msg "🎉 完整工作流程執行完成！"
    echo "==================================================" >&2
    
    # 顯示隨機感謝訊息
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
    
    # 步驟 1: 獲取用戶輸入的 commit message（支援互動輸入或 AI 生成）
    local message
    if ! message=$(get_commit_message); then
        exit 1
    fi
    
    # 步驟 2: 確認是否要提交（顯示 commit 訊息供使用者確認）
    if ! confirm_commit "$message"; then
        warning_msg "已取消提交。"
        exit 0
    fi
    
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

# 函式：execute_add_only
# 功能說明：僅執行檔案添加操作，將變更暫存但不提交。
# 輸入參數：無
# 輸出結果：
#   STDERR 輸出操作結果與後續建議
# 例外/失敗：
#   無（add 操作在主流程已完成）
# 流程：
#   1. 顯示添加操作訊息（實際 git add 已在主流程執行）
#   2. 顯示完成訊息與後續操作建議
#   3. 顯示隨機感謝語
# 副作用：
#   - 輸出至 stderr
#   - 不修改 Git 倉庫狀態（add 已在呼叫前完成）
# 參考：主流程中的 add_changes() 函數
execute_add_only() {
    info_msg "📦 僅執行檔案添加操作..."
    
    # 完成提示（add 操作已在主流程中完成）
    echo >&2
    echo "==================================================" >&2
    success_msg "📁 檔案添加完成！"
    info_msg "💡 提示：檔案已添加到暫存區，如需提交請使用 'git commit' 或重新運行腳本選擇選項 2"
    echo "==================================================" >&2
    
    # 顯示隨機感謝訊息
    show_random_thanks
}

# 執行僅提交功能 (commit)
execute_commit_only() {
    info_msg "💾 執行僅提交操作..."
    
    # 步驟 1: 檢查是否有已暫存的變更需要提交
    local staged_changes
    staged_changes=$(git diff --cached --name-only 2>/dev/null)
    
    if [ -z "$staged_changes" ]; then
        warning_msg "沒有已暫存的變更可提交。請先使用 'git add' 添加檔案，或選擇其他選項。"
        exit 0
    fi
    
    # 顯示已暫存的變更
    info_msg "已暫存的變更:"
    git diff --cached --name-only >&2
    
    # 步驟 2: 獲取用戶輸入的 commit message
    local message
    if ! message=$(get_commit_message); then
        exit 1
    fi
    
    # 步驟 3: 確認是否要提交
    if ! confirm_commit "$message"; then
        warning_msg "已取消提交。"
        exit 0
    fi
    
    # 步驟 4: 提交變更到本地倉庫
    if ! commit_changes "$message"; then
        exit 1
    fi
    
    # 完成提示
    echo >&2
    echo "==================================================" >&2
    success_msg "💾 提交完成！"
    info_msg "💡 提示：如需推送到遠端，請使用 'git push' 或重新運行腳本選擇選項 1"
    echo "==================================================" >&2
    
    # 顯示隨機感謝訊息
    show_random_thanks
}

# ============================================
# 顯示 Git 倉庫資訊函數
# 功能：顯示當前 Git 倉庫的詳細資訊
# 參數：無
# 返回：0 (總是成功)
# 
# 顯示內容包括：
#   - 當前分支名稱
#   - 遠端倉庫 URL（所有 remotes）
#   - 最近一次 commit 的資訊
#   - 本地與遠端的同步狀態
#   - 當前分支追蹤的遠端分支
#   - 倉庫根目錄路徑
#   - 工作區狀態（已修改/未追蹤檔案）
# ============================================
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
    status_output=$(git status --short 2>/dev/null)
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

# 執行全自動工作流程 (add → AI commit → push)
execute_auto_workflow() {
    info_msg "🤖 執行全自動 Git 工作流程..."
    info_msg "💡 提示：全自動模式將使用 AI 生成 commit message 並自動完成所有步驟"
    
    # 步驟 4: 使用 AI 自動生成 commit message（無需用戶確認）
    local message
    if ! message=$(generate_auto_commit_message_silent); then
        # 如果 AI 生成失敗，使用預設訊息
        message="自動提交：更新專案檔案"
        warning_msg "⚠️  使用預設 commit message: $message"
    fi
    
    # 顯示將要使用的 commit message
    echo >&2
    echo "==================================================" >&2
    info_msg "🤖 全自動提交資訊:"
    cyan_msg "📝 Commit Message: $message"
    echo "==================================================" >&2
    
    # 步驟 5: 自動提交（無需用戶確認）
    if ! commit_changes "$message"; then
        exit 1
    fi
    
    # 步驟 6: 自動推送到遠端倉庫
    if ! push_to_remote; then
        exit 1
    fi
    
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
    
    # 顯示隨機感謝訊息
    show_random_thanks
}

# 當腳本直接執行時，調用主函數開始 Git 工作流程
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
