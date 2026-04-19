🌐 [English](README_EN.md) | [简体中文](README_CN.md) | [繁體中文](README.md) | [日本語](README_JP.md) | 한국어

---

# Git 워크플로우 자동화 도구 모음

두 개의 Bash 스크립트로, 각각 전통적인 Git 작업(add/commit/push)과 GitHub Flow PR 흐름을 처리합니다. 여러 AI CLI 도구를 통한 commit 메시지 및 PR 콘텐츠 생성을 지원하며, Conventional Commits 접두사, 메시지 품질 검사, 작업 번호 자동 입력 등의 기능도 제공합니다.

버전: v2.8.0

## 프로젝트 소개

### 주요 기능

- 전통적인 Git 워크플로우 자동화 (add, commit, push)
- Conventional Commits 접두사 지원 (수동 선택 또는 AI 자동 판단)
- 명령줄에서 직접 실행 (`./git-auto-push.sh 1-7`로 메뉴 건너뛰기)
- Git 저장소 정보 조회 (브랜치 상태, 원격, 동기화 상태, 커밋 이력)
- Commit 메시지 수정 (마지막 커밋을 안전하게 수정, 작업 번호 지원)
- Commit 메시지 품질 검사 (AI 분석 품질, 자동 또는 확인 모드 설정 가능)
- GitHub Flow PR 흐름 (브랜치 생성부터 PR 생성까지)
- PR 수명 주기 관리 (생성, 취소, 리뷰, 병합)
- 브랜치 관리 (안전한 삭제, 메인 브랜치 보호, 다중 확인)
- AI 를 통한 commit 메시지, 브랜치 이름, PR 콘텐츠 생성
- 멀티 AI 도구 폴백 (하나가 실패하면 자동으로 다음 도구로 전환)
- 오류 처리 및 수정 제안
- 중단 복구 및 시그널 처리

## 시스템 아키텍처

### 핵심 구성요소

```
├── git-auto-push.sh         # 전통적인 Git 작업 자동화 (2552 행)
├── git-auto-pr.sh           # GitHub Flow PR 흐름 자동화 (2769 행)
├── Conventional Commits      # 접두사 지원: 수동 선택, AI 판단, 건너뛰기
├── AI 도구 모듈              # copilot / gemini / codex / claude
│   ├── 폴백 메커니즘        # 도구 실패 시 자동 전환
│   ├── 출력 정리            # AI 메타데이터 필터링
│   └── 품질 검사            # commit 메시지 품질 분석
├── 작업 번호                 # 브랜치 이름에서 issue key 해석 (JIRA, GitHub Issue)
├── Commit 메시지 수정        # 마지막 커밋을 안전하게 수정, 이중 확인
├── 대화형 메뉴              # 작업 옵션과 사용자 인터페이스
├── 디버그 모드              # AI 도구 실행 세부 정보 추적
├── 시그널 처리              # trap cleanup 및 중단 복구
└── 오류 처리                # 이상 감지 및 수정 제안
```

### 프로젝트 구조

```
├── git-auto-push.sh      # 전통적인 Git 자동화 도구
├── git-auto-pr.sh        # GitHub Flow PR 자동화 도구
├── LICENSE              # MIT 라이선스
├── README.md            # 프로젝트 설명 파일
├── .github/             # GitHub 관련 설정
│   └── copilot-instructions.md    # AI 에이전트 개발 가이드
├── docs/                # 문서 디렉터리
│   ├── git-auto-push.mermaid             # Git 자동화 플로우차트
│   ├── git-auto-pr.mermaid               # PR 플로우차트
│   ├── git_auto_push_workflow.png        # Git 워크플로우 다이어그램
│   ├── git_pr_automation.png             # PR 자동화 다이어그램
│   └── reports/                          # 상세 문서 보고서
│       ├── FEATURE-AMEND.md              # commit 메시지 변경 기능 설명
│       ├── FEATURE-COMMIT-QUALITY.md     # Commit 품질 검사 기능 설명
│       ├── COMMIT-QUALITY-SUMMARY.md     # Commit 품질 검사 요약
│       ├── COMMIT-QUALITY-QUICKREF.md    # Commit 품질 빠른 참조
│       ├── AI-QUALITY-CHECK-IMPROVEMENT.md # AI 품질 검사 개선 설명
│       └── 選項7-變更commit訊息功能開發報告.md # 옵션 7 개발 보고서
└── screenshots/         # 인터페이스 전시 이미지
    ├── ai-commit-generation.png
    ├── auto-mode.png
    ├── main-menu.png
    ├── pr-screenshot-cli.png
    └── pr-screenshot-web.png
```

