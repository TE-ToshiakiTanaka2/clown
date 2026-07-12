# クロスエージェントレビュー: #5 ドット絵スプライトアセットの導入

- レビュアー: Codex CLI (`gpt-5.6-sol`)
- 実行形態: bwrap サンドボックスが devcontainer 内で動作しないため、`codex exec --sandbox read-only` に diff 全文・設計文書・検証ログを同梱するインラインレビューで実施(シェル実行なし)。
- 判定: **REQUEST_CHANGES** → 指摘対応後に解消

## 指摘と対応

| 重要度 | 指摘 | 対応 |
|---|---|---|
| Major | goomba の `AnimatedSprite2D` に autoplay も `play("walk")` もなく、walk アニメが再生されない | `goomba.tscn` に `autoplay = "walk"` を追加。SceneTree スクリプトによる headless スモークテストで `is_playing()==true` を確認 |
| Major | `tile_map_data` が全セル (0,0)=草タイル参照のままで、土・レンガが未使用 | デコード/再エンコードスクリプトで役割別に再割り当て(y=10 草 176 セル、y=11-12 土 352 セル、y=6-7 レンガ 33 セル) |
| Major | スプライト表示(player 16x24 / goomba 16x16)が当たり判定(20x30 / 22x22)より小さく、接触が透明領域で発生して見える | 物理形状は維持し、表示スケールで一致させた(player 1.25 倍 → 20x30、goomba 1.375 倍 → 22x22)。player にも `autoplay = "idle"` を追加 |
| Minor | 雲タイル左右半分の楕円中心が外側にあり、連結時に中央が透明になる | `tile_cloud` を 32x16 の単一楕円をシーム中心にサンプリングする実装へ修正 |
| Minor | 300 秒相当の長時間実行でのアニメーション検証が未実施 | `--quit-after 400` のクリーン実行と、goomba を単体インスタンス化して `is_playing()` を検証するスモークテストを追加実施 |

## 修正後の検証

- `python3 game/tools/gen_sprites.py` → 20 スプライト再生成
- `godot --headless --path game --import` → 成功
- `godot --headless --path game --quit-after 400` → exit 0、SCRIPT ERROR なし
- goomba 単体スモークテスト → `GOOMBA_PLAYING=true anim=walk`
