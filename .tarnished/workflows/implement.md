# Workflow: implement

Implement a GitHub Issue using the design artifacts and existing project conventions.

## Inputs

- GitHub Issue number.
- Shared and per-issue design artifacts.
- Current branch or branch derived from the issue.

## Procedure

1. Load issue details and design artifacts.
2. Index or inspect the relevant code paths before editing.
3. Implement in small, reviewable changes that match existing conventions.
4. Run build, formatting, linting, and tests appropriate to the stack.
   For the Godot project (`game/`), verify with the `godot` MCP server
   (`run_project` → `get_debug_output` → `stop_project`; scene authoring may
   use `create_scene` / `add_node` / `save_scene`). If the MCP server is
   unavailable, fall back to the CLI:

   ```bash
   godot --headless --path game --import        # required once per fresh checkout
   godot --headless --path game --quit-after 120
   ```

   Treat any `SCRIPT ERROR` or parse error in the output as a build failure.
   Note: `--import` must run before execution on a fresh checkout, otherwise
   `class_name` global-class resolution fails with spurious parse errors.
5. Apply quality improvements for correctness, error handling, security, and maintainability.
6. Commit per logical unit of work.

## Output

- Implementation commits.
- Verification summary with commands run and any remaining risks.
