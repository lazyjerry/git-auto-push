# Commit 訊息品質檢查功能說明

## 📋 功能概述

這是一個 AI 驅動的 commit 訊息品質檢查功能，在提交前自動分析訊息品質，確保 commit 訊息描述明確、具體且有意義。

## 🎯 設計目標

### 核心理念
- **提升品質**：使用 AI 分析訊息是否清楚描述變更內容和目的
- **彈性配置**：支援自動檢查和詢問模式，不強制中斷快速提交流程
- **容錯機制**：AI 工具失敗時不影響正常提交流程
- **使用者友善**：提供清晰的警告和建議，但最終決定權在使用者

### 檢查標準

#### ✅ 良好的 commit 訊息
- 明確描述具體變更內容
- 說明變更的目的或原因
- 避免模糊或過於簡略的描述

**範例**：
```
新增用戶登入功能，支援 OAuth 2.0 驗證
修正檔案上傳時的記憶體溢位問題
重構訂單處理邏輯以提升效能
```

#### ❌ 不良的 commit 訊息
- 過於簡略，無法理解實際變更
- 缺乏明確目的或描述
- 使用模糊詞彙（如「更新」、「修改」）

**範例**：
```
fix bug          # 沒有說明修正了什麼問題
update           # 完全不知道更新了什麼
修改程式碼       # 過於籠統
test             # 缺乏具體說明
```

## ⚙️ 配置說明

### AUTO_CHECK_COMMIT_QUALITY 變數

**位置**：`git-auto-push.sh` 約第 133 行

**可用值**：
- `true`：自動檢查模式（預設）
- `false`：詢問模式

#### 自動檢查模式（true）
```bash
AUTO_CHECK_COMMIT_QUALITY=true
```

**行為**：
1. 提交前自動使用 AI 檢查訊息品質
2. 檢查良好：直接顯示確認訊息
3. 檢查不良：顯示警告並詢問是否繼續
4. AI 失敗：自動跳過檢查，繼續提交流程

**適用場景**：
- 團隊規範嚴格，需要確保 commit 品質
- 個人開發，希望養成良好習慣
- 專案需要高品質的 commit 歷史

#### 詢問模式（false）
```bash
AUTO_CHECK_COMMIT_QUALITY=false
```

**行為**：
1. 提交前詢問「是否檢查 commit 訊息品質？[y/N]」
2. 預設為 N（否），不中斷快速提交
3. 輸入 Y 時才執行品質檢查
4. 跳過檢查時直接進入確認提交

**適用場景**：
- 快速提交場景，不希望每次都檢查
- 只在重要提交時使用品質檢查
- 個人開發，靈活決定是否檢查

## 🔄 執行流程

### 完整流程圖

```
使用者輸入 commit 訊息
         ↓
   檢查配置變數
         ↓
   ┌─────────────────┐
   │ AUTO_CHECK_     │
   │ COMMIT_QUALITY? │
   └─────┬───────────┘
         │
    ┌────┴────┐
    │         │
  true      false
    │         │
    │    ┌────┴─────────────┐
    │    │ 詢問是否檢查？   │
    │    │ [y/N]            │
    │    └────┬─────────────┘
    │         │
    │    ┌────┴────┐
    │    │         │
    │   Yes       No
    │    │         │
    └────┘         │
         │         │
    ┌────┴────┐   │
    │ AI 品質 │   │
    │ 檢查    │   │
    └────┬────┘   │
         │        │
    ┌────┴────┐  │
    │ 檢查結果│  │
    └────┬────┘  │
         │       │
    ┌────┴────────┴────┐
    │  良好  │  不良   │
    │        │         │
    │   ┌────┴────┐   │
    │   │ 顯示警告│   │
    │   │ 詢問繼續│   │
    │   └────┬────┘   │
    │        │        │
    │   ┌────┴────┐  │
    │   │Yes│ No  │  │
    └───┴───┴──┬──┴──┘
              │
       ┌──────┴───────┐
       │ 顯示確認訊息 │
       │ 詢問是否提交 │
       └──────┬───────┘
              │
         ┌────┴────┐
         │Yes │ No │
         │    │    │
       提交  取消
```

## 🤖 AI 工具整合

### 支援的 AI 工具

