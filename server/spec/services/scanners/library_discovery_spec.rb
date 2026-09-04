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

  it "prefers book files over loose images in the same directory" do
    dir = File.join(tmpdir, "Volume 1")
    FileUtils.mkdir_p(dir)
    FileUtils.touch(File.join(dir, "cover.jpg"))
    FileUtils.touch(File.join(dir, "vol1.cbz"))
    FileUtils.touch(File.join(dir, "vol1.epub"))

    jobs = discover
    expect(jobs.map { |j| j[:format] }).to contain_exactly(:cbz, :epub)
    expect(jobs.map { |j| j[:path] }).to contain_exactly(
      File.join(dir, "vol1.cbz"), File.join(dir, "vol1.epub")
    )
  end

  it "still treats a subdirectory of images as an image_dir when book files sit in its parent" do
    parent = File.join(tmpdir, "Series")
    child = File.join(parent, "Chapter 1")
    FileUtils.mkdir_p(child)
    FileUtils.touch(File.join(parent, "vol1.cbz"))
    FileUtils.touch(File.join(parent, "cover.jpg"))
    FileUtils.touch(File.join(child, "001.jpg"))

    jobs = discover
    expect(jobs.map { |j| [j[:format], j[:path]] }).to contain_exactly(
      [:cbz, File.join(parent, "vol1.cbz")],
      [:image_dir, child]
    )
  end

  it "scans book files nested below an image_dir" do
    dir = File.join(tmpdir, "Chapter 1")
    nested = File.join(dir, "extras")
    FileUtils.mkdir_p(nested)
    FileUtils.touch(File.join(dir, "001.jpg"))
    FileUtils.touch(File.join(nested, "bonus.pdf"))

    jobs = discover
    expect(jobs.map { |j| [j[:format], j[:path]] }).to contain_exactly(
      [:image_dir, dir],
      [:pdf, File.join(nested, "bonus.pdf")]
    )
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
