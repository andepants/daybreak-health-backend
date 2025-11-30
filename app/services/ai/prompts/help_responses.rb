# frozen_string_literal: true

module Ai
  module Prompts
    # Help Response Templates (Story 3.3)
    # Provides empathetic explanations for common intake questions
    # to help parents understand why information is needed.
    #
    # Acceptance Criteria:
    # - AC2: Clarifying questions answered with helpful context
    # - AC5: "Why" questions explained with empathy
    # - AC8: Never makes parent feel judged or rushed
    #
    # Usage:
    #   response = Ai::Prompts::HelpResponses.explain_field(:email)
    #   # => "We need your email to send you a confirmation..."
    #
    #   response = Ai::Prompts::HelpResponses.why_we_ask(:date_of_birth)
    #   # => "We ask for your child's date of birth to ensure..."
    class HelpResponses
      # Field explanations with empathetic, supportive tone
      # AC5: "Why" questions explained with empathy
      FIELD_EXPLANATIONS = {
        email: {
          purpose: "We need your email to send you a confirmation and allow you to resume " \
                   "your session from any device. We will never share your information.",
          why: "Your email helps us keep you updated about your child's care and allows " \
               "you to access our secure parent portal. We take your privacy seriously " \
               "and use industry-standard encryption."
        },
        parent_email: {
          purpose: "We need your email to send you a confirmation and allow you to resume " \
                   "your session from any device. We will never share your information.",
          why: "Your email helps us keep you updated about your child's care and allows " \
               "you to access our secure parent portal. We take your privacy seriously " \
               "and use industry-standard encryption."
        },
        phone: {
          purpose: "Your phone number helps us reach you quickly if there's anything urgent " \
                   "about your child's care or to schedule appointments.",
          why: "We ask for your phone number so our care coordinators can contact you " \
               "efficiently. This is especially important for appointment reminders and " \
               "any time-sensitive updates about your child's treatment."
        },
        parent_phone: {
          purpose: "Your phone number helps us reach you quickly if there's anything urgent " \
                   "about your child's care or to schedule appointments.",
          why: "We ask for your phone number so our care coordinators can contact you " \
               "efficiently. This is especially important for appointment reminders and " \
               "any time-sensitive updates about your child's treatment."
        },
        name: {
          purpose: "We need your name so our team can address you personally and ensure " \
                   "we're providing care to the right family.",
          why: "Knowing your name helps us create a personal connection and ensures accuracy " \
               "in all our records. It's about treating you and your child as individuals, " \
               "not just numbers."
        },
        parent_name: {
          purpose: "We need your name so our team can address you personally and ensure " \
                   "we're providing care to the right family.",
          why: "Knowing your name helps us create a personal connection and ensures accuracy " \
               "in all our records. It's about treating you and your child as individuals, " \
               "not just numbers."
        },
        parent_first_name: {
          purpose: "We need your name so our team can address you personally and ensure " \
                   "we're providing care to the right family.",
          why: "Knowing your name helps us create a personal connection and ensures accuracy " \
               "in all our records. It's about treating you and your child as individuals, " \
               "not just numbers."
        },
        relationship: {
          purpose: "Understanding your relationship to the child helps us know who can make " \
                   "decisions about their care and who should receive updates.",
          why: "We ask about your relationship to ensure we're communicating with the right " \
               "people and following proper consent procedures. This protects your child's " \
               "privacy and wellbeing."
        },
        child_name: {
          purpose: "We need your child's name to create their care profile and ensure all " \
                   "our team members can address them respectfully.",
          why: "Knowing your child's name helps us provide personalized care. Every child " \
               "is unique, and we want to treat them as an individual from the very start."
        },
        child_first_name: {
          purpose: "We need your child's name to create their care profile and ensure all " \
                   "our team members can address them respectfully.",
          why: "Knowing your child's name helps us provide personalized care. Every child " \
               "is unique, and we want to treat them as an individual from the very start."
        },
        date_of_birth: {
          purpose: "We need your child's date of birth to ensure we match them with " \
                   "age-appropriate care, assessments, and providers.",
          why: "Age is really important in pediatric mental health. A 6-year-old and a " \
               "16-year-old need very different approaches to care. Your child's age helps " \
               "us assign the right therapist and use age-appropriate treatment methods."
        },
        child_age: {
          purpose: "We need your child's age to ensure we match them with age-appropriate " \
                   "care, assessments, and providers.",
          why: "Age is really important in pediatric mental health. A 6-year-old and a " \
               "16-year-old need very different approaches to care. Your child's age helps " \
               "us assign the right therapist and use age-appropriate treatment methods."
        },
        pronouns: {
          purpose: "We ask about pronouns to ensure we address your child respectfully " \
                   "and create an affirming care environment.",
          why: "Using the right pronouns is a basic way to show respect and create a safe " \
               "space. We want your child to feel comfortable and accepted from day one."
        },
        grade_level: {
          purpose: "Your child's grade level helps us understand their developmental stage " \
                   "and any school-related stressors they might be experiencing.",
          why: "School is a huge part of a child's life. Knowing their grade helps us " \
               "understand the social and academic pressures they're facing and provide " \
               "relevant support."
        },
        concerns: {
          purpose: "Understanding what brings you to Daybreak Health helps us prioritize " \
                   "your child's needs and match them with the right provider.",
          why: "We ask about your concerns so we can provide the most helpful support right " \
               "from the start. There's no judgment here - every concern is valid, and " \
               "seeking help is a sign of strength."
        },
        primary_concern: {
          purpose: "Understanding what brings you to Daybreak Health helps us prioritize " \
                   "your child's needs and match them with the right provider.",
          why: "We ask about your concerns so we can provide the most helpful support right " \
               "from the start. There's no judgment here - every concern is valid, and " \
               "seeking help is a sign of strength."
        },
        insurance: {
          purpose: "Insurance information helps us verify your coverage and minimize any " \
                   "out-of-pocket costs for your family.",
          why: "We ask about insurance to make mental health care more affordable for your " \
               "family. We'll handle the billing details so you can focus on your child's " \
               "wellbeing."
        },
        medical_history: {
          purpose: "Understanding your child's medical history helps us provide safe, " \
                   "comprehensive care and avoid any potential complications.",
          why: "Medical history gives our providers important context. Some medications or " \
               "conditions can affect mental health treatment, and we want to ensure your " \
               "child receives the safest, most effective care possible."
        }
      }.freeze

      # Generic responses for common help situations
      # AC2: Clarifying questions answered with helpful context
      GENERIC_RESPONSES = {
        dont_understand: {
          response: "I'm sorry for the confusion. Let me rephrase that question in a " \
                    "different way that might be clearer.",
          tone: "apologetic and helpful"
        },
        need_more_time: {
          response: "Take all the time you need. There's absolutely no rush. I'm here to " \
                    "support you through this process at whatever pace feels comfortable.",
          tone: "patient and reassuring"
        },
        privacy_concern: {
          response: "I completely understand your concern about privacy. All the information " \
                    "you share is protected by HIPAA and encrypted. We never share your " \
                    "information without your explicit consent.",
          tone: "understanding and reassuring"
        },
        too_personal: {
          response: "I appreciate you sharing that concern. We only ask for information that's " \
                    "truly necessary to provide your child with the best care. If you're not " \
                    "comfortable answering something right now, please let me know.",
          tone: "respectful and accommodating"
        },
        general_confusion: {
          response: "I'm here to help. Can you tell me what part is confusing? I want to make " \
                    "sure you feel comfortable with every step of this process.",
          tone: "supportive and patient"
        }
      }.freeze

      # Off-topic acknowledgments before gentle redirection
      # AC4: AI acknowledges non-intake concerns
      OFF_TOPIC_ACKNOWLEDGMENTS = {
        cost_concern: {
          acknowledge: "That's a great question about cost. Affordability is really important " \
                       "to us, and we accept most major insurance plans.",
          redirect: "Our care coordinator will discuss specific costs and coverage details " \
                    "with you after we complete the intake. For now, let's make sure we " \
                    "understand your child's needs."
        },
        timeline_concern: {
          acknowledge: "I understand you want to know when you'll hear back. We know waiting " \
                       "can be stressful when your child needs support.",
          redirect: "Once we complete this intake, our team typically reaches out within " \
                    "1-2 business days. Let's make sure we have all the information we need " \
                    "to get you connected quickly."
        },
        service_details: {
          acknowledge: "Those are important details about our services. We want you to feel " \
                       "informed and confident about choosing Daybreak Health.",
          redirect: "Our care coordinator will provide detailed information about our services " \
                    "and answer all your questions. First, let's complete the intake so we " \
                    "can match your child with the right provider."
        },
        general_question: {
          acknowledge: "That's a good question, and I want to make sure you get accurate " \
                       "information about that.",
          redirect: "Our care coordinator will be able to address that in detail. For now, " \
                    "let's focus on understanding your child's needs so we can help them " \
                    "as quickly as possible."
        }
      }.freeze

      class << self
        # Get explanation for a specific field
        # AC2: Clarifying questions answered with helpful context
        #
        # @param field_name [String, Symbol] Field name to explain
        # @param style [Symbol] :purpose or :why (default: :purpose)
        # @return [String] Explanation text
        def explain_field(field_name, style: :purpose)
          field_key = normalize_field_name(field_name)
          explanation = FIELD_EXPLANATIONS[field_key]

          return generic_explanation if explanation.nil?

          explanation[style] || explanation[:purpose]
        end

        # Get "why we ask" explanation for a field
        # AC5: "Why" questions explained with empathy
        #
        # @param field_name [String, Symbol] Field name to explain
        # @return [String] Why explanation
        def why_we_ask(field_name)
          explain_field(field_name, style: :why)
        end

        # Get generic help response
        # AC2: Clarifying questions answered with helpful context
        #
        # @param situation [Symbol] Situation key from GENERIC_RESPONSES
        # @return [String] Response text
        def generic_response(situation)
          response = GENERIC_RESPONSES[situation]
          return generic_explanation if response.nil?

          response[:response]
        end

        # Get off-topic acknowledgment and redirection
        # AC3: Off-topic responses gently redirected to intake
        # AC4: AI acknowledges non-intake concerns
        #
        # @param topic [Symbol] Topic key from OFF_TOPIC_ACKNOWLEDGMENTS
        # @return [Hash] Hash with :acknowledge and :redirect keys
        def off_topic_response(topic)
          OFF_TOPIC_ACKNOWLEDGMENTS[topic] || OFF_TOPIC_ACKNOWLEDGMENTS[:general_question]
        end

        # Build complete help response with empathetic framing
        # AC8: AI never makes parent feel judged or rushed
        #
        # @param field_name [String, Symbol] Field to explain
        # @param parent_message [String] What the parent asked
        # @return [String] Complete empathetic response
        def build_help_response(field_name, parent_message = nil)
          explanation = explain_field(field_name, style: :why)

          # Add empathetic framing
          [
            "That's a great question.",
            explanation,
            "Does that help clarify things?"
          ].join(" ")
        end

        # Build off-topic redirection with acknowledgment
        # AC7: Conversation naturally returns to intake after addressing concerns
        #
        # @param topic [Symbol] Off-topic category
        # @param current_phase [String] Current conversation phase
        # @return [String] Complete redirection message
        def build_off_topic_redirection(topic, current_phase = nil)
          response = off_topic_response(topic)

          [
            response[:acknowledge],
            response[:redirect]
          ].join(" ")
        end

        # Get list of available field explanations
        #
        # @return [Array<Symbol>] Field names with explanations
        def available_fields
          FIELD_EXPLANATIONS.keys
        end

        # Check if field has explanation
        #
        # @param field_name [String, Symbol] Field to check
        # @return [Boolean] True if explanation exists
        def has_explanation?(field_name)
          field_key = normalize_field_name(field_name)
          FIELD_EXPLANATIONS.key?(field_key)
        end

        private

        # Normalize field name to symbol for lookup
        #
        # @param field_name [String, Symbol] Field name
        # @return [Symbol] Normalized field name
        def normalize_field_name(field_name)
          field_name.to_s.downcase.to_sym
        end

        # Generic explanation for fields without specific templates
        #
        # @return [String] Generic explanation
        def generic_explanation
          "We ask for this information to ensure we can provide your child with the best " \
          "possible care. All information you share is confidential and protected."
        end
      end
    end
  end
end
