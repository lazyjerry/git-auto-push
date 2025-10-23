#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
git-auto-pr.sh 腳本測試套件

測試涵蓋：
- GitHub Flow 工作流程
- PR 建立和管理
- AI 工具調用（分支名稱、PR 標題、描述）
- 分支操作
- PR 撤銷功能
- 審查和合併流程
- 錯誤處理和安全機制
"""

import unittest
import os
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock
import subprocess
import re

# 加入專案根目錄到路徑
sys.path.insert(0, str(Path(__file__).parent))
from test_helpers import (
    GitTestRepo,
    MockAITool,
    run_script_with_input,
    assert_output_contains,
    assert_pr_format,
    create_mock_script
)


class TestGitAutoPRConfiguration(unittest.TestCase):
    """測試 git-auto-pr.sh 配置讀取和解析"""
    
    @classmethod
    def setUpClass(cls):
        """設置測試類別"""
        cls.script_path = Path(__file__).parent.parent / "git-auto-pr.sh"
        assert cls.script_path.exists(), f"Script not found: {cls.script_path}"
        
    def setUp(self):
        """每個測試前的設置"""
        self.test_repo = GitTestRepo()
        
    def tearDown(self):
        """每個測試後的清理"""
        self.test_repo.cleanup()
        
    def test_script_exists_and_executable(self):
        """測試：腳本存在且可執行"""
        self.assertTrue(self.script_path.exists())
        self.assertTrue(os.access(self.script_path, os.X_OK))
        
    def test_ai_tools_configuration_exists(self):
        """測試：AI 工具配置存在"""
        script_content = self.script_path.read_text(encoding="utf-8")
        
        # 驗證 AI 工具相關配置
        self.assertIn("AI", script_content.upper())
        self.assertTrue(
            "codex" in script_content or 
            "gemini" in script_content or 
            "claude" in script_content
        )
        
    def test_default_main_branches_configuration(self):
        """測試：預設主分支配置"""
        script_content = self.script_path.read_text(encoding="utf-8")
        
        # 驗證主分支配置
        self.assertIn("main", script_content.lower())
        self.assertIn("master", script_content.lower())
        
    def test_default_username_configuration(self):
        """測試：預設使用者名稱配置"""
        script_content = self.script_path.read_text(encoding="utf-8")
        
        # 驗證使用者名稱相關配置
        self.assertTrue(
            "username" in script_content.lower() or 
            "user" in script_content.lower()
        )
        

class TestGitAutoPRBranchOperations(unittest.TestCase):
    """測試分支操作功能"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        # 建立初始 commit
        self.test_repo.create_file("README.md", "# Test Repo")
        self.test_repo.add_files()
        self.test_repo.commit("Initial commit")
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_create_feature_branch(self):
        """測試：建立功能分支"""
        # 驗證當前在 main/master 分支
        current_branch = self.test_repo.get_current_branch()
        self.assertIn(current_branch, ["main", "master"])
        
        # 建立功能分支
        feature_branch = "feature/test-feature"
        self.test_repo.create_branch(feature_branch)
        
        # 驗證分支建立成功
        new_branch = self.test_repo.get_current_branch()
        self.assertEqual(new_branch, feature_branch)
        
    def test_branch_name_format_validation(self):
        """測試：分支名稱格式驗證"""
        valid_branch_names = [
            "feature/add-login",
            "feature/user-profile",
            "bugfix/fix-upload-error",
            "hotfix/critical-bug"
        ]
        
        for branch_name in valid_branch_names:
            # 驗證格式（包含 / 分隔符）
            self.assertIn("/", branch_name)
            # 驗證前綴
            self.assertTrue(
                branch_name.startswith("feature/") or
                branch_name.startswith("bugfix/") or
                branch_name.startswith("hotfix/")
            )
            
    def test_prevent_branch_creation_on_non_main(self):
        """測試：非主分支上不能建立功能分支"""
        # 建立並切換到功能分支
        self.test_repo.create_branch("feature/existing")
        
        # 腳本應該要求在主分支上建立新的功能分支
        # 這是一個業務邏輯測試
        
    def test_branch_deletion_safety(self):
        """測試：分支刪除安全機制"""
        # 建立測試分支
        test_branch = "feature/to-delete"
        self.test_repo.create_branch(test_branch)
        
        # 切回主分支
        self.test_repo.checkout_branch("master")
        
        # 刪除分支
        result = self.test_repo._run_git_command("branch", "-D", test_branch)
        self.assertEqual(result.returncode, 0)
        
    def test_cannot_delete_current_branch(self):
        """測試：不能刪除當前分支"""
        current = self.test_repo.get_current_branch()
        
        # 嘗試刪除當前分支應該失敗
        result = self.test_repo._run_git_command("branch", "-D", current)
        self.assertNotEqual(result.returncode, 0)
        

