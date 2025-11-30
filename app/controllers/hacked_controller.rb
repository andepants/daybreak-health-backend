class HackedController < ActionController::Base
  # Override to allow HTML rendering in API-only app
  def show
    render layout: false
  end
end

