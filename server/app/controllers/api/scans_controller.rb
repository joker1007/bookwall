# frozen_string_literal: true

module Api
  class ScansController < BaseController
    def create
      library = Library.find(params[:library_id])
      ScanLibraryJob.perform_later(library.id)
      head :accepted
    end
  end
end
