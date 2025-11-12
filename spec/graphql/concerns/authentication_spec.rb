# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authentication do
  describe ".encode_token" do
    it "encodes a payload into a JWT token" do
      payload = { user_id: 1 }
      token = Authentication.encode_token(payload)

      expect(token).to be_present
      expect(token.split(".").length).to eq(3) # JWT has 3 parts: header.payload.signature
    end

    it "adds 24-hour expiration to the token" do
      payload = { user_id: 1 }
      token = Authentication.encode_token(payload)

      decoded = Authentication.decode_token(token)
      expect(decoded[:exp]).to be_present
      expect(decoded[:exp]).to be_within(5).of(24.hours.from_now.to_i)
    end

    it "overwrites any manually set expiration with 24 hours" do
      payload = { user_id: 1, exp: 1.second.from_now.to_i }
      token = Authentication.encode_token(payload)

      decoded = Authentication.decode_token(token)
      expect(decoded[:exp]).to be_within(5).of(24.hours.from_now.to_i)
    end
  end

  describe ".decode_token" do
    it "decodes a valid JWT token" do
      payload = { user_id: 123 }
      token = Authentication.encode_token(payload)

      decoded = Authentication.decode_token(token)
      expect(decoded[:user_id]).to eq(123)
    end

    it "returns nil for an invalid token" do
      invalid_token = "invalid.token.here"

      result = Authentication.decode_token(invalid_token)
      expect(result).to be_nil
    end

    it "returns nil for an expired token" do
      # Create a token that expired 1 hour ago
      secret = ENV.fetch("JWT_SECRET_KEY") { Rails.application.secret_key_base }
      expired_token = JWT.encode(
        { user_id: 1, exp: 1.hour.ago.to_i },
        secret
      )

      result = Authentication.decode_token(expired_token)
      expect(result).to be_nil
    end

    it "returns nil for a token with invalid signature" do
      token = JWT.encode({ user_id: 1 }, "wrong_secret")

      result = Authentication.decode_token(token)
      expect(result).to be_nil
    end

    it "returns a HashWithIndifferentAccess" do
      token = Authentication.encode_token({ user_id: 1 })
      decoded = Authentication.decode_token(token)

      expect(decoded).to be_a(HashWithIndifferentAccess)
      expect(decoded[:user_id]).to eq(1)
      expect(decoded["user_id"]).to eq(1) # String key also works
    end
  end

  describe ".current_user_from_token" do
    let!(:user) { create(:user) }

    it "returns the user for a valid token" do
      token = Authentication.encode_token({ user_id: user.id })

      result = Authentication.current_user_from_token(token)
      expect(result).to eq(user)
    end

    it "returns nil for an invalid token" do
      result = Authentication.current_user_from_token("invalid_token")
      expect(result).to be_nil
    end

    it "returns nil for an expired token" do
      secret = ENV.fetch("JWT_SECRET_KEY") { Rails.application.secret_key_base }
      expired_token = JWT.encode(
        { user_id: user.id, exp: 1.hour.ago.to_i },
        secret
      )

      result = Authentication.current_user_from_token(expired_token)
      expect(result).to be_nil
    end

    it "returns nil when token is nil" do
      result = Authentication.current_user_from_token(nil)
      expect(result).to be_nil
    end

    it "returns nil when user does not exist" do
      token = Authentication.encode_token({ user_id: 99999 })

      result = Authentication.current_user_from_token(token)
      expect(result).to be_nil
    end
  end
end
