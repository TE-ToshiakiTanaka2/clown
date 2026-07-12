# API Specification: #16 Enemy AI and pixel-art overhaul

## Enemy Interfaces

| Name | Signature | Contract |
| --- | --- | --- |
| `defeat_by_shell` | `() -> void` | Idempotent optional interface for nodes in `enemies`. |
| `EnemyProjectile.initialize` | `(direction: Vector2) -> void` | Direction is normalized; near-zero input becomes horizontal. |
| `Cannon.active_projectile_count` | `() -> int` | Returns live tracked projectiles after pruning invalid references. |

## Signals

| Owner | Signal | Description |
| --- | --- | --- |
| `EnemyProjectile` | `expired(projectile)` | Emitted exactly once before queueing for every terminal path. |

## State Contracts

### SwoopBat

`PATROL → DIVE → RETURN → PATROL`; any active state may transition to
`DEFEATED`. DIVE has both a duration limit and maximum home distance.

### Spiny

`PATROL → WINDUP → CHARGE → PATROL`; wall collision during CHARGE enters
`STUNNED → PATROL`. Any state may transition to `DEFEATED` by shell.

### Cannon

`IDLE → WARNING → COOLDOWN → IDLE`; WARNING may abort to IDLE when the target is
invalid/out of range. Any state may transition to `DEFEATED`.

## Error Handling

| Case | Result |
| --- | --- |
| Missing Player target | AI stays in patrol/idle; no fire/dive/charge. |
| Projectile limit reached | Cannon skips spawn and enters/keeps cooldown safely. |
| Projectile hits world | Expires without player damage. |
| Projectile hits invincible/dead player | Calls guarded `take_damage`, then expires. |
| Spiny stomp | Calls guarded normal damage; Spiny remains alive. |
