# Git Auto-Push 工具

Git 工作流程自動化工具，提供 AI 驅動的 commit message 生成和多種操作模式，簡化日常 Git 操作流程。主要功能包括自動檔案添加、智慧 commit message 生成（支援 codex、gemini、claude）、互動式操作選單和完整的錯誤處理機制。

## 系統結構

### 核心組件
```
git-auto-push.sh          # 主腳本（1024 行）
├── AI 工具整合模組        # 支援 codex、gemini、claude
├── 互動式選單系統        # 5 種操作模式
├── Loading 動畫系統      # 背景進程管理
├── 信號處理機制          # 多層級 trap cleanup
└── 錯誤處理系統          # 完整的異常處理
```

### 目錄結構
```
├── git-auto-push.sh      # 主執行檔
├── LICENSE              # MIT 授權條款
└── screenshots/         # 介面展示圖片
    ├── ai-commit-generation.png
    ├── auto-mode.png
    └── main-menu.png
```

## 安裝與啟動

### 1. 複製專案
```bash
git clone https://github.com/lazyjerry/git-auto-push.git
cd git-auto-push
```

### 2. 設置執行權限
```bash
chmod +x git-auto-push.sh
```

### 3. 全域安裝（選擇性）
```bash
sudo cp git-auto-push.sh /usr/local/bin/git-auto-push
sudo chmod +x /usr/local/bin/git-auto-push
```

### 4. AI 工具安裝
安裝任一或多個 AI CLI 工具（依使用需求）：
- `codex` - GitHub Copilot CLI
- `gemini` - Google Gemini CLI
- `claude` - Anthropic Claude CLI

## 使用方法

### 基本執行指令
```bash
# 互動式模式（預設）
./git-auto-push.sh

# 全自動模式
./git-auto-push.sh --auto
./git-auto-push.sh -a

# 全域安裝後使用
git-auto-push
git-auto-push --auto
```

### 操作模式說明

| 模式 | 功能描述 | 使用情境 |
|------|----------|----------|
| 1. 完整流程 | add → 互動輸入 commit → push | 日常開發提交 |
| 2. 本地提交 | add → 互動輸入 commit | 離線開發或測試提交 |
| 3. 僅添加檔案 | add | 暫存檔案變更 |
| 4. 全自動模式 | add → AI 生成 commit → push | CI/CD 或快速提交 |
| 5. 僅提交 | commit | 提交已暫存的檔案 |

## 使用情境

### 日常開發流程
```bash
# 修改程式碼後，執行完整流程
./git-auto-push.sh
# 選擇選項 1，輸入 commit message，自動推送
```

### 快速自動提交
```bash
# AI 自動生成 commit message 並推送
./git-auto-push.sh --auto
```

### 離線開發
```bash
# 只提交到本地，不推送
./git-auto-push.sh
# 選擇選項 2
```

### 分階段操作
```bash
# 先添加檔案
./git-auto-push.sh  # 選擇選項 3

# 稍後提交
./git-auto-push.sh  # 選擇選項 5
```

## 錯誤排除

### 常見問題及解決方案

**錯誤：`當前目錄不是 Git 倉庫！`**
```bash
# 確認在 Git 倉庫根目錄執行
git init  # 或移動到正確的 Git 倉庫目錄
```

**錯誤：`沒有需要提交的變更`**
- 檢查是否有檔案變更：`git status`
- 或選擇推送現有提交到遠端

**AI 工具無法使用**
```bash
# 檢查 AI CLI 工具是否已安裝並可執行
which codex
which gemini  
which claude
```

**權限不足錯誤**
```bash
# 確認腳本具有執行權限
chmod +x git-auto-push.sh
```

**推送失敗**
- 檢查遠端倉庫連接：`git remote -v`
- 確認網路連線和認證設定

## 授權條款

本專案採用 MIT License 授權條款。詳細內容請參閱 [LICENSE](LICENSE) 檔案。