## 설치 및 시작

> 전체 설치 가이드는 [INSTALLATION.md](INSTALLATION.md)를 참조하세요

### 원클릭 설치

```bash
# 대화형 설치 (기본적으로 ~/.local/bin에 설치)
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh

# 글로벌 직접 설치 (/usr/local/bin에 설치, sudo 필요)
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh -s -- --global

# 제거
curl -fsSL https://raw.githubusercontent.com/lazyjerry/git-auto-push/refs/heads/master/install.sh | sh -s -- --uninstall
```

### 빠른 설치

```bash
# 프로젝트 클론
git clone https://github.com/lazyjerry/git-auto-push.git
cd git-auto-push

# 실행 권한 설정
chmod +x git-auto-push.sh git-auto-pr.sh

# 테스트 실행
./git-auto-push.sh --help
```

### 글로벌 설치 (선택사항)

```bash
# 시스템 경로에 설치하여 모든 디렉터리에서 직접 호출 가능
sudo install -m 755 git-auto-push.sh /usr/local/bin/git-auto-push
sudo install -m 755 git-auto-pr.sh /usr/local/bin/git-auto-pr
```

### 의존 도구

| 도구 | 용도 | 필수 여부 |
|------|------|-----------|
| **GitHub CLI** | PR 흐름 작업 | `git-auto-pr.sh` 필수 |
| **AI CLI 도구** | 콘텐츠 자동 생성 | 선택 (설치 권장) |

```bash
# GitHub CLI 설치 (macOS)
brew install gh && gh auth login
```

### 개인화 설정

외부 설정 파일로 사용자 정의 가능하며, 스크립트를 수정할 필요가 없습니다:

```bash
# 설정 디렉터리 생성 및 설정 예시 복사
mkdir -p ~/.git-auto-push-config
cp .git-auto-push-config/.env.example ~/.git-auto-push-config/.env

# 설정 편집
nano ~/.git-auto-push-config/.env
```

**설정 파일 우선순위**: 현재 작업 디렉터리 → Home 디렉터리 → 스크립트 디렉터리

자주 사용하는 설정 옵션:

```bash
# AI 도구 우선순위
AI_TOOLS=("copilot" "claude" "gemini" "codex")

# 기본 사용자 이름
DEFAULT_USERNAME="your-name"

# 디버그 모드
IS_DEBUG=false
```

> 추가 설치 옵션 및 AI 도구 설치에 대해서는 [INSTALLATION.md](INSTALLATION.md)를 참조하세요

## 사용 방법

> 전체 작업 가이드는 [USAGE.md](USAGE.md)를 참조하세요

### 기능 개요

| 도구 | 용도 | 핵심 기능 |
|------|------|-----------|
| **git-auto-push.sh** | 전통적인 Git 자동화 | Add, Commit, Push, 메시지 변경, 저장소 정보 |
| **git-auto-pr.sh** | GitHub Flow 자동화 | 브랜치 생성, PR 생성, PR 리뷰, PR 취소, 브랜치 삭제 |

### 자주 사용하는 명령어 빠른 참조

#### git-auto-push.sh

```bash
# 대화형 메뉴 (권장)
./git-auto-push.sh

# 지정 기능 빠른 실행
./git-auto-push.sh 1    # 전체 흐름 (add → commit → push)
./git-auto-push.sh 4    # 완전 자동 모드 (AI 콘텐츠 생성)
./git-auto-push.sh 7    # 마지막 commit 메시지 수정

# 기타 옵션
./git-auto-push.sh --version   # 버전 표시
./git-auto-push.sh --auto      # 완전 자동 모드
```

#### git-auto-pr.sh

