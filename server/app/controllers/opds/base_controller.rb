# frozen_string_literal: true

module Opds
  class BaseController < ActionController::API
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include LibraryScoping

    before_action :authenticate_opds_user!

    private

    def authenticate_opds_user!
      bearer_user || basic_user || render_unauthorized
    end

    def bearer_user
      header = request.headers["Authorization"].to_s
      return nil unless header.start_with?("Bearer ")
      token = header.sub(/\ABearer\s+/, "")
      api_token = ApiToken.authenticate(token)
      return nil unless api_token
      Current.api_token = api_token
      api_token.user
    end

    def basic_user
      authenticate_with_http_basic do |email, password|
        user = User.authenticate_by(email_address: email, password: password)
        Current.session = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip) if user
        user
      end
    end

    def render_unauthorized
      response.set_header("WWW-Authenticate", 'Basic realm="Bookwall OPDS"')
      render plain: "Unauthorized", status: :unauthorized
    end

    def render_feed(xml)
      render_compressed_xml(xml, Opds::ACQUISITION_MIME)
    end

    def render_navigation(xml)
      render_compressed_xml(xml, Opds::NAVIGATION_MIME)
    end

    def render_compressed_xml(xml, content_type)
      response.set_header("Vary", "Accept-Encoding")
      # The feed body is its own validator: a weak ETag over the rendered XML.
      # When the client already holds the current revision we return 304 and
      # skip compression entirely, since the body we would have encoded is the
      # one thing a 304 omits.
      return unless stale?(etag: xml)

      encoding, body = Opds::Compression.encode(xml, request.get_header("HTTP_ACCEPT_ENCODING"))
      if encoding
        response.set_header("Content-Encoding", encoding)
        render body: body, content_type: content_type
      else
        render plain: xml, content_type: content_type
      end
    end
  end
end
