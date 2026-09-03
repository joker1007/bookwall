# frozen_string_literal: true

require "rails_helper"
require "zip"

RSpec.describe "Opds::Downloads", type: :request do
  let(:user) { create(:user, password: "password123") }
  let(:auth_header) { basic_auth_header }
  let(:library_path) { Rails.root.join("spec/fixtures/files").to_s }
  let(:library) { create(:library, path: library_path, owner: user) }

  describe "GET /opds/books/:book_id/file.:format" do
    it "serves an EPUB with the .epub extension in the URL" do
      book = create(:book,
        library: library,
        file_format: :epub,
        title: "Sample EPUB",
        file_path: "sample.epub")

      get "/opds/books/#{book.id}/file.epub", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/epub+zip")
      expect(response.headers["Content-Disposition"]).to include('filename="Sample EPUB.epub"')
    end

    it "serves a CBZ with the .cbz extension" do
      book = create(:book,
        library: library,
        file_format: :cbz,
        title: "Sample CBZ",
        file_path: "sample.cbz")

      get "/opds/books/#{book.id}/file.cbz", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/x-cbz")
      expect(response.headers["Content-Disposition"]).to include('filename="Sample CBZ.cbz"')
    end

    it "rejects format that mismatches the book's actual file_format" do
      book = create(:book,
        library: library,
        file_format: :epub,
        file_path: "sample.epub")

      get "/opds/books/#{book.id}/file.cbz", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:not_found)
    end

    it "packages image_dir books into an on-the-fly CBZ" do
      book = create(:book,
        library: library,
        file_format: :image_dir,
        title: "Image Dir Book",
        file_path: "sample_image_dir")

      get "/opds/books/#{book.id}/file.cbz", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/x-cbz")
      expect(response.headers["Content-Disposition"]).to include('filename="Image Dir Book.cbz"')
      # The CBZ is streamed, not buffered: Rack::ETag would add a weak ETag if it
      # buffered the body to digest it (which is what zip_kit's headers prevent).
      expect(response.headers["ETag"]).to be_nil
      expect(response.headers["X-Accel-Buffering"]).to eq("no")
      # Response body is a real zip with the directory's images repackaged.
      Zip::File.open_buffer(response.body) do |zip|
        names = zip.entries.map(&:name)
        expect(names).not_to be_empty
        names.each { |n| expect(n).to match(/\A\d{4}\.(jpg|jpeg|png|webp|gif)\z/i) }
      end
    end

    it "rejects an image_dir download requested with a non-cbz format" do
      book = create(:book,
        library: library,
        file_format: :image_dir,
        file_path: "sample_image_dir")

      get "/opds/books/#{book.id}/file.epub", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      book = create(:book,
        library: library,
        file_format: :epub,
        file_path: "sample.epub")

      get "/opds/books/#{book.id}/file.epub"
      expect(response).to have_http_status(:unauthorized)
    end

    describe "byte ranges" do
      let(:book) { create(:book, library: library, file_format: :cbz, title: "Sample CBZ", file_path: "sample.cbz") }
      let(:full) { Rails.root.join("spec/fixtures/files/sample.cbz").binread }

      it "advertises range support and a strong ETag on the full response" do
        get "/opds/books/#{book.id}/file.cbz", headers: {"Authorization" => auth_header}

        expect(response).to have_http_status(:ok)
        expect(response.headers["Accept-Ranges"]).to eq("bytes")
        expect(response.headers["ETag"]).to match(/\A"[^"]+"\z/)
      end

      it "streams a 206 partial response for a suffix range" do
        get "/opds/books/#{book.id}/file.cbz", headers: {"Authorization" => auth_header, "Range" => "bytes=10-"}

        expect(response).to have_http_status(:partial_content)
        expect(response.headers["Content-Range"]).to eq("bytes 10-#{full.bytesize - 1}/#{full.bytesize}")
        expect(response.headers["Content-Length"]).to eq((full.bytesize - 10).to_s)
        expect(response.media_type).to eq("application/x-cbz")
        expect(response.headers["Content-Disposition"]).to include('filename="Sample CBZ.cbz"')
        expect(response.body.b).to eq(full.byteslice(10..))
      end

      it "resumes when If-Range matches the ETag" do
        get "/opds/books/#{book.id}/file.cbz", headers: {"Authorization" => auth_header}
        etag = response.headers["ETag"]

        get "/opds/books/#{book.id}/file.cbz",
          headers: {"Authorization" => auth_header, "Range" => "bytes=5-9", "If-Range" => etag}

        expect(response).to have_http_status(:partial_content)
        expect(response.body.b).to eq(full.byteslice(5, 5))
      end

      it "serves the whole file when If-Range does not match the ETag" do
        get "/opds/books/#{book.id}/file.cbz",
          headers: {"Authorization" => auth_header, "Range" => "bytes=5-9", "If-Range" => '"stale"'}

        expect(response).to have_http_status(:ok)
        expect(response.headers["Content-Range"]).to be_nil
        expect(response.body.bytesize).to eq(full.bytesize)
      end

      it "returns 416 for an unsatisfiable range" do
        get "/opds/books/#{book.id}/file.cbz",
          headers: {"Authorization" => auth_header, "Range" => "bytes=#{full.bytesize + 10}-"}

        expect(response).to have_http_status(:range_not_satisfiable)
        expect(response.headers["Content-Range"]).to eq("bytes */#{full.bytesize}")
      end

      it "ignores Range for streamed image_dir downloads" do
        dir_book = create(:book, library: library, file_format: :image_dir, file_path: "sample_image_dir")

        get "/opds/books/#{dir_book.id}/file.cbz", headers: {"Authorization" => auth_header, "Range" => "bytes=10-"}

        expect(response).to have_http_status(:ok)
        expect(response.headers["Content-Range"]).to be_nil
      end
    end
  end
end
