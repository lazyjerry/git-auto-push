# Repository Guidelines

## Project Structure & Module Organization
- Root scripts: `git-auto-push.sh` (classic Git automation), `git-auto-pr.sh` (GitHub Flow/PR automation).
- Docs: `docs/` (e.g., `docs/github-flow.md`).
- GitHub configs: `.github/` (instructions and templates).
- Assets: `screenshots/` used in the README.

## Build, Test, and Development Commands
- Run locally: `./git-auto-push.sh`, `./git-auto-pr.sh` (add `--auto` for non‑interactive).
- Make executable: `chmod +x git-auto-*.sh`.
- Lint Bash: `shellcheck git-auto-*.sh` (fix all warnings before PR).
- Format Bash: `shfmt -w -i 4 -s git-auto-*.sh`.
- GitHub CLI check (for PR tool): `gh auth status`.

## Coding Style & Naming Conventions
- Language: Bash (`/bin/bash`). Indentation: 4 spaces, no tabs.
- Functions: `lower_snake_case` (e.g., `handle_error`, `run_command`).
- Constants/readonly vars: `UPPER_SNAKE_CASE` with `readonly` where applicable.
- Strictness: prefer `set -Eeuo pipefail` in new modules; handle errors via `handle_error`.
- Messages: colored, concise; reuse `info_msg`/`warning_msg`/`success_msg` helpers.
- Filenames: `git-<domain>-<action>.sh` (e.g., `git-auto-*.sh`).

## Testing Guidelines
- Linting is required (`shellcheck`, `shfmt`).
- For behavior tests, add Bats tests under `tests/` (if introduced): `bats tests`.
- Cover critical paths: add/commit/push flow, branch/PR creation, error handling.
- Document manual test steps in PR when automation isn’t feasible.

## Commit & Pull Request Guidelines
- Commit messages: follow Conventional Commits (e.g., `feat: add auto PR flow`).
- Scope examples: `feat(push)`, `fix(pr)`, `docs(readme)`.
- PRs must include: purpose, key changes, manual/auto test evidence, related issue (`JIRA-123`/`#123`), and screenshots/logs when helpful.
- Keep PRs focused; update README/docs when user‑visible behavior changes.

## Security & Configuration Tips
- Do not commit tokens; use env vars (e.g., `GH_TOKEN`).
- Verify GitHub CLI login before PR flows: `gh auth login`.
- Scripts must handle missing tools gracefully and provide actionable guidance.

## Agent-Specific Notes
- Keep changes minimal and consistent with existing patterns.
- Prefer updating helpers over duplicating logic; avoid unrelated refactors.
- Do not add license headers; follow current headers and comments.
