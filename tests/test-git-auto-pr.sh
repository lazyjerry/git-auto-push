#!/bin/bash
# -*- coding: utf-8 -*-

# git-auto-pr.sh 自動化測試
# 使用方式：./tests/test-git-auto-pr.sh
# 說明：不依賴測試框架，於隔離的臨時環境（獨立 HOME、臨時 git 倉庫、本地 bare origin）
#       執行單元測試（source 腳本直接呼叫函數）與整合測試（實際執行腳本、stdin 管線模擬互動）。
#       GitHub CLI 以假 gh shim 模擬（記錄呼叫、依環境變數回應），全程離線、不觸發外部服務。

# ==============================================
# 測試環境設置
# ==============================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$SCRIPT_DIR/../git-auto-pr.sh"

if [ ! -f "$SCRIPT" ]; then
    printf '找不到待測腳本: %s\n' "$SCRIPT" >&2
    exit 1
fi

TEST_TMP=$(mktemp -d) || exit 1
REPO="$TEST_TMP/work-repo"
ORIGIN="$TEST_TMP/origin.git"
NOT_GIT_DIR="$TEST_TMP/not-a-git-dir"
FAKE_BIN="$TEST_TMP/bin"
FAKE_GH_LOG="$TEST_TMP/gh-calls.log"
OUT="$TEST_TMP/out.log"

cleanup() {
    rm -rf "$TEST_TMP"
}
trap cleanup EXIT

# 隔離使用者級與全域配置，並停用真實 AI 工具
export HOME="$TEST_TMP"
mkdir -p "$HOME/.git-auto-push-config" "$NOT_GIT_DIR" "$FAKE_BIN"
cat > "$HOME/.git-auto-push-config/.env" <<'EOF'
AI_TOOLS=("nonexistent-ai-tool-for-test")
DEFAULT_USERNAME="jerry"
AUTO_DELETE_BRANCH_AFTER_MERGE=false
IS_DEBUG=false
EOF

# 假 gh shim：記錄所有呼叫，依 FAKE_GH_* 環境變數決定回應
cat > "$FAKE_BIN/gh" <<'EOF'
#!/bin/bash
echo "gh $*" >> "$FAKE_GH_LOG"
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
    [ "$FAKE_GH_AUTH" = "fail" ] && exit 1
    exit 0
fi
if [ "$1" = "pr" ]; then
    case "$2" in
        create)
            echo "https://github.com/tester/repo/pull/1"
            exit 0
            ;;
        list)
            printf '%s' "$FAKE_GH_PR_LIST"
            exit 0
            ;;
        view)
            case "$*" in
                *--json*)
                    if [ -n "$FAKE_GH_PR_VIEW_JSON" ]; then
                        printf '%s\n' "$FAKE_GH_PR_VIEW_JSON"
                        exit 0
                    fi
                    exit 1
                    ;;
                *)
                    echo "PR #1 detail"
                    exit 0
                    ;;
            esac
            ;;
        close|reopen|comment|merge)
            exit 0
            ;;
    esac
fi
exit 0
EOF
chmod +x "$FAKE_BIN/gh"
export FAKE_GH_LOG

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

# 執行待測腳本（於 REPO 內、假 gh 在 PATH 最前），stdin 由第一參數餵入，輸出寫入 $OUT
run_pr() {
    local stdin_data="$1"
    shift
    local rc=0
    : > "$FAKE_GH_LOG"
    (
        cd "$REPO" || exit 99
        printf '%s' "$stdin_data" | PATH="$FAKE_BIN:$PATH" run_with_timeout 60 bash "$SCRIPT" "$@"
    ) > "$OUT" 2>&1 || rc=$?
    return $rc
}

# 重建測試倉庫與 bare origin（main 已推送）
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

# ==============================================
# A. 語法與基本 CLI
# ==============================================

section "A. 語法與基本 CLI"

bash -n "$SCRIPT" 2> "$OUT"
assert_exit "bash -n 語法檢查通過" 0 $?

