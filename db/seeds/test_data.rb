# frozen_string_literal: true

# Test Data Seeder
# Loads anonymized production data from CSV test cases for development/testing
#
# Usage:
#   rails db:seed:test_data
#   # or in console:
#   TestDataSeeder.new.seed_all

require 'csv'

class TestDataSeeder
  CSV_PATH = Rails.root.join('docs', 'test-cases')

  # Status mappings from CSV system_labels to Rails enums
  REFERRAL_STATUS_MAP = {
    'referred' => :started,
    'ready_for_scheduling' => :in_progress,
    'onboarding_completed' => :assessment_complete,
    'request_rejected' => :abandoned
  }.freeze

  ELIGIBILITY_STATUS_MAP = {
    0 => :pending,
    1 => :in_progress,
    2 => :verified,
    3 => :failed,
    4 => :verified
  }.freeze

  GENDER_MAP = {
    1 => 'male',
    2 => 'female'
  }.freeze

  INSURANCE_KIND_MAP = {
    0 => :self_pay,
    2 => :insurance
  }.freeze

  attr_reader :stats

  def initialize
    @stats = Hash.new(0)
    @parent_ids = Set.new
    @child_ids = Set.new
    @user_lookup = {}
  end

  def seed_all
    puts "Starting test data seed from #{CSV_PATH}..."

    ActiveRecord::Base.transaction do
      seed_users
      seed_kinships
      seed_onboarding_sessions
      seed_insurances
      seed_assessments
    end

    print_stats
  end

  def seed_users
    puts "  Seeding parents and children..."

    each_csv_row('patients_and_guardians_anonymized.csv') do |row|
      labels = parse_array(row['system_labels'])

      if labels.include?('guardian')
        create_parent(row)
      elsif labels.include?('dependent') || labels.include?('student')
        create_child(row)
      end

      # Store for lookup
      @user_lookup[row['id']] = { labels: labels, row: row }
    end
  end

  def seed_kinships
    puts "  Linking parents to children..."

    each_csv_row('kinships.csv') do |row|
      next unless row['kind'] == '1' # Guardian relationship only

      parent_id = row['user_0_id']
      child_id = row['user_1_id']

      # Determine which is parent and which is child based on our loaded data
      if @parent_ids.include?(parent_id) && @child_ids.include?(child_id)
        link_parent_child(parent_id, child_id, row)
      elsif @parent_ids.include?(child_id) && @child_ids.include?(parent_id)
        # Swap if reversed in kinship
        link_parent_child(child_id, parent_id, row)
      end
    end
  end

  def seed_onboarding_sessions
    puts "  Seeding onboarding sessions from referrals..."

    each_csv_row('referrals.csv') do |row|
      create_onboarding_session(row)
    end
  end

  def seed_insurances
    puts "  Seeding insurance records..."

    each_csv_row('insurance_coverages.csv') do |row|
      create_insurance(row)
    end
  end

  def seed_assessments
    puts "  Seeding assessments from questionnaires..."

    each_csv_row('questionnaires.csv') do |row|
      create_assessment(row)
    end
  end

  private

  def create_parent(row)
    Parent.create!(
      id: row['id'],
      email: row['email'] || "parent_#{row['id'][0..7]}@example.com",
      phone: row['phone'],
      first_name: row['first_name'] || 'Test',
      last_name: row['last_name'] || 'Parent',
      relationship: 'parent',
      is_guardian: true,
      created_at: parse_timestamp(row['created_at']),
      updated_at: parse_timestamp(row['updated_at'])
    )
    @parent_ids.add(row['id'])
    @stats[:parents] += 1
  rescue ActiveRecord::RecordInvalid => e
    warn "    Skipping parent #{row['id']}: #{e.message}"
  end

  def create_child(row)
    Child.create!(
      id: row['id'],
      first_name: row['first_name'] || 'Test',
      last_name: row['last_name'] || 'Child',
      date_of_birth: row['birthdate'],
      gender: GENDER_MAP[row['legal_gender'].to_i],
      created_at: parse_timestamp(row['created_at']),
      updated_at: parse_timestamp(row['updated_at'])
    )
    @child_ids.add(row['id'])
    @stats[:children] += 1
  rescue ActiveRecord::RecordInvalid => e
    warn "    Skipping child #{row['id']}: #{e.message}"
  end

  def link_parent_child(parent_id, child_id, row)
    child = Child.find_by(id: child_id)
    return unless child

    # Create or find onboarding session for this parent-child pair
    session = OnboardingSession.find_or_create_by!(id: SecureRandom.uuid) do |s|
      s.status = :started
      s.expires_at = 24.hours.from_now
    end

    # Link child to session
    child.update!(onboarding_session_id: session.id)

    # Link parent to session
    parent = Parent.find_by(id: parent_id)
    parent&.update!(onboarding_session_id: session.id)

    @stats[:kinships] += 1
  rescue ActiveRecord::RecordInvalid => e
    warn "    Skipping kinship link: #{e.message}"
  end

  def create_onboarding_session(row)
    labels = parse_array(row['system_labels'])
    status = determine_session_status(labels)

    OnboardingSession.create!(
      id: row['id'],
      status: status,
      progress: parse_json(row['data']),
      expires_at: parse_timestamp(row['created_at']) + 24.hours,
      referral_source: row['organization_id'],
      created_at: parse_timestamp(row['created_at']),
      updated_at: parse_timestamp(row['updated_at'])
    )
    @stats[:sessions] += 1
  rescue ActiveRecord::RecordInvalid => e
    warn "    Skipping session #{row['id']}: #{e.message}"
  end

  def create_insurance(row)
    # Skip non-insurance (self-pay) for now
    kind = row['kind'].to_i
    return if kind == 0

    # Find associated user's onboarding session
    user_id = row['user_id']
    child = Child.find_by(id: user_id)
    session_id = child&.onboarding_session_id

    Insurance.create!(
      id: row['id'],
      onboarding_session_id: session_id,
      payer_name: row['insurance_company_name'] || row['openpm_insurance_organization_name'] || 'Unknown',
      member_id: row['member_id'],
      group_number: row['group_id'],
      card_image_front: sanitize_s3_url(row['front_card_url']),
      card_image_back: sanitize_s3_url(row['back_card_url']),
      verification_status: ELIGIBILITY_STATUS_MAP[row['eligibility'].to_i] || :pending,
      created_at: parse_timestamp(row['created_at']),
      updated_at: parse_timestamp(row['updated_at'])
    )
    @stats[:insurances] += 1
  rescue ActiveRecord::RecordInvalid => e
    warn "    Skipping insurance #{row['id']}: #{e.message}"
  end

  def create_assessment(row)
    # Find associated subject's onboarding session
    subject_id = row['subject_id']
    child = Child.find_by(id: subject_id)
    session_id = child&.onboarding_session_id

    Assessment.create!(
      id: row['id'],
      onboarding_session_id: session_id,
      responses: parse_json(row['question_answers']),
      consent_given: row['completed_at'].present?,
      created_at: parse_timestamp(row['created_at']),
      updated_at: parse_timestamp(row['updated_at'])
    )
    @stats[:assessments] += 1
  rescue ActiveRecord::RecordInvalid => e
    warn "    Skipping assessment #{row['id']}: #{e.message}"
  end

  # Helper methods

  def each_csv_row(filename, &block)
    path = CSV_PATH.join(filename)
    return unless File.exist?(path)

    CSV.foreach(path, headers: true, &block)
  end

  def parse_array(str)
    return [] if str.blank?
    JSON.parse(str.gsub(/["\"]/, '"'))
  rescue JSON::ParserError
    []
  end

  def parse_json(str)
    return {} if str.blank?
    JSON.parse(str)
  rescue JSON::ParserError
    {}
  end

  def parse_timestamp(str)
    return Time.current if str.blank?
    Time.parse(str)
  rescue ArgumentError
    Time.current
  end

  def determine_session_status(labels)
    labels.each do |label|
      return REFERRAL_STATUS_MAP[label] if REFERRAL_STATUS_MAP.key?(label)
    end
    :started
  end

  def sanitize_s3_url(url)
    return nil if url.blank?
    # Convert s3:// URLs to just the key for storage
    url.gsub(%r{^s3://[^/]+/}, '')
  end

  def print_stats
    puts "\nSeed complete!"
    puts "  Parents:    #{@stats[:parents]}"
    puts "  Children:   #{@stats[:children]}"
    puts "  Kinships:   #{@stats[:kinships]}"
    puts "  Sessions:   #{@stats[:sessions]}"
    puts "  Insurances: #{@stats[:insurances]}"
    puts "  Assessments: #{@stats[:assessments]}"
  end
end

# Run if called directly
if __FILE__ == $PROGRAM_NAME || defined?(Rails) && Rails.env.development?
  TestDataSeeder.new.seed_all
end
