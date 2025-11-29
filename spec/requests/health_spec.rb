require 'spec_helper'

# Note: This test requires database connection and will be run after PostgreSQL is set up
# For now, it verifies the controller and route files exist

RSpec.describe "Health Check Configuration", type: :feature do
  describe "health endpoint" do
    it "has health controller file" do
      expect(File.exist?(File.expand_path("../../app/controllers/health_controller.rb", __dir__))).to be true
    end

    it "has health route configured" do
      routes_content = File.read(File.expand_path("../../config/routes.rb", __dir__))
      expect(routes_content).to include('get "/health"')
    end
  end
end
