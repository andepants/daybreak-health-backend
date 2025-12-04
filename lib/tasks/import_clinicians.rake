# frozen_string_literal: true

# Import clinicians from CSV
#
# This task imports therapist data from the Healthie export CSV.
# It parses profile_data and migration_profile_data JSON columns
# to extract bio, languages, NPI, and other profile information.
#
# Usage:
#   bundle exec rails import:clinicians
#   bundle exec rails import:clinicians[dry_run]
#   bundle exec rails import:clinicians[force]
#
# CSV columns used:
#   - id: UUID (used as therapist.id if new record)
#   - healthie_id: External ID (maps to therapist.external_id)
#   - first_name, last_name: Names (may be anonymized)
#   - email, phone: Contact info
#   - profile_data: JSON with bio, npi_number, self_gender, etc.
#   - migration_profile_data: JSON with full_name, languages, etc.
#   - states_active: JSON array of licensed states
#   - care_languages: JSON array of language codes
#
namespace :import do
  desc "Import clinicians from CSV"
  task :clinicians, [:mode] => :environment do |_t, args|
    mode = args[:mode] || "normal"
    dry_run = mode == "dry_run"
    force = mode == "force"

    csv_path = Rails.root.join("docs/test-cases/clinicians_anonymized.csv")

    unless File.exist?(csv_path)
      puts "ERROR: CSV file not found at #{csv_path}"
      exit 1
    end

    puts "=" * 60
    puts "Clinician Import"
    puts "=" * 60
    puts "Mode: #{dry_run ? 'DRY RUN' : (force ? 'FORCE (update existing)' : 'NORMAL')}"
    puts "CSV: #{csv_path}"
    puts

    require "csv"

    stats = {
      created: 0,
      updated: 0,
      skipped: 0,
      errors: 0
    }

    # Clear existing if force mode (except seed data)
    if force && !dry_run
      puts "Force mode: Will update existing therapists with matching external_id..."
    end

    CSV.foreach(csv_path, headers: true) do |row|
      process_clinician_row(row, dry_run, force, stats)
    end

    puts
    puts "=" * 60
    puts "Import Summary"
    puts "=" * 60
    puts "Created: #{stats[:created]}"
    puts "Updated: #{stats[:updated]}"
    puts "Skipped: #{stats[:skipped]}"
    puts "Errors: #{stats[:errors]}"
    puts
    puts "DRY RUN - No changes made" if dry_run

    if stats[:created] > 0 || stats[:updated] > 0
      puts
      puts "Next steps:"
      puts "  1. Run availability import: bundle exec rails import:clinician_availabilities"
      puts "  2. Verify data: rails c -e development"
      puts "     > Therapist.count"
      puts "     > Therapist.first.education"
    end
  end

  desc "Import all clinician data (clinicians + availabilities)"
  task :all_clinician_data, [:mode] => :environment do |_t, args|
    Rake::Task["import:clinicians"].invoke(args[:mode])
    Rake::Task["import:clinicians"].reenable
    Rake::Task["import:clinician_availabilities"].invoke(args[:mode])
  end

  private

  # Process a single clinician row from CSV
  #
  # @param row [CSV::Row] CSV row
  # @param dry_run [Boolean] If true, don't make changes
  # @param force [Boolean] If true, update existing records
  # @param stats [Hash] Stats counters
  def process_clinician_row(row, dry_run, force, stats)
    healthie_id = row["healthie_id"]
    return if healthie_id.blank?

    # Parse JSON columns
    profile_data = parse_json(row["profile_data"])
    migration_data = parse_json(row["migration_profile_data"])

    # Extract full name (prefer migration_data, fall back to first/last)
    full_name = migration_data["full_name"] || "#{row['first_name']} #{row['last_name']}"
    name_parts = full_name.split(" ", 2)
    first_name = name_parts[0] || "Unknown"
    last_name = name_parts[1] || "Therapist"

    # Parse languages
    languages = parse_languages(row["care_languages"], migration_data["languages"])

    # Parse states
    states_active = parse_json(row["states_active"]) || []
    primary_state = states_active.first

    # Build therapist attributes
    therapist_attrs = {
      external_id: healthie_id,
      first_name: first_name,
      last_name: last_name,
      email: row["email"],
      phone: row["phone"],
      bio: profile_data["bio"],
      npi_number: profile_data["npi_number"],
      languages: languages,
      license_state: primary_state,
      gender: profile_data["self_gender"],
      ethnicity: profile_data["ethnicity"],
      religion: profile_data["religion"],
      treatment_modalities: profile_data["modalities"] || [],
      active: true,
      appointment_duration_minutes: 50,
      buffer_time_minutes: 10,
      profile_data: build_profile_data(profile_data, migration_data)
    }

    if dry_run
      puts "Would import: #{first_name} #{last_name} (healthie_id: #{healthie_id})"
      puts "  Bio: #{(profile_data['bio'] || '').truncate(60)}"
      puts "  Languages: #{languages.join(', ')}"
      puts "  State: #{primary_state}"
      stats[:created] += 1
      return
    end

    # Find or create therapist
    therapist = Therapist.find_by(external_id: healthie_id)

    if therapist && !force
      stats[:skipped] += 1
      return
    end

    if therapist
      therapist.update!(therapist_attrs)
      puts "Updated: #{therapist.full_name} (#{healthie_id})"
      stats[:updated] += 1
    else
      therapist = Therapist.create!(therapist_attrs)
      puts "Created: #{therapist.full_name} (#{healthie_id})"

      # Create specializations if available
      create_specializations(therapist, profile_data["specialties"])

      stats[:created] += 1
    end
  rescue StandardError => e
    stats[:errors] += 1
    puts "ERROR: #{e.message}"
    puts "  Row healthie_id: #{row['healthie_id']}"
  end

  # Parse JSON string safely
  #
  # @param json_str [String, nil] JSON string
  # @return [Hash, Array, nil] Parsed JSON or nil
  def parse_json(json_str)
    return nil if json_str.blank?

    JSON.parse(json_str)
  rescue JSON::ParserError
    nil
  end

  # Parse languages from various sources
  #
  # @param care_languages_str [String] JSON array of language codes
  # @param migration_languages [Array] Languages from migration data
  # @return [Array<String>] Language names
  def parse_languages(care_languages_str, migration_languages)
    languages = []

    # Map language codes to names
    language_map = {
      "eng" => "English",
      "spa" => "Spanish",
      "vie" => "Vietnamese",
      "zho" => "Chinese",
      "kor" => "Korean",
      "jpn" => "Japanese",
      "ara" => "Arabic",
      "fra" => "French",
      "deu" => "German",
      "por" => "Portuguese",
      "rus" => "Russian",
      "hin" => "Hindi"
    }

    # Try care_languages first (JSON array like ["eng", "spa"])
    if care_languages_str.present?
      codes = parse_json(care_languages_str)
      if codes.is_a?(Array)
        languages = codes.map { |c| language_map[c] || c.to_s.capitalize }.compact.uniq
      end
    end

    # Fall back to migration_data languages
    if languages.empty? && migration_languages.is_a?(Array)
      languages = migration_languages.uniq
    end

    # Default to English if nothing found
    languages.presence || ["English"]
  end

  # Build profile_data JSON from source data
  #
  # @param profile_data [Hash] Original profile_data JSON
  # @param migration_data [Hash] Migration profile data JSON
  # @return [Hash] Combined profile data for storage
  def build_profile_data(profile_data, migration_data)
    {
      "employment_type" => profile_data["employment_type"],
      "sexual_orientation" => profile_data["sexual_orientation"],
      "specialties" => profile_data["specialties"] || [],
      "health_plans_active" => migration_data["health_plans_active"],
      # These would be populated later if we have the data
      "education" => [],
      "certifications" => [],
      "approach" => nil
    }.compact
  end

  # Create specialization records for a therapist
  #
  # @param therapist [Therapist] Therapist record
  # @param specialties [Array] Specialty names
  def create_specializations(therapist, specialties)
    return unless specialties.is_a?(Array)

    specialties.each do |specialty|
      next if specialty.blank?

      TherapistSpecialization.find_or_create_by!(
        therapist: therapist,
        specialization: specialty
      )
    end
  rescue StandardError => e
    puts "  Warning: Could not create specializations: #{e.message}"
  end
end
