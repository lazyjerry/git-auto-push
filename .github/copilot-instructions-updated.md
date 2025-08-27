````instructions
# Git Auto Push 專案指引

## 架構模式

### 核心工作流程
```bash
main() → check_git_repository() → add_all_files() → [選擇模式] → execute_*_workflow()
```

### AI 工具整合的雙函數模式
**必須同步修改兩處** (line 385 & 453):
```bash
generate_auto_commit_message_silent()  # 全自動模式
generate_auto_commit_message()         # 互動模式
```

### 信號處理層級
```bash
trap global_cleanup INT TERM     # 全局層級 (main)
trap loading_cleanup INT TERM    # Loading 動畫層級
trap cleanup_and_exit INT TERM   # 命令執行層級
```

## 關鍵實現模式

### AI 工具調用策略
- **Fallback 鏈**: codex → gemini → claude → 預設訊息
- **Command 模式**: `codex exec` vs `echo prompt | gemini/claude`
- **輸出清理**: `clean_ai_message()` 移除 AI 前綴、引號、空白
- **Timeout**: 45 秒統一超時

### 用戶輸入處理
```bash
# 輸入清理模式: $(echo "$input" | xargs)
# 重試循環模式: 'ai' 重新嘗試, 'q' 退出
# 確認模式: 空白=同意, y/yes/是/確認=同意
```

### Loading 動畫系統
```bash
show_loading() &              # 背景進程
loading_pid=$!
run_command_with_loading()    # 包裝器函數
kill $loading_pid 2>/dev/null # 清理
```

## 開發工作流程

### 新增 AI 工具
1. 在 `ai_tools` 陣列中添加 (兩處同步)
2. 在 `case` 語句中添加調用邏輯
3. 實現對應的 `run_*_command()` 函數
4. 更新輸出過濾規則

### 配置修改點
- `DEFAULT_OPTION=1` (line 674) - 預設操作模式
- AI 工具超時: `local timeout=45`
- 提示詞: 各 `run_*_command()` 函數中的 `prompt` 變數

### 測試模式
```bash
./test-ai-tools.sh    # 測試 AI 工具可用性
./check-ai-tools.sh   # 檢查工具狀態
```

## 專案特有慣例

### 彩色輸出函數
- `success_msg()` - 綠色成功訊息
- `warning_msg()` - 黃色警告訊息
- `info_msg()` - 藍色資訊訊息
- `handle_error()` - 紅色錯誤並退出

### 檔案組織
- `git-auto-push.sh` - 主腳本 (966 行)
- `extra_type/` - 替代實現
- `AUTO_MODE_GUIDE.md` - 全自動模式文檔
- `screenshots/` - UI 截圖

### 命令列模式
```bash
--auto/-a    # 啟用全自動模式
無參數       # 互動式選單
```

````
