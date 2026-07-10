# frozen_string_literal: true

# Serves cover blobs/variants from disk with send_file so Rack::Sendfile can
# hand the transfer to Thruster via X-Sendfile. Unauthenticated by design,
# matching Active Storage's proxy controllers: possession of a valid signed
# id is the access token.
class CoversController < ActionController::API
  CACHE_CONTROL = "public, max-age=31536000, immutable"

  def blob
    blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
    serve_file blob.service.path_for(blob.key),
      content_type: blob.content_type_for_serving,
      disposition: blob.forced_disposition_for_serving || :inline,
      filename: blob.filename.sanitized
  rescue ActiveSupport::MessageVerifier::InvalidSignature,
         ActiveRecord::RecordNotFound,
         ActiveStorage::Error
    head :not_found
  end

  def thumb
    blob = ActiveStorage::Blob.find_signed!(params[:signed_blob_id])
    representation = blob.representation(params[:variation_key]).processed
    serve_file representation.image.blob.service.path_for(representation.key),
      content_type: representation.content_type_for_serving,
      disposition: representation.forced_disposition_for_serving || :inline,
      filename: representation.filename.sanitized
  rescue ActiveSupport::MessageVerifier::InvalidSignature,
         ActiveRecord::RecordNotFound,
         ActiveStorage::Error
    head :not_found
  end

  private

  def serve_file(path, content_type:, disposition:, filename:)
    return head :not_found unless File.file?(path)
    response.set_header("Cache-Control", CACHE_CONTROL)
    send_file path, type: content_type, disposition: disposition, filename: filename
  end
end
