#!/bin/bash
# -*- coding: utf-8 -*-

# 腳本用途：
#   提供完整的 GitHub Flow 工作流程自動化，從分支建立到 PR 合併。
#   支援 AI 輔助生成分支名稱、PR 內容，並整合企業級安全機制。
#   適用於團隊協作開發環境，涵蓋分支管理、PR 審查、合併與撤銷等完整流程。
#
# 使用方式：
#   互動模式：    ./git-auto-pr.sh
#   顯示說明：    ./git-auto-pr.sh -h 或 --help
#   相容模式：    ./git-auto-pr.sh --auto（已廢用，會提示使用互動模式）
#   全域使用：    git-auto-pr（需先將腳本連結至 PATH）
#
# 五種操作模式：
#   1. 建立功能分支 - 基於主分支建立新分支，支援 AI 生成分支名稱
#   2. 建立 Pull Request - 建立 PR 並使用 AI 生成標題與內容
#   3. 撤銷 PR（智慧模式）- 關閉開放中的 PR 或 revert 已合併的 PR
#   4. 審查並合併 PR - 互動式審查流程，支援 squash merge
#   5. 刪除分支（安全模式）- 刪除本地與遠端分支，含主分支保護
#
# 相依工具：
#   bash>=4.0       必需，腳本執行環境
#   git>=2.0        必需，版本控制操作
#   gh>=2.0         必需，GitHub CLI，用於 PR 相關操作
#   codex/gemini/claude  可選，AI CLI 工具，用於智慧生成功能
#
# 權限與安全：
#   - 不需要 root 權限
#   - 會讀取當前 Git 倉庫配置與狀態
#   - 會執行 git/gh 指令進行分支與 PR 操作
#   - 會透過網路存取 GitHub API（經由 gh CLI）
#   - 主分支受保護，無法直接刪除或切換至主分支建立 PR
#
# 輸入來源：
#   - CLI 參數：-h/--help（顯示說明）、--auto（相容模式）
#   - 環境變數：無特定環境變數需求，使用 Git/GitHub 預設配置
#   - STDIN：互動式輸入（選單選項、分支名稱、PR 資訊等）
#   - 設定檔：使用 gh CLI 的認證配置（~/.config/gh/）
#
# 輸出結果：
#   - STDOUT：無資料輸出（所有訊息均輸出至 STDERR）
#   - STDERR：所有狀態訊息、錯誤訊息、互動提示、彩色輸出
#   - 格式：UTF-8 編碼，ANSI 彩色碼
#
# 退出碼表：
#   0   成功完成操作
#   1   一般錯誤（參數錯誤、操作失敗、使用者取消等）
#   2   相依工具不足（git 或 gh 未安裝）
#   130 使用者中斷（Ctrl+C）
#
# 主要流程：
#   1. 初始化與環境檢查（驗證 git/gh 可用性、檢測 Git 倉庫）
#   2. 顯示操作選單並接收使用者選擇
#   3. 根據選擇執行對應工作流程：
#      - 建立分支：檢測主分支 → AI 生成分支名 → 建立並切換分支
#      - 建立 PR：收集 commits → AI 生成 PR 內容 → 使用 gh 建立 PR
#      - 撤銷 PR：檢查 PR 狀態 → 關閉或 revert → 確認操作
#      - 審查合併：檢視 PR 與 CI 狀態 → 審查 → squash merge
#      - 刪除分支：確認分支狀態 → 多重確認 → 刪除本地與遠端分支
#   4. 輸出操作結果與後續建議
#   5. 清理暫存資源並退出
#
# 注意事項：
#   - AI 工具調用有 45 秒超時機制，失敗時會自動切換至下一個工具
#   - PR 合併預設使用 squash 策略，會將所有 commits 壓縮為一個
#   - 分支名稱格式：username/type/issue-key-description（小寫、連字號分隔）
#   - 主分支自動檢測順序：uat → main → master（可於配置區調整）
#   - 撤銷已合併 PR 的 revert 操作預設選項為「否」，需明確確認
#   - 網路操作（gh CLI）無內建重試機制，失敗時需手動重新執行
#   - 時區假設：使用系統本地時區
#   - 不支援離線模式，所有 PR 操作均需網路連線
#
# 參考：
#   - GitHub Flow 說明：docs/github-flow.md
#   - PR 撤銷功能：docs/pr-cancel-feature.md
#   - Git 倉庫資訊：docs/git-info-feature.md
#   - GitHub CLI 文檔：https://cli.github.com/manual/
#   - Conventional Commits：https://www.conventionalcommits.org/
#
# 作者：Lazy Jerry
# 版本：v1.7.0
# 最後更新：2025-10-24
# 授權：MIT License
# 倉庫：https://github.com/lazyjerry/git-auto-push
#

