require "rails_helper"

RSpec.describe Books::PageStreaming do
  let(:library) { create(:library) }
  let(:book) do
    create(:book,
      library: library,
      file_format: :cbz,
      file_path: Rails.root.join("spec/fixtures/files/sample.cbz").to_s,
      page_count: 4)
  end

  describe ".fetch" do
    it "returns ok with bytes and MIME for a valid index" do
      result = described_class.fetch(book, 0)

      expect(result.status).to eq(:ok)
      expect(result.bytes.bytesize).to be > 1000
      expect(result.content_type).to eq("image/jpeg")
    end

    it "returns the page's actual MIME (image/png for the PNG entry)" do
      result = described_class.fetch(book, 3)
      expect(result.content_type).to eq("image/png")
    end

    it "returns bad_request for a negative index" do
      result = described_class.fetch(book, -1)
      expect(result.status).to eq(:bad_request)
      expect(result.bytes).to be_nil
    end

    it "returns not_found when the parser raises (out-of-range)" do
      result = described_class.fetch(book, 9_999)
      expect(result.status).to eq(:not_found)
    end
  end
end
