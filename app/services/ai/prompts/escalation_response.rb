# frozen_string_literal: true

module Ai
  module Prompts
    # Escalation Response Prompt Template
    # AC 3.5.1: AI acknowledges request empathetically without making parent feel judged
    # AC 3.5.4: Contact options provided to parent
    # AC 3.5.5: Offer to continue with AI for data collection if parent agrees
    #
    # This prompt is injected into the conversation when a parent requests
    # human assistance, ensuring empathetic acknowledgment and clear next steps.
    class EscalationResponse
      class << self
        # Generate empathetic escalation acknowledgment with contact options
        # AC 3.5.1: Empathetic acknowledgment without judgment
        # AC 3.5.4: Include phone, email, chat hours
        # AC 3.5.5: Offer to continue collecting information
        #
        # @param contact_options [Hash] Contact information (phone, email, chat_hours)
        # @param escalation_reason [String, nil] Optional reason provided by parent
        # @return [String] Complete escalation response message
        def generate_response(contact_options:, escalation_reason: nil)
          # Build empathetic acknowledgment
          acknowledgment = build_acknowledgment(escalation_reason)

          # Build contact information section
          contact_info = build_contact_info(contact_options)

          # Build continuation offer
          continuation = build_continuation_offer

          # Combine all sections
          <<~RESPONSE.strip
            #{acknowledgment}

            #{contact_info}

            #{continuation}
          RESPONSE
        end

        # Generate system prompt addition for escalation mode
        # This is injected into the AI context when session is escalated
        # AC 3.5.1: Maintain empathetic tone, don't make parent feel judged
        # AC 3.5.5: Continue data collection with gentler tone
        #
        # @return [String] System prompt addition for escalation mode
        def escalation_mode_prompt
          <<~PROMPT
            ## ESCALATION MODE ACTIVE

            The parent has requested to speak with a human team member. This is completely
            valid and should never be questioned or discouraged.

            **Your Updated Role:**
            - Continue being helpful and supportive while they wait for human contact
            - Use a gentler, more accommodating tone
            - Make it clear they can stop the conversation at any time
            - Emphasize that all information collected helps expedite care
            - Never make them feel obligated to continue
            - Acknowledge that speaking with a human is a great choice

            **What to AVOID:**
            - Don't try to convince them the AI is sufficient
            - Don't ask "why" they want human contact
            - Don't make them feel they should continue if uncomfortable
            - Don't pressure for information they're hesitant to share

            **What to DO:**
            - Respect their boundaries completely
            - Offer help without expectation
            - Acknowledge any hesitation with understanding
            - Provide options ("Would it be helpful if..." vs "I need you to...")
            - Remind them a team member will reach out soon
          PROMPT
        end

        private

        # Build empathetic acknowledgment based on whether reason was provided
        #
        # @param escalation_reason [String, nil] Optional escalation reason
        # @return [String] Acknowledgment message
        def build_acknowledgment(escalation_reason)
          if escalation_reason.present?
            # Acknowledge specific reason with empathy
            "I completely understand, and I appreciate you letting me know. It makes sense " \
            "that you'd like to speak with someone from our team directly."
          else
            # Generic empathetic acknowledgment
            "I understand you'd like to speak with someone from our team, and I'm happy to " \
            "help make that connection. This is a completely normal request."
          end
        end

        # Build contact information section with all available options
        # AC 3.5.4: Provide phone, email, chat hours
        #
        # @param contact_options [Hash] Contact information
        # @return [String] Formatted contact information
        def build_contact_info(contact_options)
          phone = contact_options[:phone]
          email = contact_options[:email]
          chat_hours = contact_options[:chat_hours]

          <<~CONTACT.strip
            Here's how you can reach our team:

            📞 **Phone:** #{phone}
            📧 **Email:** #{email}
            💬 **Chat Hours:** #{chat_hours}

            A team member will also reach out to you directly based on the information
            you've provided so far.
          CONTACT
        end

        # Build offer to continue data collection
        # AC 3.5.5: Offer to continue with AI if parent agrees
        #
        # @return [String] Continuation offer message
        def build_continuation_offer
          <<~OFFER.strip
            While you wait for someone to reach out, I'm here if you'd like to continue
            sharing information about your child. Anything you can provide now will help
            our team get started more quickly when they connect with you.

            Would it be helpful for us to continue, or would you prefer to wait and share
            everything when you speak with a team member directly? Either choice is
            completely fine.
          OFFER
        end

        # Format contact options for display in prompt
        # Used when escalation context is injected into ongoing conversation
        #
        # @param contact_options [Hash] Contact information
        # @return [String] Formatted contact options for prompt
        def format_contact_options_for_prompt(contact_options)
          <<~OPTIONS
            Phone: #{contact_options[:phone]}
            Email: #{contact_options[:email]}
            Chat Hours: #{contact_options[:chat_hours]}
          OPTIONS
        end
      end
    end
  end
end