依據 `AI_TOOLS` 配置順序（約第 88 行）：

1. **codex**（OpenAI Codex CLI）- 優先使用
2. **gemini**（Google Gemini CLI）- 次要選擇
3. **claude**（Anthropic Claude CLI）- 最後備用

### 容錯機制

#### 工具選擇邏輯
```bash
for tool in "${AI_TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        # 嘗試使用該工具
        if 執行成功; then
            break  # 成功則停止
        else
            continue  # 失敗則嘗試下一個
        fi
    fi
done
```

#### 失敗處理
- **單一工具失敗**：自動嘗試下一個 AI 工具
- **全部工具失敗**：顯示警告但不影響提交
- **超時（45秒）**：視為失敗，嘗試下一個工具
- **網路錯誤**：自動降級至下一個工具

### AI 分析提示詞

內建的分析提示詞會要求 AI：

```
分析以下 commit 訊息的品質，判斷是否：
1. 明確描述具體變更內容
2. 說明變更的目的或原因
3. 避免模糊或過於簡略的描述

請只回答「良好」或「不良」，並簡短說明理由（一行）。

Commit 訊息：
{使用者輸入的訊息}
```

## 📊 實際使用範例

### 範例 1: 自動檢查模式 - 良好訊息

```bash
$ ./git-auto-push.sh
請輸入 commit message：新增用戶註冊功能，包含信箱驗證

🔍 檢查 commit 訊息品質...
✓ Commit 訊息品質良好

==================================================
💬 確認提交資訊:
Commit Message: 新增用戶註冊功能，包含信箱驗證
==================================================
是否確認提交？[Y/n]: 
```

### 範例 2: 自動檢查模式 - 不良訊息

```bash
$ ./git-auto-push.sh
請輸入 commit message：update

🔍 檢查 commit 訊息品質...
⚠ Commit 訊息品質檢查警告：

分析結果：不良
原因：訊息過於簡略，無法理解具體更新了什麼內容

是否仍要繼續提交？[y/N]: n
✗ 使用者取消提交
```

### 範例 3: 詢問模式 - 跳過檢查

```bash
$ ./git-auto-push.sh
# (AUTO_CHECK_COMMIT_QUALITY=false)

請輸入 commit message：修正登入錯誤

是否檢查 commit 訊息品質？[y/N]: 
ℹ️  跳過品質檢查

==================================================
💬 確認提交資訊:
Commit Message: 修正登入錯誤
==================================================
是否確認提交？[Y/n]: 
```

### 範例 4: AI 工具失敗

```bash
$ ./git-auto-push.sh
請輸入 commit message：重構資料庫查詢邏輯

🔍 檢查 commit 訊息品質...
⚠ AI 品質檢查失敗（所有工具都無法使用），跳過檢查

==================================================
💬 確認提交資訊:
Commit Message: 重構資料庫查詢邏輯
==================================================
是否確認提交？[Y/n]: 
```

## 🔧 函數實作詳解

### check_commit_message_quality() 函數

**位置**：`git-auto-push.sh` 約第 1159 行

**函數簽名**：
```bash
check_commit_message_quality() {
    local message="$1"
    # ... 實作邏輯
}
```

**返回值**：
- `0`：品質檢查通過或使用者選擇繼續
- `1`：使用者取消提交

**執行邏輯**：

#### 步驟 1: 檢查配置
```bash
if [[ "$AUTO_CHECK_COMMIT_QUALITY" != "true" ]]; then
    # 詢問模式：詢問是否檢查
    printf "是否檢查 commit 訊息品質？[y/N]: " >&2
    read -r check_quality
    
    if [[ ! "$check_quality" =~ ^[yY]$ ]]; then
        info_msg "ℹ️  跳過品質檢查"
        return 0  # 跳過檢查，繼續提交
    fi
fi
```

#### 步驟 2: 顯示檢查訊息
```bash
echo >&2
info_msg "🔍 檢查 commit 訊息品質..."
```

#### 步驟 3: 準備 AI 提示詞
```bash
local quality_prompt="分析以下 commit 訊息的品質，判斷是否：
1. 明確描述具體變更內容
2. 說明變更的目的或原因
3. 避免模糊或過於簡略的描述

請只回答「良好」或「不良」，並簡短說明理由（一行）。

Commit 訊息：
$message"
```

