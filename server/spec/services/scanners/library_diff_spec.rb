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
end
