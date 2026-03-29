🌐 [English](README_EN.md) | 简体中文 | [繁體中文](README.md) | [日本語](README_JP.md) | [한국어](README_KR.md)

---

# Git 工作流程自动化工具集

两支 Bash 脚本，分别处理传统 Git 操作（add/commit/push）和 GitHub Flow PR 流程。支持多种 AI CLI 工具生成 commit 消息与 PR 内容，也提供 Conventional Commits 前缀、消息品质检查、任务编号自动带入等功能。

版本：v2.8.0

## 项目简介

### 主要功能

- 传统 Git 工作流程自动化（add、commit、push）
- Conventional Commits 前缀支持（手动选择或 AI 自动判断）
- 命令行直接执行（`./git-auto-push.sh 1-7` 跳过菜单）
- Git 仓库信息查看（分支状态、远端、同步状态、提交历史）
- Commit 消息修改（安全修改最后一次 commit，支持任务编号）
- Commit 消息品质检查（AI 分析品质，可设定自动或询问模式）
- GitHub Flow PR 流程（从创建分支到创建 PR）
- PR 生命周期管理（创建、撤销、审查、合并）
- 分支管理（安全删除、主分支保护、多重确认）
- AI 生成 commit 消息、分支名称、PR 内容
- 多 AI 工具容错（一个失败自动切换下一个）
- 错误处理与修复建议
- 中断恢复和信号处理

## 系统架构

### 核心组件

```
├── git-auto-push.sh         # 传统 Git 操作自动化（2552 行）
├── git-auto-pr.sh           # GitHub Flow PR 流程自动化（2769 行）
├── Conventional Commits      # 前缀支持：手动选择、AI 判断、跳过
├── AI 工具模块               # copilot / gemini / codex / claude
│   ├── 容错机制             # 工具失败自动切换
│   ├── 输出清理             # 过滤 AI 中继数据
│   └── 品质检查             # 分析 commit 消息品质
├── 任务编号                  # 从分支名称解析 issue key（JIRA、GitHub Issue）
├── Commit 消息修改           # 安全修改最后一次 commit，二次确认
├── 交互式菜单               # 操作选项与用户界面
├── 调试模式                  # AI 工具执行详情追踪
├── 信号处理                  # trap cleanup 与中断恢复
└── 错误处理                  # 异常检测与修复建议
```

### 项目结构

```
├── git-auto-push.sh      # 传统 Git 自动化工具
├── git-auto-pr.sh        # GitHub Flow PR 自动化工具
├── LICENSE              # MIT 授权条款
├── README.md            # 项目说明文件
├── .github/             # GitHub 相关设置
│   └── copilot-instructions.md    # AI 代理开发指导
├── docs/                # 文档目录
│   ├── git-auto-push.mermaid             # Git 自动化流程图
│   ├── git-auto-pr.mermaid               # PR 流程图
│   ├── git_auto_push_workflow.png        # Git 工作流程图
│   ├── git_pr_automation.png             # PR 自动化图
│   └── reports/                          # 详细文档报告
│       ├── FEATURE-AMEND.md              # 变更 commit 消息功能说明
│       ├── FEATURE-COMMIT-QUALITY.md     # Commit 品质检查功能说明
│       ├── COMMIT-QUALITY-SUMMARY.md     # Commit 品质检查摘要
│       ├── COMMIT-QUALITY-QUICKREF.md    # Commit 品质快速参考
│       ├── AI-QUALITY-CHECK-IMPROVEMENT.md # AI 品质检查改进说明
│       └── 選項7-變更commit訊息功能開發報告.md # 选项 7 开发报告
└── screenshots/         # 界面展示图片
    ├── ai-commit-generation.png
    ├── auto-mode.png
    ├── main-menu.png
    ├── pr-screenshot-cli.png
    └── pr-screenshot-web.png
```

## 安装与启动

> 完整安装指南请查看 [INSTALLATION.md](INSTALLATION.md)

