class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Pagy::Method
  include Authentication

  private

  def pagy_metadata(pagy)
    {
      page: pagy.page,
      pages: pagy.pages,
      count: pagy.count
    }
  end
end
