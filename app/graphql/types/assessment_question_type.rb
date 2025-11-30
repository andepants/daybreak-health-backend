# frozen_string_literal: true

module Types
  # GraphQL type for assessment questions
  # Story 5.1: Conversational Screening Questions
  class AssessmentQuestionType < Types::BaseObject
    description 'A screening assessment question'

    field :id, String, null: false, description: 'Question ID (e.g., phq_a_1)'
    field :item, Integer, null: false, description: 'Item number (1-9 for PHQ-A, 1-7 for GAD-7)'
    field :text, String, null: false, description: 'Question text'
    field :domain, String, null: false, description: 'Clinical domain (e.g., anhedonia, anxious)'
    field :instrument, String, null: false, description: 'Instrument name (PHQ-A or GAD-7)'
  end
end
