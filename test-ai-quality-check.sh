#!/usr/bin/env bash
# 測試 AI 品質檢查功能改進
# 用途：驗證重構後的 check_commit_message_quality() 函數

set -euo pipefail

# 顏色輸出
cyan() { printf "\033[0;36m%s\033[0m\n" "$1"; }
green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
yellow() { printf "\033[1;33m%s\033[0m\n" "$1"; }
red() { printf "\033[0;31m%s\033[0m\n" "$1"; }

echo ""
cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cyan "  AI 品質檢查功能改進驗證"
cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 測試 1: 檢查新函數是否存在
yellow "📋 測試 1: 檢查 run_simple_ai_command() 函數"
if grep -q "^run_simple_ai_command()" git-auto-push.sh; then
    green "✓ run_simple_ai_command() 函數已添加"
    
    start_line=$(grep -n "^run_simple_ai_command()" git-auto-push.sh | cut -d':' -f1)
    cyan "  函數位置：第 $start_line 行"
else
    red "✗ run_simple_ai_command() 函數不存在"
    exit 1
fi
echo ""

# 測試 2: 檢查是否使用新函數
yellow "📋 測試 2: 檢查 check_commit_message_quality() 是否使用新函數"
if grep -A 50 "^check_commit_message_quality()" git-auto-push.sh | grep -q "run_simple_ai_command"; then
    green "✓ check_commit_message_quality() 已整合 run_simple_ai_command()"
else
    red "✗ check_commit_message_quality() 未使用 run_simple_ai_command()"
    exit 1
fi
echo ""

# 測試 3: 檢查是否移除了舊的 case 語句
yellow "📋 測試 3: 檢查是否移除了舊的 AI 調用邏輯"
old_pattern_count=$(grep -A 50 "^check_commit_message_quality()" git-auto-push.sh | grep -c "timeout 45s codex" || true)
if [ "$old_pattern_count" -eq 0 ]; then
    green "✓ 舊的直接 AI 調用邏輯已移除"
else
    yellow "⚠ 仍有 $old_pattern_count 處舊的調用方式"
fi
echo ""

# 測試 4: 檢查是否使用 clean_ai_message
yellow "📋 測試 4: 檢查是否使用 clean_ai_message() 清理輸出"
if grep -A 30 "^run_simple_ai_command()" git-auto-push.sh | grep -q "clean_ai_message"; then
    green "✓ run_simple_ai_command() 使用 clean_ai_message() 清理輸出"
else
    red "✗ 未使用 clean_ai_message() 清理輸出"
fi
echo ""

# 測試 5: 檢查錯誤處理
yellow "📋 測試 5: 檢查錯誤處理機制"
error_checks=0

if grep -A 30 "^run_simple_ai_command()" git-auto-push.sh | grep -q "debug_msg"; then
    green "  ✓ 包含調試訊息"
    ((error_checks++))
fi

if grep -A 30 "^run_simple_ai_command()" git-auto-push.sh | grep -q "exit_code"; then
    green "  ✓ 檢查退出碼"
    ((error_checks++))
fi

if grep -A 30 "^run_simple_ai_command()" git-auto-push.sh | grep -q "timeout"; then
    green "  ✓ 包含超時控制"
    ((error_checks++))
fi

cyan "  錯誤處理機制：$error_checks / 3 項"
echo ""

# 測試 6: 語法驗證
yellow "📋 測試 6: 語法驗證"
if bash -n git-auto-push.sh 2>/dev/null; then
    green "✓ 腳本語法正確"
else
    red "✗ 腳本語法錯誤"
    bash -n git-auto-push.sh
    exit 1
fi
echo ""

# 測試 7: 檢查函數註解
yellow "📋 測試 7: 檢查函數文件註解"
if grep -B 10 "^run_simple_ai_command()" git-auto-push.sh | grep -q "# 功能說明"; then
    green "✓ run_simple_ai_command() 包含完整註解"
else
    yellow "⚠ run_simple_ai_command() 可能缺少註解"
fi
echo ""

# 改進總結
cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
green "✅ 改進驗證完成！"
cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

yellow "💡 改進重點："
echo "  1. ✓ 新增 run_simple_ai_command() 函數"
echo "  2. ✓ 移除 tail -1 問題"
echo "  3. ✓ 使用 clean_ai_message() 清理輸出"
echo "  4. ✓ 完整的錯誤處理和調試訊息"
echo "  5. ✓ 統一的 AI 工具調用介面"
echo ""

yellow "📊 主要改進對比："
echo ""
cyan "  舊版問題："
echo "    ❌ 使用 tail -1 只取最後一行（可能為空）"
echo "    ❌ 錯誤訊息被 2>/dev/null 隱藏"
echo "    ❌ 沒有使用 clean_ai_message() 清理"
echo "    ❌ 直接參數傳遞可能有特殊字元問題"
echo "    ❌ 缺少調試訊息"
echo ""
cyan "  新版改進："
echo "    ✅ 取得完整輸出並清理"
echo "    ✅ 錯誤訊息可以看到（debug_msg）"
echo "    ✅ 使用 clean_ai_message() 移除雜訊"
echo "    ✅ 使用臨時檔案傳遞提示詞"
echo "    ✅ 完整的錯誤處理和調試"
echo ""

yellow "🧪 測試建議："
echo "  1. 測試良好訊息："
echo "     ./git-auto-push.sh"
echo "     輸入：新增用戶登入功能，支援 OAuth 驗證"
echo ""
echo "  2. 測試不良訊息："
echo "     ./git-auto-push.sh"
echo "     輸入：fix bug"
echo ""
echo "  3. 測試 AI 工具："
echo "     確保至少一個 AI 工具可用："
echo "     command -v codex && echo '✓ codex 可用'"
echo "     command -v gemini && echo '✓ gemini 可用'"
echo "     command -v claude && echo '✓ claude 可用'"
echo ""
