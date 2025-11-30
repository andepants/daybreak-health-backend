# frozen_string_literal: true

# CurrentSession concern for GraphQL resolvers
#
# Provides helper methods to extract the current session and user
# from the GraphQL context. Handles missing or invalid sessions gracefully.
#
# The session is expected to be injected into the context by the
# GraphqlController after JWT authentication.
#
# Example usage in a mutation:
#   class UpdateSession < BaseMutation
#     include GraphqlConcerns::CurrentSession
#
#     def resolve(**attributes)
#       session = current_session
#       return error_response('Session required') if session.nil?
#       # ... perform update
#     end
#   end
module GraphqlConcerns::CurrentSession
  # Get the current onboarding session from GraphQL context
  #
  # @return [OnboardingSession, nil] Current session or nil
  def current_session
    context&.[](:current_session)
  end

  # Get the current user (JWT payload) from GraphQL context
  #
  # @return [Hash, nil] Current user payload or nil
  def current_user
    context&.[](:current_user)
  end

  # Check if a user is authenticated
  #
  # @return [Boolean] true if user is present
  def authenticated?
    current_user.present?
  end

  # Check if a session exists
  #
  # @return [Boolean] true if session is present
  def session_exists?
    current_session.present?
  end

  # Require authentication (raise error if not authenticated)
  #
  # @raise [GraphQL::ExecutionError] If user is not authenticated
  def require_authentication!
    return if authenticated?

    raise GraphQL::ExecutionError.new(
      'Authentication required',
      extensions: {
        code: 'UNAUTHENTICATED',
        timestamp: Time.current.iso8601
      }
    )
  end

  # Require session (raise error if no session)
  #
  # @raise [GraphQL::ExecutionError] If session is not present
  def require_session!
    return if session_exists?

    raise GraphQL::ExecutionError.new(
      'Session required',
      extensions: {
        code: 'UNAUTHENTICATED',
        timestamp: Time.current.iso8601
      }
    )
  end

  # Get session ID from context
  #
  # @return [String, nil] Session ID or nil
  def current_session_id
    current_session&.id
  end

  # Get user ID from context
  #
  # @return [String, nil] User ID or nil
  def current_user_id
    current_user&.dig(:user_id)
  end

  # Get current user role
  #
  # @return [String, nil] User role or nil
  def current_user_role
    current_user&.dig(:role)
  end

  # Check if current user has a specific role
  #
  # @param role [String, Symbol] Role to check
  # @return [Boolean] true if user has role
  def has_role?(role)
    current_user_role.to_s == role.to_s
  end

  # Check if current user is anonymous
  #
  # @return [Boolean] true if user is anonymous
  def anonymous?
    has_role?('anonymous')
  end

  # Check if current user is admin
  #
  # @return [Boolean] true if user is admin
  def admin?
    has_role?('admin')
  end

  # Check if current user is parent
  #
  # @return [Boolean] true if user is parent
  def parent?
    has_role?('parent')
  end

  # Check if current user is coordinator
  #
  # @return [Boolean] true if user is coordinator
  def coordinator?
    has_role?('coordinator')
  end

  # Check if current user is system
  #
  # @return [Boolean] true if user is system
  def system?
    has_role?('system')
  end

  # Normalize session ID (handle sess_ prefix)
  #
  # @param session_id [String] Session ID (with or without sess_ prefix)
  # @return [String] Normalized UUID
  def normalize_session_id(session_id)
    if session_id.start_with?('sess_')
      hex = session_id.sub('sess_', '')
      "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
    else
      session_id
    end
  end
end
