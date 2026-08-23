#!/bin/bash
# -*- coding: utf-8 -*-

# git-auto-push.sh 全覆蓋自動化測試
# 使用方式：./tests/test-git-auto-push.sh
# 說明：不依賴測試框架，於隔離的臨時環境（獨立 HOME、臨時 git 倉庫、本地 bare origin）
#       執行單元測試（source 腳本直接呼叫函數）與整合測試（實際執行腳本、stdin 管線模擬互動）。
#       AI 工具以不存在的指令名稱隔離，全程不觸發外部服務。

# ==============================================
# 測試環境設置
# ==============================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$SCRIPT_DIR/../git-auto-push.sh"

if [ ! -f "$SCRIPT" ]; then
    printf '找不到待測腳本: %s\n' "$SCRIPT" >&2
    exit 1
fi

TEST_TMP=$(mktemp -d) || exit 1
REPO="$TEST_TMP/work-repo"
ORIGIN="$TEST_TMP/origin.git"
NOT_GIT_DIR="$TEST_TMP/not-a-git-dir"
OUT="$TEST_TMP/out.log"

cleanup() {
    rm -rf "$TEST_TMP"
}
trap cleanup EXIT

# 隔離使用者級與全域配置，並停用真實 AI 工具
export HOME="$TEST_TMP"
mkdir -p "$HOME/.git-auto-push-config" "$NOT_GIT_DIR"
cat > "$HOME/.git-auto-push-config/.env" <<'EOF'
AI_TOOLS=("nonexistent-ai-tool-for-test")
AUTO_CHECK_COMMIT_QUALITY=false
AUTO_INCLUDE_TICKET=true
IS_DEBUG=false
EOF

# ==============================================
# 測試輔助函數
# ==============================================

TESTS_RUN=0
TESTS_FAILED=0

pass() {
    printf '\033[0;32m  ✓ %s\033[0m\n' "$1"
}

fail() {
    printf '\033[0;31m  ✗ %s\033[0m\n' "$1"
    printf '\033[0;31m    %s\033[0m\n' "$2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

section() {
    printf '\n\033[1;36m== %s ==\033[0m\n' "$1"
}

assert_eq() {
    # $1=測試名稱 $2=期望值 $3=實際值
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$2" = "$3" ]; then
        pass "$1"
    else
        fail "$1" "期望 [$2] 實際 [$3]"
    fi
}

assert_exit() {
    # $1=測試名稱 $2=期望退出碼 $3=實際退出碼
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$2" = "$3" ]; then
        pass "$1"
    else
        fail "$1" "期望退出碼 [$2] 實際 [$3]"
    fi
}

assert_nonzero_exit() {
    # $1=測試名稱 $2=實際退出碼
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$2" != "0" ]; then
        pass "$1"
    else
        fail "$1" "期望非零退出碼，實際 [0]"
    fi
}

assert_contains() {
    # $1=測試名稱 $2=期望包含的字串 $3=檔案路徑
    TESTS_RUN=$((TESTS_RUN + 1))
    if grep -qF -- "$2" "$3" 2>/dev/null; then
        pass "$1"
    else
        fail "$1" "輸出不含 [$2]"
    fi
}

# 逾時保護：優先用 timeout，macOS 無此指令時 fallback 至 perl alarm
run_with_timeout() {
    local secs="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$secs" "$@"
    else
        perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
    fi
}

# 執行待測腳本（於 REPO 內），stdin 由第一參數餵入，輸出寫入 $OUT，回傳退出碼
run_push() {
    local stdin_data="$1"
    shift
    local rc=0
    (
        cd "$REPO" || exit 99
        printf '%s' "$stdin_data" | run_with_timeout 60 bash "$SCRIPT" "$@"
    ) > "$OUT" 2>&1 || rc=$?
    return $rc
}

# 目前暫存區檔案清單（排序後以空白連接；LC_ALL=C 避免 macOS collation 問題）
staged_files() {
    git -C "$REPO" diff --cached --name-only | LC_ALL=C sort | paste -sd' ' -
}

# 取得檔案選單第 N 行對應的路徑（與 select_files_to_add 相同的解析順序）
menu_path() {
    git -C "$REPO" status --porcelain | sed -n "${1}p" | cut -c4-
}

# 將選單路徑解析為實際會被暫存的檔案清單（未追蹤資料夾如 docs/ 展開為其下檔案）
resolve_menu_paths() {
    local p
    for p in "$@"; do
        case "$p" in
            */) git -C "$REPO" ls-files --others -- "$p" ;;
            *) printf '%s\n' "$p" ;;
        esac
    done | LC_ALL=C sort | paste -sd' ' -
}

