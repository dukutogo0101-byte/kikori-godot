# KIKORI — Phase 1

Godot 4.6.3で作る、スマホブラウザ向け3D木こり経営ゲーム。小さな森林のジオラマを眺めながら、伐採 → 丸太の運搬 → 製材 → 売上 → 設備強化の循環を育てます。

公開先（Pagesのデプロイ完了後）： **https://dukutogo0101-byte.github.io/kikori-godot/**

[自動ビルド・テスト・公開の状況](https://github.com/dukutogo0101-byte/kikori-godot/actions/workflows/web.yml)

## 遊び方

- 木こりは自動で木に移動し、斧を振って伐採します。木が倒れ、3本の丸太になります。
- トラックが丸太を積み込み、製材所まで往復します。加工した丸太1本につき12の売上が入ります。
- 画面下の「木こり」「トラック」「製材所」をタップして強化します。費用は各ボタンに表示します。
- 「応援する」で15秒間すべての作業が2倍速になります。再使用は45秒後です。広告・課金はありません。
- 木は24秒で再生します。出荷数10 → 50 → 150 → 500を目指しましょう。
- 森をドラッグすると視点が回転します。ピンチまたはマウスホイールで拡大できます。
- 音は初期状態でOFFです。右上でON/OFFを切り替えられます。

進行は5秒ごと、強化時、画面のフォーカスが外れたときに保存します。同じブラウザ・同じURLで再開してください。留守中の進行は実際の経営シミュレーションで最大10分まで計算します。シークレットモード・サイトデータ削除・別端末への変更では保存が残らない場合があります。保存不可でもそのタブ内では遊べます。

## 対応と描画方針

- **Godot 4 Compatibility / WebGL 2**、GDScript、シングルスレッドWeb出力。SharedArrayBuffer、COOP/COEPヘッダー、サーバー、DBは不要です。
- 対象：WebGL 2対応のAndroid ChromeとiPhone Safari（GodotのWeb要件に合わせ、iOS 16以降を目安に最新ブラウザを推奨）。実機の性能・メモリ制限に依存します。
- 手作りの枝葉、根、切り株、木口、作業員、斧、窓枠、屋根の継ぎ目、製材機、車両、植生、地層を持つオリジナルのローポリ世界です。元のゲームの素材は使用していません。
- 静的な島・道路・製材所を1メッシュに統合。頂点カラーで材質を表現し、大容量テクスチャを避けています。樹木メッシュは共有し、丸太の表示プールは上限付きです。
- 影は1灯・1024px。SSAO、リアルタイムGI、ポストプロセス、剛体物理は使いません。木の転倒やトラックの移動は軽量なアニメーションです。
- 縦画面では下部の操作パネル、横画面では右側の操作パネルに切り替えます。タッチボタンの高さは48pxです。

## ローカル起動・GUI不要ビルド

Linux x86_64、Python 3、Godot 4.6.3、Webエクスポートテンプレートが必要です。

```bash
# 初回のみ：公式配布を取得し、SHA-256で検証します。
python3 tools/install_godot.py
export PATH="/tmp/kikori-godot-tools:$PATH"

# インポート・815項目の経営テスト・シーン起動・Web出力
bash tools/build_web.sh

# WebAssemblyはfile://では動きません。HTTPで配信します。
python3 -m http.server 8000 --directory build/web
```

http://localhost:8000 を開きます。既存Godotを使う場合は `GODOT_BIN=/path/to/godot bash tools/build_web.sh` と指定できます。

Godotエディターでは `project.godot` を開いてF6/F5でも起動できます。ネイティブ版は `user://kikori_save.json`、Web版は `localStorage` の `kikori.phase1.v1` に保存します。

## 自動検証

```bash
godot --headless --path . --script tests/test_simulation.gd
godot --headless --path . -- --smoke-test
pip install playwright==1.56.0
python3 -m playwright install --with-deps chromium webkit
python3 tests/browser_smoke.py --engine chromium
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a python3 tests/browser_smoke.py --engine webkit
```

経営テストは丸太の保存則、二重課金防止、強化上限、再生、応援クールダウン、輸送中の保存・復元、破損データの拒否、10分の留守中進行、1時間の最大強化運転、輸送が詰まる状態を検証します。JSONの浮動小数点タイマー比較には1nsの許容差があります。

ブラウザテストは実際のWebGL出力を起動し、タッチで説明を閉じて応援・購入、出荷による収益、リロード後の復元、縦横画面、壊れた保存データからの復帰を確認します。`kikori-test-reports` に結果とスクリーンショット、`kikori-web` に遊べるWeb出力を保存します。診断用の `window.kikoriState` と `window.kikoriUi` は読み取り専用の要約で、ゲーム状態の変更用APIではありません。

Chrome/WebKitのCIは実機の代わりにはなりません。実機チェック項目と現時点の確認範囲は [docs/QA.md](docs/QA.md) を参照してください。

## GitHub Pages

`main` へのpushで `.github/workflows/web.yml` がインポート・テスト・Webビルド・ブラウザ検証を実行し、成功したビルドをPagesにデプロイします。pull requestでは公開せず検証のみ実行します。

初回、GitHub側でPagesが無効の場合は、リポジトリの **Settings → Pages → Build and deployment → Source: GitHub Actions** を設定してください。ワークフローには自動有効化も設定していますが、組織やトークンの権限によって管理者による初回設定が必要な場合があります。その後はActionsの「Run workflow」、または次のpushで再デプロイできます。

公開リポジトリのGitHub Actions・Pagesの無料枠で運用できます。独自ドメイン、外部サービス、APIキー、クラウド課金は不要です。

## 構成

| ファイル | 役割 |
|---|---|
| `scripts/simulation.gd` | ノード非依存の経営シミュレーション、保存データ検証 |
| `scripts/art.gd` | オリジナルの3Dメッシュ・頂点カラーマテリアル |
| `scripts/main.gd` | 描画、アニメーション、レスポンシブUI、入力、効果音 |
| `scripts/save_store.gd` | localStorage / 原子的ファイル保存 |
| `web/shell.html` | 日本語の読み込み画面、再試行、WebGL非対応時の案内 |
| `tools/` | 公式Godot導入・ヘッドレスWebビルド |
| `tests/` | 経営・保存テストと実ブラウザテスト |

Phase 1の範囲は1つの森林・トラック1台・製材所1つ、各20段階の強化です。木こりの人数は最大5人、その後は伐採速度が伸びます。ログ在庫は各240本、装飾の表示本数は負荷を抑えるため上限があります。セーブのクラウド同期、複数の島、広告、課金は含みません。

コードとオリジナル素材はMIT、日本語フォントはSIL OFL 1.1です。詳細は [ASSET_LICENSES.md](ASSET_LICENSES.md) を参照してください。
