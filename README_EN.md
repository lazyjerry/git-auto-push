🌐 English | [简体中文](README_CN.md) | [繁體中文](README.md) | [日本語](README_JP.md) | [한국어](README_KR.md)

---

# Git Workflow Automation Toolkit

Two Bash scripts that handle traditional Git operations (add/commit/push) and GitHub Flow PR workflows respectively. Supports multiple AI CLI tools for generating commit messages and PR content, along with Conventional Commits prefixes, message quality checks, issue key auto-insertion, and more.

Version: v2.8.0

## Project Overview

### Key Features

- Traditional Git workflow automation (add, commit, push)
- Conventional Commits prefix support (manual selection or AI auto-detection)
- Direct command-line execution (`./git-auto-push.sh 1-7` to skip the menu)
- Git repository info display (branch status, remotes, sync status, commit history)
- Commit message amendment (safely amend the last commit, with issue key support)
- Commit message quality check (AI-powered quality analysis, configurable auto or prompt mode)
- GitHub Flow PR workflow (from branch creation to PR creation)
- PR lifecycle management (create, cancel, review, merge)
- Branch management (safe deletion, main branch protection, multi-step confirmation)
- AI-generated commit messages, branch names, and PR content
- Multi-AI tool failover (automatically switches to the next tool on failure)
- Error handling with actionable fix suggestions
- Interrupt recovery and signal handling

## System Architecture

### Core Components

```
├── git-auto-push.sh         # Traditional Git operations automation (2552 lines)
├── git-auto-pr.sh           # GitHub Flow PR workflow automation (2769 lines)
├── Conventional Commits      # Prefix support: manual selection, AI detection, skip
├── AI Tool Module            # copilot / gemini / codex / claude
│   ├── Failover             # Auto-switch on tool failure
│   ├── Output Cleaning      # Filter AI metadata
│   └── Quality Check        # Analyze commit message quality
├── Issue Key                 # Parse issue key from branch name (JIRA, GitHub Issue)
├── Commit Message Amendment  # Safely amend last commit with double confirmation
├── Interactive Menu          # Operation options and user interface
├── Debug Mode               # AI tool execution detail tracking
├── Signal Handling          # trap cleanup and interrupt recovery
└── Error Handling           # Anomaly detection and fix suggestions
```

### Project Structure

```
├── git-auto-push.sh      # Traditional Git automation tool
├── git-auto-pr.sh        # GitHub Flow PR automation tool
├── LICENSE              # MIT License
├── README.md            # Project documentation
├── .github/             # GitHub configuration
│   └── copilot-instructions.md    # AI agent development guide
├── docs/                # Documentation directory
│   ├── git-auto-push.mermaid             # Git automation flowchart
│   ├── git-auto-pr.mermaid               # PR flowchart
│   ├── git_auto_push_workflow.png        # Git workflow diagram
│   ├── git_pr_automation.png             # PR automation diagram
│   └── reports/                          # Detailed document reports
│       ├── FEATURE-AMEND.md              # Commit message amendment feature docs
│       ├── FEATURE-COMMIT-QUALITY.md     # Commit quality check feature docs
│       ├── COMMIT-QUALITY-SUMMARY.md     # Commit quality check summary
│       ├── COMMIT-QUALITY-QUICKREF.md    # Commit quality quick reference
│       ├── AI-QUALITY-CHECK-IMPROVEMENT.md # AI quality check improvement docs
│       └── 選項7-變更commit訊息功能開發報告.md # Option 7 development report
└── screenshots/         # Interface screenshots
    ├── ai-commit-generation.png
    ├── auto-mode.png
    ├── main-menu.png
    ├── pr-screenshot-cli.png
    └── pr-screenshot-web.png
```

## Installation

> For the complete installation guide, see [INSTALLATION.md](INSTALLATION.md)

### One-Click Install

```bash
# Interactive install (defaults to ~/.local/bin)
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh

# Direct global install (installs to /usr/local/bin, requires sudo)
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh -s -- --global

# Uninstall
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh -s -- --uninstall
```

### Quick Install

```bash
# Clone the project
git clone https://github.com/lazyjerry/git-auto-push.git
cd git-auto-push

# Set execute permissions
chmod +x git-auto-push.sh git-auto-pr.sh

# Test run
./git-auto-push.sh --help
```

### Global Install (Optional)

```bash
# Install to system path for access from any directory
sudo install -m 755 git-auto-push.sh /usr/local/bin/git-auto-push
sudo install -m 755 git-auto-pr.sh /usr/local/bin/git-auto-pr
```

### Dependencies

