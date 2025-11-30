# frozen_string_literal: true

module Types
  # GraphQL enum for payment method options
  #
  # Available payment methods for therapy services:
  # - CARD: Credit or debit card (Visa, Mastercard, American Express, Discover)
  # - HSA_FSA: Health Savings Account or Flexible Spending Account
  # - BANK_TRANSFER: Direct bank account transfer (ACH)
  #
  # Note: Actual payment processing is post-MVP. This enum is used to
  # capture parent preferences for future billing integration.
  class PaymentMethodEnum < Types::BaseEnum
    description "Payment method options for therapy services"

    value "CARD", "Credit or debit card (Visa, Mastercard, Amex, Discover)",
          description: "Payment via credit or debit card"

    value "HSA_FSA", "Health Savings Account or Flexible Spending Account",
          description: "Payment via HSA or FSA card"

    value "BANK_TRANSFER", "Direct bank account transfer (ACH)",
          description: "Payment via bank account transfer"
  end
end
