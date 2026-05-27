require "rails_helper"

RSpec.describe "Api::Scans", type: :request do
  let(:user) { create(:user, password: "password123") }
  let(:library) { create(:library) }

  before do
    post "/api/session",
         params: {email_address: user.email_address, password: "password123"},
         as: :json
  end

  describe "POST /api/libraries/:library_id/scans" do
    it "requires authentication" do
      delete "/api/session"
      post "/api/libraries/#{library.id}/scans"
      expect(response).to have_http_status(:unauthorized)
    end

    it "enqueues a ScanLibraryJob" do
      # test env uses :inline by default; flip to :test so the enqueue itself
      # is what we observe (otherwise the job would also run inline and try
      # to scan a non-existent directory).
      original = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      begin
        expect {
          post "/api/libraries/#{library.id}/scans"
        }.to have_enqueued_job(ScanLibraryJob).with(library.id).on_queue("default")
        expect(response).to have_http_status(:accepted)
      ensure
        ActiveJob::Base.queue_adapter = original
      end
    end

    it "404 when library is missing" do
      post "/api/libraries/999999/scans"
      expect(response).to have_http_status(:not_found)
    end
  end
end
