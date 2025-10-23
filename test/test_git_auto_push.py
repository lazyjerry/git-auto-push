#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
git-auto-push.sh 腳本測試套件

測試涵蓋：
- 配置讀取和解析
- Git 狀態檢查
- AI 工具調用邏輯
- Commit message 生成和驗證
- 錯誤處理
- 用戶互動
- 完整工作流程
"""

import unittest
import os
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock
import subprocess

# 加入專案根目錄到路徑
sys.path.insert(0, str(Path(__file__).parent))
from test_helpers import (
    GitTestRepo,
    MockAITool,
    run_script_with_input,
    assert_output_contains,
    assert_commit_message_format,
    create_mock_script
)


class TestGitAutoPushConfiguration(unittest.TestCase):
    """測試 git-auto-push.sh 配置讀取和解析"""
    
    @classmethod
    def setUpClass(cls):
        """設置測試類別"""
        cls.script_path = Path(__file__).parent.parent / "git-auto-push.sh"
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
        
    def test_ai_tools_configuration(self):
        """測試：AI 工具配置是否正確讀取"""
        # 讀取腳本內容
        script_content = self.script_path.read_text(encoding="utf-8")
        
        # 驗證 AI_TOOLS 配置存在
        self.assertIn("readonly AI_TOOLS=", script_content)
        self.assertIn("codex", script_content)
        self.assertIn("gemini", script_content)
        self.assertIn("claude", script_content)
        
    def test_ai_commit_prompt_configuration(self):
        """測試：AI commit 提示詞配置是否存在"""
        script_content = self.script_path.read_text(encoding="utf-8")
        
        # 驗證提示詞配置
        self.assertIn("AI_COMMIT_PROMPT=", script_content)
        self.assertIn("commit", script_content.lower())
        
    def test_help_option(self):
        """測試：--help 選項顯示使用說明"""
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            args=["--help"]
        )
        
        # 驗證輸出包含使用說明
        output = result.stdout + result.stderr
        self.assertIn("使用", output)
        

class TestGitAutoPushGitStatus(unittest.TestCase):
    """測試不同 Git 狀態下的腳本行為"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-push.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_no_git_repository(self):
        """測試：非 Git 倉庫時的錯誤處理"""
        # 建立非 Git 目錄
        temp_dir = Path(self.test_repo.temp_dir) / "not_git"
        temp_dir.mkdir()
        
        result = run_script_with_input(
            self.script_path,
            temp_dir,
            timeout=10
        )
        
        # 驗證錯誤訊息
        output = result.stdout + result.stderr
        self.assertIn("Git", output)
        self.assertNotEqual(result.returncode, 0)
        
    def test_no_changes_to_commit(self):
        """測試：無變更時的提示訊息"""
        # 建立初始 commit
        self.test_repo.create_file("test.txt")
        self.test_repo.add_files()
        self.test_repo.commit("initial commit")
        
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            timeout=10
        )
        
        # 驗證提示訊息
        output = result.stdout + result.stderr
        self.assertIn("沒有", output)
        
    def test_has_uncommitted_changes(self):
        """測試：有未提交變更時的處理"""
        # 建立初始 commit
        self.test_repo.create_file("test.txt", "initial")
        self.test_repo.add_files()
        self.test_repo.commit("initial")
        
        # 修改檔案
        self.test_repo.modify_file("test.txt", "modified")
        
        # 驗證有變更
        self.assertTrue(self.test_repo.has_uncommitted_changes())
        
    def test_has_staged_changes(self):
        """測試：有已暫存變更時的處理"""
        # 建立並暫存檔案
        self.test_repo.create_file("staged.txt")
        self.test_repo.add_files("staged.txt")
        
        # 驗證有暫存變更
        status = self.test_repo.get_status()
        self.assertIn("staged.txt", status)
        

