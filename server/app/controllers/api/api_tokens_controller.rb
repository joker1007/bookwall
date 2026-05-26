module Api
  class ApiTokensController < BaseController
    def index
      tokens = Current.user.api_tokens.order(created_at: :desc)
      render json: tokens.map { |t| serialize_token(t) }
    end

    def create
      name = params.require(:name)
      token = ApiToken.issue!(
        user: Current.user,
        name: name,
        expires_at: parse_expires_at(params[:expires_at])
      )
      render json: serialize_token(token).merge(token: token.plain_token),
             status: :created
    end

    def destroy
      token = Current.user.api_tokens.find(params[:id])
      token.destroy!
      head :no_content
    end

    private

    def parse_expires_at(raw)
      return nil if raw.blank?
      Time.zone.parse(raw.to_s)
    rescue ArgumentError
      nil
    end

    def serialize_token(token)
      {
        id: token.id,
        name: token.name,
        last_used_at: token.last_used_at,
        expires_at: token.expires_at,
        created_at: token.created_at
      }
    end
  end
end
