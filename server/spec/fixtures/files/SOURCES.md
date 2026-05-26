# Test fixtures — sources and licenses

このディレクトリにある電子書籍サンプルファイルの入手元とライセンスを記録する。
いずれも CC-BY 4.0 または public domain のものを利用しているが、再配布する場合は各ライセンスを確認すること。

## sample.cbz — Pepper&Carrot, Episode 1 "The Potion of Flight"

- 入手元: https://archive.org/download/peppercarrot-en/peppercarrot_episode01.cbz
- 配布元アーカイブ: https://archive.org/details/peppercarrot-en
- オリジナル作品サイト: https://www.peppercarrot.com/
- 作者: David Revoy
- ライセンス: Creative Commons Attribution 4.0 International (CC-BY 4.0)
- 内容: 3 ページの JPEG + クレジット PNG が ZIP にまとめられた CBZ。
- 用途: `Parsers::CbzParser` のテスト (ComicInfo.xml 不在ケース、画像エントリ列挙、表紙抽出)。

## sample_image_dir/ — Pepper&Carrot Episode 1 を展開したもの

- 入手元: 上記 `sample.cbz` を `unzip -j` で展開しただけ (再ダウンロードではない)
- ライセンス: 上記と同じ (CC-BY 4.0, David Revoy)
- 用途: `Parsers::ImageDirParser` のテスト (ディレクトリ直下の連番画像列挙、表紙抽出)。

## sample.epub — Alice's Adventures in Wonderland (Project Gutenberg eBook #11, no-images)

- 入手元: https://www.gutenberg.org/ebooks/11.epub.noimages
- 作品ページ: https://www.gutenberg.org/ebooks/11
- 作者: Lewis Carroll
- ライセンス: Public Domain (United States)。Project Gutenberg License による配布 (https://www.gutenberg.org/policy/license.html)
- 内容: 横書き・英語の標準的な EPUB3 (画像なし軽量版)。
- 用途: `Parsers::EpubParser` のテスト (OPF メタデータ抽出、spine 走査、表紙 fallback など)。

## sample_vertical_jp.epub — 芥川龍之介「蜘蛛の糸」(縦書き日本語 EPUB)

- 入手元: https://kyukyunyorituryo.github.io/bookshelf/epub/%5B%E8%8A%A5%E5%B7%9D%E9%BE%8D%E4%B9%8B%E4%BB%8B%5D%20%E8%9C%98%E8%9B%9B%E3%81%AE%E7%B3%B8.epub
- 配布元: 提灯書庫 (https://kyukyunyorituryo.github.io/bookshelf/)
- オリジナルテキスト: 青空文庫 (https://www.aozora.gr.jp/)
- 作者: 芥川龍之介
- ライセンス: Public Domain (著作権切れ)。配布元の青空文庫テキストはパブリックドメイン。
- 内容: `<spine page-progression-direction="rtl">` を持つ縦書き仕様の EPUB3、`dc:language: ja`。`item/standard.opf` 構造で青空文庫 EPUB の典型。
- 用途: `Parsers::EpubParser` で日本語 / 縦書き / 右開き / 著者名読み・タイトル取得のテストに使う。

## sample.pdf — Pepper&Carrot Episode 14 "The Dragon's Tooth" (Free Kids Books 版)

- 入手元: https://freekidsbooks.org/wp-content/uploads/2018/09/Pepper_and_Carrot_Comic_Episode_14_FKB_M.pdf
- 紹介ページ: https://freekidsbooks.org/pepper-and-carrot-episode-14-the-dragons-tooth/
- オリジナル: Pepper&Carrot Episode 14 by David Revoy (https://www.peppercarrot.com/)
- ライセンス: Creative Commons Attribution 4.0 International (CC-BY 4.0)。FKB によるリミックス版。
- 内容: 8 ページのコミック PDF (1.4 MB)。
- 用途: `Parsers::PdfParser` のテスト (ページ数取得、メタデータ、1 ページ目を画像化した表紙抽出)。

---

## 取得手順 (再現用)

```sh
cd server/spec/fixtures/files

curl -sSL -o sample.cbz \
  "https://archive.org/download/peppercarrot-en/peppercarrot_episode01.cbz"

curl -sSL -o sample.epub \
  "https://www.gutenberg.org/ebooks/11.epub.noimages"

curl -sSL -o sample_vertical_jp.epub \
  "https://kyukyunyorituryo.github.io/bookshelf/epub/%5B%E8%8A%A5%E5%B7%9D%E9%BE%8D%E4%B9%8B%E4%BB%8B%5D%20%E8%9C%98%E8%9B%9B%E3%81%AE%E7%B3%B8.epub"

curl -sSL -o sample.pdf \
  "https://freekidsbooks.org/wp-content/uploads/2018/09/Pepper_and_Carrot_Comic_Episode_14_FKB_M.pdf"

unzip -j -o sample.cbz -d sample_image_dir
```
