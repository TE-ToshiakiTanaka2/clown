# Shared Data Model Snapshot

## Run State (`Game` autoload)

| Field | Type | Invariant |
| --- | --- | --- |
| `score` | `int` | Non-negative during normal play; reset on title return. |
| `lives` | `int` | Starts at 3; one decrement per accepted death. |
| `current_level` | `int` | 0 outside a level, otherwise a registered key. |
| `unlocked_level` | `int` | Persisted and clamped to 1…`max_level()`. |
| `_level_ending` | `bool` | At most one terminal outcome per scene epoch. |

## Player State

- `PowerState`: `SMALL`, `SUPER`.
- `ContactOutcome`: `IGNORE`, `STOMP`, `DAMAGE`.
- Dead or invincible state makes normal enemy contact resolve to `IGNORE`.
- Player is the single member of group `player` in a level.

## Enemy States

- Goomba: `WALK`, implicit defeated guard.
- Turtle: `WALK`, `SHELL`, `SLIDING`.
- SwoopBat: `PATROL`, `DIVE`, `RETURN`, `DEFEATED`.
- Spiny: `PATROL`, `WINDUP`, `CHARGE`, `STUNNED`, `DEFEATED`.
- Cannon: `IDLE`, `WARNING`, `COOLDOWN`, `DEFEATED`.

## Enemy Projectile

| Field | Type | Invariant |
| --- | --- | --- |
| `direction` | `Vector2` | Normalized and immutable after initialization. |
| `speed` | `float` | Positive exported tuning. |
| `lifetime_sec` | `float` | Positive hard expiry bound. |
| `max_distance` | `float` | Positive travel expiry bound. |
| `_expired` | `bool` | Guards a single terminal signal/queue operation. |

## Sprite Contracts

| Family | Dimensions | Animation minimum |
| --- | --- | --- |
| SMALL Player | 24×24 | idle, run×3, jump, death |
| SUPER Player | 24×32 | idle, run×3, jump |
| Goomba/Turtle | 24×24 | walk×3 plus defeated/state frame |
| SwoopBat | 24×24 | fly×3, dive, defeated |
| Spiny | 24×24 | walk×3, windup, charge |
| Cannon | 24×24 | idle, warning×2, fire |
| Ember projectile | 12×12 or 16×16 | fly×2 |
| Coin/items/tiles | 16×16 cell | existing semantic frames, upgraded art |
| Flag | 16×48 | static |

All images are RGBA8 with transparent outer corners for non-atlas actors.

## Stage Component Configuration

- Platform size and color are exported per instance.
- Moving platforms add travel vector, period, and phase.
- Falling platforms add trigger delay, fall speed, and reset delay.
- Springs add upward launch velocity.
- Damage hazards add size, color, and instant-kill policy.
