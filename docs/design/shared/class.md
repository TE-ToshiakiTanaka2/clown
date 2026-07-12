# Class Diagram (Project-wide)

```mermaid
classDiagram
    class GameManager {
        +score: int
        +lives: int
        +current_level: int
        +unlocked_level: int
        +start_level(n)
        +player_died()
        +clear_level()
    }
    class Player {
        +PowerState power_state
        +classify_enemy_contact(y) ContactOutcome
        +take_damage() bool
        +die() bool
        +bounce()
        +launch(velocity)
    }
    class Goomba {
        +defeat_by_shell()
    }
    class Turtle {
        +State state
        +defeat_by_shell()
    }
    class SwoopBat {
        +State state
        +defeat_by_shell()
    }
    class Spiny {
        +State state
        +defeat_by_shell()
    }
    class Cannon {
        +State state
        +active_projectile_count() int
        +defeat_by_shell()
    }
    class EnemyProjectile {
        +expired(projectile)
        +initialize(direction)
    }
    class MovingPlatform
    class FallingPlatform
    class Spring
    class DamageHazard {
        +instant_kill: bool
    }
    GameManager --> Player : death / clear signals
    Goomba --> Player : classify and damage
    Turtle --> Player : classify and damage
    SwoopBat --> Player : cache, dive, contact
    Spiny --> Player : cache, charge, dangerous top
    Cannon --> Player : cache and target
    Cannon "1" --> "0..*" EnemyProjectile : bounded spawn / expiry
    EnemyProjectile --> Player : guarded damage
    Spring --> Player : launch
    DamageHazard --> Player : damage or die
```
