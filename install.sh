#!/bin/sh
#
# Git 工作流程自動化工具集 - 安裝腳本
# 
# 使用方式：
#   curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh
#   或
#   wget -qO- https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh
#
# 選項：
#   --local    僅安裝到當前目錄（預設）
#   --global   安裝到系統路徑 /usr/local/bin（需要 sudo）
#   --no-config 跳過配置文件設定
#

set -e

# ========== 顏色定義 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ========== 配置 ==========
REPO_BASE_URL="https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master"
SCRIPTS="git-auto-push.sh git-auto-pr.sh"
CONFIG_DIR=".git-auto-push-config"
CONFIG_FILE=".env"
GLOBAL_INSTALL_DIR="/usr/local/bin"
LOCAL_INSTALL_DIR="${PWD}"

# ========== 輸出函數 ==========
info() {
    printf "${BLUE}ℹ️  ${NC}%s\n" "$1"
}

success() {
    printf "${GREEN}✅ ${NC}%s\n" "$1"
}

warning() {
    printf "${YELLOW}⚠️  ${NC}%s\n" "$1"
}

error() {
    printf "${RED}❌ ${NC}%s\n" "$1" >&2
}

header() {
    echo ""
    printf "${CYAN}════════════════════════════════════════════════════════════${NC}\n"
    printf "${CYAN}  %s${NC}\n" "$1"
    printf "${CYAN}════════════════════════════════════════════════════════════${NC}\n"
    echo ""
}

# ========== 工具檢測 ==========
check_download_tool() {
    if command -v curl > /dev/null 2>&1; then
        DOWNLOAD_TOOL="curl"
        DOWNLOAD_CMD="curl -fsSL"
    elif command -v wget > /dev/null 2>&1; then
        DOWNLOAD_TOOL="wget"
        DOWNLOAD_CMD="wget -qO-"
    else
        error "需要 curl 或 wget 來下載檔案"
        error "請先安裝：brew install curl 或 apt install curl"
        exit 1
    fi
    info "使用 ${DOWNLOAD_TOOL} 進行下載"
}

# ========== 必要套件檢測 ==========
check_dependencies() {
    echo ""
    info "檢查必要套件..."
    
    missing_required=false
    missing_optional=""
    
    # 檢查 git（必須）
    if command -v git > /dev/null 2>&1; then
        success "git 已安裝：$(git --version | head -1)"
    else
        error "git 未安裝！這是必要的核心依賴"
        echo ""
        echo "   📦 Git 安裝方式："
        echo "      macOS:   brew install git"
        echo "      Ubuntu:  sudo apt install git"
        echo "      Windows: https://git-scm.com/download/win"
        echo "      官方網站: https://git-scm.com/"
        echo ""
        missing_required=true
    fi
    
    # 檢查 gh CLI（git-auto-pr.sh 必須）
    if command -v gh > /dev/null 2>&1; then
        if gh auth status > /dev/null 2>&1; then
            success "GitHub CLI 已安裝且已登入"
        else
            warning "GitHub CLI 已安裝但未登入"
            echo "   請執行：gh auth login"
        fi
    else
        warning "GitHub CLI (gh) 未安裝"
        echo "   git-auto-pr.sh 需要此工具來建立和管理 Pull Request"
        echo ""
        echo "   📦 GitHub CLI 安裝方式："
        echo "      macOS:   brew install gh"
        echo "      Ubuntu:  sudo apt install gh"
        echo "      Windows: winget install GitHub.cli"
        echo "      官方網站: https://cli.github.com/"
        echo ""
        echo "   安裝後請執行：gh auth login"
        missing_optional="${missing_optional}gh "
    fi
    
    # 檢查 AI CLI 工具（選擇性）
    echo ""
    info "檢查 AI CLI 工具（選擇性）..."
    ai_tools_found=0
    
    # Copilot CLI
    if command -v gh > /dev/null 2>&1 && gh copilot --version > /dev/null 2>&1; then
        success "copilot 可用（gh copilot extension）"
        ai_tools_found=$((ai_tools_found + 1))
    fi
    
    # Gemini CLI
    if command -v gemini > /dev/null 2>&1; then
        success "gemini 可用"
        ai_tools_found=$((ai_tools_found + 1))
    fi
    
    # Codex CLI
    if command -v codex > /dev/null 2>&1; then
        success "codex 可用"
        ai_tools_found=$((ai_tools_found + 1))
    fi
    
    # Claude CLI
    if command -v claude > /dev/null 2>&1; then
        success "claude 可用"
        ai_tools_found=$((ai_tools_found + 1))
    fi
    
    if [ "$ai_tools_found" -eq 0 ]; then
        warning "未偵測到任何 AI CLI 工具"
        echo "   AI 功能將無法使用，但腳本仍可正常運作"
        echo ""
        echo "   💡 建議至少安裝一個 AI 工具以啟用自動內容產生功能："
        echo ""
        echo "   📦 GitHub Copilot CLI（推薦，需要 Copilot 訂閱）"
        echo "      gh extension install github/gh-copilot"
        echo "      https://github.com/github/copilot-cli"
        echo ""
        echo "   📦 Google Gemini CLI"
        echo "      npm install -g @anthropic-ai/claude-cli"
        echo "      https://github.com/google-gemini/gemini-cli"
        echo ""
        echo "   📦 OpenAI Codex CLI"
        echo "      npm install -g @openai/codex"
        echo "      https://github.com/openai/codex"
        echo ""
        echo "   📦 Anthropic Claude CLI"
        echo "      npm install -g @anthropic-ai/claude-code"
        echo "      https://docs.anthropic.com/en/docs/claude-code/overview"
        echo ""
    else
        info "已偵測到 ${ai_tools_found} 個 AI 工具"
    fi
    
    echo ""
    
    # 如果缺少必要套件，詢問是否繼續
    if [ "$missing_required" = "true" ]; then
        error "缺少必要套件，無法繼續安裝"
        exit 1
    fi
}