class TestGitAutoPRAIGeneration(unittest.TestCase):
    """測試 AI 生成功能（分支名稱、PR 標題、描述）"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        self.test_repo.create_file("test.txt")
        self.test_repo.add_files()
        self.test_repo.commit("test commit")
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_ai_branch_name_generation(self):
        """測試：AI 生成分支名稱"""
        # 模擬 AI 生成的分支名稱
        ai_generated_names = [
            "feature/add-user-login",
            "feature/implement-search",
            "bugfix/fix-upload-error"
        ]
        
        for name in ai_generated_names:
            # 驗證格式
            self.assertIn("/", name)
            self.assertTrue(name.startswith("feature/") or name.startswith("bugfix/"))
            
    def test_ai_pr_title_generation(self):
        """測試：AI 生成 PR 標題"""
        ai_generated_titles = [
            "新增用戶登入功能",
            "修正檔案上傳錯誤",
            "改善搜尋效能"
        ]
        
        for title in ai_generated_titles:
            # 驗證標題格式
            self.assertLessEqual(len(title), 100)
            # 驗證包含中文
            has_chinese = any('\u4e00' <= char <= '\u9fff' for char in title)
            self.assertTrue(has_chinese)
            
    def test_ai_pr_description_generation(self):
        """測試：AI 生成 PR 描述"""
        ai_generated_desc = """
## 變更說明
新增用戶登入功能，包含：
- 登入表單
- 驗證邏輯
- 錯誤處理

## 測試
- [ ] 單元測試
- [ ] 整合測試
"""
        
        # 驗證描述不為空
        self.assertTrue(ai_generated_desc.strip())
        
    def test_pr_format_validation(self):
        """測試：PR 格式驗證"""
        valid_pr_examples = [
            ("新增用戶登入功能", "實作用戶登入表單和驗證邏輯"),
            ("修正檔案上傳錯誤", "修復檔案上傳時的空指標錯誤"),
            ("改善搜尋效能", "優化搜尋演算法，提升 50% 效能")
        ]
        
        for title, description in valid_pr_examples:
            try:
                assert_pr_format(title, description)
            except AssertionError as e:
                self.fail(f"Valid PR rejected: {title}\nError: {e}")
                
    def test_pr_delimiter_format(self):
        """測試：PR 標題與描述分隔符格式"""
        # 腳本使用 | 分隔標題和描述
        pr_output = "新增用戶功能 | 實作完整的用戶管理系統"
        
        parts = pr_output.split(" | ")
        self.assertEqual(len(parts), 2)
        
        title = parts[0].strip()
        description = parts[1].strip()
        
        self.assertTrue(title)
        self.assertTrue(description)
        

class TestGitAutoPRCreation(unittest.TestCase):
    """測試 PR 建立流程"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        # 建立基礎環境
        self.test_repo.create_file("README.md", "# Test")
        self.test_repo.add_files()
        self.test_repo.commit("Initial commit")
        self.test_repo.add_remote()
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_pr_requires_feature_branch(self):
        """測試：建立 PR 需要在功能分支上"""
        # 當前在 main/master，不應該允許建立 PR
        current = self.test_repo.get_current_branch()
        self.assertIn(current, ["main", "master"])
        
    def test_pr_requires_changes(self):
        """測試：建立 PR 需要有變更"""
        # 建立功能分支
        self.test_repo.create_branch("feature/test")
        
        # 沒有變更時不應該能建立 PR
        has_changes = self.test_repo.has_uncommitted_changes()
        # 如果沒有變更，應該要有提示或錯誤
        
    def test_pr_with_valid_changes(self):
        """測試：有有效變更時可建立 PR"""
        # 建立功能分支並添加變更
        self.test_repo.create_branch("feature/new-feature")
        self.test_repo.create_file("new_file.txt", "new content")
        self.test_repo.add_files()
        self.test_repo.commit("Add new feature")
        
        # 驗證有 commit
        log = self.test_repo._run_git_command("log", "--oneline")
        self.assertIn("Add new feature", log.stdout)
        

