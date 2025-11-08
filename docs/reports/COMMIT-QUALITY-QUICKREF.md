# Commit 訊息品質檢查 - 快速參考

## 🚀 快速開始

### 啟用/停用品質檢查

編輯 `git-auto-push.sh` 第 133 行：

```bash
# 自動檢查模式（預設）
AUTO_CHECK_COMMIT_QUALITY=true

# 詢問模式
AUTO_CHECK_COMMIT_QUALITY=false
```

## 📋 兩種模式對比

| 特性 | 自動模式（true） | 詢問模式（false） |
|------|-----------------|------------------|
| 檢查時機 | 每次提交前自動檢查 | 提示詢問，預設跳過 |
| 預設行為 | 執行檢查 | 不檢查（N） |
| 適用場景 | 團隊專案、嚴格規範 | 快速開發、個人專案 |
| 時間成本 | +2-5秒 | +1秒（跳過）/+3-6秒（檢查） |

## ✅ 良好 vs ❌ 不良訊息

### ✅ 良好範例
```
新增用戶登入功能，支援 OAuth 2.0 驗證
修正檔案上傳時的記憶體溢位問題
重構訂單處理邏輯以提升查詢效能
移除已棄用的 API 端點
更新相依套件至最新穩定版本
```

### ❌ 不良範例
```
fix bug          # 沒說修什麼
update           # 完全不知道更新什麼
修改程式碼       # 太籠統
test             # 缺乏說明
.                # 毫無意義
```

## 🤖 AI 工具設定

### 檢查工具狀態
```bash
# 檢查是否安裝
command -v codex
command -v gemini
command -v claude

# 測試工具
codex "測試訊息"
```

### 工具優先順序
編輯第 88 行：
```bash
readonly AI_TOOLS=("codex" "gemini" "claude")
```

## 🔧 常見操作

### 1. 暫時停用檢查（單次）
```bash
# 修改配置為 false
AUTO_CHECK_COMMIT_QUALITY=false

# 執行提交
./git-auto-push.sh

# 改回 true（如需要）
```

### 2. 使用詢問模式
```bash
# 設定為 false
AUTO_CHECK_COMMIT_QUALITY=false

# 執行時會詢問
是否檢查 commit 訊息品質？[y/N]: 
# 直接按 Enter 跳過（預設 N）
# 輸入 y 才檢查
```

### 3. 處理品質警告
```bash
⚠ Commit 訊息品質檢查警告：
分析結果：不良
原因：訊息過於簡略

是否仍要繼續提交？[y/N]: 
# y = 繼續提交
# n = 取消，重新輸入訊息
```

## 🐛 問題排解

### AI 工具總是失敗？
```bash
# 1. 檢查工具安裝
command -v codex || echo "codex 未安裝"

# 2. 檢查認證
codex auth status
gemini auth status

# 3. 重新登入
codex auth login
```

### 檢查太慢？
```bash
# 調整超時時間（行 1234，找到 timeout 45）
timeout 30 "$tool" "$quality_prompt"  # 改為 30 秒

# 或切換到更快的工具
readonly AI_TOOLS=("gemini" "codex")  # gemini 通常較快
```

### 想完全停用？
```bash
# 方法 1：設定為 false 並總是跳過
AUTO_CHECK_COMMIT_QUALITY=false
# 執行時直接按 Enter

# 方法 2：註解掉整合（行 1287-1289）
# if ! check_commit_message_quality "$message"; then
#     return 1
# fi
```

## 📊 流程圖（簡化版）

```
提交 → 檢查配置
          ↓
    ┌─────┴─────┐
  true        false
    ↓            ↓
  AI檢查      詢問檢查？
    ↓            ↓
  結果      Yes → AI檢查
    ↓       No → 跳過
    └────┬────┘
         ↓
      確認提交
```

## 💡 最佳實踐

### 撰寫良好訊息的技巧

1. **使用動詞開頭**
   - ✅ 新增、修正、重構、移除、更新
   - ❌ 修改、調整、處理

2. **描述具體內容**
   - ✅ 修正登入時的 token 過期錯誤
   - ❌ 修正錯誤

3. **說明目的**
   - ✅ 重構查詢邏輯以提升效能
   - ❌ 重構程式碼

4. **使用 Conventional Commits**
   ```
   feat: 新增功能
   fix: 錯誤修正
   docs: 文件更新
   refactor: 程式重構
   test: 測試相關
   chore: 雜項任務
   ```

### 配置建議

| 情境 | 建議配置 | 理由 |
|------|---------|------|
| 團隊專案 | `true` | 統一品質標準 |
| 開源專案 | `true` | 維護專業形象 |
| 個人學習 | `true` | 培養良好習慣 |
| 快速原型 | `false` | 不打斷流程 |
| 緊急修復 | `false` | 時間優先 |
| 實驗專案 | `false` | 彈性較高 |

## 📚 更多資訊

- **完整文件**：`docs/FEATURE-COMMIT-QUALITY.md`
- **開發總結**：`docs/COMMIT-QUALITY-SUMMARY.md`
- **測試腳本**：`test-quality-check.sh`
- **主程式**：`git-auto-push.sh`

## 🆘 需要協助？

1. 執行測試腳本檢查狀態
   ```bash
   ./test-quality-check.sh
   ```

2. 查看詳細說明
   ```bash
   ./git-auto-push.sh --help | grep -A 20 "品質檢查"
   ```

3. 檢視完整文件
   ```bash
   cat docs/FEATURE-COMMIT-QUALITY.md
   ```

---

**提示**：這是快速參考，完整說明請參閱 `docs/FEATURE-COMMIT-QUALITY.md`
