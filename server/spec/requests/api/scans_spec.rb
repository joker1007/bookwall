# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Scans", type: :request do
  let(:user) { create(:user, password: "password123") }
  let(:library) { create(:library, owner: user) }

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

  describe "GET /api/libraries/:library_id/scans" do
    it "requires authentication" do
      delete "/api/session"
      get "/api/libraries/#{library.id}/scans"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the most recent scan logs, newest first" do
      _old = library.scan_logs.create!(status: :succeeded, started_at: 2.days.ago,
        finished_at: 2.days.ago + 1.hour, added_count: 5)
      _new = library.scan_logs.create!(status: :succeeded, started_at: 1.hour.ago,
        finished_at: 30.minutes.ago, added_count: 10)

      get "/api/libraries/#{library.id}/scans"

      expect(response).to have_http_status(:ok)
      added = response.parsed_body["scans"].map { |s| s["added_count"] }
      expect(added).to eq([10, 5])
    end

    it "surfaces the live processed_count from the cache for running scans" do
      store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(store)

      running = library.scan_logs.create!(status: :running, started_at: 1.minute.ago,
        found_count: 100, added_count: 80, updated_count: 20)
      store.write(
        Scanners::LibraryScanner.progress_cache_key(running.id),
        {processed: 45, total: 100}
      )

      get "/api/libraries/#{library.id}/scans"

      payload = response.parsed_body["scans"].first
      expect(payload["status"]).to eq("running")
      expect(payload["processed_count"]).to eq(45)
    end

    it "leaves processed_count nil for finished scans" do
      library.scan_logs.create!(status: :succeeded, started_at: 1.hour.ago,
        finished_at: 30.minutes.ago)
      get "/api/libraries/#{library.id}/scans"
      expect(response.parsed_body["scans"].first["processed_count"]).to be_nil
    end
  end
end
