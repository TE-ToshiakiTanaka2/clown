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
| `classify_enemy_contact` | `(enemy_center_y: float) -> ContactOutcome` | Classification from player state, position, and a fixed recent physics-frame motion window. |
| `take_damage` | `() -> bool` | Applies SMALL death or SUPER downgrade at most once. |
| `die` | `() -> bool` | Accepts one death and notifies `Game`; repeats are no-ops. |
| `bounce` | `() -> void` | Applies stomp rebound velocity to a live player. |
| `launch` | `(vertical_velocity: float) -> void` | Applies spring velocity to a live player. |
| `is_dead` | `() -> bool` | Exposes death guard without mutable access. |

## Enemy interoperability

- Enemies in group `enemies` may expose `defeat_by_shell() -> void`.
- A moving shell calls that method without concrete enemy coupling.
- Each enemy processes a player through exactly one `ContactArea` callback.