# 重建測試倉庫與 bare origin（每組整合測試前呼叫，確保狀態乾淨）
setup_repo() {
    rm -rf "$REPO" "$ORIGIN"
    git init -q --bare "$ORIGIN"
    git init -q "$REPO" 2>/dev/null
    git -C "$REPO" checkout -q -b main 2>/dev/null
    git -C "$REPO" config user.name "Tester"
    git -C "$REPO" config user.email "tester@example.com"
    git -C "$REPO" remote add origin "$ORIGIN"
    printf 'base\n' > "$REPO/base.txt"
    git -C "$REPO" add . >/dev/null
    git -C "$REPO" commit -qm "chore: 初始提交"
    git -C "$REPO" push -q origin main
}

# 建立標準測試變更：兩個修改檔＋一個資料夾內新檔
make_changes() {
    printf 'file1 changed\n' > "$REPO/file1.txt"
    printf 'file2 changed\n' > "$REPO/file2.txt"
    mkdir -p "$REPO/docs"
    printf 'doc\n' > "$REPO/docs/doc1.md"
}

# 提交類互動流程的 stdin 行序（一律用 $'...' 字面字串，避免命令替換去除尾端換行造成錯位）：
#   [檔案選單（僅無 -f 時）] → 前綴選單選 12（無前綴）→ commit 訊息 →
#   跳過品質檢查(n) → DUMMY 行（confirm_commit 前的 read -t 0.1 會吃掉一行緩衝；
#   若未吃掉，確認迴圈會因 DUMMY 無效而重問並讀到最後的 y，兩種情況皆可通過）→ 確認(y)

# ==============================================
# A. 語法與基本 CLI
# ==============================================

section "A. 語法與基本 CLI"

bash -n "$SCRIPT" 2> "$OUT"
assert_exit "bash -n 語法檢查通過" 0 $?

bash -n "${BASH_SOURCE[0]}" 2> "$OUT"
assert_exit "測試腳本自身語法檢查通過" 0 $?

setup_repo

run_push "" --help
assert_exit "--help 退出碼為 0" 0 $?
assert_contains "--help 顯示 -f 用法" "指定檔案" "$OUT"
assert_contains "--help 顯示互動選檔說明" "互動選檔" "$OUT"

run_push "" --version
assert_exit "--version 退出碼為 0" 0 $?
assert_contains "--version 顯示版本號" "git-auto-push v" "$OUT"

make_changes
run_push "" --bogus-flag
assert_nonzero_exit "未知參數以非零退出" $?
assert_contains "未知參數顯示錯誤訊息" "未知參數" "$OUT"

run_push "" -f
assert_nonzero_exit "-f 未帶路徑以非零退出" $?
assert_contains "-f 未帶路徑顯示錯誤訊息" "至少一個檔案" "$OUT"

rc=0
(
    cd "$NOT_GIT_DIR" || exit 99
    printf '' | run_with_timeout 30 bash "$SCRIPT" 3
) > "$OUT" 2>&1 || rc=$?
assert_nonzero_exit "非 git 目錄以非零退出" $rc
assert_contains "非 git 目錄顯示錯誤訊息" "不是 Git 倉庫" "$OUT"

# ==============================================
# B. 單元測試（source 腳本直接呼叫函數）
# ==============================================

section "B. 單元測試"

setup_repo