| Tool | Purpose | Required |
|------|---------|----------|
| **GitHub CLI** | PR workflow operations | Required for `git-auto-pr.sh` |
| **AI CLI Tools** | Automatic content generation | Optional (recommended) |

```bash
# Install GitHub CLI (macOS)
brew install gh && gh auth login
```

### Custom Configuration

External config files allow customization without modifying scripts:

```bash
# Create config directory and copy example
mkdir -p ~/.git-auto-push-config
cp .git-auto-push-config/.env.example ~/.git-auto-push-config/.env

# Edit configuration
nano ~/.git-auto-push-config/.env
```

**Config file priority**: Current working directory → Home directory → Script directory

Common configuration options:

```bash
# AI tool priority order
AI_TOOLS=("copilot" "claude" "gemini" "codex")

# Default username
DEFAULT_USERNAME="your-name"

# Debug mode
IS_DEBUG=false
```

> For more installation options and AI tool setup, see [INSTALLATION.md](INSTALLATION.md)

## Usage

> For the complete usage guide, see [USAGE.md](USAGE.md)

### Feature Overview

| Tool | Purpose | Core Features |
|------|---------|---------------|
| **git-auto-push.sh** | Traditional Git automation | Add, Commit, Push, Amend message, Repo info |
| **git-auto-pr.sh** | GitHub Flow automation | Create branch, Create PR, Review PR, Cancel PR, Delete branch |

### Quick Command Reference

#### git-auto-push.sh

```bash
# Interactive menu (recommended)
./git-auto-push.sh

# Execute specific features directly
./git-auto-push.sh 1    # Full flow (add → commit → push)
./git-auto-push.sh 4    # Full auto mode (AI-generated content)
./git-auto-push.sh 7    # Amend last commit message

# Other options
./git-auto-push.sh --version   # Show version
./git-auto-push.sh --auto      # Full auto mode
```

#### git-auto-pr.sh

```bash
# Interactive menu
./git-auto-pr.sh

# Follow the prompts to select:
# 1. Create feature branch (jerry/feature/issue-123)
# 2. Create Pull Request (AI-generated content)
# 4. Review and merge PR
```

> Supports Conventional Commits prefixes, AI content generation, quality checks, issue key auto-insertion, and more. See the [Usage Guide](USAGE.md) for details.

## Key Features

### AI Content Generation

Supports four AI CLI tools: copilot, gemini, codex, and claude. If one fails, it automatically tries the next. Output is automatically cleaned of AI tool metadata. Enable `IS_DEBUG=true` to see prompts, diff content, and output for debugging.

**Generated Content**

- Commit messages: Analyzes git diff to generate Conventional Commits-compliant messages
- Quality checks: AI checks if commit messages are clearly descriptive; configurable auto-check or prompt mode; AI failure does not block commits
- Issue keys: Parses issue key from branch name (supports JIRA `PROJ-123`, GitHub Issue `feat-001`), auto-prepended to commit prefix; covers options 1, 2, 4, 5, 7
- Branch names: Generates formatted names based on issue key, owner, and type (e.g., `username/type/issue-key`)
- PR content: Generates title and description based on branch change history

### Error Handling

- Auto-detects `401 Unauthorized`, `token_expired`, `stream error` and other errors, providing corresponding fix commands
- Detects PR self-approval restrictions and provides alternatives
- Color-formatted error messages
- Supports Ctrl+C interrupt exit with automatic temp resource cleanup

### Workflows

**git-auto-push.sh**

- 7 operation modes, supporting staged execution (add → commit → push) or one-click completion
- View repository info: branches, remotes, sync status, commit history
- Amend last commit message (option 7)
- Auto-insert issue key from branch name

**git-auto-pr.sh**

- Complete flow from branch creation to PR creation
- PR cancellation: Detects PR status, safely handles open or merged PRs
- Main branch auto-detection; shows fix suggestions when not found
- Detects user identity to prevent self-approval; provides team review or direct merge options
- Revert operation defaults to "no", displays impact analysis
- Safe branch deletion with main branch protection

## Troubleshooting

### Common Issues and Solutions

**Error: `Current directory is not a Git repository!`**

```bash
# Confirm you're running in a Git repository root directory
git init  # or navigate to the correct Git repository directory
```

**Error: `No changes to commit`**

- Check if there are file changes: `git status`
- Or choose to push existing commits to remote

AI Tool Authentication Errors

```bash
❌ codex authentication error: authentication token expired
💡 Run the following command to re-login to codex:
   codex auth login
```

When `401 Unauthorized` or `token_expired` errors occur, follow the prompts to re-authenticate.

GitHub CLI Related Errors (git-auto-pr.sh)

```bash
❌ gh CLI tool not installed! Run: brew install gh
❌ gh CLI not logged in! Run: gh auth login
```

