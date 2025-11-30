# frozen_string_literal: true

module Types
  # GraphQL type for Assessment model
  # Story 5.1: Conversational Screening Questions
  #
  # Represents the mental health assessment responses and scoring.
  # PHI fields (responses, summary) are encrypted at rest.
  class AssessmentType < Types::BaseObject
    description 'Mental health screening assessment (PHQ-A, GAD-7)'

    field :id, ID, null: false, description: 'Unique identifier'
    field :status, String, null: false, description: 'Assessment status (not_started, in_progress, complete)'
    field :responses, GraphQL::Types::JSON, null: false, description: 'Assessment responses (encrypted PHI)'
    field :risk_flags, [String], null: false, description: 'Identified risk flags'
    field :summary, String, null: true, description: 'AI-generated clinical summary (encrypted PHI)'
    field :consent_given, Boolean, null: false, description: 'Whether consent was given'
    field :score, Integer, null: true, description: 'Combined assessment score (0-100)'
    field :assessment_mode, String, null: true, description: 'Assessment mode (conversational or legacy)'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When assessment was started'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When assessment was last updated'

    # Computed fields for progress tracking
    field :phq_a_score, Integer, null: true, description: 'PHQ-A depression score (0-27)'
    field :gad_7_score, Integer, null: true, description: 'GAD-7 anxiety score (0-21)'
    field :completed_questions_count, Integer, null: false, description: 'Number of completed questions'
    field :total_questions_count, Integer, null: false, description: 'Total questions (16)'
    field :progress_percentage, Integer, null: false, description: 'Completion percentage (0-100)'
    field :phq_a_complete, Boolean, null: false, description: 'Whether PHQ-A is complete'
    field :gad_7_complete, Boolean, null: false, description: 'Whether GAD-7 is complete'
    field :current_instrument, String, null: true, description: 'Current instrument being administered'
    field :next_question_id, String, null: true, description: 'Next question identifier'

    def phq_a_complete
      object.phq_a_complete?
    end

    def gad_7_complete
      object.gad_7_complete?
    end

    def current_instrument
      object.progress[:current_instrument]
    end

    def next_question_id
      object.progress[:next_question_id]
    end
  end
end