# ==============================================
# AI 提示詞配置區域
# ==============================================
#
# 說明：此區域集中管理所有 AI 工具的提示詞模板函數。
#       修改這些函數可調整 AI 生成內容的品質、格式與風格。
#       支援的 AI 工具：codex、gemini、claude（依 AI_TOOLS 陣列順序調用）
#
# 注意事項：
# 1. 提示詞應簡潔明確，避免過長導致 AI 工具超時（預設 45 秒）
# 2. 輸出格式需統一便於後處理（如使用 ||| 分隔多欄位）
# 3. 修改後請測試各種場景（空輸入、長輸入、特殊字元）確保相容性
# 4. 提示詞使用英文可提升跨 AI 工具的相容性
# ==============================================

# 函式：generate_ai_branch_prompt
# 功能說明：生成 AI 分支名稱提示詞，用於請求 AI 工具產生符合規範的 Git 分支名稱。
# 輸入參數：
#   $1 <username> 使用者名稱，用於分支名稱前綴，應為小寫英文
#   $2 <branch_type> 分支類型，如 feature、bugfix、hotfix 等
#   $3 <issue_key> 議題編號，如 issue-001、jira-456 等
#   $4 <description_hint> 功能描述提示（可選），用於生成分支描述部分
# 輸出結果：
#   STDOUT 輸出英文提示詞字串，不含換行符號
#   格式範例："Generate branch name for: add login. Username: jerry, Type: feature..."
# 例外/失敗：
#   無例外，總是返回提示詞字串（即使參數為空）
# 流程：
#   1. 檢查 description_hint 是否為空
#   2. 若為空，使用通用提示詞模板
#   3. 若不為空，使用包含描述的詳細模板
#   4. 使用 printf '%s' 輸出避免額外換行
# 副作用：無副作用，純函數
# 參考：generate_ai_branch_name() 函數會調用此提示詞
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

# 函式：generate_ai_pr_prompt
# 功能說明：生成 AI PR 內容提示詞，用於請求 AI 工具根據 commit 訊息生成 PR 標題與內容。
# 輸入參數：
#   $1 <issue_key> 議題編號，如 issue-001、jira-456，用於 PR 內容參考
#   $2 <branch_name> 分支名稱，用於 PR 內容參考
#   注意：實際的 commits 與 file_changes 會透過臨時檔案（content 參數）傳遞給 AI 工具
# 輸出結果：
#   STDOUT 輸出多行提示詞文字（透過 cat <<EOF），包含格式指示與範例
#   提示詞指示 AI 輸出格式：標題。詳細內容（標題需以句號結尾）
# 例外/失敗：
#   無例外，總是返回提示詞字串
# 流程：
#   1. 接收 issue_key 與 branch_name 參數
#   2. 使用 cat <<EOF 輸出多行提示詞模板
#   3. 提示詞包含格式要求、語言要求（繁體中文）、輸出範例
# 副作用：無副作用，純函數
# 參考：generate_pr_content_with_ai() 函數會調用此提示詞
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

