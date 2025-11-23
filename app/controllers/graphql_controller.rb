# frozen_string_literal: true

class GraphqlController < ApplicationController
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  # protect_from_forgery with: :null_session

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      current_user: current_user
    }

    # Only cache read queries (not mutations) for anonymous users
    is_mutation = query.to_s.strip.start_with?("mutation")

    if is_mutation || current_user.present?
      # Don't cache mutations or authenticated requests
      result = EventQlSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    else
      # Cache read queries for anonymous users
      cache_key = build_cache_key(query, variables, operation_name)

      result = begin
        Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
          EventQlSchema.execute(query, variables: variables, context: context, operation_name: operation_name).to_h
        end
      rescue => e
        Rails.logger.error("GraphQL cache error: #{e.message}")
        EventQlSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
      end
    end

    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  def build_cache_key(query, variables, operation_name)
    # Normalize query (remove extra whitespace) for consistent cache keys
    normalized_query = query.to_s.gsub(/\s+/, " ").strip

    key_parts = [
      "graphql_response",
      "v1",
      Digest::MD5.hexdigest(normalized_query),
      Digest::MD5.hexdigest(variables.to_json),
      operation_name
    ].compact

    key_parts.join(":")
  end

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [ { message: e.message, backtrace: e.backtrace } ], data: {} }, status: 500
  end

  # Extract current user from Authorization header
  # Expected format: "Bearer <token>"
  def current_user
    token = request.headers["Authorization"]&.split(" ")&.last
    Authentication.current_user_from_token(token)
  end
end
