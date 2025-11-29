# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ParentMailer, type: :mailer do
  describe '#session_recovery' do
    let(:session) { create(:onboarding_session, :with_parent) }
    let(:parent) { session.parent }
    let(:recovery_url) { 'https://app.daybreak.health/recover?token=abc123def456' }
    let(:mail) { described_class.session_recovery(parent: parent, recovery_url: recovery_url) }

    it 'has correct subject' do
      expect(mail.subject).to eq('Continue your Daybreak onboarding')
    end

    it 'sends to parent email' do
      expect(mail.to).to eq([parent.email])
    end

    it 'includes recovery URL in HTML body' do
      expect(mail.html_part.body.encoded).to include(recovery_url)
    end

    it 'includes recovery URL in text body' do
      expect(mail.text_part.body.encoded).to include(recovery_url)
    end

    it 'includes expiration notice in HTML body' do
      expect(mail.html_part.body.encoded).to include('15 minutes')
    end

    it 'includes expiration notice in text body' do
      expect(mail.text_part.body.encoded).to include('15 minutes')
    end

    context 'with parent first name' do
      it 'includes personalized greeting in HTML body' do
        expect(mail.html_part.body.encoded).to include("Hi #{parent.first_name}")
      end

      it 'includes personalized greeting in text body' do
        expect(mail.text_part.body.encoded).to include("Hi #{parent.first_name}")
      end
    end

    # Note: Parent model requires first_name, so we always have a name to use
    # The email template checks for present? which handles this gracefully

    it 'includes Daybreak branding' do
      expect(mail.html_part.body.encoded).to include('Daybreak Health')
      expect(mail.text_part.body.encoded).to include('Daybreak Health')
    end

    it 'includes support contact information' do
      expect(mail.html_part.body.encoded).to include('support@daybreak.health')
      expect(mail.text_part.body.encoded).to include('support@daybreak.health')
    end

    it 'has both HTML and text parts' do
      expect(mail.html_part).to be_present
      expect(mail.text_part).to be_present
    end

    it 'includes security notice about ignoring if not requested' do
      expect(mail.html_part.body.encoded).to include("didn't request this email")
      expect(mail.text_part.body.encoded).to include("didn't request this email")
    end
  end
end
