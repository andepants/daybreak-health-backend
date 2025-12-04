# frozen_string_literal: true

module Types
  # GraphQL type for quick reply suggestions
  #
  # Represents a suggested response option that users can click
  # instead of typing their own message.
  class QuickReplyOptionType < Types::BaseObject
    description 'Quick reply suggestion option for chat interface'

    field :label, String, null: false, description: 'Display text for the button'
    field :value, String, null: false, description: 'Value sent when selected (usually same as label)'
    field :icon, String, null: true, description: 'Optional emoji or icon'
  end
end