Ensure GitHub CLI is installed and logged in.

**Branch Status Errors**

```bash
❌ Cannot create PR from main branch (master)
❌ Branch has not been pushed to remote yet
```

Make sure you're working on a feature branch that has been pushed to GitHub.

**PR Review Permission Errors**

```bash
❌ Can not approve your own pull request
⚠️  Cannot approve your own Pull Request
```

GitHub security policies prevent developers from approving their own PRs. Request a team member review, or merge directly if you have permission.

**PR Cancellation Related Errors**

```bash
❌ No related PR found for current branch
⚠️ PR has already been merged; reverting will affect subsequent changes
```

Common PR cancellation scenarios:

- PR not found: Confirm you're on the correct feature branch
- Merged PR: System displays impact scope; revert defaults to requiring explicit confirmation
- Revert conflicts: Resolve manually following prompts
- Insufficient permissions: Ensure you have permission to close PRs or push to the main branch

**Main Branch Auto-Detection**

The tool tries remote `origin/main`, then `origin/master`, and finally checks local branches. Supports both "main" and "master" naming conventions.

**AI Tool Network Errors**

```bash
❌ codex network error: stream error: unexpected status
💡 Check your network connection or try again later
```

Network issues are automatically detected with suggestions provided.

**AI Tools Unavailable**

```bash
# Check if AI CLI tools are installed and executable
which codex
which gemini
which claude
```

Permission Errors

```bash
# Confirm scripts have execute permissions
chmod +x git-auto-push.sh
chmod +x git-auto-pr.sh
```

**Push Failed**

- Check remote repository connection: `git remote -v`
- Verify network connection and authentication settings

## Advanced Usage

### GitHub Flow Best Practices

Both scripts support the [GitHub Flow](docs/github-flow.md) workflow:

**Tool Selection**

- **git-auto-push.sh**: Personal development, experimental projects, rapid prototyping
- **git-auto-pr.sh**: Team collaboration, formal feature development

### Real-World Workflow Examples

**Personal Development Flow**

```bash
# Quick commit and push
git-auto-push --auto
```

**Team Collaboration Flow**

```bash
# 1. Create feature branch
git-auto-pr                    # Select option 1

# 2. After development is complete
git-auto-pr                    # Select option 2 (commit & push)

# 3. Create PR for review
git-auto-pr                    # Select option 3 (create PR)
```

## Development Notes

### Code Architecture

The project uses a modular design with these main components:

#### Configuration Area Overview

- **Location**: Beginning of both script files
- **git-auto-push.sh**: Lines 28-52 - AI tool priority and prompt configuration
- **git-auto-pr.sh**: Lines 25-125 - AI prompt templates, tool settings, branch settings, user settings
- **Principle**: All settings are centralized at the top of files for easy maintenance

#### Branch Settings

**git-auto-pr.sh** branch settings:

- **Main branch array**: `DEFAULT_MAIN_BRANCHES=("main" "master")`
- **Default user setting**: `DEFAULT_USERNAME="jerry"` - customizable owner name
- **Auto-detection**: Detects the first existing branch in order
- **Error handling**: Provides solutions when branch is not found
- Can add `develop`, `dev`, and other branch options

#### Unified Variable Management

- **AI_TOOLS variable**: Unified AI tool priority array
- **Conditional assignment**: Uses `: "${VAR:=default}"` syntax; config files take precedence over defaults
- **Default call order**: copilot → gemini → codex → claude (overridable via config file)

### Code Documentation Standard

All major functions follow this format:

```bash
# ============================================
# Function Name
# Purpose: Detailed description of function behavior
# Parameters: $1 - parameter description, $2 - parameter description
# Returns: Return value meaning and error codes
# Usage: Specific invocation examples
# Notes: Security considerations and special cases
# ============================================
```

**Documentation coverage**: Utility functions, core logic, security mechanisms, usage examples

### Modification Guidelines

#### 1. AI Prompt Modification

```bash
# Location: AI prompt configuration area at the beginning of files
generate_ai_commit_prompt() {
    # Modify commit message generation logic
}

generate_ai_pr_prompt() {
    # Modify PR content generation logic
}
```

**Note**: Branch names are now auto-generated and no longer use AI generation.

#### 2. AI Tool Order Adjustment

```bash
# Method 1: Override via config file (recommended)
# ~/.git-auto-push-config/.env
AI_TOOLS=("copilot" "codex" "gemini" "claude")

# Method 2: Modify script defaults (advanced)
# Find the AI_TOOLS default value block and modify the array
AI_TOOLS=(
    "copilot"   # 1st priority
    "codex"     # 2nd priority
    "gemini"    # 3rd priority
    "claude"    # 4th priority
)
```

