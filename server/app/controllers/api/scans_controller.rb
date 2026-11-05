# frozen_string_literal: true

module Api
  class ScansController < BaseController
    LATEST_LIMIT = 10

    def create
      library = find_owned_library!(params[:library_id])
      # Created up front so the client sees the scan immediately and keeps polling until the job finishes.
      log = library.scan_logs.create!(status: :pending, started_at: Time.current)
      ScanLibraryJob.perform_later(library.id, log.id)
      render json: ScanLogSerializer.new(log).serializable_hash, status: :accepted
    end

    def index
      library = find_owned_library!(params[:library_id])
      logs = library.scan_logs.order(started_at: :desc).limit(LATEST_LIMIT)
      render json: {
        scans: ScanLogSerializer.new(logs).serializable_hash
      }
    end
  end
end
