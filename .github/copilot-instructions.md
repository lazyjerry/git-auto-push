# Git 自動化工具開發指引

這是一個 Git 工作流程自動化工具集，包含兩個核心 Bash 腳本和 AI 驅動的內容產生系統。

## 🏗️ 架構概覽

### 雙腳本架構
- **`git-auto-push.sh`** (1655 行) - 傳統 Git 操作自動化（add/commit/push）
- **`git-auto-pr.sh`** (2896 行) - GitHub Flow PR 流程自動化

### 核心設計模式
- **模組化函數設計**：所有主要功能都封裝為獨立函數（如 `error_msg()`, `run_command()`）
- **AI 工具容錯鏈**：支援多個 AI CLI 工具 (`codex` → `gemini` → `claude`) 的自動容錯機制
- **配置驅動**：所有可配置項集中在檔案頂部（AI 工具順序、分支設定等）

## ⚙️ 關鍵配置系統

### AI 工具配置 (兩檔案同步)
```bash
# 位置：檔案頂部配置區域
readonly AI_TOOLS=("codex" "gemini" "claude")  # 優先順序陣列
```

### 分支管理配置 (git-auto-pr.sh 獨有)
```bash
readonly -a DEFAULT_MAIN_BRANCHES=("uat" "main" "master")  # 自動偵測順序
readonly DEFAULT_USERNAME="jerry"                          # 預設使用者名稱  
readonly AUTO_DELETE_BRANCH_AFTER_MERGE=false              # PR 合併後分支處理策略
```

## 🔧 開發工作流程

### 修改 AI 行為
1. **提示詞調整**：修改檔案頂部的 `generate_ai_*_prompt()` 函數
2. **工具順序**：調整 `AI_TOOLS` 陣列元素順序
3. **容錯邏輯**：在對應的 `run_*_command()` 函數中添加錯誤處理

### 錯誤處理模式
- **自動偵測**：`401 Unauthorized`, `token_expired`, `stream error` 等特定錯誤
- **具體建議**：每種錯誤都提供對應的修復命令（如 `gh auth login`）
- **優雅降級**：AI 工具全部失效時自動切換至手動輸入模式

### 分支管理最佳實踐
- **主分支保護**：絕對禁止刪除 `DEFAULT_MAIN_BRANCHES` 中定義的分支
- **分支命名規則**：`{username}/{type}/{issue-key}` 格式，自動小寫轉換
- **安全確認機制**：多重確認防止誤刪未合併分支

## 🎯 核心函數架構

### 通用工具函數
- **訊息輸出**：`error_msg()`, `success_msg()`, `warning_msg()` - 彩色格式化輸出
- **指令執行**：`run_command()` - 統一的指令執行介面
- **Loading 動畫**：`show_loading()` - 長時間操作的使用者體驗

### AI 整合函數
- **AI 指令執行**：`run_codex_command()`, `run_stdin_ai_command()` - 各種 AI 工具的統一介面
- **輸出清理**：`clean_ai_message()` - 過濾 AI 工具的技術雜訊
- **容錯機制**：45 秒超時，自動切換至下一個 AI 工具

### Git 操作函數
- **狀態檢查**：`check_git_repository()`, `get_git_status()` - Git 倉庫驗證
- **檔案處理**：`add_all_files()` - Git add 操作封裝
- **分支管理**：主分支自動偵測和分支安全刪除邏輯

## 🚨 開發注意事項

### 同步修改要求
修改 AI 相關功能時，必須同時更新兩個檔案：
- `git-auto-push.sh` - AI commit 訊息產生
- `git-auto-pr.sh` - AI PR 內容和分支名稱產生

### 安全考量
- **權限檢查**：腳本不需要 root 權限，但會執行 Git 和網路操作
- **資料保護**：所有使用者輸入都會經過清理和驗證
- **中斷處理**：支援 Ctrl+C 優雅退出，自動清理暫存資源

### 測試策略
```bash
# 語法檢查
bash -n git-auto-push.sh && bash -n git-auto-pr.sh

# 基本功能測試
./git-auto-push.sh --help
./git-auto-pr.sh --help

# AI 工具連線測試
for tool in codex gemini claude; do command -v "$tool" && echo "$tool 可用"; done
```

## 🔄 版本管理慣例

### 行數統計維護
README.md 中包含精確的行數統計，修改後需同步更新：
- `git-auto-push.sh`: 當前 1655 行
- `git-auto-pr.sh`: 當前 2896 行

### Commit 訊息規範
遵循 [Conventional Commits](https://www.conventionalcommits.org/) 格式，工具本身也會產生符合此規範的 commit 訊息。

### 功能標註
新功能使用 🆕 標註，改進使用 🔧 標註，保持 README.md 的一致性。

---

開發時優先參考現有函數的實作模式，保持程式碼風格一致性，並確保所有修改都經過基本的功能測試。