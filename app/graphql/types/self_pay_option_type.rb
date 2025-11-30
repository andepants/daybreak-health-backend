# frozen_string_literal: true

module Types
  # GraphQL type for self-pay option preview
  #
  # Always visible to parents regardless of insurance verification status.
  # Provides preview of self-pay rates (full details in Story 4.6).
  class SelfPayOptionType < Types::BaseObject
    description "Self-pay option preview (always available)"

    field :available, Boolean, null: false,
          description: "Whether self-pay is available (always true)"

    field :description, String, null: false,
          description: "Self-pay option description"

    field :preview_rate, String, null: true,
          description: "Preview of self-pay rates"
  end
end
