# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::Prompts::HelpResponses do
  describe '.explain_field' do
    context 'with common fields' do
      it 'explains email field' do
        explanation = described_class.explain_field(:email)

        expect(explanation).to be_present
        expect(explanation).to include("email")
        expect(explanation.downcase).not_to include("judge")
      end

      it 'explains phone field' do
        explanation = described_class.explain_field(:phone)

        expect(explanation).to be_present
        expect(explanation).to include("phone")
      end

      it 'explains date_of_birth field' do
        explanation = described_class.explain_field(:date_of_birth)

        expect(explanation).to be_present
        expect(explanation).to include("age")
      end

      it 'explains child_name field' do
        explanation = described_class.explain_field(:child_name)

        expect(explanation).to be_present
        expect(explanation).to include("child")
      end

      it 'explains concerns field' do
        explanation = described_class.explain_field(:concerns)

        expect(explanation).to be_present
        expect(explanation.downcase).not_to include("judge")
      end
    end

    context 'with style parameter' do
      it 'returns purpose explanation by default' do
        explanation = described_class.explain_field(:email)

        expect(explanation).to include("confirmation")
      end

      it 'returns why explanation when style: :why' do
        explanation = described_class.explain_field(:email, style: :why)

        expect(explanation).to include("helps us")
        expect(explanation.length).to be > 50 # Should be detailed
      end
    end

    context 'with unknown fields' do
      it 'returns generic explanation for unknown field' do
        explanation = described_class.explain_field(:unknown_field)

        expect(explanation).to be_present
        expect(explanation).to include("care")
        expect(explanation).to include("confidential")
      end
    end

    context 'with field name variations' do
      it 'handles string field names' do
        explanation = described_class.explain_field("email")

        expect(explanation).to be_present
      end

      it 'handles symbol field names' do
        explanation = described_class.explain_field(:email)

        expect(explanation).to be_present
      end

      it 'handles uppercase field names' do
        explanation = described_class.explain_field("EMAIL")

        expect(explanation).to be_present
      end
    end
  end

  describe '.why_we_ask' do
    it 'returns why explanation for email' do
      why = described_class.why_we_ask(:email)

      expect(why).to be_present
      expect(why).to include("email")
      expect(why.length).to be > 50 # Should be detailed
    end

    it 'returns why explanation for date_of_birth' do
      why = described_class.why_we_ask(:date_of_birth)

      expect(why).to be_present
      expect(why).to include("age")
    end

    it 'explains importance of child age appropriately' do
      why = described_class.why_we_ask(:child_age)

      expect(why).to include("age")
      expect(why.downcase).not_to include("judge")
    end
  end

  describe '.generic_response' do
    it 'returns response for dont_understand' do
      response = described_class.generic_response(:dont_understand)

      expect(response).to be_present
      expect(response.downcase).to include("sorry")
      expect(response.downcase).to include("rephrase")
    end

    it 'returns response for need_more_time' do
      response = described_class.generic_response(:need_more_time)

      expect(response).to be_present
      expect(response.downcase).to include("time")
      expect(response.downcase).to include("no rush")
    end

    it 'returns response for privacy_concern' do
      response = described_class.generic_response(:privacy_concern)

      expect(response).to be_present
      expect(response).to include("privacy")
      expect(response).to include("HIPAA")
    end

    it 'returns generic response for unknown situation' do
      response = described_class.generic_response(:unknown_situation)

      expect(response).to be_present
    end
  end

  describe '.off_topic_response' do
    it 'returns acknowledgment and redirect for cost_concern' do
      response = described_class.off_topic_response(:cost_concern)

      expect(response).to have_key(:acknowledge)
      expect(response).to have_key(:redirect)
      expect(response[:acknowledge]).to include("cost")
      expect(response[:redirect]).to include("intake")
    end

    it 'returns acknowledgment and redirect for timeline_concern' do
      response = described_class.off_topic_response(:timeline_concern)

      expect(response).to have_key(:acknowledge)
      expect(response).to have_key(:redirect)
      expect(response[:acknowledge]).to include("hear back")
    end

    it 'returns acknowledgment and redirect for service_details' do
      response = described_class.off_topic_response(:service_details)

      expect(response).to have_key(:acknowledge)
      expect(response).to have_key(:redirect)
    end

    it 'returns generic response for unknown topic' do
      response = described_class.off_topic_response(:unknown_topic)

      expect(response).to have_key(:acknowledge)
      expect(response).to have_key(:redirect)
    end
  end

  describe '.build_help_response' do
    it 'builds complete help response for field' do
      response = described_class.build_help_response(:email)

      expect(response).to include("great question")
      expect(response).to include("email")
      expect(response).to include("clarify")
    end

    it 'builds empathetic response' do
      response = described_class.build_help_response(:date_of_birth)

      expect(response).to be_present
      expect(response.downcase).not_to include("must")
      expect(response.downcase).not_to include("required")
    end

    it 'ends with an invitation for clarification' do
      response = described_class.build_help_response(:phone)

      expect(response).to include("?")
    end
  end

  describe '.build_off_topic_redirection' do
    it 'builds complete redirection for cost concern' do
      redirection = described_class.build_off_topic_redirection(:cost_concern)

      expect(redirection).to include("cost")
      expect(redirection).to include("intake")
    end

    it 'builds complete redirection for timeline concern' do
      redirection = described_class.build_off_topic_redirection(:timeline_concern)

      expect(redirection).to include("hear back")
      expect(redirection).to include("complete")
    end

    it 'maintains empathetic tone in redirection' do
      redirection = described_class.build_off_topic_redirection(:service_details)

      expect(redirection.downcase).not_to include("but")
      expect(redirection.downcase).not_to include("however")
    end
  end

  describe '.available_fields' do
    it 'returns array of field symbols' do
      fields = described_class.available_fields

      expect(fields).to be_an(Array)
      expect(fields).to include(:email)
      expect(fields).to include(:phone)
      expect(fields).to include(:date_of_birth)
    end

    it 'includes all major intake fields' do
      fields = described_class.available_fields

      expect(fields).to include(:email)
      expect(fields).to include(:phone)
      expect(fields).to include(:child_name)
      expect(fields).to include(:date_of_birth)
      expect(fields).to include(:concerns)
    end
  end

  describe '.has_explanation?' do
    it 'returns true for field with explanation' do
      expect(described_class.has_explanation?(:email)).to be true
      expect(described_class.has_explanation?(:phone)).to be true
    end

    it 'returns false for field without explanation' do
      expect(described_class.has_explanation?(:unknown_field)).to be false
    end

    it 'handles string field names' do
      expect(described_class.has_explanation?("email")).to be true
    end
  end

  context 'AC2: Clarifying questions answered with helpful context' do
    it 'provides helpful context for common fields' do
      %i[email phone date_of_birth child_name concerns].each do |field|
        explanation = described_class.explain_field(field)

        expect(explanation).to be_present
        expect(explanation.length).to be > 30 # Should be detailed
      end
    end
  end

  context 'AC5: "Why" questions explained with empathy' do
    it 'explains why with empathetic tone' do
      why = described_class.why_we_ask(:email)

      expect(why).to be_present
      # Should not use judgmental language
      expect(why.downcase).not_to include("must")
      expect(why.downcase).not_to include("required to")
      expect(why.downcase).not_to include("have to")
    end

    it 'provides reassurance about privacy' do
      why = described_class.why_we_ask(:email)

      expect(why.downcase).to include("privacy")
    end
  end

  context 'AC8: Never makes parent feel judged or rushed' do
    it 'uses patient tone in generic responses' do
      response = described_class.generic_response(:need_more_time)

      expect(response.downcase).to include("no rush")
      expect(response.downcase).to include("time you need")
    end

    it 'uses supportive language in help responses' do
      response = described_class.build_help_response(:concerns)

      expect(response.downcase).not_to include("quickly")
      expect(response.downcase).not_to include("hurry")
      expect(response.downcase).not_to include("just answer")
    end

    it 'acknowledges parent concerns in off-topic responses' do
      response = described_class.off_topic_response(:cost_concern)

      expect(response[:acknowledge].downcase).to include("great question")
    end
  end

  context 'tone and empathy' do
    it 'maintains empathetic tone across all responses' do
      fields = described_class.available_fields

      fields.each do |field|
        explanation = described_class.explain_field(field)

        # Should not use commanding language
        expect(explanation.downcase).not_to match(/\byou must\b/)
        expect(explanation.downcase).not_to match(/\byou have to\b/)
        expect(explanation.downcase).not_to match(/\byou need to\b/)
      end
    end

    it 'provides reassurance about confidentiality' do
      why = described_class.why_we_ask(:concerns)

      expect(why.downcase).to include("no judgment")
    end

    it 'emphasizes child-centered care' do
      why = described_class.why_we_ask(:child_age)

      expect(why.downcase).to include("child")
      expect(why.downcase).to include("care")
    end
  end
end
