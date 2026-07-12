# Project Index: clown

Generated: 2026-07-12

## Project Structure

```text
game/
├── project.godot        # Godot 4.7 project configuration
├── assets/sprites/      # Generated pixel-art textures
├── scenes/              # Screens, levels, actors, pickups, and HUD
├── scripts/             # GDScript gameplay and flow logic
└── tools/               # Deterministic sprite-generation helper
docs/design/             # Shared architecture snapshots and issue deltas
.tarnished/workflows/    # Shared lifecycle contracts
```

## Entry Points

- Game: `game/scenes/title_screen.tscn` — configured by `game/project.godot`.
- Global flow: `game/scripts/game_manager.gd` — `Game` autoload for score, lives, unlocks, and scene transitions.
- Campaign: `game/scenes/stage_select.tscn` → `game/scenes/level_N.tscn`.

## Core Modules

- `game/scripts/player.gd`: movement, SMALL/SUPER state, damage, death, and bounce.
- `game/scripts/goomba.gd`, `turtle.gd`: baseline patrol and stomp/shell enemy behavior.
- `game/scripts/swoop_bat.gd`: bounded flying patrol, targeted dive, and home-return AI.
- `game/scripts/spiny.gd`: armored patrol, telegraphed charge, stun, and shell-only defeat AI.
- `game/scripts/cannon.gd`, `enemy_projectile.gd`: telegraphed ranged AI with bounded live shots and projectile lifetime/distance limits.
- `game/scripts/game_manager.gd`: registry, run state, unlock persistence, and terminal-outcome guards.
- `game/scripts/stage_select.gd`, `hud.gd`: progression UI and status presentation.
- `question_block.gd`, `mushroom.gd`, `coin.gd`: pickups and rewards.
- `flag.gd`, `kill_zone.gd`: level terminal triggers.

## Configuration

- `game/project.godot`: Godot 4.7, 640×360, input actions, physics layers, and `Game` autoload.
- Physics layers: 1 world, 2 player, 3 enemy, 4 pickup.

## Test Coverage

- `game/tests/test_runner.gd`: 226 headless regression checks covering campaign progression, deterministic contact, enemy state machines, projectile bounds/impacts/removal safety, stage distribution, gimmicks, and sprite contracts.
- Verification also includes a clean Godot import, headless main-scene smoke run, and deterministic sprite regeneration.

## Key Dependencies

- Godot Engine 4.7 stable; no third-party runtime add-ons.