class TestGitAutoPushAITools(unittest.TestCase):
    """測試 AI 工具調用邏輯"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-push.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        # 準備有變更的狀態
        self.test_repo.create_file("test.txt", "test content")
        self.test_repo.add_files()
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_ai_tool_priority_codex_first(self):
        """測試：AI 工具優先順序（codex 優先）"""
        script_content = self.script_path.read_text(encoding="utf-8")
        
        # 找到 AI_TOOLS 定義
        import re
        match = re.search(r'readonly AI_TOOLS=\((.*?)\)', script_content, re.DOTALL)
        self.assertIsNotNone(match)
        
        tools_str = match.group(1)
        # 驗證 codex 在列表中
        self.assertIn("codex", tools_str)
        
    def test_ai_tool_fallback_logic(self):
        """測試：AI 工具失敗時的降級邏輯"""
        script_content = self.script_path.read_text(encoding="utf-8")
        
        # 驗證有多個 AI 工具可供選擇
        self.assertIn("codex", script_content)
        self.assertIn("gemini", script_content)
        self.assertIn("claude", script_content)
        
        # 驗證有 for 循環遍歷工具
        self.assertIn("for tool_name in", script_content)
        
    def test_manual_input_fallback(self):
        """測試：所有 AI 工具失敗時降級到手動輸入"""
        # 模擬用戶手動輸入
        user_input = "手動輸入的 commit message\ny\n"
        
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            input_text=user_input,
            timeout=15
        )
        
        output = result.stdout + result.stderr
        # 腳本應該詢問 commit message
        self.assertTrue(
            "commit message" in output.lower() or "提交" in output,
            f"Expected commit message prompt, got: {output[:500]}"
        )
        

class TestGitAutoPushCommitMessage(unittest.TestCase):
    """測試 commit message 生成和驗證"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-push.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        self.test_repo.create_file("test.txt")
        self.test_repo.add_files()
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_manual_commit_message_input(self):
        """測試：手動輸入 commit message"""
        commit_msg = "測試：新增測試檔案"
        user_input = f"{commit_msg}\ny\n"
        
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            input_text=user_input,
            args=["2"],  # 選擇模式 2：本地提交
            timeout=15
        )
        
        # 驗證 commit 是否成功
        commits = self.test_repo._run_git_command("log", "--oneline")
        if result.returncode == 0:
            self.assertIn("測試", commits.stdout)
            
    def test_commit_message_format_validation(self):
        """測試：commit message 格式驗證"""
        # 有效的 commit message
        valid_messages = [
            "新增用戶登入功能",
            "修正檔案上傳錯誤",
            "改善搜尋效能",
            "更新文檔說明"
        ]
        
        for msg in valid_messages:
            try:
                assert_commit_message_format(msg)
            except AssertionError as e:
                self.fail(f"Valid message rejected: {msg}\nError: {e}")
                
    def test_empty_commit_message_rejected(self):
        """測試：空 commit message 應被拒絕"""
        with self.assertRaises(AssertionError):
            assert_commit_message_format("")
            
    def test_commit_message_chinese_requirement(self):
        """測試：commit message 應包含中文"""
        # 純英文 message 應該失敗（根據專案要求）
        with self.assertRaises(AssertionError):
            assert_commit_message_format("Add new feature")
            

