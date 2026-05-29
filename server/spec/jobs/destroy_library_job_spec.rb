# frozen_string_literal: true

require "rails_helper"

RSpec.describe DestroyLibraryJob, type: :job do
  it "destroys the library" do
    library = create(:library)

    expect {
      described_class.perform_now(library.id)
    }.to change(Library, :count).by(-1)
  end

  it "is a no-op when the library no longer exists" do
    expect {
      described_class.perform_now(0)
    }.not_to change(Library, :count)
  end

  it "enqueues onto the default queue" do
    # test env uses :inline by default; switch to :test for this assertion.
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    begin
      library = create(:library)
      expect {
        described_class.perform_later(library.id)
      }.to have_enqueued_job(described_class).on_queue("default")
    ensure
      ActiveJob::Base.queue_adapter = original
    end
  end
end