# ========== 下載函數 ==========
download_file() {
    url="$1"
    output="$2"
    
    if [ "$DOWNLOAD_TOOL" = "curl" ]; then
        curl -fsSL "$url" -o "$output"
    else
        wget -q "$url" -O "$output"
    fi
}

# ========== 安裝函數 ==========
install_scripts() {
    install_dir="$1"
    use_sudo="$2"
    sudo_cmd=""
    
    if [ "$use_sudo" = "true" ]; then
        sudo_cmd="sudo"
    fi
    
    for script in $SCRIPTS; do
        url="${REPO_BASE_URL}/${script}"
        script_name=$(echo "$script" | sed 's/\.sh$//')
        
        if [ "$use_sudo" = "true" ]; then
            target_path="${install_dir}/${script_name}"
        else
            target_path="${install_dir}/${script}"
        fi
        
        info "下載 ${script}..."
        
        # 下載到暫存檔
        tmp_file=$(mktemp)
        if ! download_file "$url" "$tmp_file"; then
            error "下載 ${script} 失敗"
            rm -f "$tmp_file"
            exit 1
        fi
        
        # 驗證下載內容
        if [ ! -s "$tmp_file" ]; then
            error "下載的檔案為空：${script}"
            rm -f "$tmp_file"
            exit 1
        fi
        
        # 檢查是否為有效的 shell 腳本
        if ! head -1 "$tmp_file" | grep -q "^#!/"; then
            error "下載的檔案不是有效的腳本：${script}"
            rm -f "$tmp_file"
            exit 1
        fi
        
        # 移動到目標位置
        if [ "$use_sudo" = "true" ]; then
            $sudo_cmd install -m 755 "$tmp_file" "$target_path"
        else
            mv "$tmp_file" "$target_path"
            chmod +x "$target_path"
        fi
        
        rm -f "$tmp_file" 2>/dev/null || true
        success "已安裝 ${target_path}"
    done
}

