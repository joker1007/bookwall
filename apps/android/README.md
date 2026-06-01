# Bookwall Android

Bookwall サーバーの OPDS フィードを参照し、CBZ / EPUB / PDF / 画像ディレクトリを閲覧する Android リーダーアプリ。

## 技術スタック

- Kotlin + Coroutines/Flow、Jetpack Compose + Material 3
- DI: Hilt / 画面遷移: Navigation Compose
- 通信: OkHttp(認証・自己署名証明書) + 自前 OPDS(Atom)パーサ
- 画像: Coil 3(表紙・サムネ・PSE ページ画像、ディスクキャッシュ)
- 永続化: Room(サーバー・書籍別設定) / DataStore(全体設定) / Jetpack Security(認証情報)
- EPUB 描画: Readium Kotlin Toolkit(縦書き・ルビ・TOC・フォント設定)
- PDF/CBZ: PSE サーバー配信を主軸、ダウンロード済みはローカル描画(PdfRenderer / Zip)

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

リーダーは供給元を `BookSource` で抽象化する:

- `OpdsBookSource` … PSE ページ配信 / EPUB 全文ダウンロード(初期実装)
- `LocalFileBookSource` … 端末内ファイル(将来追加。IF のみ先行用意)

## テスト方針

各実装フェーズで Robot パターンの E2E テスト(Compose UI Test)を追加し、画面ごとに Robot
(操作 + 検証 API)を `androidTest/.../robot` に置く。テストは Robot の DSL で記述する。

## 実装フェーズ

- Phase 0: Compose/Hilt 基盤、Robot E2E 基盤 ✅
- Phase 1: OPDS サーバー管理(Basic 認証・SSL/自己署名)+ 認証情報の暗号化保管 ✅
- Phase 2: OPDS クライアント(パーサ + リポジトリ)とカタログ取得 ✅
- Phase 3: カタログ UI(リスト/グリッド・ソート・サムネキャッシュ・詳細・進捗表示) ✅
- Phase 4: 画像系リーダー(PSE 主軸、単ページ・LTR/RTL・タップ送り/中央メニュー・プリロード・スクロールバー)✅
- Phase 4b: 見開き2ページ + 1ページ送り、タップゾーンのカスタマイズ、スクロールバーのサムネ ← 次
- Phase 5: EPUB リーダー(Readium、TOC・フォント・縦書き・ルビ)
- Phase 6: 目次ジャンプ・端末別レイアウト・ノッチ対応
- Phase 7: オフライン DL・進捗同期の足場・仕上げ