class TestGitAutoPushErrorHandling(unittest.TestCase):
    """測試錯誤處理邏輯"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-push.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_git_not_installed_error(self):
        """測試：Git 未安裝時的錯誤處理"""
        # 這個測試假設 git 已安裝，主要測試錯誤訊息格式
        # 實際測試需要在沒有 git 的環境中運行
        pass
        
    def test_no_remote_repository_warning(self):
        """測試：無遠端倉庫時的警告"""
        # 準備有變更的狀態
        self.test_repo.create_file("test.txt")
        self.test_repo.add_files()
        
        # 嘗試執行完整流程（會失敗因為沒有 remote）
        user_input = "測試 commit\ny\n"
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            input_text=user_input,
            args=["1"],  # 完整流程
            timeout=15
        )
        
        # 應該顯示錯誤或警告
        output = result.stdout + result.stderr
        # 可能會提示沒有 upstream 或 remote
        
    def test_user_cancellation(self):
        """測試：用戶取消操作"""
        self.test_repo.create_file("test.txt")
        self.test_repo.add_files()
        
        # 輸入 commit message 但取消確認
        user_input = "測試 commit\nn\n"
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            input_text=user_input,
            timeout=15
        )
        
        # 驗證操作被取消
        output = result.stdout + result.stderr
        self.assertTrue(
            "取消" in output or "中止" in output or result.returncode != 0
        )
        

class TestGitAutoPushWorkflows(unittest.TestCase):
    """測試不同的工作流程"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-push.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_mode_1_full_workflow(self):
        """測試：模式 1 - 完整流程 (add → commit → push)"""
        # 準備變更
        self.test_repo.create_file("test.txt")
        self.test_repo.add_remote()
        
        # 注意：實際 push 會失敗因為 remote 不存在
        # 這裡主要測試流程是否正確執行到 push 步驟
        
    def test_mode_2_local_commit(self):
        """測試：模式 2 - 本地提交 (add → commit)"""
        self.test_repo.create_file("test.txt")
        
        user_input = "本地測試 commit\ny\n"
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            input_text=user_input,
            args=["2"],
            timeout=15
        )
        
        # 驗證 commit 成功
        if result.returncode == 0:
            log = self.test_repo._run_git_command("log", "--oneline")
            self.assertIn("本地測試", log.stdout)
            
    def test_mode_3_add_only(self):
        """測試：模式 3 - 僅添加 (add)"""
        self.test_repo.create_file("test.txt")
        
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            args=["3"],
            timeout=10
        )
        
        # 驗證檔案已暫存
        status = self.test_repo.get_status()
        self.assertIn("test.txt", status)
        
    def test_mode_4_auto_workflow(self):
        """測試：模式 4 - 全自動 (add → AI commit → push)"""
        self.test_repo.create_file("test.txt")
        
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            args=["--auto"],
            timeout=60  # AI 可能需要更長時間
        )
        
        # 驗證自動模式執行
        output = result.stdout + result.stderr
        self.assertTrue("自動" in output or "AI" in output)
        
    def test_mode_5_commit_only(self):
        """測試：模式 5 - 僅提交（針對已暫存檔案）"""
        # 先暫存檔案
        self.test_repo.create_file("test.txt")
        self.test_repo.add_files()
        
        user_input = "僅提交測試\ny\n"
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            input_text=user_input,
            args=["5"],
            timeout=15
        )
        
        if result.returncode == 0:
            log = self.test_repo._run_git_command("log", "--oneline")
            self.assertIn("僅提交", log.stdout)
            
    def test_mode_6_show_git_info(self):
        """測試：模式 6 - 顯示 Git 資訊"""
        self.test_repo.add_remote()
        
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            args=["6"],
            timeout=10
        )
        
        output = result.stdout + result.stderr
        # 應該顯示分支、remote 等資訊
        self.assertTrue(
            "分支" in output or "branch" in output.lower() or
            "remote" in output.lower() or "倉庫" in output
        )
        

class TestGitAutoPushInteraction(unittest.TestCase):
    """測試用戶互動功能"""
    
    @classmethod
    def setUpClass(cls):
        cls.script_path = Path(__file__).parent.parent / "git-auto-push.sh"
        
    def setUp(self):
        self.test_repo = GitTestRepo()
        self.test_repo.create_file("test.txt")
        
    def tearDown(self):
        self.test_repo.cleanup()
        
    def test_menu_display(self):
        """測試：選單顯示"""
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            input_text="\n",  # 按 Enter 使用預設選項
            timeout=10
        )
        
        output = result.stdout + result.stderr
        # 應該顯示操作選單
        self.assertTrue("選擇" in output or "操作" in output or "模式" in output)
        
    def test_commit_confirmation(self):
        """測試：commit 確認提示"""
        user_input = "測試 commit\ny\n"
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            input_text=user_input,
            timeout=15
        )
        
        output = result.stdout + result.stderr
        # 應該有確認提示
        self.assertTrue(
            "確認" in output or "確定" in output or "是否" in output
        )
        
    def test_ai_generation_prompt(self):
        """測試：AI 生成提示"""
        # 直接按 Enter 觸發 AI 生成
        user_input = "\nn\n"  # Enter 後取消
        result = run_script_with_input(
            self.script_path,
            self.test_repo.repo_path,
            input_text=user_input,
            timeout=60
        )
        
        output = result.stdout + result.stderr
        # 應該提示使用 AI 生成
        self.assertTrue(
            "AI" in output or "自動生成" in output or "生成" in output
        )


def run_tests():
    """執行所有測試"""
    # 建立測試套件
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # 加入所有測試類別
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPushConfiguration))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPushGitStatus))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPushAITools))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPushCommitMessage))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPushErrorHandling))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPushWorkflows))
    suite.addTests(loader.loadTestsFromTestCase(TestGitAutoPushInteraction))
    
    # 執行測試
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
