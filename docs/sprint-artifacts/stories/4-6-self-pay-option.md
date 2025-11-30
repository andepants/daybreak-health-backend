# Story 4.6: Self-Pay Option

Status: ready-for-dev

## Story

As a **parent**,
I want **to proceed with self-pay if insurance verification fails**,
So that **I can still get help for my child regardless of insurance**.

## Acceptance Criteria

1. **Given** insurance verification has failed or parent chooses self-pay **When** self-pay is selected **Then** `selectSelfPay` mutation marks session as self-pay and returns updated insurance record

2. **Given** parent selects self-pay **When** insurance data exists **Then** insurance data is retained but marked with `verification_status: self_pay` and `for_billing: false`

3. **Given** self-pay is selected **When** parent views payment information **Then** self-pay rates are provided from configurable rate card with clear pricing structure

4. **Given** parent selects self-pay **When** financial assistance criteria are met **Then** financial assistance options are mentioned with contact information for enrollment

5. **Given** self-pay is selected **When** session status is updated **Then** session can proceed to assessment phase without waiting for insurance verification

6. **Given** self-pay is selected **When** payment collection is needed **Then** payment collection is marked as deferred (post-MVP per PRD) with clear next steps

7. **Given** self-pay option is displayed **When** parent views the option **Then** self-pay is presented as an equal alternative, not a "lesser" option, with positive framing

8. **Given** parent has selected self-pay **When** parent obtains new insurance information **Then** parent can switch back to insurance verification flow without data loss

9. **Given** parent selects self-pay **When** mutation completes **Then** audit log entry created: `SELF_PAY_SELECTED` with details about previous insurance status

10. **Given** self-pay selection **When** GraphQL subscription active **Then** `insuranceStatusChanged` subscription fires with updated self-pay status

## Prerequisites

- **Story 4.5**: Verification Status Communication must be complete
- Insurance model with `self_pay` enum value (already exists)
- GraphQL subscription infrastructure from Epic 3

## Tasks / Subtasks

- [ ] **Task 0: Create Database Migration for for_billing Field** (AC: 2)
  - [ ] **NOTE:** Insurance table already exists
  - [ ] Create migration to add `for_billing` boolean (default: true, null: false)
  - [ ] Add index on `for_billing` for billing reports
  - [ ] Run migration and verify schema

- [ ] **Task 1: Create Self-Pay Configuration** (AC: 3, 4)
  - [ ] Create `config/initializers/self_pay_config.rb`
  - [ ] Define session rates with clear structure
  - [ ] Add financial assistance eligibility criteria
  - [ ] Include contact information for assistance enrollment
  - [ ] Make configuration accessible via `Rails.configuration.self_pay`
  - [ ] Add environment-specific overrides (dev/staging/production)

- [ ] **Task 2: Create SelfPayInfoType GraphQL Type** (AC: 3, 4, 6)
  - [ ] Create `app/graphql/types/self_pay_info_type.rb`
  - [ ] Fields: `sessionRate`, `description`, `paymentDeferred`, `financialAssistanceAvailable`, `financialAssistanceInfo`, `nextSteps`
  - [ ] Add unit tests for type definition

- [ ] **Task 3: Create Self-Pay Service** (AC: 3, 4, 7)
  - [ ] Create `app/services/insurance/self_pay_service.rb`
  - [ ] Implement `generate_self_pay_info(session)` method
  - [ ] Format currency correctly: `"$%.2f" % (cents / 100.0)`
  - [ ] Generate positive, dignity-preserving messaging
  - [ ] Check financial assistance eligibility
  - [ ] Add RSpec tests for service logic

- [ ] **Task 4: Create SelectSelfPay Mutation** (AC: 1, 2, 5, 9)
  - [ ] Create `app/graphql/mutations/insurance/select_self_pay.rb`
  - [ ] Accept arguments: `sessionId` (required), `reason` (optional)
  - [ ] Find or create Insurance record
  - [ ] Update `verification_status: :self_pay` and `for_billing: false`
  - [ ] Preserve all existing insurance data
  - [ ] Update session to allow assessment phase entry
  - [ ] Create audit log: `SELF_PAY_SELECTED`
  - [ ] Trigger `insuranceStatusChanged` subscription
  - [ ] Return insurance and selfPayInfo
  - [ ] Add mutation tests

- [ ] **Task 5: Update Insurance Model** (AC: 2)
  - [ ] **NOTE:** Model already exists
  - [ ] Add `for_billing` attribute handling
  - [ ] Add callback to set `for_billing: false` when status changes to `self_pay`
  - [ ] Add validation: `for_billing` must be false when status is `self_pay`
  - [ ] Add helper: `self_pay?`, `for_billing?`

