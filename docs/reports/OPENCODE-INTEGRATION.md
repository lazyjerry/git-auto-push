# Plan: 新增 opencode AI 工具支援

## Context

目前 `AI_TOOLS` 陣列支援 copilot / gemini / codex / claude，採容錯鏈設計。使用者要求新增 `opencode` 支援。

### --format json 決策

實測確認輸出格式如下（nd-JSON 串流）：
```json
{"type":"step_start","part":{...}}
{"type":"text","part":{"text":"實際回應內容",...}}
{"type":"step_finish","part":{...}}
```

**使用 `--format json`**，直接從 `type=="text"` 事件的 `part.text` 提取文字，比預設格式更可靠，且不需要 `clean_ai_message()` 清理。

**jq 偵測策略**：執行前檢查 `jq` 是否可用，優先使用 jq 解析（準確處理 Unicode 與跳脫字元），若未安裝則 fallback 至 grep/sed：
```bash
# 優先：jq（精確）
jq -r 'select(.type == "text") | .part.text' 2>/dev/null | tr -d '\n'
# Fallback：grep/sed（不依賴 jq）
grep '"type":"text"' | grep -o '"text":"[^"]*"' | sed 's/^"text":"//;s/"$//' | tr -d '\n'
```

### opencode run 呼叫方式

opencode 不接受 stdin piping，提示詞以命令列引數傳入，`--file` 作為附件：

```bash
printf '%s\n\n%s' "$prompt" "$content" > "$temp_file"
opencode run --format json 'Follow the instructions in the attached file.' --file "$temp_file"
```

## 修改範圍

兩個腳本必須**同步修改**（CLAUDE.md 明確要求）。

### 腳本檔案

| 檔案 | 修改位置 | 說明 |
|------|----------|------|
| `git-auto-push.sh` | ~第 112 行 `AI_TOOLS` 陣列 | 新增 `"opencode"` |
| `git-auto-push.sh` | ~第 394 行 `show_hints` case | 新增 opencode 提示訊息 |
| `git-auto-push.sh` | ~第 412 行 `run_ai_with_fallback()` case | 新增 `"opencode"` dispatch 分支 |
| `git-auto-push.sh` | `run_codex_command()` 之後 | 新增 `run_opencode_command()` 函數 |
| `git-auto-pr.sh` | ~第 147 行 `AI_TOOLS` 陣列 | 新增 `"opencode"` |
| `git-auto-pr.sh` | `run_codex_command()` 之後 | 新增 `run_opencode_command()` 函數（含 content 參數） |
| `git-auto-pr.sh` | ~第 1079 行 `generate_branch_name_with_ai()` for loop | 新增 `"opencode"` case |
| `git-auto-pr.sh` | ~第 1199 行 `generate_pr_content_with_ai()` for loop | 新增 `"opencode"` case |

### 文件與設定檔

| 檔案 | 修改位置 | 說明 |
|------|----------|------|
| `.git-auto-push-config/.env.example` | 第 24-26 行 | 更新可用工具列表與範例 |
| `INSTALLATION.md` | ~第 130 行（push 設定）、~第 146 行（pr 設定）、~第 277 行（驗證迴圈） | 新增 opencode 安裝小節與工具清單 |
| `README.md` | ~第 37 行、~第 206 行、~第 403 行 | 更新工具名稱列表 |
| `README_EN.md` | 對應英文版相同位置 | 同步更新英文說明 |

## 實作細節

### 1. AI_TOOLS 陣列（兩個腳本）

opencode 放第一位，作為最高優先順序：

```bash
AI_TOOLS=(
    "opencode"    # 新增，最高優先
    "copilot"
    "gemini"
    "codex"
    "claude"
)
```

### 2. show_hints case（git-auto-push.sh）

在 `"codex"` case 之後：
```bash
"opencode")
    info_msg "💡 提醒: opencode 需要登入，請執行 opencode auth login"
    ;;
```

### 3. run_ai_with_fallback dispatch（git-auto-push.sh）

在 `"gemini"|"claude"` case 之後：
```bash
"opencode")
    if result=$(run_opencode_command "$prompt"); then
        LAST_AI_TOOL="$tool_name"
        echo "$result"
        return 0
    fi
    ;;
```

### 4. run_opencode_command()（git-auto-push.sh）

放在 `run_codex_command()` 函數之後，使用 `--format json` 並解析 nd-JSON 事件：

