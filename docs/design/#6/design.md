# 設計: #6 タイトル画面とステージ選択画面によるゲームフロー整備

## 画面遷移図

```
[Title] --(ui_accept/jump)--> [StageSelect] --(決定)--> [Level N]
   ^                              ^   ^                    |
   |                              |   +--(クリア演出後)-----+
   +--(ゲームオーバー演出後)---------------------------------+
```

## GameManager 拡張 (`scripts/game_manager.gd`)

- 定数:
  - `LEVELS: Dictionary[int, String] = {1: "res://scenes/level_1.tscn", 2: "res://scenes/level_2.tscn"}`
    - #6 時点で level_2.tscn は未作成のため、レジストリには 1 のみ登録し、`max_level()` はレジストリ由来にする(#8 で 2 を追加)。StageSelect は「レジストリにあるが未解放 → ロック表示」「レジストリにない → 非表示 or COMING SOON 表示」どちらでも良いが、2枠は常に表示して LOCKED とする。
- 状態:
  - `current_level: int = 0`(0 = レベル外)
  - `unlocked_level: int = 1`(到達可能な最大レベル)
- API(すべて `call_deferred` 安全):
  - `start_level(n: int)` — score はレベル開始時にリセットしない(ラン継続)。`current_level = n` して `change_scene_to_file`。
  - `retry_level()` — 死亡リスポーン用。`reload_current_scene` を置き換え、`LEVELS[current_level]` を再ロード。
  - `go_to_title()` — `reset_run` 相当(score/lives リセット)+ タイトルへ。
  - `go_to_stage_select()` — スコア・残機は維持したまま遷移。
  - `clear_level()` — 既存シグナルに加え、`unlocked_level = max(unlocked_level, current_level + 1)`(レジストリ上限でクランプ)、永続化、数秒後に `go_to_stage_select()`。
  - 進捗永続化: `user://save.cfg` に `ConfigFile` で `unlocked_level` を保存/ロード(_ready でロード)。
- `player_died()`: lives>0 → `retry_level()`、lives==0 → `game_over` emit 後、2秒後に `go_to_title()`(SceneTreeTimer)。

## タイトル画面 (`scenes/title_screen.tscn` + `scripts/title_screen.gd`)

- CanvasLayer 不要。`Control` ルート、空色背景 `ColorRect`、中央にタイトルロゴ。
- ロゴ: `Label` を大きめフォントサイズ+ `label_settings`(影付き)で表現。タイトル文字列は「CLOWN QUEST」等のオリジナル名(商標回避)。
- 「PRESS START」Label を Tween か Timer で点滅(visible トグル 0.5s)。
- 装飾として #5 のスプライト(player_idle, goomba 等)を `TextureRect`/`Sprite2D` で配置してよい。
- `_unhandled_input`: `ui_accept` または `jump` で `Game.go_to_stage_select()`。

## ステージ選択画面 (`scenes/stage_select.tscn` + `scripts/stage_select.gd`)

- `Control` ルート。横並びのステージパネル x2(`PanelContainer` + `Label "1" / "2"`)。
- カーソル: 選択中パネルを枠色/スケールで強調。`ui_left`/`ui_right`(move_left/move_right も可)で移動。ロック中パネルへは移動可だが決定不可(ブザー的挙動: 軽い揺れ or 無視)。
- ロック表示: `unlocked_level` 未満は "LOCKED" ラベル+暗色。
- `ui_accept`/`jump` で `Game.start_level(selected)`。
- `ui_cancel`(Esc)でタイトルへ戻る。
- HUD 情報(現在スコア・残機)を下部に表示すると親切(任意)。

## main.tscn / project.godot

- `main.tscn` は Level1 直接インスタンスをやめ、`run/main_scene` を `title_screen.tscn` に変更して main.tscn は削除する。
  - ※ 既存 docs の「エントリは main.tscn」が変わるため `docs/design/shared/architecture.md` を更新。
- 入力: `ui_accept`/`ui_left`/`ui_right`/`ui_cancel` は Godot デフォルトで存在するため追加不要。ジャンプキー(Space/W/Up)でも決定できるよう画面スクリプト側で `jump` も見る。

## シグナル残留対策

- 一時シーン(HUD 等)が `Game` のシグナルへ接続する場合、`CONNECT_REFERENCE_COUNTED` は使わず、ノードの `tree_exiting` で自動切断される通常接続(Object 消滅で自動切断)なので問題なし。autoload 側から一時ノードへの参照保持は禁止。
- `player.gd` の `Game.level_cleared.connect(_on_level_cleared)` は connect 済みチェックまたは `_exit_tree` 不要(自動切断)だが、レビューで重複接続がないか確認。

## HUD

- レベルクリア時メッセージは「COURSE CLEAR!」等に。ゲームオーバー時は「GAME OVER」表示 → タイトルへ(GameManager 主導)。

## 検証

1. `godot --headless --path game --import`
2. `--quit-after 120` SCRIPT ERROR ゼロ
3. headless で `Game.go_to_stage_select()` → `Game.start_level(1)` → `Game.clear_level()` の遷移をスクリプト検証(テスト用一時シーン or `--script` で SceneTree ベースの smoke test)が可能なら実施