#### 3. Adding New AI Tools

1. Add the new tool name to the `AI_TOOLS` array
2. Add a case branch in the corresponding function
3. Implement the corresponding `run_*_command()` function

#### 4. Commit Quality Check Configuration

```bash
# git-auto-push.sh Commit quality check config (around line 149)
AUTO_CHECK_COMMIT_QUALITY=true

# Auto-check mode (default) - automatically check before every commit
AUTO_CHECK_COMMIT_QUALITY=true

# Prompt mode - ask whether to check before commit (defaults to no)
AUTO_CHECK_COMMIT_QUALITY=false
```

**Configuration notes**:

- **Auto-check mode (true)**: Checks before every commit; suitable for strict team standards
- **Prompt mode (false)**: Asks before checking; suitable for quick commit scenarios
- AI tool failure automatically skips the check without affecting commits

#### 5. Branch Configuration Customization

```bash
# Method 1: Override via config file (recommended)
# ~/.git-auto-push-config/.env
DEFAULT_MAIN_BRANCHES=("main" "master" "develop")
DEFAULT_USERNAME="tom"
AUTO_DELETE_BRANCH_AFTER_MERGE=true

# Method 2: Modify script defaults (advanced)
# Main branch candidate list
DEFAULT_MAIN_BRANCHES=("main" "master")

# Default username
DEFAULT_USERNAME="jerry"

# Branch deletion policy after PR merge (true=auto-delete, false=keep)
AUTO_DELETE_BRANCH_AFTER_MERGE=false
```

**Configuration notes**:

- **Detection order**: Script detects the first existing branch in array order
- **Default user**: Owner name when creating branches; can be overridden at runtime
- **Branch deletion policy**: Controls whether to auto-delete branch after PR merge
  - `false` (default): Keep branch
  - `true`: Auto-delete
- Shows error message and solution when branch is not found

#### 6. Error Handling Extension

- Add new error patterns in existing error detection functions
- Update error messages and fix suggestions
- Maintain consistent error output format

### Important Notes

#### Synchronized Modification Requirements

- **AI tools**: Must update both scripts simultaneously
- **Prompts**: Keep style consistent across both files
- **Error handling**: Unified processing model and output format

#### Functional Testing

```bash
# Syntax check
bash -n git-auto-push.sh
bash -n git-auto-pr.sh

# Functional test
./git-auto-push.sh --help
./git-auto-pr.sh --help

# AI tool test
source git-auto-push.sh
for tool in "${AI_TOOLS[@]}"; do echo "Testing $tool"; done
```

#### Version Control

- Update version number after modifications
- Update line count statistics in README
- Record significant changes in commit message

### Common Modification Scenarios

#### Scenario 1: Optimize AI Prompts

1. Modify the corresponding `generate_ai_*_prompt()` function
2. Test generation results
3. Update related documentation

#### Scenario 2: Add Error Handling

1. Identify new error patterns
2. Add conditional checks in the detection function
3. Provide specific fix suggestions

#### Scenario 3: Adjust Workflow

1. Modify `execute_*_workflow()` functions
2. Update menu display
3. Test the workflow

## Changelog

> For the complete version history, see [CHANGELOG.md](CHANGELOG.md)

- Latest version: v2.8.0 (2026-02-01)
- Total versions: 16 major versions
- Development period: 2025-08-21 to present
- Lines of code: `git-auto-push.sh` 2,552 lines, `git-auto-pr.sh` 2,769 lines, `install.sh` 773 lines

### References

- [CHANGELOG.md](CHANGELOG.md) - Complete version history and feature changelog
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - AI agent development guide
- [docs/github-flow.md](docs/github-flow.md) - GitHub Flow documentation
- [docs/pr-cancel-feature.md](docs/pr-cancel-feature.md) - PR cancellation feature details
- [docs/git-info-feature.md](docs/git-info-feature.md) - Git repository info feature docs
- [docs/FEATURE-AMEND.md](docs/FEATURE-AMEND.md) - Commit message amendment feature docs
- [docs/FEATURE-COMMIT-QUALITY.md](docs/FEATURE-COMMIT-QUALITY.md) - Commit quality check feature docs

## Screenshots

git-auto-pr.sh main menu: ![Main Menu](screenshots/main-menu.png)

AI auto-generated Git commit message: ![AI Commit](screenshots/ai-commit-generation.png)

git-auto-push.sh full auto mode: ![Auto Mode](screenshots/auto-mode.png)

Command-line PR creation flow: ![PR CLI](screenshots/pr-screenshot-cli.png)

GitHub web PR creation result: ![PR Web](screenshots/pr-screenshot-web.png)

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
