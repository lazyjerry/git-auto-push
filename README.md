# Git Auto-Push 工具

**智能化的 Git 工作流程自動化工具**，提供多 AI 工具鏈整合與四種操作模式，讓 Git 提交更聰明、更省時。

## 專案簡介

Git Auto-Push 工具透過 AI 自動生成 commit message，簡化 Git 工作流程。主要特色包括：

- 🤖 **智能 Commit Message 生成**：整合 Codex、Gemini、Claude 三種 AI 工具
- 🚀 **四種操作模式**：從完全手動到全自動，滿足不同使用場景
- ⚡ **45 秒超時機制**：避免 AI 工具卡死，自動降級處理
- 🎨 **彩色終端介面**：直觀的視覺回饋與 Loading 動畫

## 系統結構

```
git-auto-push.sh          # 主腳本 (966 行)
├── AI 工具整合 (4 tools) # run_*_command() 函數群
├── Loading 動畫系統      # show_loading() + 背景進程
├── 信號處理機制         # 多層級 trap cleanup
└── 四種操作模式         # execute_*_workflow() 函數

相關文件/
├── AUTO_MODE_GUIDE.md   # 全自動模式專用文檔
├── screenshots/         # UI 展示圖片
└── LICENSE             # MIT 授權條款
```

## 安裝與啟動

**前置需求：**

- Git 已安裝並設定
- 至少一個 AI CLI 工具：`codex`、`gemini`、或 `claude`

```bash
# 1. 下載腳本並設定執行權限
curl -O https://raw.githubusercontent.com/lazyjerry/git-auto-push/master/git-auto-push.sh
chmod +x git-auto-push.sh

# 2. 基本使用
./git-auto-push.sh           # 互動模式
./git-auto-push.sh --auto    # 全自動模式
./git-auto-push.sh -a        # 全自動模式（短參數）
```

## 使用方法

### 常用指令

```bash
# 互動式選擇操作模式
./git-auto-push.sh

# 全自動模式（適合 CI/CD）
./git-auto-push.sh --auto

# 檢查腳本權限
chmod +x git-auto-push.sh
```

### 四種操作模式

| 模式        | 指令                          | 流程                   | 適用場景   |
| ----------- | ----------------------------- | ---------------------- | ---------- |
| 1. 完整流程 | `./git-auto-push.sh` (選擇 1) | add → commit → push    | 日常開發   |
| 2. 本地提交 | `./git-auto-push.sh` (選擇 2) | add → commit           | 離線開發   |
| 3. 僅添加   | `./git-auto-push.sh` (選擇 3) | add                    | 暫存檔案   |
| 4. 全自動   | `./git-auto-push.sh --auto`   | add → AI commit → push | CI/CD 整合 |

### AI 工具鏈優先級

1. **Codex** (優先) - 最穩定的程式碼分析
2. **Gemini** - 可能遇到頻率限制
3. **Claude** - 需要付費帳號登入
4. **預設訊息** - 所有 AI 工具失敗時的保底方案

## 使用情境

### 日常開發工作流程

```bash
# 1. 修改檔案後執行
./git-auto-push.sh

# 2. 選擇模式 1（完整流程）
# 3. 按 Enter 讓 AI 生成 commit message
# 4. 確認後自動推送
```

### 快速提交小改動

```bash
# 一鍵完成：分析變更 → AI 生成訊息 → 提交 → 推送
./git-auto-push.sh --auto
```

### CI/CD 自動化整合

```bash
# 在自動化腳本中使用
#!/bin/bash
cd /path/to/project
./git-auto-push.sh -a  # 完全無人值守
```

### 離線開發場景

```bash
# 僅本地提交，稍後手動推送
./git-auto-push.sh  # 選擇模式 2
```

## 錯誤排除

### 常見問題及解決方案

**❌ 「不是 Git 倉庫」**

```bash
# 解決方案：初始化 Git 倉庫或切換到正確目錄
git init
# 或
cd /path/to/your/git/project
```

**❌ AI 工具無回應或超時**

- 檢查網路連線狀態
- 等待 45 秒後會自動使用預設訊息
- 確認 AI 工具已正確安裝和登入

**❌ 推送失敗**

```bash
# 確保遠端倉庫已設定
git remote add origin https://github.com/user/repo.git
git remote -v  # 檢查遠端設定
```

**❌ 權限錯誤**

```bash
# 設定執行權限
chmod +x git-auto-push.sh
```

**❌ AI 工具認證問題**

```bash
# Claude 登入
claude /login

# 檢查工具可用性
codex --version
gemini --version
claude --version
```

## 授權條款

本專案採用 MIT 授權條款 - 詳見 [LICENSE](LICENSE) 文件。

Copyright (c) 2025 A Bit of Vibe Jerry

## 授權條款

## 🎯 工作流程

