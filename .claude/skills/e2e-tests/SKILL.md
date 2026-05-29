---
name: e2e-tests
description: Run / debug Bookwall の Playwright e2e テスト。dev 環境ではなく test 環境を立ててブラウザ経由で動作検証する手順。
allowed-tools: Bash(npx:*) Bash(npm:*) Bash(bundle:*) Bash(playwright-cli:*) Bash(curl:*)
---

# Bookwall e2e テストの実行フロー

UI / API レベルの動作検証は **dev 環境ではなく e2e 専用の `test_e2e` 環境** で実施する。
dev は普段の手作業用、 e2e は隔離 DB + reset エンドポイント付きで毎テスト前にクリーンになる。

`test_e2e` は `test` を母体にした専用 environment で、DB は `storage/test_e2e.sqlite3`、
Active Storage は `tmp/storage_e2e` を参照する。これにより rspec が使う `test`
(`storage/test.sqlite3` / `tmp/storage`) と永続データが完全に分離され、e2e の残骸が
rspec を汚すことがない (rspec は常に `RAILS_ENV=test`)。

## 構成

| プロセス | ポート | 役割 |
|---|---|---|
| Rails (Falcon) | 3001 | `RAILS_ENV=test_e2e` + `BOOKWALL_E2E_RESET=1` 起動 |
| Vite | 5174 | `BOOKWALL_API_TARGET=http://127.0.0.1:3001` で proxy |

両者は `client/playwright.config.ts` の `webServer` 設定で **`npx playwright test` 実行時に自動起動** する。手動で立てる必要は基本ない (`reuseExistingServer: !CI` なので既に立っていれば再利用)。

bind は `127.0.0.1` — localhost を `::1` だけにマップしている環境を踏まないため。

### 重要な前提

- 個別テストは `tests/e2e/helpers/test-base.ts` の `resetDb` fixture で毎テスト最初に `POST /api/test_support/reset` を投げる。これはルートが `BOOKWALL_E2E_RESET=1` の時にだけマウントされるエンドポイント (`server/app/controllers/api/test_support_controller.rb`)
- 既存 user / session / library / book / Active Storage attachment / blob / variant_record / 等を全削除する。 ActiveStorage は **VariantRecord → Blob** の順で消す必要があるので、新規にテーブルを足したら reset 順序にも追加すること

## よく使うコマンド

すべて `client/` ディレクトリで実行 (cwd を間違えない)。

```bash
cd client

# 全 e2e (desktop + mobile)
npm run test:e2e

# desktop chromium のみ
npx playwright test --project=desktop-chromium

# 1 ファイル
npx playwright test tests/e2e/smoke.spec.ts

# UI モード (対話デバッグ)
npm run test:e2e:ui

# 失敗時にだけ trace と動画が残る (`use: { trace: "retain-on-failure", video: "retain-on-failure" }`)
# trace を開く
npx playwright show-trace test-results/<name>/trace.zip

# HTML レポート
npx playwright show-report
```

## 初回 / 壊れた時の test_e2e DB セットアップ

playwright が自動で `bin/rails db:prepare` を呼ぶので普段は不要。手動で立て直すときは:

```bash
cd server
RAILS_ENV=test_e2e bundle exec rails db:prepare
```

DB がスキーマ不整合で起動できない時:

```bash
cd server
RAILS_ENV=test_e2e bundle exec rails db:drop db:prepare
```

## スキャナや model レベルの動作確認 (Playwright を使わず rails runner で完結)

UI を立ち上げる前にロジックだけ確認したい場合は `rails runner` で `RAILS_ENV=test_e2e` を指定する:

```bash
cd server
RAILS_ENV=test_e2e BOOKWALL_E2E_RESET=1 bundle exec rails runner '
  library = Library.create!(name: "Smoke", path: Rails.root.join("spec/fixtures/files").to_s)
  log = Scanners::LibraryScanner.new(library).call
  puts({status: log.status, books: library.books.count}.inspect)
'
```

ポイント:
- **`BOOKWALL_E2E_RESET=1` を付けておく** — `/api/test_support/reset` が必要な後続テストでルートマウントが効くようにするため (起動した rails runner 自体には不要だが、playwright が後で立てる server で必要)
- runner 実行後に `Library.delete_all` などで掃除しないと、その後 playwright が走ったときに `test_support#reset` が壊れたデータで FK 違反する場合がある。怪しい時は次節の手動 reset を使う

### 残骸を強制的に掃除する

`test_support#reset` がエラーを返す / playwright の最初のテストが `reset failed: HTTP 500` で死ぬ時:

```bash
cd server
RAILS_ENV=test_e2e bundle exec rails runner '
  ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF")
  ActiveStorage::Attachment.delete_all
  ActiveStorage::VariantRecord.delete_all
  ActiveStorage::Blob.delete_all
  Library.delete_all
  Book.delete_all
  ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
  puts "cleaned"
'
```

または `RAILS_ENV=test_e2e bundle exec rails db:drop db:prepare` で完全リセット。

## test fixture

書籍メタやリーダーの実 file が必要なテストでは `server/spec/fixtures/files/` を library のパスとして使える:

| ファイル | 用途 |
|---|---|
| `sample.cbz` | CBZ scanner |
| `sample.epub` | EPUB scanner |
| `sample_vertical_jp.epub` | 縦書き writing-mode |
| `sample.pdf` | PDF scanner |
| `sample_image_dir/` | image_dir scanner |

## デバッグ

- `BOOKWALL_E2E_RESET` が未設定 → `reset failed: HTTP 404` を踏む。 `playwright.config.ts` の webServer command に必ず付ける
- `localhost` vs `127.0.0.1` を混ぜると Node の health check が失敗する。 config の `RAILS_HOST` / `VITE_HOST` がどちらも `127.0.0.1` 固定なのを変えない
- 失敗テストの DOM は `test-results/<test-id>/error-context.md` に snapshot がある
- `webServer: reuseExistingServer: !CI` なので、開発中に手動で `RAILS_ENV=test_e2e bin/rails s -p 3001` を起動しておくと playwright がそれを使う

## ローカルで playwright-cli 単発操作したい時

`playwright-cli open http://127.0.0.1:5174/ui/` で繋げば dev 環境ではなく **test 環境のフロント** に対して手で触れる。 e2e test 環境の状態はテスト毎リセットされるが、 playwright-cli はリセットしないので、状態を作りたければ `playwright-cli` の前に手動で curl の `POST /api/test_support/reset` してから signup → 操作、という流れになる。
