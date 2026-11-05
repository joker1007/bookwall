# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScanLibraryJob, type: :job do
  let(:tmpdir) { Dir.mktmpdir("bookwall-scan-job-") }
  let(:library) { create(:library, path: tmpdir) }

  before do
    FileUtils.cp(Rails.root.join("spec/fixtures/files/sample.cbz"), tmpdir)
  end

  after { FileUtils.remove_entry(tmpdir) if File.directory?(tmpdir) }

  it "delegates to LibraryScanner via perform_now" do
    expect {
      described_class.perform_now(library.id)
    }.to change { library.books.count }.by(1)
  end

  it "promotes a given pending scan log instead of creating a new one" do
    log = library.scan_logs.create!(status: :pending, started_at: 1.minute.ago)

    expect {
      described_class.perform_now(library.id, log.id)
    }.not_to change { library.scan_logs.count }

    expect(log.reload).to be_succeeded
    expect(log.added_count).to eq(1)
  end

  it "enqueues onto the default queue" do
    # test env uses :inline by default; switch to :test for this assertion.
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    begin
      expect {
        described_class.perform_later(library.id)
      }.to have_enqueued_job(described_class).on_queue("default")
    ensure
      ActiveJob::Base.queue_adapter = original
    end
  end
end
