# frozen_string_literal: true

# Authorization policy for TherapistTimeOff model
#
# AC 5.2: Admin-only mutations for time-off management
#
# Rules:
# - create?: Admin or system only
# - show?: Allow all (public time-off for scheduling)
# - update?: Admin or system only
# - destroy?: Admin or system only
#
# Example usage in GraphQL:
#   class CreateTimeOff < BaseMutation
#     def resolve(input:)
#       authorize TherapistTimeOff, :create?
#       # ... create time-off
#     end
#   end
class TherapistTimeOffPolicy < ApplicationPolicy
  # Only admins and system can create time-off periods
  # AC 5.2: Admin-only mutations
  #
  # @return [Boolean] true if user has permission
  def create?
    admin? || system?
  end

  # All authenticated users can view time-off
  # Public information needed for booking availability
  #
  # @return [Boolean] true (allow all)
  def show?
    true
  end

  # Only admins and system can update time-off periods
  # AC 5.2: Admin-only mutations
  #
  # @return [Boolean] true if user has permission
  def update?
    admin? || system?
  end

  # Only admins and system can delete time-off periods
  # AC 5.2: Admin-only mutations
  #
  # @return [Boolean] true if user has permission
  def destroy?
    admin? || system?
  end

  # All authenticated users can list time-offs
  #
  # @return [Boolean] true (allow all)
  def index?
    true
  end

  class Scope < ApplicationPolicy::Scope
    # Return all time-offs (no filtering needed)
    #
    # @return [ActiveRecord::Relation] Scoped time-offs
    def resolve
      scope.all
    end
  end

  private

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