bash -n "${BASH_SOURCE[0]}" 2> "$OUT"
assert_exit "測試腳本自身語法檢查通過" 0 $?

setup_repo

run_pr "" --help
assert_exit "--help 退出碼為 0" 0 $?

run_pr "" --version
assert_exit "--version 退出碼為 0" 0 $?
assert_contains "--version 顯示版本號" "git-auto-pr v" "$OUT"

# --auto 已移除：顯示提醒後仍進入互動選單（以選項 5 + Enter 取消收尾）
run_pr $'5\n\n' --auto
assert_exit "--auto 提醒後可正常結束" 0 $?
assert_contains "--auto 顯示已移除提醒" "全自動模式已移除" "$OUT"

rc=0
(
    cd "$NOT_GIT_DIR" || exit 99
    printf '' | PATH="$FAKE_BIN:$PATH" run_with_timeout 30 bash "$SCRIPT"
) > "$OUT" 2>&1 || rc=$?
assert_nonzero_exit "非 git 目錄以非零退出" $rc
assert_contains "非 git 目錄顯示錯誤訊息" "不是 Git 倉庫" "$OUT"

# gh 未安裝：以僅含系統目錄的 PATH 執行（git 在 /usr/bin，gh 不在）
rc=0
(
    cd "$REPO" || exit 99
    printf '' | PATH="/usr/bin:/bin" run_with_timeout 30 bash "$SCRIPT"
) > "$OUT" 2>&1 || rc=$?
if command -v /usr/bin/gh >/dev/null 2>&1 || [ -x "/usr/bin/gh" ] || [ -x "/bin/gh" ]; then
    printf '\033[1;33m  ⚠ 略過「gh 未安裝」測試（系統目錄中存在 gh）\033[0m\n'
else
    assert_nonzero_exit "gh 未安裝以非零退出" $rc
    assert_contains "gh 未安裝顯示錯誤訊息" "未安裝 gh CLI" "$OUT"
fi

# gh 未登入：假 gh 的 auth status 回傳失敗
rc=0
(
    cd "$REPO" || exit 99
    printf '' | PATH="$FAKE_BIN:$PATH" FAKE_GH_AUTH=fail run_with_timeout 30 bash "$SCRIPT"
) > "$OUT" 2>&1 || rc=$?
assert_nonzero_exit "gh 未登入以非零退出" $rc
assert_contains "gh 未登入顯示錯誤訊息" "gh CLI 未登入" "$OUT"

# 選單：無效輸入重問後接受有效輸入
run_pr $'9\n5\n\n'
assert_exit "選單無效輸入後重問: 退出碼 0" 0 $?
assert_contains "選單顯示無效選項警告" "無效選項" "$OUT"

# ==============================================
# B. 單元測試（source 腳本直接呼叫函數）
# ==============================================

section "B. 單元測試"

setup_repo

# resolve_ai_command
actual=$(cd "$REPO" && source "$SCRIPT" && resolve_ai_command "gemini")
assert_eq "resolve_ai_command: gemini 映射為 agy" "agy" "$actual"

# clean_ai_message
raw_msg=$'(node:12345) DeprecationWarning: punycode is deprecated\n  新增登入功能  '
actual=$(cd "$REPO" && source "$SCRIPT" && clean_ai_message "$raw_msg")
assert_eq "clean_ai_message: 過濾 Node 警告並修剪空白" "新增登入功能" "$actual"

# validate_and_standardize_issue_key
actual=$(cd "$REPO" && source "$SCRIPT" && validate_and_standardize_issue_key "jira-123")
rc=$?
assert_eq "issue_key: 小寫轉大寫標準格式" "JIRA-123" "$actual"
assert_exit "issue_key: 標準格式返回 0" 0 $rc

