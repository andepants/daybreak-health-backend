# frozen_string_literal: true

module Assessments
  # Standardized mental health screening question sets
  # Story 5.1: Conversational Screening Questions
  #
  # Implements PHQ-A (Patient Health Questionnaire - Adolescent) and
  # GAD-7 (Generalized Anxiety Disorder) instruments.
  #
  # Question sets are age-appropriate:
  # - Ages 5-12: Simplified language for younger children
  # - Ages 13-18: Standard adolescent/adult language
  #
  # Likert Scale:
  # - 0: Not at all
  # - 1: Several days
  # - 2: More than half the days
  # - 3: Nearly every day
  class QuestionSets
    # Likert scale options with natural language mappings
    LIKERT_SCALE = {
      0 => { label: 'Not at all', keywords: ['not at all', 'never', 'none', 'no', 'not really', 'rarely', 'hardly ever'] },
      1 => { label: 'Several days', keywords: ['several days', 'sometimes', 'occasionally', 'a few days', 'some days', 'once in a while'] },
      2 => { label: 'More than half the days', keywords: ['more than half', 'most days', 'often', 'frequently', 'pretty often', 'a lot'] },
      3 => { label: 'Nearly every day', keywords: ['nearly every day', 'almost every day', 'every day', 'always', 'all the time', 'constantly', 'daily'] }
    }.freeze

    # PHQ-A Questions (9 items) - Standard version for ages 13-18
    PHQ_A_STANDARD = [
      { id: 'phq_a_1', item: 1, domain: 'anhedonia',
        text: 'In the past two weeks, how often has your child had little interest or pleasure in doing things they usually enjoy?' },
      { id: 'phq_a_2', item: 2, domain: 'depressed_mood',
        text: 'In the past two weeks, how often has your child felt down, depressed, or hopeless?' },
      { id: 'phq_a_3', item: 3, domain: 'sleep',
        text: 'In the past two weeks, how often has your child had trouble falling asleep, staying asleep, or sleeping too much?' },
      { id: 'phq_a_4', item: 4, domain: 'fatigue',
        text: 'In the past two weeks, how often has your child felt tired or had little energy?' },
      { id: 'phq_a_5', item: 5, domain: 'appetite',
        text: 'In the past two weeks, how often has your child had poor appetite or been overeating?' },
      { id: 'phq_a_6', item: 6, domain: 'self_esteem',
        text: 'In the past two weeks, how often has your child felt bad about themselves, or felt like a failure, or let themselves or your family down?' },
      { id: 'phq_a_7', item: 7, domain: 'concentration',
        text: 'In the past two weeks, how often has your child had trouble concentrating on things like schoolwork, reading, or watching TV?' },
      { id: 'phq_a_8', item: 8, domain: 'psychomotor',
        text: 'In the past two weeks, how often has your child been moving or speaking so slowly that others noticed? Or the opposite - being so fidgety or restless that they moved around more than usual?' },
      { id: 'phq_a_9', item: 9, domain: 'suicidal_ideation',
        text: 'In the past two weeks, how often has your child had thoughts that they would be better off dead, or thoughts of hurting themselves in some way?' }
    ].freeze

    # PHQ-A Questions - Simplified version for ages 5-12
    PHQ_A_SIMPLIFIED = [
      { id: 'phq_a_1', item: 1, domain: 'anhedonia',
        text: 'In the past two weeks, how often has your child not wanted to do things they usually like to do, like playing or their favorite activities?' },
      { id: 'phq_a_2', item: 2, domain: 'depressed_mood',
        text: 'In the past two weeks, how often has your child seemed sad, unhappy, or like they were having a hard time?' },
      { id: 'phq_a_3', item: 3, domain: 'sleep',
        text: 'In the past two weeks, how often has your child had trouble sleeping, like not being able to fall asleep, waking up at night, or sleeping too much?' },
      { id: 'phq_a_4', item: 4, domain: 'fatigue',
        text: 'In the past two weeks, how often has your child seemed tired or like they didn\'t have energy to do things?' },
      { id: 'phq_a_5', item: 5, domain: 'appetite',
        text: 'In the past two weeks, how often has your child not wanted to eat much, or eaten more than usual?' },
      { id: 'phq_a_6', item: 6, domain: 'self_esteem',
        text: 'In the past two weeks, how often has your child said things like they\'re not good at anything, or felt bad about themselves?' },
      { id: 'phq_a_7', item: 7, domain: 'concentration',
        text: 'In the past two weeks, how often has your child had trouble paying attention to things like schoolwork or activities?' },
      { id: 'phq_a_8', item: 8, domain: 'psychomotor',
        text: 'In the past two weeks, how often has your child seemed to move or talk much slower than usual, or been extra restless and fidgety?' },
      { id: 'phq_a_9', item: 9, domain: 'suicidal_ideation',
        text: 'In the past two weeks, has your child said anything about not wanting to be alive or about hurting themselves?' }
    ].freeze

    # GAD-7 Questions (7 items) - Standard version for ages 13-18
    GAD_7_STANDARD = [
      { id: 'gad_7_1', item: 1, domain: 'anxious',
        text: 'In the past two weeks, how often has your child felt nervous, anxious, or on edge?' },
      { id: 'gad_7_2', item: 2, domain: 'worry_control',
        text: 'In the past two weeks, how often has your child not been able to stop or control worrying?' },
      { id: 'gad_7_3', item: 3, domain: 'excessive_worry',
        text: 'In the past two weeks, how often has your child worried too much about different things?' },
      { id: 'gad_7_4', item: 4, domain: 'relaxation',
        text: 'In the past two weeks, how often has your child had trouble relaxing?' },
      { id: 'gad_7_5', item: 5, domain: 'restlessness',
        text: 'In the past two weeks, how often has your child been so restless that it\'s hard to sit still?' },
      { id: 'gad_7_6', item: 6, domain: 'irritability',
        text: 'In the past two weeks, how often has your child become easily annoyed or irritable?' },
      { id: 'gad_7_7', item: 7, domain: 'fear',
        text: 'In the past two weeks, how often has your child felt afraid, as if something awful might happen?' }
    ].freeze

    # GAD-7 Questions - Simplified version for ages 5-12
    GAD_7_SIMPLIFIED = [
      { id: 'gad_7_1', item: 1, domain: 'anxious',
        text: 'In the past two weeks, how often has your child seemed worried, nervous, or scared about things?' },
      { id: 'gad_7_2', item: 2, domain: 'worry_control',
        text: 'In the past two weeks, how often has your child had trouble stopping their worries even when they try?' },
      { id: 'gad_7_3', item: 3, domain: 'excessive_worry',
        text: 'In the past two weeks, how often has your child worried a lot about many different things?' },
      { id: 'gad_7_4', item: 4, domain: 'relaxation',
        text: 'In the past two weeks, how often has your child had trouble calming down or relaxing?' },
      { id: 'gad_7_5', item: 5, domain: 'restlessness',
        text: 'In the past two weeks, how often has your child been so wiggly or restless that it\'s hard for them to sit still?' },
      { id: 'gad_7_6', item: 6, domain: 'irritability',
        text: 'In the past two weeks, how often has your child gotten upset or cranky easily?' },
      { id: 'gad_7_7', item: 7, domain: 'fear',
        text: 'In the past two weeks, how often has your child felt really scared that something bad might happen?' }
    ].freeze

    class << self
      # Get PHQ-A questions appropriate for child's age
      #
      # @param age [Integer] Child's age in years
      # @return [Array<Hash>] PHQ-A questions with metadata
      def phq_a_questions(age:)
        return PHQ_A_SIMPLIFIED if age < 13

        PHQ_A_STANDARD
      end

      # Get GAD-7 questions appropriate for child's age
      #
      # @param age [Integer] Child's age in years
      # @return [Array<Hash>] GAD-7 questions with metadata
      def gad_7_questions(age:)
        return GAD_7_SIMPLIFIED if age < 13

        GAD_7_STANDARD
      end

      # Get all questions for assessment
      #
      # @param age [Integer] Child's age in years
      # @return [Hash] All questions organized by instrument
      def all_questions(age:)
        {
          phq_a: phq_a_questions(age: age),
          gad_7: gad_7_questions(age: age)
        }
      end

      # Get specific question by ID
      #
      # @param question_id [String] Question ID (e.g., 'phq_a_1')
      # @param age [Integer] Child's age in years
      # @return [Hash, nil] Question hash or nil if not found
      def find_question(question_id:, age:)
        instrument, item_str = question_id.to_s.split('_', 2)
        return nil unless item_str

        case instrument
        when 'phq'
          # Handle phq_a_X format
          phq_a_questions(age: age).find { |q| q[:id] == question_id }
        when 'gad'
          # Handle gad_7_X format
          gad_7_questions(age: age).find { |q| q[:id] == question_id }
        end
      end

      # Get next question in sequence
      #
      # @param current_question_id [String] Current question ID
      # @param age [Integer] Child's age in years
      # @return [Hash, nil] Next question or nil if assessment complete
      def next_question(current_question_id:, age:)
        all = all_questions(age: age)
        flat_questions = all[:phq_a] + all[:gad_7]

        current_index = flat_questions.find_index { |q| q[:id] == current_question_id }
        return flat_questions.first if current_index.nil?

        flat_questions[current_index + 1]
      end

      # Get question by instrument and item number
      #
      # @param instrument [String] 'phq_a' or 'gad_7'
      # @param item [Integer] Item number (1-based)
      # @param age [Integer] Child's age in years
      # @return [Hash, nil] Question hash or nil if not found
      def question_by_item(instrument:, item:, age:)
        questions = case instrument.to_s
                    when 'phq_a' then phq_a_questions(age: age)
                    when 'gad_7' then gad_7_questions(age: age)
                    else []
                    end

        questions.find { |q| q[:item] == item }
      end

      # Get natural language Likert options for conversational presentation
      #
      # @return [String] Natural language options string
      def likert_options_text
        "not at all, several days, more than half the days, or nearly every day"
      end

      # Get Likert scale definition
      #
      # @return [Hash] Likert scale with labels and keywords
      def likert_scale
        LIKERT_SCALE
      end

      # Validate question ID is valid
      #
      # @param question_id [String] Question ID to validate
      # @param age [Integer] Child's age in years
      # @return [Boolean] True if valid
      def valid_question_id?(question_id:, age:)
        find_question(question_id: question_id, age: age).present?
      end

      # Get total question count
      #
      # @return [Integer] Total questions (16)
      def total_questions
        16 # 9 PHQ-A + 7 GAD-7
      end

      # Get PHQ-A severity interpretation
      #
      # @param score [Integer] PHQ-A total score (0-27)
      # @return [Hash] Severity level with label and description
      def phq_a_severity(score)
        case score
        when 0..4
          { level: :minimal, label: 'Minimal Depression', description: 'Symptoms are minimal or absent' }
        when 5..9
          { level: :mild, label: 'Mild Depression', description: 'Mild depressive symptoms present' }
        when 10..14
          { level: :moderate, label: 'Moderate Depression', description: 'Moderate depressive symptoms; warrants clinical attention' }
        when 15..19
          { level: :moderately_severe, label: 'Moderately Severe Depression', description: 'Significant symptoms; active treatment recommended' }
        when 20..27
          { level: :severe, label: 'Severe Depression', description: 'Severe symptoms; immediate intervention recommended' }
        else
          { level: :unknown, label: 'Unknown', description: 'Invalid score' }
        end
      end

      # Get GAD-7 severity interpretation
      #
      # @param score [Integer] GAD-7 total score (0-21)
      # @return [Hash] Severity level with label and description
      def gad_7_severity(score)
        case score
        when 0..4
          { level: :minimal, label: 'Minimal Anxiety', description: 'Symptoms are minimal or absent' }
        when 5..9
          { level: :mild, label: 'Mild Anxiety', description: 'Mild anxiety symptoms present' }
        when 10..14
          { level: :moderate, label: 'Moderate Anxiety', description: 'Moderate anxiety symptoms; warrants clinical attention' }
        when 15..21
          { level: :severe, label: 'Severe Anxiety', description: 'Severe symptoms; immediate intervention recommended' }
        else
          { level: :unknown, label: 'Unknown', description: 'Invalid score' }
        end
      end
    end
  end
end
