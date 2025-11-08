#!/usr/bin/env bash
# 測試 commit 訊息品質檢查功能
# 用途：驗證 AUTO_CHECK_COMMIT_QUALITY 配置和 check_commit_message_quality() 函數

set -euo pipefail

# 顏色輸出函數
cyan_msg() { printf "\033[0;36m%s\033[0m\n" "$1" >&2; }
green_msg() { printf "\033[0;32m%s\033[0m\n" "$1" >&2; }
yellow_msg() { printf "\033[1;33m%s\033[0m\n" "$1" >&2; }
red_msg() { printf "\033[0;31m%s\033[0m\n" "$1" >&2; }

echo ""
cyan_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cyan_msg "  Commit 訊息品質檢查功能測試"
cyan_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 測試 1: 檢查配置變數是否存在
yellow_msg "📋 測試 1: 檢查配置變數"
if grep -q "AUTO_CHECK_COMMIT_QUALITY" git-auto-push.sh; then
    green_msg "✓ AUTO_CHECK_COMMIT_QUALITY 配置變數已添加"
    
    # 顯示配置值
    config_value=$(grep "^AUTO_CHECK_COMMIT_QUALITY=" git-auto-push.sh | head -1 | cut -d'=' -f2)
    cyan_msg "  當前值：$config_value"
else
    red_msg "✗ 找不到 AUTO_CHECK_COMMIT_QUALITY 配置變數"
    exit 1
fi
echo ""

# 測試 2: 檢查品質檢查函數是否存在
yellow_msg "📋 測試 2: 檢查品質檢查函數"
if grep -q "check_commit_message_quality()" git-auto-push.sh; then
    green_msg "✓ check_commit_message_quality() 函數已實作"
    
    # 統計函數行數
    start_line=$(grep -n "^check_commit_message_quality()" git-auto-push.sh | head -1 | cut -d':' -f1)
    cyan_msg "  函數起始行：$start_line"
else
    red_msg "✗ 找不到 check_commit_message_quality() 函數"
    exit 1
fi
echo ""

# 測試 3: 檢查 confirm_commit() 是否整合品質檢查
yellow_msg "📋 測試 3: 檢查 confirm_commit() 整合"
if grep -A 10 "^confirm_commit()" git-auto-push.sh | grep -q "check_commit_message_quality"; then
    green_msg "✓ confirm_commit() 已整合品質檢查呼叫"
    
    # 顯示整合方式
    cyan_msg "  整合邏輯："
    grep -A 5 "^confirm_commit()" git-auto-push.sh | grep -B 1 -A 1 "check_commit_message_quality" | sed 's/^/    /'
else
    red_msg "✗ confirm_commit() 未整合品質檢查"
    exit 1
fi
echo ""

# 測試 4: 檢查說明文件是否更新
yellow_msg "📋 測試 4: 檢查說明文件"
if grep -q "Commit 訊息品質檢查" git-auto-push.sh; then
    green_msg "✓ show_help() 已包含品質檢查說明"
else
    yellow_msg "⚠ show_help() 可能尚未更新品質檢查說明"
fi
echo ""

# 測試 5: 語法驗證
yellow_msg "📋 測試 5: 語法驗證"
if bash -n git-auto-push.sh 2>/dev/null; then
    green_msg "✓ 腳本語法正確"
else
    red_msg "✗ 腳本語法錯誤"
    bash -n git-auto-push.sh
    exit 1
fi
echo ""

# 測試 6: 檢查 AI 工具配置
yellow_msg "📋 測試 6: 檢查 AI 工具配置"
if grep -q "readonly AI_TOOLS=" git-auto-push.sh; then
    green_msg "✓ AI_TOOLS 配置存在"
    
    tools=$(grep "^readonly AI_TOOLS=" git-auto-push.sh | sed 's/.*(\(.*\)).*/\1/')
    cyan_msg "  可用工具：$tools"
else
    yellow_msg "⚠ AI_TOOLS 配置可能不存在"
fi
echo ""

# 測試總結
cyan_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
green_msg "✅ 所有測試通過！"
cyan_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

yellow_msg "💡 下一步建議："
cyan_msg "  1. 執行 ./git-auto-push.sh --help 查看更新後的說明"
cyan_msg "  2. 執行 ./git-auto-push.sh 測試互動式品質檢查"
cyan_msg "  3. 測試 AUTO_CHECK_COMMIT_QUALITY=false 的詢問模式"
cyan_msg "  4. 測試不良訊息（如 'fix bug'）的警告功能"
echo ""
