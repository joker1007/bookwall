# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScheduledCleanupJob, type: :job do
  it "runs the cleaner when the global cleanup switch is on" do
    cleaner = instance_double(Cleanup::OrphanCleaner, call: nil)
    allow(Cleanup::OrphanCleaner).to receive(:new).and_return(cleaner)

    described_class.perform_now

    expect(cleaner).to have_received(:call)
  end

  it "does nothing when the global cleanup switch is off" do
    ScheduledTaskSetting.instance.update!(cleanup_enabled: false)
    allow(Cleanup::OrphanCleaner).to receive(:new)

    described_class.perform_now

    expect(Cleanup::OrphanCleaner).not_to have_received(:new)
  end
end
