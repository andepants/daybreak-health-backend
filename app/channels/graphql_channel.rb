# frozen_string_literal: true

class GraphqlChannel < ApplicationCable::Channel
  def subscribed
    @subscription_ids = []
  end

  def execute(data)
    query = data["query"]
    variables = ensure_hash(data["variables"])
    operation_name = data["operationName"]
    context = {
      channel: self,
      current_user: current_user
    }

    result = DaybreakHealthBackendSchema.execute(
      query: query,
      context: context,
      variables: variables,
      operation_name: operation_name
    )

    payload = {
      result: result.to_h,
      more: result.subscription?
    }

    # Track subscription IDs for cleanup
    if result.context[:subscription_id]
      @subscription_ids << result.context[:subscription_id]
    end

    transmit(payload)
  end

  def unsubscribed
    @subscription_ids.each do |sid|
      DaybreakHealthBackendSchema.subscriptions.delete_subscription(sid)
    end
  end

  private

  def current_user
    # TODO: Implement user authentication via connection params
    # For now, allow anonymous access for session subscriptions
    nil
  end

  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      ambiguous_param.present? ? ensure_hash(JSON.parse(ambiguous_param)) : {}
    when Hash, ActionController::Parameters
      ambiguous_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end
end
