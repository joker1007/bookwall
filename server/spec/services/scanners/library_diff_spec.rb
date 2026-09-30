# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scanners::LibraryDiff do
  let(:library) { create(:library) }

  def absolute(rel)
    File.expand_path(File.join(library.path, rel))
  end

  def diff(jobs)
    described_class.new(library).call(jobs)
  end

  it "classifies a job with no matching book as an add" do
    jobs = [{path: absolute("new.cbz"), format: :cbz, mtime: Time.current}]

    result = diff(jobs)
    expect(result[:add]).to eq(jobs)
    expect(result[:update]).to be_empty
  end

  it "classifies a job newer than the stored scanned_at as an update" do
    create(:book, library: library, file_path: "old.cbz", scanned_at: 2.days.ago)
    jobs = [{path: absolute("old.cbz"), format: :cbz, mtime: 1.hour.ago}]

    result = diff(jobs)
    expect(result[:update].map { |j| j[:path] }).to eq([absolute("old.cbz")])
    expect(result[:add]).to be_empty
  end

  it "leaves a job no newer than the stored scanned_at untouched" do
    create(:book, library: library, file_path: "same.cbz", scanned_at: Time.current)
    jobs = [{path: absolute("same.cbz"), format: :cbz, mtime: 2.days.ago}]

    result = diff(jobs)
    expect(result[:add]).to be_empty
    expect(result[:update]).to be_empty
  end

  context "with an image_dir" do
    let(:library) { create(:library, path: Dir.mktmpdir("library-diff-")) }
    let(:dir) { absolute("comic") }
    let(:jobs) { [{path: dir, format: :image_dir, mtime: nil}] }

    before do
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "001.jpg"), "a")
      File.write(File.join(dir, "002.jpg"), "b")
      set_mtime(3.days.ago, *Dir.glob(File.join(dir, "*")))
      create(:book, library: library, file_path: "comic", file_format: :image_dir, scanned_at: 2.days.ago)
    end

    after { FileUtils.rm_rf(library.path) }

    def set_mtime(time, *paths)
      File.utime(time.to_time, time.to_time, *paths)
    end

    it "updates when an image with an old timestamp is added" do
      File.write(File.join(dir, "003.jpg"), "c")
      set_mtime(3.days.ago, File.join(dir, "003.jpg"))
      set_mtime(1.hour.ago, dir)

      expect(diff(jobs)[:update]).to eq(jobs)
    end

    it "updates when an image is removed" do
      File.delete(File.join(dir, "002.jpg"))
      set_mtime(1.hour.ago, dir)

      expect(diff(jobs)[:update]).to eq(jobs)
    end

    it "leaves an unchanged directory untouched" do
      set_mtime(3.days.ago, dir)

      expect(diff(jobs)[:update]).to be_empty
    end
  end
end
