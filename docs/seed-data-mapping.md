# Seed Data Mapping: CSV Test Cases → Rails Schema

This document maps the production CSV test data to the planned Rails onboarding schema.

## Data Flow Overview

```
CSV Files                          Rails Models
─────────────────────────────────────────────────────────────
referrals.csv                  →   OnboardingSession
patients_and_guardians.csv     →   Parent (where system_labels includes "guardian")
patients_and_guardians.csv     →   Child (where system_labels includes "dependent"/"student")
kinships.csv                   →   Links Parent ↔ Child
insurance_coverages.csv        →   Insurance
questionnaires.csv             →   Assessment
```

## Field Mappings

### OnboardingSession ← referrals.csv

| Rails Field | CSV Field | Transform |
|-------------|-----------|-----------|
| `id` | `id` | UUID direct |
| `status` | `system_labels` | Parse array: "referred"→started, "onboarding_completed"→submitted |
| `progress` | `data` | JSON direct |
| `expires_at` | - | Generate (created_at + 24h) |
| `referral_source` | `organization_id` | Lookup org name |
| `created_at` | `created_at` | Direct |

**Status Mapping:**
```ruby
LABEL_TO_STATUS = {
  "referred" => :started,
  "ready_for_scheduling" => :in_progress,
  "onboarding_completed" => :assessment_complete,
  "request_rejected" => :abandoned
}
```

### Parent ← patients_and_guardians_anonymized.csv

Filter: `system_labels` contains `"guardian"`

| Rails Field | CSV Field | Transform |
|-------------|-----------|-----------|
| `id` | `id` | UUID direct |
| `email` | `email` | Direct (already anonymized) |
| `phone` | `phone` | Direct |
| `first_name` | `first_name` | Direct |
| `last_name` | `last_name` | Direct |
| `relationship` | - | Default: "parent" |
| `is_guardian` | - | Default: true |

### Child ← patients_and_guardians_anonymized.csv

Filter: `system_labels` contains `"dependent"` OR `"student"`

| Rails Field | CSV Field | Transform |
|-------------|-----------|-----------|
| `id` | `id` | UUID direct |
| `first_name` | `first_name` | Direct |
| `last_name` | `last_name` | Direct |
| `date_of_birth` | `birthdate` | Date format |
| `gender` | `legal_gender` | Map: 1→male, 2→female |
| `school_name` | - | From org membership lookup |
| `grade` | - | Not available |

### Parent-Child Link ← kinships.csv

| Rails Relationship | CSV Fields | Notes |
|--------------------|------------|-------|
| `child.parent_id` | `user_0_id` → `user_1_id` | kind=1 is guardian relationship |

**Kind Values:**
- `1` = Guardian/Parent relationship

### Insurance ← insurance_coverages.csv

| Rails Field | CSV Field | Transform |
|-------------|-----------|-----------|
| `id` | `id` | UUID direct |
| `payer_name` | `insurance_company_name` | Direct |
| `member_id` | `member_id` | Direct |
| `group_number` | `group_id` | Direct |
| `card_image_front` | `front_card_url` | S3 key |
| `card_image_back` | `back_card_url` | S3 key |
| `verification_status` | `eligibility` | Map: 0→pending, 4→verified |

**Eligibility Mapping:**
```ruby
ELIGIBILITY_TO_STATUS = {
  0 => :pending,
  1 => :in_progress,
  4 => :verified
}
```

**Kind Values:**
- `0` = non_insurance (self-pay)
- `2` = insurance

### Assessment ← questionnaires.csv

| Rails Field | CSV Field | Transform |
|-------------|-----------|-----------|
| `id` | `id` | UUID direct |
| `responses` | `question_answers` | JSON direct |
| `summary` | - | Not available |
| `risk_flags` | - | Parse from question_answers |
| `consent_given` | - | Default: true if completed |

**Type Values:**
- `3` = PHQ-style assessment
- `4` = Intake questionnaire

## Sample Seed Script

```ruby
# db/seeds/test_data.rb
require 'csv'

class TestDataSeeder
  CSV_PATH = Rails.root.join('docs', 'test-cases')

  def seed_all
    ActiveRecord::Base.transaction do
      seed_parents_and_children
      seed_kinships
      seed_onboarding_sessions
      seed_insurances
      seed_assessments
    end
  end

  private

  def seed_parents_and_children
    CSV.foreach(CSV_PATH.join('patients_and_guardians_anonymized.csv'), headers: true) do |row|
      labels = parse_array(row['system_labels'])

      if labels.include?('guardian')
        Parent.create!(
          id: row['id'],
          email: row['email'],
          phone: row['phone'],
          first_name: row['first_name'],
          last_name: row['last_name'],
          relationship: 'parent',
          is_guardian: true
        )
      elsif labels.include?('dependent') || labels.include?('student')
        Child.create!(
          id: row['id'],
          first_name: row['first_name'],
          last_name: row['last_name'],
          date_of_birth: row['birthdate'],
          gender: map_gender(row['legal_gender'])
        )
      end
    end
  end

  def seed_kinships
    CSV.foreach(CSV_PATH.join('kinships.csv'), headers: true) do |row|
      next unless row['kind'] == '1'  # Guardian relationship

      child = Child.find_by(id: row['user_1_id'])
      parent = Parent.find_by(id: row['user_0_id'])

      if child && parent
        child.update!(parent_id: parent.id)
      end
    end
  end

  def seed_insurances
    CSV.foreach(CSV_PATH.join('insurance_coverages.csv'), headers: true) do |row|
      next if row['kind'] == '0'  # Skip non-insurance

      Insurance.create!(
        id: row['id'],
        user_id: row['user_id'],
        payer_name: row['insurance_company_name'],
        member_id: row['member_id'],
        group_number: row['group_id'],
        card_image_front: row['front_card_url'],
        card_image_back: row['back_card_url'],
        verification_status: map_eligibility(row['eligibility'])
      )
    end
  end

  def seed_assessments
    CSV.foreach(CSV_PATH.join('questionnaires.csv'), headers: true) do |row|
      Assessment.create!(
        id: row['id'],
        subject_id: row['subject_id'],
        responses: JSON.parse(row['question_answers'] || '{}'),
        consent_given: row['completed_at'].present?
      )
    end
  end

  def parse_array(str)
    return [] if str.blank?
    JSON.parse(str.gsub(/"/, '"').gsub(/"/, '"'))
  rescue
    []
  end

  def map_gender(code)
    { '1' => 'male', '2' => 'female' }[code]
  end

  def map_eligibility(code)
    { '0' => :pending, '1' => :in_progress, '4' => :verified }[code] || :pending
  end
end
```

## Data Statistics

| CSV File | Total Rows | Usable for Seed |
|----------|------------|-----------------|
| patients_and_guardians | ~200 | ~100 guardians, ~100 children |
| kinships | ~100 | ~100 relationships |
| insurance_coverages | ~50 | ~40 insurance records |
| questionnaires | ~50 | ~50 assessments |
| referrals | ~50 | ~50 onboarding sessions |

## Usage

```bash
# Load test data in development
rails db:seed:test_data

# Or in rails console
TestDataSeeder.new.seed_all
```

## Notes

1. **Anonymized Data**: Email/names are already anonymized in CSVs
2. **S3 URLs**: Card image URLs point to production S3 - will need placeholder images for dev
3. **UUID Preservation**: Keep original UUIDs to maintain referential integrity
4. **Fivetran Fields**: Ignore `_fivetran_*` columns (ETL metadata)