```bash
# 대화형 메뉴
./git-auto-pr.sh

# 안내에 따라 선택:
# 1. 기능 브랜치 생성 (jerry/feature/issue-123)
# 2. Pull Request 생성 (AI 콘텐츠 생성)
# 4. PR 리뷰 및 병합
```

> Conventional Commits 접두사, AI 콘텐츠 생성, 품질 검사, 작업 번호 자동 입력 등의 기능을 지원합니다. 자세한 설명은 [사용 가이드](USAGE.md)를 참조하세요.

## 주요 기능

### AI 콘텐츠 생성

copilot, gemini, codex, claude 4가지 AI CLI 도구를 지원하며, 하나가 실패하면 자동으로 다음 도구를 시도합니다. 출력은 AI 도구의 메타데이터를 자동으로 정리합니다. `IS_DEBUG=true`를 활성화하면 프롬프트, diff 내용, 출력 결과를 확인할 수 있어 디버그에 편리합니다.

**생성되는 콘텐츠**

- commit 메시지: git diff 를 분석하여 Conventional Commits 에 부합하는 메시지 생성
- 품질 검사: AI 가 commit 메시지의 기술이 명확한지 검사. 자동 검사 또는 확인 모드 설정 가능. AI 실패 시 커밋에 영향 없음
- 작업 번호: 브랜치 이름에서 issue key 해석 (JIRA `PROJ-123`, GitHub Issue `feat-001` 지원), 자동으로 commit 접두사에 추가. 옵션 1, 2, 4, 5, 7 포함
- 브랜치 이름: issue key, 소유자, 유형을 기반으로 포맷된 이름 생성 (예: `username/type/issue-key`)
- PR 콘텐츠: 브랜치 변경 이력을 기반으로 제목과 설명 생성

### 오류 처리

- `401 Unauthorized`, `token_expired`, `stream error` 등의 오류를 자동 감지하고 해당 수정 명령어 제공
- PR 자기 승인 제한 감지 및 대안 제공
- 색상 포맷의 오류 메시지
- Ctrl+C 중단 종료 지원, 임시 리소스 자동 정리

### 워크플로우

**git-auto-push.sh**

- 7가지 작업 모드, 단계별 실행 (add → commit → push) 또는 원클릭 완료 지원
- 저장소 정보 조회: 브랜치, 원격, 동기화 상태, 커밋 이력
- 마지막 commit 메시지 수정 (옵션 7)
- 브랜치 이름에서 작업 번호 자동 입력

**git-auto-pr.sh**

- 브랜치 생성부터 PR 생성까지의 흐름
- PR 취소: PR 상태를 감지하여 열린 또는 병합된 PR 을 안전하게 처리
- 메인 브랜치 자동 감지. 찾을 수 없는 경우 수정 제안 표시
- 사용자 ID 를 감지하여 자기 승인 방지, 팀 리뷰 또는 직접 병합 옵션 제공
- revert 작업은 기본적으로 "아니오", 영향 분석 표시
- 브랜치 안전 삭제, 메인 브랜치 보호

## 문제 해결

### 자주 발생하는 문제 및 해결 방법

**오류: `현재 디렉터리는 Git 저장소가 아닙니다!`**

```bash
# Git 저장소 루트 디렉터리에서 실행 중인지 확인
git init  # 또는 올바른 Git 저장소 디렉터리로 이동
```

**오류: `커밋할 변경 사항이 없습니다`**

- 파일 변경이 있는지 확인: `git status`
- 또는 기존 커밋을 원격으로 푸시 선택

AI 도구 인증 오류

```bash
❌ codex 인증 오류: 인증 토큰이 만료됨
💡 다음 명령어를 실행하여 codex 에 다시 로그인하세요:
   codex auth login
```

`401 Unauthorized` 또는 `token_expired` 오류가 발생하면 안내에 따라 재인증하세요.

GitHub CLI 관련 오류 (git-auto-pr.sh)

```bash
❌ gh CLI 도구가 설치되지 않았습니다! 실행하세요: brew install gh
❌ gh CLI 에 로그인하지 않았습니다! 실행하세요: gh auth login
```

