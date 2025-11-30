# frozen_string_literal: true

require 'csv'
require 'set'

# AC 5.1.8: Therapist data can be seeded/imported from existing system
# This script imports therapist profiles from CSV files:
# - docs/test-cases/clinicians_anonymized.csv (therapist profiles)
# - docs/test-cases/clinician_credentialed_insurances.csv (therapist-insurance join)
# - docs/test-cases/credentialed_insurances.csv (insurance definitions)

puts "Starting therapist data import..."

# Paths to CSV files
clinicians_path = Rails.root.join('docs', 'test-cases', 'clinicians_anonymized.csv')
clinician_insurance_path = Rails.root.join('docs', 'test-cases', 'clinician_credentialed_insurances.csv')
credentialed_insurance_path = Rails.root.join('docs', 'test-cases', 'credentialed_insurances.csv')

# Check if files exist
unless File.exist?(clinicians_path)
  puts "ERROR: #{clinicians_path} not found"
  exit 1
end

unless File.exist?(clinician_insurance_path)
  puts "ERROR: #{clinician_insurance_path} not found"
  exit 1
end

unless File.exist?(credentialed_insurance_path)
  puts "ERROR: #{credentialed_insurance_path} not found"
  exit 1
end

# Step 1: Load credentialed insurances data into a hash for quick lookup
puts "Loading credentialed insurances..."
credentialed_insurances = {}
CSV.foreach(credentialed_insurance_path, headers: true) do |row|
  credentialed_insurances[row['id']] = {
    name: row['name'],
    state: row['state'],
    line_of_business: row['line_of_business'],
    network_status: row['network_status']&.to_i || 0
  }
end
puts "Loaded #{credentialed_insurances.count} credentialed insurances"

# Step 2: Load clinician-insurance relationships into a hash
puts "Loading clinician-insurance relationships..."
clinician_insurances = {}
CSV.foreach(clinician_insurance_path, headers: true) do |row|
  provider_id = row['care_provider_profile_id']
  insurance_id = row['credentialed_insurance_id']

  clinician_insurances[provider_id] ||= []
  clinician_insurances[provider_id] << insurance_id if insurance_id.present?
end
puts "Loaded insurance relationships for #{clinician_insurances.count} clinicians"

# Step 3: Import therapist profiles
puts "Importing therapist profiles..."
imported_count = 0
skipped_count = 0
error_count = 0

CSV.foreach(clinicians_path, headers: true) do |row|
  begin
    # Skip if therapist already exists (based on external_id)
    if Therapist.exists?(external_id: row['id'])
      skipped_count += 1
      next
    end

    # Parse profile_data JSON if present
    profile_data = {}
    if row['profile_data'].present?
      begin
        profile_data = JSON.parse(row['profile_data'])
      rescue JSON::ParserError => e
        puts "  Warning: Failed to parse profile_data for #{row['first_name']} #{row['last_name']}: #{e.message}"
      end
    end

    # Parse care_languages array
    languages = []
    if row['care_languages'].present?
      begin
        lang_array = JSON.parse(row['care_languages'])
        # Convert language codes to lowercase (eng -> en)
        languages = lang_array.map { |lang| lang&.downcase&.slice(0, 2) }.compact
      rescue JSON::ParserError
        # Fallback to parsing as simple string
        languages = ['en']
      end
    end

    # Parse states_active array (more reliable than licensed_states)
    states_active = []
    if row['states_active'].present?
      begin
        states_active = JSON.parse(row['states_active'])
      rescue JSON::ParserError
        states_active = []
      end
    end

    # Get primary state (use primary_state column, fallback to first states_active)
    primary_state = row['primary_state'].presence || states_active.first

    # Extract data from profile_data
    bio = profile_data['bio']
    npi_number = profile_data['npi_number']
    specialties = profile_data['specialties'] || []
    modalities = profile_data['modalities'] || []

    # Determine active status
    # Since 'active' column is empty in CSV, use migration_profile_data status or default to true
    active_status = true
    if row['active'].present?
      active_status = row['active'] == 'true' || row['active'] == '1' || row['active'] == 't'
    elsif profile_data['status'].present?
      active_status = profile_data['status']&.downcase == 'active'
    end

    # Create therapist record
    therapist = Therapist.create!(
      external_id: row['id'],
      first_name: row['first_name'],
      last_name: row['last_name'],
      email: row['email'],
      phone: row['phone'],
      license_state: primary_state,
      npi_number: npi_number,
      bio: bio,
      active: active_status,
      languages: languages,
      age_ranges: [], # Will be populated later if needed
      treatment_modalities: modalities.is_a?(Array) ? modalities.map(&:downcase) : []
    )

    # Create specializations
    if specialties.is_a?(Array) && specialties.any?
      specialties.each do |specialty|
        next if specialty.blank?

        therapist.therapist_specializations.create!(
          specialization: specialty.downcase.gsub(/\s+/, '_')
        )
      end
    end

    # Create insurance panel relationships
    if clinician_insurances[row['id']].present?
      # Track unique combinations to avoid duplicates
      created_panels = Set.new

      clinician_insurances[row['id']].each do |insurance_id|
        insurance_data = credentialed_insurances[insurance_id]
        next unless insurance_data

        # Create unique key for this panel
        panel_key = "#{insurance_data[:name]}|#{insurance_data[:state]}"
        next if created_panels.include?(panel_key)

        # Normalize network_status: only 0 (in_network) and 1 (out_of_network) are valid
        network_status = case insurance_data[:network_status]
                         when 0, '0' then 0
                         when 1, '1' then 1
                         else 0 # Default to in_network for any other value
                         end

        therapist.therapist_insurance_panels.create!(
          insurance_name: insurance_data[:name],
          insurance_state: insurance_data[:state],
          line_of_business: insurance_data[:line_of_business],
          network_status: network_status,
          external_insurance_id: insurance_id
        )

        created_panels.add(panel_key)
      end
    end

    imported_count += 1
    print "." if imported_count % 10 == 0
  rescue StandardError => e
    error_count += 1
    puts "\n  Error importing therapist #{row['first_name']} #{row['last_name']}: #{e.message}"
    puts "  #{e.backtrace.first(3).join("\n  ")}"
  end
end

puts "\n"
puts "=" * 60
puts "Therapist import completed!"
puts "=" * 60
puts "Imported: #{imported_count}"
puts "Skipped (already exists): #{skipped_count}"
puts "Errors: #{error_count}"
puts "Total therapists in database: #{Therapist.count}"
puts "Total specializations: #{TherapistSpecialization.count}"
puts "Total insurance panels: #{TherapistInsurancePanel.count}"
puts "=" * 60
