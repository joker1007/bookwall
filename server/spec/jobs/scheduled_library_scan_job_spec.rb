# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScheduledLibraryScanJob, type: :job do
  around do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
    ActiveJob::Base.queue_adapter = original
  end

  it "enqueues a scan only for libraries that opt in" do
    on = create(:library, auto_scan_enabled: true)
    create(:library, auto_scan_enabled: false)

    expect {
      described_class.perform_now
    }.to have_enqueued_job(ScanLibraryJob).with(on.id).exactly(:once)
  end

  it "does nothing when the global daily-scan switch is off" do
    ScheduledTaskSetting.instance.update!(daily_scan_enabled: false)
    create(:library, auto_scan_enabled: true)

    expect {
      described_class.perform_now
    }.not_to have_enqueued_job(ScanLibraryJob)
  end
end
