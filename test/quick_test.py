#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
快速測試執行器 - 帶詳細流程輸出

提供簡化的測試執行，專注於核心功能驗證，避免超時問題
"""

import sys
import subprocess
from pathlib import Path
import tempfile
import shutil

# 顏色定義
GREEN = '\033[1;32m'
RED = '\033[1;31m'
YELLOW = '\033[1;33m'
BLUE = '\033[1;34m'
CYAN = '\033[1;36m'
RESET = '\033[0m'


def print_section(title):
    """打印段落標題"""
    print(f"\n{CYAN}{'=' * 70}")
    print(f"{title.center(70)}")
    print(f"{'=' * 70}{RESET}\n")


def print_test(name, description):
    """打印測試名稱"""
    print(f"{BLUE}▶ 測試: {name}{RESET}")
    print(f"  描述: {description}")


def print_result(success, message=""):
    """打印測試結果"""
    if success:
        print(f"  {GREEN}✓ 通過{RESET} {message}\n")
    else:
        print(f"  {RED}✗ 失敗{RESET} {message}\n")


def run_cmd(cmd, cwd=None, timeout=10):
    """執行命令並返回結果"""
    try:
        env = {
            'LC_ALL': 'en_US.UTF-8',
            'LANG': 'en_US.UTF-8',
            'PATH': '/usr/local/bin:/usr/bin:/bin'
        }
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
            errors='replace'
        )
        return result
    except subprocess.TimeoutExpired:
        print(f"  {YELLOW}⚠ 超時（{timeout}秒）{RESET}")
        return None
    except Exception as e:
        print(f"  {RED}✗ 錯誤: {e}{RESET}")
        return None


def test_script_exists():
    """測試腳本檔案是否存在"""
    print_test("腳本檔案檢查", "檢查 git-auto-push.sh 和 git-auto-pr.sh 是否存在")
    
    base_dir = Path(__file__).parent.parent
    push_script = base_dir / "git-auto-push.sh"
    pr_script = base_dir / "git-auto-pr.sh"
    
    push_exists = push_script.exists()
    pr_exists = pr_script.exists()
    push_executable = push_script.is_file() and push_script.stat().st_mode & 0o111
    pr_executable = pr_script.is_file() and pr_script.stat().st_mode & 0o111
    
    if push_exists and pr_exists:
        print(f"    → git-auto-push.sh: {GREEN}存在{RESET} {'(可執行)' if push_executable else '(不可執行)'}")
        print(f"    → git-auto-pr.sh: {GREEN}存在{RESET} {'(可執行)' if pr_executable else '(不可執行)'}")
        print_result(True)
        return True
    else:
        print(f"    → git-auto-push.sh: {RED if not push_exists else GREEN}{'不存在' if not push_exists else '存在'}{RESET}")
        print(f"    → git-auto-pr.sh: {RED if not pr_exists else GREEN}{'不存在' if not pr_exists else '存在'}{RESET}")
        print_result(False)
        return False


def test_script_syntax():
    """測試腳本語法"""
    print_test("腳本語法檢查", "使用 bash -n 檢查腳本語法")
    
    base_dir = Path(__file__).parent.parent
    scripts = [
        base_dir / "git-auto-push.sh",
        base_dir / "git-auto-pr.sh"
    ]
    
    all_ok = True
    for script in scripts:
        result = run_cmd(['bash', '-n', str(script)])
        if result and result.returncode == 0:
            print(f"    → {script.name}: {GREEN}✓ 語法正確{RESET}")
        else:
            print(f"    → {script.name}: {RED}✗ 語法錯誤{RESET}")
            if result and result.stderr:
                print(f"       {result.stderr}")
            all_ok = False
    
    print_result(all_ok)
    return all_ok


def test_ai_tool_config():
    """測試 AI 工具配置"""
    print_test("AI 工具配置", "檢查 AI_TOOLS 配置是否存在")
    
    base_dir = Path(__file__).parent.parent
    push_script = base_dir / "git-auto-push.sh"
    pr_script = base_dir / "git-auto-pr.sh"
    
    try:
        push_content = push_script.read_text(encoding='utf-8')
        pr_content = pr_script.read_text(encoding='utf-8')
        
        push_has_config = 'AI_TOOLS=' in push_content
        pr_has_config = 'AI_TOOLS=' in pr_content
        
        print(f"    → git-auto-push.sh: {GREEN if push_has_config else RED}{'✓ 有 AI_TOOLS 配置' if push_has_config else '✗ 缺少 AI_TOOLS 配置'}{RESET}")
        print(f"    → git-auto-pr.sh: {GREEN if pr_has_config else RED}{'✓ 有 AI_TOOLS 配置' if pr_has_config else '✗ 缺少 AI_TOOLS 配置'}{RESET}")
        
        success = push_has_config and pr_has_config
        print_result(success)
        return success
    except Exception as e:
        print(f"    {RED}✗ 讀取檔案錯誤: {e}{RESET}")
        print_result(False)
        return False


def test_git_init():
    """測試 Git 初始化"""
    print_test("Git 倉庫初始化", "建立臨時 Git 倉庫並測試基本操作")
    
    temp_dir = tempfile.mkdtemp(prefix='git_test_')
    try:
        # 初始化 Git
        result = run_cmd(['git', 'init'], cwd=temp_dir)
        if not result or result.returncode != 0:
            print(f"    {RED}✗ Git init 失敗{RESET}")
            print_result(False)
            return False
        print(f"    → {GREEN}Git init 成功{RESET}")
        
        # 設置用戶
        run_cmd(['git', 'config', 'user.name', 'Test'], cwd=temp_dir)
        run_cmd(['git', 'config', 'user.email', 'test@test.com'], cwd=temp_dir)
        print(f"    → {GREEN}Git config 設置完成{RESET}")
        
        # 建立檔案
        test_file = Path(temp_dir) / 'test.txt'
        test_file.write_text('test content')
        print(f"    → {GREEN}建立測試檔案{RESET}")
        
        # Git add
        result = run_cmd(['git', 'add', '.'], cwd=temp_dir)
        if not result or result.returncode != 0:
            print(f"    {RED}✗ Git add 失敗{RESET}")
            print_result(False)
            return False
        print(f"    → {GREEN}Git add 成功{RESET}")
        
        # Git commit
        result = run_cmd(['git', 'commit', '-m', 'test commit'], cwd=temp_dir)
        if not result or result.returncode != 0:
            print(f"    {RED}✗ Git commit 失敗{RESET}")
            print_result(False)
            return False
        print(f"    → {GREEN}Git commit 成功{RESET}")
        
        print_result(True)
        return True
        
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def test_help_output():
    """測試幫助輸出"""
    print_test("幫助信息", "測試 --help 選項是否正常工作")
    
    base_dir = Path(__file__).parent.parent
    push_script = base_dir / "git-auto-push.sh"
    
    # 創建臨時 Git 倉庫
    temp_dir = tempfile.mkdtemp(prefix='git_test_')
    try:
        run_cmd(['git', 'init'], cwd=temp_dir, timeout=5)
        run_cmd(['git', 'config', 'user.name', 'Test'], cwd=temp_dir, timeout=5)
        run_cmd(['git', 'config', 'user.email', 'test@test.com'], cwd=temp_dir, timeout=5)
        
        result = run_cmd([str(push_script), '--help'], cwd=temp_dir, timeout=10)
        
        if result:
            output = result.stdout + result.stderr
            has_help = '使用' in output or 'usage' in output.lower() or 'help' in output.lower()
            
            if has_help:
                print(f"    → {GREEN}幫助信息正常輸出{RESET}")
                print_result(True)
                return True
            else:
                print(f"    → {YELLOW}未找到幫助信息關鍵字{RESET}")
                print_result(False, "(可能需要檢查輸出格式)")
                return False
        else:
            print_result(False, "(超時或執行失敗)")
            return False
            
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def main():
    """主函數"""
    print_section("Git 自動化工具 - 快速測試")
    
    print(f"{CYAN}執行快速測試以驗證核心功能...{RESET}\n")
    
    tests = [
        ("腳本檔案", test_script_exists),
        ("腳本語法", test_script_syntax),
        ("AI 配置", test_ai_tool_config),
        ("Git 操作", test_git_init),
        ("幫助信息", test_help_output),
    ]
    
    passed = 0
    failed = 0
    
    for name, test_func in tests:
        try:
            if test_func():
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"{RED}✗ 測試異常: {e}{RESET}\n")
            failed += 1
    
    # 總結
    print_section("測試總結")
    
    total = passed + failed
    print(f"總測試數: {total}")
    print(f"{GREEN}✓ 通過: {passed}{RESET}")
    if failed > 0:
        print(f"{RED}✗ 失敗: {failed}{RESET}")
    print(f"\n成功率: {(passed/total*100):.1f}%\n")
    
    if failed == 0:
        print(f"{GREEN}🎉 所有測試通過！{RESET}\n")
        return 0
    else:
        print(f"{YELLOW}⚠ 有 {failed} 個測試失敗{RESET}\n")
        print(f"{CYAN}提示: 使用完整測試套件進行詳細測試:{RESET}")
        print(f"  python3 test/run_all_tests.py --verbose\n")
        return 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(f"\n\n{YELLOW}測試被中斷{RESET}")
        sys.exit(130)
    except Exception as e:
        print(f"\n\n{RED}測試執行錯誤: {e}{RESET}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
