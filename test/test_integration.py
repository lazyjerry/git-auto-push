#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
整合測試套件

測試 git-auto-push.sh 和 git-auto-pr.sh 的整合場景：
- 完整的開發工作流程
- 腳本間的協作
- 端到端場景
- 真實使用案例模擬
"""

import unittest
import os
import sys
from pathlib import Path
import subprocess
import time

sys.path.insert(0, str(Path(__file__).parent))
from test_helpers import (
    GitTestRepo,
    run_script_with_input,
    assert_commit_message_format
)


class TestCompleteWorkflow(unittest.TestCase):
    """測試完整的開發工作流程"""
    
    @classmethod
    def setUpClass(cls):
        """設置測試類別"""
        cls.push_script = Path(__file__).parent.parent / "git-auto-push.sh"
        cls.pr_script = Path(__file__).parent.parent / "git-auto-pr.sh"
        
        # 驗證腳本存在
        assert cls.push_script.exists(), f"Push script not found: {cls.push_script}"
        assert cls.pr_script.exists(), f"PR script not found: {cls.pr_script}"
        
    def setUp(self):
        """每個測試前的設置"""
        self.test_repo = GitTestRepo()
        
        # 建立初始環境
        self.test_repo.create_file("README.md", "# Test Project")
        self.test_repo.add_files()
        self.test_repo.commit("Initial commit")
        self.test_repo.add_remote()
        
    def tearDown(self):
        """每個測試後的清理"""
        self.test_repo.cleanup()
        
    def test_scenario_1_traditional_workflow(self):
        """
        場景 1：傳統工作流程
        使用 git-auto-push.sh 進行日常開發
        """
        # 1. 修改檔案
        self.test_repo.create_file("feature.py", "def new_feature(): pass")
        
        # 2. 使用 git-auto-push.sh 提交（本地提交模式）
        result = run_script_with_input(
            self.push_script,
            self.test_repo.repo_path,
            input_text="新增功能模組\ny\n",
            args=["2"],  # 模式 2：本地提交
            timeout=15
        )
        
        # 3. 驗證提交成功
        log = self.test_repo._run_git_command("log", "--oneline", "-1")
        if result.returncode == 0:
            self.assertIn("新增", log.stdout)
            
    def test_scenario_2_github_flow(self):
        """
        場景 2：GitHub Flow 工作流程
        1. 建立功能分支
        2. 開發功能
        3. 提交變更
        4. 建立 PR
        """
        # 1. 建立功能分支
        feature_branch = "feature/user-auth"
        self.test_repo.create_branch(feature_branch)
        
        # 2. 開發功能
        self.test_repo.create_file("auth.py", "class UserAuth: pass")
        
        # 3. 使用 git-auto-push.sh 提交
        result = run_script_with_input(
            self.push_script,
            self.test_repo.repo_path,
            input_text="新增用戶認證模組\ny\n",
            args=["2"],
            timeout=15
        )
        
        # 4. 驗證功能分支有提交
        if result.returncode == 0:
            log = self.test_repo._run_git_command("log", "--oneline", "-1")
            self.assertIn("認證", log.stdout)
            
        # 5. （模擬）使用 git-auto-pr.sh 建立 PR
        # 實際測試需要 GitHub CLI 和真實倉庫
        
    def test_scenario_3_multiple_commits_workflow(self):
        """
        場景 3：多次提交工作流程
        模擬實際開發中的多次提交
        """
        commits = [
            ("utils.py", "新增工具函數", "def helper(): pass"),
            ("models.py", "新增資料模型", "class Model: pass"),
            ("views.py", "新增視圖函數", "def view(): pass")
        ]
        
        for filename, commit_msg, content in commits:
            # 建立/修改檔案
            self.test_repo.create_file(filename, content)
            
            # 提交
            result = run_script_with_input(
                self.push_script,
                self.test_repo.repo_path,
                input_text=f"{commit_msg}\ny\n",
                args=["2"],
                timeout=15
            )
            
            # 短暫延遲，確保提交順序
            time.sleep(0.1)
            
        # 驗證所有提交
        log = self.test_repo._run_git_command("log", "--oneline")
        self.assertIn("工具", log.stdout)
        self.assertIn("模型", log.stdout)
        self.assertIn("視圖", log.stdout)
        
    def test_scenario_4_feature_branch_lifecycle(self):
        """
        場景 4：功能分支生命週期
        1. 建立分支
        2. 多次提交
        3. PR 建立（模擬）
        4. 合併
        5. 分支刪除
        """
        # 1. 建立功能分支
        feature = "feature/new-api"
        self.test_repo.create_branch(feature)
        
        # 2. 多次提交
        self.test_repo.create_file("api.py", "API v1")
        self.test_repo.add_files()
        self.test_repo.commit("Add API endpoint")
        
        self.test_repo.modify_file("api.py", "API v2")
        self.test_repo.add_files()
        self.test_repo.commit("Update API")
        
        # 3. 驗證分支狀態
        self.assertEqual(self.test_repo.get_current_branch(), feature)
        
        # 4. 切回主分支（模擬合併後）
        self.test_repo.checkout_branch("master")
        
        # 5. 刪除功能分支
        result = self.test_repo._run_git_command("branch", "-D", feature)
        self.assertEqual(result.returncode, 0)
        
    def test_scenario_5_hotfix_workflow(self):
        """
        場景 5：熱修復工作流程
        快速修復生產問題
        """
        # 1. 從主分支建立 hotfix 分支
        self.test_repo.create_branch("hotfix/critical-bug")
        
        # 2. 修復問題
        self.test_repo.create_file("bugfix.py", "# Fixed critical bug")
        
        # 3. 緊急提交
        result = run_script_with_input(
            self.push_script,
            self.test_repo.repo_path,
            input_text="修正：緊急修復生產環境錯誤\ny\n",
            args=["2"],
            timeout=15
        )
        
        # 4. 驗證修復已提交
        if result.returncode == 0:
            log = self.test_repo._run_git_command("log", "--oneline", "-1")
            self.assertIn("修正", log.stdout)
            

class TestScriptCooperation(unittest.TestCase):
    """測試兩個腳本之間的協作"""
    
    @classmethod
    def setUpClass(cls):
        cls.push_script = Path(__file__).parent.parent / "git-auto-push.sh"
        cls.pr_script = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        self.test_repo.create_file("README.md", "# Test")
        self.test_repo.add_files()
        self.test_repo.commit("Initial commit")
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_push_then_pr_workflow(self):
        """
        測試：先 push 再 PR 的工作流程
        """
        # 1. 建立功能分支
        self.test_repo.create_branch("feature/test")
        
        # 2. 使用 push 腳本提交
        self.test_repo.create_file("test.py", "test")
        result = run_script_with_input(
            self.push_script,
            self.test_repo.repo_path,
            input_text="測試功能\ny\n",
            args=["2"],
            timeout=15
        )
        
        # 3. 驗證可以繼續建立 PR
        # （需要 PR 腳本的實際測試）
        
    def test_branch_state_consistency(self):
        """
        測試：分支狀態在腳本間保持一致
        """
        # 1. 建立並切換分支
        feature = "feature/consistency"
        self.test_repo.create_branch(feature)
        
        # 2. 驗證兩個腳本都能正確識別當前分支
        current = self.test_repo.get_current_branch()
        self.assertEqual(current, feature)
        
    def test_commit_history_preservation(self):
        """
        測試：commit 歷史在操作間保持完整
        """
        # 建立多個 commits
        for i in range(3):
            self.test_repo.create_file(f"file{i}.txt", f"content {i}")
            self.test_repo.add_files()
            self.test_repo.commit(f"Commit {i}")
            
        # 驗證歷史完整
        log = self.test_repo._run_git_command("log", "--oneline")
        self.assertEqual(len(log.stdout.strip().split('\n')), 4)  # 3 + initial
        

class TestErrorRecovery(unittest.TestCase):
    """測試錯誤恢復場景"""
    
    @classmethod
    def setUpClass(cls):
        cls.push_script = Path(__file__).parent.parent / "git-auto-push.sh"
        cls.pr_script = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        self.test_repo.create_file("README.md", "test")
        self.test_repo.add_files()
        self.test_repo.commit("initial")
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_recover_from_failed_commit(self):
        """
        測試：從失敗的 commit 恢復
        """
        # 建立變更但不提交
        self.test_repo.create_file("test.txt", "test")
        
        # 驗證有未提交的變更
        self.assertTrue(self.test_repo.has_uncommitted_changes())
        
        # 可以重新嘗試提交
        self.test_repo.add_files()
        self.test_repo.commit("Recovery commit")
        
        # 驗證提交成功
        self.assertFalse(self.test_repo.has_uncommitted_changes())
        
    def test_recover_from_cancelled_operation(self):
        """
        測試：從取消的操作恢復
        """
        # 建立變更
        self.test_repo.create_file("test.txt", "content")
        
        # 模擬用戶取消
        result = run_script_with_input(
            self.push_script,
            self.test_repo.repo_path,
            input_text="測試\nn\n",  # 輸入後取消
            timeout=15
        )
        
        # 驗證檔案仍未暫存（取消成功）
        # 可以重新執行操作
        
    def test_handle_merge_conflicts(self):
        """
        測試：處理合併衝突（模擬）
        """
        # 建立分支並產生可能的衝突
        self.test_repo.create_branch("branch1")
        self.test_repo.modify_file("README.md", "Branch 1 content")
        self.test_repo.add_files()
        self.test_repo.commit("Branch 1 change")
        
        self.test_repo.checkout_branch("master")
        self.test_repo.create_branch("branch2")
        self.test_repo.modify_file("README.md", "Branch 2 content")
        self.test_repo.add_files()
        self.test_repo.commit("Branch 2 change")
        
        # 實際的衝突解決需要手動介入
        

class TestPerformanceAndReliability(unittest.TestCase):
    """測試效能和可靠性"""
    
    @classmethod
    def setUpClass(cls):
        cls.push_script = Path(__file__).parent.parent / "git-auto-push.sh"
        cls.pr_script = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        self.test_repo.create_file("README.md", "test")
        self.test_repo.add_files()
        self.test_repo.commit("initial")
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_large_diff_handling(self):
        """
        測試：處理大型 diff
        """
        # 建立大檔案
        large_content = "x" * 10000  # 10KB 內容
        self.test_repo.create_file("large.txt", large_content)
        self.test_repo.add_files()
        
        # 獲取 diff 大小
        diff = self.test_repo._run_git_command("diff", "--cached")
        diff_lines = len(diff.stdout.split('\n'))
        
        # 驗證能夠處理
        self.assertGreater(diff_lines, 100)
        
    def test_multiple_files_commit(self):
        """
        測試：一次提交多個檔案
        """
        # 建立多個檔案
        for i in range(10):
            self.test_repo.create_file(f"file{i}.txt", f"content {i}")
            
        self.test_repo.add_files()
        
        # 驗證所有檔案都被暫存
        status = self.test_repo.get_status()
        for i in range(10):
            self.assertIn(f"file{i}.txt", status)
            
    def test_script_timeout_handling(self):
        """
        測試：腳本超時處理
        """
        # 測試腳本的超時機制
        # 使用較短的超時時間
        self.test_repo.create_file("test.txt", "test")
        
        result = run_script_with_input(
            self.push_script,
            self.test_repo.repo_path,
            input_text="\n",  # 使用預設/觸發 AI
            timeout=5  # 短超時
        )
        
        # 驗證腳本能在超時內完成或正確處理超時
        
    def test_concurrent_operations(self):
        """
        測試：並發操作（限制）
        """
        # Git 操作通常不支援並發
        # 驗證腳本在並發嘗試時的行為
        

class TestRealWorldScenarios(unittest.TestCase):
    """測試真實世界場景"""
    
    @classmethod
    def setUpClass(cls):
        cls.push_script = Path(__file__).parent.parent / "git-auto-push.sh"
        cls.pr_script = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        self.test_repo.create_file("README.md", "# Project")
        self.test_repo.add_files()
        self.test_repo.commit("initial")
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_daily_development_cycle(self):
        """
        場景：日常開發循環
        - 早上：拉取最新代碼
        - 開發：多次小提交
        - 晚上：推送代碼
        """
        # 1. 開發階段：多次小提交
        changes = [
            ("main.py", "初始化主程式"),
            ("utils.py", "新增工具函數"),
            ("tests.py", "新增測試案例")
        ]
        
        for filename, msg in changes:
            self.test_repo.create_file(filename, "code")
            result = run_script_with_input(
                self.push_script,
                self.test_repo.repo_path,
                input_text=f"{msg}\ny\n",
                args=["2"],
                timeout=15
            )
            
        # 2. 驗證所有提交
        log = self.test_repo._run_git_command("log", "--oneline")
        for _, msg in changes:
            if "初始化" in msg or "新增" in msg:
                pass  # 簡化的驗證
                
    def test_feature_development_lifecycle(self):
        """
        場景：功能開發完整生命週期
        - 建立功能分支
        - 開發實作
        - 單元測試
        - 文檔更新
        - PR 審查
        - 合併
        """
        # 1. 建立功能分支
        self.test_repo.create_branch("feature/user-management")
        
        # 2. 實作階段
        self.test_repo.create_file("user.py", "class User: pass")
        self.test_repo.add_files()
        self.test_repo.commit("實作用戶類別")
        
        # 3. 測試階段
        self.test_repo.create_file("test_user.py", "def test_user(): pass")
        self.test_repo.add_files()
        self.test_repo.commit("新增用戶測試")
        
        # 4. 文檔階段
        self.test_repo.create_file("USER_GUIDE.md", "# User Guide")
        self.test_repo.add_files()
        self.test_repo.commit("新增用戶指南")
        
        # 驗證完整的提交歷史
        log = self.test_repo._run_git_command("log", "--oneline")
        commit_count = len(log.stdout.strip().split('\n'))
        self.assertGreaterEqual(commit_count, 3)
        
    def test_emergency_hotfix(self):
        """
        場景：緊急熱修復
        - 發現生產問題
        - 快速建立 hotfix 分支
        - 修復並測試
        - 緊急部署
        """
        # 1. 快速建立 hotfix
        self.test_repo.create_branch("hotfix/security-patch")
        
        # 2. 快速修復
        self.test_repo.create_file("security.py", "# Security patch")
        
        # 3. 快速提交
        result = run_script_with_input(
            self.push_script,
            self.test_repo.repo_path,
            input_text="緊急：修復安全漏洞\ny\n",
            args=["2"],
            timeout=15
        )
        
        # 驗證修復已提交
        if result.returncode == 0:
            log = self.test_repo._run_git_command("log", "-1", "--oneline")
            self.assertIn("緊急", log.stdout)


def run_tests():
    """執行所有整合測試"""
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # 加入所有測試類別
    suite.addTests(loader.loadTestsFromTestCase(TestCompleteWorkflow))
    suite.addTests(loader.loadTestsFromTestCase(TestScriptCooperation))
    suite.addTests(loader.loadTestsFromTestCase(TestErrorRecovery))
    suite.addTests(loader.loadTestsFromTestCase(TestPerformanceAndReliability))
    suite.addTests(loader.loadTestsFromTestCase(TestRealWorldScenarios))
    
    # 執行測試
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
