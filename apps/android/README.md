# Bookwall Android

Bookwall サーバーの OPDS フィードを参照し、CBZ / EPUB / PDF / 画像ディレクトリを閲覧する Android リーダーアプリ。

## 技術スタック

- Kotlin + Coroutines/Flow、Jetpack Compose + Material 3
- DI: Hilt / 画面遷移: Navigation Compose
- 通信: OkHttp(認証・自己署名証明書) + 自前 OPDS(Atom)パーサ
- 画像: Coil 3(表紙・サムネ・PSE ページ画像、ディスクキャッシュ + カスタム Fetcher でローカル CBZ/PDF ページ描画)
- 永続化: Room(サーバー・書籍別設定・キャッシュ管理) / DataStore(全体設定) / Jetpack Security(認証情報)
- バックグラウンド処理: WorkManager(オフラインキャッシュの DL キュー、進捗のオフライン同期)
- EPUB 描画: foliate-js を WebView に同梱(web reader と同一エンジン → CFI 相互運用。縦書き・ルビ・TOC・フォント設定)
- PDF/CBZ: PSE サーバー配信を主軸、キャッシュ済みはローカル描画(PdfRenderer / ZipFile)

## ビルド要件

- JDK 21(Gradle daemon)/ AGP 9.2.1 / Gradle 9.4.1
- Android SDK: compileSdk 36.1 / minSdk 34 / targetSdk 36
- AGP 9 のビルトイン Kotlin を利用(`org.jetbrains.kotlin.android` は適用しない)
- `gradle.properties` の `android.disallowKotlinSourceSets=false` は KSP + ビルトイン Kotlin の併用フラグ

```sh
./gradlew :app:assembleDebug      # デバッグ APK
./gradlew :app:testDebugUnitTest  # JVM ユニットテスト
./gradlew :app:connectedDebugAndroidTest  # 端末/エミュレータ必須の E2E(Robot パターン)
```

## アーキテクチャの要点

- **ページ供給の抽象化**: 画像リーダーは `PageSource`(`data/reader/`)からページを受け取る。実装は `OpdsPageSource`(PSE ストリーミング)と `LocalCbzPageSource` / `LocalPdfPageSource`(`data/reader/local/`、キャッシュ済みファイルのローカル描画)。ローカル CBZ のページ順はサーバーの CBZ パーサと同じ小文字辞書順で、進捗ページ番号が相互運用できる
- **ローカルファイルオープン**: `LocalBookSourceFactory` が MIME → 拡張子 → マジックバイトで形式判定してファイルを開く。サーバー非依存なので、端末ストレージのファイル直接オープン(将来)にもそのまま使える
- **オフラインキャッシュ**: `data/cache/` の `BookCacheRepository` が Room の `cached_books`(キー = serverId + bookId)と `filesDir/book_cache/` を管理。DL は WorkManager のキュードレイナー(`BookCacheDownloadWorker`、デフォルト Wi-Fi のみ)、上限超過は LRU で削除
- **オープンフローの一元化**: `BookLauncherViewModel` が「キャッシュ済みローカル / PSE ストリーミング / EPUB DL」の分岐を持ち、カタログ・ダウンロード済み画面・ロールオーバーのすべてが同じ経路で開く
- **進捗のオフライン同期**: 進捗保存は dirty フラグ付きで、push 失敗時は `ProgressSyncWorker`(CONNECTED 制約)が再接続時にフラッシュする

## テスト方針

各実装フェーズで Robot パターンの E2E テスト(Compose UI Test)を追加し、画面ごとに Robot
(操作 + 検証 API)を `androidTest/.../robot` に置く。テストは Robot の DSL で記述する。

## 実装フェーズ

- Phase 0: Compose/Hilt 基盤、Robot E2E 基盤 ✅
- Phase 1: OPDS サーバー管理(Basic 認証・SSL/自己署名)+ 認証情報の暗号化保管 ✅
- Phase 2: OPDS クライアント(パーサ + リポジトリ)とカタログ取得 ✅
- Phase 3: カタログ UI(リスト/グリッド・ソート・サムネキャッシュ・詳細・進捗表示) ✅
- Phase 4: 画像系リーダー(PSE 主軸、単ページ・LTR/RTL・タップ送り/中央メニュー・プリロード・スクロールバー)✅
- Phase 4b: 見開き2ページ + 1ページ送り(オフセット)+ リーダー設定シート ✅
- Phase 4c: タップゾーンのカスタマイズ + スクロールバーのサムネ ✅
- Phase 5: EPUB リーダー(Readium 表示の足場: DL→オープン→ナビゲータ表示) ✅
- Phase 5b: EPUB 設定(テーマ/フォントサイズ/縦書き/スクロール)+ TOC + 進捗保存(Locator)✅
- Phase 6: 没入リーダー + 切り欠き/インセット対応・レスポンシブグリッド ✅
- Phase 7a: 進捗同期 push(Bookwall サーバ検出 + ページ系進捗の push 専用同期) ✅
  - OPDS ルートフィードの capability link で Bookwall サーバを検出し、対応サーバのみページ系の読書進捗をサーバへ push する
- EPUB リーダーを foliate-js(WebView 同梱)へ刷新し Readium を撤去 ✅
  - web reader と同一の foliate-js で描画するため EPUB CFI が相互運用可能
  - EPUB 進捗も双方向同期(epub_cfi + fraction を push / 開く時に pull して CFI 復元、最遠進捗で調停)
- カタログ強化: ソート(タイトル/著者/登録日)・クライアント側フィルタ・タグファセット・ナビエントリのサムネ表示 ✅
- リーダーのロールオーバー: 最終ページからカタログ順の次の本を開く ✅
- Phase 7b: オフラインキャッシュ ✅
  - 手動 DL + 読んだ本の自動キャッシュ。WorkManager によるバックグラウンド DL(既定 Wi-Fi のみ)
  - 完全オフラインで動く「ダウンロード済み」画面 + キャッシュ設定(上限超過は LRU で自動削除)
  - オフライン中の読書進捗は再接続時にサーバーへ同期
