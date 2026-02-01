---
name: syncProjectDocs
description: Synchronize documentation files with current codebase statistics and configurations.
argument-hint: List of documentation files to update (e.g., README.md, INSTALLATION.md, CHANGELOG.md)
---
Update and synchronize the specified documentation files to reflect the current state of the codebase.

## Tasks

1. **Gather Current Statistics**
   - Count lines of code for all main script files (`wc -l *.sh`)
   - Identify current version numbers and dates
   - Review current configuration options and default values
   - Check latest git commits for recent changes

2. **Version Update Management**
   - Determine if version bump is needed (major/minor/patch)
   - Update version number in all files (see checklist below)
   - Update version in CHANGELOG.md with new entry
   - Update version in README.md header and statistics section
   - Ensure version date reflects current date
   - Update total version count statistics

   **Version Update Checklist (所有需要更新版本號的位置)**:
   ```
   # 1. 主要腳本檔案標頭
   git-auto-push.sh:6   → # 作者：Lazy Jerry | 版本：vX.X.X | 授權：MIT License
   git-auto-pr.sh:6     → # 作者：Lazy Jerry | 版本：vX.X.X | 授權：MIT License
   
   # 2. README.md
   README.md:5          → 版本：vX.X.X
   README.md:621        → - 📅 **最新版本**：vX.X.X (YYYY-MM-DD)
   README.md:622        → - 📈 **總版本數**：N 個主要版本
   
   # 3. CHANGELOG.md
   CHANGELOG.md:7       → ### vX.X.X - 版本名稱 (YYYY-MM-DD) [新增條目]
   CHANGELOG.md:610     → - **最新版本**：vX.X.X (YYYY-MM-DD)
   CHANGELOG.md:611     → - **總版本數**：N 個主要版本
   
   # 4. copilot-instructions.md
   .github/copilot-instructions.md:173 → - 📅 **最新版本**：vX.X.X (YYYY-MM-DD)
   .github/copilot-instructions.md:174 → - 📈 **總版本數**：N 個主要版本
   .github/copilot-instructions.md:175 → - 📊 **程式碼行數**：[更新行數統計]
   ```

   **版本號更新順序**:
   1. 先執行 `wc -l *.sh` 取得最新行數
   2. 更新兩個主要腳本的檔案標頭 (git-auto-push.sh, git-auto-pr.sh)
   3. 更新 CHANGELOG.md（新增版本條目 + 統計區塊）
   4. 更新 README.md（標頭 + 更新日誌區塊）
   5. 更新 .github/copilot-instructions.md（範例區塊）

3. **Update Line Count Statistics**
   - Find all references to line counts in documentation
   - Update with accurate current values
   - Ensure consistency across all files (README, CHANGELOG, instruction files, etc.)

4. **Update CHANGELOG.md**
   - Add new version entry with current date
   - Document new features (🆕), improvements (🔧), and fixes (🐛)
   - Update line count statistics in the new entry
   - Update version statistics section at bottom

5. **Synchronize Configuration Documentation**
   - Verify configuration examples match actual code defaults
   - Update configuration option lists and descriptions
   - Ensure code snippets in docs reflect current implementation

6. **Cross-File Consistency**
   - Ensure version numbers are consistent across all files
   - Verify all file references and links are correct
   - Check that feature descriptions match between files

7. **Update Related Files**
   - Configuration example files (.env.example, etc.)
   - Developer instruction files (copilot-instructions.md, CONTRIBUTING.md, etc.)
   - Any files that reference the updated statistics or configurations

## Output
- List all files modified
- Summarize changes made to each file
- Note any inconsistencies found and resolved
