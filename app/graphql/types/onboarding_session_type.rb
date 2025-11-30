# frozen_string_literal: true

module Types
  # GraphQL type for OnboardingSession model
  #
  # Represents the main onboarding session entity tracking a parent's intake process.
  # The session ID is returned in CUID format with sess_ prefix.
  class OnboardingSessionType < Types::BaseObject
    description 'An onboarding session for parent intake'

    # Core fields
    field :id, ID, null: false, description: 'Unique session identifier (CUID format with sess_ prefix)'
    field :status, String, null: false, description: 'Current session status'
    field :progress_data, GraphQL::Types::JSON, null: false, description: 'Session progress data', method: :progress
    field :referral_source, String, null: true, description: 'How the parent found Daybreak'
    field :expires_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When session will expire'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When session was created'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When session was last updated'

    # AC 3.5.2,3.5.3: Escalation fields
    field :needs_human_contact, Boolean, null: false,
          description: 'Whether parent has requested to speak with a human'
    field :escalation_requested_at, GraphQL::Types::ISO8601DateTime, null: true,
          description: 'When escalation was requested'

    # Progress indicators
    field :progress, Types::ProgressType, null: false, description: 'Calculated progress indicators'

    # Associated data
    field :parent, Types::ParentType, null: true, description: 'Parent/guardian information'
    field :child, Types::ChildType, null: true, description: 'Child information'
    field :assessment, Types::AssessmentType, null: true, description: 'Assessment data'
    field :insurance, Types::InsuranceType, null: true, description: 'Insurance information'
    field :messages, [Types::MessageType], null: true, description: 'Chat messages in assessment conversation'

    # Override ID field to add 'sess_' prefix to UUID
    def id
      "sess_#{object.id.gsub('-', '')}"
    end

    # Resolver for progress - calculates progress indicators
    def progress
      Conversation::ProgressService.new(object).calculate
    end

    # Resolver for messages - orders by creation time
    def messages
      object.messages.order(created_at: :asc)
    end
  end
end