GitHub CLI 가 설치되고 로그인되어 있는지 확인하세요.

**브랜치 상태 오류**

```bash
❌ 메인 브랜치 (master) 에서 PR 을 생성할 수 없습니다
❌ 브랜치가 아직 원격에 푸시되지 않았습니다
```

기능 브랜치에서 작업하고 있으며, GitHub 에 이미 푸시되었는지 확인하세요.

**PR 리뷰 권한 오류**

```bash
❌ Can not approve your own pull request
⚠️  자신의 Pull Request 를 승인할 수 없습니다
```

GitHub 보안 정책에 따라 개발자는 자신의 PR 을 승인할 수 없습니다. 팀 구성원에게 리뷰를 요청하거나, 권한이 있는 경우 직접 병합할 수 있습니다.

**PR 취소 관련 오류**

```bash
❌ 현재 브랜치에서 관련 PR 을 찾을 수 없습니다
⚠️ PR 이 이미 병합되었으며, revert 를 실행하면 후속 변경에 영향을 줍니다
```

PR 취소의 자주 발생하는 상황:

- PR 을 찾을 수 없음: 올바른 기능 브랜치에 있는지 확인
- 병합된 PR: 시스템이 영향 범위를 표시. revert 는 기본적으로 명시적 확인 필요
- revert 충돌: 안내에 따라 수동으로 해결
- 권한 부족: PR 닫기 또는 메인 브랜치 푸시 권한이 있는지 확인

**메인 브랜치 자동 감지**

도구는 원격 `origin/main`, `origin/master` 를 순서대로 시도하고, 마지막으로 로컬 브랜치를 확인합니다. main 과 master 두 가지 명명에 모두 대응합니다.

**AI 도구 네트워크 오류**

```bash
❌ codex 네트워크 오류: stream error: unexpected status
💡 네트워크 연결을 확인하거나 나중에 다시 시도하세요
```

네트워크 문제는 자동으로 감지되며 제안이 표시됩니다.

**AI 도구를 사용할 수 없음**

```bash
# AI CLI 도구가 설치되어 있고 실행 가능한지 확인
which codex
which gemini
which claude
```

권한 부족 오류

```bash
# 스크립트에 실행 권한이 있는지 확인
chmod +x git-auto-push.sh
chmod +x git-auto-pr.sh
```

**푸시 실패**

- 원격 저장소 연결 확인: `git remote -v`
- 네트워크 연결 및 인증 설정 확인

## 고급 사용법

### GitHub Flow 모범 사례

두 개의 스크립트는 [GitHub Flow](docs/github-flow.md) 워크플로우를 지원합니다:

**도구 선택**

- **git-auto-push.sh**: 개인 개발, 실험 프로젝트, 빠른 프로토타입
- **git-auto-pr.sh**: 팀 협업, 정식 기능 개발

### 실제 워크플로우 예시

**개인 개발 흐름**

```bash
# 빠른 커밋 및 푸시
git-auto-push --auto
```

**팀 협업 흐름**

```bash
# 1. 기능 브랜치 생성
git-auto-pr                    # 옵션 1 선택

# 2. 개발 완료 후
git-auto-pr                    # 옵션 2 선택 (커밋 및 푸시)

# 3. 리뷰용 PR 생성
git-auto-pr                    # 옵션 3 선택 (PR 생성)
```

## 개발 수정 주의사항

### 코드 아키텍처 설명

프로젝트는 모듈화 설계를 채택하고 있으며, 주요 구성요소는 다음과 같습니다:

#### 설정 영역 개요

- **위치**: 두 스크립트 파일의 시작 부분
- **git-auto-push.sh**: 28-52행 - AI 도구 우선순위 및 프롬프트 설정
- **git-auto-pr.sh**: 25-125행 - AI 프롬프트 템플릿, 도구 설정, 브랜치 설정, 사용자 설정
- **수정 원칙**: 모든 설정이 파일 상단에 집중되어 있어 유지보수와 수정이 용이

#### 브랜치 설정

**git-auto-pr.sh** 의 브랜치 설정 기능:

