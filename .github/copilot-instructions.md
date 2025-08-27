# Git Auto-Push 專案 AI 指導說明

## 🏗️ 專案架構總覽

這是一個 **單腳本 Bash 工具**（966 行），提供 Git 工作流程自動化，主要特色是多 AI 工具鏈整合和四種操作模式。

### 核心組件結構

```
git-auto-push.sh          # 主腳本 - 所有功能都在此文件
├── AI 工具整合 (4 tools) # run_*_command() 函數群
├── Loading 動畫系統      # show_loading() + 背景進程
├── 信號處理機制         # 多層級 trap cleanup
└── 四種操作模式         # execute_*_workflow() 函數
```

## 🤖 AI 工具鏈架構（關鍵理解）

**硬編碼的優先級順序** 存在於兩個關鍵函數中：

- `generate_auto_commit_message()` (互動模式，line ~444)
- `generate_auto_commit_message_silent()` (自動模式，line ~377)

```bash
# 調用順序：codex → gemini → claude → fallback
local ai_tools=("codex" "gemini" "claude")

# 不同的調用模式
codex exec '$prompt'           # 直接執行
echo '$prompt' | gemini        # stdin 管道
echo '$prompt' | claude        # stdin 管道
```

**重要**：修改 AI 工具優先級時，必須同步更新這兩個函數！

## ⚙️ 關鍵配置點

- `DEFAULT_OPTION=1` (line 674) - 預設操作模式
- 45 秒統一超時機制用於所有 AI 工具
- `clean_ai_message()` 函數處理 AI 輸出格式清理

## 🎯 四種操作模式詳解

| 模式        | 函數                      | 流程                   | 用途     |
| ----------- | ------------------------- | ---------------------- | -------- |
| 1. 完整流程 | `execute_full_workflow()` | add → commit → push    | 日常開發 |
| 2. 本地提交 | 選項 2                    | add → commit           | 離線開發 |
| 3. 僅添加   | 選項 3                    | add                    | 暫存檔案 |
| 4. 全自動   | `execute_auto_workflow()` | add → AI commit → push | CI/CD    |

## 🎬 Loading 動畫系統

`show_loading()` 函數啟動背景進程來顯示 AI 工具調用時的動畫效果：

- 使用 `&` 創建背景進程
- 通過 PID 管理和清理
- 多層級 trap 機制確保穩定性

## 🔧 開發工作流程

### 新增 AI 工具

1. 在兩個 `generate_*_commit_message*()` 函數中添加工具
2. 創建對應的 `run_*_command()` 函數
3. 更新 AI 工具陣列順序

### 修改操作模式

1. 更新 `show_operation_menu()` 顯示
2. 在主選擇邏輯中添加 case 分支
3. 實現對應的 `execute_*_workflow()` 函數

### 調試要點

- 使用 `info_msg()`, `warning_msg()`, `success_msg()` 進行彩色輸出
- 信號處理：每個長時間運行的函數都有對應的 trap cleanup
- 輸入緩衝區清理：`read -t 0.1 -n 1000` 模式

## 📁 專案文件說明

- `AUTO_MODE_GUIDE.md` - 全自動模式專用文檔
- `screenshots/` - UI 展示圖片，用於 README
- `Tools/` - 空目錄（未來擴展用）
- `LICENSE` - MIT 授權

## 🚀 命令列接口

```bash
./git-auto-push.sh           # 互動模式
./git-auto-push.sh --auto    # 全自動模式（長參數）
./git-auto-push.sh -a        # 全自動模式（短參數）
```

## ⚠️ 常見陷阱

1. **AI 工具同步**：記住同時更新兩個 `generate_*_commit_message*()` 函數
2. **信號處理**：新增長時間運行的函數時，務必實現對應的 trap cleanup
3. **輸出格式**：使用專案定義的 `*_msg()` 函數而非直接 echo
4. **路徑處理**：腳本假設在 Git 倉庫根目錄運行

這個專案的精髓在於將複雜的 Git 工作流程包裝成簡單的用戶介面，同時提供強大的 AI 整合和穩定的錯誤處理機制。
