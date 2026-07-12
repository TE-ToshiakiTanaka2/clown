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
- Dead or invincible state makes enemy contact resolve to `IGNORE`.

## Turtle State

- `WALK`: side contact damages; stomp enters `SHELL`.
- `SHELL`: side contact kicks; stomp also kicks after bounce.
- `SLIDING`: side contact damages; stomp stops the shell.

## Stage Component Configuration

- Platform size and color are exported per instance.
- Moving platforms add travel vector, period, and phase.
- Falling platforms add trigger delay, fall speed, and reset delay.
- Springs add upward launch velocity.
- Damage hazards add size, color, and instant-kill policy.
