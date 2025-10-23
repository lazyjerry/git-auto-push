#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
測試框架驗證腳本
快速驗證測試套件是否正常運作
"""

import sys
from pathlib import Path

# 測試檔案列表
test_files = [
    "test_helpers.py",
    "test_git_auto_push.py", 
    "test_git_auto_pr.py",
    "test_integration.py",
    "run_all_tests.py"
]

def verify_test_structure():
    """驗證測試檔案結構"""
    print("🔍 驗證測試檔案結構...")
    test_dir = Path(__file__).parent
    
    missing_files = []
    for filename in test_files:
        file_path = test_dir / filename
        if not file_path.exists():
            missing_files.append(filename)
            print(f"  ❌ 缺少: {filename}")
        else:
            print(f"  ✅ 存在: {filename}")
    
    if missing_files:
        print(f"\n❌ 缺少 {len(missing_files)} 個檔案")
        return False
    else:
        print("\n✅ 所有測試檔案都存在")
        return True

def verify_imports():
    """驗證模組導入"""
    print("\n🔍 驗證模組導入...")
    
    try:
        import test_helpers
        print("  ✅ test_helpers 導入成功")
    except Exception as e:
        print(f"  ❌ test_helpers 導入失敗: {e}")
        return False
    
    try:
        import test_git_auto_push
        print("  ✅ test_git_auto_push 導入成功")
    except Exception as e:
        print(f"  ❌ test_git_auto_push 導入失敗: {e}")
        return False
    
    try:
        import test_git_auto_pr
        print("  ✅ test_git_auto_pr 導入成功")
    except Exception as e:
        print(f"  ❌ test_git_auto_pr 導入失敗: {e}")
        return False
    
    try:
        import test_integration
        print("  ✅ test_integration 導入成功")
    except Exception as e:
        print(f"  ❌ test_integration 導入失敗: {e}")
        return False
    
    print("\n✅ 所有模組導入成功")
    return True

def verify_scripts():
    """驗證被測試的腳本"""
    print("\n🔍 驗證被測試的腳本...")
    
    project_root = Path(__file__).parent.parent
    scripts = [
        "git-auto-push.sh",
        "git-auto-pr.sh"
    ]
    
    missing_scripts = []
    for script in scripts:
        script_path = project_root / script
        if not script_path.exists():
            missing_scripts.append(script)
            print(f"  ❌ 缺少: {script}")
        else:
            print(f"  ✅ 存在: {script}")
    
    if missing_scripts:
        print(f"\n❌ 缺少 {len(missing_scripts)} 個腳本")
        return False
    else:
        print("\n✅ 所有腳本都存在")
        return True

def count_test_cases():
    """統計測試案例數量"""
    print("\n📊 統計測試案例...")
    
    try:
        import unittest
        import test_git_auto_push
        import test_git_auto_pr
        import test_integration
        
        loader = unittest.TestLoader()
        
        push_tests = loader.loadTestsFromModule(test_git_auto_push)
        pr_tests = loader.loadTestsFromModule(test_git_auto_pr)
        integration_tests = loader.loadTestsFromModule(test_integration)
        
        push_count = push_tests.countTestCases()
        pr_count = pr_tests.countTestCases()
        integration_count = integration_tests.countTestCases()
        total = push_count + pr_count + integration_count
        
        print(f"  📝 git-auto-push.sh 測試: {push_count} 個")
        print(f"  📝 git-auto-pr.sh 測試: {pr_count} 個")
        print(f"  📝 整合測試: {integration_count} 個")
        print(f"  📝 總計: {total} 個測試案例")
        
        return True
    except Exception as e:
        print(f"  ❌ 統計失敗: {e}")
        return False

def main():
    """主函數"""
    print("=" * 70)
    print("Git 自動化工具測試框架驗證".center(70))
    print("=" * 70)
    
    results = []
    
    # 驗證檔案結構
    results.append(verify_test_structure())
    
    # 驗證腳本存在
    results.append(verify_scripts())
    
    # 驗證模組導入
    results.append(verify_imports())
    
    # 統計測試案例
    results.append(count_test_cases())
    
    # 總結
    print("\n" + "=" * 70)
    if all(results):
        print("✅ 測試框架驗證通過".center(70))
        print("=" * 70)
        print("\n🚀 可以開始執行測試:")
        print("  python3 test/run_all_tests.py")
        print("  python3 test/run_all_tests.py --push")
        print("  python3 test/run_all_tests.py --pr")
        print("  python3 test/run_all_tests.py --integration")
        return 0
    else:
        print("❌ 測試框架驗證失敗".center(70))
        print("=" * 70)
        return 1

if __name__ == "__main__":
    sys.exit(main())
