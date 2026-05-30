# frozen_string_literal: true

module Api
  class ScansController < BaseController
    LATEST_LIMIT = 10

    def create
      library = find_owned_library!(params[:library_id])
      ScanLibraryJob.perform_later(library.id)
      head :accepted
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
