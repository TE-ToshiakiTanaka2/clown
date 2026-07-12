# Shared Architecture Snapshot

最終更新: #16（敵AIバリエーション・ドット絵品質刷新）

## リポジトリ構成

- `game/` — Godot 4.7 の2Dプラットフォーマー。タイトル → ステージ選択 →
  `level_1`〜`level_4` の順で進行する。
- `game/scenes/` — 画面、レベル、プレイヤー、5系統の敵、投射物、アイテム、HUD、
  再利用可能な足場／バネ／ハザード。
- `game/scripts/` — エンティティロジックと `Game` オートロード。
- `game/assets/sprites/` — 決定論的に生成されるRGBAピクセルアート。
- `game/tools/gen_sprites.py` — 標準ライブラリのみで全PNGを再生成するソース。
- `game/tests/` — Godot headless で動くルール・AI・アセット・シーン契約テスト。
- `docs/design/shared/` — 累積設計。`docs/design/#N/` — Issue 単位の差分。

## 実行時アーキテクチャ

- **フロー所有者**: `Game` がスコア、残機、現在面、解放面、保存、遷移を管理。
- **レベルレジストリ**: 1〜4 を各 `level_N.tscn` に対応付け、最大キーで最終面と
  保存値の上限を決める。
- **終端イベント**: `_level_ending` と `_flow_epoch` で死亡／クリアの多重処理と
  過去シーンの遅延遷移を防ぐ。
- **プレイヤー探索**: Player は `player` グループへ所属。AIは `_ready()` で単一ターゲットを
  キャッシュし、毎フレームのツリー走査を行わない。
- **接触契約**: 敵ごとにプレイヤー用 Area は1つ。`Player` が `IGNORE` / `STOMP` /
  `DAMAGE` を分類し、敵が状態固有の処理へ変換する。
- **敵系統**:
  - Goomba — 崖を避ける地上巡回。
  - Turtle — WALK/SHELL/SLIDING。
  - SwoopBat — PATROL/DIVE/RETURN。
  - Spiny — PATROL/WINDUP/CHARGE/STUNNED。踏めない。
  - Cannon — IDLE/WARNING/COOLDOWN と上限付き投射物。
- **相互運用**: `enemies` グループのうち対応する敵は `defeat_by_shell()` をduck typingで公開。
- **ダメージ契約**: SMALL は1ミス、SUPER は SMALL 化＋1.5秒無敵。溶岩・落下は
  `die()`、トゲ・敵・投射物は `take_damage()`。
- **ギミック**: solid/moving/falling platform、spring、damage hazard は PackedScene と
  export パラメータで再利用し、レベルスクリプトへ依存しない。

## 投射物境界

- Cannon は `max_active_projectiles` を超えて生成しない。
- Projectile は寿命、最大距離、world/player衝突のいずれかで必ず終了する。
- Projectile の `expired` は一度だけ emit され、Cannon は無効参照を防御的に除去する。
- Cannon が先に解放されても Projectile は独立して安全に終了する。

## ピクセルアート契約

- 主役・敵: 24px幅を基準（SUPER player は24×32）。既存当たり判定は維持。
- タイル・アイテム: 16×16セル契約を維持。旗は16×48。
- near-navyの1px輪郭、shadow/base/highlightの値構造、上左ハイライトを統一。
- 移動キャラクターは原則3フレーム以上。攻撃・警告・敗北は別シルエット。
- Godot は nearest-neighbor (`default_texture_filter=0`) で表示。
- PNGは `gen_sprites.py` と生成物を同時にコミットし、クリーン再生成を検証する。

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
- ステージ選択に基本接触ルールと Bat/Spiny/Cannon の特殊ルールを常時表示する。

## ツールチェーン

- Godot 4.7 stable。初回は `godot --headless --path game --import`。
- アセット検証は `python3 game/tools/gen_sprites.py` を2回実行し差分なしを確認。
- 実行検証はプロジェクト本体、各レベル直接ロード、`game/tests/test_runner.tscn`。
- `SCRIPT ERROR`、parse error、resource load error は失敗として扱う。
