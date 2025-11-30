# frozen_string_literal: true

# PaymentPlan model stores payment plan selections for onboarding sessions
#
# A payment plan represents a parent's choice for paying for therapy services.
# This is used for billing integration - actual payment processing is post-MVP.
#
# Associations:
# - belongs_to :onboarding_session
#
# Enums:
# - status: pending, active, completed, cancelled
# - payment_method_preference: card, hsa_fsa, bank_transfer
#
# Validations:
# - Amounts must be positive
# - Plan duration must be non-negative (0 for upfront, positive for monthly plans)
# - Payment method and status must be valid enum values
class PaymentPlan < ApplicationRecord
  # Associations
  belongs_to :onboarding_session

  # Enums
  enum :status, {
    pending: 0,
    active: 1,
    completed: 2,
    cancelled: 3
  }

  enum :payment_method_preference, {
    card: 0,
    hsa_fsa: 1,
    bank_transfer: 2
  }

  # Validations
  validates :plan_duration_months, presence: true,
            numericality: { greater_than_or_equal_to: 0, only_integer: true }

  validates :monthly_amount, presence: true,
            numericality: { greater_than: 0 }

  validates :total_amount, presence: true,
            numericality: { greater_than: 0 }

  validates :discount_applied, numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  validates :payment_method_preference, presence: true
  validates :status, presence: true

  # Scopes
  scope :active_plans, -> { where(status: :active) }
  scope :pending_plans, -> { where(status: :pending) }
  scope :for_session, ->(session_id) { where(onboarding_session_id: session_id) }

  # Check if this is an upfront payment plan (pay in full)
  #
  # @return [Boolean] true if upfront payment, false if monthly plan
  def upfront_payment?
    plan_duration_months.zero?
  end

  # Check if this is a monthly payment plan
  #
  # @return [Boolean] true if monthly plan, false if upfront
  def monthly_payment?
    !upfront_payment?
  end

  # Get human-readable description of payment plan
  #
  # @return [String] Payment plan description
  def description
    if upfront_payment?
      discount_text = discount_applied&.positive? ? " (#{discount_percentage}% discount)" : ""
      "Pay in full#{discount_text}"
    else
      "#{plan_duration_months} monthly payments of #{format_currency(monthly_amount)}"
    end
  end

  # Calculate discount percentage from discount amount
  #
  # @return [Float, nil] Discount percentage or nil if no discount
  def discount_percentage
    return nil if discount_applied.zero? || total_amount.zero?

    original_amount = total_amount + discount_applied
    (discount_applied / original_amount * 100).round(1)
  end

  private

  # Format currency for display
  #
  # @param amount [Numeric] The amount to format
  # @return [String] Formatted currency string
  def format_currency(amount)
    "$#{amount.to_f.round(2)}"
  end
end
