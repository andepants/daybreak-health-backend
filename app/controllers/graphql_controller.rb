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
    context = build_context
    result = DaybreakHealthBackendSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  # Build GraphQL execution context with authentication and session
  def build_context
    context = {
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    }

    # Extract and validate JWT token from Authorization header
    token = extract_token_from_header
    if token.present?
      payload = Auth::JwtService.decode(token)
      if payload.present?
        context[:current_user] = payload
        # Load session if session_id is in token
        if payload[:session_id].present?
          session = OnboardingSession.find_by(id: payload[:session_id])
          context[:current_session] = session if session.present?
        end
      end
    end

    context
  end

  # Extract JWT token from Authorization header
  #
  # @return [String, nil] Token or nil if not present
  def extract_token_from_header
    auth_header = request.headers['Authorization']
    return nil if auth_header.blank?

    # Support both "Bearer token" and just "token" formats
    if auth_header.start_with?('Bearer ')
      auth_header.sub('Bearer ', '')
    else
      auth_header
    end
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

    render json: { errors: [{ message: e.message, backtrace: e.backtrace }], data: {} }, status: 500
  end
end
