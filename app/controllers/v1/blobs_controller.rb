require "base64"

module V1
  class BlobsController < ApplicationController
    class InvalidBase64 < StandardError; end

    rescue_from ActionController::ParameterMissing do |e|
      render json: { error: "missing required parameter: #{e.param}" }, status: :bad_request
    end

    rescue_from InvalidBase64 do
      render json: { error: "data is not valid Base64" }, status: :bad_request
    end

    # POST /v1/blobs  { "id": "...", "data": "<base64>" }
    def create
      id = params.require(:id).to_s
      # params.require rejects "", but the empty string is valid Base64
      # (the empty blob) -- so check presence of the key explicitly.
      encoded = params[:data]
      raise ActionController::ParameterMissing, :data unless encoded.is_a?(String)

      bytes = decode_base64!(encoded)

      if Blob.exists?(blob_id: id)
        return render json: { error: "blob with this id already exists" }, status: :conflict
      end

      backend_name = Rails.configuration.x.storage.backend
      blob = nil

      # Metadata row and backend write succeed or fail together: if the
      # backend raises, the transaction rolls back and no orphan metadata
      # is left behind.
      Blob.transaction do
        blob = Blob.create!(blob_id: id, size: bytes.bytesize, backend: backend_name)
        Storage.backend(backend_name).put(id, bytes)
      end

      render json: metadata_json(blob), status: :created
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      render json: { error: "blob with this id already exists" }, status: :conflict
    end

    # GET /v1/blobs/*id
    def show
      blob = Blob.find_by!(blob_id: params[:id].to_s)
      bytes = blob.storage.get(blob.blob_id)

      render json: metadata_json(blob).merge(data: Base64.strict_encode64(bytes))
    end

    private

    # Strict decoding: any string that is not canonical Base64 (bad
    # alphabet, bad padding, stray whitespace) is rejected, per spec.
    def decode_base64!(encoded)
      Base64.strict_decode64(encoded)
    rescue ArgumentError
      raise InvalidBase64
    end

    def metadata_json(blob)
      {
        id: blob.blob_id,
        size: blob.size.to_s,
        created_at: blob.created_at.utc.iso8601
      }
    end
  end
end
