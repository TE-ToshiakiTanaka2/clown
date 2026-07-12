# Design: #14 Four-stage campaign, deterministic damage rules, and stage gimmicks

## Context

`game/` is a Godot 4.7 platformer whose `Game` autoload owns score, lives,
level registration, unlock persistence, and scene transitions. Levels 1 and 2
compose reusable player, enemy, pickup, flag, kill-zone, and HUD scenes. The
player has SMALL and SUPER states, but each enemy currently uses two overlapping
areas for stomp and damage, so the order of `body_entered` callbacks can change
the result of one physical contact.

Issue #14 expands the registry and selector to four stages, makes contact
classification a single-path contract, explains those rules in the UI, and adds
reusable world gimmicks. Saved `unlocked_level` remains an integer and is clamped
to the new registry maximum, so old saves remain valid.

## Architecture Overview (delta)

Each enemy exposes exactly one player contact area. On entry, the enemy asks the
`Player` to classify the contact as `STOMP`, `DAMAGE`, or `IGNORE` using death and
invincibility state, downward velocity, and feet position. The enemy then performs
its state-specific stomp behavior or calls `take_damage()`. This removes signal
ordering ambiguity while retaining turtle behavior inside `turtle.gd`.

Reusable solid, moving, and falling platforms, springs, and damage hazards provide
stage primitives. Stage 3 is a sky course emphasizing moving and falling floors;
stage 4 is a castle combining lava, spikes, springs, and moving floors. Both keep
the level contract (`Player`, `Flag`, `KillZone`, and `HUD`).

## Module Structure (delta)

```text
game/
├── scenes/
│   ├── level_3.tscn
│   ├── level_4.tscn
│   ├── solid_platform.tscn
│   ├── moving_platform.tscn
│   ├── falling_platform.tscn
│   ├── spring.tscn
│   └── damage_hazard.tscn
├── scripts/
│   ├── player.gd
│   ├── goomba.gd
│   ├── turtle.gd
│   ├── solid_platform.gd
│   ├── moving_platform.gd
│   ├── falling_platform.gd
│   ├── spring.gd
│   └── damage_hazard.gd
└── tests/
    ├── test_runner.gd
    └── test_runner.tscn
```

## Interface Design (delta)

### Public API / Functions

| Name | Signature | Description |
| --- | --- | --- |
| `Player.classify_enemy_contact` | `(enemy_center_y: float) -> ContactOutcome` | Returns one deterministic result for the current contact. |
| `Player.take_damage` | `() -> bool` | Applies at most one hit and reports whether state changed. |
| `Player.is_dead` | `() -> bool` | Read-only state query. |
| `Player.launch` | `(vertical_velocity: float) -> void` | Applies an upward spring impulse. |
| `Game.max_level` | `() -> int` | Returns the highest registered key, now 4. |

### Type Definitions (delta)

- `Player.ContactOutcome { IGNORE, STOMP, DAMAGE }`.
- `DamageHazard.instant_kill`: true calls `Player.die()` (lava), false calls
  `Player.take_damage()` (spikes).
- Moving platform exports `travel`, `cycle_sec`, and `phase`.
- Falling platform exports `trigger_delay_sec`, `reset_delay_sec`, and `fall_speed`.
- Spring exports `launch_velocity` (negative is upward).

## Data Flow

1. One enemy contact area reports a `Player` entry.
2. The enemy calls `classify_enemy_contact(global_position.y)` once.
3. `STOMP` advances enemy state and bounces the player; `DAMAGE` calls
   `take_damage`; `IGNORE` has no side effect.
4. SMALL damage calls `die` once and `Game.player_died` decrements one life.
   SUPER damage changes to SMALL and starts invincibility without losing a life.
5. Re-entry while dead or invincible resolves to `IGNORE`.

Progression remains flag → `Game.clear_level()` → unlock next registered number →
stage select. Stage 4 is final because `is_final_level()` uses the registry max.

## Error Handling

- All damage/death paths are idempotent for dead or invincible players.
- Platform periods and delays are clamped to positive minimums.
- Missing or locked level requests retain warning-and-return behavior.
- Hazard callbacks ignore non-player bodies.
- Falling platforms reset to origin with velocity and timers reset.

## Implementation Notes

- Preserve physics layers; consolidate only enemy child Areas.
- A stomp requires downward motion and feet at/above the enemy center, preserving
  the existing forgiving threshold without depending on callback order.
- Runtime-sized reusable geometry avoids duplicated collision resources per ledge.
- Stage select states power-up, stomp, lives, and instant-miss rules explicitly.
- Tests cover classifications, damage idempotence, registry, scene contracts, and
  expected stage 3/4 gimmick composition.
