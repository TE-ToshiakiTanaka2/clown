# Shared Architecture Snapshot

最終更新: #6(タイトル画面とステージ選択画面によるゲームフロー整備)

## リポジトリ構成

- `game/` — Godot 4.7 プロジェクト(2Dプラットフォーマー)。エントリは `scenes/title_screen.tscn` → `scenes/stage_select.tscn` → `scenes/level_N.tscn`。`main.tscn` は #6 で廃止。
- `.tarnished/workflows/` — エージェント中立のライフサイクル文書(issue → design → implement → review → pr)。
- `docs/design/#N/` — Issue ごとの設計成果物。`docs/design/shared/` — プロジェクト全体の累積スナップショット。
- `docs/review/#N/` — クロスエージェントレビュー成果物。

## エージェント分担(dual プロファイル)

| 役割 | エージェント |
|------|--------------|
| 設計 | Claude (Fable) |
| 実装 | Claude (Sonnet 5 サブエージェント) |
| レビュー | Codex CLI (`gpt-5.6-sol`, `.codex/config.toml`) |

## ゲームアーキテクチャ(#6 時点)

- **autoload**: `Game`(`scripts/game_manager.gd`)がスコア・残機・ゲーム進行・画面遷移を集中管理。シーン遷移を跨いで状態維持。
- **結合規約**: エンティティ間の直接参照は避け、`Game` のシグナル(`score_changed`, `lives_changed`, `game_over`, `level_cleared`)経由で HUD/画面へ伝播。
- **物理レイヤー**: 1=world, 2=player, 3=enemy, 4=pickup。
- **シーン責務**: 1シーン=1エンティティ(player / goomba / coin / flag / hud / level_1)+ 画面(title_screen / stage_select)。
- **アート**: `assets/sprites/` のドット絵(#5)。差し替えは各シーンの Sprite2D/AnimatedSprite2D/TextureRect のテクスチャ交換のみで済む構造。

### Game のゲームフロー API(#6)

- `LEVELS: Dictionary[int, String]` — レベル番号→シーンパスのレジストリ。#6 時点は `1: "res://scenes/level_1.tscn"` のみ登録(`2` は #8 で追加)。`max_level()` はレジストリのサイズ由来。
- `current_level: int` — 0 はレベル外(タイトル/ステージ選択)。
- `unlocked_level: int` — 到達可能な最大レベル。`user://save.cfg` に `ConfigFile` で永続化(`_ready` でロード)。
- `start_level(n)` / `retry_level()` / `go_to_title()` / `go_to_stage_select()` / `clear_level()` — すべて `change_scene_to_file` を `call_deferred` 経由で呼ぶため、物理コールバック中でも安全に呼べる。
- 死亡: `lives > 0` なら `retry_level()`、`lives == 0` なら `game_over` emit 後 2 秒(`SceneTreeTimer`)で `go_to_title()`(score/lives リセット)。
- クリア: `level_cleared` emit → `unlocked_level` をレジストリ上限までクランプして更新・保存 → 数秒後に `go_to_stage_select()`(score/lives は維持)。
- タイトルとステージ選択は `Control` ルートの通常シーン(`CanvasLayer` 不要)。HUD 同様、`Game` のシグナルに接続し、ノード解放時に自動切断される通常 `connect` のみを使う(autoload → 一時ノードへの参照保持は禁止)。

## ツールチェーン

- Godot 4.7 headless(`/usr/local/bin/godot`)。検証: `godot --headless --path game --quit-after 120`。
- godot-mcp(Claude: `.mcp.json` / Codex: `.codex/config.toml`)— シーン生成・実行・デバッグ出力取得。