# AI 工具優先順序配置
# 說明：定義 AI 工具的調用順序，當前一個工具失敗時會自動嘗試下一個。
#       腳本會依陣列順序逐一調用，直到成功或全部失敗。
# 修改方式：調整陣列元素順序或新增其他 AI CLI 工具名稱（需系統已安裝）
# 已知問題：codex 在某些環境可能產生亂碼或編碼問題
# 範例：
#   readonly AI_TOOLS=("gemini")                    # 僅使用 gemini
#   readonly AI_TOOLS=("codex" "gemini" "claude")   # 依序嘗試三個工具
readonly AI_TOOLS=("codex" "gemini" "claude")

# ==============================================
# 分支配置區域
# ==============================================

# 主分支候選清單配置
# 說明：定義主分支的候選名稱，腳本會依陣列順序檢測第一個存在的遠端分支。
#       此設定影響「建立功能分支」與「建立 PR」功能的基底分支選擇。
# 格式：Bash 只讀陣列，元素為分支名稱字串（無 origin/ 前綴）
# 檢測邏輯：透過 git show-ref --verify refs/remotes/origin/<branch> 驗證存在性
# 修改範例：
#   readonly -a DEFAULT_MAIN_BRANCHES=("main" "master")           # 標準配置
#   readonly -a DEFAULT_MAIN_BRANCHES=("uat" "main" "master")     # 包含預發布分支
#   readonly -a DEFAULT_MAIN_BRANCHES=("develop" "main")          # Git Flow 風格
readonly -a DEFAULT_MAIN_BRANCHES=("uat" "main" "master")

# 預設使用者名稱配置
# 說明：用於生成分支名稱的使用者前綴（格式：username/type/issue-description）。
#       建議設定為團隊成員的 Git 使用者名稱或縮寫。
# 格式：小寫英文字母，無空白或特殊符號（可含數字、連字號）
# 使用時機：「建立功能分支」功能會使用此值作為分支名稱前綴
# 修改範例：
#   readonly DEFAULT_USERNAME="john"
#   readonly DEFAULT_USERNAME="team-a"
readonly DEFAULT_USERNAME="jerry"

# PR 合併後分支刪除策略配置
# 說明：控制 PR 合併後是否自動刪除功能分支。
#       設定為 true 時，合併 PR 會自動刪除遠端分支；
#       設定為 false 時，合併 PR 會保留分支供後續參考或重複使用。
# 安全考量：預設為 false（保守策略），避免誤刪重要分支
# 使用時機：「審查與合併 PR」功能會參考此設定決定是否使用 --delete-branch 選項
# 修改範例：
#   readonly AUTO_DELETE_BRANCH_AFTER_MERGE=true   # 自動刪除（適合短期功能分支）
#   readonly AUTO_DELETE_BRANCH_AFTER_MERGE=false  # 保留分支（適合需要追蹤的分支）
readonly AUTO_DELETE_BRANCH_AFTER_MERGE=false

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

# ============================================
# 警告訊息函數
# 功能：顯示黃色警告訊息
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

# 函式：magenta_msg
# 功能說明：輸出粗體洋紅色訊息至 stderr，用於特殊高亮或重要提示。
# 輸入參數：
#   $1 <message> 訊息文字，支援 UTF-8 編碼
# 輸出結果：
#   STDERR 輸出粗體洋紅色 ANSI 彩色文字，格式：\033[1;35m<message>\033[0m\n
# 例外/失敗：
#   無例外，總是返回 0
# 流程：
#   1. 使用 printf 輸出 ANSI 粗體洋紅色碼（\033[1;35m）
#   2. 輸出訊息內容
#   3. 重置顏色（\033[0m）並換行
#   4. 重導向至 stderr（>&2）
# 副作用：輸出至 stderr，不影響 stdout
# 參考：用於特殊狀態提示、關鍵資訊高亮
magenta_msg() {
    printf "\033[1;35m%s\033[0m\n" "$1" >&2
}

