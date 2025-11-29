# frozen_string_literal: true

# This file should ensure the existence of records required to run the application
# in every environment (production, development, test).
#
# Example:
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Load test data in development
if Rails.env.development?
  require_relative 'seeds/test_data'

  puts "Loading test data..."
  TestDataSeeder.new.seed_all
end