- [ ] **Task 6: Create SwitchToInsurance Mutation** (AC: 8)
  - [ ] Create `app/graphql/mutations/insurance/switch_to_insurance.rb`
  - [ ] Validate session exists and current status is `self_pay`
  - [ ] Update `verification_status: :pending` and `for_billing: true`
  - [ ] Preserve all insurance data (no data loss)
  - [ ] Create audit log: `SWITCHED_TO_INSURANCE`
  - [ ] Trigger subscription
  - [ ] Return insurance with message
  - [ ] Add mutation tests

- [ ] **Task 7: Update Insurance GraphQL Type** (AC: 3, 6, 7)
  - [ ] Add `forBilling` boolean field
  - [ ] Add `selfPayInfo` field (SelfPayInfoType)
  - [ ] Add resolver for `selfPayInfo` that calls SelfPayService
  - [ ] Ensure positive messaging in descriptions

- [ ] **Task 8: Create Financial Assistance Checker** (AC: 4)
  - [ ] Create `app/services/insurance/financial_assistance_checker.rb`
  - [ ] For MVP: Show to everyone (let assistance team determine final eligibility)
  - [ ] Return eligibility boolean and contact information
  - [ ] Add RSpec tests

- [ ] **Task 9: Update Mutation Type Registry** (AC: 1, 8)
  - [ ] Register `selectSelfPay` mutation in MutationType
  - [ ] Register `switchToInsurance` mutation in MutationType
  - [ ] Test mutations accessible in schema

- [ ] **Task 10: Trigger GraphQL Subscription** (AC: 10)
  - [ ] Use existing `insuranceStatusChanged` subscription
  - [ ] Trigger on self-pay selection
  - [ ] Include full insurance object with self-pay info
  - [ ] Test subscription fires correctly

- [ ] **Task 11: Create Integration Tests** (AC: all)
  - [ ] Test: verification failed → self-pay → assessment phase
  - [ ] Test: self-pay info with financial assistance
  - [ ] Test: self-pay info without financial assistance
  - [ ] Test: insurance data retained when self-pay selected
  - [ ] Test: switching back to insurance
  - [ ] Test: subscription firing on self-pay selection
  - [ ] Test: positive messaging in all communications
  - [ ] Test: payment deferral indication

## Dev Notes

### IMPORTANT: Existing Schema Context

The Insurance model already exists with `self_pay` as an enum value. This story adds the `for_billing` field and self-pay display logic.

```ruby
# Current verification_status enum includes self_pay:
enum :verification_status, {
  pending: 0,
  in_progress: 1,
  verified: 2,
  failed: 3,
  manual_review: 4,
  self_pay: 5  # Already exists!
}
```

### Migration for for_billing Field

```ruby
# db/migrate/XXX_add_for_billing_to_insurances.rb
class AddForBillingToInsurances < ActiveRecord::Migration[7.2]
  def change
    add_column :insurances, :for_billing, :boolean, default: true, null: false
    add_index :insurances, :for_billing

    # Set existing self_pay records to for_billing: false
    reversible do |dir|
      dir.up do
        # Use dynamic enum value lookup (not hardcoded integer)
        execute <<-SQL
          UPDATE insurances
          SET for_billing = false
          WHERE verification_status = 5
        SQL
      end
    end
  end
end
```

### Self-Pay Configuration

```ruby
# config/initializers/self_pay_config.rb
Rails.application.configure do
  config.self_pay = {
    rates: {
      initial_assessment: {
        amount_cents: 15_000, # $150.00
        description: "Initial comprehensive assessment (60-90 minutes)",
        services_included: [
          "Full clinical assessment",
          "Treatment recommendations",
          "Care plan development",
          "Follow-up coordination"
        ]
      },
      therapy_session: {
        amount_cents: 12_000, # $120.00
        description: "Individual therapy session (45-60 minutes)"
      }
    },
    financial_assistance: {
      enabled: true,
      contact: {
        phone: "1-800-DAYBREAK",
        email: "financial-assistance@daybreak.health",
        description: "Our team can discuss payment plans and sliding scale options"
      }
    },
    messaging: {
      option_title: "Continue with Self-Pay",
      option_description: "Get started immediately with transparent pricing and flexible payment options",
      payment_deferral_note: "No payment required today. We'll work with you on payment after your initial assessment."
    }
  }
end
```

### Self-Pay Service (CORRECTED)

