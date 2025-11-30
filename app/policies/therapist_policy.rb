# frozen_string_literal: true

# Authorization policy for Therapist model
#
# AC 5.1.9: Admin-only mutations for therapist CRUD operations
#
# Rules:
# - create?: Admin or system only
# - show?: Allow all (public therapist profiles for matching)
# - update?: Admin or system only
# - destroy?: Admin or system only (soft delete via active=false)
#
# Example usage in GraphQL:
#   class CreateTherapist < BaseMutation
#     def resolve(input:)
#       authorize Therapist, :create?
#       # ... create therapist
#     end
#   end
class TherapistPolicy < ApplicationPolicy
  # Only admins and system can create therapist profiles
  # AC 5.1.9: Admin-only mutations
  #
  # @return [Boolean] true if user has permission
  def create?
    admin? || system?
  end

  # All authenticated users can view therapist profiles
  # Public information needed for matching algorithm
  #
  # @return [Boolean] true (allow all)
  def show?
    true
  end

  # Only admins and system can update therapist profiles
  # AC 5.1.9: Admin-only mutations
  #
  # @return [Boolean] true if user has permission
  def update?
    admin? || system?
  end

  # Only admins and system can delete therapist profiles
  # AC 5.1.9: Admin-only mutations
  #
  # @return [Boolean] true if user has permission
  def destroy?
    admin? || system?
  end

  # All authenticated users can list therapists
  #
  # @return [Boolean] true (allow all)
  def index?
    true
  end

  class Scope < ApplicationPolicy::Scope
    # Return therapists based on user role
    # All users can see active therapists for matching
    #
    # @return [ActiveRecord::Relation] Scoped therapists
    def resolve
      case user[:role]&.to_s
      when 'system', 'admin'
        # Admins and system can see all therapists (including inactive)
        scope.all
      else
        # All other users can only see active therapists
        scope.active
      end
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