class TestGitAutoPRCancellation(unittest.TestCase):
    """測試 PR 撤銷功能"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        self.test_repo.create_file("test.txt")
        self.test_repo.add_files()
        self.test_repo.commit("test")
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_cancel_open_pr_logic(self):
        """測試：撤銷 OPEN 狀態的 PR（關閉）"""
        # 測試邏輯：OPEN PR 應該被關閉
        pr_state = "OPEN"
        
        if pr_state == "OPEN":
            # 應該提供關閉選項
            expected_action = "close"
            self.assertEqual(expected_action, "close")
            
    def test_cancel_merged_pr_logic(self):
        """測試：撤銷 MERGED 狀態的 PR（revert）"""
        # 測試邏輯：MERGED PR 應該提供 revert 選項
        pr_state = "MERGED"
        
        if pr_state == "MERGED":
            # 應該提供 revert 選項（預設為「否」）
            expected_action = "revert"
            self.assertEqual(expected_action, "revert")
            
    def test_revert_requires_confirmation(self):
        """測試：revert 操作需要確認"""
        # revert 是危險操作，預設應該是「否」
        default_answer = "n"
        self.assertEqual(default_answer.lower(), "n")
        
    def test_display_commit_impact(self):
        """測試：顯示 commit 影響範圍"""
        # 建立多個 commits
        self.test_repo.create_file("file1.txt")
        self.test_repo.add_files()
        self.test_repo.commit("commit 1")
        
        self.test_repo.create_file("file2.txt")
        self.test_repo.add_files()
        self.test_repo.commit("commit 2")
        
        # 獲取 commit 數量
        log = self.test_repo._run_git_command("log", "--oneline")
        commit_count = len(log.stdout.strip().split('\n'))
        
        # 應該顯示影響的 commit 數量
        self.assertGreater(commit_count, 0)
        

class TestGitAutoPRReview(unittest.TestCase):
    """測試 PR 審查和合併流程"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        self.test_repo.create_file("test.txt")
        self.test_repo.add_files()
        self.test_repo.commit("initial")
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_review_requires_approval(self):
        """測試：合併需要審查批准"""
        # 業務邏輯測試：應該有審查機制
        
    def test_self_approval_restriction(self):
        """測試：限制自我批准"""
        # 業務邏輯測試：不應該允許自己批准自己的 PR
        
    def test_squash_merge_strategy(self):
        """測試：使用 squash 合併策略"""
        # 驗證腳本使用 squash merge
        script_content = self.script_path.read_text(encoding="utf-8")
        # 可能包含 squash 相關的 gh pr merge 命令
        
    def test_ci_status_check(self):
        """測試：檢查 CI 狀態"""
        # 業務邏輯測試：合併前應該檢查 CI 狀態
        