- **메인 브랜치 배열 설정**: `DEFAULT_MAIN_BRANCHES=("main" "master")`
- **기본 사용자 설정**: `DEFAULT_USERNAME="jerry"` - 소유자 이름 사용자 정의 가능
- **자동 감지**: 순서대로 첫 번째로 존재하는 브랜치를 감지
- **오류 처리**: 브랜치를 찾을 수 없을 때 해결 방법 제공
- `develop`, `dev` 등의 브랜치 옵션 추가 가능

#### 통합 변수 관리

- **AI_TOOLS 변수**: 통합된 AI 도구 우선순위 배열
- **조건부 할당**: `: "${VAR:=default}"` 구문 사용, 설정 파일이 기본값보다 우선
- **기본 호출 순서**: copilot → gemini → codex → claude (설정 파일로 덮어쓰기 가능)

### 코드 문서 표준

모든 주요 함수는 다음 형식을 따릅니다:

```bash
# ============================================
# 함수 이름
# 기능: 함수 용도와 동작에 대한 상세 설명
# 매개변수: $1 - 매개변수 설명, $2 - 매개변수 설명
# 반환값: 반환값 의미와 오류 코드
# 사용법: 구체적인 호출 예시
# 주의: 보안 고려사항 및 특수한 경우
# ============================================
```

**문서 범위**: 유틸리티 함수, 핵심 로직, 보안 메커니즘, 사용 예시

### 수정 가이드라인

#### 1. AI 프롬프트 수정

```bash
# 수정 위치: 파일 시작의 AI 프롬프트 설정 영역
generate_ai_commit_prompt() {
    # commit 메시지 생성 로직 수정
}

generate_ai_pr_prompt() {
    # PR 콘텐츠 생성 로직 수정
}
```

**주의**: 브랜치 이름은 현재 자동 생성으로 변경되었으며, AI 생성은 더 이상 사용하지 않습니다.

#### 2. AI 도구 순서 조정

```bash
# 방법 1: 설정 파일로 덮어쓰기 (권장)
# ~/.git-auto-push-config/.env
AI_TOOLS=("copilot" "codex" "gemini" "claude")

# 방법 2: 스크립트 기본값 수정 (고급)
# AI_TOOLS 기본값 블록을 찾아 배열 내용 수정
AI_TOOLS=(
    "copilot"   # 1순위
    "codex"     # 2순위
    "gemini"    # 3순위
    "claude"    # 4순위
)
```

#### 3. 새 AI 도구 추가

1. `AI_TOOLS` 배열에 새 도구 이름 추가
2. 해당 함수에 case 분기 처리 추가
3. 해당 `run_*_command()` 함수 구현

#### 4. Commit 품질 검사 설정

```bash
# git-auto-push.sh Commit 품질 검사 설정 (약 149행)
AUTO_CHECK_COMMIT_QUALITY=true

# 자동 검사 모드 (기본값) - 매번 commit 전에 자동 검사
AUTO_CHECK_COMMIT_QUALITY=true

# 확인 모드 - 커밋 전에 검사할지 확인 (기본값은 "아니오")
AUTO_CHECK_COMMIT_QUALITY=false
```

**설정 설명**:

- **자동 검사 모드 (true)**: 매번 commit 전에 자동 검사. 팀 규범이 엄격한 프로젝트에 적합
- **확인 모드 (false)**: 커밋 전에 검사할지 확인. 빠른 커밋 시나리오에 적합
- AI 도구 실패 시 자동으로 검사를 건너뛰며, 커밋에 영향 없음

#### 5. 브랜치 설정 사용자 정의

```bash
# 방법 1: 설정 파일로 덮어쓰기 (권장)
# ~/.git-auto-push-config/.env
DEFAULT_MAIN_BRANCHES=("main" "master" "develop")
DEFAULT_USERNAME="tom"
AUTO_DELETE_BRANCH_AFTER_MERGE=true

# 방법 2: 스크립트 기본값 수정 (고급)
# 메인 브랜치 후보 목록
DEFAULT_MAIN_BRANCHES=("main" "master")

# 기본 사용자 이름
DEFAULT_USERNAME="jerry"

# PR 병합 후 브랜치 삭제 정책 (true=자동 삭제, false=유지)
AUTO_DELETE_BRANCH_AFTER_MERGE=false
```

