# Git Auto Push 自動推送工具

一個功能強大的 Git 工作流程自動化工具，提供完整的從變更檢測到遠端推送的一站式解決方案。

## ✨ 主要功能-

- 🔍 **自動檢測** Git 倉庫和變更狀態
- 📝 **AI 智能生成** commit message（支援多種 AI 工具）
- 🚀 **一鍵操作** 完成 add、commit、push 全流程
- 🌈 **彩色輸出** 提供清晰的視覺反饋
- 🛡️ **安全確認** 每步操作都有確認機制
- 📱 **友善介面** 支援中英文雙語操作

## 🎯 工作流程

1. **檢查 Git 倉庫**：驗證當前目錄是否為有效的 Git 倉庫
2. **檢測變更**：自動掃描並顯示所有變更的檔案
3. **添加檔案**：將所有變更添加到 Git 暫存區
4. **生成訊息**：智能 AI 生成或手動輸入 commit message
5. **確認提交**：顯示提交資訊供用戶確認
6. **本地提交**：執行 Git commit 操作
7. **推送遠端**：自動推送到對應的遠端分支

## 🤖 支援的 AI 工具

工具會依序檢查並使用以下 AI CLI 工具：

| 工具       | 說明                 | 優先級      |
| ---------- | -------------------- | ----------- |
| **codex**  | GitHub Copilot CLI   | 🥇 第一優先 |
| **gemini** | Google Gemini CLI    | 🥈 第二優先 |
| **claude** | Anthropic Claude CLI | 🥉 第三優先 |

### AI 工具設定

- **Codex**: 需要 GitHub Copilot 訂閱和 CLI 工具
- **Gemini**: 支援多種調用方式：
  - 直接使用 `gemini` 命令
  - 透過 `gcloud ai generative-models`
  - 使用 `google-generativeai` CLI
- **Claude**: 支援多種調用方式：
  - 直接使用 `claude` 命令
  - 使用 `anthropic` CLI
  - 使用 `claude-cli` 工具

## 📦 安裝與使用

### 快速開始

1. **下載腳本**：

```bash
wget https://raw.githubusercontent.com/lazyjerry/git-auto-push/master/git-auto-push.sh
# 或
curl -O https://raw.githubusercontent.com/lazyjerry/git-auto-push/master/git-auto-push.sh
```

2. **添加執行權限**：

```bash
chmod +x git-auto-push.sh
```

3. **執行腳本**：

```bash
./git-auto-push.sh
```

### 全域安裝（推薦）

```bash
# 複製到系統路徑
sudo cp git-auto-push.sh /usr/local/bin/git-auto-push
sudo chmod +x /usr/local/bin/git-auto-push

# 現在可以在任何 Git 倉庫中使用
git-auto-push
```

### 創建別名

在你的 `~/.bashrc` 或 `~/.zshrc` 中添加：

```bash
alias gap="git-auto-push"  # 快速別名
alias gitpush="/path/to/git-auto-push.sh"
```

## 🎮 使用說明

### 基本使用

在任何 Git 倉庫目錄中執行：

```bash
./git-auto-push.sh
```

### 互動選項

1. **輸入 commit message**：

   - 直接輸入 → 使用您的訊息
   - 按 Enter → 自動 AI 生成

2. **AI 生成失敗時**：

   - 輸入具體內容 → 使用手動輸入
   - 輸入 `ai` → 重新嘗試 AI 生成
   - 輸入 `q` → 取消操作

3. **確認選項**：
   - `y/yes/是/確認` → 確認操作
   - `n/no/否/取消` → 取消操作

## 🔧 系統需求

- **Shell**: bash, zsh, 或其他 POSIX 兼容 shell
- **Git**: 已安裝並配置的 Git
- **網路**: 推送到遠端倉庫時需要網路連接
- **AI 工具**（可選）: codex, gemini, claude 等 CLI 工具

## 💡 使用範例

### 範例 1：基本工作流程

```bash
$ ./git-auto-push.sh
Git 自動添加推送到遠端倉庫工具
==================================================
檢測到以下變更:
M  src/main.js
A  docs/api.md
正在添加所有變更的檔案...
檔案添加成功！

==================================================
請輸入 commit message (直接按 Enter 可使用 AI 自動生成):
==================================================

正在使用 AI 工具分析變更並生成 commit message...
找到 AI 工具: codex
使用 codex 生成的 commit message: 新增 API 文檔並優化主程式邏輯

AI 生成的 commit message: 新增 API 文檔並優化主程式邏輯
是否使用此訊息？(y/n，直接按 Enter 表示同意):

==================================================
確認提交資訊:
Commit Message: 新增 API 文檔並優化主程式邏輯
==================================================
正在提交變更...
提交成功！
正在推送到遠端倉庫...
成功推送到遠端分支: main

==================================================
所有操作完成！
==================================================
```

### 範例 2：手動輸入 commit message

```bash
$ ./git-auto-push.sh
[...前面步驟相同...]

請輸入 commit message (直接按 Enter 可使用 AI 自動生成):
==================================================
修復用戶登入驗證邏輯

[...繼續後續步驟...]
```

## ⚠️ 注意事項

- **備份重要**：使用前請確保重要變更已備份
- **檢查變更**：腳本會顯示所有變更，請仔細檢查
- **網路連接**：推送時需要穩定的網路連接
- **權限確認**：確保對遠端倉庫有推送權限
- **API 設定**：AI 功能需要相應的 API key 或登入認證

## 🐛 故障排除

### 常見問題

**Q: AI 工具顯示 "Invalid API key"**

```bash
# Claude 登入
claude login

# GitHub Copilot 登入
gh auth login
```

**Q: 推送失敗**

- 檢查網路連接
- 確認遠端倉庫權限
- 檢查分支名稱是否正確

**Q: 顏色顯示異常**

- 確保終端支援 ANSI 顏色
- 嘗試不同的終端應用程式

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

1. Fork 本倉庫
2. 創建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交變更 (`git commit -m 'Add some amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 開啟 Pull Request

## 📄 授權條款

本專案採用 MIT License - 查看 [LICENSE](LICENSE) 檔案了解詳情。

## 👨‍💻 作者

**Vibe Jerry**

- GitHub: [@lazyjerry](https://github.com/lazyjerry)

## 🌟 致謝

感謝所有貢獻者和使用者的支持！

---

如果這個工具對您有幫助，請給個 ⭐️ Star 支持一下！
