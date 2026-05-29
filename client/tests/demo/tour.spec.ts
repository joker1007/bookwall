import { fileURLToPath } from "node:url";
import { test, expect } from "../e2e/helpers/test-base";

// One continuous "guided tour" recorded as a single .webm. The whole
// journey is one test so the video doesn't split per BrowserContext:
//   signup → register library → scan → grid/list browse →
//   CBZ reader → horizontal EPUB reader → vertical EPUB reader.
//
// UI is forced to Japanese; pacing comes from slowMo (config) plus the
// `beat()` pauses at scene boundaries below. No synthetic cursor / captions.

// Same depth as tests/e2e/reader.spec.ts: ../../../ from a spec file is the
// repo root, then the canonical fixtures dir (cbz / epub / vertical epub / pdf).
const FIXTURES_PATH = fileURLToPath(
  new URL("../../../server/spec/fixtures/files", import.meta.url),
);

type ApiBook = {
  id: number;
  title: string;
  file_format: string;
  series_name: string | null;
  authors: { id: number; name: string }[];
};

test("Bookwall guided tour", async ({ page, setLanguage, signup }) => {
  test.slow();
  const beat = (ms = 1200) => page.waitForTimeout(ms);

  // --- 0. 日本語 UI でサインアップ -------------------------------------
  await setLanguage("ja");
  await signup();
  await beat();

  // --- 1. ライブラリ登録 (UI 操作で見せる) -----------------------------
  await page.goto("/ui/settings/libraries");
  await page.getByRole("button", { name: "追加", exact: true }).click();
  const dialog = page.getByRole("dialog");
  await expect(dialog).toBeVisible();
  await dialog.locator("#lib-name").fill("サンプル書庫");
  await dialog.locator("#lib-path").fill(FIXTURES_PATH);
  await beat(800);
  await dialog.getByRole("button", { name: "保存", exact: true }).click();
  await expect(dialog).toBeHidden();
  // 一覧にパスが出ているのを確認
  await expect(page.getByText(FIXTURES_PATH)).toBeVisible();
  await beat();

  // 作成したライブラリ id を取得 (スキャン完了の API ポーリングに使う)
  const libsRes = await page.request.get("/api/libraries");
  expect(libsRes.ok()).toBeTruthy();
  const { libraries } = (await libsRes.json()) as { libraries: { id: number }[] };
  const libraryId = libraries[0].id;

  // --- 2. スキャン (UI 操作で見せる) -----------------------------------
  // test_e2e は ActiveJob inline なのでスキャンは POST 内で同期実行され、表紙
  // 生成込みで fixtures (5 冊) は実測 ~11s。その間スキャンボタンは disabled
  // (pulsing) になる。完了は UI バッジ (React Query の更新タイミング依存で
  // 不安定) ではなく scans API を直接ポーリングして確実に待つ。
  await page.getByRole("button", { name: "スキャン", exact: true }).click();
  await expect
    .poll(
      async () => {
        const r = await page.request.get(`/api/libraries/${libraryId}/scans`);
        if (!r.ok()) return "pending";
        const { scans } = (await r.json()) as { scans: { status: string }[] };
        return scans[0]?.status ?? "none";
      },
      { timeout: 90_000, intervals: [1000, 2000, 2000] },
    )
    .toBe("succeeded");
  await beat(1500);

  // --- 3. book id を取得 (裏で API、画面遷移なし) ----------------------
  const booksRes = await page.request.get(`/api/books?library_id=${libraryId}`);
  expect(booksRes.ok()).toBeTruthy();
  const { books } = (await booksRes.json()) as { books: ApiBook[] };

  const cbz = books.find((b) => b.file_format === "cbz");
  const epubs = books.filter((b) => b.file_format === "epub");
  const haystack = (b: ApiBook) =>
    `${b.title} ${b.series_name ?? ""} ${b.authors.map((a) => a.name).join(" ")}`;
  const verticalEpub = epubs.find((b) => /蜘蛛|芥川/.test(haystack(b)));
  const horizontalEpub = epubs.find((b) => b !== verticalEpub);

  expect(cbz, "fixtures should contain a CBZ book").toBeTruthy();
  expect(horizontalEpub, "fixtures should contain a horizontal EPUB").toBeTruthy();
  expect(verticalEpub, "fixtures should contain the vertical JP EPUB").toBeTruthy();

  // --- 4. 一覧表示 (グリッド → リスト) ---------------------------------
  await page.goto(`/ui/libraries/${libraryId}`);
  await expect(page.locator("article").first()).toBeVisible();
  await beat(1500);
  // グリッド/リスト切替 (Radix ToggleGroupItem。role 非依存に aria-label で掴む)
  await page.locator('[aria-label="リスト表示"]').click();
  await beat(1500);
  await page.locator('[aria-label="グリッド表示"]').click();
  await beat(1200);

  // --- 5. CBZ リーダー --------------------------------------------------
  await page.goto(`/ui/books/${cbz!.id}/read`);
  // ヘッダーの戻るボタンとページ画像が出れば描画完了
  await expect(page.getByRole("button", { name: "戻る", exact: true })).toBeVisible();
  await expect(page.locator(`img[src*="/api/books/${cbz!.id}/pages/"]`).first()).toBeVisible();
  await beat(1200);
  // 数ページ送り (Space)
  for (let i = 0; i < 3; i++) {
    await page.keyboard.press("Space");
    await beat(900);
  }
  // 設定シートを開いて見開きトグルを軽く見せる
  await page.getByRole("button", { name: "リーダー設定", exact: true }).click();
  await expect(page.getByRole("dialog").getByText("見開き表示")).toBeVisible();
  await beat(1500);
  await page.keyboard.press("Escape"); // 設定シートを閉じる
  await beat(800);
  await page.getByRole("button", { name: "戻る", exact: true }).click();
  await beat();

  // --- 6. 横書き EPUB リーダー -----------------------------------------
  await page.goto(`/ui/books/${horizontalEpub!.id}/read`);
  await expect(page.getByRole("button", { name: "戻る", exact: true })).toBeVisible();
  await expect(page.locator("foliate-view")).toBeAttached();
  // ready になると下部スクラバー (aria-label) が出る
  await expect(page.getByLabel("位置にジャンプ")).toBeVisible({ timeout: 20_000 });
  await beat(1200);
  for (let i = 0; i < 3; i++) {
    await page.keyboard.press("Space");
    await beat(1000);
  }
  // 目次を開いて閉じる
  await page.getByRole("button", { name: "目次", exact: true }).click();
  await beat(1500);
  await page.keyboard.press("Escape");
  await beat(800);
  await page.getByRole("button", { name: "戻る", exact: true }).click();
  await beat();

  // --- 7. 縦書き EPUB リーダー (RTL/縦組みは自動適用) ------------------
  await page.goto(`/ui/books/${verticalEpub!.id}/read`);
  await expect(page.getByRole("button", { name: "戻る", exact: true })).toBeVisible();
  await expect(page.locator("foliate-view")).toBeAttached();
  await expect(page.getByLabel("位置にジャンプ")).toBeVisible({ timeout: 20_000 });
  await beat(1500);
  // 縦書きでも Space は常に「次へ」。数ページ送って縦組み表示を見せる。
  for (let i = 0; i < 3; i++) {
    await page.keyboard.press("Space");
    await beat(1100);
  }
  // 設定で書字方向が縦書きとして扱われているのを見せる
  await page.getByRole("button", { name: "リーダー設定", exact: true }).click();
  await expect(page.getByRole("dialog").getByText("書字方向")).toBeVisible();
  await beat(1800);
  await page.keyboard.press("Escape");
  await beat(1500); // 締めの余韻
});
