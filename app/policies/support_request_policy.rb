# frozen_string_literal: true

# Authorization policy for SupportRequest
# Story 7.3: Support Request Tracking
#
# Rules:
# - index?: Allow session owner, admin, system
# - show?: Allow session owner, admin, system
# - create?: Deny (created via webhook)
# - update?: Deny (updated via webhook)
# - destroy?: Deny all
#
# Role hierarchy:
# - anonymous/parent: Can view own session's support requests
# - admin: Can view all support requests
# - system: Full access, used for background jobs and webhooks
#
class SupportRequestPolicy < ApplicationPolicy
  # Session owner, admin, or system can view list
  #
  # @return [Boolean] true if user has permission
  def index?
    session_owner? || admin? || system?
  end

  # Session owner, admin, or system can view
  #
  # @return [Boolean] true if user has permission
  def show?
    session_owner? || admin? || system?
  end

  # Support requests are created via webhook only
  #
  # @return [Boolean] false (deny all)
  def create?
    false
  end

  # Support requests are updated via webhook only
  #
  # @return [Boolean] false (deny all)
  def update?
    false
  end

  # Support requests should not be destroyed
  #
  # @return [Boolean] false (deny all)
  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    # Return support requests based on user role
    #
    # @return [ActiveRecord::Relation] Scoped support requests
    def resolve
      return scope.none if user.blank?

      case user[:role]&.to_s
      when 'system', 'admin'
        # System and admin can see all support requests
        scope.all
      when 'parent', 'anonymous'
        # Parents and anonymous users can only see support requests for their session
        if user[:session_id].present?
          scope.joins(:onboarding_session).where(onboarding_sessions: { id: user[:session_id] })
        else
          scope.none
        end
      else
        scope.none
      end
    end
  end

  private

  # Check if current user owns the session for this support request
  #
  # @return [Boolean] true if user owns session
  def session_owner?
    return false if user.blank?
    return false if record.blank?

    # User is a JWT payload hash with session_id claim
    user[:session_id].to_s == record.onboarding_session_id.to_s
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
