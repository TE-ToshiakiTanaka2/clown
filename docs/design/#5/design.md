# 設計: #5 ドット絵スプライトアセットの導入

## 方針

- ドット絵は **純 Python 標準ライブラリ**(zlib + struct)で PNG を生成する。PIL / 外部依存は使わない。
- 生成スクリプトと生成物(PNG)の両方をコミットする。再生成は `python3 game/tools/gen_sprites.py`。
- 見た目のみの変更。当たり判定・物理レイヤー・ゲームロジックには手を入れない。

## アセット生成ツール `game/tools/gen_sprites.py`

- スプライトは「文字グリッド + 文字→RGBA凡例」で定義する(可読性・レビュー性重視)。

```python
PLAYER_IDLE = """
....RRRR........
...RRRRRRR......
...SSKSKS.......   # S=skin, K=black(目), R=red(帽子) など
"""
```

- PNG writer: RGBA8、`zlib.compress`、IHDR/IDAT/IEND のみの最小実装。フィルタは 0(None)固定。
- 出力先 `game/assets/sprites/`。**1 アニメフレーム = 1 PNG**(tscn の SpriteFrames 記述を単純にするため。AtlasTexture を使わない)。ただしタイルは 1 枚のアトラス `tiles.png`。

## 生成ファイル一覧(16x16 / プレイヤーは 16x24 可)

| ファイル | 内容 |
|---|---|
| `player_idle.png` `player_run_0..2.png` `player_jump.png` `player_death.png` | 帽子+オーバーオールの人型。16x16 |
| `goomba_walk_0..1.png` `goomba_squashed.png` | 茶色キノコ型 |
| `turtle_walk_0..1.png` `turtle_shell.png` | 緑のカメ(#7 で使用、先行生成) |
| `coin_0..3.png` | 黄色コイン回転 |
| `mushroom.png` `one_up.png` | 赤キノコ / 緑キノコ(#7 で使用) |
| `flag.png` | ポール+三角旗。16x48 |
| `tiles.png` | 16x16 タイルのアトラス(8列xN行): 地上=草付き土/土/レンガ/ハテナ(2)/使用済み/土管4種/雲(左右)/草、地下=暗色の土/レンガ(#8 用パレット違いを同居させてよい) |

## シーン反映

- `player.tscn` / `goomba.tscn` / `coin.tscn`: `Sprite2D` → `AnimatedSprite2D`(SpriteFrames を tscn 内サブリソースで定義)。
  - player.gd: `_physics_process` 末尾で速度に応じ `idle/run/jump` を切替、`flip_h = velocity.x < 0`。死亡時 `death`。
  - goomba.gd: `walk` ループ、踏まれたら `squashed` 表示(既存の潰れ処理に合わせる)。
  - coin: `spin` 自動再生。
- `flag.tscn`: `Sprite2D` のテクスチャを `flag.png` に差し替え。
- `level_1.tscn`: TileSet の各タイルのテクスチャを `tiles.png` の AtlasTexture 参照(TileSetAtlasSource)へ移行。物理(衝突ポリゴン、physics_layer=world)は既存設定を維持。

## ノードパス互換

`Sprite2D` → `AnimatedSprite2D` 変更でノード名参照が壊れないよう、既存スクリプト内の `$Sprite2D` 参照を全 grep して追随させる。

## 検証

1. `python3 game/tools/gen_sprites.py` — PNG 再生成、差分なしを確認
2. `godot --headless --path game --import`(.import 生成物もコミット)
3. `godot --headless --path game --quit-after 120` — SCRIPT ERROR ゼロ
4. `godot --headless --path game --quit-after 300` 中の debug 出力でアニメ関連エラーがないこと