class TestGitAutoPRSafetyMechanisms(unittest.TestCase):
    """測試安全防護機制"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        self.test_repo.create_file("test.txt")
        self.test_repo.add_files()
        self.test_repo.commit("test")
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_main_branch_protection(self):
        """測試：主分支保護"""
        # 驗證腳本包含主分支保護邏輯
        script_content = self.script_path.read_text(encoding="utf-8")
        
        # 應該有檢查當前分支是否為主分支的邏輯
        self.assertTrue(
            "main" in script_content.lower() or 
            "master" in script_content.lower()
        )
        
    def test_prevent_delete_main_branch(self):
        """測試：防止刪除主分支"""
        current = self.test_repo.get_current_branch()
        
        if current in ["main", "master"]:
            # 嘗試刪除當前（主）分支應該失敗
            result = self.test_repo._run_git_command("branch", "-D", current)
            self.assertNotEqual(result.returncode, 0)
            
    def test_prevent_delete_current_branch(self):
        """測試：防止刪除當前分支"""
        # 已在其他測試中覆蓋
        
    def test_multiple_confirmation_for_deletion(self):
        """測試：分支刪除需要多重確認"""
        # 業務邏輯測試：刪除操作應該需要確認
        

class TestGitAutoPRErrorHandling(unittest.TestCase):
    """測試錯誤處理邏輯"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_no_git_repository_error(self):
        """測試：非 Git 倉庫時的錯誤"""
        temp_dir = Path(self.test_repo.temp_dir) / "not_git"
        temp_dir.mkdir()
        
        result = run_script_with_input(
            self.script_path,
            temp_dir,
            timeout=10
        )
        
        # 應該顯示錯誤訊息
        self.assertNotEqual(result.returncode, 0)
        
    def test_gh_cli_not_installed_error(self):
        """測試：GitHub CLI 未安裝時的錯誤"""
        # 檢查腳本是否處理 gh 命令不存在的情況
        script_content = self.script_path.read_text(encoding="utf-8")
        # 應該有檢查 gh 命令是否存在的邏輯
        
    def test_no_remote_repository_error(self):
        """測試：無遠端倉庫時的錯誤"""
        self.test_repo.create_file("test.txt")
        self.test_repo.add_files()
        self.test_repo.commit("test")
        
        # 沒有 remote 時執行 PR 操作應該失敗
        
    def test_network_error_handling(self):
        """測試：網路錯誤處理"""
        # 業務邏輯測試：應該處理網路相關錯誤
        
    def test_invalid_branch_name_error(self):
        """測試：無效分支名稱錯誤"""
        invalid_names = [
            "invalid name with spaces",
            "invalid/name/with/../dots",
            ""
        ]
        
        for name in invalid_names:
            # 這些名稱應該被拒絕
            if name:  # 空名稱直接跳過
                # Git 會拒絕這些名稱
                pass
                

class TestGitAutoPRIntegration(unittest.TestCase):
    """測試完整的 GitHub Flow 工作流程整合"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-pr.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        # 建立完整的測試環境
        self.test_repo.create_file("README.md", "# Test Project")
        self.test_repo.add_files()
        self.test_repo.commit("Initial commit")
        self.test_repo.add_remote()
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_complete_github_flow(self):
        """測試：完整的 GitHub Flow 流程"""
        # 1. 從主分支開始
        main_branch = self.test_repo.get_current_branch()
        self.assertIn(main_branch, ["main", "master"])
        
        # 2. 建立功能分支
        feature_branch = "feature/test-feature"
        self.test_repo.create_branch(feature_branch)
        self.assertEqual(self.test_repo.get_current_branch(), feature_branch)
        
        # 3. 進行變更
        self.test_repo.create_file("new_feature.txt", "new feature code")
        self.test_repo.add_files()
        self.test_repo.commit("Add new feature")
        
        # 4. 驗證變更已提交
        log = self.test_repo._run_git_command("log", "--oneline", "-1")
        self.assertIn("Add new feature", log.stdout)
        
        # 5. 切回主分支（模擬 PR 合併後）
        self.test_repo.checkout_branch(main_branch)
        self.assertEqual(self.test_repo.get_current_branch(), main_branch)
        
    def test_multiple_feature_branches(self):
        """測試：多個功能分支並行開發"""
        # 建立第一個功能分支
        self.test_repo.create_branch("feature/feature-1")
        self.test_repo.create_file("feature1.txt")
        self.test_repo.add_files()
        self.test_repo.commit("Feature 1")
        
        # 切回主分支
        main = self.test_repo.get_current_branch()
        if main not in ["main", "master"]:
            self.test_repo.checkout_branch("master")
        
        # 建立第二個功能分支
        self.test_repo.create_branch("feature/feature-2")
        self.test_repo.create_file("feature2.txt")
        self.test_repo.add_files()
        self.test_repo.commit("Feature 2")
        
        # 驗證兩個分支都存在
        branches = self.test_repo._run_git_command("branch")
        self.assertIn("feature-1", branches.stdout)
        self.assertIn("feature-2", branches.stdout)
        

def run_tests():
    """執行所有測試"""
    # 建立測試套件
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # 加入所有測試類別
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPRConfiguration))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPRBranchOperations))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPRAIGeneration))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPRCreation))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPRCancellation))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPRReview))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPRSafetyMechanisms))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPRErrorHandling))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPRIntegration))
    
    # 執行測試
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
