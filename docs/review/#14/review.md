# Code Review: #14

- **Branch**: `feature/TE-ToshiakiTanaka2/#14/expand-game-to-four-stages`
- **Base**: `develop` (merge base: `a407cd3`)
- **Review scope**: Large (1,913 insertions, 135 deletions before this artifact)
- **Reviewed at**: 2026-07-12T12:45:19Z
- **Reviewers**: Claude CLI 2.1.207 (cross-agent review) and fresh-context Codex reviewer

---

## Initial Review Summary

**Overall**: REQUEST_CHANGES

## Critical Issues

- [`game/scripts/player.gd`](../../../game/scripts/player.gd): the original
  time-decayed stomp history made `classify_enemy_contact()` timing-dependent.
  The shipped test intermittently classified a forced non-descending contact as
  `STOMP`. Replace elapsed-time decay with a fixed physics-frame contract and
  make the unit fixture explicitly control physics processing.

## Major Issues

- [`game/tests/test_runner.gd`](../../../game/tests/test_runner.gd): no physical
  two-enemy fixture proved that simultaneous Area2D signals consume only one
  life. Add a real overlap test.
- [`game/scripts/game_manager.gd`](../../../game/scripts/game_manager.gd): save
  compatibility and out-of-range clamping were only inferred from an in-memory
  helper. Exercise `_load_progress()` with isolated ConfigFile fixtures.
- [`game/scripts/player.gd`](../../../game/scripts/player.gd): `_do_jump()` did
  not clear recent falling history, allowing an upward jump shortly after a
  descent to be classified as a stomp. Reset contact motion state on every jump.

## Minor Issues

- [`docs/design/#14/design.md`](../../design/#14/design.md): the idempotence
  statement did not carve out intentional instant-miss lava and fall paths.
- [`game/tests/test_runner.gd`](../../../game/tests/test_runner.gd): dead-player
  contact classification and falling-platform trigger re-arming lacked direct
  assertions.
- [`game/scripts/moving_platform.gd`](../../../game/scripts/moving_platform.gd):
  a nonzero phase was applied only on the first physics tick, causing an initial
  teleport. Apply phase in `_ready()` without physics-sync interpolation.

## Suggestions

- Cover Turtle `SHELL` kick and `SLIDING` side-damage/top-stop transitions.
- Continue toward an input-driven stage-completion smoke test when a render/input
  test harness becomes available; current headless coverage validates scene
  loading, geometry contracts, gimmick behavior, and flag presence.

---

## Fixes Applied

- Commit `7b655bc` (`fix: address review feedback for #14`)
  - Replaced the timer-based falling history with a fixed physics-frame window.
  - Stabilized the pure classification fixture by disabling physics updates.
  - Added isolated legacy/out-of-range/negative save-file clamp tests.
  - Added two-enemy simultaneous-contact and dead-contact assertions.
  - Verified falling-platform collision monitoring re-arms after reset.
  - Clarified that lava and fall boundaries intentionally bypass invincibility.
- Commit `84fad34` (`fix: resolve remaining review findings for #14`)
  - Cleared falling history on normal jumps.
  - Applied moving-platform phase during `_ready()` without a first-frame jump.
  - Added Turtle stationary-shell kick, sliding side damage, and sliding top-stop tests.
  - Added phased-platform position continuity coverage.

Verification after fixes:

- `godot --headless --path game --import` — passed.
- Main scene and `level_1.tscn` through `level_4.tscn` — 300-frame direct-load checks passed.
- `godot --headless --path game res://tests/test_runner.tscn` — 107 checks passed.
- Flake audit — the 107-check suite passed 10/10 consecutive runs.

---

## Final Review Summary

**Overall**: APPROVE

## Critical Issues

None.

## Major Issues

None.

## Minor Issues

None.

## Suggestions

None remaining from the final reviewer pass.
