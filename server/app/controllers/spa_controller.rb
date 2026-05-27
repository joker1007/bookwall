class SpaController < ActionController::API
  def index
    index_path = Rails.public_path.join("ui/index.html")
    if index_path.exist?
      send_file index_path, type: "text/html; charset=utf-8", disposition: "inline"
    else
      render plain: "Bookwall client bundle is not present. Run `cd client && npm run build`.",
             status: :not_found
    end
  end
end
