#!/bin/bash
#
# Git 工作流程自動化工具集 - 安裝腳本
# 
# 使用方式：
#   curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | bash
#   或
#   wget -qO- https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | bash
#
# 選項：
#   --local    僅安裝到當前目錄（預設）
#   --global   安裝到系統路徑 /usr/local/bin（需要 sudo）
#

set -e

# ========== 顏色定義 ==========
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# ========== 配置 ==========
readonly REPO_BASE_URL="https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master"
readonly SCRIPTS=("git-auto-push.sh" "git-auto-pr.sh")
readonly CONFIG_DIR=".git-auto-push-config"
readonly CONFIG_FILE=".env"
readonly GLOBAL_INSTALL_DIR="/usr/local/bin"
readonly LOCAL_INSTALL_DIR="${PWD}"

# ========== 輸出函數 ==========
info() {
    echo -e "${BLUE}ℹ️  ${NC}$1"
}

success() {
    echo -e "${GREEN}✅ ${NC}$1"
}

warning() {
    echo -e "${YELLOW}⚠️  ${NC}$1"
}

error() {
    echo -e "${RED}❌ ${NC}$1" >&2
}

header() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ========== 工具檢測 ==========
check_download_tool() {
    if command -v curl &> /dev/null; then
        DOWNLOAD_TOOL="curl"
        DOWNLOAD_CMD="curl -fsSL"
    elif command -v wget &> /dev/null; then
        DOWNLOAD_TOOL="wget"
        DOWNLOAD_CMD="wget -qO-"
    else
        error "需要 curl 或 wget 來下載檔案"
        error "請先安裝：brew install curl 或 apt install curl"
        exit 1
    fi
    info "使用 ${DOWNLOAD_TOOL} 進行下載"
}

# ========== 下載函數 ==========
download_file() {
    local url="$1"
    local output="$2"
    
    if [[ "$DOWNLOAD_TOOL" == "curl" ]]; then
        curl -fsSL "$url" -o "$output"
    else
        wget -q "$url" -O "$output"
    fi
}

# ========== 安裝函數 ==========
install_scripts() {
    local install_dir="$1"
    local use_sudo="$2"
    local sudo_cmd=""
    
    [[ "$use_sudo" == "true" ]] && sudo_cmd="sudo"
    
    for script in "${SCRIPTS[@]}"; do
        local url="${REPO_BASE_URL}/${script}"
        local script_name="${script%.sh}"  # 移除 .sh 副檔名（全域安裝用）
        local target_path
        
        if [[ "$use_sudo" == "true" ]]; then
            target_path="${install_dir}/${script_name}"
        else
            target_path="${install_dir}/${script}"
        fi
        
        info "下載 ${script}..."
        
        # 下載到暫存檔
        local tmp_file=$(mktemp)
        if ! download_file "$url" "$tmp_file"; then
            error "下載 ${script} 失敗"
            rm -f "$tmp_file"
            exit 1
        fi
        
        # 驗證下載內容
        if [[ ! -s "$tmp_file" ]]; then
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
        if [[ "$use_sudo" == "true" ]]; then
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
    local install_dir="$1"
    local is_global="$2"
    
    echo ""
    info "驗證安裝..."
    
    local all_ok=true
    for script in "${SCRIPTS[@]}"; do
        local script_name="${script%.sh}"
        local target_path
        
        if [[ "$is_global" == "true" ]]; then
            target_path="${install_dir}/${script_name}"
        else
            target_path="${install_dir}/${script}"
        fi
        
        if [[ -x "$target_path" ]]; then
            success "${target_path} 已安裝且可執行"
        else
            error "${target_path} 安裝失敗或不可執行"
            all_ok=false
        fi
    done
    
    if [[ "$all_ok" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# ========== 顯示使用說明 ==========
show_usage() {
    local install_dir="$1"
    local is_global="$2"
    
    echo ""
    header "安裝完成！"
    
    if [[ "$is_global" == "true" ]]; then
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
}

# ========== 配置文件設定 ==========
setup_config() {
    local config_location="$1"
    local config_dir_path=""
    local config_file_path=""
    
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
    local ai_tools=""
    local default_username=""
    local is_debug=""
    local auto_include_ticket=""
    local auto_check_quality=""
    local main_branches=""
    
    # AI 工具順序
    echo "🤖 AI 工具優先順序設定"
    echo "   可用工具：gemini, codex, claude"
    echo "   多個工具用空格分隔，例如：gemini codex claude"
    read -p "   請輸入 AI 工具順序 [預設: gemini codex claude]: " ai_tools_input
    ai_tools="${ai_tools_input:-gemini codex claude}"
    echo ""
    
    # 預設使用者名稱
    echo "👤 預設使用者名稱（用於分支命名）"
    local current_git_user=""
    current_git_user=$(git config user.name 2>/dev/null || echo "")
    if [[ -n "$current_git_user" ]]; then
        read -p "   請輸入使用者名稱 [預設: ${current_git_user}]: " default_username
        default_username="${default_username:-$current_git_user}"
    else
        read -p "   請輸入使用者名稱 [預設: jerry]: " default_username
        default_username="${default_username:-jerry}"
    fi
    echo ""
    
    # 調試模式
    echo "🐛 調試模式"
    read -p "   是否啟用調試模式？(y/N) [預設: N]: " is_debug_input
    case "${is_debug_input,,}" in
        y|yes) is_debug="true" ;;
        *) is_debug="false" ;;
    esac
    echo ""
    
    # 任務編號自動帶入
    echo "🎫 任務編號自動帶入"
    echo "   從分支名稱偵測任務編號（如 JIRA-123）並加入 commit 訊息"
    read -p "   是否啟用？(Y/n) [預設: Y]: " auto_ticket_input
    case "${auto_ticket_input,,}" in
        n|no) auto_include_ticket="false" ;;
        *) auto_include_ticket="true" ;;
    esac
    echo ""
    
    # Commit 品質檢查
    echo "✅ Commit 訊息品質檢查"
    echo "   使用 AI 檢查 commit 訊息是否具有明確的目的"
    read -p "   是否啟用？(Y/n) [預設: Y]: " auto_quality_input
    case "${auto_quality_input,,}" in
        n|no) auto_check_quality="false" ;;
        *) auto_check_quality="true" ;;
    esac
    echo ""
    
    # 主分支候選清單
    echo "🌿 主分支候選清單（用於 PR 目標分支偵測）"
    echo "   多個分支用空格分隔，依順序偵測第一個存在的分支"
    read -p "   請輸入主分支清單 [預設: uat main master]: " main_branches_input
    main_branches="${main_branches_input:-uat main master}"
    echo ""
    
    # 生成配置文件
    info "正在生成配置文件..."
    
    # 轉換 AI 工具為陣列格式
    local ai_tools_array=""
    for tool in $ai_tools; do
        ai_tools_array="${ai_tools_array}\"${tool}\" "
    done
    ai_tools_array=$(echo "$ai_tools_array" | xargs)
    
    # 轉換主分支為陣列格式
    local main_branches_array=""
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
    cat "$config_file_path" | grep -v "^#" | grep -v "^$" | sed 's/^/   /'
    echo "────────────────────────────────────"
}

