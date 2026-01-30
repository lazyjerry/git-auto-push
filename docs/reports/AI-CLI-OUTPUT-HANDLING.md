# AI CLI 輸出處理報告

> 📅 報告日期：2026-01-30  
> 📋 相關檔案：`git-auto-push.sh`、`git-auto-pr.sh`

## 📋 問題摘要

在使用 AI CLI 工具（Gemini、Codex）產生 commit message 時，發現輸出包含大量技術雜訊，導致生成的 commit message 不正確。

### 問題症狀

```
[issue-260130] (node:35959) [DEP0040] DeprecationWarning: The `punycode` module is deprecated...
[ERROR] [IDEClient] Failed to connect to IDE companion extension...
Hook registry initialized with 0 hook entries
重構 AI 相關函數以減少程式碼重複
```

預期的 commit message 應該只有：`重構 AI 相關函數以減少程式碼重複`

---

## 🔍 根本原因分析

### Gemini CLI 雜訊來源

| 訊息類型 | 輸出管道 | 來源說明 |
|---------|---------|----------|
| `(node:xxxxx) DeprecationWarning` | **stderr** | Node.js 運行時的 punycode 模組棄用警告 |
| `[ERROR] [IDEClient]` | **stderr** | Gemini IDE 擴展連線錯誤（VS Code companion） |
| `Skill "..." is overriding` | **stderr** | Gemini skill 系統覆蓋提示 |
| `Hook registry initialized` | **stderr** | Gemini 初始化訊息 |
| `Loaded cached credentials` | **stderr** | 認證狀態訊息 |
| `Attempt N failed...exhausted capacity` | **stderr** | API 配額限制重試訊息 |

**關鍵發現**：Gemini 的技術雜訊全部輸出到 **stderr**，實際 AI 回應輸出到 **stdout**。

### Codex CLI 雜訊來源

| 訊息類型 | 輸出管道 | 來源說明 |
|---------|---------|----------|
| `OpenAI Codex v0.44.0` | **stdout** | 版本標頭 |
| `workdir:`, `model:`, `provider:` | **stdout** | 工作環境資訊 |
| `approval:`, `sandbox:`, `reasoning` | **stdout** | 執行模式設定 |
| `session id:` | **stdout** | 會話識別碼 |
| `user` / `codex` | **stdout** | 對話角色標記 |
| `tokens used` | **stdout** | Token 使用統計 |

**關鍵發現**：Codex 的技術雜訊和 AI 回應都輸出到 **stdout**，無法透過 stderr 重導向分離。

---

## ✅ 解決方案

### Gemini：使用 stderr 重導向

```bash
# ❌ 錯誤：合併 stderr 到 stdout（包含雜訊）
output=$(gemini -p "$prompt" < "$input_file" 2>&1)

# ✅ 正確：丟棄 stderr（只保留乾淨的 AI 回應）
output=$(gemini -p "$prompt" < "$input_file" 2>/dev/null)
```

**測試驗證**：
```bash
# 包含雜訊
$ gemini -p "今天幾號？" 2>&1
(node:44195) [DEP0040] DeprecationWarning: The `punycode` module is deprecated...
[ERROR] [IDEClient] Failed to connect to IDE companion extension...
今天日期是 2026 年 1 月 30 日，星期五。

# 乾淨輸出
$ gemini -p "今天幾號？" 2>/dev/null
今天星期五，2026 年 1 月 30 日。
```

### Codex：使用 --output-last-message 選項

```bash
# ❌ 錯誤：直接捕獲 stdout（包含 header 和 metadata）
output=$(codex exec "$prompt")

# ✅ 正確：使用 --output-last-message 將乾淨回應寫入檔案
temp_output=$(mktemp)
codex exec --output-last-message "$temp_output" "$prompt" 2>/dev/null
output=$(cat "$temp_output")
rm -f "$temp_output"
```

**測試驗證**：
```bash
# 包含雜訊
$ codex exec "說 hello" 2>&1
OpenAI Codex v0.44.0 (research preview)
--------
workdir: /Users/workjerry/work/git-auto-push
model: gpt-5.2-codex
...
codex
hello
tokens used
6,201

# 乾淨輸出
$ codex exec --output-last-message /tmp/out.txt "說 hello" && cat /tmp/out.txt
hello
```

---

## 📊 方案比較

| 項目 | Gemini | Codex |
|------|--------|-------|
| 雜訊位置 | stderr | stdout |
| 解法複雜度 | 簡單（重導向） | 中等（臨時檔案） |
| 需要臨時檔案 | 否 | 是 |
| 解法 | `2>/dev/null` | `--output-last-message` |
| 額外選項 | 無 | `--json` 也可用 |

---

## 🔧 額外優化（可選）

### Gemini 配置優化

修改 `~/.gemini/settings.json` 可減少部分雜訊：

```json
{
  "ide": {
    "enabled": false  // 禁用 IDE 連線，避免 [ERROR] [IDEClient] 訊息
  }
}
```

### 環境變數優化

```bash
# 抑制 Node.js 棄用警告
NODE_NO_WARNINGS=1 gemini -p "prompt"
```

**效果**：
- `NODE_NO_WARNINGS=1`：移除 `DeprecationWarning`
- `ide.enabled = false`：移除 `[ERROR] [IDEClient]`

> ⚠️ 注意：即使使用這些優化，仍有部分訊息無法透過配置關閉（如 `Loaded cached credentials`、`Hook registry initialized`），因此 `2>/dev/null` 仍是最可靠的解法。

---

## 📝 程式碼修改摘要

### git-auto-push.sh

1. **`run_stdin_ai_command()`**（gemini/claude）
   - 將 `2>&1` 改為 `2>/dev/null`
   - 新增臨時檔案儲存 prompt 避免引號解析問題

2. **`run_codex_command()`**
   - 新增 `--output-last-message` 選項
   - 從臨時檔案讀取乾淨輸出
   - 移除複雜的正則表達式過濾邏輯

3. **`clean_ai_message()`**
   - 使用 `grep -v -E` 逐行過濾
   - 新增多種雜訊模式匹配

### git-auto-pr.sh

同步更新以上所有函數。

---

## 🧪 測試建議

```bash
# 1. 語法檢查
bash -n git-auto-push.sh && bash -n git-auto-pr.sh

# 2. Gemini 測試
gemini -p "說 hello" 2>/dev/null

# 3. Codex 測試
codex exec --output-last-message /tmp/test.txt "說 hello" && cat /tmp/test.txt

# 4. 整合測試
./git-auto-push.sh -a  # 全自動模式
```

---

## 📚 參考資源

- [Gemini CLI 文檔](https://github.com/google-gemini/gemini-cli)
- [OpenAI Codex CLI 文檔](https://github.com/openai/codex)
- Node.js `NODE_NO_WARNINGS` 環境變數

---

## 🔄 後續維護

當 AI CLI 工具更新時，可能需要：

1. 檢查新版本是否有 quiet/silent 模式
2. 確認雜訊訊息格式是否變化
3. 更新 `clean_ai_message()` 的過濾規則
4. 測試 `--output-last-message` 選項是否仍可用