# resolve_ai_command
actual=$(cd "$REPO" && source "$SCRIPT" && resolve_ai_command "gemini")
assert_eq "resolve_ai_command: gemini 映射為 agy" "agy" "$actual"
actual=$(cd "$REPO" && source "$SCRIPT" && resolve_ai_command "codex")
assert_eq "resolve_ai_command: 其他名稱原樣返回" "codex" "$actual"

# clean_ai_message：過濾 Node.js 雜訊並清理空白
raw_msg=$'(node:12345) DeprecationWarning: punycode is deprecated\n  新增登入功能  '
actual=$(cd "$REPO" && source "$SCRIPT" && clean_ai_message "$raw_msg")
assert_eq "clean_ai_message: 過濾 Node 警告並修剪空白" "新增登入功能" "$actual"

raw_msg=$'Loading credentials...\nAuthentication successful\n修正檔案上傳錯誤'
actual=$(cd "$REPO" && source "$SCRIPT" && clean_ai_message "$raw_msg")
assert_eq "clean_ai_message: 過濾認證訊息" "修正檔案上傳錯誤" "$actual"

# append_ticket_number_to_message
actual=$(cd "$REPO" && source "$SCRIPT" && TICKET_NUMBER="" append_ticket_number_to_message "訊息內容")
assert_eq "append_ticket: 無任務編號直接返回" "訊息內容" "$actual"
actual=$(cd "$REPO" && source "$SCRIPT" && TICKET_NUMBER="ABC-123" AUTO_INCLUDE_TICKET=true append_ticket_number_to_message "訊息內容")
assert_eq "append_ticket: 自動加入編號前綴" "[ABC-123] 訊息內容" "$actual"
actual=$(cd "$REPO" && source "$SCRIPT" && TICKET_NUMBER="ABC-123" AUTO_INCLUDE_TICKET=true append_ticket_number_to_message "[ABC-123] 訊息內容")
assert_eq "append_ticket: 已含編號不重複加入" "[ABC-123] 訊息內容" "$actual"

# initialize_ticket_number
git -C "$REPO" checkout -q -b feat-001
actual=$(cd "$REPO" && source "$SCRIPT" && initialize_ticket_number && printf '%s' "$TICKET_NUMBER")
assert_eq "initialize_ticket: feat-001 分支解析出編號" "feat-001" "$actual"
git -C "$REPO" checkout -q -b JIRA-123
actual=$(cd "$REPO" && source "$SCRIPT" && initialize_ticket_number && printf '%s' "$TICKET_NUMBER")
assert_eq "initialize_ticket: JIRA-123 分支解析出編號" "JIRA-123" "$actual"
git -C "$REPO" checkout -q main
actual=$(cd "$REPO" && source "$SCRIPT" && initialize_ticket_number && printf '%s' "$TICKET_NUMBER")
assert_eq "initialize_ticket: 主分支無任務編號" "" "$actual"

# get_remote_web_url
git -C "$REPO" remote set-url origin "git@github.com:user/repo.git"
actual=$(cd "$REPO" && source "$SCRIPT" && get_remote_web_url)
assert_eq "get_remote_web_url: SSH 短格式轉 https" "https://github.com/user/repo" "$actual"
git -C "$REPO" remote set-url origin "ssh://git@github.com/user/repo.git"
actual=$(cd "$REPO" && source "$SCRIPT" && get_remote_web_url)
assert_eq "get_remote_web_url: ssh:// 格式轉 https" "https://github.com/user/repo" "$actual"
git -C "$REPO" remote set-url origin "$ORIGIN"

# check_git_repository / get_git_status
rc=0
(cd "$REPO" && source "$SCRIPT" >/dev/null 2>&1 && check_git_repository) || rc=$?
assert_exit "check_git_repository: 倉庫內返回 0" 0 $rc
rc=0
(cd "$NOT_GIT_DIR" && source "$SCRIPT" >/dev/null 2>&1 && check_git_repository) || rc=$?
assert_nonzero_exit "check_git_repository: 倉庫外返回非零" $rc

make_changes
actual=$(cd "$REPO" && source "$SCRIPT" && get_git_status | wc -l | xargs)
assert_eq "get_git_status: 回報三筆變更" "3" "$actual"

