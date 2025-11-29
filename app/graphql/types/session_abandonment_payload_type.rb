# frozen_string_literal: true

module Types
  # Payload type for abandonSession mutation
  #
  # Returns the updated session with ABANDONED status and a success indicator.
  # This type confirms that the session has been successfully abandoned.
  #
  # AC 2.5.7: Response confirms abandonment with session ID and new status
  class SessionAbandonmentPayloadType < Types::BaseObject
    description "Result of abandoning a session"

    field :session, Types::OnboardingSessionType, null: false,
          description: "The abandoned session with updated status"

    field :success, Boolean, null: false,
          description: "Indicates if the abandonment was successful"
  end
end
