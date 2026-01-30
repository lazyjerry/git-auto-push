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

# ========== 主程式 ==========
main() {
    local install_mode="local"
    
    # 解析參數
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global|-g)
                install_mode="global"
                shift
                ;;
            --local|-l)
                install_mode="local"
                shift
                ;;
            --help|-h)
                echo "Git 工作流程自動化工具集 - 安裝腳本"
                echo ""
                echo "使用方式："
                echo "  ./install.sh [選項]"
                echo ""
                echo "選項："
                echo "  --local, -l    安裝到當前目錄（預設）"
                echo "  --global, -g   安裝到 /usr/local/bin（需要 sudo）"
                echo "  --help, -h     顯示此說明"
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
    
    if [[ "$install_mode" == "global" ]]; then
        info "安裝模式：全域安裝 (${GLOBAL_INSTALL_DIR})"
        
        # 檢查是否有 sudo 權限
        if ! sudo -v 2>/dev/null; then
            error "全域安裝需要 sudo 權限"
            exit 1
        fi
        
        install_scripts "$GLOBAL_INSTALL_DIR" "true"
        verify_installation "$GLOBAL_INSTALL_DIR" "true"
        show_usage "$GLOBAL_INSTALL_DIR" "true"
    else
        info "安裝模式：本地安裝 (${LOCAL_INSTALL_DIR})"
        install_scripts "$LOCAL_INSTALL_DIR" "false"
        verify_installation "$LOCAL_INSTALL_DIR" "false"
        show_usage "$LOCAL_INSTALL_DIR" "false"
    fi
}

# 執行主程式
main "$@"
