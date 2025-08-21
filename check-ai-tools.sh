#!/bin/bash
# AI 工具診斷腳本

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AI 工具狀態診斷 ===${NC}"
echo

# 檢查工具安裝狀態
echo -e "${BLUE}1. 檢查工具安裝狀態:${NC}"
ai_tools=("gemini" "codex" "claude")

for tool in "${ai_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "  ✅ $tool: $(which $tool)"
    else
        echo -e "  ❌ $tool: 未安裝"
    fi
done

echo
echo -e "${BLUE}2. 檢查工具基本功能:${NC}"

# 檢查 gemini
echo -e "  ${YELLOW}測試 gemini...${NC}"
gemini_result=$(timeout 15 gemini -p "test" 2>&1)
gemini_exit_code=$?

if [ $gemini_exit_code -eq 0 ]; then
    if echo "$gemini_result" | grep -q "429\|rateLimitExceeded\|Resource exhausted"; then
        echo -e "  ⚠️  gemini: 連線正常但遇到頻率限制"
        echo -e "     狀態: API 使用量已達上限，但認證正常"
    else
        echo -e "  ✅ gemini: 連線正常"
    fi
elif [ $gemini_exit_code -eq 124 ]; then
    echo -e "  ⏰ gemini: 連線超時 - 可能是網路問題或需要認證"
else
    if echo "$gemini_result" | grep -q "429\|rateLimitExceeded\|Resource exhausted"; then
        echo -e "  ⚠️  gemini: API 頻率限制"
        echo -e "     問題: 使用量已達上限，請稍後再試"
    else
        echo -e "  ❌ gemini: 執行失敗"
        echo -e "     錯誤訊息: ${gemini_result}"
    fi
fi

# 檢查 claude
echo -e "  ${YELLOW}測試 claude...${NC}"
claude_result=$(timeout 10 claude -p "test" < /dev/null 2>&1)
claude_exit_code=$?

if [ $claude_exit_code -eq 0 ]; then
    echo -e "  ✅ claude: 認證正常"
elif echo "$claude_result" | grep -q "Invalid API key\|Please run.*login"; then
    echo -e "  🔑 claude: 需要登入認證"
    echo -e "     解決方法: 執行 'claude /login'"
else
    echo -e "  ❌ claude: 執行失敗"
    echo -e "     錯誤訊息: ${claude_result}"
fi

# 檢查 codex
echo -e "  ${YELLOW}測試 codex...${NC}"
codex_result=$(timeout 10 codex exec "test" 2>&1)
codex_exit_code=$?

if [ $codex_exit_code -eq 0 ]; then
    echo -e "  ✅ codex: 連線正常"
elif [ $codex_exit_code -eq 124 ]; then
    echo -e "  ⏰ codex: 連線超時"
else
    echo -e "  ❌ codex: 執行失敗"
    echo -e "     錯誤訊息: ${codex_result}"
fi

echo
echo -e "${BLUE}3. 建議:${NC}"

# 根據檢查結果提供建議
if [ $gemini_exit_code -eq 124 ]; then
    echo -e "  📍 ${YELLOW}Gemini 超時建議:${NC}"
    echo -e "     - 檢查網路連線"
    echo -e "     - 確認是否需要設定 API key 或認證"
    echo -e "     - 嘗試使用 VPN 或更換網路環境"
elif echo "$gemini_result" | grep -q "429\|rateLimitExceeded\|Resource exhausted"; then
    echo -e "  📍 ${YELLOW}Gemini 頻率限制建議:${NC}"
    echo -e "     - 您的 API 使用量已達上限"
    echo -e "     - 等待一段時間後再試（通常是每分鐘或每小時限制）"
    echo -e "     - 考慮升級到付費方案以獲得更高限額"
    echo -e "     - 使用其他 AI 工具作為備選方案"
fi

if echo "$claude_result" | grep -q "Invalid API key\|Please run.*login"; then
    echo -e "  📍 ${YELLOW}Claude 認證建議:${NC}"
    echo -e "     - 執行: claude /login"
    echo -e "     - 按照提示完成認證流程"
fi

if [ $codex_exit_code -eq 0 ]; then
    echo -e "  📍 ${GREEN}Codex 可正常使用${NC}"
    echo -e "     - 建議優先使用 codex 工具"
fi

echo
echo -e "${BLUE}4. git-auto-push.sh 配置建議:${NC}"
echo -e "  📍 AI 工具優先順序已自動調整："

working_tools=()
if [ $codex_exit_code -eq 0 ]; then
    working_tools+=("codex")
fi
if [ $gemini_exit_code -eq 0 ]; then
    if echo "$gemini_result" | grep -q "429\|rateLimitExceeded\|Resource exhausted"; then
        working_tools+=("gemini(限制中)")
    else
        working_tools+=("gemini")
    fi
fi
if [ $claude_exit_code -eq 0 ]; then
    working_tools+=("claude")
fi

if [ ${#working_tools[@]} -gt 0 ]; then
    echo -e "     - 可用工具: ${working_tools[*]}"
    echo -e "     - 腳本會自動按順序嘗試這些工具"
else
    echo -e "     ⚠️  沒有可用的 AI 工具，需要修復認證問題"
fi

echo
echo -e "${BLUE}=== 診斷完成 ===${NC}"