actual=$(cd "$REPO" && source "$SCRIPT" && validate_and_standardize_issue_key "  proj_001  ")
rc=$?
assert_eq "issue_key: 底線格式含空白清理" "PROJ_001" "$actual"
assert_exit "issue_key: 底線格式返回 0" 0 $rc

actual=$(cd "$REPO" && source "$SCRIPT" && validate_and_standardize_issue_key "HOTFIX")
rc=$?
assert_eq "issue_key: 無數字部分仍可接受" "HOTFIX" "$actual"
assert_exit "issue_key: 可接受格式返回 3" 3 $rc

(cd "$REPO" && source "$SCRIPT" >/dev/null 2>&1 && validate_and_standardize_issue_key "123ABC" >/dev/null)
assert_exit "issue_key: 數字開頭返回 2" 2 $?

(cd "$REPO" && source "$SCRIPT" >/dev/null 2>&1 && validate_and_standardize_issue_key "AB C!" >/dev/null)
assert_exit "issue_key: 含非法字元返回 1" 1 $?

# clean_branch_name
actual=$(cd "$REPO" && source "$SCRIPT" && clean_branch_name "feature/user-login")
assert_eq "clean_branch_name: 標準名稱原樣通過" "feature/user-login" "$actual"

actual=$(cd "$REPO" && source "$SCRIPT" && clean_branch_name "分支名稱: feature/user-login")
assert_eq "clean_branch_name: 移除描述性前綴" "feature/user-login" "$actual"

actual=$(cd "$REPO" && source "$SCRIPT" && clean_branch_name "feature/User-Login")
assert_eq "clean_branch_name: 標準化為小寫" "feature/user-login" "$actual"

actual=$(cd "$REPO" && source "$SCRIPT" && clean_branch_name "建議分支 feature/add-search 供參考")
assert_eq "clean_branch_name: 從雜訊中提取分支名稱" "feature/add-search" "$actual"

rc=0
actual=$(cd "$REPO" && source "$SCRIPT" && clean_branch_name "完全沒有分支格式的文字") || rc=$?
assert_eq "clean_branch_name: 無效輸入返回空值" "" "$actual"
assert_nonzero_exit "clean_branch_name: 無效輸入返回非零" $rc

# format_pr_content / format_pr_body
result=$(cd "$REPO" && source "$SCRIPT" && format_pr_content "add login feature" "簡短描述")
assert_eq "format_pr_content: 標題首字母大寫" "Add login feature" "${result%%|||*}"

body=$(cd "$REPO" && source "$SCRIPT" && format_pr_body "新增功能")
printf '%s' "$body" > "$TEST_TMP/body.txt"
assert_contains "format_pr_body: 短內容加上功能變更結構" "## 📝 功能變更" "$TEST_TMP/body.txt"
assert_contains "format_pr_body: 短內容加上技術實作清單" "功能測試通過" "$TEST_TMP/body.txt"

