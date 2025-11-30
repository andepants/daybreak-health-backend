# frozen_string_literal: true

module Types
  # GraphQL type for assessment progress tracking
  # Story 5.1: Conversational Screening Questions
  class AssessmentProgressType < Types::BaseObject
    description 'Assessment progress information'

    field :status, String, null: false, description: 'Assessment status (not_started, in_progress, complete)'
    field :completed_questions, Integer, null: false, description: 'Number of completed questions'
    field :total_questions, Integer, null: false, description: 'Total questions (16)'
    field :percentage, Integer, null: false, description: 'Progress percentage (0-100)'
    field :phq_a_complete, Boolean, null: false, description: 'Whether PHQ-A is complete'
    field :gad_7_complete, Boolean, null: false, description: 'Whether GAD-7 is complete'
    field :current_phase, String, null: false, description: 'Current phase (not_started, phq_a, gad_7, complete)'
  end
end