1. **檢查 Git 倉庫**：驗證當前目錄是否為有效的 Git 倉庫
2. **檢測變更**：自動掃描並顯示所有變更的檔案
3. **無變更處理**：如沒有新變更，檢查是否有未推送的提交並提供推送選項
4. **添加檔案**：將所有變更添加到 Git 暫存區
5. **選擇模式**：用戶選擇要執行的操作範圍（或自動模式跳過此步）
6. **生成訊息**：智能 AI 生成或手動輸入 commit message（需要時）
7. **確認提交**：顯示提交資訊供用戶確認（需要時）
8. **執行操作**：根據選擇執行對應的 Git 操作

## � 安裝使用

```bash
# 下載並設置執行權限
curl -O https://raw.githubusercontent.com/lazyjerry/git-auto-push/master/git-auto-push.sh
chmod +x git-auto-push.sh

# 基本使用 - 互動模式
./git-auto-push.sh

# 全自動模式 - 零互動
./git-auto-push.sh --auto

# 全域安裝 (推薦)
sudo cp git-auto-push.sh /usr/local/bin/git-auto-push
```

## ⚙️ 四種操作模式

| 模式         | 流程                   | 場景       | 參數     |
| ------------ | ---------------------- | ---------- | -------- |
| **完整流程** | add → commit → push    | 日常開發   | 預設     |
| **本地提交** | add → commit           | 離線開發   | 選項 2   |
| **僅添加**   | add                    | 暫存檔案   | 選項 3   |
| **全自動**   | add → AI commit → push | CI/CD 整合 | `--auto` |

## 🤖 AI 工具鏈架構

**優先級順序** (hardcoded in `generate_auto_commit_message*()` functions):

```bash
codex → gemini → claude → fallback("自動提交：更新專案檔案")
```

**調用模式**:

- `codex exec '$prompt'` - 直接執行
- `echo '$prompt' | gemini` - stdin 管道
- `echo '$prompt' | claude` - stdin 管道

**關鍵特性**:

- 45 秒統一超時機制
- `clean_ai_message()` 自動清理輸出格式
- 背景 Loading 動畫 (`show_loading()` 進程)

## ⚙️ 配置要點

**關鍵配置位置**:

- `DEFAULT_OPTION=1` (line 674) - 預設操作模式
- AI 工具優先級在 **兩處必須同步**:
  - `generate_auto_commit_message()` (line ~453)
  - `generate_auto_commit_message_silent()` (line ~385)

```bash
# 修改範例：讓 Gemini 優先
local ai_tools=(
    "gemini"    # 第一優先
    "codex"     # 第二優先
    "claude"    # 第三優先
)
```

## 🎬 使用範例

### 互動模式典型流程

```bash
$ ./git-auto-push.sh
檢測到以下變更: M src/main.js
請選擇要執行的 Git 操作: [1-4] (預設 1):
請輸入 commit message (Enter 使用 AI):
⠋ 正在等待 codex 回應...
✅ AI 生成: 🔖 優化主程式邏輯
是否使用此訊息？(y/n):
正在提交變更... ✅ 成功推送到 main
```

### 全自動模式 - 零互動

```bash
$ ./git-auto-push.sh --auto
🤖 全自動模式啟動
檢測變更 → AI 生成 → 自動提交推送
✅ 完整流程執行完成
```

### 無變更時的智能處理

```bash
$ ./git-auto-push.sh
沒有需要提交的變更。
檢測到 2 個未推送的本地提交。
是否推送？(Enter=是):
成功推送到 main 🎉
```

==================================================
🎉 全自動工作流程執行完成！
📊 執行摘要：
✅ 檔案已添加到暫存區
✅ 使用 AI 生成 commit message
✅ 變更已提交到本地倉庫
✅ 變更已推送到遠端倉庫
==================================================

````

### 範例 5：無變更但有未推送提交

```bash
$ ./git-auto-push.sh
Git 自動添加推送到遠端倉庫工具
==================================================
沒有需要提交的變更。

檢測到 2 個未推送的本地提交。

是否要將本地提交推送到遠端倉庫？(y/n，直接按 Enter 表示同意):

正在推送到遠端倉庫...
成功推送到 main 🎉
````

## 📁 專案結構

```
git-auto-push.sh       # 主腳本 (966 行)
├── AI 工具整合         # run_*_command() 函數群
├── Loading 系統        # show_loading() + run_command_with_loading()
├── 模式選擇           # show_operation_menu() + execute_*_workflow()
└── 信號處理           # 多層級 trap 機制

extra_type/           # 替代實現 (Python 開發中)
AUTO_MODE_GUIDE.md    # 全自動模式專用文檔
screenshots/          # UI 展示圖片
```

## � 版本歷程

- **v1.3** - 全自動模式 (`--auto`), 未推送提交檢測
- **v1.2** - 四種操作模式選單, Loading 動畫系統
- **v1.1** - 修正輸入緩衝區清理問題
- **v1.0** - 基礎版本發布

---

作者: **A Bit of Vibe Jerry** ([@lazyjerry](https://github.com/lazyjerry))  
授權: **MIT License** - 查看 [LICENSE](LICENSE)

⭐️ 如果這個工具對您有幫助，請給個 Star 支持！