### 一键安装

```bash
# 交互式安装（选择本地或全局）
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh

# 直接全局安装（需要 sudo）
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh -s -- --global
```

### 快速安装

```bash
# 克隆项目
git clone https://github.com/lazyjerry/git-auto-push.git
cd git-auto-push

# 设置执行权限
chmod +x git-auto-push.sh git-auto-pr.sh

# 测试执行
./git-auto-push.sh --help
```

### 全局安装（可选）

```bash
# 安装到系统路径，可在任意目录直接调用
sudo install -m 755 git-auto-push.sh /usr/local/bin/git-auto-push
sudo install -m 755 git-auto-pr.sh /usr/local/bin/git-auto-pr
```

### 依赖工具

| 工具 | 用途 | 必要性 |
|-----|------|--------|
| **GitHub CLI** | PR 流程操作 | `git-auto-pr.sh` 必需 |
| **AI CLI 工具** | 内容自动生成 | 可选（建议安装） |

```bash
# 安装 GitHub CLI (macOS)
brew install gh && gh auth login
```

### 个性化配置

支持外部配置文件自定义设置，无需修改脚本：

```bash
# 创建配置目录并复制配置示例
mkdir -p ~/.git-auto-push-config
cp .git-auto-push-config/.env.example ~/.git-auto-push-config/.env

# 编辑配置
nano ~/.git-auto-push-config/.env
```

**配置文件优先级**：当前工作目录 → Home 目录 → 脚本目录

常用配置选项：

```bash
# AI 工具优先顺序
AI_TOOLS=("copilot" "claude" "gemini" "codex")

# 默认用户名
DEFAULT_USERNAME="your-name"

# 调试模式
IS_DEBUG=false
```

> 更多安装选项和 AI 工具安装请参阅 [INSTALLATION.md](INSTALLATION.md)

## 使用方法

> 完整操作指南请查看 [USAGE.md](USAGE.md)

### 功能总览

| 工具 | 用途 | 核心功能 |
|-----|------|----------|
| **git-auto-push.sh** | 传统 Git 自动化 | Add, Commit, Push, 变更消息, 仓库信息 |
| **git-auto-pr.sh** | GitHub Flow 自动化 | 创建分支, 创建 PR, 审查 PR, 撤销 PR, 删除分支 |

### 常用命令速查

#### git-auto-push.sh

```bash
# 交互式菜单（推荐）
./git-auto-push.sh

# 快速执行指定功能
./git-auto-push.sh 1    # 完整流程 (add → commit → push)
./git-auto-push.sh 4    # 全自动模式 (AI 生成内容)
./git-auto-push.sh 7    # 修改最后一次 commit 消息
```

#### git-auto-pr.sh

```bash
# 交互式菜单
./git-auto-pr.sh

# 根据提示选择：
# 1. 创建功能分支 (jerry/feature/issue-123)
# 2. 创建 Pull Request (AI 生成内容)
# 4. 审查与合并 PR
```

> 支持 Conventional Commits 前缀、AI 内容生成、品质检查、任务编号自动带入等功能。详细说明请见 [使用指南](USAGE.md)。

## 特色功能

### AI 内容生成

支持 copilot、gemini、codex、claude 四种 AI CLI 工具，一个失败自动尝试下一个。输出会自动清理 AI 工具的中继数据。开启 `IS_DEBUG=true` 可以看到提示词、diff 内容、输出结果，方便调试。

**生成的内容**

- commit 消息：分析 git diff 生成符合 Conventional Commits 的消息
- 品质检查：AI 检查 commit 消息是否描述清楚，可设定自动检查或询问模式；AI 失败不影响提交
- 任务编号：从分支名称解析 issue key（支持 JIRA `PROJ-123`、GitHub Issue `feat-001`），自动加到 commit 前缀，涵盖选项 1、2、4、5、7
- 分支名称：根据 issue key、所有者、类型生成格式化名称（如 `username/type/issue-key`）
- PR 内容：根据分支变更历史生成标题和描述

