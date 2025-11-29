# Health check endpoint for monitoring and load balancer probes
class HealthController < ApplicationController
  # GET /health
  def check
    render json: { status: "ok", timestamp: Time.current.iso8601 }, status: :ok
  end
end
