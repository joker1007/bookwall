# frozen_string_literal: true

require "rails_helper"
require "zip"

RSpec.describe Parsers::EpubParser do
  let(:path) { Rails.root.join("spec/fixtures/files/sample.epub").to_s }
  subject(:parser) { described_class.new(path) }

  describe "#metadata" do
    it "extracts title and creators from OPF" do
      meta = parser.metadata
      expect(meta[:title]).to eq("Alice's Adventures in Wonderland")
      expect(meta[:authors]).to include("Lewis Carroll")
    end

    it "exposes page_count equal to spine size" do
      expect(parser.metadata[:page_count]).to eq(parser.page_count)
      expect(parser.page_count).to be > 0
    end

    it "maps dc:subject entries to tags" do
      expect(parser.metadata[:tags]).to contain_exactly(
        "Fantasy fiction",
        "Children's stories",
        "Imaginary places -- Juvenile fiction",
        "Alice (Fictitious character from Carroll) -- Juvenile fiction"
      )
    end
  end

  describe "#metadata with calibre series tags" do
    let(:tmpdir) { Dir.mktmpdir("bookwall-epub-calibre-") }
    let(:path) do
      inject_opf2_meta(
        Rails.root.join("spec/fixtures/files/sample.epub").to_s,
        File.join(tmpdir, "calibre.epub"),
        {"calibre:series" => "Wonderland Series", "calibre:series_index" => "3.0"}
      )
    end

    after { FileUtils.remove_entry(tmpdir) }

    it "extracts series and volume from calibre meta" do
      meta = parser.metadata
      expect(meta[:series]).to eq("Wonderland Series")
      expect(meta[:volume]).to eq(3)
    end

    context "when calibre:series_index is missing" do
      let(:path) do
        inject_opf2_meta(
          Rails.root.join("spec/fixtures/files/sample.epub").to_s,
          File.join(tmpdir, "calibre.epub"),
          {"calibre:series" => "Wonderland Series"}
        )
      end

      it "still surfaces the series but leaves volume nil" do
        expect(parser.metadata[:series]).to eq("Wonderland Series")
        expect(parser.metadata[:volume]).to be_nil
      end
    end

    context "when calibre:series_index is non-numeric" do
      let(:path) do
        inject_opf2_meta(
          Rails.root.join("spec/fixtures/files/sample.epub").to_s,
          File.join(tmpdir, "calibre.epub"),
          {"calibre:series" => "Foo", "calibre:series_index" => "abc"}
        )
      end

      it "treats the volume as absent" do
        expect(parser.metadata[:volume]).to be_nil
      end
    end
  end

  # Copy `source` to `dest`, then patch the OPF inside the EPUB zip with
  # extra OPF2-style `<meta name=... content=.../>` entries so we can
  # cheaply exercise calibre-specific fields without shipping another
  # fixture file.
  def inject_opf2_meta(source, dest, meta_attrs)
    FileUtils.cp(source, dest)
    Zip::File.open(dest) do |zip|
      opf_entry = zip.glob("**/*.opf").first
      raise "no .opf in #{source}" unless opf_entry

      content = opf_entry.get_input_stream.read
      injection = meta_attrs.map { |name, value|
        %(<meta name="#{name}" content="#{value}"/>)
      }.join("\n")
      patched = content.sub("</metadata>", "#{injection}\n</metadata>")

      zip.get_output_stream(opf_entry.name) { |io| io.write(patched) }
    end
    dest
  end

  describe "#page_bytes" do
    it "returns xhtml/html content for spine index 0" do
      bytes = parser.page_bytes(0)
      expect(bytes).to be_a(String)
      expect(bytes.bytesize).to be > 0
    end
  end

  context "with the vertical Japanese EPUB" do
    let(:path) { Rails.root.join("spec/fixtures/files/sample_vertical_jp.epub").to_s }

    it "reads Japanese title and author" do
      meta = parser.metadata
      expect(meta[:title]).to eq("蜘蛛の糸")
      expect(meta[:authors]).to include("芥川龍之介")
    end

    it "exposes language and page-progression-direction" do
      expect(parser.language).to eq("ja")
      expect(parser.page_progression_direction).to eq("rtl")
    end
  end

  context "with a corrupted file" do
    let(:path) do
      tmp = Dir.mktmpdir("bookwall-epub-broken-")
      file = File.join(tmp, "broken.epub")
      File.write(file, "not an epub")
      file
    end

    it "raises Parsers::InvalidFile" do
      expect { described_class.new(path).metadata }.to raise_error(Parsers::InvalidFile)
    end
  end
end
