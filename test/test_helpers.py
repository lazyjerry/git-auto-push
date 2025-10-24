#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
測試輔助工具模組
提供共用的測試工具類和函數，用於設置測試環境、模擬 Git 操作等
"""

import os
import shutil
import tempfile
import subprocess
from pathlib import Path
from typing import Optional, Dict, List


class GitTestRepo:
    """
    Git 測試倉庫管理類
    
    功能：
    - 建立臨時 Git 倉庫
    - 模擬各種 Git 狀態
    - 執行 Git 命令
    - 清理測試環境
    """
    
    def __init__(self):
        """初始化測試倉庫"""
        self.temp_dir = tempfile.mkdtemp(prefix="git_test_")
        self.repo_path = Path(self.temp_dir)
        self._init_git_repo()
        
    def _init_git_repo(self):
        """初始化 Git 倉庫"""
        self._run_git_command("init")
        self._run_git_command("config", "user.name", "Test User")
        self._run_git_command("config", "user.email", "test@example.com")
        
    def _run_git_command(self, *args) -> subprocess.CompletedProcess:
        """
        執行 Git 命令
        
        參數：
            *args: Git 命令參數
            
        返回：
            subprocess.CompletedProcess 對象
        """
        cmd = ["git"] + list(args)
        env = os.environ.copy()
        env['LC_ALL'] = 'en_US.UTF-8'
        env['LANG'] = 'en_US.UTF-8'
        
        return subprocess.run(
            cmd,
            cwd=self.repo_path,
            capture_output=True,
            text=True,
            env=env,
            errors='replace'  # 處理無法解碼的字元
        )
        
    def create_file(self, filename: str, content: str = "test content"):
        """
        建立測試檔案
        
        參數：
            filename: 檔案名稱
            content: 檔案內容
        """
        file_path = self.repo_path / filename
        file_path.write_text(content, encoding="utf-8")
        
    def modify_file(self, filename: str, content: str):
        """
        修改現有檔案
        
        參數：
            filename: 檔案名稱
            content: 新的檔案內容
        """
        self.create_file(filename, content)
        
    def delete_file(self, filename: str):
        """
        刪除檔案
        
        參數：
            filename: 檔案名稱
        """
        file_path = self.repo_path / filename
        if file_path.exists():
            file_path.unlink()
            
    def add_files(self, *filenames):
        """
        將檔案加入暫存區
        
        參數：
            *filenames: 要加入的檔案名稱
        """
        if not filenames:
            self._run_git_command("add", ".")
        else:
            self._run_git_command("add", *filenames)
            
    def commit(self, message: str = "test commit"):
        """
        提交變更
        
        參數：
            message: commit 訊息
        """
        self._run_git_command("commit", "-m", message)
        
    def create_branch(self, branch_name: str):
        """
        建立新分支
        
        參數：
            branch_name: 分支名稱
        """
        self._run_git_command("checkout", "-b", branch_name)
        
    def checkout_branch(self, branch_name: str):
        """
        切換分支
        
        參數：
            branch_name: 分支名稱
        """
        self._run_git_command("checkout", branch_name)
        
    def add_remote(self, name: str = "origin", url: str = "https://github.com/test/test.git"):
        """
        添加遠端倉庫
        
        參數：
            name: 遠端名稱
            url: 遠端 URL
        """
        self._run_git_command("remote", "add", name, url)
        
    def get_current_branch(self) -> str:
        """
        獲取當前分支名稱
        
        返回：
            當前分支名稱
        """
        result = self._run_git_command("branch", "--show-current")
        return result.stdout.strip()
        
    def get_status(self) -> str:
        """
        獲取 Git 狀態
        
        返回：
            Git status 輸出
        """
        result = self._run_git_command("status", "--porcelain")
        return result.stdout
        
    def has_uncommitted_changes(self) -> bool:
        """
        檢查是否有未提交的變更
        
        返回：
            True 如果有未提交的變更，否則 False
        """
        return bool(self.get_status())
        
    def cleanup(self):
        """清理測試倉庫"""
        if self.temp_dir and os.path.exists(self.temp_dir):
            shutil.rmtree(self.temp_dir)
            

class MockAITool:
    """
    模擬 AI 工具類
    
    功能：
    - 模擬 codex, gemini, claude 等 AI 工具
    - 可配置返回內容和行為
    - 記錄調用歷史
    """
    
    def __init__(self, tool_name: str, responses: Optional[List[str]] = None):
        """
        初始化模擬 AI 工具
        
        參數：
            tool_name: 工具名稱 (codex, gemini, claude)
            responses: 預設回應列表，按順序返回
        """
        self.tool_name = tool_name
        self.responses = responses or [f"AI generated message by {tool_name}"]
        self.call_count = 0
        self.call_history: List[Dict] = []
        
    def __call__(self, *args, **kwargs) -> str:
        """
        模擬工具調用
        
        參數：
            *args: 位置參數
            **kwargs: 關鍵字參數
            
        返回：
            模擬的 AI 回應
        """
        self.call_history.append({
            'args': args,
            'kwargs': kwargs,
            'call_count': self.call_count
        })
        
        response_index = min(self.call_count, len(self.responses) - 1)
        response = self.responses[response_index]
        self.call_count += 1
        
        return response
        
    def reset(self):
        """重置調用記錄"""
        self.call_count = 0
        self.call_history.clear()
        

def create_mock_script(script_path: Path, mock_ai_tools: Dict[str, MockAITool]):
    """
    建立模擬 AI 工具的包裝腳本
    
    參數：
        script_path: 原始腳本路徑
        mock_ai_tools: AI 工具名稱到 MockAITool 的映射
    """
    # 建立 mock 工具的臨時目錄
    mock_dir = tempfile.mkdtemp(prefix="mock_ai_tools_")
    
    for tool_name, mock_tool in mock_ai_tools.items():
        mock_tool_path = Path(mock_dir) / tool_name
        
        # 建立模擬工具腳本
        mock_script = f"""#!/bin/bash
