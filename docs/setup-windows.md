# Windows ホスト側セットアップ（Godot GUI プレビュー用）

このドキュメントは、WSL2 上の devcontainer（コンテナ側）で AI（Claude Code /
Codex CLI）が godot-mcp 経由で Godot プロジェクトを操作しつつ、
**GUI でのプレビュー・実行は Windows ホスト側の Godot エディタで行う**
ための手順です。コンテナと Windows の間にネットワークブリッジは存在しません。
プロジェクトファイル（`game/` 配下）を同じ WSL ファイルシステム上で
共有することで連携します。

## 前提

- コンテナ側にインストールされている Godot のバージョンは
  **`4.7-stable`**（`.devcontainer/scripts/setup-godot.sh` の
  `GODOT_VERSION` を参照）です。
- Windows 側にも **同じバージョン** の Godot をインストールしてください。
  バージョンが異なると、シーン/リソースの内部フォーマットや
  `.godot/` インポートキャッシュの互換性で問題が起きる可能性があります。

## 1. Windows に Godot をインストールする

1. 公式サイトから Windows 版をダウンロードします。
   https://godotengine.org/download/windows/
   （または GitHub Releases:
   https://github.com/godotengine/godot/releases/tag/4.7-stable ）
2. 「Standard」版（.NET/Mono 版ではない通常版）の
   `Godot_v4.7-stable_win64.exe` をダウンロードします。
   - コンテナ側は Mono 版を使用していないため、Windows 側も
     Standard 版で揃えてください。
3. ダウンロードした exe はインストーラ不要の単体実行ファイルです。
   任意のフォルダ（例: `C:\Tools\Godot\`）に配置してください。

## 2. プロジェクトの場所を WSL 経由で見つける

このリポジトリはコンテナ内では `/workspace` にバインドマウントされています。
コンテナ（devcontainer）は WSL2 上の Docker で動作しているため、
プロジェクトの実体は WSL ディストリビューションのファイルシステム上、
またはお使いの環境によっては Windows 側のフォルダをバインドマウントした
ものになります。以下の手順で実際の場所を特定してください。

### 2-1. 自分の WSL ディストリビューション名を確認する

Windows の PowerShell またはコマンドプロンプトで以下を実行します。

```powershell
wsl -l -v
```

`*` が付いている、または通常使っているディストリビューション名
（例: `Ubuntu`, `Debian` など）を確認してください。

### 2-2. リポジトリの実パスを確認する

コンテナ内（Claude Code / Codex CLI のターミナル）で以下を実行し、
このリポジトリがホストのどこにあるか確認します。

```bash
# コンテナ内で実行
readlink -f /workspace
```

このリポジトリは Docker Compose の `volumes` で
`.:/workspace` としてバインドマウントされています
（`docker-compose.yml` 参照）。つまり `/workspace` の実体は、
**devcontainer を起動した際にリポジトリを clone/配置した場所**です。

- リポジトリを WSL 側のファイルシステム（例: `~/repos/clown`）に
  clone している場合は、Windows のエクスプローラのアドレスバーに
  以下のように入力してアクセスできます。

  ```
  \\wsl$\<ディストリビューション名>\home\<WSLのユーザー名>\repos\clown\game
  ```

  例: `\\wsl$\Ubuntu\home\yourname\repos\clown\game`

- リポジトリを Windows 側のファイルシステム
  （例: `C:\Users\yourname\repos\clown`）に置き、そこを
  Docker Desktop 経由でマウントしている場合は、そのまま
  Windows のエクスプローラで元のフォルダ（`C:\Users\yourname\repos\clown\game`）
  を開けば同じファイルにアクセスできます。

  どちらのパターンか分からない場合は、コンテナ内で
  `git remote -v` や `pwd` の結果と、実際にリポジトリを clone した
  Windows/WSL 上の場所を突き合わせて確認してください。

### 2-3. Godot エディタでプロジェクトを開く

1. Windows 側の Godot（`Godot_v4.7-stable_win64.exe`）を起動します。
2. プロジェクトマネージャ画面で「インポート」を選択します。
3. 上記で特定したパス配下の `game\project.godot` を選択します。

   ```
   \\wsl$\<ディストリビューション名>\...\clown\game\project.godot
   ```

4. 「インポート & 編集」でエディタを開きます。

## 3. 運用ルール

- **コード/シーンの編集は AI（コンテナ内の Claude Code / Codex CLI +
  godot-mcp）が行い、GUI での見た目確認・実行（プレビュー）は
  Windows 側の Godot で行う**、という役割分担です。
- Windows 側からファイルを直接編集した場合でも Git 管理上は
  問題ありませんが、**Windows 側からコミットはしないでください**。
  コミットは常にコンテナ内（WSL/devcontainer）から行います。
- `game/.godot/` は Godot が生成するインポートキャッシュ用ディレクトリで、
  OS ごとに再生成されます。`game/.gitignore` でリポジトリから除外済みのため、
  コンテナ側と Windows 側でそれぞれ別々の `.godot/` が生成されても
  コンフリクトは起きません。
- Windows 側の Godot でプロジェクトを開くと初回のみアセットの
  再インポートが走り、`game/.godot/` が生成されます。これは正常な
  動作です。

## 4. トラブルシューティング

### `\\wsl$\...` にアクセスできない / パスが見つからない

- WSL2 のディストリビューションが起動していないとネットワークパスが
  見えないことがあります。一度 WSL のターミナル（またはコンテナ）を
  起動した状態で再度アクセスしてください。
- Windows 11 以降では `\\wsl$\` の代わりに `\\wsl.localhost\` が
  使われる場合もあります。どちらか片方でアクセスできない場合は
  もう一方を試してください。

### Godot でプロジェクトを開くとエラー/警告が出る

- Windows 側と Godot のバージョンが一致しているか確認してください
  （`Godot Engine v4.7.stable...` のようにヘルプ→ About から
  バージョン文字列を確認できます）。バージョンが一致していれば、
  通常は再インポートのみで解決します。
- `game/.godot/` が古い/壊れている場合は、そのフォルダを削除して
  Godot エディタで再度開けば再生成されます（Git 管理外なので
  削除しても安全です）。

### シーン/スクリプトの変更が Windows 側に反映されない

- コンテナ内のファイル変更は同じファイルシステム上のファイルへの
  書き込みなので、通常は即座に反映されます。反映されない場合は
  Godot エディタの「ファイルシステム」パネルを再スキャン
  （右クリック→ Reimport、または FileSystem タブの再読み込み）
  してください。

### パフォーマンスが遅い

- `\\wsl$\` 経由のファイルアクセスはネットワーク越しのアクセスに
  近い挙動になるため、Windows のネイティブファイルシステム
  （`C:\...`）上のプロジェクトを直接開く場合に比べて遅くなることが
  あります。プロジェクト規模が大きくなり体感速度が問題になる場合は、
  WSL 側で作業を完結させる、または Docker Desktop の WSL2 バックエンド
  設定を見直すことを検討してください。
