#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
測試執行器 - 執行所有測試套件

使用方式：
    python3 run_all_tests.py              # 執行所有測試
    python3 run_all_tests.py --push       # 只測試 git-auto-push.sh
    python3 run_all_tests.py --pr         # 只測試 git-auto-pr.sh
    python3 run_all_tests.py --integration # 只執行整合測試
    python3 run_all_tests.py --verbose    # 詳細輸出
    python3 run_all_tests.py --quick      # 快速測試（跳過耗時測試）
"""

import sys
import unittest
import argparse
from pathlib import Path
import time

# 確保可以導入測試模組
sys.path.insert(0, str(Path(__file__).parent))

# 導入測試模組
import test_git_auto_push
import test_git_auto_pr
import test_integration


class ColoredTextTestResult(unittest.TextTestResult):
    """彩色輸出的測試結果"""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.test_start_time = None
        self.current_test_index = 0
        self.total_tests = 0
        
    def startTest(self, test):
        super().startTest(test)
        self.test_start_time = time.time()
        self.current_test_index += 1
        
        if self.showAll:
            # 顯示測試進度和描述
            test_name = str(test).split()[0]
            test_doc = test.shortDescription() or "無描述"
            self.stream.write(f"\n\033[1;36m[{self.current_test_index}/{self.total_tests}]\033[0m ")
            self.stream.write(f"\033[1;34m{test_name}\033[0m\n")
            self.stream.write(f"    {test_doc} ... ")
            self.stream.flush()
            
    def addSuccess(self, test):
        super().addSuccess(test)
        if self.showAll:
            elapsed = time.time() - self.test_start_time
            self.stream.write("\033[1;32m✓ PASS\033[0m")
            self.stream.write(f" ({elapsed:.3f}s)\n")
        elif self.dots:
            self.stream.write("\033[1;32m.\033[0m")
            self.stream.flush()
            
    def addError(self, test, err):
        super().addError(test, err)
        if self.showAll:
            self.stream.write("\033[1;31m✗ ERROR\033[0m\n")
        elif self.dots:
            self.stream.write("\033[1;31mE\033[0m")
            self.stream.flush()
            
    def addFailure(self, test, err):
        super().addFailure(test, err)
        if self.showAll:
            self.stream.write("\033[1;33m✗ FAIL\033[0m\n")
        elif self.dots:
            self.stream.write("\033[1;33mF\033[0m")
            self.stream.flush()
            
    def addSkip(self, test, reason):
        super().addSkip(test, reason)
        if self.showAll:
            self.stream.write(f"\033[1;36m⊘ SKIP\033[0m: {reason}\n")
        elif self.dots:
            self.stream.write("\033[1;36ms\033[0m")
            self.stream.flush()


class ColoredTextTestRunner(unittest.TextTestRunner):
    """使用彩色輸出的測試執行器"""
    resultclass = ColoredTextTestResult
    
    def run(self, test):
        """執行測試並設置總測試數"""
        result = self._makeResult()
        result.total_tests = test.countTestCases()
        result.current_test_index = 0
        
        # 註冊結果觀察者
        unittest.registerResult(result)
        
        result.failfast = self.failfast
        result.buffer = self.buffer
        
        startTime = time.time()
        startTestRun = getattr(result, 'startTestRun', None)
        if startTestRun is not None:
            startTestRun()
        try:
            test(result)
        finally:
            stopTestRun = getattr(result, 'stopTestRun', None)
            if stopTestRun is not None:
                stopTestRun()
        stopTime = time.time()
        
        timeTaken = stopTime - startTime
        result.printErrors()
        
        if hasattr(result, 'separator2'):
            self.stream.writeln(result.separator2)
        
        return result


def print_banner(text, color="\033[1;36m"):
    """列印彩色橫幅"""
    width = 70
    print(f"\n{color}{'=' * width}")
    print(f"{text.center(width)}")
    print(f"{'=' * width}\033[0m\n")


def print_summary(result, elapsed_time):
    """列印測試摘要"""
    print_banner("測試結果摘要", "\033[1;35m")
    
    total = result.testsRun
    success = total - len(result.failures) - len(result.errors) - len(result.skipped)
    
    print(f"總測試數: {total}")
    print(f"\033[1;32m✓ 成功: {success}\033[0m")
    
    if result.failures:
        print(f"\033[1;33m✗ 失敗: {len(result.failures)}\033[0m")
    if result.errors:
        print(f"\033[1;31m✗ 錯誤: {len(result.errors)}\033[0m")
    if result.skipped:
        print(f"\033[1;36m⊘ 跳過: {len(result.skipped)}\033[0m")
        
    print(f"\n總耗時: {elapsed_time:.2f} 秒")
    print(f"成功率: {(success/total*100):.1f}%\n")
    
    return result.wasSuccessful()


def run_test_suite(suite, verbosity=2):
    """執行測試套件"""
    # 計算總測試數
    total_tests = suite.countTestCases()
    
    print(f"\033[1;36m準備執行 {total_tests} 個測試...\033[0m\n")
    
    runner = ColoredTextTestRunner(verbosity=verbosity)
    # 設置總測試數
    if hasattr(runner.resultclass, 'total_tests'):
        runner.resultclass.total_tests = total_tests
    
    start_time = time.time()
    result = runner.run(suite)
    
    # 設置總測試數到結果對象
    if hasattr(result, 'total_tests'):
        result.total_tests = total_tests
    else:
        result.current_test_index = 0
        result.total_tests = total_tests
    
    elapsed = time.time() - start_time
    
    return result, elapsed


def main():
    """主函數"""
    parser = argparse.ArgumentParser(
        description="執行 Git 自動化工具的測試套件",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
範例:
  python3 run_all_tests.py                    # 執行所有測試
  python3 run_all_tests.py --push             # 只測試 push 腳本
  python3 run_all_tests.py --pr               # 只測試 PR 腳本
  python3 run_all_tests.py --integration      # 只執行整合測試
  python3 run_all_tests.py --verbose          # 詳細輸出
  python3 run_all_tests.py --quick            # 快速測試
        """
    )
    
    parser.add_argument(
        "--push",
        action="store_true",
        help="只執行 git-auto-push.sh 測試"
    )
    parser.add_argument(
        "--pr",
        action="store_true",
        help="只執行 git-auto-pr.sh 測試"
    )
    parser.add_argument(
        "--integration",
        action="store_true",
        help="只執行整合測試"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="詳細輸出模式"
    )
    parser.add_argument(
        "--quick",
        action="store_true",
        help="快速測試模式（跳過耗時測試）"
    )
    parser.add_argument(
        "--failfast",
        action="store_true",
        help="遇到第一個失敗就停止"
    )
    
    args = parser.parse_args()
    
    # 決定詳細程度
    verbosity = 2 if args.verbose else 1
    
    # 建立測試套件
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # 根據參數決定要執行哪些測試
    if args.push:
        print_banner("執行 git-auto-push.sh 測試")
        suite.addTests(loader.loadTestsFromModule(test_git_auto_push))
    elif args.pr:
        print_banner("執行 git-auto-pr.sh 測試")
        suite.addTests(loader.loadTestsFromModule(test_git_auto_pr))
    elif args.integration:
        print_banner("執行整合測試")
        suite.addTests(loader.loadTestsFromModule(test_integration))
    else:
        print_banner("執行所有測試")
        print("\033[1;33m提示: 使用 --push, --pr, 或 --integration 只執行特定測試\033[0m\n")
        suite.addTests(loader.loadTestsFromModule(test_git_auto_push))
        suite.addTests(loader.loadTestsFromModule(test_git_auto_pr))
        suite.addTests(loader.loadTestsFromModule(test_integration))
    
    # 如果是快速模式，可以添加標記跳過某些測試
    if args.quick:
        print("\033[1;33m⚡ 快速測試模式：跳過耗時測試\033[0m\n")
    
    # 執行測試
    try:
        print("\033[1;32m▶ 開始執行測試...\033[0m")
        print("=" * 70)
        
        result, elapsed = run_test_suite(suite, verbosity)
        
        print("\n" + "=" * 70)
        print("\033[1;32m✓ 測試執行完成\033[0m\n")
        
        success = print_summary(result, elapsed)
        
        # 顯示失敗詳情
        if result.failures:
            print_banner("失敗詳情 (Failures)", "\033[1;33m")
            for i, (test, traceback) in enumerate(result.failures, 1):
                print(f"\033[1;33m失敗 #{i}: {test}\033[0m")
                print("-" * 70)
                print(traceback)
                print()
                
        if result.errors:
            print_banner("錯誤詳情 (Errors)", "\033[1;31m")
            for i, (test, traceback) in enumerate(result.errors, 1):
                print(f"\033[1;31m錯誤 #{i}: {test}\033[0m")
                print("-" * 70)
                print(traceback)
                print()
        
        # 提供建議
        if not success:
            print("\033[1;33m💡 提示:\033[0m")
            print("  - 使用 --verbose 查看更詳細的輸出")
            print("  - 使用 --failfast 在第一個錯誤時停止")
            print("  - 查看個別測試文件以了解測試內容")
            print()
        
        # 返回適當的退出碼
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\n\n\033[1;31m測試被中斷\033[0m")
        sys.exit(130)
    except Exception as e:
        print(f"\n\n\033[1;31m測試執行錯誤: {e}\033[0m")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
