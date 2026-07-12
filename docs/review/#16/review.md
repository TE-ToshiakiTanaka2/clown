# Code Review: #16

- **Branch**: `feature/TE-ToshiakiTanaka2/#16/expand-enemy-ai-and-pixel-art`
- **Base**: `develop` (merge base: `46017ac`)
- **Review scope**: Large (3,414 lines changed)
- **Reviewed at**: 2026-07-12T14:41:38+00:00
- **Reviewer**: Cross-agent review (fresh-context Codex subagent)

---

## Review Summary

**Overall**: REQUEST_CHANGES

## Critical Issues

None.

## Major Issues

- [game/scripts/cannon.gd:102] The projectile is added to the tree before its spawn position is assigned. `EnemyProjectile._ready()` therefore records `_origin` at its default position, not the cannon muzzle. In Stage 4, projectiles from cannons at x=1880 and x=3220 exceed `max_distance` immediately and expire on their first physics tick; the x=520 cannon also receives an incorrect travel bound. Set the projectile position before capturing its origin, or move origin capture into `initialize()` after positioning.
- [game/tests/test_runner.gd:242] The new-enemy tests directly invoke transition methods but omit several required behavioral paths: an actual cannon-spawned projectile’s distance origin, projectile player/world impacts, Spiny wall-to-STUNNED recovery, shell defeat of each new enemy, and target/cannon removal. This allowed the projectile-origin defect to pass all 209 checks despite contradicting the design’s behavior-tested requirement. Add physics-driven integration tests for these paths, including a cannon placed far from the scene origin.

## Minor Issues

- [game/tools/gen_sprites.py:415] `ember_frame(0)` and `ember_frame(1)` generate byte-identical PNGs because the differing tail geometry is completely covered by later drawing. The configured two-frame projectile animation therefore has no visible animation, contrary to the art-direction requirement that frames change weight or silhouette. Adjust exposed flame/tail pixels and assert that animation frames differ.

## Suggestions

None.

---

## Fixes Applied

- Captured projectile distance origin during `initialize()` after Cannon assigns the muzzle position, so Stage 4 shots use a local travel bound.
- Added physics-driven coverage for far-stage Cannon shots, world/player impacts, Spiny wall stun/recovery, shell defeat idempotency, freed targets, and freed Cannon owners.
- Redrew the two ember frames with visibly and byte-distinct tail silhouettes and added an asset-difference assertion.
- Expanded the clean headless regression suite from 209 to 226 passing checks.
- Fix commit: `c91e695`

## Post-fix Validation

**Overall**: APPROVE — the independent cross-agent re-review confirmed all
Critical, Major, and Minor findings are resolved; the expanded suite passes 226
checks and regenerated ember assets are distinct and generator-consistent.