# ========== 驗證安裝 ==========
verify_installation() {
    install_dir="$1"
    is_global="$2"
    
    echo ""
    info "驗證安裝..."
    
    all_ok=true
    for script in $SCRIPTS; do
        script_name=$(echo "$script" | sed 's/\.sh$//')
        
        if [ "$is_global" = "true" ]; then
            target_path="${install_dir}/${script_name}"
        else
            target_path="${install_dir}/${script}"
        fi
        
        if [ -x "$target_path" ]; then
            success "${target_path} 已安裝且可執行"
        else
            error "${target_path} 安裝失敗或不可執行"
            all_ok=false
        fi
    done
    
    if [ "$all_ok" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# ========== 顯示使用說明 ==========
show_usage() {
    install_dir="$1"
    is_global="$2"
    
    echo ""
    header "安裝完成！"
    
    if [ "$is_global" = "true" ]; then
        echo "📌 已安裝到系統路徑，可在任意目錄使用："
        echo ""
        echo "   git-auto-push          # 傳統 Git 自動化"
        echo "   git-auto-push --auto   # 全自動模式"
        echo "   git-auto-push 1-7      # 直接執行指定選項"
        echo ""
        echo "   git-auto-pr            # GitHub Flow PR 自動化"
    else
        echo "📌 已安裝到當前目錄，使用方式："
        echo ""
        echo "   ./git-auto-push.sh          # 傳統 Git 自動化"
        echo "   ./git-auto-push.sh --auto   # 全自動模式"
        echo "   ./git-auto-push.sh 1-7      # 直接執行指定選項"
        echo ""
        echo "   ./git-auto-pr.sh            # GitHub Flow PR 自動化"
        echo ""
        echo "💡 如需全域安裝，請執行："
        echo "   sudo install -m 755 git-auto-push.sh /usr/local/bin/git-auto-push"
        echo "   sudo install -m 755 git-auto-pr.sh /usr/local/bin/git-auto-pr"
    fi
    
    echo ""
    echo "📚 更多資訊："
    echo "   https://github.com/lazyjerry/git-auto-push"
    echo ""
    
    # 顯示隨機感謝語
    show_random_thanks
}

# ========== 隨機感謝語 ==========
show_random_thanks() {
    # 感謝語清單（Jerry 風格）
    thanks_messages="
讓我們感謝 Jerry，他花了很多時間寫這個安裝腳本，結果你一分鐘就裝完了。
讓我們感謝 Jerry，他讓你不用再記那些 Git 指令，雖然 Jerry 本來也記不住。
讓我們感謝 Jerry，他需要一些鼓勵。請去打星星 https://github.com/lazyjerry/git-auto-push
讓我們感謝 Jerry，他可能正在某個角落 Debug，而你已經開始快樂 Coding 了。
讓我們感謝 Jerry，這些奇怪的結語，可能是他看了《幼女戰記》才會有這個無聊的結尾語。
讓我們感謝 Jerry，雖然這個工具不能幫你找到女朋友，但至少能幫你少打幾行指令。
讓我們感謝 Jerry，他簡化了複雜的 Git 工作流程。甘啊捏？
讓我們感謝 Jerry，他最近可能有點窮，如果這工具有幫到你，請請他喝杯咖啡。
讓我們感謝 Jerry，這個安裝腳本比他的感情生活還穩定。
讓我們感謝 Jerry，雖然人生依然艱難，但至少 Git 不再是問題，最後剩下你是最大的問題。
讓我們感謝 Jerry，他最近可能吃太胖，請督促他減肥。
讓我們感謝 Jerry，好玩一直玩。
讓我們感謝 Jerry，這工具雖然不能改變世界，但能少掉一些麻煩，多了一些 Bug。
"
    
    # 計算訊息數量並隨機選擇
    msg_count=$(echo "$thanks_messages" | grep -c "^[^$]" || echo "13")
    
    # 使用多種方式產生隨機數（POSIX 相容）
    if [ -r /dev/urandom ]; then
        random_num=$(od -An -tu4 -N4 /dev/urandom | tr -d ' ')
        random_index=$((random_num % msg_count + 1))
    else
        # 備用方案：使用時間戳
        random_index=$(($(date +%S) % msg_count + 1))
    fi
    
    # 取得對應的感謝語
    selected_msg=$(echo "$thanks_messages" | grep -v "^$" | sed -n "${random_index}p")
    
    if [ -n "$selected_msg" ]; then
        echo "────────────────────────────────────────────────────────────"
        printf "${GREEN}💚 %s${NC}\n" "$selected_msg"
        echo "────────────────────────────────────────────────────────────"
        echo ""
    fi
}

# ========== 配置文件設定 ==========
setup_config() {
    config_location="$1"
    config_dir_path=""
    config_file_path=""
    
    case "$config_location" in
        home)
            config_dir_path="$HOME/$CONFIG_DIR"
            ;;
        current)
            config_dir_path="$PWD/$CONFIG_DIR"
            ;;
        *)
            return 0
            ;;
    esac
    
    config_file_path="$config_dir_path/$CONFIG_FILE"
    
    # 建立配置目錄
    mkdir -p "$config_dir_path"
    
    echo ""
    header "配置文件設定"
    
    # 收集配置選項
    ai_tools=""
    default_username=""
    is_debug=""
    auto_include_ticket=""
    auto_check_quality=""
    main_branches=""
    
    # AI 工具順序
    echo "🤖 AI 工具優先順序設定"
    echo "   可用工具: copilot, gemini, codex, claude"
    echo "   多個工具用空格分隔，例如: copilot gemini codex claude"
    printf "   請輸入 AI 工具順序 [預設: copilot gemini codex claude]: "
    read ai_tools_input
    ai_tools="${ai_tools_input:-copilot gemini codex claude}"
    echo ""
    
    # 預設使用者名稱
    echo "👤 預設使用者名稱（用於分支命名）"
    current_git_user=""
    current_git_user=$(git config user.name 2>/dev/null || echo "")
    if [ -n "$current_git_user" ]; then
        printf "   請輸入使用者名稱 [預設: %s]: " "$current_git_user"
        read default_username
        default_username="${default_username:-$current_git_user}"
    else
        printf "   請輸入使用者名稱 [預設: jerry]: "
        read default_username
        default_username="${default_username:-jerry}"
    fi
    echo ""
    
    # 調試模式
    echo "🐛 調試模式"
    printf "   是否啟用調試模式？(y/N) [預設: N]: "
    read is_debug_input
    is_debug_input=$(echo "$is_debug_input" | tr '[:upper:]' '[:lower:]')
    case "$is_debug_input" in
        y|yes) is_debug="true" ;;
        *) is_debug="false" ;;
    esac
    echo ""
    
    # 任務編號自動帶入
    echo "🎫 任務編號自動帶入"
    echo "   從分支名稱偵測任務編號（如 JIRA-123）並加入 commit 訊息"
    printf "   是否啟用？(Y/n) [預設: Y]: "
    read auto_ticket_input
    auto_ticket_input=$(echo "$auto_ticket_input" | tr '[:upper:]' '[:lower:]')
    case "$auto_ticket_input" in
        n|no) auto_include_ticket="false" ;;
        *) auto_include_ticket="true" ;;
    esac
    echo ""
    
    # Commit 品質檢查
    echo "✅ Commit 訊息品質檢查"
    echo "   使用 AI 檢查 commit 訊息是否具有明確的目的"
    printf "   是否啟用？(Y/n) [預設: Y]: "
    read auto_quality_input
    auto_quality_input=$(echo "$auto_quality_input" | tr '[:upper:]' '[:lower:]')
    case "$auto_quality_input" in
        n|no) auto_check_quality="false" ;;
        *) auto_check_quality="true" ;;
    esac
    echo ""
    
    # 主分支候選清單
    echo "🌿 主分支候選清單（用於 PR 目標分支偵測）"
    echo "   多個分支用空格分隔，依順序偵測第一個存在的分支"
    printf "   請輸入主分支清單 [預設: uat main master]: "
    read main_branches_input
    main_branches="${main_branches_input:-uat main master}"
    echo ""
    
    # 生成配置文件
    info "正在生成配置文件..."
    
    # 轉換 AI 工具為陣列格式
    ai_tools_array=""
    for tool in $ai_tools; do
        ai_tools_array="${ai_tools_array}\"${tool}\" "
    done
    ai_tools_array=$(echo "$ai_tools_array" | xargs)
    
    # 轉換主分支為陣列格式
    main_branches_array=""
    for branch in $main_branches; do
        main_branches_array="${main_branches_array}\"${branch}\" "
    done
    main_branches_array=$(echo "$main_branches_array" | xargs)
    
    cat > "$config_file_path" << EOF
