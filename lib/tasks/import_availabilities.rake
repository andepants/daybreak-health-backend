# frozen_string_literal: true

# Import clinician availabilities from CSV
#
# This task imports therapist availability data from the Healthie export CSV.
# It maps user_id from the CSV to therapist.external_id in our database.
#
# Usage:
#   bundle exec rails import:clinician_availabilities
#   bundle exec rails import:clinician_availabilities[dry_run]
#   bundle exec rails import:clinician_availabilities[force]
#
# CSV columns used:
#   - user_id: Maps to therapist.external_id
#   - day_of_week: 0-6 (Sunday-Saturday)
#   - range_start: Start datetime (UTC)
#   - range_end: End datetime (UTC)
#   - timezone: IANA timezone
#   - is_repeating: boolean
#   - deleted_at: If present, row is deleted
#
namespace :import do
  desc "Import clinician availabilities from CSV"
  task :clinician_availabilities, [:mode] => :environment do |_t, args|
    mode = args[:mode] || "normal"
    dry_run = mode == "dry_run"
    force = mode == "force"

    csv_path = Rails.root.join("docs/test-cases/clinician_availabilities.csv")

    unless File.exist?(csv_path)
      puts "ERROR: CSV file not found at #{csv_path}"
      exit 1
    end

    puts "=" * 60
    puts "Clinician Availability Import"
    puts "=" * 60
    puts "Mode: #{dry_run ? 'DRY RUN' : (force ? 'FORCE (delete existing)' : 'NORMAL')}"
    puts "CSV: #{csv_path}"
    puts

    # Read and parse CSV
    require "csv"
    rows = CSV.read(csv_path, headers: true)
    puts "Total rows in CSV: #{rows.count}"

    # Filter out deleted rows
    active_rows = rows.reject { |row| row["deleted_at"].present? }
    puts "Active rows (not deleted): #{active_rows.count}"

    # Filter to only repeating availabilities
    repeating_rows = active_rows.select { |row| row["is_repeating"] == "true" }
    puts "Repeating availabilities: #{repeating_rows.count}"
    puts

    # Get unique user_ids
    user_ids = repeating_rows.map { |row| row["user_id"] }.uniq
    puts "Unique clinician IDs: #{user_ids.count}"

    # Map to therapists
    therapist_map = {}
    user_ids.each do |user_id|
      therapist = Therapist.find_by(external_id: user_id.to_s)
      therapist_map[user_id] = therapist if therapist
    end

    puts "Mapped to existing therapists: #{therapist_map.count}"
    puts

    if therapist_map.empty?
      puts "WARNING: No therapists found with matching external_id."
      puts "Make sure therapists have been imported with their external_id set."
      puts
      puts "User IDs in CSV (first 10):"
      user_ids.first(10).each { |id| puts "  - #{id}" }
      exit 1 unless dry_run
    end

    # Process availabilities
    stats = {
      created: 0,
      skipped_no_therapist: 0,
      skipped_duplicate: 0,
      errors: 0
    }

    # Clear existing if force mode
    if force && !dry_run
      puts "Force mode: Clearing existing therapist availabilities..."
      TherapistAvailability.where(therapist_id: therapist_map.values.map(&:id)).delete_all
    end

    repeating_rows.each do |row|
      user_id = row["user_id"]
      therapist = therapist_map[user_id]

      unless therapist
        stats[:skipped_no_therapist] += 1
        next
      end

      # Parse times
      begin
        timezone = row["timezone"] || "America/Los_Angeles"
        range_start = Time.parse(row["range_start"])
        range_end = Time.parse(row["range_end"])

        # Convert to local timezone for start/end times
        tz = ActiveSupport::TimeZone[timezone]
        local_start = range_start.in_time_zone(tz)
        local_end = range_end.in_time_zone(tz)

        day_of_week = row["day_of_week"].to_i
        start_time = local_start.strftime("%H:%M")
        end_time = local_end.strftime("%H:%M")

        # Check for duplicates
        existing = TherapistAvailability.find_by(
          therapist_id: therapist.id,
          day_of_week: day_of_week,
          start_time: Time.parse(start_time),
          end_time: Time.parse(end_time)
        )

        if existing && !force
          stats[:skipped_duplicate] += 1
          next
        end

        if dry_run
          puts "Would create: #{therapist.full_name} - #{%w[Sun Mon Tue Wed Thu Fri Sat][day_of_week]} #{start_time}-#{end_time} (#{timezone})"
        else
          TherapistAvailability.create!(
            therapist_id: therapist.id,
            day_of_week: day_of_week,
            start_time: Time.parse(start_time),
            end_time: Time.parse(end_time),
            timezone: timezone,
            is_repeating: true
          )
        end

        stats[:created] += 1
      rescue StandardError => e
        stats[:errors] += 1
        puts "ERROR processing row: #{e.message}"
        puts "  Row: #{row.to_h.slice('user_id', 'day_of_week', 'range_start', 'range_end')}"
      end
    end

    puts
    puts "=" * 60
    puts "Import Summary"
    puts "=" * 60
    puts "Created: #{stats[:created]}"
    puts "Skipped (no therapist): #{stats[:skipped_no_therapist]}"
    puts "Skipped (duplicate): #{stats[:skipped_duplicate]}"
    puts "Errors: #{stats[:errors]}"
    puts
    puts "DRY RUN - No changes made" if dry_run
  end

  desc "Import patient availabilities from CSV"
  task :patient_availabilities, [:mode] => :environment do |_t, args|
    mode = args[:mode] || "normal"
    dry_run = mode == "dry_run"

    csv_path = Rails.root.join("docs/test-cases/patient_availabilities.csv")

    unless File.exist?(csv_path)
      puts "ERROR: CSV file not found at #{csv_path}"
      puts "Patient availabilities file is optional - skipping."
      exit 0
    end

    puts "=" * 60
    puts "Patient Availability Import"
    puts "=" * 60
    puts "Mode: #{dry_run ? 'DRY RUN' : 'NORMAL'}"
    puts "CSV: #{csv_path}"
    puts

    # Implementation would follow similar pattern to clinician import
    # but mapping to onboarding_session instead of therapist
    puts "Patient availability import not yet implemented."
    puts "Patient availabilities are typically submitted via the frontend form."
  end
end
