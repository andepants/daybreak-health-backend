# frozen_string_literal: true

module Types
  # GraphQL type for support contact options
  # AC 3.5.4: Provide contact options to parent (phone, email, chat hours)
  # AC 3.5.9: Option always visible/accessible via GraphQL query
  class ContactOptionsType < Types::BaseObject
    description 'Support contact options for parents requesting human assistance'

    field :phone, String, null: false,
          description: 'Support phone number'

    field :email, String, null: false,
          description: 'Support email address'

    field :chat_hours, String, null: false,
          description: 'Chat availability hours with timezone'
  end
end
