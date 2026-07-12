# Implementation Workflow: #3 2Dマリオ風プラットフォーマー

実装担当: Claude Sonnet 5(サブエージェント)。各ステップは依存順。完了条件を満たしてから次へ進む。
コミットは論理単位ごと(conventional commit + `(#3)`)。

## Step 1: プロジェクト設定

- `game/project.godot` に autoload (`Game`)、input map、physics layer 名、表示設定を追記(design.md §7)。
- **完了条件**: `godot --headless --path game --quit` が exit 0(autoload スクリプトは Step 2 で追加するため、本ステップは Step 2 と同一コミットで検証してよい)。

## Step 2: GameManager + HUD

- `scripts/game_manager.gd`(autoload)、`scripts/hud.gd`、`scenes/hud.tscn`。
- **完了条件**: headless ロードでエラーなし。シグナル定義が design.md §4.1 と一致。

## Step 3: Player

- `scripts/player.gd`、`scenes/player.tscn`(コヨーテタイム・ジャンプバッファ・可変ジャンプ含む)。
- **完了条件**: headless ロードでエラーなし。`bounce()` / `die()` が公開されている。

## Step 4: 敵・コイン・旗・キルゾーン

- `scripts/goomba.gd` + `scenes/goomba.tscn`、`scripts/coin.gd` + `scenes/coin.tscn`、`scripts/flag.gd` + `scenes/flag.tscn`、`scripts/kill_zone.gd`。
- **完了条件**: 各シーン単体が headless でロード可能。踏み判定条件が design.md §4.3 と一致。

## Step 5: レベルと main.tscn

- `scenes/level_1.tscn`(TileMapLayer 地形 + エンティティ配置 + KillZone)、`main.tscn` 更新。
- 穴・段差・敵3体・コイン8枚・終端に旗。
- **完了条件**: `godot --headless --path game --quit-after 120` でエラーなし。

## Step 6: 実行検証

- godot-mcp `run_project` → `get_debug_output` → `stop_project`、または `godot --headless --path game --quit-after 300`。
- パースエラー・ランタイムエラー・シグナル接続エラーが 0 件。
- **完了条件**: 検証コマンドとログ要約を報告に含める。

## Step 7: ワークフロー文書統合

- `.tarnished/workflows/design.md` / `implement.md` / `review.md` に godot-mcp 手順を追記(design.md §8 の表に従う)。
- `AGENTS.md` の Codex 向け記述を整合。
- **完了条件**: 文書間で記述が矛盾しない。`.claude/skills/` は変更しない。

## 検証で `is_on_floor()` が効かない場合

TileSet の physics layer(collision_layer=1)と TileData の collision polygon 設定を最初に確認すること(design.md §10)。
