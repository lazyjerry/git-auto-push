# Git Auto-Push 工具

這是一個單腳本 Bash 工具，提供 Git 工作流程自動化，整合多種 AI 工具鏈，協助開發者快速完成 Git 操作流程。

## 專案簡介

Git Auto-Push 工具主要透過單一腳本整合 Git 工作流程，特色功能包含：

- 多種操作模式，滿足不同開發情境需求
- 多 AI 工具鏈整合，自動生成高品質 commit message
- 完整的錯誤處理與信號中斷處理機制
- 互動式選單與直觀的使用者介面
- 彩色終端輸出，提升使用體驗

## 系統結構

專案採用單腳本設計，所有功能模組都整合在單一檔案中：

```
git-auto-push.sh          # 主腳本 - 所有功能都在此檔案
├── AI 工具整合           # run_*_command() 函數群
├── Loading 動畫系統      # show_loading() + 背景進程
├── 信號處理機制          # 多層級 trap cleanup
└── 四種操作模式          # execute_*_workflow() 函數
```

目錄結構：

```
.
├── git-auto-push.sh     # 主程式腳本
├── LICENSE              # MIT 授權條款
└── screenshots/         # 使用者介面預覽圖
    ├── ai-commit-generation.png
    ├── auto-mode.png
    └── main-menu.png
```

## 安裝與啟動

### 基本安裝

1. 複製專案到本地：

   ```bash
   git clone https://github.com/lazyjerry/git-auto-push.git
   ```

2. 進入專案目錄：

   ```bash
   cd git-auto-push
   ```

3. 設定執行權限：
   ```bash
   chmod +x git-auto-push.sh
   ```

### 全域安裝（方便隨時使用）

1. 將腳本移至系統 PATH 目錄：

   ```bash
   sudo cp git-auto-push.sh /usr/local/bin/git-auto-push
   sudo chmod +x /usr/local/bin/git-auto-push
   ```

2. **或**建立個人 bin 目錄並加入 PATH：

   ```bash
   mkdir -p ~/bin
   cp git-auto-push.sh ~/bin/git-auto-push
   chmod +x ~/bin/git-auto-push
   echo 'export PATH=$PATH:~/bin' >> ~/.zshrc  # 或 ~/.bashrc
   source ~/.zshrc  # 或 source ~/.bashrc
   ```

3. 使用方式：
   ```bash
   git-auto-push  # 在任何 Git 倉庫中直接使用
   ```

### AI 工具相依性（選擇性安裝）

若要使用自動 commit message 生成功能，請安裝下列 AI CLI 工具：

- codex (首選工具)
- gemini
- claude

腳本會依序檢查可用的工具，若全部不可用，將使用預設訊息。

## 使用方法

### 基本命令

執行互動式模式（提供選單）：

```bash
./git-auto-push.sh
```

直接執行全自動模式：

```bash
./git-auto-push.sh --auto
# 或使用簡短參數
./git-auto-push.sh -a
```

### 操作模式說明

工具提供四種操作模式：

| 模式        | 流程                   | 使用場景         |
| ----------- | ---------------------- | ---------------- |
| 1. 完整流程 | add → commit → push    | 日常開發         |
| 2. 本地提交 | add → commit           | 離線開發         |
| 3. 僅添加   | add                    | 暫存檔案         |
| 4. 全自動   | add → AI commit → push | CI/CD 或無人值守 |

## 使用情境

### 情境一：日常提交開發進度

當您有一組變更需要提交並推送到遠端時：

```bash
cd 您的專案目錄
/path/to/git-auto-push.sh
# 選擇選項 1，輸入 commit message 後確認
```

### 情境二：離線開發環境

當您需要在離線環境工作，但仍想記錄變更：

```bash
cd 您的專案目錄
/path/to/git-auto-push.sh
# 選擇選項 2，完成本地提交
```

### 情境三：自動化 CI/CD 流程

在自動化腳本或 CI/CD 流程中：

```bash
cd 您的專案目錄
/path/to/git-auto-push.sh --auto
```

## 錯誤排除

以下為常見錯誤與解決方案：

1. **「AI 工具 xxx 未安裝，跳過...」**

   - 確認相關 AI CLI 工具是否已正確安裝
   - 檢查工具是否在系統 PATH 中

2. **「無法從遠端倉庫拉取更新」**

   - 檢查網路連接狀態
   - 確認 Git 認證是否正確設定

3. **「未偵測到 Git 倉庫」**

   - 確認當前目錄是否為 Git 倉庫
   - 使用 `git init` 初始化新倉庫

4. **AI 工具執行超時**
   - 檢查網路連線是否穩定
   - 工具有 45 秒統一超時機制，若仍無回應將自動嘗試下一個工具

## 授權條款

本專案採用 MIT 授權條款發布。

Copyright (c) 2025 Lazy Jerry

詳細授權內容請參閱 [LICENSE](LICENSE) 檔案。