# select_files_to_add（sourced，stdin 管線）
expected_path=$(menu_path 1)
actual=$(printf '1\n' | (cd "$REPO" && source "$SCRIPT" && select_files_to_add 2>/dev/null && printf '%s' "${SELECTED_ADD_PATHS[*]}"))
assert_eq "select_files: 選編號 1 對應第一個檔案" "$expected_path" "$actual"

actual=$(printf '\n' | (cd "$REPO" && source "$SCRIPT" && select_files_to_add 2>/dev/null && printf '%d' "${#SELECTED_ADD_PATHS[@]}"))
assert_eq "select_files: Enter 代表全部（空陣列）" "0" "$actual"

actual=$(printf '99\n1\n' | (cd "$REPO" && source "$SCRIPT" && select_files_to_add 2>/dev/null && printf '%s' "${SELECTED_ADD_PATHS[*]}"))
assert_eq "select_files: 無效編號重問後接受有效輸入" "$expected_path" "$actual"

# add_all_files（sourced）
(cd "$REPO" && source "$SCRIPT" >/dev/null 2>&1 && add_all_files "file1.txt" >/dev/null 2>&1)
assert_eq "add_all_files: 帶參數僅添加指定檔案" "file1.txt" "$(staged_files)"
git -C "$REPO" reset -q

(cd "$REPO" && source "$SCRIPT" >/dev/null 2>&1 && add_all_files >/dev/null 2>&1)
assert_eq "add_all_files: 不帶參數添加全部" "docs/doc1.md file1.txt file2.txt" "$(staged_files)"
git -C "$REPO" reset -q

setup_repo
rc=0
(cd "$REPO" && source "$SCRIPT" >/dev/null 2>&1 && add_all_files >/dev/null 2>&1) || rc=$?
assert_nonzero_exit "add_all_files: 無變更時返回非零" $rc

# ==============================================
# C. 模式 3（僅 add）：-f 與互動選單
# ==============================================

section "C. 模式 3：-f 指定與互動選單"

setup_repo
make_changes
run_push "" 3 -f file1.txt
assert_exit "3 -f 單檔: 退出碼 0" 0 $?
assert_eq "3 -f 單檔: 僅指定檔案進暫存區" "file1.txt" "$(staged_files)"

setup_repo
make_changes
run_push "" 3 -f docs/
assert_exit "3 -f 資料夾: 退出碼 0" 0 $?
assert_eq "3 -f 資料夾: 僅資料夾內容進暫存區" "docs/doc1.md" "$(staged_files)"

setup_repo
make_changes
run_push "" 3 -f file1.txt docs/
assert_exit "3 -f 多路徑: 退出碼 0" 0 $?
assert_eq "3 -f 多路徑: 指定路徑皆進暫存區" "docs/doc1.md file1.txt" "$(staged_files)"

setup_repo
make_changes
run_push "" 3 -f no-such-file.txt
assert_nonzero_exit "3 -f 不存在路徑: 非零退出" $?
assert_eq "3 -f 不存在路徑: 暫存區為空" "" "$(staged_files)"

setup_repo
make_changes
expected=$(resolve_menu_paths "$(menu_path 1)")
run_push $'1\n' 3
assert_exit "3 互動選單選 1: 退出碼 0" 0 $?
assert_eq "3 互動選單選 1: 僅第一個項目進暫存區" "$expected" "$(staged_files)"

setup_repo
make_changes
run_push $'\n' 3
assert_exit "3 互動選單 Enter: 退出碼 0" 0 $?
assert_eq "3 互動選單 Enter: 全部進暫存區" "docs/doc1.md file1.txt file2.txt" "$(staged_files)"

setup_repo
make_changes
expected=$(resolve_menu_paths "$(menu_path 1)" "$(menu_path 3)")
run_push $'1 3\n' 3
assert_exit "3 互動選單多選 1 3: 退出碼 0" 0 $?
assert_eq "3 互動選單多選 1 3: 對應項目進暫存區" "$expected" "$(staged_files)"

