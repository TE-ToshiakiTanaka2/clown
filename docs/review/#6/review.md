# クロスエージェントレビュー: #6 タイトル画面とステージ選択画面

- レビュアー: Codex CLI (`gpt-5.6-sol`)
- 実行形態: bwrap サンドボックス不可のため、diff 全文・設計文書・検証ログ同梱のインラインレビュー(`codex exec --sandbox read-only`)。
- 判定: **REQUEST_CHANGES** → 指摘対応後に解消

## 指摘と対応

| 重要度 | 指摘 | 対応 |
|---|---|---|
| Major | `player_died()` / `clear_level()` に遷移中ガードがなく、クリア後 2.5 秒・ゲームオーバー後 2 秒の窓で死亡/クリアが多重受理される(残機が負数化、古いタイマーがタイトル遷移後にステージ選択へ飛ばす等) | `_level_ending` フラグで終端イベントを 1 レベル 1 回に制限し、`_flow_epoch` 世代カウンタで遷移後に残った遅延タイマーを無効化(`_begin_transition()` / `_delayed_transition()`)。SceneTree スモークテストで「クリア窓中の死亡無視」「ゲームオーバー窓中のクリア無視」「遷移先の正しさ」を検証(FLOW_TEST_PASS) |
| Minor | `ConfigFile.save()` の戻り値を無視 | 失敗時に `push_error` でパスとエラーコードを記録 |
| Minor | `LEVELS` が型なし `Dictionary` | `Dictionary[int, String]` に変更 |
| Minor | architecture.md の「title/stage_select は Game のシグナルに接続」が実装と不一致 | 実態(シグナル接続は HUD のみ、画面は API 呼び出しと状態読み取り)に記述を修正し、多重通知対策の項を追記 |

## 修正後の検証

- `godot --headless --path game --quit-after 120` → SCRIPT ERROR ゼロ
- フロー・スモークテスト(SceneTree スクリプト): title→level1→クリア(重複・窓中死亡無視)→ステージ選択→残機 3 消費→ゲームオーバー(窓中クリア無視)→タイトル(score/lives リセット) すべて PASS
