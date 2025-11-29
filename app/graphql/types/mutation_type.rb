# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    # Session mutations
    field :create_session, mutation: Mutations::Sessions::CreateSession
    field :update_session_progress, mutation: Mutations::Sessions::UpdateSessionProgress
    field :request_session_recovery, mutation: Mutations::Sessions::RequestRecovery
    field :abandon_session, mutation: Mutations::Sessions::AbandonSession
  end
end
