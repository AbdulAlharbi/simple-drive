require "openssl"
require "digest"

module Storage
  # Minimal AWS Signature Version 4 signer, implemented from the AWS
  # specification (no AWS SDK / S3 libraries). Produces the headers
  # required to authenticate a plain HTTP request against any
  # SigV4-speaking service (S3, minio, DO Spaces, ...).
  #
  # Reference: https://docs.aws.amazon.com/IAM/latest/UserGuide/create-signed-request.html
  class SigV4
    ALGORITHM = "AWS4-HMAC-SHA256"

    def initialize(access_key_id:, secret_access_key:, region:, service: "s3")
      @access_key_id = access_key_id
      @secret_access_key = secret_access_key
      @region = region
      @service = service
    end

    # Returns the full header set for the request, including Authorization.
    #
    # path must already be URI-encoded exactly as it will be sent on the
    # wire: for S3 the canonical URI is the path as-sent, *not* re-encoded.
    def sign(method:, host:, path: "/", query: {}, headers: {}, payload: "", time: Time.now.utc)
      amz_date   = time.strftime("%Y%m%dT%H%M%SZ")
      date_stamp = time.strftime("%Y%m%d")
      payload_hash = Digest::SHA256.hexdigest(payload)

      all_headers = headers.merge("host" => host, "x-amz-date" => amz_date)
      all_headers["x-amz-content-sha256"] = payload_hash if @service == "s3"

      canonical_headers, signed_headers = canonicalize_headers(all_headers)

      canonical_request = [
        method.upcase,
        path,
        canonical_query_string(query),
        canonical_headers,
        signed_headers,
        payload_hash
      ].join("\n")

      credential_scope = "#{date_stamp}/#{@region}/#{@service}/aws4_request"

      string_to_sign = [
        ALGORITHM,
        amz_date,
        credential_scope,
        Digest::SHA256.hexdigest(canonical_request)
      ].join("\n")

      signature = hmac_hex(signing_key(date_stamp), string_to_sign)

      authorization = "#{ALGORITHM} " \
        "Credential=#{@access_key_id}/#{credential_scope}, " \
        "SignedHeaders=#{signed_headers}, " \
        "Signature=#{signature}"

      all_headers.merge("authorization" => authorization)
    end

    # RFC 3986 "unreserved characters" encoding, as required by SigV4:
    # everything except A-Z a-z 0-9 - _ . ~ is percent-encoded.
    def self.uri_encode(string)
      string.b.gsub(/[^A-Za-z0-9\-_.~]/) { |c| format("%%%02X", c.ord) }
    end

    private

    def canonicalize_headers(headers)
      normalized = headers
        .map { |k, v| [k.to_s.downcase, v.to_s.strip.squeeze(" ")] }
        .sort_by(&:first)
      canonical = normalized.map { |k, v| "#{k}:#{v}\n" }.join
      signed = normalized.map(&:first).join(";")
      [canonical, signed]
    end

    def canonical_query_string(query)
      query
        .map { |k, v| [self.class.uri_encode(k.to_s), self.class.uri_encode(v.to_s)] }
        .sort
        .map { |k, v| "#{k}=#{v}" }
        .join("&")
    end

    def signing_key(date_stamp)
      k_date    = hmac("AWS4#{@secret_access_key}", date_stamp)
      k_region  = hmac(k_date, @region)
      k_service = hmac(k_region, @service)
      hmac(k_service, "aws4_request")
    end

    def hmac(key, data)
      OpenSSL::HMAC.digest("sha256", key, data)
    end

    def hmac_hex(key, data)
      OpenSSL::HMAC.hexdigest("sha256", key, data)
    end
  end
end
