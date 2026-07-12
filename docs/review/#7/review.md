# クロスエージェントレビュー: #7 敵・アイテム・ギミックの拡充

- レビュアー: Codex CLI (`gpt-5.6-sol`)
- 実行形態: bwrap サンドボックス不可のため、diff 全文・設計文書・検証ログ同梱のインラインレビュー(`codex exec --sandbox read-only`)。
- 判定: **REQUEST_CHANGES** → 指摘対応後に解消

## 指摘と対応

| 重要度 | 指摘 | 対応 |
|---|---|---|
| Major | カメの `defeat_by_shell()` が `_enter_shell()` を呼ぶだけで撃破にならず、5秒後に WALK 復帰する | 撃破処理を実装: `_defeated` ガード、+200点、甲羅スプライトを上下反転、物理・全 Area 無効化、0.4 秒後に `queue_free()` |
| Major | 甲羅撃破スコアの責務が二重(呼び出し側+100 と goomba 側 `_die(100)` で計200点) | スコア加算は被撃破側の `defeat_by_shell()` に一本化(呼び出し側の加算を削除)。クリボー=100点、カメ=200点 |
| Major | キノコ出現演出中も取得・衝突判定が有効で、ブロック内で即取得可能。終了位置でもブロックと約3px重なる | 上昇中は `PickupArea.monitoring` と `CollisionShape2D` を無効化し、`rise_distance` を 20px に変更して重なりを解消 |
| Minor | SHELL 中に重なっていた敵は蹴った瞬間の `body_entered` が発生せずすり抜ける | `_enter_sliding()` で `get_overlapping_bodies()` を一度スイープ |
| Minor | すべてのキノコが `_ready()` で無条件に出現演出を開始し、直接配置でも 16px 移動する | `@export var rise_from_block: bool = false` を追加し、question_block 側が生成時に true を指定。直接配置は演出なし |
| Minor | `count <= 0` の export 値で最初の一打が中身を1個生成する | `_ready()` で `count <= 0` なら警告を出して初期状態を used に |

## 修正後の検証

- `godot --headless --path game --quit-after 120` → SCRIPT ERROR ゼロ
- 修正対象スモークテスト(SceneTree スクリプト): カメ撃破(+200・物理停止)/甲羅経由クリボー撃破(+100のみ)/直接配置キノコは演出なし/count=0 ブロックは初期 used — すべて PASS
- 実装エージェントによる 17/17 スモークテスト(状態機械・壁反射・被弾API・キノコ・ブロック)も別途 PASS 済み
