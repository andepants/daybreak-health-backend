# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    # Session mutations
    field :create_session, mutation: Mutations::Sessions::CreateSession
    field :update_session_progress, mutation: Mutations::Sessions::UpdateSessionProgress
    field :request_session_recovery, mutation: Mutations::Sessions::RequestRecovery
    field :abandon_session, mutation: Mutations::Sessions::AbandonSession
    field :request_human_contact, mutation: Mutations::Sessions::RequestHumanContact

    # Auth mutations
    field :refresh_token, mutation: Mutations::Auth::RefreshToken

    # Conversation mutations
    field :send_message, mutation: Mutations::Conversation::SendMessage

    # Intake mutations
    field :submit_parent_info, mutation: Mutations::Intake::SubmitParentInfo
    field :submit_child_info, mutation: Mutations::Intake::SubmitChildInfo

    # Insurance mutations
    field :upload_insurance_card, mutation: Mutations::Insurance::UploadCard
    field :submit_insurance_info, mutation: Mutations::Insurance::SubmitInfo
    field :verify_eligibility, mutation: Mutations::Insurance::VerifyEligibility

    # Assessment mutations (Story 5.1)
    field :submit_assessment_response, mutation: Mutations::Assessment::SubmitResponse
  end
end