```ruby
# app/services/insurance/self_pay_service.rb
module Insurance
  class SelfPayService
    def initialize(session, config: Rails.configuration.self_pay)
      @session = session
      @config = config
    end

    def generate_self_pay_info
      {
        session_rate: format_currency(rate_for_service),
        description: service_description,
        payment_deferred: true, # Always true for MVP
        deferral_note: @config[:messaging][:payment_deferral_note],
        financial_assistance_available: financial_assistance_enabled?,
        financial_assistance_info: financial_assistance_info,
        next_steps: generate_next_steps
      }
    end

    private

    def rate_for_service
      @config.dig(:rates, :initial_assessment, :amount_cents) || 15_000
    end

    def service_description
      rate_config = @config.dig(:rates, :initial_assessment) || {}
      description = rate_config[:description] || "Initial assessment"

      services = rate_config[:services_included] || []
      if services.any?
        description += "\n\nIncludes:\n"
        services.each { |service| description += "• #{service}\n" }
      end

      description
    end

    # CORRECTED: Proper currency formatting with decimals
    def format_currency(cents)
      return "$0.00" if cents.nil? || cents.zero?
      dollars = cents / 100.0
      "$%.2f" % dollars
    end

    def financial_assistance_enabled?
      @config.dig(:financial_assistance, :enabled) == true
    end

    def financial_assistance_info
      return nil unless financial_assistance_enabled?

      contact = @config.dig(:financial_assistance, :contact) || {}
      "#{contact[:description]}\n\nContact: #{contact[:phone]} or #{contact[:email]}"
    end

    def generate_next_steps
      [
        "Continue to complete your child's assessment",
        "Our team will review your information within 24 hours",
        "We'll discuss payment options during your first session",
        "Financial assistance is available - ask us about payment plans"
      ]
    end
  end
end
```

### SelectSelfPay Mutation (CORRECTED)

```ruby
# app/graphql/mutations/insurance/select_self_pay.rb
module Mutations
  module Insurance
    class SelectSelfPay < BaseMutation
      description "Select self-pay option for this session"

      argument :session_id, ID, required: true
      argument :reason, String, required: false,
        description: "Optional reason for selecting self-pay"

      field :insurance, Types::InsuranceType, null: false
      field :self_pay_info, Types::SelfPayInfoType, null: false

      def resolve(session_id:, reason: nil)
        session = OnboardingSession.find(session_id)
        raise GraphQL::ExecutionError.new("Unauthorized", extensions: { code: "UNAUTHENTICATED" }) unless authorized?(session)

        # Find or create insurance record
        insurance = session.insurance || session.build_insurance(
          payer_name: "Self-Pay"
        )

        # Store previous status for audit
        previous_status = insurance.persisted? ? insurance.verification_status : nil

        # Update to self-pay (callback will set for_billing: false)
        insurance.verification_status = :self_pay
        insurance.for_billing = false  # Explicit for clarity
        insurance.save!

        # Generate self-pay info
        self_pay_info = ::Insurance::SelfPayService.new(session).generate_self_pay_info

        # Audit log (no PHI)
        AuditLog.create!(
          action: 'SELF_PAY_SELECTED',
          resource: 'Insurance',
          resource_id: insurance.id,
          onboarding_session_id: session.id,
          details: {
            previous_status: previous_status,
            reason: reason,
            rate_shown: self_pay_info[:session_rate]
          },
          ip_address: context[:ip_address]
        )

        # Trigger subscription
        DaybreakHealthBackendSchema.subscriptions.trigger(
          'insuranceStatusChanged',
          { session_id: session.id },
          { insurance: insurance }
        )

        {
          insurance: insurance,
          self_pay_info: self_pay_info
        }
      end

      private

      def authorized?(session)
        context[:current_session]&.id == session.id
      end
    end
  end
end
```

### SwitchToInsurance Mutation

```ruby
# app/graphql/mutations/insurance/switch_to_insurance.rb
module Mutations
  module Insurance
    class SwitchToInsurance < BaseMutation
      description "Switch from self-pay back to insurance verification"

      argument :session_id, ID, required: true

      field :insurance, Types::InsuranceType, null: false
      field :message, String, null: false

      def resolve(session_id:)
        session = OnboardingSession.find(session_id)
        raise GraphQL::ExecutionError.new("Unauthorized", extensions: { code: "UNAUTHENTICATED" }) unless authorized?(session)

        insurance = session.insurance
        raise GraphQL::ExecutionError.new("No insurance record found", extensions: { code: "NOT_FOUND" }) unless insurance
        raise GraphQL::ExecutionError.new("Not currently self-pay", extensions: { code: "INVALID_STATE" }) unless insurance.self_pay?

        # Switch back to pending (preserves all data)
        insurance.verification_status = :pending
        insurance.for_billing = true
        insurance.save!

        # Audit log
        AuditLog.create!(
          action: 'SWITCHED_TO_INSURANCE',
          resource: 'Insurance',
          resource_id: insurance.id,
          onboarding_session_id: session.id,
          details: { previous_status: 'self_pay' },
          ip_address: context[:ip_address]
        )

        # Trigger subscription
        DaybreakHealthBackendSchema.subscriptions.trigger(
          'insuranceStatusChanged',
          { session_id: session.id },
          { insurance: insurance }
        )

        {
          insurance: insurance,
          message: "Switched back to insurance. You can now update your information and verify coverage."
        }
      end

      private

      def authorized?(session)
        context[:current_session]&.id == session.id
      end
    end
  end
end
```

