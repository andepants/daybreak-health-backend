require 'spec_helper'

RSpec.describe "Project Structure", type: :feature do
  let(:root_path) { File.expand_path("..", __dir__) }

  describe "required directories" do
    it "has app/graphql directory" do
      expect(Dir.exist?(File.join(root_path, "app/graphql"))).to be true
    end

    it "has app/services directory" do
      expect(Dir.exist?(File.join(root_path, "app/services"))).to be true
    end

    it "has app/policies directory" do
      expect(Dir.exist?(File.join(root_path, "app/policies"))).to be true
    end

    it "has app/jobs directory" do
      expect(Dir.exist?(File.join(root_path, "app/jobs"))).to be true
    end

    it "has lib/encryption directory" do
      expect(Dir.exist?(File.join(root_path, "lib/encryption"))).to be true
    end

    it "has lib/ai_providers directory" do
      expect(Dir.exist?(File.join(root_path, "lib/ai_providers"))).to be true
    end
  end

  describe "base classes" do
    it "has BaseService class file" do
      expect(File.exist?(File.join(root_path, "app/services/base_service.rb"))).to be true
    end

    it "has ApplicationPolicy class file" do
      expect(File.exist?(File.join(root_path, "app/policies/application_policy.rb"))).to be true
    end
  end

  describe "configuration files" do
    it "has .env.example file" do
      expect(File.exist?(File.join(root_path, ".env.example"))).to be true
    end

    it ".env.example contains DATABASE_URL" do
      content = File.read(File.join(root_path, ".env.example"))
      expect(content).to include("DATABASE_URL")
    end

    it ".env.example contains REDIS_URL" do
      content = File.read(File.join(root_path, ".env.example"))
      expect(content).to include("REDIS_URL")
    end

    it ".env.example contains JWT_SECRET_KEY" do
      content = File.read(File.join(root_path, ".env.example"))
      expect(content).to include("JWT_SECRET_KEY")
    end

    it ".env.example contains ANTHROPIC_API_KEY" do
      content = File.read(File.join(root_path, ".env.example"))
      expect(content).to include("ANTHROPIC_API_KEY")
    end

    it ".env.example contains OPENAI_API_KEY" do
      content = File.read(File.join(root_path, ".env.example"))
      expect(content).to include("OPENAI_API_KEY")
    end

    it ".env.example contains ENCRYPTION_KEY" do
      content = File.read(File.join(root_path, ".env.example"))
      expect(content).to include("ENCRYPTION_KEY")
    end
  end

  describe "Rails version" do
    it "is Rails 7.x" do
      gemfile = File.read(File.join(root_path, "Gemfile"))
      expect(gemfile).to match(/gem\s+"rails",\s+"~>\s*7/)
    end

    it "is configured as API-only" do
      application_rb = File.read(File.join(root_path, "config/application.rb"))
      expect(application_rb).to include("config.api_only = true")
    end
  end
end
