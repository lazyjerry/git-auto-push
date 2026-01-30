# 程式碼重複分析報告

> 分析日期：2026-01-30  
> 分析檔案：`git-auto-push.sh` (3031 行)

## 📋 重複程式碼總覽

| 編號 | 重複類型 | 重複次數 | 影響行數 | 優先級 |
|------|----------|----------|----------|--------|
| 1 | AI 訊息確認流程 | 3 次 | ~60 行 | 高 |
| 2 | AI 工具迴圈邏輯 | 3 次 | ~90 行 | 高 |
| 3 | 函數相似度過高 | 2 個函數 | ~140 行 | 中 |

---

## 1. AI 訊息確認流程（重複 3 次）

### 位置
- `get_commit_message()` 函數內，第 1450-1472 行（AUTO 模式確認）
- `get_commit_message()` 函數內，第 1513-1535 行（空輸入觸發 AI）
- `get_commit_message()` 函數內，第 1551-1573 行（手動輸入 'ai' 重新生成）

### 重複內容
```bash
cyan_msg "🤖 AI 生成的 commit message:"
highlight_success_msg "🔖 $auto_message"
echo >&2
cyan_msg "💡 下一步動作："
if [[ "$AUTO_CHECK_COMMIT_QUALITY" == "true" ]]; then
    white_msg "  • 按 Enter 或輸入 y - 使用此訊息並進行品質檢查"
else
    white_msg "  • 按 Enter 或輸入 y - 使用此訊息（稍後詢問是否檢查品質）"
fi
white_msg "  • 輸入 n - 拒絕並手動輸入"
echo >&2
printf "是否使用此訊息？[Y/n]: " >&2
read -r confirm
confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)

if [ -z "$confirm" ] || [[ "$confirm" =~ ^(y|yes|是|確認)$ ]]; then
    local final_message
    final_message=$(append_ticket_number_to_message "$auto_message")
    echo "$final_message"
    return 0
fi
```

### 建議重構
抽取為 `confirm_ai_message()` 函數：

```bash
# 函式：confirm_ai_message
# 功能說明：顯示 AI 生成的訊息並詢問使用者確認
# 輸入參數：
#   $1 <message> AI 生成的 commit 訊息
#   $2 <label> 顯示標籤（可選，預設為 "🤖 AI 生成的"）
# 輸出結果：
#   STDOUT 輸出確認後的訊息（含任務編號）
#   返回 0=確認使用，1=拒絕
confirm_ai_message() {
    local message="$1"
    local label="${2:-🤖 AI 生成的}"
    
    echo >&2
    cyan_msg "$label commit message:"
    highlight_success_msg "🔖 $message"
    echo >&2
    cyan_msg "💡 下一步動作："
    if [[ "$AUTO_CHECK_COMMIT_QUALITY" == "true" ]]; then
        white_msg "  • 按 Enter 或輸入 y - 使用此訊息並進行品質檢查"
    else
        white_msg "  • 按 Enter 或輸入 y - 使用此訊息（稍後詢問是否檢查品質）"
    fi
    white_msg "  • 輸入 n - 拒絕並手動輸入"
    echo >&2
    printf "是否使用此訊息？[Y/n]: " >&2
    read -r confirm
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)
    
    if [ -z "$confirm" ] || [[ "$confirm" =~ ^(y|yes|是|確認)$ ]]; then
        local final_message
        final_message=$(append_ticket_number_to_message "$message")
        echo "$final_message"
        return 0
    fi
    
    return 1
}
```

**調用方式**：
```bash
if final_message=$(confirm_ai_message "$auto_message"); then
    echo "$final_message"
    return 0
fi
```

---

## 2. AI 工具迴圈邏輯（重複 3 次）

### 位置
- `generate_commit_prefix_by_ai()` 函數，第 600-626 行
- `generate_auto_commit_message_silent()` 函數，第 1220-1246 行
- `generate_auto_commit_message()` 函數，第 1295-1340 行

### 重複內容
```bash
for tool_name in "${AI_TOOLS[@]}"; do
    if ! command -v "$tool_name" >/dev/null 2>&1; then
        # 工具未安裝訊息...
        continue
    fi

    # 工具狀態訊息（各函數略有不同）...
    ai_tool_used="$tool_name"
    
    case "$tool_name" in
        "codex")
            if generated_xxx=$(run_codex_command "$prompt"); then
                break
            fi
            ;;
        "gemini"|"claude")
            if generated_xxx=$(run_stdin_ai_command "$tool_name" "$prompt"); then
                break
            fi
            ;;
    esac
    
    # 失敗訊息...
    generated_xxx=""
    ai_tool_used=""
done
```

### 建議重構
抽取為 `run_ai_with_fallback()` 函數：

```bash
# 函式：run_ai_with_fallback
# 功能說明：依序嘗試多個 AI 工具執行任務，支援容錯機制
# 輸入參數：
#   $1 <prompt> 提示詞內容
#   $2 <show_hints> 是否顯示工具提示（true/false）
# 輸出結果：
#   STDOUT 輸出 AI 回應內容
#   全域變數 LAST_AI_TOOL 記錄成功使用的工具名稱
# 返回值：
#   0=成功，1=所有工具都失敗
LAST_AI_TOOL=""

run_ai_with_fallback() {
    local prompt="$1"
    local show_hints="${2:-false}"
    
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
```

**調用方式**：
```bash
if result=$(run_ai_with_fallback "$prompt" "true"); then
    info_msg "使用 $LAST_AI_TOOL 成功"
    # 處理 result...
fi
```

