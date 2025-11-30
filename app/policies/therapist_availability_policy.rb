# frozen_string_literal: true

# Authorization policy for TherapistAvailability model
#
# AC 5.2: Admin-only mutations for availability management
#
# Rules:
# - create?: Admin or system only
# - show?: Allow all (public availability for scheduling)
# - update?: Admin or system only
# - destroy?: Admin or system only
#
# Example usage in GraphQL:
#   class CreateAvailability < BaseMutation
#     def resolve(input:)
#       authorize TherapistAvailability, :create?
#       # ... create availability
#     end
#   end
class TherapistAvailabilityPolicy < ApplicationPolicy
  # Only admins and system can create availability slots
  # AC 5.2: Admin-only mutations
  #
  # @return [Boolean] true if user has permission
  def create?
    admin? || system?
  end

  # All authenticated users can view availability
  # Public information needed for booking
  #
  # @return [Boolean] true (allow all)
  def show?
    true
  end

  # Only admins and system can update availability slots
  # AC 5.2: Admin-only mutations
  #
  # @return [Boolean] true if user has permission
  def update?
    admin? || system?
  end

  # Only admins and system can delete availability slots
  # AC 5.2: Admin-only mutations
  #
  # @return [Boolean] true if user has permission
  def destroy?
    admin? || system?
  end

  # All authenticated users can list availabilities
  #
  # @return [Boolean] true (allow all)
  def index?
    true
  end

  class Scope < ApplicationPolicy::Scope
    # Return all availabilities (no filtering needed)
    #
    # @return [ActiveRecord::Relation] Scoped availabilities
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
