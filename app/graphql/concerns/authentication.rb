# frozen_string_literal: true

module Authentication
  class << self
    # Encode a payload into a JWT token
    # @param payload [Hash] The payload to encode (e.g., { user_id: 1 })
    # @return [String] The JWT token
    def encode_token(payload)
      # Add expiration time (24 hours from now)
      payload[:exp] = 24.hours.from_now.to_i
      JWT.encode(payload, Rails.application.credentials.secret_key_base)
    end

    # Decode a JWT token
    # @param token [String] The JWT token to decode
    # @return [HashWithIndifferentAccess, nil] The decoded payload or nil if invalid
    def decode_token(token)
      # Third parameter 'true' enables signature verification
      # algorithm: 'HS256' specifies the algorithm and enables expiration check
      body = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: "HS256" })[0]
      HashWithIndifferentAccess.new(body)
    rescue JWT::DecodeError, JWT::ExpiredSignature => e
      Rails.logger.info "JWT decode error: #{e.message}"
      nil
    end

    # Get the current user from a JWT token
    # @param token [String] The JWT token
    # @return [User, nil] The user object or nil if not found/invalid token
    def current_user_from_token(token)
      return nil unless token

      decoded = decode_token(token)
      return nil unless decoded

      User.find_by(id: decoded[:user_id])
    end
  end
end