### 错误处理

- 自动检测 `401 Unauthorized`、`token_expired`、`stream error` 等错误，提供对应的修复命令
- 检测 PR 自我批准限制并提供替代方案
- 彩色格式化的错误消息
- 支持 Ctrl+C 中断退出，自动清理暂存资源

### 工作流程

**git-auto-push.sh**

- 7 种操作模式，支持分阶段（add → commit → push）或一键完成
- 查看仓库信息：分支、远端、同步状态、提交历史
- 修改最后一次 commit 消息（选项 7）
- 从分支名称自动带入任务编号

**git-auto-pr.sh**

- 从创建分支到创建 PR 的流程
- PR 撤销：检测 PR 状态，安全处理开放或已合并的 PR
- 主分支自动检测，找不到时给出修复建议
- 检测用户身份避免自我批准，提供团队审查或直接合并选项
- revert 操作默认为否，显示影响分析
- 分支安全删除，主分支保护

## 错误排除

### 常见问题及解决方案

**错误：`当前目录不是 Git 仓库！`**

```bash
# 确认在 Git 仓库根目录执行
git init  # 或移动到正确的 Git 仓库目录
```

**错误：`没有需要提交的变更`**

- 检查是否有文件变更：`git status`
- 或选择推送现有提交到远端

AI 工具认证错误

```bash
❌ codex 认证错误: 认证令牌已过期
💡 请执行以下命令重新登录 codex:
   codex auth login
```

当出现 `401 Unauthorized` 或 `token_expired` 错误时，按提示重新认证。

GitHub CLI 相关错误（git-auto-pr.sh）

```bash
❌ 未安装 gh CLI 工具！请执行：brew install gh
❌ gh CLI 未登录！请执行：gh auth login
```

确保已安装并登录 GitHub CLI。

**分支状态错误**

```bash
❌ 无法从主分支 (master) 创建 PR
❌ 分支尚未推送到远端
```

确保在功能分支上操作，并已推送到 GitHub。

**PR 审查权限错误**

```bash
❌ Can not approve your own pull request
⚠️  无法批准自己的 Pull Request
```

GitHub 安全策略不允许开发者批准自己的 PR。可以请团队成员审查，或在有权限时直接合并。

**PR 撤销相关错误**

```bash
❌ 当前分支没有找到相关的 PR
⚠️ PR 已经合并，执行 revert 会影响到后续变更
```

PR 撤销的常见情况：

- 找不到 PR：确认在正确的功能分支上
- 已合并 PR：系统会显示影响范围，revert 按默认需明确确认
- revert 冲突：按提示手动解决
- 权限不足：确保有关闭 PR 或推送到主分支的权限

**主分支自动检测**

工具会依次尝试远端 `origin/main`、`origin/master`，最后才看本地分支。同时支持 main 和 master 两种命名。

**AI 工具网络错误**

```bash
❌ codex 网络错误: stream error: unexpected status
💡 请检查网络连接或稍后重试
```

网络问题会自动检测并给出建议。

**AI 工具无法使用**

```bash
# 检查 AI CLI 工具是否已安装并可执行
which codex
which gemini
which claude
```

权限不足错误

```bash
# 确认脚本具有执行权限
chmod +x git-auto-push.sh
chmod +x git-auto-pr.sh
```

**推送失败**

- 检查远端仓库连接：`git remote -v`
- 确认网络连接和认证设置

## 进阶使用

### GitHub Flow 最佳实践

两支脚本支持 [GitHub Flow](docs/github-flow.md) 工作流程：

**工具选择**

- **git-auto-push.sh**: 个人开发、实验项目、快速原型
- **git-auto-pr.sh**: 团队协作、正式功能开发

### 实际工作流程示例

**个人开发流程**

```bash
# 快速提交和推送
git-auto-push --auto
```