# Git 自動化工具配置文件
# 生成時間：$(date '+%Y-%m-%d %H:%M:%S')
# ================================

# ==============================================
# 通用設定
# ==============================================

# AI 工具優先順序
AI_TOOLS=(${ai_tools_array})

# 調試模式
IS_DEBUG=${is_debug}

# ==============================================
# git-auto-push.sh 專用設定
# ==============================================

# 任務編號自動帶入
AUTO_INCLUDE_TICKET=${auto_include_ticket}

# Commit 訊息品質檢查
AUTO_CHECK_COMMIT_QUALITY=${auto_check_quality}

# ==============================================
# git-auto-pr.sh 專用設定
# ==============================================

# 主分支候選清單
DEFAULT_MAIN_BRANCHES=(${main_branches_array})

# 預設使用者名稱
DEFAULT_USERNAME="${default_username}"

# PR 合併後分支刪除策略
AUTO_DELETE_BRANCH_AFTER_MERGE=false
EOF
    
    success "配置文件已建立：${config_file_path}"
    echo ""
    echo "📄 配置內容預覽："
    echo "────────────────────────────────────"
    grep -v "^#" "$config_file_path" | grep -v "^$" | sed 's/^/   /'
    echo "────────────────────────────────────"
}

# ========== 詢問配置設定 ==========
ask_config_setup() {
    echo ""
    echo "⚙️  是否要設定配置文件？"
    echo ""
    printf "  ${CYAN}1)${NC} 設定到 Home 目錄 (~/${CONFIG_DIR}/${CONFIG_FILE}) [推薦]\n"
    printf "  ${CYAN}2)${NC} 設定到當前目錄 (./${CONFIG_DIR}/${CONFIG_FILE})\n"
    printf "  ${CYAN}3)${NC} 跳過配置設定（使用預設值）\n"
    echo ""
    
    while true; do
        printf "請輸入選項 [1/2/3] (預設: 3): "
        read config_choice
        config_choice="${config_choice:-3}"
        
        case "$config_choice" in
            1)
                setup_config "home"
                break
                ;;
            2)
                setup_config "current"
                break
                ;;
            3)
                info "跳過配置設定，將使用預設值"
                echo ""
                echo "💡 之後可手動建立配置文件："
                echo "   mkdir -p ~/${CONFIG_DIR}"
                echo "   nano ~/${CONFIG_DIR}/${CONFIG_FILE}"
                break
                ;;
            *)
                warning "無效選項，請輸入 1、2 或 3"
                ;;
        esac
    done
}

