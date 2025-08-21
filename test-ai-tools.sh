#!/bin/bash

echo "=== 測試 AI 工具 ==="

# 創建一個測試變更
echo "# Test file" > test.txt
git add test.txt

echo "1. 測試 codex:"
codex exec "請分析暫存區的 git 變更內容，並生成一個簡潔的中文 commit 訊息標題。只需回應標題，不要額外說明。" 2>/dev/null | grep -v "^\[" | grep -v "^workdir:" | grep -v "^model:" | grep -v "^provider:" | grep -v "^approval:" | grep -v "^sandbox:" | grep -v "^reasoning" | grep -v "^tokens used:" | grep -v "^--------" | grep -v "User instructions:" | grep -v "codex$" | tail -1

echo ""
echo "2. 測試 gemini:"
git diff --cached | gemini -p "請分析這些 git 變更內容，並生成一個簡潔的中文 commit 訊息標題。只需回應標題，不要額外說明。" 2>/dev/null

echo ""
echo "3. 測試 claude:"
claude -p "請分析暫存區的 git 變更內容，並生成一個簡潔的中文 commit 訊息標題。只需回應標題，不要額外說明。" 2>/dev/null

# 清理
git reset HEAD test.txt >/dev/null 2>&1
rm -f test.txt