# Mock {tool_name} tool
echo "{mock_tool.responses[0]}"
exit 0
"""
        mock_tool_path.write_text(mock_script)
        mock_tool_path.chmod(0o755)
        
    return mock_dir


def run_script_with_input(
    script_path: Path,
    cwd: Path,
    input_text: Optional[str] = None,
    args: Optional[List[str]] = None,
    env: Optional[Dict[str, str]] = None,
    timeout: int = 30
) -> subprocess.CompletedProcess:
    """
    執行腳本並提供輸入
    
    參數：
        script_path: 腳本路徑
        cwd: 工作目錄
        input_text: 要輸入的文字
        args: 命令列參數
        env: 環境變數
        timeout: 超時時間（秒）
        
    返回：
        subprocess.CompletedProcess 對象
    """
    cmd = [str(script_path)]
    if args:
        cmd.extend(args)
        
    process_env = os.environ.copy()
    if env:
        process_env.update(env)
    
    # 設置語言環境為 UTF-8
    process_env['LC_ALL'] = 'en_US.UTF-8'
    process_env['LANG'] = 'en_US.UTF-8'
        
    return subprocess.run(
        cmd,
        cwd=cwd,
        input=input_text,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=process_env,
        errors='replace'  # 處理無法解碼的字元
    )


def assert_output_contains(output: str, expected_strings: List[str]):
    """
    斷言輸出包含預期的字串
    
    參數：
        output: 實際輸出
        expected_strings: 預期包含的字串列表
        
    拋出：
        AssertionError 如果任何預期字串不在輸出中
    """
    for expected in expected_strings:
        if expected not in output:
            raise AssertionError(
                f"Expected string not found in output:\n"
                f"Expected: {expected}\n"
                f"Output: {output[:500]}..."
            )


def assert_commit_message_format(message: str):
    """
    驗證 commit message 格式
    
    參數：
        message: commit 訊息
        
    拋出：
        AssertionError 如果格式不符合預期
    """
    # 基本檢查：不能為空
    assert message, "Commit message should not be empty"
    
    # 檢查長度（第一行應該簡潔）
    first_line = message.split('\n')[0]
    assert len(first_line) <= 100, f"First line too long: {len(first_line)} chars"
    
    # 檢查是否包含中文（根據專案要求）
    has_chinese = any('\u4e00' <= char <= '\u9fff' for char in message)
    assert has_chinese, "Commit message should contain Chinese characters"


def assert_pr_format(title: str, description: str):
    """
    驗證 PR 標題和描述格式
    
    參數：
        title: PR 標題
        description: PR 描述
        
    拋出：
        AssertionError 如果格式不符合預期
    """
    # 標題檢查
    assert title, "PR title should not be empty"
    assert len(title) <= 100, f"PR title too long: {len(title)} chars"
    
    # 描述檢查
    assert description, "PR description should not be empty"
    
    # 檢查是否包含中文
    has_chinese_title = any('\u4e00' <= char <= '\u9fff' for char in title)
    has_chinese_desc = any('\u4e00' <= char <= '\u9fff' for char in description)
    
    assert has_chinese_title or has_chinese_desc, \
        "PR title or description should contain Chinese characters"