# ========== 詢問配置設定 ==========
ask_config_setup() {
    echo ""
    echo "⚙️  是否要設定配置文件？"
    echo ""
    echo -e "  ${CYAN}1)${NC} 設定到 Home 目錄 (~/${CONFIG_DIR}/${CONFIG_FILE}) [推薦]"
    echo -e "  ${CYAN}2)${NC} 設定到當前目錄 (./${CONFIG_DIR}/${CONFIG_FILE})"
    echo -e "  ${CYAN}3)${NC} 跳過配置設定（使用預設值）"
    echo ""
    
    while true; do
        read -p "請輸入選項 [1/2/3] (預設: 3): " config_choice
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
    local install_mode=""
    local skip_prompt=false
    local skip_config=false
    
    # 解析參數
    while [[ $# -gt 0 ]]; do
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
    
    # 互動式選擇安裝模式
    if [[ "$skip_prompt" == "false" ]]; then
        echo ""
        echo "請選擇安裝方式："
        echo ""
        echo -e "  ${CYAN}1)${NC} 本地安裝 - 安裝到當前目錄 (${LOCAL_INSTALL_DIR})"
        echo -e "  ${CYAN}2)${NC} 全域安裝 - 安裝到系統路徑 (${GLOBAL_INSTALL_DIR}) [需要 sudo]"
        echo ""
        
        while true; do
            read -p "請輸入選項 [1/2] (預設: 1): " choice
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
    
    if [[ "$install_mode" == "global" ]]; then
        info "安裝模式：全域安裝 (${GLOBAL_INSTALL_DIR})"
        
        # 檢查是否有 sudo 權限
        if ! sudo -v 2>/dev/null; then
            error "全域安裝需要 sudo 權限"
            exit 1
        fi
        
        install_scripts "$GLOBAL_INSTALL_DIR" "true"
        verify_installation "$GLOBAL_INSTALL_DIR" "true"
        
        # 詢問配置設定
        if [[ "$skip_config" == "false" ]]; then
            ask_config_setup
        fi
        
        show_usage "$GLOBAL_INSTALL_DIR" "true"
    else
        info "安裝模式：本地安裝 (${LOCAL_INSTALL_DIR})"
        install_scripts "$LOCAL_INSTALL_DIR" "false"
        verify_installation "$LOCAL_INSTALL_DIR" "false"
        
        # 詢問配置設定
        if [[ "$skip_config" == "false" ]]; then
            ask_config_setup
        fi
        
        show_usage "$LOCAL_INSTALL_DIR" "false"
    fi
}

# 執行主程式
main "$@"
