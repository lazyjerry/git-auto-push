---
name: syncProjectDocs
description: Synchronize documentation files with current codebase statistics and configurations.
argument-hint: List of documentation files to update (e.g., README.md, INSTALLATION.md, CHANGELOG.md)
---
Update and synchronize the specified documentation files to reflect the current state of the codebase.

## Tasks

1. **Gather Current Statistics**
   - Count lines of code for all main script files
   - Identify current version numbers and dates
   - Review current configuration options and default values

2. **Update Line Count Statistics**
   - Find all references to line counts in documentation
   - Update with accurate current values
   - Ensure consistency across all files (README, CHANGELOG, instruction files, etc.)

3. **Synchronize Configuration Documentation**
   - Verify configuration examples match actual code defaults
   - Update configuration option lists and descriptions
   - Ensure code snippets in docs reflect current implementation

4. **Cross-File Consistency**
   - Ensure version numbers are consistent across all files
   - Verify all file references and links are correct
   - Check that feature descriptions match between files

5. **Update Related Files**
   - Configuration example files (.env.example, etc.)
   - Developer instruction files (copilot-instructions.md, CONTRIBUTING.md, etc.)
   - Any files that reference the updated statistics or configurations

## Output
- List all files modified
- Summarize changes made to each file
- Note any inconsistencies found and resolved