```bash
# ============================================
# run_opencode_command
# 功能：調用 opencode CLI 生成 commit 訊息
# 參數：$1 - prompt 提示詞
# 返回：0=成功並輸出結果，1=失敗
# 使用：result=$(run_opencode_command "$prompt")
# 注意：使用 --format json 解析 part.text 欄位，避免 clean_ai_message 清理依賴
# ============================================
run_opencode_command() {
    local prompt="$1"
    local timeout=60

    info_msg "正在調用 opencode..."

    if ! command -v opencode >/dev/null 2>&1; then
        warning_msg "opencode 工具未安裝"
        return 1
    fi

    # 檢查 jq 是否可用（建議安裝，可獲得更精確的 JSON 解析）
    if ! command -v jq >/dev/null 2>&1; then
        warning_msg "⚠️  建議安裝 jq 以獲得更精確的 opencode 輸出解析（brew install jq）"
    fi

    local diff_size
    diff_size=$(git diff --cached 2>/dev/null | wc -l)
    if [ "$diff_size" -gt 500 ]; then
        timeout=90
        info_msg "檢測到大型變更（$diff_size 行），增加處理時間到 ${timeout} 秒..."
    fi

    local git_diff
    git_diff=$(git diff --cached 2>/dev/null || git diff 2>/dev/null)
    if [ -z "$git_diff" ]; then
        warning_msg "沒有檢測到任何變更內容"
        return 1
    fi

    local temp_input
    temp_input=$(mktemp)
    printf '%s\n\nGit 變更內容:\n%s' "$prompt" "$git_diff" > "$temp_input"

    debug_msg "🔍 調試: run_opencode_command() 輸入統計: $(wc -l < "$temp_input") 行"

    local output exit_code
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "timeout ${timeout}s opencode run --format json 'Follow the instructions in the attached file.' --file '$temp_input' 2>&1" "正在等待 opencode 分析變更" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "opencode run --format json 'Follow the instructions in the attached file.' --file '$temp_input' 2>&1" "正在等待 opencode 分析變更" "$timeout")
        exit_code=$?
    fi

    rm -f "$temp_input"

    case $exit_code in
        0)
            # 從 nd-JSON 事件中提取 type=="text" 的 part.text 欄位
            # 優先使用 jq（精確），fallback 至 grep/sed
            local text_output
            if command -v jq >/dev/null 2>&1; then
                text_output=$(echo "$output" | jq -r 'select(.type == "text") | .part.text' 2>/dev/null | tr -d '\n')
            else
                text_output=$(echo "$output" | grep '"type":"text"' | grep -o '"text":"[^"]*"' | sed 's/^"text":"//;s/"$//' | tr -d '\n')
            fi
            debug_msg "🔍 調試: opencode 提取文字: '$text_output'"
            if [ -n "$text_output" ] && [ ${#text_output} -gt 3 ]; then
                success_msg "opencode 回應完成"
                echo "$text_output"
                return 0
            fi
            warning_msg "opencode 沒有返回有效內容"
            debug_msg "🔍 調試: opencode 原始輸出: $(echo "$output" | head -c 300)"
            ;;
        124)
            error_msg "❌ opencode 執行超時（${timeout}秒）"
            warning_msg "💡 建議：檢查網路連接或稍後重試"
            ;;
        *)
            warning_msg "opencode 執行失敗（退出碼: $exit_code）"
            debug_msg "🔍 調試: opencode 輸出: $output"
            ;;
    esac

    return 1
}
```

### 5. run_opencode_command()（git-auto-pr.sh）

簽名與 `run_codex_command` 一致（含 content 參數），放在 `run_codex_command()` 之後：

```bash
# ============================================
# run_opencode_command
# 功能：調用 opencode CLI 生成分支名稱或 PR 內容
# 參數：$1 - prompt，$2 - content，$3 - timeout（預設 60）
# 返回：0=成功並輸出結果，1=失敗
# 注意：使用 --format json 解析 part.text 欄位
# ============================================
run_opencode_command() {
    local prompt="$1"
    local content="$2"
    local timeout="${3:-60}"

    info_msg "正在調用 opencode..."

    if ! command -v opencode >/dev/null 2>&1; then
        warning_msg "opencode 工具未安裝"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        warning_msg "⚠️  建議安裝 jq 以獲得更精確的 opencode 輸出解析（brew install jq）"
    fi

    if [ -z "$content" ]; then
        warning_msg "沒有內容可供 opencode 分析"
        return 1
    fi

    local temp_input
    temp_input=$(mktemp)
    printf '%s\n\n%s' "$prompt" "$content" > "$temp_input"

    debug_msg "🔍 調試: run_opencode_command() 輸入統計: $(wc -l < "$temp_input") 行"

    local output exit_code
    if command -v timeout >/dev/null 2>&1; then
        output=$(run_command_with_loading "timeout ${timeout}s opencode run --format json 'Follow the instructions in the attached file.' --file '$temp_input' 2>&1" "正在等待 opencode 回應" "$timeout")
        exit_code=$?
    else
        output=$(run_command_with_loading "opencode run --format json 'Follow the instructions in the attached file.' --file '$temp_input' 2>&1" "正在等待 opencode 回應" "$timeout")
        exit_code=$?
    fi

    rm -f "$temp_input"

    case $exit_code in
        0)
            local text_output
            if command -v jq >/dev/null 2>&1; then
                text_output=$(echo "$output" | jq -r 'select(.type == "text") | .part.text' 2>/dev/null | tr -d '\n')
            else
                text_output=$(echo "$output" | grep '"type":"text"' | grep -o '"text":"[^"]*"' | sed 's/^"text":"//;s/"$//' | tr -d '\n')
            fi
            debug_msg "🔍 調試: opencode 提取文字: '$text_output'"
            if [ -n "$text_output" ] && [ ${#text_output} -gt 3 ]; then
                success_msg "opencode 回應完成"
                echo "$text_output"
                return 0
            fi
            warning_msg "opencode 沒有返回有效內容"
            debug_msg "🔍 調試: opencode 原始輸出: $(echo "$output" | head -c 300)"
            ;;
        124)
            error_msg "❌ opencode 執行超時（${timeout}秒）"
            warning_msg "💡 建議：檢查網路連接或稍後重試"
            ;;
        *)
            warning_msg "opencode 執行失敗（退出碼: $exit_code）"
            debug_msg "🔍 調試: opencode 輸出: $output"
            ;;
    esac

    return 1
}
```

