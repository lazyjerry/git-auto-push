---
applyTo: "README.md"
description: "自動產生或更新 README.md 的指令模板"
---

# README.md 生成指令模板

供 AI 代理在專案中自動產生或更新 README.md 的規範與步驟

---

## 指令

分析程式庫並產生或更新 README.md（專案真實可驗證的做法）

---

## 目標

- 分析此程式庫，生成或更新 README.md，使新進開發者能快速完成安裝、啟動與使用。
- 聚焦可由程式碼與文件「直接證實」的知識，避免理想化與空話。

---

## 探勘來源（一次 glob 搜尋，排除 README 自身）

- `**/{AGENT.md,AGENTS.md,CLAUDE.md,CONTRIBUTING.md,DEVELOPING.md,.cursorrules,.windsurfrules,.clinerules,.cursor/rules/**,.windsurf/rules/**,.clinerules/**,docs/**}`
- 專案根目錄的 package 與組建檔（例如 `package.json`、`pyproject.toml`、`go.mod`、`Cargo.toml`、`pom.xml`、`build.gradle`、`Makefile`、`Dockerfile`、`docker-compose.*`、`Taskfile.yml`、`nx.json`、`turbo.json` 等）
- CI/CD 與工具設定（例如 `.github/workflows/**`、`.gitlab-ci.yml`、`.prettierrc*`、`.eslintrc*`、`tsconfig*.json`、`ruff.toml`、`mypy.ini`、`.golangci.yml` 等）

---

## README.md 章節結構

1. **專案簡介（Project Overview）**  
   一句話價值主張 + 主要亮點功能列表。
2. **系統結構（System Architecture）**  
   高層級元件、資料流、主要目錄與模組（可用 tree 格式）。
3. **安裝與啟動（Installation & Getting Started）**
   - clone → install → env → run
   - 需要的環境變數與樣板檔（提供 `.env.example` 路徑）
4. **使用方法（Usage）**
   - 常用指令：dev、test、build、lint、format、type-check
   - 範例操作：至少提供一個 CLI 或 API 範例
5. **使用情境（Scenarios/Examples）**
   - 常見的實際應用方式或範例
6. **錯誤排除（Troubleshooting）**
   - 僅限專案中常見錯誤訊息 → 對應解法或指令
7. **授權條款（License）**
   - 若存在 LICENSE 檔，直接引用
   - 若不存在，預設建立 MIT License

---

## 產出規範

- 只寫專案真實做法；引用實際檔案與目錄（相對路徑）。
- 每個命令給出「可直接複製」的一行版本。
- 範例依實際檔案與工具生成，不要泛用。
- 避免使用 emoji。
- 語氣需正式專業。
- 使用台灣繁體中文，語句通順無誤，避免簡體中文或中國用語。

---

## 驗收核對清單（Done 定義）

- README 使用台灣繁體中文，語句通順無誤，避免簡體中文或中國用語。
- README 中的安裝、啟動、使用方法是驗證過可行的。
- 所有引用檔案與路徑正確無誤。
- 若 README 已存在，智慧合併：保留有效段落，更新過時內容。
- 避免冗長儘量不要重複描述；更詳細內容可連結至 `docs/**`。
- LICENSE 條款已確認存在，若無則自動建立 MIT License。
