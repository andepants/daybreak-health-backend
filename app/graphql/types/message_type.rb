# frozen_string_literal: true

module Types
  # GraphQL type for Message model
  #
  # Represents a chat message in the assessment conversation.
  # PHI field (content) is encrypted at rest.
  class MessageType < Types::BaseObject
    description 'Chat message in assessment conversation'

    field :id, ID, null: false, description: 'Unique identifier'
    field :role, String, null: false, description: 'Message sender role (user, assistant, system)'
    field :content, String, null: false, description: 'Message content (encrypted)'
    field :metadata, GraphQL::Types::JSON, null: true, description: 'Additional message metadata'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When message was created'
  end
end
