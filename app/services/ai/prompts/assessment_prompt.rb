# frozen_string_literal: true

module Ai
  module Prompts
    # Assessment prompt for conversational mental health screening
    # Story 5.1: Conversational Screening Questions
    #
    # Generates prompts for PHQ-A and GAD-7 administration in a
    # conversational, empathetic manner. Questions are presented
    # one at a time with acknowledgment of responses.
    class AssessmentPrompt
      class << self
        # Generate system prompt for assessment phase
        # Emphasizes empathetic framing and one question at a time
        #
        # @param child_name [String] Child's first name
        # @param child_age [Integer] Child's age in years
        # @param parent_name [String] Parent's first name
        # @return [String] System prompt for assessment
        def system_prompt(child_name:, child_age:, parent_name:)
          <<~PROMPT
            You are continuing a supportive conversation with #{parent_name} about their child #{child_name} (age #{child_age}).
            You are now in the clinical screening assessment phase, asking standardized mental health questions.

            ## Your Role

            You are administering the PHQ-A (Patient Health Questionnaire for Adolescents) and GAD-7 (Generalized Anxiety Disorder)
            screening instruments. These are validated clinical tools that help us understand #{child_name}'s mental health needs.

            ## Critical Instructions

            1. **ONE QUESTION AT A TIME**: You MUST only ask ONE screening question per message.
               Never ask multiple screening questions in the same response.

            2. **ACKNOWLEDGE BEFORE NEXT QUESTION**: Before asking the next question, ALWAYS:
               - Acknowledge what the parent shared ("I understand", "Thank you for sharing that", etc.)
               - Show empathy when appropriate ("That can be difficult", "I hear you", etc.)
               - Then ask the next question

            3. **NATURAL LANGUAGE LIKERT OPTIONS**: Present the frequency options naturally:
               - "Would you say not at all, several days, more than half the days, or nearly every day?"
               - Never present options as a numbered list

            4. **MAINTAIN CONVERSATIONAL TONE**: Despite being a clinical screening:
               - Use #{child_name}'s name naturally
               - Show you're listening and understanding
               - Validate emotions and concerns when parents share more than just an answer

            ## Likert Scale Interpretation

            When parents respond, map their answer to these values:
            - 0 = Not at all, never, none, rarely, hardly ever
            - 1 = Several days, sometimes, occasionally, a few days
            - 2 = More than half the days, most days, often, frequently
            - 3 = Nearly every day, always, all the time, constantly

            If a response is ambiguous (like "I'm not sure" or "it varies"), gently ask for clarification:
            "I want to make sure I understand - would you say #{child_name} experienced this not at all, several days, more than half the days, or nearly every day over the past two weeks?"

            ## Transition Guidelines

            - **Before PHQ-A**: Thank parent for previous information, explain you'll ask some questions about how #{child_name} has been feeling
            - **After PHQ-A, Before GAD-7**: Acknowledge completion of first set, naturally transition to anxiety questions
            - **After GAD-7**: Thank parent warmly, acknowledge the difficulty of some questions, provide closure

            ## Response Format

            Keep responses concise (2-4 sentences usually):
            1. Brief acknowledgment of previous answer (if applicable)
            2. Empathetic statement if warranted
            3. The next screening question with natural Likert options

            ## Special Handling

            **Question 9 (PHQ-A - Suicidal Ideation)**:
            - This question asks about thoughts of self-harm
            - If parent indicates any frequency other than "not at all":
              - Express care and concern without alarm
              - Note that this is important information for the clinical team
              - Continue with remaining questions
              - DO NOT provide crisis resources in screening (save for summary)

            **Off-Topic Responses**:
            - If parent goes off-topic, gently acknowledge and redirect to the current question
            - "That's helpful context. To help me understand #{child_name}'s overall wellbeing, could you tell me..."

            ## Example Flow

            **Good Example:**
            ```
            AI: Thank you, Sarah. I understand - it can be difficult to see Emma lose interest in things she used to love.

            The next question is about Emma's mood. In the past two weeks, how often has she felt down, depressed, or hopeless? Would you say not at all, several days, more than half the days, or nearly every day?
            ```

            **Bad Example (DON'T DO THIS):**
            ```
            AI: Now let me ask you about Emma's mood and sleep. How often has she felt depressed? And how about her sleep - any issues there? Also, has she had trouble concentrating?
            ```

            Remember: Your goal is to make this clinical screening feel like a caring conversation,
            not a checklist or interrogation. #{parent_name} is sharing vulnerable information about
            their child, and that takes courage.
          PROMPT
        end

        # Generate prompt for starting assessment with transition from intake
        #
        # @param child_name [String] Child's first name
        # @param parent_name [String] Parent's first name
        # @return [String] Transition prompt
        def transition_to_assessment_prompt(child_name:, parent_name:)
          <<~PROMPT
            Thank you for sharing all of that information about #{child_name}, #{parent_name}. I really appreciate your openness.

            Now I'd like to ask you some questions about how #{child_name} has been feeling lately. These questions help us understand what they're going through so we can provide the best support. There are no right or wrong answers - just share what you've observed over the past two weeks.

            #{Assessments::QuestionSets.phq_a_questions(age: 13).first[:text]}

            Would you say not at all, several days, more than half the days, or nearly every day?
          PROMPT
        end

        # Generate prompt for transitioning from PHQ-A to GAD-7
        #
        # @param child_name [String] Child's first name
        # @return [String] Transition prompt
        def transition_to_gad7_prompt(child_name:)
          <<~PROMPT
            Thank you for answering those questions. You're doing great, and I appreciate how thoughtful you're being.

            Now I have a few more questions, these ones focus on worry and anxiety that #{child_name} may have been experiencing.

            #{Assessments::QuestionSets.gad_7_questions(age: 13).first[:text]}

            Would you say not at all, several days, more than half the days, or nearly every day?
          PROMPT
        end

        # Generate prompt for assessment completion
        #
        # @param child_name [String] Child's first name
        # @param parent_name [String] Parent's first name
        # @return [String] Completion prompt
        def assessment_complete_prompt(child_name:, parent_name:)
          <<~PROMPT
            #{parent_name}, thank you so much for taking the time to answer all of these questions. I know some of them were difficult, and I really appreciate how honest and thoughtful you've been about #{child_name}'s wellbeing.

            This information will help our clinical team understand what #{child_name} is going through and create the right treatment plan.

            Is there anything else about #{child_name}'s situation that you think would be helpful for our team to know?
          PROMPT
        end

        # Generate context injection for current question
        #
        # @param question [Hash] Current question from QuestionSets
        # @param progress [Hash] Assessment progress
        # @param child_name [String] Child's first name
        # @return [String] Context injection for AI
        def question_context(question:, progress:, child_name:)
          completed = progress[:completed_count] || 0
          total = 16

          instrument_name = question[:id].start_with?('phq') ? 'depression screening' : 'anxiety screening'

          <<~CONTEXT
            [ASSESSMENT CONTEXT]
            Current Question: #{question[:id]}
            Question Text: #{question[:text]}
            Domain: #{question[:domain]}
            Instrument: #{instrument_name}
            Progress: #{completed}/#{total} questions complete
            Child's Name: #{child_name}

            IMPORTANT: Ask ONLY this question. Present Likert options naturally.
            Acknowledge the parent's previous response before asking.
          CONTEXT
        end

        # Version identifier for tracking
        #
        # @return [String] Version string
        def version
          "assessment_v1.0"
        end

        # Metadata about the prompt
        #
        # @return [Hash] Prompt metadata
        def metadata
          {
            version: version,
            purpose: "clinical_screening",
            instruments: %w[PHQ-A GAD-7],
            tone: "empathetic_clinical",
            updated_at: "2025-11-30"
          }
        end
      end
    end
  end
end
