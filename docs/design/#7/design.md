# 設計: #7 敵・アイテム・ギミックの拡充

## 共通: プレイヤー被弾 API (`scripts/player.gd`)

- `enum PowerState { SMALL, SUPER }` / `var power_state := PowerState.SMALL`
- `func take_damage() -> void`:
  - 無敵時間中(`_invincible == true`)は無視
  - SUPER → SMALL に戻し、無敵時間 1.5s(スプライト点滅: AnimatedSprite2D の modulate.a を Tween/Timer でトグル)
  - SMALL → `die()`(既存の死亡処理を集約)
- `func power_up() -> void`: SMALL→SUPER。スプライトを大サイズ(16x24 の super_* フレーム)に切替。SUPER 中の再取得はスコアのみ。
  - CollisionShape は変更しない(簡素化。見た目のみ大きく)— 変更する場合は天井詰まり対策が必要なため #7 では見た目のみとする。
- goomba.gd / turtle の接触ダメージは `player.take_damage()` 呼び出しに統一(既存 goomba.gd の直接死亡処理を置換)。
- #5 で作った player スプライトに `super_idle/run/jump` フレーム追加が必要(gen_sprites.py 拡張、16x24)。

## カメ敵 (`scenes/turtle.tscn` + `scripts/turtle.gd`)

- `CharacterBody2D`、enemy レイヤー。構造は goomba.tscn を踏襲(StompArea/HitArea 方式は既存 goomba に合わせる)。
- 状態機械 `enum State { WALK, SHELL, SLIDING }`:
  - WALK: goomba 同様のパトロール+**崖検知**(進行方向足元の `RayCast2D` が床を失ったら反転)。
  - 踏まれる → SHELL(停止、`shell` スプライト、踏んだプレイヤーはバウンス)。SHELL 中に踏む or 触れる → SLIDING(プレイヤーと反対方向へ speed 220)。
  - SLIDING: 壁(`is_on_wall()`)で反転。他の敵(enemy レイヤーの Area 検知)に当たると相手を撃破(スコア加算)。プレイヤーが横から触れると `take_damage()`、踏むと SHELL に戻す。
  - SHELL 放置 5s で WALK 復帰(任意、実装コスト低なら入れる)。
- 踏み判定: 既存 goomba と同じ「player.feet_global_y() が敵の中心より上」方式で統一。

## キノコ (`scenes/mushroom.tscn` + `scripts/mushroom.gd`)

- `CharacterBody2D`(pickup レイヤー、world とだけ衝突)。重力あり、一定速度(60)で水平移動、壁で反転。崖は落ちる(本家準拠)。
- `@export var kind: Kind`(`SUPER` / `ONE_UP`)。スプライト切替。
- プレイヤー接触(Area2D)で: SUPER → `player.power_up()` + スコア 1000、ONE_UP → `Game.add_life()`(GameManager に `add_life()` 追加、lives_changed emit)。
- ブロックから出現時: 0.5s かけて上にせり上がる演出(Tween、その間は物理無効)→ その後移動開始。

## ハテナブロック (`scenes/question_block.tscn` + `scripts/question_block.gd`)

- `StaticBody2D`(world レイヤー)+ 16x16 矩形衝突 + `AnimatedSprite2D`(question 点滅 2f / used)。
- 下から叩いた検知: ブロック下面直下の薄い `Area2D`(player レイヤーを mask)に player が入り、かつ `player.velocity.y < 0` のとき発火。発火時にブロックを 4px 跳ねさせる Tween。
- `@export var content: Content`(`COIN` / `MUSHROOM` / `ONE_UP`)+ `@export var count: int = 1`(COIN 用)。
  - COIN: スコア+コイン飛び出し演出(coin スプライトを上に飛ばして消す一時ノード)。
  - MUSHROOM/ONE_UP: mushroom.tscn をブロック上に spawn。
- 中身が尽きたら `used` 表示に固定し Area を無効化。

## goomba.gd 改修

- 接触ダメージを `player.take_damage()` 経由に変更。
- 甲羅で撃破されるための `func defeat_by_shell() -> void`(スコア+反転潰れ演出 or 即 queue_free)。turtle からも goomba からも呼べるよう、共通メソッド名 `defeat_by_shell` を敵グループ(`add_to_group("enemies")`)で duck-typing 呼び出し。

## スプライト追加 (gen_sprites.py)

- `super_idle/run_0..2/jump`(16x24)、(turtle/mushroom/one_up/question は #5 で生成済み)。

## 検証

1. gen_sprites.py 再実行 → import → `--quit-after 120` SCRIPT ERROR ゼロ
2. level_1 に turtle / question_block / mushroom を仮配置した検証は #8 で本配置するため、ここでは最小限の動作確認用に level_1 に 1 体ずつ配置してよい(#8 でリメイクされる前提)