#### 步驟 4: 嘗試使用 AI 工具
```bash
local ai_response=""
local tool_found=false

for tool in "${AI_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        continue
    fi
    
    tool_found=true
    
    if ai_response=$(timeout 45 "$tool" "$quality_prompt" 2>&1); then
        # 清理 AI 輸出
        ai_response=$(echo "$ai_response" | clean_ai_message)
        
        if [ -n "$ai_response" ]; then
            break  # 成功取得回應
        fi
    fi
done
```

#### 步驟 5: 處理 AI 回應
```bash
if [ -z "$ai_response" ]; then
    # AI 失敗：顯示警告但不阻擋
    warning_msg "⚠ AI 品質檢查失敗，跳過檢查"
    return 0
fi

# 判斷品質
if echo "$ai_response" | grep -iq "良好"; then
    success_msg "✓ Commit 訊息品質良好"
    return 0
else
    # 品質不良：顯示警告並詢問
    warning_msg "⚠ Commit 訊息品質檢查警告："
    echo >&2
    echo "$ai_response" | sed 's/^/  /' >&2
    echo >&2
    
    printf "是否仍要繼續提交？[y/N]: " >&2
    read -r continue_commit
    
    if [[ "$continue_commit" =~ ^[yY]$ ]]; then
        return 0  # 使用者選擇繼續
    else
        error_msg "✗ 使用者取消提交"
        return 1  # 取消提交
    fi
fi
```

### confirm_commit() 整合

**修改位置**：`git-auto-push.sh` 約第 1284 行

**整合方式**：
```bash
confirm_commit() {
    local message="$1"
    
    # 步驟 1: 檢查 commit 訊息品質（在顯示確認訊息之前）
    if ! check_commit_message_quality "$message"; then
        return 1  # 使用者取消提交
    fi
    
    # 步驟 2: 顯示確認訊息
    echo >&2
    echo "==================================================" >&2
    highlight_success_msg "💬 確認提交資訊:"
    echo "Commit Message: $message" >&2
    echo "==================================================" >&2
    
    # 步驟 3: 詢問使用者確認
    # ... 原有邏輯 ...
}
```

**執行順序**：
1. **品質檢查**：先使用 AI 分析訊息品質
2. **顯示訊息**：品質通過後顯示確認資訊
3. **最終確認**：詢問使用者是否提交

## 🎯 最佳實踐建議

### 配置選擇

#### 推薦使用自動檢查模式（true）的情境
- 團隊協作專案，需要統一 commit 品質
- 公開專案，希望維護專業形象
- 學習階段，希望培養良好習慣
- 有充足時間進行程式碼審查

#### 推薦使用詢問模式（false）的情境
- 個人實驗專案，追求快速迭代
- 緊急修復（hotfix），時間優先
- 頻繁的小型提交（WIP commits）
- 不依賴 AI 工具的環境

### 撰寫良好 commit 訊息的技巧

#### 結構化格式（Conventional Commits）
```
<type>(<scope>): <subject>

<body>

<footer>
```

**範例**：
```
feat(auth): 新增雙因素驗證功能

實作基於 TOTP 的雙因素驗證，支援 Google Authenticator。
包含：
- QR code 生成
- 驗證碼驗證
- 備用碼生成

Closes #123
```

#### 動詞使用建議
- ✅ **明確動詞**：新增、修正、重構、移除、更新
- ❌ **模糊動詞**：修改、調整、處理、改動

#### 描述層次
1. **What（是什麼）**：描述變更的內容
2. **Why（為什麼）**：說明變更的原因或目的
3. **How（如何）**：複雜變更時說明實作方式

### AI 工具配置建議

#### 優先順序設定
```bash
# 根據可用性和速度調整順序
readonly AI_TOOLS=("codex" "gemini" "claude")

# 範例：優先使用本地部署的工具
readonly AI_TOOLS=("local-llm" "codex" "gemini")
```

#### 超時時間調整
- **預設**：45 秒（適合大部分情況）
- **快速模式**：30 秒（網路良好時）
- **穩定模式**：60 秒（網路不穩時）

## 📊 效能影響分析