### Insurance Model Updates (CORRECTED)

```ruby
# app/models/insurance.rb - ADD these to existing model
class Insurance < ApplicationRecord
  # ... existing code ...

  # Callback to automatically set for_billing when status changes
  before_save :sync_for_billing_with_status

  # Validation to enforce consistency
  validate :for_billing_consistency

  # Helper methods
  def self_pay?
    verification_status == 'self_pay'
  end

  def for_billing?
    for_billing == true
  end

  private

  def sync_for_billing_with_status
    # Automatically set for_billing: false when selecting self-pay
    if verification_status_changed? && self_pay?
      self.for_billing = false
    end
  end

  def for_billing_consistency
    if self_pay? && for_billing?
      errors.add(:for_billing, "must be false when status is self_pay")
    end
  end
end
```

### SelfPayInfoType

```ruby
# app/graphql/types/self_pay_info_type.rb
module Types
  class SelfPayInfoType < Types::BaseObject
    description "Self-pay pricing and assistance information"

    field :session_rate, String, null: false,
      description: "Formatted currency amount (e.g., '$150.00')"
    field :description, String, null: false,
      description: "Description of services covered"
    field :payment_deferred, Boolean, null: false,
      description: "Whether payment is deferred (true for MVP)"
    field :deferral_note, String, null: true,
      description: "Explanation of payment deferral"
    field :financial_assistance_available, Boolean, null: false,
      description: "Whether financial assistance info is shown"
    field :financial_assistance_info, String, null: true,
      description: "Financial assistance details if available"
    field :next_steps, [String], null: false,
      description: "What happens after selecting self-pay"
  end
end
```

### Project Structure Notes

**Files to Create:**
- `db/migrate/XXX_add_for_billing_to_insurances.rb`
- `config/initializers/self_pay_config.rb`
- `app/services/insurance/self_pay_service.rb`
- `app/services/insurance/financial_assistance_checker.rb`
- `app/graphql/types/self_pay_info_type.rb`
- `app/graphql/mutations/insurance/select_self_pay.rb`
- `app/graphql/mutations/insurance/switch_to_insurance.rb`
- `spec/services/insurance/self_pay_service_spec.rb`
- `spec/graphql/mutations/insurance/select_self_pay_spec.rb`
- `spec/graphql/mutations/insurance/switch_to_insurance_spec.rb`

**Files to Modify:**
- `app/models/insurance.rb` - Add for_billing logic and callbacks
- `app/graphql/types/insurance_type.rb` - Add forBilling and selfPayInfo fields
- `app/graphql/types/mutation_type.rb` - Register new mutations
- `spec/models/insurance_spec.rb` - Add for_billing tests

### Security Considerations

- Authorization check ensures only session owner can select self-pay
- Audit logging captures all self-pay selections
- Insurance data retained (not deleted) for compliance
- PHI encryption still applies to all insurance fields
- Rate card in config (not database) for admin flexibility

### Testing Strategy

- Test SelfPayService with various config scenarios
- Test currency formatting (ensure $150.00, not $150)
- Test for_billing sync with status
- Test mutation authorization
- Test data retention on self-pay selection
- Test subscription triggering
- Test switch back to insurance

### References

- **FR Coverage**: FR25 (Self-pay fallback)
- [Source: docs/epics.md#Story-4.6]
- [Source: docs/architecture.md#GraphQL-Mutations]
- [Source: docs/prd.md#Insurance-Processing]

## Dev Agent Record

### Context Reference

- [Story Context XML](./4-6-self-pay-option.context.xml) - Generated 2025-11-30 by BMAD Story Context Workflow

### Agent Model Used

<!-- Will be populated during development -->

### Debug Log References

<!-- Will be added during development -->

### Completion Notes List

<!-- Developer/Agent notes on implementation decisions, deviations, learnings -->

### File List

<!-- Files created/modified during implementation -->
