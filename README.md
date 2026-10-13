# KIKORI — Snow Trail

雪の森で主人公を動かし、自分で切る・背負う・運ぶ・橋を建てる3D木こりゲーム。Godot 4.5.2 Compatibility / WebGL 2、スマホ縦画面と片手操作が中心です。

この変更は作業ブランチ `feature/snow-lumber-adventure` / [PR #1](https://github.com/dukutogo0101-byte/kikori-godot/pull/1) で検証します。**マージ・公開はしていません。既存PagesのURLはmainの旧経営ゲームです。** 新版を試すにはPRのActionsから `kikori-web` をダウンロードし、下記のHTTPサーバーで開きます。

## 遊び方

- ゲーム領域を押してドラッグすると、その場所に仮想スティックが出ます。指を離すと止まります。PCはWASD／矢印キー、またはマウスのドラッグです。
- 木に近づいて止まると自動で斧を振ります。移動すればすぐ中断します。木のそばの金色の輪と耐久表示は、現在の対象だけに出ます。
- 丸太は近づくと自動で背中へ。荷物は見た目と数値の両方で確認できます。満載でも歩く速さは変わりません。
- 拠点の**金色の売り場**で止まると一本ずつ荷下ろしし、売上が入ります。最初から使えます。
- 右上の「強化」から、斧・リュック・靴を同じ画面で強化できます。費用・上限・次の効果を表示します。メニュー中は作業を停止します。
- **青い建設エリア**で止まると木材を投入します。途中で離れても投入量は残ります。橋の完成前は対岸へ行けません。
- 音と振動は初期OFF。強化画面で任意にONにできます。振動は対応ブラウザのみです。

最初の目標は、雪松を切って6本の丸太を売り、60でリュックを強化すること。その後、橋へ60本を運んで琥珀の森へ進みます。

| 場所・建設 | 木材・効果 |
|---|---|
| 雪松の森 | 耐久3、3本、売値10／本 |
| 森への橋 | 木材60本で完成。琥珀の森を解放 |
| 琥珀カラマツ | 耐久7、4本、売値24／本 |
| 木工工房 | 木材84本で完成。全木材の売値×1.5 |
| 白樺への橋 | 木材120本で完成。銀の森を解放 |
| 銀の白樺 | 耐久12、5本、売値50／本（工房完成後75） |

斧の初回価格90、リュック60、靴80。以降は1.65倍で、初期を含め各7段階です。斧は威力1→7と振る速度、リュックは6→30本、靴は3.2→6.5m/sへ伸びます。木は32／40／48秒で再生し、主人公が切り株に重なる間は再生を待ちます。

## 保存と互換性

3秒ごと、強化・完成時、タブの非表示やフォーカス喪失時に保存します。主人公位置、荷物、地面の資源、伐採途中、強化、建設投入、解放状態を復元します。危険な位置からは安全な拠点へ戻します。

Webのキーは **`kikori.adventure.v2`**、ネイティブは `user://kikori_adventure_v2.json`。旧 `kikori.phase1.v1` / `kikori_save.json` は読み込まず削除もしません。旧資金で序盤が飛ばない別セーブです。**留守中に主人公が作業する処理はありません。** 壊れたデータや異なるバージョンは安全に新規開始し、保存不可ならそのタブ内で続行できます。別端末への同期はありません。

## GUI不要ビルド・起動

Linux x86_64、Python 3、Node.js 18以降が必要です。公式GodotとWebテンプレートをSHA-256で検証します。

```bash
python3 tools/install_godot.py
export PATH="/tmp/kikori-godot-tools:$PATH"
bash tools/build_web.sh
python3 -m http.server 8000 --directory build/web
```

`http://localhost:8000` を開きます。WebAssemblyは `file://` では動きません。Godotエディターなら `project.godot` を開いてF5。既存Godotを使う場合は `GODOT_BIN=/path/to/godot bash tools/build_web.sh`。

ダウンロードした `kikori-web` も全ファイルを同じフォルダーへ展開し、そのフォルダーをHTTPで配信してください。

## 検証

```bash
godot --headless --path . --script tests/test_direct_loop.gd
godot --headless --path . --script tests/test_adventure.gd
godot --headless --path . --script tests/test_scene.gd -- --smoke-test
node tests/test_web_guard.cjs
pip install playwright==1.56.0
python3 -m playwright install --with-deps chromium webkit
python3 tests/browser_smoke.py --engine chromium --full
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a python3 tests/browser_smoke.py --engine webkit
```

経営ルートのテストは移動時間を含め、資源を集めて売り、3種の強化、橋、工房、新しい森を実際の状態更新で通します。通路、売却・建設の保存則、二重ID拒否、購入価格・上限、部分投入の再開、破損データ拒否、地形内からの安全復帰も検証します。シーンテストは入力キャンセルと一時間分の表示プール更新を確認します。

ブラウザテストはGodotの実Web出力に入力し、Chromeではプロトコルのタッチドラッグ、両エンジンではPC操作とUIタップを試します。Chromeの長いルートは橋を完成させ、新しい木を切って売却し、セーブを再読み込みします。状態を変えるゲーム用APIは用意していません。`window.kikoriState` / `window.kikoriUi` は診断用の読み取り要約です。

Actionsの `kikori-test-reports` にJSONと実際のスクリーンショット、`kikori-web` に遊べる出力を保存します。現時点の結果・テンポ・実機未確認項目は [docs/QA.md](docs/QA.md) に記録します。

## 実装と負荷

| 所有者 | 責務 |
|---|---|
| `scripts/main.gd` | シーン接続、保存タイミング、ブラウザライフサイクル |
| `scripts/adventure/definitions.gd` | エリア、木、建設、価格などのデータ |
| `scripts/adventure/game_state.gd` | 60Hzの移動・衝突、資源、経済、建設、厳密な保存検証 |
| `scripts/adventure/player_controller.gd` | タッチ／マウス／キー、入力解除 |
| `scripts/adventure/world_view.gd` | 固定カメラ追従、歩行・伐採・荷物・完成演出 |
| `scripts/adventure/game_ui.gd` / `stick_view.gd` | 小型HUD、強化、目標誘導、スティック |
| `scripts/adventure/feedback.gd` | オリジナル効果音と任意の振動 |
| `scripts/art.gd` | 雪景色・人物・木・橋・建物のオリジナル3Dメッシュ |
| `scripts/save_store.gd` | localStorage / 原子的ファイル保存 |

移動は旧10Hz経営更新を使わず、物理フレームで更新します。カメラは方向を回転せず、画面の上下左右と操作を一致させます。GUIを避けた入力開始、解除時のキー履歴クリア、キャンセル／非表示／回転のリセットで暴走を防ぎます。

一本ごとの資源IDを、地面→荷物→売却／建設へ論理上で一度だけ移します。見た目の飛翔は状態を変更しません。途中保存で飛翔は再現せず、確定済みの資源状態から再開します。丸太の保存則と建設投入総量、伐採回数、売上と購入代金を検証してから一括復元します。

地面の資源は最大160本、荷物30本、飛翔・木くずは固定48スロット。地面と荷物を種類別MultiMeshで表示します。容量不足の丸太は残し、地面の上限が近いと新たな伐採を待ちます。静的な地形と小物を結合し、木はメッシュを共有します。影は1灯1024px、3Dは80%解像度、重い物理・GI・ポスト処理はありません。

Webはシングルスレッドで、SharedArrayBuffer／COOP／COEPは不要。WebKitのフレームバッファ出力対策 `web/framebuffer_guard.js` は保持しています。[上流報告](https://github.com/godotengine/godot/issues/122816)。Android Chrome／iPhone SafariのWebGL 2を対象にしていますが、実機で安定30fpsを測定したとは主張しません。

## CIと公開の境界

PRはビルド・テスト・成果物だけを作ります。`deploy` と `verify-live` はmain以外で実行しません。この依頼ではmainへの直接push、マージ、公開デプロイを行いません。将来マージが承認された場合は、既存mainのActions／Pages自動公開が働く構成です。

有料サービス、APIキー、サーバー、DBは不要。外部作品の素材は使いません。コードと独自素材はMIT、日本語フォントはSIL OFL 1.1。[ASSET_LICENSES.md](ASSET_LICENSES.md) を参照してください。
