# Shared Architecture Snapshot

最終更新: #3(2Dマリオ風プラットフォーマー)

## リポジトリ構成

- `game/` — Godot 4.7 プロジェクト(2Dプラットフォーマー)。エントリは `main.tscn` → `scenes/level_1.tscn`。
- `.tarnished/workflows/` — エージェント中立のライフサイクル文書(issue → design → implement → review → pr)。
- `docs/design/#N/` — Issue ごとの設計成果物。`docs/design/shared/` — プロジェクト全体の累積スナップショット。
- `docs/review/#N/` — クロスエージェントレビュー成果物。

## エージェント分担(dual プロファイル)

| 役割 | エージェント |
|------|--------------|
| 設計 | Claude (Fable) |
| 実装 | Claude (Sonnet 5 サブエージェント) |
| レビュー | Codex CLI (`gpt-5.6-sol`, `.codex/config.toml`) |

## ゲームアーキテクチャ(#3 時点)

- **autoload**: `Game`(`scripts/game_manager.gd`)がスコア・残機・ゲーム進行を集中管理。シーンリロードを跨いで状態維持。
- **結合規約**: エンティティ間の直接参照は避け、`Game` のシグナル(`score_changed`, `lives_changed`, `game_over`, `level_cleared`)経由で HUD へ伝播。
- **物理レイヤー**: 1=world, 2=player, 3=enemy, 4=pickup。
- **シーン責務**: 1シーン=1エンティティ(player / goomba / coin / flag / hud / level_1)。
- **アート**: PlaceholderTexture2D による単色プレースホルダー。差し替えは各シーンの Sprite2D テクスチャ交換のみで済む構造。

## ツールチェーン

- Godot 4.7 headless(`/usr/local/bin/godot`)。検証: `godot --headless --path game --quit-after 120`。
- godot-mcp(Claude: `.mcp.json` / Codex: `.codex/config.toml`)— シーン生成・実行・デバッグ出力取得。
