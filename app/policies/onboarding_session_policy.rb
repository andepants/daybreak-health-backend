# frozen_string_literal: true

# Authorization policy for OnboardingSession
#
# AC 2.6.4: Role-based access control with Pundit policies
#
# Rules:
# - create?: Allow all (anonymous session creation)
# - show?: Allow session owner, coordinator, admin, system
# - update?: Allow session owner, admin, system
# - destroy?: Deny all (sessions should be abandoned, not destroyed)
# - abandon?: Allow session owner only
#
# Role hierarchy:
# - anonymous: Can create sessions, read/update own session
# - parent: Can read/update own session and related data
# - coordinator: Can read all sessions, update session status
# - admin: Can read/update all sessions, manage configuration
# - system: Full access, used for background jobs
#
# Example usage in GraphQL:
#   class UpdateSession < BaseMutation
#     def resolve(id:, **attributes)
#       session = OnboardingSession.find(id)
#       authorize session, :update?
#       # ... perform update
#     end
#   end
class OnboardingSessionPolicy < ApplicationPolicy
  # Anyone can create a session (anonymous onboarding)
  #
  # @return [Boolean] true (always allow)
  def create?
    true
  end

  # Session owner, coordinator, admin, or system can view
  # AC 2.6.4: Role-based permission checks
  #
  # @return [Boolean] true if user has permission
  def show?
    session_owner? || coordinator? || admin? || system?
  end

  # Session owner, admin, or system can update
  # AC 2.6.4: Role-based permission checks
  #
  # @return [Boolean] true if user has permission
  def update?
    session_owner? || admin? || system?
  end

  # Sessions should not be destroyed, only abandoned
  #
  # @return [Boolean] false (deny all)
  def destroy?
    false
  end

  # Only the session owner can abandon their session
  # AC 2.5.2: Mutation requires valid session token (cannot abandon others' sessions)
  #
  # @return [Boolean] true if user owns this session
  def abandon?
    session_owner?
  end

  # Coordinators, admins, and system can list sessions
  # AC 2.6.4: Role-based permission checks
  #
  # @return [Boolean] true if user has permission
  def index?
    coordinator? || admin? || system?
  end

  class Scope < ApplicationPolicy::Scope
    # Return sessions based on user role
    # AC 2.6.4: Role-based scoping
    #
    # @return [ActiveRecord::Relation] Scoped sessions
    def resolve
      return scope.none if user.blank?

      case user[:role]&.to_s
      when 'system', 'admin'
        # System and admin can see all sessions
        scope.all
      when 'coordinator'
        # Coordinators can see all sessions
        scope.all
      when 'parent', 'anonymous'
        # Parents and anonymous users can only see their own session
        if user[:session_id].present?
          scope.where(id: user[:session_id])
        else
          scope.none
        end
      else
        scope.none
      end
    end
  end

  private

  # Check if current user owns this session
  #
  # User ownership is determined by the session_id claim in the JWT payload
  #
  # @return [Boolean] true if user owns session
  def session_owner?
    return false if user.blank?
    return false if record.blank?

    # User is a JWT payload hash with session_id claim
    user[:session_id].to_s == record.id.to_s
  end

  # Check if user has coordinator role
  #
  # @return [Boolean] true if user is coordinator
  def coordinator?
    return false if user.blank?

    user[:role]&.to_s == 'coordinator'
  end

  # Check if user has admin role
  #
  # @return [Boolean] true if user is admin
  def admin?
    return false if user.blank?

    user[:role]&.to_s == 'admin'
  end

  # Check if user has system role
  #
  # @return [Boolean] true if user is system
  def system?
    return false if user.blank?

    user[:role]&.to_s == 'system'
  end
end