# 函式：purple_msg
# 功能說明：輸出紫色訊息至 stderr，用於分支資訊等中性資訊。
# 輸入參數：
#   $1 <message> 訊息文字，支援 UTF-8 編碼
# 輸出結果：
#   STDERR 輸出紫色 ANSI 彩色文字，格式：\033[0;35m<message>\033[0m\n
# 例外/失敗：
#   無例外，總是返回 0
# 流程：
#   1. 使用 printf 輸出 ANSI 紫色碼（\033[0;35m）
#   2. 輸出訊息內容
#   3. 重置顏色（\033[0m）並換行
#   4. 重導向至 stderr（>&2）
# 副作用：輸出至 stderr，不影響 stdout
# 參考：用於顯示分支名稱、標籤等中性資訊
purple_msg() {
    printf "\033[0;35m%s\033[0m\n" "$1" >&2
}

# 函式：cyan_msg
# 功能說明：輸出青色訊息至 stderr，用於連結、命令提示等輔助資訊。
# 輸入參數：
#   $1 <message> 訊息文字，支援 UTF-8 編碼
# 輸出結果：
#   STDERR 輸出青色 ANSI 彩色文字，格式：\033[0;36m<message>\033[0m\n
# 例外/失敗：
#   無例外，總是返回 0
# 流程：
#   1. 使用 printf 輸出 ANSI 青色碼（\033[0;36m）
#   2. 輸出訊息內容
#   3. 重置顏色（\033[0m）並換行
#   4. 重導向至 stderr（>&2）
# 副作用：輸出至 stderr，不影響 stdout
# 參考：用於顯示 URL 連結、命令提示、次要資訊
cyan_msg() {
    printf "\033[0;36m%s\033[0m\n" "$1" >&2
}

