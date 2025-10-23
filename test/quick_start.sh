#!/bin/bash
# -*- coding: utf-8 -*-

# 測試快速開始腳本
# 用途：快速驗證測試環境並執行基礎測試

set -e

echo "========================================"
echo "  Git 自動化工具測試快速開始"
echo "========================================"
echo ""

# 檢查 Python 版本
echo "🔍 檢查 Python 版本..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "  ✅ $PYTHON_VERSION"
else
    echo "  ❌ Python 3 未安裝"
    exit 1
fi

# 檢查 Git 版本
echo ""
echo "🔍 檢查 Git 版本..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    echo "  ✅ $GIT_VERSION"
else
    echo "  ❌ Git 未安裝"
    exit 1
fi

# 驗證測試框架
echo ""
echo "🔍 驗證測試框架..."
python3 test/verify_tests.py
if [ $? -ne 0 ]; then
    echo "  ❌ 測試框架驗證失敗"
    exit 1
fi

echo ""
echo "========================================"
echo "  選擇要執行的測試"
echo "========================================"
echo ""
echo "1) 執行所有測試 (推薦)"
echo "2) 只測試 git-auto-push.sh"
echo "3) 只測試 git-auto-pr.sh"
echo "4) 只執行整合測試"
echo "5) 快速測試（跳過耗時測試）"
echo "6) 退出"
echo ""

read -p "請選擇 [1-6]: " choice

case $choice in
    1)
        echo ""
        echo "🚀 執行所有測試..."
        python3 test/run_all_tests.py
        ;;
    2)
        echo ""
        echo "🚀 執行 git-auto-push.sh 測試..."
        python3 test/run_all_tests.py --push
        ;;
    3)
        echo ""
        echo "🚀 執行 git-auto-pr.sh 測試..."
        python3 test/run_all_tests.py --pr
        ;;
    4)
        echo ""
        echo "🚀 執行整合測試..."
        python3 test/run_all_tests.py --integration
        ;;
    5)
        echo ""
        echo "⚡ 執行快速測試..."
        python3 test/run_all_tests.py --quick
        ;;
    6)
        echo ""
        echo "👋 退出"
        exit 0
        ;;
    *)
        echo ""
        echo "❌ 無效的選擇"
        exit 1
        ;;
esac

echo ""
echo "========================================"
echo "  測試完成"
echo "========================================"
echo ""
echo "📚 更多資訊請參閱:"
echo "  - test/README.md"
echo "  - test/測試檢查清單.md"
echo ""