# ==============================================
# D. 提交與推送流程（模式 2 / 5 / 1 / 4 / -a）
# ==============================================

section "D. 提交與推送流程"

# 模式 2：本地提交（互動選單 Enter 全選 + 手動訊息），不推送
setup_repo
make_changes
run_push $'\n12\n新增測試檔案與文件內容\nn\nDUMMY\ny\n' 2
assert_exit "模式 2: 退出碼 0" 0 $?
assert_eq "模式 2: commit 訊息正確" "新增測試檔案與文件內容" "$(git -C "$REPO" log -1 --pretty=%s)"
local_head=$(git -C "$REPO" rev-parse HEAD)
origin_head=$(git -C "$ORIGIN" rev-parse main)
TESTS_RUN=$((TESTS_RUN + 1))
if [ "$local_head" != "$origin_head" ]; then
    pass "模式 2: 未推送到遠端"
else
    fail "模式 2: 未推送到遠端" "origin HEAD 不應等於本地 HEAD"
fi

# 模式 5：僅提交（搭配 -f 只暫存 file1），file2 維持未提交
setup_repo
make_changes
run_push $'12\n修正檔案一的內容\nn\nDUMMY\ny\n' 5 -f file1.txt
assert_exit "模式 5 + -f: 退出碼 0" 0 $?
assert_eq "模式 5 + -f: commit 訊息正確" "修正檔案一的內容" "$(git -C "$REPO" log -1 --pretty=%s)"
committed=$(git -C "$REPO" diff-tree --no-commit-id --name-only -r HEAD | LC_ALL=C sort | paste -sd' ' -)
assert_eq "模式 5 + -f: 僅提交指定檔案" "file1.txt" "$committed"

# 模式 1：完整流程（-f 指定單檔），驗證推送到 bare origin
setup_repo
make_changes
run_push $'12\n新增檔案一並推送\nn\nDUMMY\ny\n' 1 -f file1.txt
assert_exit "模式 1 + -f: 退出碼 0" 0 $?
assert_eq "模式 1 + -f: 本地與遠端 HEAD 一致" "$(git -C "$REPO" rev-parse HEAD)" "$(git -C "$ORIGIN" rev-parse main)"
assert_contains "模式 1 + -f: 顯示推送成功" "成功推送到遠端分支" "$OUT"

# 模式 4：全自動（AI 全部失敗 → 預設訊息），不需 stdin、不進選單
setup_repo
make_changes
run_push "" 4
assert_exit "模式 4: 退出碼 0" 0 $?
assert_eq "模式 4: 使用預設 commit 訊息" "自動提交：更新專案檔案" "$(git -C "$REPO" log -1 --pretty=%s)"
assert_eq "模式 4: 已推送到遠端" "$(git -C "$REPO" rev-parse HEAD)" "$(git -C "$ORIGIN" rev-parse main)"

# --auto / -a：與模式 4 等效
setup_repo
make_changes
run_push "" --auto
assert_exit "--auto: 退出碼 0" 0 $?
assert_eq "--auto: 已推送到遠端" "$(git -C "$REPO" rev-parse HEAD)" "$(git -C "$ORIGIN" rev-parse main)"

# -a -f：全自動僅提交指定檔案
setup_repo
make_changes
run_push "" -a -f file2.txt
assert_exit "-a -f: 退出碼 0" 0 $?
committed=$(git -C "$REPO" diff-tree --no-commit-id --name-only -r HEAD | LC_ALL=C sort | paste -sd' ' -)
assert_eq "-a -f: 僅提交指定檔案" "file2.txt" "$committed"

# ==============================================
# E. 模式 6 / 7、任務編號、配置載入、其他情境
# ==============================================

section "E. 模式 6 / 7 與其他情境"

# 模式 6：倉庫資訊（乾淨工作區經由無變更選單進入）
setup_repo
run_push $'6\n'
assert_exit "模式 6: 退出碼 0" 0 $?
assert_contains "模式 6: 顯示倉庫資訊標題" "Git 倉庫資訊" "$OUT"
assert_contains "模式 6: 顯示當前分支" "main" "$OUT"

