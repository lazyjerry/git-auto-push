# Git Auto Push 專案指引

## 架構概述

這是一個多語言的 Git 自動化工具專案，主要組件：

- **主腳本**: `git-auto-push.sh` - 核心 Bash 實現，支援多 AI 工具整合
- **Python 版本**: `extra_type/git-auto-push.py` - 替代實現（開發中）
- **文檔系統**: 多層次使用指南和故障排除文檔

## 核心功能流程

### 四種操作模式

1. **完整流程** (預設): add → commit → push，含互動式確認
2. **本地提交**: add → commit，適合離線開發
3. **僅添加**: add 變更到暫存區
4. **全自動模式**: add → AI commit → push，零互動

### AI 工具整合架構

```bash
# 優先級順序硬編碼在兩處：
generate_auto_commit_message()        # 互動模式 (line ~453)
generate_auto_commit_message_silent() # 全自動模式 (line ~385)
```

## 關鍵實現細節

### AI 工具調用模式

- **Codex**: `codex exec '$prompt'` - 直接執行命令
- **Gemini**: 多種命令嘗試 (`gemini`, `gcloud ai`, `google-generativeai`)
- **Claude**: 多種命令嘗試 (`claude`, `anthropic`, `claude-cli`)
- **輸出過濾**: 使用 `grep -v -E` 移除系統輸出，只保留實際內容

### 並發安全與用戶體驗

```bash
# Loading 動畫系統
show_loading() {  # 背景程序顯示動畫
run_command_with_loading()  # 執行命令時顯示進度
```

### 配置系統

- `DEFAULT_OPTION` - 控制預設操作模式
- 兩處 `ai_tools` 陣列必須同步修改

## 開發模式

### 功能擴展

- **新增 AI 工具**: 在兩個 `generate_auto_commit_message*` 函數中添加
- **新增操作模式**: 修改 `show_operation_menu()` 和主要條件判斷
- **自訂提示**: 修改 AI prompt 內容在各個 `run_*_command()` 函數中

### 測試策略

- 使用 `test-ai-tools.sh` 和 `check-ai-tools.sh` 驗證 AI 工具可用性
- 每個 AI 工具有獨立的 timeout 機制 (30-45 秒)

### 用戶體驗設計

- **彩色輸出**: `success_msg()`, `warning_msg()`, `info_msg()`, `handle_error()`
- **輸入緩衝**: 在確認前清空 stdin 避免意外輸入
- **多語言支援**: 確認訊息支援中英文 (`y/yes/是/確認`)

## 檔案結構規範

- **主目錄**: 核心腳本和主文檔
- **extra_type/**: 替代實現（Python 等）
- **screenshots/**: UI 展示圖片
- **AUTO_MODE_GUIDE.md**: 全自動模式專用文檔
- **AI_TOOLS_FIX_GUIDE.md**: AI 工具故障排除

## 命令列參數

```bash
./git-auto-push.sh --auto  # 全自動模式
./git-auto-push.sh -a      # 全自動模式簡寫
```

## 故障處理

- AI 工具失敗時提供重試機制 (`輸入 'ai' 重新嘗試`)
- 網路超時有明確的 timeout 控制
- 所有 Git 操作都有錯誤處理和回滾機制
