# Shared Architecture Snapshot

最終更新: #14（4ステージ化・接触ルール・ステージギミック）

## リポジトリ構成

- `game/` — Godot 4.7 の2Dプラットフォーマー。タイトル → ステージ選択 →
  `level_1`〜`level_4` の順で進行する。
- `game/scenes/` — 画面、レベル、プレイヤー、敵、アイテム、HUD、再利用可能な
  足場／バネ／ハザード。
- `game/scripts/` — エンティティロジックと `Game` オートロード。
- `game/tests/` — Godot headless で動くルール・シーン契約テスト。
- `docs/design/shared/` — 累積設計。`docs/design/#N/` — Issue 単位の差分。

## 実行時アーキテクチャ

- **フロー所有者**: `Game` がスコア、残機、現在面、解放面、保存、遷移を管理。
- **レベルレジストリ**: 1〜4 を各 `level_N.tscn` に対応付け、最大キーで最終面と
  保存値の上限を決める。
- **終端イベント**: `_level_ending` と `_flow_epoch` で死亡／クリアの多重処理と
  過去シーンの遅延遷移を防ぐ。
- **接触契約**: 敵ごとにプレイヤー用 Area は1つ。`Player` が `IGNORE` / `STOMP` /
  `DAMAGE` を分類し、敵が状態固有の処理を行う。
- **ダメージ契約**: SMALL は1ミス、SUPER は SMALL 化＋1.5秒無敵。死亡中／無敵中は
  再ダメージなし。溶岩・落下は `die()`、トゲは `take_damage()`。
- **レベル契約**: 各面は `Player`（Camera2D を内包）、`Flag`、`KillZone`、`HUD` を持つ。
- **ギミック**: solid/moving/falling platform、spring、damage hazard は PackedScene と
  export パラメータで再利用し、レベルスクリプトへ依存しない。

## 物理レイヤー

| Layer | Name | Usage |
| --- | --- | --- |
| 1 | world | 地形・足場 |
| 2 | player | プレイヤー本体 |
| 3 | enemy | 敵本体 |
| 4 | pickup | コイン・アイテム |

Area は必要な body layer のみを mask し、自身の layer は原則0とする。

## 画面と進行

- ステージ選択は4パネルを表示し、`unlocked_level` より大きい面を LOCKED にする。
- クリアすると次の登録面だけを解放し、2.5秒後にステージ選択へ戻る。
- 4面クリア時のみ HUD が全クリア文言を表示する。
- ステージ選択に操作と接触ルールを常時表示する。

## ツールチェーン

- Godot 4.7 stable。初回は `godot --headless --path game --import`。
- 実行検証はプロジェクト本体、各レベル直接ロード、`game/tests/test_runner.gd`。
- `SCRIPT ERROR`、parse error、resource load error は失敗として扱う。
