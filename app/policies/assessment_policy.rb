# frozen_string_literal: true

# Authorization policy for Assessment model
#
# AC 2.6.4: Pundit policies enforce role-based permission checks for PHI access
#
# Rules:
# - create?: Allow session owner, admin, system
# - show?: Allow session owner, coordinator, admin, system
# - update?: Allow session owner, admin, system
# - destroy?: Deny all (soft delete via session abandonment)
#
# PHI Access Rules:
# - Assessment data contains sensitive health information (presenting concerns, symptoms)
# - Only session owner can create/update their assessment data
# - Coordinators can view for care coordination
# - Admins and system have full access
#
# Example usage in GraphQL:
#   class UpdateAssessment < BaseMutation
#     def resolve(id:, **attributes)
#       assessment = Assessment.find(id)
#       authorize assessment, :update?
#       # ... perform update
#     end
#   end
class AssessmentPolicy < ApplicationPolicy
  # Session owner, admin, or system can create assessment data
  # AC 2.6.4: PHI access control
  #
  # @return [Boolean] true if user has permission
  def create?
    owns_session? || admin? || system?
  end

  # Session owner, coordinator, admin, or system can view assessment data
  # AC 2.6.4: PHI access control
  #
  # @return [Boolean] true if user has permission
  def show?
    owns_session? || coordinator? || admin? || system?
  end

  # Session owner, admin, or system can update assessment data
  # AC 2.6.4: PHI access control
  #
  # @return [Boolean] true if user has permission
  def update?
    owns_session? || admin? || system?
  end

  # Assessment data should not be destroyed, only soft deleted via session
  #
  # @return [Boolean] false (deny all)
  def destroy?
    false
  end

  # Coordinators, admins, and system can list assessments
  #
  # @return [Boolean] true if user has permission
  def index?
    coordinator? || admin? || system?
  end

  class Scope < ApplicationPolicy::Scope
    # Return assessments based on user role
    # AC 2.6.4: Role-based PHI scoping
    #
    # @return [ActiveRecord::Relation] Scoped assessments
    def resolve
      return scope.none if user.blank?

      case user[:role]&.to_s
      when 'system', 'admin', 'coordinator'
        # System, admin, and coordinators can see all assessments
        scope.all
      when 'parent', 'anonymous'
        # Parents and anonymous users can only see their own assessment data
        if user[:session_id].present?
          scope.where(onboarding_session_id: user[:session_id])
        else
          scope.none
        end
      else
        scope.none
      end
    end
  end

  private

  # Check if current user owns the session associated with this assessment
  #
  # @return [Boolean] true if user owns session
  def owns_session?
    return false if user.blank?
    return false if record.blank?

    user[:session_id].to_s == record.onboarding_session_id.to_s
  end

  # Check if user has coordinator role
  #
  # @return [Boolean] true if user is coordinator
  def coordinator?
    user[:role]&.to_s == 'coordinator'
  end

  # Check if user has admin role
  #
  # @return [Boolean] true if user is admin
  def admin?
    user[:role]&.to_s == 'admin'
  end

  # Check if user has system role
  #
  # @return [Boolean] true if user is system
  def system?
    user[:role]&.to_s == 'system'
  end
end
