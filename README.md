# Git Auto Push 自動推送工具

基於多 AI 工具的 Git 工作流程自動化，支援四種操作模式和智能 commit message 生成。

## 🎯 核心特色

- **多模式設計**: 完整流程 | 本地提交 | 僅添加 | 全自動模式
- **AI 工具鏈**: codex → gemini → claude 智能 fallback
- **彩色動畫**: Loading 效果與視覺反饋系統
- **信號處理**: 多層級 trap 機制確保穩定性

## 💡 靈感來源

此工具源自 [@ihower](https://www.threads.com/@ihower) 的 [Claude Code 自動化流程](https://www.threads.com/@ihower/post/DNnLBb6xDKF)，擴展為支援多種 AI CLI 工具的開源替代方案。

## 📸 Screenshots

### 主要介面操作流程

![操作選單界面](./screenshots/main-menu.png)
_主要操作選單，提供四種不同的 Git 工作流程模式_

### AI 智能生成 Commit Message

![AI 生成 Commit Message](./screenshots/ai-commit-generation.png)
_AI 工具自動分析程式碼變更並生成合適的 commit message_

### 全自動模式

![全自動模式](./screenshots/auto-mode.png)
_一鍵執行的全自動模式，完全無需人工介入_

> 📖 **使用指南**：完整的全自動模式設定和使用說明，請參閱 [AUTO_MODE_GUIDE.md](./AUTO_MODE_GUIDE.md)

## ✨ 主要功能

- 🔍 **自動檢測** Git 倉庫和變更狀態
- 📝 **AI 智能生成** commit message（支援多種 AI 工具）
- 🎯 **靈活選單** 四種操作模式：完整流程、本地提交、僅添加檔案、全自動模式
- 🎬 **Loading 動畫** AI 工具調用時的精美動畫效果
- 🌈 **彩色輸出** 提供清晰的視覺反饋和粗體突出顯示
- 🛡️ **安全確認** 每步操作都有確認機制和輸入緩衝區清理
- 🚀 **命令列支援** 支援全自動模式的命令列參數

## 🎯 操作模式

工具提供四種靈活的操作模式：

### 1. 🚀 完整流程 (預設)

- **流程**：add → commit → push
- **適用**：日常開發提交，完整的版本控制流程
- **特色**：包含 AI 生成 commit message、用戶確認等完整功能

### 2. 📝 本地提交

- **流程**：add → commit
- **適用**：離線開發、本地測試或暫不推送的情況
- **特色**：完成本地版本記錄，稍後可手動推送

### 3. 📦 僅添加檔案

- **流程**：add
- **適用**：分階段提交、檢查變更或暫存檔案
- **特色**：將變更添加到暫存區，保留提交控制權

### 4. 🤖 全自動模式 (新)

- **流程**：add → AI commit → push
- **適用**：快速提交、自動化腳本、CI/CD 整合
- **特色**：完全無需用戶介入，AI 自動生成 commit message 並推送
- **命令列**：支援 `--auto` 和 `-a` 參數直接啟用

> 📖 **詳細說明**：關於全自動模式的完整使用指南，請參閱 [AUTO_MODE_GUIDE.md](AUTO_MODE_GUIDE.md)

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

## 🛠 故障排除

````

## � 故障排除

### AI 工具問題
```bash
# 檢查工具狀態
./check-ai-tools.sh && ./test-ai-tools.sh

# 登入認證
claude login    # Claude CLI
gh auth login   # GitHub Copilot
````

### 輸入處理問題

- **v1.1+** 已修正輸入緩衝區清理 (每次確認前執行 `read -r -t 0.1 dummy`)
- 使用 **空白輸入 = 同意** 的預設行為
- 重試機制: 輸入 `'ai'` 重新生成, `'q'` 退出

### 信號處理架構

```bash
# 三層 trap 機制確保穩定性
trap global_cleanup INT TERM      # 主程序層級
trap loading_cleanup INT TERM     # Loading 動畫層級
trap cleanup_and_exit INT TERM    # 命令執行層級
```

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

## 🤝 參與貢獻

```bash
# 標準 Git 工作流程
git checkout -b feature/amazing-feature
git commit -m 'Add amazing feature'
git push origin feature/amazing-feature
# 然後開啟 Pull Request
```

---

作者: **A Bit of Vibe Jerry** ([@lazyjerry](https://github.com/lazyjerry))  
授權: **MIT License** - 查看 [LICENSE](LICENSE)

⭐️ 如果這個工具對您有幫助，請給個 Star 支持！