# 無變更時取消操作
setup_repo
run_push $'x\n'
assert_exit "無變更取消: 退出碼 0" 0 $?
assert_contains "無變更取消: 顯示取消訊息" "已取消操作" "$OUT"

# 模式 7：乾淨工作區 amend 成功
setup_repo
run_push $'7\nchore: 修正初始提交訊息\nn\nDUMMY\ny\n'
assert_exit "模式 7 amend: 退出碼 0" 0 $?
assert_eq "模式 7 amend: 訊息已改寫" "chore: 修正初始提交訊息" "$(git -C "$REPO" log -1 --pretty=%s)"

# 模式 7：有未提交變更時中止
setup_repo
make_changes
before_msg=$(git -C "$REPO" log -1 --pretty=%s)
run_push $'\n' 7
assert_contains "模式 7 有變更: 顯示中止警告" "尚未提交的變更" "$OUT"
assert_eq "模式 7 有變更: 訊息未被改寫" "$before_msg" "$(git -C "$REPO" log -1 --pretty=%s)"

# 任務編號整合：feat-001 分支提交自動加 [feat-001] 前綴
setup_repo
git -C "$REPO" checkout -q -b feat-001
make_changes
run_push $'\n12\n新增任務相關功能\nn\nDUMMY\ny\n' 2
assert_exit "任務編號: 退出碼 0" 0 $?
assert_eq "任務編號: 訊息含 [feat-001] 前綴" "[feat-001] 新增任務相關功能" "$(git -C "$REPO" log -1 --pretty=%s)"

# 配置載入優先級：專案級（PWD）優先於 HOME 級
setup_repo
mkdir -p "$REPO/.git-auto-push-config"
cat > "$REPO/.git-auto-push-config/.env" <<'EOF'
AI_TOOLS=("nonexistent-ai-tool-for-test")
IS_DEBUG=true
EOF
run_push "" --version
assert_contains "配置載入: 專案級配置優先載入" "已加載配置文件: $REPO/.git-auto-push-config/.env" "$OUT"
rm -rf "$REPO/.git-auto-push-config"

# ==============================================
# F. --upgrade 自我更新（全程離線，不觸發網路）
# ==============================================

section "F. --upgrade 自我更新"

# 版本比較：0=相同、1=前者較新、2=前者較舊
rc=0; (source "$SCRIPT" && compare_versions "v2.12.0" "v2.11.0") || rc=$?
assert_eq "compare_versions: 較新版本回傳 1" "1" "$rc"
rc=0; (source "$SCRIPT" && compare_versions "v2.11.0" "v2.11.0") || rc=$?
assert_eq "compare_versions: 版本相同回傳 0" "0" "$rc"
rc=0; (source "$SCRIPT" && compare_versions "v2.10.9" "v2.11.0") || rc=$?
assert_eq "compare_versions: 較舊版本回傳 2" "2" "$rc"
rc=0; (source "$SCRIPT" && compare_versions "2.11" "v2.11.0") || rc=$?
assert_eq "compare_versions: 位數不同且數值相等回傳 0" "0" "$rc"
rc=0; (source "$SCRIPT" && compare_versions "v3.0.0" "v2.99.99") || rc=$?
assert_eq "compare_versions: 主版本優先比較" "1" "$rc"

# 版本號讀取
actual=$(source "$SCRIPT" && extract_script_version "$SCRIPT")
assert_eq "extract_script_version: 讀出腳本自身版本" "$(grep -m1 '^readonly VERSION=' "$SCRIPT" | sed 's/^readonly VERSION="//; s/".*$//')" "$actual"

printf 'echo no version constant\n' > "$TEST_TMP/no-version.sh"
actual=$(source "$SCRIPT" && extract_script_version "$TEST_TMP/no-version.sh")
assert_eq "extract_script_version: 無版本常數時回傳空字串" "" "$actual"

