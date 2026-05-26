module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    Current.session.present? || Current.api_token.present?
  end

  def require_authentication
    resume_session || authenticate_with_token || render_unauthorized
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    return nil unless cookies.signed[:session_id]
    Session.find_by(id: cookies.signed[:session_id])
  end

  def authenticate_with_token
    header = request.headers["Authorization"].to_s
    return nil unless header.start_with?("Bearer ")
    plain = header.sub(/\ABearer\s+/, "")
    Current.api_token ||= ApiToken.authenticate(plain)
  end

  def start_new_session_for(user)
    user.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    ).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = {
        value: session.id,
        httponly: true,
        same_site: :lax
      }
    end
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_id)
    Current.session = nil
  end

  def render_unauthorized
    render json: {error: "unauthorized"}, status: :unauthorized
  end
end