---

## 3. 函數相似度過高

### 相似函數
- `generate_auto_commit_message()` (第 1287-1379 行)
- `generate_auto_commit_message_silent()` (第 1212-1285 行)

### 相似度分析
| 功能 | generate_auto_commit_message | generate_auto_commit_message_silent |
|------|------------------------------|-------------------------------------|
| AI 工具迴圈 | ✅ 相同 | ✅ 相同 |
| 訊息清理 | ✅ 相同 | ✅ 相同 |
| 前綴生成 | ✅ 相同 | ✅ 相同 |
| 工具提示 | ✅ 顯示詳細提示 | ❌ 不顯示 |
| 失敗處理 | 返回錯誤 | 使用預設訊息 |

**相似度：~85%**

### 建議重構
合併為單一函數，用參數控制行為：

```bash
# 函式：generate_auto_commit_message
# 功能說明：使用 AI 工具自動生成 commit message
# 輸入參數：
#   $1 <silent_mode> 是否為靜默模式（true=不顯示提示，失敗用預設訊息）
# 輸出結果：
#   STDOUT 輸出生成的 commit 訊息
# 返回值：
#   0=成功，1=失敗（非靜默模式）
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
            local ai_prefix=""
            if ai_prefix=$(generate_commit_prefix_by_ai); then
                if [ -n "$ai_prefix" ]; then
                    generated_message="$ai_prefix: $generated_message"
                fi
            fi
            
            info_msg "✅ 使用 $LAST_AI_TOOL 生成的 commit message:"
            highlight_success_msg "🔖 $generated_message"
            echo "$generated_message"
            return 0
        fi
    fi
    
    # 失敗處理
    if [ "$silent_mode" = "true" ]; then
        warning_msg "⚠️  所有 AI 工具都執行失敗，使用預設 commit message"
        local default_message="自動提交：更新專案檔案"
        local final_message
        final_message=$(append_ticket_number_to_message "$default_message")
        echo "$final_message"
        return 0
    else
        warning_msg "所有 AI 工具都執行失敗或未生成有效的 commit message"
        return 1
    fi
}
```

**調用方式**：
```bash
# 互動模式
generate_auto_commit_message

# 全自動模式（原 _silent 版本）
generate_auto_commit_message "true"
```

---

## 📊 重構效益評估

| 指標 | 重構前 | 重構後 | 減少 |
|------|--------|--------|------|
| 重複程式碼行數 | ~290 行 | ~50 行 | **83%** |
| 維護點 | 8 處 | 3 處 | **63%** |
| 修改風險 | 高（易漏改） | 低 | - |

---

## ⚠️ 重構注意事項

1. **測試覆蓋**：重構前確保所有情境都有測試
2. **漸進式重構**：建議分階段進行，每次只重構一個區塊
3. **向後相容**：保持函數簽名不變，或提供過渡期別名
4. **全域變數**：`LAST_AI_TOOL` 使用全域變數需注意並發問題

---

## 📝 執行計畫

### 第一階段：提取 confirm_ai_message() ✅ 已完成
- [x] 建立 `confirm_ai_message()` 函數
- [x] 替換 `get_commit_message()` 中的三處重複
- [x] 測試 AUTO 模式、空輸入、手動 'ai' 三種情境

**重構成果**：
- 減少重複程式碼：~60 行 → 5 行（每處調用）
- 新函數位置：第 1407-1437 行
- 三處調用確認：
  - AUTO 模式（L1464）：`confirm_ai_message "$auto_message"`
  - 空輸入（L1509）：`confirm_ai_message "$auto_message"`
  - 手動 'ai'（L1528）：`confirm_ai_message "$auto_message" "🔄 AI 重新生成的"`

### 第二階段：提取 run_ai_with_fallback() ✅ 已完成
- [x] 建立 `run_ai_with_fallback()` 函數
- [x] 新增全域變數 `LAST_AI_TOOL` 記錄成功工具
- [x] 替換 `generate_commit_prefix_by_ai()` 中的迴圈
- [x] 替換 `generate_auto_commit_message_silent()` 中的迴圈
- [x] 替換 `generate_auto_commit_message()` 中的迴圈
- [x] 語法檢查通過

**重構成果**：
- 新函數位置：第 563-624 行
- 減少重複程式碼：~90 行 → 15 行（3 處調用）
- 檔案行數：3020 行 → 2988 行（減少 32 行）

### 第三階段：合併 commit message 生成函數 ✅ 已完成
- [x] 合併 `generate_auto_commit_message` 和 `generate_auto_commit_message_silent`
- [x] 更新所有調用點
- [x] 語法檢查通過

**重構成果**：
- 合併為單一函數：`generate_auto_commit_message(silent_mode)`
- 參數說明：`silent_mode=true` 為全自動模式（原 _silent 版本）
- 調用點更新：
  - 互動模式（L1472, L1517, L1536）：`generate_auto_commit_message`
  - 全自動模式（L2956）：`generate_auto_commit_message "true"`
- 檔案行數：2988 行 → 2997 行（+9 行，因新增函數文檔）

---

## 📊 最終重構效益

| 階段 | 重構內容 | 減少行數 |
|------|----------|----------|
| 第一階段 | `confirm_ai_message()` | -11 行 |
| 第二階段 | `run_ai_with_fallback()` | -32 行 |
| 第三階段 | 合併 commit message 函數 | +9 行（含文檔） |
| **總計** | | **-34 行** |

**最終行數**：3031 行 → 2997 行

---

*報告結束*
