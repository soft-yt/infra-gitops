# Repository Guidelines

This repository is a documentation and planning workspace for the soft-yt platform. Keep changes focused, well-structured, and easy to review.

## Project Structure & Module Organization
- `plan.md` — primary roadmap (Russian), authoritative source of truth.
- `docs/` — supplementary specs, RFCs, diagrams, and examples. Place images in `docs/assets/` (create if needed).

## Build, Test, and Development Commands
- No build step is required. Use any Markdown preview (e.g., VS Code) for local review.
- Optional quality checks (run only if tools are available):
  - `npx markdownlint .` — lint Markdown style.
  - `npx markdown-link-check plan.md` — validate links in the plan.
  - `npx prettier -w .` — format Markdown/YAML consistently.

## Coding Style & Naming Conventions
- Markdown: ATX headings (`#`), one H1 per file; use `-` for lists; fenced code blocks with language hints (`yaml`, `bash`, `go`, `ts`).
- Indentation: 2 spaces; wrap lines near 120 columns; use relative links.
- Filenames: kebab-case with `.md` (e.g., `docs/gitops-overview.md`).
- Assets: `docs/assets/<topic>/<name>.png` and reference via relative paths.
- Language: narrative in Russian to match `plan.md`; keep code/identifiers in English.

## Testing Guidelines
- Ensure code blocks are copy-pasteable and minimal; prefer runnable, real-world snippets.
- Validate links and anchors before submitting; run the optional checks above when available.
- For YAML, prefer complete snippets; note placeholders like `<IMAGE_TAG>` and avoid real secrets.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `docs:`, `feat:`, `fix:`, `chore:`, `refactor:` (optional scope, e.g., `docs(app-base-go-react): ...`).
- Subject ≤ 72 chars; body explains rationale and references sections of `plan.md` when relevant.
- PRs: concise description, list of affected files/sections, linked issues/tasks, and updated screenshots/diagrams if visuals changed.

## Agent-Specific Instructions
- Keep changes incremental and surgical; do not introduce build systems/CI without discussion.
- Prefer adding new materials under `docs/`; do not rename `plan.md`.
- Never commit secrets; use placeholders like `<TOKEN>` and document how to obtain them.
- When suggesting commands, mark them as optional unless the repo adds tool configs.