**团队协作流程**

```bash
# 1. 创建功能分支
git-auto-pr                    # 选择选项 1

# 2. 开发完成后
git-auto-pr                    # 选择选项 2（提交推送）

# 3. 创建 PR 供审查
git-auto-pr                    # 选择选项 3（创建 PR）
```

## 开发修改注意事项

### 代码架构说明

项目采用模块化设计，主要组件包括：

#### 设置区域总览

- **位置**：两个脚本文件的开头部分
- **git-auto-push.sh**：第 28-52 行 - AI 工具优先顺序和提示词配置
- **git-auto-pr.sh**：第 25-125 行 - AI 提示词模板、工具设置、分支设置和用户设置
- **修改原则**：所有设置都集中在文件上方，便于维护和修改

#### 分支设置

**git-auto-pr.sh** 的分支设置功能：

- **主分支数组设置**：`DEFAULT_MAIN_BRANCHES=("main" "master")`
- **默认用户设置**：`DEFAULT_USERNAME="jerry"` - 可自定义所有者名字
- **自动检测**：按顺序检测第一个存在的分支
- **错误处理**：找不到分支时提供解决建议
- 可添加 `develop`、`dev` 等分支选项

#### 统一变量管理

- **AI_TOOLS 变量**：统一的 AI 工具优先顺序数组
- **条件赋值**：使用 `: "${VAR:=default}"` 语法，配置文件优先于默认值
- **默认调用顺序**：copilot → gemini → codex → claude（可通过配置文件覆盖）

### 代码文档标准

所有主要函数都采用这个格式：

```bash
# ============================================
# 函数名称
# 功能：详细描述函数用途和行为
# 参数：$1 - 参数说明，$2 - 参数说明
# 返回：返回值含义和错误代码
# 使用：具体的调用示例
# 注意：安全考量和特殊情况
# ============================================
```

**文档覆盖范围**：工具函数、核心逻辑、安全机制、使用示例

### 修改指导原则

#### 1. AI 提示词修改

```bash
# 修改位置：文件开头的 AI 提示词配置区域
generate_ai_commit_prompt() {
    # 修改 commit 消息生成逻辑
}

generate_ai_pr_prompt() {
    # 修改 PR 内容生成逻辑
}
```

**注意**：分支名称现已改为自动生成，不再使用 AI 生成。

#### 2. AI 工具顺序调整

```bash
# 方式一：通过配置文件覆盖（推荐）
# ~/.git-auto-push-config/.env
AI_TOOLS=("copilot" "codex" "gemini" "claude")

# 方式二：修改脚本默认值（进阶）
# 找到 AI_TOOLS 默认值区块，修改数组内容
AI_TOOLS=(
    "copilot"   # 第一优先
    "codex"     # 第二优先
    "gemini"    # 第三优先
    "claude"    # 第四优先
)
```

#### 3. 新增 AI 工具

1. 在 `AI_TOOLS` 数组中添加新工具名称
2. 在对应函数中添加 case 分支处理
3. 实现对应的 `run_*_command()` 函数

#### 4. Commit 品质检查配置

```bash
# git-auto-push.sh Commit 品质检查配置（约 149 行）
AUTO_CHECK_COMMIT_QUALITY=true

# 自动检查模式（默认）- 每次 commit 前自动检查
AUTO_CHECK_COMMIT_QUALITY=true

# 询问模式 - 提交前询问是否检查（默认为否）
AUTO_CHECK_COMMIT_QUALITY=false
```

**配置说明**：

- **自动检查模式（true）**：每次 commit 前自动检查，适合团队规范严格的项目
- **询问模式（false）**：提交前问你要不要检查，适合快速提交场景
- AI 工具失败时自动跳过检查，不影响提交

#### 5. 分支配置自定义