# 函式：show_ai_debug_info
# 功能說明：統一格式顯示 AI 工具的調試資訊，包含工具名稱、輸入與輸出內容。
# 輸入參數：
#   $1 <tool_name> AI 工具名稱，如 codex、gemini、claude
#   $2 <prompt> 提示詞內容（指令部分）
#   $3 <content> 實際資料內容（如 diff、commits）
#   $4 <output> 輸出內容（可選），AI 工具的回應結果
# 輸出結果：
#   STDERR 輸出彩色格式化的調試資訊，包含分隔線與標題
# 例外/失敗：
#   無例外，總是返回 0
# 流程：
#   1. 輸出分隔線與工具名稱標題（使用 debug_msg）
#   2. 顯示 prompt 內容（截取前 200 字元）
#   3. 顯示 content 內容（截取前 500 字元）
#   4. 若提供 output 參數，顯示輸出內容（截取前 300 字元）
#   5. 輸出結束分隔線
# 副作用：輸出至 stderr，不影響 stdout
# 參考：用於開發階段追蹤 AI 工具的輸入輸出
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
    # 確保使用 UTF-8 編碼以避免編碼轉換問題
    local temp_prompt
    temp_prompt=$(mktemp)
    
    # 使用 printf 確保 UTF-8 編碼
    # 使用 C.UTF-8 或 en_US.UTF-8 避免 locale 相關問題
    {
        export LC_ALL=C.UTF-8 LANG=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
        printf '%s\n\n%s' "$prompt" "$content"
    } > "$temp_prompt" || {
        rm -f "$temp_prompt"
        warning_msg "寫入臨時檔案失敗"
        return 1
    }
    
    # 驗證臨時檔案是否為有效的 UTF-8
    if ! file "$temp_prompt" | grep -q "UTF-8\|ASCII"; then
        info_msg "⚠️  臨時檔案編碼檢查：$(file -b "$temp_prompt")"
    fi
    
    # 🔍 調試輸出：印出即將傳遞給 codex 的內容
    debug_msg "🔍 調試: run_codex_command() - 即將傳遞給 codex 的內容"
    debug_msg "─────────────────────────────────────────"
    debug_msg "📄 文件內容（編碼: UTF-8）:"
    debug_msg "─────────────────────────────────────────"
    file -b "$temp_prompt" | sed 's/^/  /' >&2
    debug_msg ""
    debug_msg "📊 內容統計:"
    debug_msg "   - 總行數: $(wc -l < "$temp_prompt") 行"
    debug_msg "   - 總位元組: $(wc -c < "$temp_prompt") 位元組"
    debug_msg "   - 檔案大小: $(du -h "$temp_prompt" | cut -f1)"
    debug_msg ""
    debug_msg "📝 前 20 行內容:"
    debug_msg "─────────────────────────────────────────"
    head -n 20 "$temp_prompt" | sed 's/^/  /' >&2
    debug_msg "─────────────────────────────────────────"
    echo >&2
    
    # 執行 codex 命令，設定 UTF-8 環境變數
    local output exit_code
    export LC_ALL=C.UTF-8 LANG=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "timeout $timeout codex exec < '$temp_prompt'" "正在等待 codex 分析內容" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "codex exec < '$temp_prompt'" "正在等待 codex 分析內容" "$timeout")
        exit_code=$?
    fi
    
    # 確保 exit_code 是乾淨的數字（清理所有可能的隱藏字符）
    exit_code=$(echo "$exit_code" | tr -d '\r\n\t ' | tr -cd '0-9')
    if ! [[ "$exit_code" =~ ^[0-9]+$ ]] || [ -z "$exit_code" ]; then
        warning_msg "⚠️  退出碼無效: '$exit_code'，設為 1"
        exit_code=1
    fi
    
    # 🔍 調試：顯示退出碼
    debug_msg "🔍 調試: codex 退出碼 exit_code='$exit_code'"
    
    # 清理臨時檔案
    rm -f "$temp_prompt"
    
    # 處理執行結果
    case $exit_code in
        0)
            # 成功執行，處理輸出
            if [ -n "$output" ]; then
                local filtered_output
                
                # 清理 output 中的控制字符（保留換行）
                output=$(echo "$output" | tr -d '\r')
                
                # 🔍 調試：顯示原始輸出
                debug_msg "🔍 調試: codex 原始輸出（前 500 字符）"
                echo "$output" | head -c 500 | sed 's/^/  /' >&2
                echo >&2
                
                # 改進的過濾邏輯：使用 LC_ALL=C 避免 locale 相關錯誤
                # 方法1：精確提取 "codex" 行之後、"tokens used" 行之前的內容
                filtered_output=$(LC_ALL=C echo "$output" | \
                    awk '/^codex$/{flag=1; next} /^tokens used/{flag=0} flag' | \
                    grep -v '^[[:space:]]*$' | \
                    grep -v -E '^(thinking|user|OpenAI Codex|workdir:|model:|provider:|approval:|sandbox:|reasoning|session id:|-----)' | \
                    tr '\n' ' ' | \
                    sed 's/[[:space:]]\+/ /g' | \
                    xargs)
                
                # 方法2：如果方法1沒有結果，嘗試更簡單的過濾
                if [ -z "$filtered_output" ]; then
                    filtered_output=$(LC_ALL=C echo "$output" | \
                        grep -v -E '^(OpenAI Codex|workdir:|model:|provider:|approval:|sandbox:|reasoning|tokens used:|-------|User instructions:|codex$|^$|thinking|user|session id:|effort:|summaries:)' | \
                        grep -E ".+" | \
                        tail -n 5 | \
                        tr '\n' ' ' | \
                        xargs)
                fi
                
                # 🔍 調試：顯示過濾後的輸出
                debug_msg "🔍 調試: 過濾後的輸出 filtered_output='$filtered_output'"
                
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
                show_ai_debug_info "codex" "$prompt" "$content" "$output"
            elif [[ "$output" == *"stream error"* ]] || [[ "$output" == *"connection"* ]] || [[ "$output" == *"network"* ]]; then
                error_msg "❌ codex 網路錯誤"
                warning_msg "💡 請檢查網路連接"
                show_ai_debug_info "codex" "$prompt" "$content" "$output"
            else
                # 清理 exit_code 確保是純數字（最後一次保險）
                local clean_code
                clean_code=$(printf '%s' "$exit_code" | LC_ALL=C tr -cd '0-9')
                [ -z "$clean_code" ] && clean_code="1"
                
                # 🔍 調試：顯示錯誤訊息前的 exit_code
                debug_msg "🔍 調試: 準備顯示錯誤，clean_code='$clean_code' (原始: '$exit_code')"
                warning_msg "codex 執行失敗"
                
                # 顯示 AI 的輸入和輸出訊息
                show_ai_debug_info "codex" "$prompt" "$content" "$output"
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
    
    # 最簡化處理：只移除前後空白，保留完整內容
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

