#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
cd "$repo_root"

fail() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

require_line() {
    target_file=$1
    expected_line=$2

    LC_ALL=C grep -Fqx -- "$expected_line" "$target_file" || \
        fail "$target_file does not contain the expected README baseline: $expected_line"
}

replace_line() {
    target_file=$1
    old_line=$2
    new_line=$3

    if LC_ALL=C grep -Fqx -- "$new_line" "$target_file"; then
        return
    fi

    LC_ALL=C grep -Fqx -- "$old_line" "$target_file" || \
        fail "$target_file contains neither the old nor synchronized text: $old_line"

    OLD_LINE=$old_line NEW_LINE=$new_line LC_ALL=C perl -i -pe \
        's/^\Q$ENV{OLD_LINE}\E$/$ENV{NEW_LINE}/' "$target_file"

    require_line "$target_file" "$new_line"
}

require_line README.md '版本：v2.11.0'
require_line README.md '# 互動式安裝/更新（預設安裝到 ~/.local/bin）'
require_line README.md '# 直接全域安裝/更新（安裝到 /usr/local/bin，需要 sudo）'
require_line README.md '# AI 工具優先順序（gemini 已停用，請改用 agy）'
require_line README.md '- 最新版本：v2.11.0 (2026-08-15)'
require_line README.md '- 總版本數：19 個主要版本'
require_line README.md '- 程式碼行數：`git-auto-push.sh` 2,837 行、`git-auto-pr.sh` 2,915 行、`install.sh` 782 行'

replace_line README_CN.md '版本：v2.10.0' '版本：v2.11.0'
replace_line README_CN.md '# 交互式安装（默认安装到 ~/.local/bin）' '# 交互式安装/更新（默认安装到 ~/.local/bin）'
replace_line README_CN.md '# 直接全局安装（安装到 /usr/local/bin，需要 sudo）' '# 直接全局安装/更新（安装到 /usr/local/bin，需要 sudo）'
replace_line README_CN.md '# AI 工具优先顺序' '# AI 工具优先顺序（gemini 已停用，请改用 agy）'
replace_line README_CN.md '- 最新版本：v2.10.0 (2026-06-19)' '- 最新版本：v2.11.0 (2026-08-15)'
replace_line README_CN.md '- 总版本数：18 个主要版本' '- 总版本数：19 个主要版本'
replace_line README_CN.md '- 代码行数：`git-auto-push.sh` 2,673 行、`git-auto-pr.sh` 2,902 行、`install.sh` 772 行' '- 代码行数：`git-auto-push.sh` 2,837 行、`git-auto-pr.sh` 2,915 行、`install.sh` 782 行'

replace_line README_EN.md 'Version: v2.10.0' 'Version: v2.11.0'
replace_line README_EN.md '# Interactive install (defaults to ~/.local/bin)' '# Interactive install/update (defaults to ~/.local/bin)'
replace_line README_EN.md '# Direct global install (installs to /usr/local/bin, requires sudo)' '# Direct global install/update (installs to /usr/local/bin, requires sudo)'
replace_line README_EN.md '# AI tool priority order' '# AI tool priority order (gemini is disabled; use agy instead)'
replace_line README_EN.md '- Latest version: v2.10.0 (2026-06-19)' '- Latest version: v2.11.0 (2026-08-15)'
replace_line README_EN.md '- Total versions: 18 major versions' '- Total versions: 19 major versions'
replace_line README_EN.md '- Lines of code: `git-auto-push.sh` 2,673 lines, `git-auto-pr.sh` 2,902 lines, `install.sh` 772 lines' '- Lines of code: `git-auto-push.sh` 2,837 lines, `git-auto-pr.sh` 2,915 lines, `install.sh` 782 lines'

replace_line README_JP.md 'バージョン：v2.10.0' 'バージョン：v2.11.0'
replace_line README_JP.md '# インタラクティブインストール（デフォルトで ~/.local/bin にインストール）' '# インタラクティブインストール／更新（デフォルトで ~/.local/bin にインストール）'
replace_line README_JP.md '# グローバルインストール（/usr/local/bin にインストール、sudo が必要）' '# グローバルインストール／更新（/usr/local/bin にインストール、sudo が必要）'
replace_line README_JP.md '# AI ツールの優先順序' '# AI ツールの優先順序（gemini は無効です。agy を使用してください）'
replace_line README_JP.md '- 最新バージョン：v2.10.0 (2026-06-19)' '- 最新バージョン：v2.11.0 (2026-08-15)'
replace_line README_JP.md '- 総バージョン数：18 のメジャーバージョン' '- 総バージョン数：19 のメジャーバージョン'
replace_line README_JP.md '- コード行数：`git-auto-push.sh` 2,673 行、`git-auto-pr.sh` 2,902 行、`install.sh` 772 行' '- コード行数：`git-auto-push.sh` 2,837 行、`git-auto-pr.sh` 2,915 行、`install.sh` 782 行'

replace_line README_KR.md '버전: v2.10.0' '버전: v2.11.0'
replace_line README_KR.md '# 대화형 설치 (기본적으로 ~/.local/bin에 설치)' '# 대화형 설치/업데이트 (기본적으로 ~/.local/bin에 설치)'
replace_line README_KR.md '# 글로벌 직접 설치 (/usr/local/bin에 설치, sudo 필요)' '# 글로벌 직접 설치/업데이트 (/usr/local/bin에 설치, sudo 필요)'
replace_line README_KR.md '# AI 도구 우선순위' '# AI 도구 우선순위 (gemini는 비활성화되었으므로 agy를 사용하세요)'
replace_line README_KR.md '- 최신 버전: v2.10.0 (2026-06-19)' '- 최신 버전: v2.11.0 (2026-08-15)'
replace_line README_KR.md '- 총 버전 수: 18개 주요 버전' '- 총 버전 수: 19개 주요 버전'
replace_line README_KR.md '- 코드 행 수: `git-auto-push.sh` 2,673행, `git-auto-pr.sh` 2,902행, `install.sh` 772행' '- 코드 행 수: `git-auto-push.sh` 2,837행, `git-auto-pr.sh` 2,915행, `install.sh` 782행'

printf 'README translations are synchronized with README.md.\n'
