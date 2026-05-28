# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scanners::LibraryDiscovery do
  let(:tmpdir) { Dir.mktmpdir("bookwall-discovery-") }
  after { FileUtils.remove_entry(tmpdir) if File.directory?(tmpdir) }

  def discover
    described_class.new(tmpdir).call
  end

  it "discovers cbz/epub/pdf files and tags each with its format" do
    FileUtils.touch(File.join(tmpdir, "a.cbz"))
    FileUtils.touch(File.join(tmpdir, "b.epub"))
    FileUtils.touch(File.join(tmpdir, "c.pdf"))

    expect(discover.map { |j| j[:format] }).to contain_exactly(:cbz, :epub, :pdf)
  end

  it "treats a directory of images as a single image_dir book" do
    dir = File.join(tmpdir, "Chapter 1")
    FileUtils.mkdir_p(dir)
    FileUtils.touch(File.join(dir, "001.jpg"))
    FileUtils.touch(File.join(dir, "002.png"))

    image_dirs = discover.select { |j| j[:format] == :image_dir }
    expect(image_dirs.map { |j| j[:path] }).to contain_exactly(dir)
  end

  it "skips archive files that live inside an image_dir" do
    dir = File.join(tmpdir, "Chapter 1")
    FileUtils.mkdir_p(dir)
    FileUtils.touch(File.join(dir, "001.jpg"))
    FileUtils.touch(File.join(dir, "extra.cbz"))

    expect(discover.map { |j| j[:format] }).to contain_exactly(:image_dir)
  end

  it "ignores hidden files and directories" do
    FileUtils.touch(File.join(tmpdir, ".hidden.cbz"))
    hidden_dir = File.join(tmpdir, ".trash")
    FileUtils.mkdir_p(hidden_dir)
    FileUtils.touch(File.join(hidden_dir, "x.epub"))

    expect(discover).to be_empty
  end

  it "does not treat loose images at the library root as a book" do
    FileUtils.touch(File.join(tmpdir, "loose.jpg"))
    expect(discover).to be_empty
  end

  it "matches archive extensions case-insensitively" do
    FileUtils.touch(File.join(tmpdir, "UPPER.CBZ"))
    FileUtils.touch(File.join(tmpdir, "Mixed.Epub"))

    expect(discover.map { |j| j[:format] }).to contain_exactly(:cbz, :epub)
  end

  it "matches image extensions case-insensitively when grouping image dirs" do
    dir = File.join(tmpdir, "Chapter 1")
    FileUtils.mkdir_p(dir)
    FileUtils.touch(File.join(dir, "001.JPG"))

    image_dirs = discover.select { |j| j[:format] == :image_dir }
    expect(image_dirs.map { |j| j[:path] }).to contain_exactly(dir)
  end
end
