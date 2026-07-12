# Workflow: #16 Enemy AI variety and pixel-art quality overhaul

## Implementation Steps

### Step 1: Encode the new art system

- **Action**: Expand shared palette/grid helpers and author upgraded existing plus
  new enemy frames in `gen_sprites.py`; regenerate PNGs.
- **Files**: `game/tools/gen_sprites.py`, `game/assets/sprites/*.png`.
- **Depends on**: Approved art direction in `design.md` and `art-direction.png`.
- **Done when**: All declared dimensions/frame names exist, silhouettes are
  visually distinct, and a second clean generation produces no diff.

### Step 2: Update existing actor scenes

- **Action**: Add third Goomba/Turtle walk frames, replace textures, normalize
  sprite scale, and add Player to the target group.
- **Files**: player/goomba/turtle scripts and scenes.
- **Depends on**: Step 1.
- **Done when**: Existing collision contracts remain stable and animations load.

### Step 3: Implement flying and charging AI

- **Action**: Create SwoopBat and Spiny scenes with explicit state machines,
  contact policies, cached target lookup, and shell defeat.
- **Files**: `swoop_bat.gd/.tscn`, `spiny.gd/.tscn`.
- **Depends on**: Step 1 and Player group from Step 2.
- **Done when**: Dive/return and windup/charge/stun transitions are bounded and
  deterministic in headless tests.

### Step 4: Implement ranged AI

- **Action**: Create Cannon and EnemyProjectile, warning/cooldown animation,
  bounded active-shot tracking, world/player impact, and lifetime/range expiry.
- **Files**: `cannon.gd/.tscn`, `enemy_projectile.gd/.tscn`.
- **Depends on**: Steps 1–2.
- **Done when**: Cannon never exceeds its configured active projectile count and
  every terminal projectile path releases a slot.

### Step 5: Recompose stages and communicate rules

- **Action**: Add enemy ext-resources/instances to stages 2–4 and expand selector
  enemy tips while preserving progression and traversal geometry.
- **Files**: `level_2.tscn`–`level_4.tscn`, `stage_select.tscn`.
- **Depends on**: Steps 3–4.
- **Done when**: Stage distribution matches the design table and every special
  enemy rule is visible before play.

### Step 6: Expand automated verification

- **Action**: Add enemy state, contact policy, projectile bound/lifetime, stage
  distribution, image dimension, transparency, and frame-count checks.
- **Files**: `game/tests/test_runner.gd`.
- **Depends on**: Steps 1–5.
- **Done when**: New paths are behavior-tested rather than only scene-loaded.

### Step 7: Build, inspect, analyze, and improve

- **Action**: Regenerate twice, import, run main/all levels/tests, inspect native
  sprite output, run a flake audit, and address review findings.
- **Files**: Any touched files when fixes are necessary.
- **Depends on**: Steps 1–6.
- **Done when**: No resource/script errors, regeneration is clean, tests repeat
  reliably, and independent review approves.

## Task Dependencies

- Sprite names/dimensions precede every scene update.
- Player grouping precedes target-aware AI.
- New AI scenes precede level composition and distribution tests.
- Behavioral tests precede quality review and PR.

## Test Strategy

### Unit Tests

- Bat state transitions: patrol detection, dive timeout, return/home, defeat.
- Spiny transitions: patrol, windup, charge direction, wall stun, recovery;
  stomp damages but does not defeat.
- Cannon: target gate, warning, max-active bound, cooldown, defeat.
- Projectile: normalized direction, player/world impact, distance/lifetime expiry,
  single `expired` emission.
- Asset contracts: exact dimensions, alpha corners, required frame files, and at
  least three walk/fly frames where declared.

### Integration Tests

- All new packed scenes instantiate with one ContactArea and expected groups.
- Shell defeats Bat/Spiny/Cannon exactly once.
- Stage 2 contains Bat + Spiny, Stage 3 contains Bat + Spiny, Stage 4 contains
  Cannon + Spiny + Bat.
- Main scene and each level run for sufficient physics frames without errors.
- Two consecutive generator runs yield byte-identical tracked PNGs.

### Edge Cases

- Target is freed during WARNING/DIVE/CHARGE.
- Cannon reaches its active projectile cap.
- Projectile expires while Cannon is already freed.
- Spiny receives a top contact while Player is SUPER/invincible/dead.
- Enemy is shell-defeated while a state timer is active.
- Sprite scale change does not alter collision shape dimensions.
