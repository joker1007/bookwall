# frozen_string_literal: true

require "rails_helper"

RSpec.describe Opds::Compression do
  describe ".negotiate" do
    it "returns nil for a blank header" do
      expect(described_class.negotiate(nil)).to be_nil
      expect(described_class.negotiate("")).to be_nil
      expect(described_class.negotiate("   ")).to be_nil
    end

    it "returns nil when nothing supported is offered" do
      expect(described_class.negotiate("compress, identity")).to be_nil
    end

    it "picks the only offered codec" do
      expect(described_class.negotiate("gzip")).to eq("gzip")
      expect(described_class.negotiate("deflate")).to eq("deflate")
      expect(described_class.negotiate("br")).to eq("br")
      expect(described_class.negotiate("zstd")).to eq("zstd")
    end

    it "prefers the server order (zstd > br > gzip > deflate) on equal quality" do
      expect(described_class.negotiate("deflate, gzip, br, zstd")).to eq("zstd")
      expect(described_class.negotiate("deflate, gzip, br")).to eq("br")
      expect(described_class.negotiate("deflate, gzip")).to eq("gzip")
      expect(described_class.negotiate("deflate")).to eq("deflate")
    end

    it "honors client q-values over server preference" do
      expect(described_class.negotiate("zstd;q=0.1, gzip;q=0.9")).to eq("gzip")
    end

    it "skips codecs explicitly disabled with q=0" do
      expect(described_class.negotiate("zstd;q=0, br;q=0, gzip")).to eq("gzip")
    end

    it "uses the wildcard quality as a fallback" do
      expect(described_class.negotiate("*")).to eq("zstd")
      expect(described_class.negotiate("gzip;q=0.2, *;q=0.8")).to eq("zstd")
    end

    it "treats x-gzip as gzip" do
      expect(described_class.negotiate("x-gzip")).to eq("gzip")
    end
  end

  describe ".encode" do
    let(:data) { "<feed>#{"book" * 200}</feed>" }

    it "returns the original data untouched when nothing is acceptable" do
      expect(described_class.encode(data, "identity")).to eq([nil, data])
    end

    it "gzip-encodes and round-trips" do
      encoding, body = described_class.encode(data, "gzip")
      expect(encoding).to eq("gzip")
      expect(body.bytesize).to be < data.bytesize
      expect(Zlib.gunzip(body)).to eq(data)
    end

    it "deflate-encodes and round-trips" do
      encoding, body = described_class.encode(data, "deflate")
      expect(encoding).to eq("deflate")
      expect(body.bytesize).to be < data.bytesize
      expect(Zlib::Inflate.inflate(body)).to eq(data)
    end

    it "brotli-encodes and round-trips" do
      encoding, body = described_class.encode(data, "br")
      expect(encoding).to eq("br")
      expect(Brotli.inflate(body)).to eq(data)
    end

    it "zstd-encodes and round-trips" do
      encoding, body = described_class.encode(data, "zstd")
      expect(encoding).to eq("zstd")
      expect(Zstd.decompress(body)).to eq(data)
    end
  end
end