# 使用 AI 生成分支名稱
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

# 使用 AI 生成 PR 標題和內容
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

# 顯示操作選單
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

# 獲取用戶選擇的操作
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
        warning_msg "程序被用戶中斷，正在清理..."
        exit 130  # SIGINT 的標準退出碼
    }
    
    # 設置中斷信號處理
    trap global_cleanup INT TERM

    warning_msg "使用前請確認 git 指令、gh CLI 與 AI CLI 工具能夠在您的命令提示視窗中執行。"
    
    # 檢查命令行參數（移除自動模式支援）
    if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
        warning_msg "⚠️  全自動模式已移除，請使用互動式選單操作"
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

# 函式：execute_create_branch
# 功能說明：執行功能分支建立流程，基於主分支建立標準化命名的功能分支。
# 輸入參數：無（透過互動式輸入獲取）
# 輸出結果：
#   STDERR 輸出各階段進度訊息、輸入提示與結果
# 例外/失敗：
#   1=使用者取消、主分支切換失敗、分支建立失敗
# 流程：
#   1. 檢測當前分支與主分支，若不在主分支則詢問是否切換
#   2. 更新主分支至最新狀態（git pull --ff-only）
#   3. 互動輸入 issue key 並驗證格式（支援多種格式：ISSUE-123、JIRA_456 等）
#   4. 輸入擁有者名字（預設使用 DEFAULT_USERNAME）
#   5. 選擇分支類型（issue、bug、feature、enhancement、blocker）
#   6. 基於 AI 或手動輸入生成分支名稱（格式：username/type/issue-key-description）
#   7. 驗證分支名稱格式並建立分支
#   8. 切換到新建立的分支
#   9. 顯示完成訊息與後續建議
# 副作用：
#   - 可能切換當前分支
#   - 更新主分支（git pull）
#   - 建立新的本地分支
#   - 輸出至 stderr
# 參考：get_main_branch()、check_main_branch()、validate_and_standardize_issue_key()、generate_ai_branch_name()
execute_create_branch() {
    info_msg "🌿 建立功能分支流程..."
    
    # 步驟 1: 檢測當前分支與主分支狀態
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

# 提交並推送變更
# 函式：execute_commit_and_push
# 功能說明：此函式已移除。請使用 git-auto-push.sh 來提交並推送變更。
# 注意事項：建立 PR 前必須先推送分支變更到遠端。

# 函式：execute_create_pr
# 功能說明：執行 Pull Request 建立流程，基於當前分支向主分支提交 PR。
# 輸入參數：無（透過互動式輸入獲取）
# 輸出結果：
#   STDERR 輸出各階段進度訊息、輸入提示與結果
#   在 GitHub 上建立新的 Pull Request
# 例外/失敗：
#   1=在主分支上無法建立 PR、分支未推送、PR 建立失敗
# 流程：
#   1. 檢測當前分支與主分支，驗證不在主分支上
#   2. 檢查分支是否已推送到遠端（必須先推送才能建立 PR）
#   3. 從分支名稱提取或手動輸入 issue key
#   4. 收集分支的 commit 訊息與檔案變更
#   5. 使用 AI 生成或手動輸入 PR 標題與內容
#   6. 解析 AI 輸出（格式：標題。內容，以句號分隔）
#   7. 確認 PR 資訊
#   8. 使用 gh pr create 建立 PR
#   9. 顯示 PR URL 與後續建議
# 副作用：
#   - 在 GitHub 上建立新的 Pull Request
#   - 輸出至 stderr
#   - 不修改本地 Git 狀態
# 參考：get_current_branch()、get_main_branch()、generate_pr_content_with_ai()
execute_create_pr() {
    info_msg "🔄 建立 Pull Request 流程..."
    
    # 步驟 1: 檢測當前分支與主分支
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