body=$(cd "$REPO" && source "$SCRIPT" && format_pr_body "# 自訂標題
既有的 Markdown 內容")
assert_eq "format_pr_body: 既有 Markdown 保持原格式" "# 自訂標題" "$(printf '%s' "$body" | head -n 1)"

# generate_ai_branch_prompt / generate_ai_pr_prompt
prompt=$(cd "$REPO" && source "$SCRIPT" && generate_ai_branch_prompt "jerry" "feature" "JIRA-1" "")
printf '%s' "$prompt" > "$TEST_TMP/prompt.txt"
assert_contains "branch_prompt: 含 username/type/issue 格式" "jerry/feature/JIRA-1" "$TEST_TMP/prompt.txt"

prompt=$(cd "$REPO" && source "$SCRIPT" && generate_ai_pr_prompt "JIRA-9" "jerry/feature/jira-9")
printf '%s' "$prompt" > "$TEST_TMP/prompt.txt"
assert_contains "pr_prompt: 含 issue key" "JIRA-9" "$TEST_TMP/prompt.txt"
assert_contains "pr_prompt: 含分支名稱" "jerry/feature/jira-9" "$TEST_TMP/prompt.txt"

# 分支偵測相關
actual=$(cd "$REPO" && source "$SCRIPT" && get_current_branch)
assert_eq "get_current_branch: 回傳 main" "main" "$actual"

actual=$(cd "$REPO" && source "$SCRIPT" && get_main_branch)
assert_eq "get_main_branch: 依候選清單偵測到 main" "main" "$actual"

rc=0
(cd "$REPO" && source "$SCRIPT" >/dev/null 2>&1 && check_main_branch) || rc=$?
assert_exit "check_main_branch: 在主分支返回 0" 0 $rc

git -C "$REPO" checkout -q -b feature-branch
rc=0
(cd "$REPO" && source "$SCRIPT" >/dev/null 2>&1 && check_main_branch) || rc=$?
assert_nonzero_exit "check_main_branch: 非主分支返回非零" $rc
git -C "$REPO" checkout -q main

# get_main_branch：無任何主分支候選時報錯退出
rc=0
(
    cd "$TEST_TMP" && rm -rf trunk-repo && git init -q trunk-repo 2>/dev/null &&
    cd trunk-repo && git checkout -q -b trunk 2>/dev/null &&
    git config user.name t && git config user.email t@e.co &&
    source "$SCRIPT" >/dev/null 2>&1 && get_main_branch >/dev/null 2>&1
) || rc=$?
assert_nonzero_exit "get_main_branch: 找不到主分支時非零退出" $rc

# check_gh_cli：三種狀態
rc=0
(cd "$REPO" && PATH="$FAKE_BIN:$PATH" && source "$SCRIPT" >/dev/null 2>&1 && check_gh_cli) || rc=$?
assert_exit "check_gh_cli: 假 gh 正常返回 0" 0 $rc

rc=0
(cd "$REPO" && PATH="$FAKE_BIN:$PATH" && export FAKE_GH_AUTH=fail && source "$SCRIPT" >/dev/null 2>&1 && check_gh_cli) || rc=$?
assert_exit "check_gh_cli: 未登入返回 2" 2 $rc

rc=0
(cd "$REPO" && PATH="/usr/bin:/bin" && source "$SCRIPT" >/dev/null 2>&1 && check_gh_cli) || rc=$?
if [ -x "/usr/bin/gh" ] || [ -x "/bin/gh" ]; then
    printf '\033[1;33m  ⚠ 略過「check_gh_cli 未安裝」測試（系統目錄中存在 gh）\033[0m\n'
else
    assert_exit "check_gh_cli: 未安裝返回 1" 1 $rc
fi

# ==============================================
# C. 模式 1：建立功能分支
# ==============================================

section "C. 模式 1：建立功能分支"

# 在主分支上：issue key + 預設使用者 + 類型 3(feature)
setup_repo
run_pr $'1\nJIRA-123\n\n3\n'
assert_exit "模式 1: 退出碼 0" 0 $?
assert_eq "模式 1: 建立並切換到標準命名分支" "jerry/feature/jira-123" "$(git -C "$REPO" branch --show-current)"

# 無效 issue key 重問後接受有效輸入
setup_repo
run_pr $'1\n123abc\nJIRA-456\n\n2\n'
assert_exit "模式 1 無效 issue key: 退出碼 0" 0 $?
assert_contains "模式 1 無效 issue key: 顯示字母開頭警告" "必須以英文字母開頭" "$OUT"
assert_eq "模式 1 無效 issue key: 重問後建立 bug 分支" "jerry/bug/jira-456" "$(git -C "$REPO" branch --show-current)"

# 不在主分支上：詢問切換（Enter=同意）後建立
setup_repo
git -C "$REPO" checkout -q -b other-branch
run_pr $'1\n\nJIRA-789\n\n3\n'
assert_exit "模式 1 非主分支: 退出碼 0" 0 $?
assert_contains "模式 1 非主分支: 顯示切換詢問" "當前不在主分支" "$OUT"
assert_eq "模式 1 非主分支: 切換後建立分支" "jerry/feature/jira-789" "$(git -C "$REPO" branch --show-current)"

# 分支已存在：詢問切換到現有分支（Enter=同意）
setup_repo
git -C "$REPO" branch jerry/feature/jira-123
run_pr $'1\nJIRA-123\n\n3\n\n'
assert_exit "模式 1 分支已存在: 退出碼 0" 0 $?
assert_contains "模式 1 分支已存在: 顯示已存在警告" "已存在" "$OUT"
assert_eq "模式 1 分支已存在: 切換到現有分支" "jerry/feature/jira-123" "$(git -C "$REPO" branch --show-current)"

# ==============================================
# D. 模式 5：刪除分支
# ==============================================

section "D. 模式 5：刪除分支"

# Enter 取消
setup_repo
git -C "$REPO" branch feat-x
run_pr $'5\n\n'
assert_exit "模式 5 取消: 退出碼 0" 0 $?
assert_contains "模式 5 取消: 顯示取消訊息" "已取消刪除分支操作" "$OUT"
TESTS_RUN=$((TESTS_RUN + 1))
if git -C "$REPO" show-ref --verify --quiet refs/heads/feat-x; then
    pass "模式 5 取消: 分支仍存在"
else
    fail "模式 5 取消: 分支仍存在" "feat-x 不應被刪除"
fi

# 刪除已合併分支
setup_repo
git -C "$REPO" branch feat-x
run_pr $'5\n1\ny\n'
assert_exit "模式 5 刪除已合併分支: 退出碼 0" 0 $?
TESTS_RUN=$((TESTS_RUN + 1))
if git -C "$REPO" show-ref --verify --quiet refs/heads/feat-x; then
    fail "模式 5 刪除已合併分支: 分支已刪除" "feat-x 仍存在"
else
    pass "模式 5 刪除已合併分支: 分支已刪除"
fi

# 未合併分支：需二次確認強制刪除
setup_repo
git -C "$REPO" checkout -q -b feat-unmerged
printf 'wip\n' > "$REPO/wip.txt"
git -C "$REPO" add . >/dev/null && git -C "$REPO" commit -qm "wip: 未合併變更"
git -C "$REPO" checkout -q main
run_pr $'5\n1\ny\ny\n'
assert_exit "模式 5 強制刪除: 退出碼 0" 0 $?
assert_contains "模式 5 強制刪除: 顯示未合併警告" "未合併的變更" "$OUT"
TESTS_RUN=$((TESTS_RUN + 1))
if git -C "$REPO" show-ref --verify --quiet refs/heads/feat-unmerged; then
    fail "模式 5 強制刪除: 分支已刪除" "feat-unmerged 仍存在"
else
    pass "模式 5 強制刪除: 分支已刪除"
fi

# 刪除當前分支：先切換到主分支再刪除
setup_repo
git -C "$REPO" checkout -q -b feat-current
run_pr $'5\n1\n\ny\n'
assert_exit "模式 5 刪除當前分支: 退出碼 0" 0 $?
assert_contains "模式 5 刪除當前分支: 顯示切換詢問" "無法刪除當前所在的分支" "$OUT"
assert_eq "模式 5 刪除當前分支: 已切回主分支" "main" "$(git -C "$REPO" branch --show-current)"
TESTS_RUN=$((TESTS_RUN + 1))
if git -C "$REPO" show-ref --verify --quiet refs/heads/feat-current; then
    fail "模式 5 刪除當前分支: 分支已刪除" "feat-current 仍存在"
else
    pass "模式 5 刪除當前分支: 分支已刪除"
fi

# 一併刪除遠端分支（本地 bare origin 驗證）
setup_repo
git -C "$REPO" branch feat-remote
git -C "$REPO" push -q origin feat-remote
run_pr $'5\n1\ny\n\n'
assert_exit "模式 5 含遠端分支: 退出碼 0" 0 $?
assert_contains "模式 5 含遠端分支: 顯示遠端刪除詢問" "發現遠端分支" "$OUT"
TESTS_RUN=$((TESTS_RUN + 1))
if git -C "$ORIGIN" show-ref --verify --quiet refs/heads/feat-remote; then
    fail "模式 5 含遠端分支: 遠端分支已刪除" "origin/feat-remote 仍存在"
else
    pass "模式 5 含遠端分支: 遠端分支已刪除"
fi

# ==============================================
# E. 模式 2 / 3 / 4：PR 流程（假 gh 模擬）
# ==============================================

section "E. 模式 2 / 3 / 4：PR 流程"

# 模式 2：建立 PR（手動輸入標題與描述，gh pr create 由假 gh 回應）
setup_repo
git -C "$REPO" checkout -q -b jerry/feature/jira-123
printf 'feature\n' > "$REPO/feature.txt"
git -C "$REPO" add . >/dev/null && git -C "$REPO" commit -qm "feat: 新增功能檔案"
git -C "$REPO" push -q origin jerry/feature/jira-123
run_pr $'2\nJIRA-123\nn\n新增使用者登入功能\n\n'
assert_exit "模式 2 建立 PR: 退出碼 0" 0 $?
assert_contains "模式 2 建立 PR: 呼叫 gh pr create" "pr create --base main" "$FAKE_GH_LOG"
assert_contains "模式 2 建立 PR: 標題傳遞給 gh" "新增使用者登入功能" "$FAKE_GH_LOG"

# 模式 2：於主分支上建立 PR 應報錯
setup_repo
rc=0
run_pr $'2\n' || rc=$?
assert_nonzero_exit "模式 2 主分支: 非零退出" $rc
assert_contains "模式 2 主分支: 顯示錯誤訊息" "無法從主分支" "$OUT"

# 模式 3：當前分支沒有 PR（gh pr view --json 失敗）
setup_repo
git -C "$REPO" checkout -q -b jerry/feature/jira-123
run_pr $'3\nn\n'
assert_contains "模式 3 無 PR: 顯示找不到 PR" "沒有找到相關的 PR" "$OUT"

# 模式 3：主分支上撤銷 PR 應報錯
setup_repo
rc=0
run_pr $'3\n' || rc=$?
assert_nonzero_exit "模式 3 主分支: 非零退出" $rc
assert_contains "模式 3 主分支: 顯示錯誤訊息" "無法在主分支" "$OUT"

# 模式 3：已關閉的 PR（假 gh 回傳 CLOSED JSON，需 jq）
if command -v jq >/dev/null 2>&1; then
    setup_repo
    git -C "$REPO" checkout -q -b jerry/feature/jira-123
    (
        cd "$REPO" || exit 99
        printf '3\nn\n' | PATH="$FAKE_BIN:$PATH" \
            FAKE_GH_PR_VIEW_JSON='{"number":12,"state":"CLOSED","mergeable":"UNKNOWN","url":"https://github.com/tester/repo/pull/12","title":"測試 PR","mergedAt":null}' \
            run_with_timeout 60 bash "$SCRIPT"
    ) > "$OUT" 2>&1
    assert_contains "模式 3 CLOSED PR: 顯示已關閉" "已經被關閉" "$OUT"
    assert_contains "模式 3 CLOSED PR: 顯示 PR 標題" "測試 PR" "$OUT"
else
    printf '\033[1;33m  ⚠ 略過「模式 3 CLOSED PR」測試（未安裝 jq）\033[0m\n'
fi

# 模式 4：沒有待審查的 PR（假 gh pr list 回傳空）
setup_repo
rc=0
run_pr $'4\n' || rc=$?
assert_contains "模式 4 無待審 PR: 顯示提示" "目前沒有待審查的 Pull Request" "$OUT"
assert_contains "模式 4 無待審 PR: 呼叫 gh pr list" "pr list" "$FAKE_GH_LOG"

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
