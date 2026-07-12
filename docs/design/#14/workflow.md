# Workflow: #14 Four-stage campaign, deterministic damage rules, and stage gimmicks

## Implementation Steps

### Step 1: Make the contact contract deterministic

- **Action**: Add player contact outcomes, convert enemies to one contact Area,
  and expose idempotent damage/death results.
- **Files**: `player.gd`, `goomba.gd`, `turtle.gd`, and both enemy scenes.
- **Depends on**: None.
- **Done when**: Every contact enters one callback and matches the rules matrix.

### Step 2: Add reusable stage components

- **Action**: Implement configurable solid, moving, and falling platforms,
  springs, and hazards as packed scenes.
- **Files**: New scripts and scenes under `game/scripts/` and `game/scenes/`.
- **Depends on**: Step 1 for Player damage and launch APIs.
- **Done when**: Components instance independently with exported settings.

### Step 3: Extend progression and explain rules

- **Action**: Register levels 3/4, expand stage select, and add a rules legend.
- **Files**: `game_manager.gd`, `stage_select.gd`, `stage_select.tscn`.
- **Depends on**: None.
- **Done when**: Four stages display with locks and rules are readable.

### Step 4: Author stages 3 and 4

- **Action**: Compose sky and castle levels with terrain, enemies, collectibles,
  goal, kill zone, camera, HUD, and new gimmicks.
- **Files**: `level_3.tscn`, `level_4.tscn`.
- **Depends on**: Steps 2 and 3.
- **Done when**: Both load and contain distinct, traversable gimmick sequences.

### Step 5: Add automated verification

- **Action**: Add a headless runner for rules, progression, and scene contracts.
- **Files**: `game/tests/test_runner.gd`, `game/tests/test_runner.tscn`.
- **Depends on**: Steps 1–4.
- **Done when**: Tests exit 0 and assertion failures exit nonzero.

### Step 6: Build, test, analyze, and improve

- **Action**: Import, run project/levels/tests headlessly, review the diff, and fix findings.
- **Files**: Any files above when fixes are needed.
- **Depends on**: Steps 1–5.
- **Done when**: No script/parse/resource errors and every Issue requirement has evidence.

## Task Dependencies

- Step 2 depends on Step 1 for player-facing contracts.
- Step 4 depends on reusable components and progression updates.
- Step 5 depends on all behavior and scenes it verifies.
- Step 6 is the final quality gate.

## Test Strategy

### Unit Tests

- Descending top, side/upward, dead, and invincible contact classification.
- SUPER downgrade, repeated-hit rejection, SMALL death, and one-life decrement.
- Registry maximum and final-stage detection.

### Integration Tests

- Load all registered scenes and require `Player`, `Flag`, `KillZone`, and `HUD`.
- Require intended gimmick groups in stages 3/4.
- Run the main scene and each level headlessly.

### Edge Cases

- Multiple simultaneous enemies cannot remove multiple lives.
- Sliding shell stops from above but damages from the side.
- Old saves remain valid and out-of-range values clamp to 4.
- Lava/fall is instant miss while spikes use normal damage.
- Falling platforms reset and can trigger again.
