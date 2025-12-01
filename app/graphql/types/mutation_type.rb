# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    # Session mutations
    field :create_session, mutation: Mutations::Sessions::CreateSession
    field :update_session_progress, mutation: Mutations::Sessions::UpdateSessionProgress
    field :request_session_recovery, mutation: Mutations::Sessions::RequestRecovery
    field :abandon_session, mutation: Mutations::Sessions::AbandonSession
    field :request_human_contact, mutation: Mutations::Sessions::RequestHumanContact
    field :complete_assessment, mutation: Mutations::Sessions::CompleteAssessment

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

    # Story 6.3: Self-pay selection mutations
    # AC 6.3.9: Easy to switch between insurance and self-pay
    field :select_self_pay, mutation: Mutations::Insurance::SelectSelfPay
    field :switch_to_insurance, mutation: Mutations::Insurance::SwitchToInsurance

    # Story 6.4: Deductible override mutation
    # AC 6.4.6: Manual entry option with audit trail
    field :update_deductible_override, mutation: Mutations::Billing::UpdateDeductibleOverride

    # Story 6.5: Payment plan selection mutation
    # AC 6.5.8: Save payment plan selection for billing integration
    field :save_payment_plan_selection, mutation: Mutations::Billing::SavePaymentPlanSelection

    # Assessment mutations (Story 5.1)
    field :submit_assessment_response, mutation: Mutations::Assessment::SubmitResponse

    # Therapist mutations (Story 5.1)
    # AC 5.1.9: Admin can CRUD therapist profiles via GraphQL
    field :create_therapist, mutation: Mutations::Therapists::CreateTherapist
    field :update_therapist, mutation: Mutations::Therapists::UpdateTherapist
    field :delete_therapist, mutation: Mutations::Therapists::DeleteTherapist

    # Scheduling mutations (Story 5.2)
    # AC 5.2.1: Admin can manage therapist availability slots
    # AC 5.2.2: Admin can manage therapist time-off periods
    field :create_availability, mutation: Mutations::Scheduling::CreateAvailability
    field :update_availability, mutation: Mutations::Scheduling::UpdateAvailability
    field :delete_availability, mutation: Mutations::Scheduling::DeleteAvailability
    field :create_time_off, mutation: Mutations::Scheduling::CreateTimeOff
    field :delete_time_off, mutation: Mutations::Scheduling::DeleteTimeOff

    # Story 5.4: Therapist selection mutation
    # Records parent's therapist selection for analytics
    field :select_therapist, mutation: Mutations::SelectTherapist

    # Story 5.5: Appointment booking mutations
    # AC 5.5.1-5.5.9: Book, cancel, and reschedule appointments
    field :book_appointment, mutation: Mutations::Scheduling::BookAppointment
    field :cancel_appointment, mutation: Mutations::Scheduling::CancelAppointment
    field :reschedule_appointment, mutation: Mutations::Scheduling::RescheduleAppointment
  end
end