### 6. generate_branch_name_with_ai() for loop（git-auto-pr.sh）

在 `"gemini"|"claude"` case 之後新增：
```bash
"opencode")
    if result=$(run_opencode_command "$prompt" "$content" 30); then
        debug_msg "🔍 調試: opencode 原始輸出 result='$result'"
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
        warning_msg "⚠️  run_opencode_command 執行失敗或返回空結果"
    fi
    ;;
```

### 7. generate_pr_content_with_ai() for loop（git-auto-pr.sh）

在 `"gemini"|"claude"` case 之後新增：
```bash
"opencode")
    if ! command -v opencode >/dev/null 2>&1; then
        warning_msg "opencode 工具未安裝"
        continue
    fi
    local content_text
    content_text=$(cat "$temp_content")
    if result=$(run_opencode_command "$prompt" "$content_text" "$timeout"); then
        debug_msg "🔍 調試: opencode PR 內容原始輸出 result='$result'"
        success_msg "✅ $tool 生成 PR 內容成功"
        rm -f "$temp_content"
        echo "$result"
        return 0
    else
        warning_msg "$tool 無法生成 PR 內容"
    fi
    ;;
```

### 8. .env.example 更新

```bash
# 可用工具：copilot, gemini, codex, claude, opencode
# 範例：AI_TOOLS=("copilot" "gemini" "codex" "claude" "opencode")
# AI_TOOLS=("copilot" "gemini" "codex" "claude" "opencode")
```

### 9. INSTALLATION.md 更新

- AI_TOOLS 代碼區塊新增 `"opencode"` 條目（push 設定 ~第 130 行、pr 設定 ~第 146 行）
- 新增 opencode 安裝小節（位於 Anthropic Claude CLI 之後）：
  ```markdown
  ##### OpenCode CLI

  ```bash
  # 安裝方式請參考官方文件
  # https://opencode.ai/docs/zh-tw/

  # 建議同時安裝 jq 以啟用精確 JSON 解析
  brew install jq      # macOS
  # apt install jq     # Ubuntu/Debian
  ```
  ```
- 在「注意事項」區塊新增：`- opencode 工具建議同時安裝 jq 以精確解析輸出；未安裝時會自動 fallback 至內建文字解析`
- 驗證迴圈更新（~第 277 行）：`for tool in copilot codex gemini claude opencode; do`

### 10. README.md / README_EN.md 更新

- 架構清單（~第 37 行）：`copilot / gemini / codex / claude / opencode`
- 工具介紹段落（~第 206 行）：加入 opencode 說明
- 預設順序說明（~第 403 行）：`copilot → gemini → codex → claude → opencode`

## 實作順序

1. 複製本計畫文件到 `docs/reports/OPENCODE-INTEGRATION.md`（存檔備查）
2. 修改 `git-auto-push.sh`
3. 修改 `git-auto-pr.sh`
4. 更新 `.git-auto-push-config/.env.example`
5. 更新 `INSTALLATION.md`
6. 更新 `README.md` 與 `README_EN.md`

## 驗證

```bash
# 1. 語法檢查
bash -n git-auto-push.sh && echo "✅ push 語法正確"
bash -n git-auto-pr.sh && echo "✅ pr 語法正確"

# 2. 確認 AI_TOOLS 陣列包含 opencode
grep -A 8 'AI_TOOLS=(' git-auto-push.sh git-auto-pr.sh

# 3. 功能測試（需要有 staged 變更）
IS_DEBUG=true ./git-auto-push.sh 4
```