**설정 설명**:

- **감지 순서**: 스크립트가 배열 순서대로 첫 번째 존재하는 브랜치를 감지
- **기본 사용자**: 브랜치 생성 시 소유자 이름. 실행 시 덮어쓰기 가능
- **브랜치 삭제 정책**: PR 병합 후 브랜치 자동 삭제 여부 제어
  - `false` (기본값): 브랜치 유지
  - `true`: 자동 삭제
- 브랜치를 찾을 수 없을 때 오류 메시지와 해결 방법 표시

#### 6. 오류 처리 확장

- 기존 오류 감지 함수에 새로운 오류 패턴 추가
- 오류 메시지 및 수정 제안 업데이트
- 일관된 오류 출력 형식 유지

### 중요 주의사항

#### 동기화 수정 요구사항

- **AI 도구**: 수정 시 두 개의 스크립트를 동시에 업데이트 필요
- **프롬프트**: 두 파일의 스타일 일관성 유지
- **오류 처리**: 통일된 처리 모델과 출력 형식

#### 기능 테스트

```bash
# 구문 검사
bash -n git-auto-push.sh
bash -n git-auto-pr.sh

# 기능 테스트
./git-auto-push.sh --help
./git-auto-pr.sh --help

# AI 도구 테스트
source git-auto-push.sh
for tool in "${AI_TOOLS[@]}"; do echo "테스트 $tool"; done
```

#### 버전 관리

- 수정 후 버전 번호 업데이트
- README 의 행 수 통계 업데이트
- 중요 변경 사항을 commit message 에 기록

### 자주 발생하는 수정 시나리오

#### 시나리오 1: AI 프롬프트 최적화

1. 해당 `generate_ai_*_prompt()` 함수 수정
2. 생성 결과 테스트
3. 관련 문서 업데이트

#### 시나리오 2: 새 오류 처리 추가

1. 새로운 오류 패턴 식별
2. 감지 함수에 조건 판단 추가
3. 구체적인 수정 제안 제공

#### 시나리오 3: 워크플로우 조정

1. `execute_*_workflow()` 함수 수정
2. 메뉴 표시 업데이트
3. 흐름 테스트

## 업데이트 로그

> 전체 버전 이력은 [CHANGELOG.md](CHANGELOG.md)를 참조하세요

- 최신 버전: v2.8.0 (2026-02-01)
- 총 버전 수: 16개 주요 버전
- 개발 기간: 2025-08-21부터 현재까지
- 코드 행 수: `git-auto-push.sh` 2,552행, `git-auto-pr.sh` 2,769행, `install.sh` 773행

### 참조 자료

- [CHANGELOG.md](CHANGELOG.md) - 전체 버전 이력 및 기능 변경 기록
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - AI 에이전트 개발 가이드
- [docs/github-flow.md](docs/github-flow.md) - GitHub Flow 설명
- [docs/pr-cancel-feature.md](docs/pr-cancel-feature.md) - PR 취소 기능 상세 설명
- [docs/git-info-feature.md](docs/git-info-feature.md) - Git 저장소 정보 기능 설명
- [docs/FEATURE-AMEND.md](docs/FEATURE-AMEND.md) - commit 메시지 변경 기능 설명
- [docs/FEATURE-COMMIT-QUALITY.md](docs/FEATURE-COMMIT-QUALITY.md) - Commit 품질 검사 기능 설명

## 스크린샷

git-auto-pr.sh 메인 메뉴: ![메인 메뉴](screenshots/main-menu.png)

AI 자동 생성 Git 커밋 메시지: ![AI 커밋](screenshots/ai-commit-generation.png)

git-auto-push.sh 완전 자동 작업 모드: ![자동 모드](screenshots/auto-mode.png)

명령줄 PR 생성 흐름: ![PR CLI](screenshots/pr-screenshot-cli.png)

GitHub 웹 PR 생성 결과: ![PR Web](screenshots/pr-screenshot-web.png)

## 라이선스

이 프로젝트는 MIT 라이선스에 따라 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.