# 下載內容驗證：空檔 / 無 shebang / 語法錯誤 / 合法腳本
: > "$TEST_TMP/dl-empty.sh"
rc=0; (source "$SCRIPT" && validate_downloaded_script "$TEST_TMP/dl-empty.sh") 2>/dev/null || rc=$?
assert_nonzero_exit "validate_downloaded_script: 空檔不通過" "$rc"

printf '<html>404: Not Found</html>\n' > "$TEST_TMP/dl-html.sh"
rc=0; (source "$SCRIPT" && validate_downloaded_script "$TEST_TMP/dl-html.sh") 2>/dev/null || rc=$?
assert_nonzero_exit "validate_downloaded_script: 非腳本內容不通過" "$rc"

printf '#!/bin/bash\nif [ 1\n' > "$TEST_TMP/dl-broken.sh"
rc=0; (source "$SCRIPT" && validate_downloaded_script "$TEST_TMP/dl-broken.sh") 2>/dev/null || rc=$?
assert_nonzero_exit "validate_downloaded_script: 語法錯誤不通過" "$rc"

printf '#!/bin/bash\nreadonly VERSION="v9.9.9"\n' > "$TEST_TMP/dl-valid.sh"
rc=0; (source "$SCRIPT" && validate_downloaded_script "$TEST_TMP/dl-valid.sh") 2>/dev/null || rc=$?
assert_exit "validate_downloaded_script: 合法腳本通過" 0 "$rc"

# 自身路徑解析（含符號連結）
actual=$(source "$SCRIPT" && get_self_path)
assert_eq "get_self_path: 回傳腳本實體路徑" "$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")" "$actual"

ln -sf "$SCRIPT" "$TEST_TMP/git-auto-push-link"
actual=$(source "$TEST_TMP/git-auto-push-link" && get_self_path)
assert_eq "get_self_path: 解析符號連結至實體檔案" "$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")" "$actual"

# 說明文件涵蓋 --upgrade
run_push "" --help
assert_contains "--help 顯示 --upgrade 用法" "--upgrade" "$OUT"
assert_contains "--help 說明會自動備份" ".bak" "$OUT"

# 無 curl/wget 時應報錯並非零退出（以僅含必要指令的 PATH 模擬）
NO_NET_BIN="$TEST_TMP/no-net-bin"
mkdir -p "$NO_NET_BIN"
for cmd in dirname basename mktemp grep sed head cat tr xargs rm cp mv chmod date git; do
    cmd_path=$(command -v "$cmd" 2>/dev/null) || continue
    ln -sf "$cmd_path" "$NO_NET_BIN/$cmd"
done
BASH_BIN=$(command -v bash)

rc=0
(
    cd "$NOT_GIT_DIR" || exit 99
    printf '' | run_with_timeout 30 /usr/bin/env PATH="$NO_NET_BIN" "$BASH_BIN" "$SCRIPT" --upgrade
) > "$OUT" 2>&1 || rc=$?
assert_nonzero_exit "--upgrade 無 curl/wget 時以非零退出" "$rc"
assert_contains "--upgrade 無下載工具顯示錯誤訊息" "需要 curl 或 wget" "$OUT"
assert_contains "--upgrade 顯示目標檔案路徑" "$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")" "$OUT"

# --upgrade 不需身處 Git 倉庫（上一步已在非 git 目錄執行）
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qF "不是 Git 倉庫" "$OUT"; then
    fail "--upgrade 於非 git 目錄不做倉庫檢查" "輸出出現了 Git 倉庫檢查錯誤"
else
    pass "--upgrade 於非 git 目錄不做倉庫檢查"
fi

# ==============================================
# 測試結果摘要
# ==============================================

printf '\n==================================================\n'
if [ "$TESTS_FAILED" -eq 0 ]; then
    printf '\033[1;32m✅ 全部通過：%d / %d\033[0m\n' "$TESTS_RUN" "$TESTS_RUN"
    exit 0
else
    printf '\033[0;31m❌ 失敗 %d 項（共 %d 項）\033[0m\n' "$TESTS_FAILED" "$TESTS_RUN"
    exit 1
fi
