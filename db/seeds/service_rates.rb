# frozen_string_literal: true

require 'csv'

# Service Rates Seed
#
# Seeds SessionRate records from contracts.csv data
# Extracts service types from "services" JSON array and maps to base rates
#
# Service Type Mapping:
# - individual_therapy: 1:1 child-therapist session (standard base rate)
# - family_therapy: Parent + child with therapist (premium rate)
# - onsite_care: School-based services (standard rate)
# - intake: Initial assessment/screening (assessment rate)
#
# Rate Structure (based on industry standards):
# - Intake: $175 (comprehensive initial assessment)
# - Individual Therapy: $150 (50-minute session)
# - Family Therapy: $200 (90-minute session with multiple participants)
# - Onsite Care: $175 (includes travel and coordination)
#
# These rates are configurable and will be updated based on actual contract terms
# when more detailed pricing data becomes available.

puts 'Seeding service rates...'

# Parse contracts.csv for service types and effective dates
contracts_path = Rails.root.join('docs/test-cases/contracts.csv')

unless File.exist?(contracts_path)
  puts "Warning: #{contracts_path} not found. Skipping contracts-based seeding."
  puts 'Creating default service rates instead...'
end

# Define default base rates
# These are industry-standard rates that can be overridden by contract data
default_rates = {
  'intake' => 175.00,
  'individual_therapy' => 150.00,
  'family_therapy' => 200.00,
  'onsite_care' => 175.00
}

# Track created rates
created_count = 0
updated_count = 0

if File.exist?(contracts_path)
  # Parse CSV and extract service types with effective dates
  CSV.foreach(contracts_path, headers: true) do |row|
    next unless row['services'] && row['effective_date']

    # Parse services JSON array
    services = JSON.parse(row['services'])
    effective_date = Date.parse(row['effective_date'])
    end_date = row['end_date'].present? ? Date.parse(row['end_date']) : nil

    # Map CSV service names to our service types
    service_type_mapping = {
      'individual_therapy' => 'individual_therapy',
      'family_therapy' => 'family_therapy',
      'onsite_care' => 'onsite_care'
    }

    # Create rates for each recognized service type
    services.each do |service_name|
      next unless service_type_mapping.key?(service_name)

      service_type = service_type_mapping[service_name]
      base_rate = default_rates[service_type]

      # Check if rate already exists for this service type and date range
      existing_rate = SessionRate.find_by(
        service_type: service_type,
        effective_date: effective_date
      )

      if existing_rate
        # Update existing rate
        existing_rate.update!(
          base_rate: base_rate,
          end_date: end_date,
          metadata: {
            source: 'contracts_csv',
            contract_id: row['id'],
            seeded_at: Time.current.iso8601
          }
        )
        updated_count += 1
        puts "  Updated #{service_type} rate: $#{base_rate} (effective: #{effective_date})"
      else
        # Create new rate
        SessionRate.create!(
          service_type: service_type,
          base_rate: base_rate,
          effective_date: effective_date,
          end_date: end_date,
          metadata: {
            source: 'contracts_csv',
            contract_id: row['id'],
            seeded_at: Time.current.iso8601
          }
        )
        created_count += 1
        puts "  Created #{service_type} rate: $#{base_rate} (effective: #{effective_date})"
      end
    end
  rescue JSON::ParserError => e
    puts "  Warning: Failed to parse services JSON for contract #{row['id']}: #{e.message}"
    next
  rescue Date::Error => e
    puts "  Warning: Invalid date for contract #{row['id']}: #{e.message}"
    next
  end
else
  # No contracts.csv found - create default rates with current date
  default_rates.each do |service_type, base_rate|
    existing_rate = SessionRate.find_by(
      service_type: service_type,
      effective_date: Date.current
    )

    if existing_rate
      existing_rate.update!(
        base_rate: base_rate,
        metadata: {
          source: 'default_seed',
          seeded_at: Time.current.iso8601
        }
      )
      updated_count += 1
      puts "  Updated #{service_type} rate: $#{base_rate}"
    else
      SessionRate.create!(
        service_type: service_type,
        base_rate: base_rate,
        effective_date: Date.current,
        end_date: nil, # Open-ended
        metadata: {
          source: 'default_seed',
          seeded_at: Time.current.iso8601
        }
      )
      created_count += 1
      puts "  Created #{service_type} rate: $#{base_rate}"
    end
  end
end

# Create intake rate if not already created
# Intake is not explicitly listed in contracts but is a core service
unless SessionRate.exists?(service_type: 'intake')
  SessionRate.create!(
    service_type: 'intake',
    base_rate: default_rates['intake'],
    effective_date: Date.current,
    end_date: nil,
    metadata: {
      source: 'default_seed',
      note: 'Intake assessment rate (not in contracts.csv)',
      seeded_at: Time.current.iso8601
    }
  )
  created_count += 1
  puts "  Created intake rate: $#{default_rates['intake']}"
end

puts "Service rates seeding complete: #{created_count} created, #{updated_count} updated"
puts "Total active rates: #{SessionRate.active.count}"