### 時間成本

| 模式 | 額外時間 | 說明 |
|------|----------|------|
| 自動檢查（良好訊息） | 2-5 秒 | AI 分析時間 |
| 自動檢查（不良訊息） | 2-5 秒 + 使用者決定時間 | 包含警告顯示 |
| 詢問模式（跳過） | 1 秒 | 僅詢問時間 |
| 詢問模式（檢查） | 3-6 秒 | 詢問 + AI 分析 |
| AI 失敗 | 45 秒 | 超時後自動跳過 |

### 網路需求

- **必要性**：需要網路連線（除非使用本地 AI）
- **頻寬**：低（僅傳輸文字）
- **離線模式**：自動跳過檢查，不影響提交

## 🐛 常見問題與解決

### Q1: AI 檢查總是失敗？

**可能原因**：
1. AI 工具未安裝或未配置
2. 網路連線問題
3. API Token 過期或無效

**解決方案**：
```bash
# 檢查工具是否安裝
command -v codex
command -v gemini
command -v claude

# 檢查工具配置
codex --version
gemini --help

# 重新登入（以 codex 為例）
codex auth login
```

### Q2: 良好的訊息被判定為不良？

**可能原因**：
- AI 判斷標準過於嚴格
- 訊息格式不符合 AI 預期

**解決方案**：
1. **短期**：選擇繼續提交（y）
2. **長期**：提供更詳細的描述

**範例**：
```
# 可能被判為不良
修正錯誤

# 改進版本
修正登入時的 session 過期錯誤
```

### Q3: 想要完全停用品質檢查？

**方案 1：設定為詢問模式並總是跳過**
```bash
AUTO_CHECK_COMMIT_QUALITY=false
# 執行時直接按 Enter（預設 N）
```

**方案 2：修改 confirm_commit() 函數**
```bash
# 註解掉品質檢查呼叫
confirm_commit() {
    local message="$1"
    
    # if ! check_commit_message_quality "$message"; then
    #     return 1
    # fi
    
    # ... 其他邏輯 ...
}
```

### Q4: 如何自訂檢查標準？

**修改提示詞**：
在 `check_commit_message_quality()` 函數中修改 `quality_prompt` 變數

**範例：更嚴格的標準**
```bash
local quality_prompt="分析以下 commit 訊息是否符合 Conventional Commits 規範：
1. 是否包含 type（feat/fix/docs 等）
2. 是否有清楚的 subject
3. 描述是否具體且有意義

請只回答「良好」或「不良」，並簡短說明理由。

Commit 訊息：
$message"
```

### Q5: 品質檢查影響提交速度？

**優化建議**：

1. **使用詢問模式**
   ```bash
   AUTO_CHECK_COMMIT_QUALITY=false
   # 僅在重要提交時檢查
   ```

2. **調整超時時間**
   ```bash
   # 在函數中找到這行
   timeout 45 "$tool" "$quality_prompt"
   # 改為
   timeout 30 "$tool" "$quality_prompt"
   ```

3. **優先使用快速 AI 工具**
   ```bash
   # 調整工具順序，將最快的放前面
   readonly AI_TOOLS=("gemini" "codex" "claude")
   ```

## 📚 相關文件

- **Git Auto Push 主文檔**：`README.md`
- **選項 7 功能說明**：`docs/FEATURE-AMEND.md`
- **開發報告**：`docs/reports/選項7-變更commit訊息功能開發報告.md`
- **測試腳本**：`test-quality-check.sh`

## 🔄 版本歷史

### v2.2.0（當前版本）
- 🆕 新增 commit 訊息品質檢查功能
- 🆕 支援自動檢查和詢問兩種模式
- 🆕 整合 AI 工具容錯機制
- 🆕 更新 show_help() 說明文件

### v2.1.0
- 新增選項 7：變更最後一次 commit 訊息
- 新增任務編號自動帶入功能
- 優化使用者體驗

## 📧 回饋與建議

如有任何問題或建議，歡迎透過以下方式聯繫：

- GitHub Issues：[專案倉庫](https://github.com/lazyjerry/git-auto-push)
- Email：[作者信箱]

---

**最後更新**：2025-01-XX
**作者**：Lazy Jerry
**授權**：MIT License
