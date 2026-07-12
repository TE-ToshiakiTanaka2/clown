# Shared Interface Specification

## Game flow

| API | Signature | Contract |
| --- | --- | --- |
| `start_level` | `(n: int) -> void` | Starts only registered and unlocked levels. |
| `retry_level` | `() -> void` | Re-enters current registered level safely. |
| `clear_level` | `() -> void` | Emits once, persists next unlock, returns to selector. |
| `player_died` | `() -> void` | Decrements once; retry above zero, game over at zero. |
| `max_level` | `() -> int` | Highest registry key (4 in the current campaign). |
| `is_final_level` | `() -> bool` | Current level equals the highest registry key. |

## Player gameplay contract

| API | Signature | Contract |
| --- | --- | --- |
| `classify_enemy_contact` | `(enemy_center_y: float) -> ContactOutcome` | Uses player state, position, and bounded recent physics motion. |
| `take_damage` | `() -> bool` | Applies SMALL death or SUPER downgrade at most once. |
| `die` | `() -> bool` | Accepts one death and notifies `Game`; repeats are no-ops. |
| `bounce` | `() -> void` | Applies stomp rebound velocity to a live player. |
| `launch` | `(vertical_velocity: float) -> void` | Applies spring velocity to a live player. |
| `is_dead` | `() -> bool` | Exposes death guard without mutable access. |

## Enemy interoperability

- Enemies join group `enemies`; Player joins group `player`.
- Compatible enemies expose idempotent `defeat_by_shell() -> void`.
- Every physical enemy processes Player through one `ContactArea` callback.
- SwoopBat/Spiny/Cannon cache the first `player` group member and validate it
  with `is_instance_valid()` before access.

## Ranged enemy contract

| API | Signature | Contract |
| --- | --- | --- |
| `EnemyProjectile.initialize` | `(direction: Vector2) -> void` | Stores normalized direction with safe horizontal fallback. |
| `EnemyProjectile.expired` | signal `(projectile)` | Emitted exactly once on every terminal path. |
| `Cannon.active_projectile_count` | `() -> int` | Prunes invalid references and returns count ≤ configured maximum. |

## Asset generation contract

- `python3 game/tools/gen_sprites.py` writes every tracked runtime PNG.
- String-grid sprites must be rectangular and use only declared legend symbols.
- A second generation with unchanged source must produce no byte differences.
