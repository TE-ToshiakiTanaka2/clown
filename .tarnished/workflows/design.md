# Workflow: design

Design the implementation for a GitHub Issue before writing production code.

## Inputs

- GitHub Issue number.
- Existing shared design artifacts under `docs/design/shared/`.
- Relevant codebase context.

## Procedure

1. Read the issue and create or reuse the issue branch.
2. Load shared design artifacts and relevant per-issue artifacts.
3. When the issue touches the Godot project (`game/`), ground the design in the
   actual project state via the `godot` MCP server (`get_godot_version`,
   `get_project_info`) instead of assuming engine or project settings.
4. Research external dependencies only when needed.
5. Write the per-issue design delta under `docs/design/#{issue_number}/`.
6. Regenerate affected shared design snapshots under `docs/design/shared/`.
7. Commit design artifacts separately from implementation changes.

## Output

- `docs/design/#{issue_number}/design.md`
- `docs/design/#{issue_number}/workflow.md`
- Optional API, diagram, and research artifacts.
- Updated shared design snapshots when the issue changes project-wide truth.
