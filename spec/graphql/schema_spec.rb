require 'spec_helper'

# Simple tests to verify GraphQL files exist
RSpec.describe "GraphQL Configuration", type: :feature do
  let(:root_path) { File.expand_path("../..", __dir__) }

  describe "GraphQL files" do
    it "has GraphQL schema file" do
      expect(File.exist?(File.join(root_path, "app/graphql/daybreak_health_backend_schema.rb"))).to be true
    end

    it "has Query type file" do
      expect(File.exist?(File.join(root_path, "app/graphql/types/query_type.rb"))).to be true
    end

    it "has Mutation type file" do
      expect(File.exist?(File.join(root_path, "app/graphql/types/mutation_type.rb"))).to be true
    end

    it "has GraphQL route configured" do
      routes_content = File.read(File.join(root_path, "config/routes.rb"))
      expect(routes_content).to include('post "/graphql"')
    end

    it "has GraphiQL route configured for development" do
      routes_content = File.read(File.join(root_path, "config/routes.rb"))
      expect(routes_content).to include('mount GraphiQL::Rails::Engine')
    end
  end
end
