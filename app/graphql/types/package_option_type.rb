# frozen_string_literal: true

module Types
  # GraphQL type for package pricing option
  #
  # Represents a discounted session package (e.g., 4-session bundle)
  class PackageOptionType < Types::BaseObject
    description "Package pricing option with savings"

    field :sessions, Integer, null: false,
          description: "Number of sessions in package"

    field :total_price, String, null: false,
          description: "Total package price"

    field :per_session_cost, String, null: false,
          description: "Cost per session in package"

    field :savings, String, null: false,
          description: "Amount saved compared to individual sessions"

    field :description, String, null: false,
          description: "Package description"
  end
end