# ========== 主程式 ==========
main() {
    install_mode=""
    skip_prompt=false
    skip_config=false
    
    # 解析參數
    while [ $# -gt 0 ]; do
        case "$1" in
            --global|-g)
                install_mode="global"
                skip_prompt=true
                shift
                ;;
            --local|-l)
                install_mode="local"
                skip_prompt=true
                shift
                ;;
            --no-config)
                skip_config=true
                shift
                ;;
            --help|-h)
                echo "Git 工作流程自動化工具集 - 安裝腳本"
                echo ""
                echo "使用方式："
                echo "  ./install.sh [選項]"
                echo ""
                echo "選項："
                echo "  --local, -l    安裝到當前目錄"
                echo "  --global, -g   安裝到 /usr/local/bin（需要 sudo）"
                echo "  --no-config    跳過配置文件設定"
                echo "  --help, -h     顯示此說明"
                echo ""
                echo "若不帶參數執行，將會互動式詢問安裝位置和配置設定。"
                exit 0
                ;;
            *)
                error "未知選項：$1"
                echo "使用 --help 查看說明"
                exit 1
                ;;
        esac
    done
    
    header "Git 工作流程自動化工具集 - 安裝程式"
    
    # 檢測下載工具
    check_download_tool
    
    # 檢查必要套件
    check_dependencies
    
    # 互動式選擇安裝模式
    if [ "$skip_prompt" = "false" ]; then
        echo ""
        echo "請選擇安裝方式："
        echo ""
        printf "  ${CYAN}1)${NC} 本地安裝 - 安裝到當前目錄 (${LOCAL_INSTALL_DIR})\n"
        printf "  ${CYAN}2)${NC} 全域安裝 - 安裝到系統路徑 (${GLOBAL_INSTALL_DIR}) [需要 sudo]\n"
        echo ""
        
        while true; do
            printf "請輸入選項 [1/2] (預設: 1): "
            read choice
            choice="${choice:-1}"
            
            case "$choice" in
                1|local|l)
                    install_mode="local"
                    break
                    ;;
                2|global|g)
                    install_mode="global"
                    break
                    ;;
                *)
                    warning "無效選項，請輸入 1 或 2"
                    ;;
            esac
        done
        echo ""
    fi
    
    if [ "$install_mode" = "global" ]; then
        info "安裝模式：全域安裝 (${GLOBAL_INSTALL_DIR})"
        
        # 檢查是否有 sudo 權限
        if ! sudo -v 2>/dev/null; then
            error "全域安裝需要 sudo 權限"
            exit 1
        fi
        
        install_scripts "$GLOBAL_INSTALL_DIR" "true"
        verify_installation "$GLOBAL_INSTALL_DIR" "true"
        
        # 詢問配置設定
        if [ "$skip_config" = "false" ]; then
            ask_config_setup
        fi
        
        show_usage "$GLOBAL_INSTALL_DIR" "true"
    else
        info "安裝模式：本地安裝 (${LOCAL_INSTALL_DIR})"
        install_scripts "$LOCAL_INSTALL_DIR" "false"
        verify_installation "$LOCAL_INSTALL_DIR" "false"
        
        # 詢問配置設定
        if [ "$skip_config" = "false" ]; then
            ask_config_setup
        fi
        
        show_usage "$LOCAL_INSTALL_DIR" "false"
    fi
}

# 執行主程式
main "$@"