```bash
# 方式一：通过配置文件覆盖（推荐）
# ~/.git-auto-push-config/.env
DEFAULT_MAIN_BRANCHES=("main" "master" "develop")
DEFAULT_USERNAME="tom"
AUTO_DELETE_BRANCH_AFTER_MERGE=true

# 方式二：修改脚本默认值（进阶）
# 主分支候选列表
DEFAULT_MAIN_BRANCHES=("main" "master")

# 默认用户名
DEFAULT_USERNAME="jerry"

# PR 合并后分支删除策略（true=自动删除，false=保留）
AUTO_DELETE_BRANCH_AFTER_MERGE=false
```

**配置说明**：

- **检测顺序**：脚本按数组顺序检测第一个存在的分支
- **默认用户**：分支创建时的所有者名称，执行时可覆写
- **分支删除策略**：控制 PR 合并后是否自动删除分支
  - `false`（默认）：保留分支
  - `true`：自动删除
- 找不到分支时会显示错误消息和解决建议

#### 6. 错误处理扩展

- 在现有错误检测函数中添加新的错误模式
- 更新错误消息和修复建议
- 保持一致的错误输出格式

### 重要注意事项

#### 同步修改要求

- **AI 工具**：修改时需同时更新两个脚本
- **提示词**：两个文件风格保持一致
- **错误处理**：统一处理模式和输出格式

#### 功能测试

```bash
# 语法检查
bash -n git-auto-push.sh
bash -n git-auto-pr.sh

# 功能测试
./git-auto-push.sh --help
./git-auto-pr.sh --help

# AI 工具测试
source git-auto-push.sh
for tool in "${AI_TOOLS[@]}"; do echo "测试 $tool"; done
```

#### 版本控制

- 修改后更新版本号
- 更新 README 中的行数统计
- 记录重要变更到 commit message

### 常见修改场景

#### 场景 1：优化 AI 提示词

1. 修改对应的 `generate_ai_*_prompt()` 函数
2. 测试生成效果
3. 更新相关文档

#### 场景 2：新增错误处理

1. 识别新的错误模式
2. 在检测函数中添加条件判断
3. 提供具体的修复建议

#### 场景 3：调整工作流程

1. 修改 `execute_*_workflow()` 函数
2. 更新菜单显示
3. 测试流程

## 更新日志

> 完整版本历史请查看 [CHANGELOG.md](CHANGELOG.md)

- 最新版本：v2.8.0 (2026-02-01)
- 总版本数：16 个主要版本
- 开发期间：2025-08-21 至今
- 代码行数：`git-auto-push.sh` 2,552 行、`git-auto-pr.sh` 2,769 行、`install.sh` 689 行

### 参考资源

- [CHANGELOG.md](CHANGELOG.md) - 完整版本历史与功能变更记录
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - AI 代理开发指导
- [docs/github-flow.md](docs/github-flow.md) - GitHub Flow 说明
- [docs/pr-cancel-feature.md](docs/pr-cancel-feature.md) - PR 撤销功能详细说明
- [docs/git-info-feature.md](docs/git-info-feature.md) - Git 仓库信息功能说明
- [docs/FEATURE-AMEND.md](docs/FEATURE-AMEND.md) - 变更 commit 消息功能说明
- [docs/FEATURE-COMMIT-QUALITY.md](docs/FEATURE-COMMIT-QUALITY.md) - Commit 品质检查功能说明

## 截图展示

git-auto-pr.sh 主要操作菜单：![主菜单](screenshots/main-menu.png)

AI 自动生成 Git 提交消息：![AI 提交](screenshots/ai-commit-generation.png)

git-auto-push.sh 全自动操作模式：![自动模式](screenshots/auto-mode.png)

命令行 PR 创建流程：![PR CLI](screenshots/pr-screenshot-cli.png)

GitHub 网页 PR 创建结果：![PR Web](screenshots/pr-screenshot-web.png)

## 授权条款

本项目采用 MIT 授权条款。详细信息请参阅 [LICENSE](LICENSE) 文件。
