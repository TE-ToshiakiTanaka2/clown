# 設計: #8 ステージ1リメイク + ステージ2新規作成

## 共通構造

- 各レベルシーンのルート構成は既存 level_1 を踏襲: TileMapLayer(world)、Player、Enemies/、Pickups/、Blocks/、Flag、KillZone、Camera(Player 内蔵 or レベル側 limit 設定)。
- カメラ: Player の Camera2D に `limit_left/right/top/bottom` をレベルごとに設定(レベルスクリプトか export で)。
- レベル寸法: 1 画面 640x360 = 40x22.5 タイル。横スクロールで 1 面 = 幅 200〜260 タイル程度を目安。
- タイル配置は tscn の `tile_map_data` ベタ書きになるため、**レベル生成ヘルパー** `game/tools/gen_level.py` は作らない。代わりに Godot エディタ非依存で管理できるよう、レベルスクリプトから `_ready()` でタイルを組むのではなく、tscn に焼き込む(実装エージェントが座標計算スクリプトを一時的に使って tile_map_data を生成するのは可)。

## ステージ1リメイク (level_1.tscn)

- テーマ: 地上(空色背景、雲・草装飾タイル、緑パイプ)。
- 構成(左→右):
  1. 平地+クリボー1、ハテナ(コイン)
  2. 段差+土管、コイン列
  3. 穴(2〜3タイル幅)+ハテナ(キノコ)
  4. レンガ+ハテナの列(空中足場)、クリボー2連
  5. カメ1体の平地、コイン配置
  6. 階段状の登り → ゴール旗
- 敵: クリボー x4〜5、カメ x1。ブロック: ハテナ x4(コイン x3、キノコ x1)。コイン: 15〜20 枚。
- 落下穴の下に KillZone(既存方式を踏襲し、レベル全幅をカバー)。

## ステージ2新規 (level_2.tscn)

- テーマ: 地下(暗色タイル、黒背景 or 濃紺 ColorRect 背景、雲なし)。
- 高難度要素:
  - 広い穴(4〜5 タイル)+ 空中レンガ足場の連続ジャンプ
  - カメ x2 を含む敵密度高め(クリボー x5〜6、カメ x2)。甲羅で敵をなぎ倒せる直線配置を1箇所用意
  - 天井のある通路(地下らしさ)、天井と床の間の狭い区間
  - ハテナ x4(コイン x2、キノコ x1、1UP x1 — 1UP は隠し気味の高所)
  - コイン 20〜25 枚(一部は穴の上など危険地帯)
- ゴール: 終端で地上に出る演出(天井が開ける)→ 階段 → ゴール旗。

## GameManager

- `LEVELS` レジストリに `2: "res://scenes/level_2.tscn"` を追加。
- クリアフロー: level 2 クリア時は次レベルがないため、クリア演出後ステージ選択へ(unlocked_level はクランプ)。全クリアメッセージ(HUD「ALL CLEAR! THANKS FOR PLAYING」)を level 2 クリア時のみ表示(GameManager に `is_final_level()` ヘルパー)。

## タイル追加(必要なら gen_sprites.py)

- 地下パレットの土/レンガは #5 で生成済み。不足があれば gen_sprites.py に追加(例: 地下の天井向きタイルは既存を流用可)。

## 検証

1. import → `--quit-after 120` SCRIPT ERROR ゼロ
2. 両レベルを `godot --headless` で直接ロード(`godot --headless --path game res://scenes/level_2.tscn --quit-after 300`)し、ロードエラー・物理エラーがないこと
3. ステージ選択 → level 2 遷移の smoke test(#6 の遷移 API 経由)
