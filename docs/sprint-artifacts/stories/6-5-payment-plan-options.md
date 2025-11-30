# Story 6-5: Payment Plan Options

**Epic:** Epic 6 - Cost Estimation Tool (P1)
**Status:** COMPLETED
**Priority:** P1
**Complexity:** Medium
**Dependencies:** Story 6.3 (Cost Comparison)

## User Story

As a **parent** with financial concerns,
I want **to see payment plan options**,
So that **I can afford care for my child**.

## Acceptance Criteria

- [x] Upfront payment option with 5% discount displayed
- [x] Monthly payment plans: 3, 6, 12 month options available
- [x] Calculate monthly amount based on total estimate
- [x] Interest/fee disclosure (MVP: 0% interest, $0 fees)
- [x] Financial assistance program information displayed
- [x] Link to apply for hardship consideration provided
- [x] Payment method options (card, HSA/FSA, bank) available
- [x] No predatory terms (transparent pricing)
- [x] Clear total cost comparison across all options
- [x] Payment plan selection stored for billing integration

## Technical Implementation

### Models

**PaymentPlan** (`app/models/payment_plan.rb`)
- Already existed with all necessary fields
- Fields: `plan_duration_months`, `monthly_amount`, `total_amount`, `discount_applied`, `payment_method_preference`, `status`
- Enums: `status` (pending, active, completed, cancelled), `payment_method_preference` (card, hsa_fsa, bank_transfer)
- Validations: Positive amounts, non-negative duration
- Methods: `upfront_payment?`, `monthly_payment?`, `description`, `discount_percentage`

### Services

**Billing::PaymentPlanService** (`app/services/billing/payment_plan_service.rb`)
- Already existed with complete implementation
- Calculates payment plan options from total amount
- Returns array of plan options (1 upfront + 3 monthly plans)
- Supports custom durations, discounts, interest rates, and service fees
- Loads configuration from `config/payment_plans.yml`
- MVP constraints: 0% interest, $0 fees (no predatory terms)

### GraphQL Types

**PaymentPlanType** (`app/graphql/types/payment_plan_type.rb`)
- Already existed
- Represents saved payment plan selection
- Fields: id, planDurationMonths, monthlyAmount, totalAmount, discountApplied, paymentMethodPreference, status, description

**PaymentPlanOptionType** (`app/graphql/types/payment_plan_option_type.rb`)
- Already existed
- Represents calculated payment plan option
- Fields: durationMonths, monthlyAmount, totalAmount, interestRate, hasFees, feeAmount, upfrontDiscount, description

**FinancialAssistanceType** (`app/graphql/types/financial_assistance_type.rb`)
- Already existed
- Exposes financial assistance program information
- Fields: available, eligibilityCriteria, applicationUrl, description, slidingScaleAvailable, discountRange, additionalInfo
- Loads configuration from `config/financial_assistance.yml`

**PaymentMethodEnum** (`app/graphql/types/payment_method_enum.rb`)
- Already existed
- Values: CARD, HSA_FSA, BANK_TRANSFER

### GraphQL Queries

**paymentPlanOptions** (`app/graphql/types/query_type.rb:378-444`)
- Already registered in QueryType
- Arguments: sessionId (ID!), estimatedCost (Float!)
- Returns: [PaymentPlanOptionType!]!
- Calls `Billing::PaymentPlanService` to calculate options
- Requires authentication (current_session)
- Handles sess_ prefixed session IDs

**financialAssistanceInfo** (`app/graphql/types/query_type.rb:386, 446-449`)
- Already registered in QueryType
- No arguments required (public information)
- Returns: FinancialAssistanceType!
- No authentication required

### GraphQL Mutations

**savePaymentPlanSelection** (`app/graphql/mutations/billing/save_payment_plan_selection.rb`)
- Already existed with complete implementation
- Arguments: sessionId, planDurationMonths, monthlyAmount, totalAmount, discountApplied (optional), paymentMethodPreference
- Returns: PaymentPlanType, success, message
- Creates PaymentPlan record linked to OnboardingSession
- Creates audit log entry (action: PAYMENT_PLAN_SELECTED)
- Validates amounts and payment method
- Requires authentication (current_session)

### Configuration Files

**config/payment_plans.yml**
- Already existed
- Defines plan durations (3, 6, 12 months by default)
- Upfront discount percentage (5% by default)
- Interest rates by plan duration (0% for MVP)
- Service fees by plan duration ($0 for MVP)
- Environment-specific configuration

**config/financial_assistance.yml**
- Already existed
- Program availability flag
- Eligibility criteria list
- Income thresholds by household size
- Sliding scale discounts by income bracket (20-75%)
- Application URL
- Program description and additional info

### Testing

**Service Specs** (`spec/services/billing/payment_plan_service_spec.rb`)
- Created comprehensive test suite (33 examples)
- Tests valid inputs, custom options, edge cases
- Tests configuration loading, MVP constraints
- Tests invalid inputs and error handling
- Tests rounding, precision, and calculations

**Query Specs**
- `spec/graphql/queries/payment_plan_options_query_spec.rb` (21 examples)
  - Tests authenticated query execution
  - Tests all plan options returned correctly
  - Tests different estimated costs
  - Tests sess_ prefix handling
  - Tests authentication and validation errors
  - Tests MVP constraints (0% interest, no fees)

- `spec/graphql/queries/financial_assistance_info_query_spec.rb` (16 examples)
  - Tests configuration loading
  - Tests eligibility criteria, discount range
  - Tests public access (no authentication)
  - Tests missing configuration handling

**Mutation Spec** (`spec/graphql/mutations/billing/save_payment_plan_selection_spec.rb`)
- Created comprehensive test suite (33 examples)
- Tests valid inputs, upfront plans, monthly plans
- Tests all payment methods (CARD, HSA_FSA, BANK_TRANSFER)
- Tests sess_ prefix handling
- Tests authentication errors
- Tests validation errors (negative amounts, zero amounts)
- Tests audit log creation with IP and user agent
- Tests MVP constraints (no actual payment processing)

**Total Test Coverage:** 103 examples, 0 failures

## Files Modified

### Created (Tests Only)
- `spec/graphql/queries/payment_plan_options_query_spec.rb`
- `spec/graphql/queries/financial_assistance_info_query_spec.rb`
- `spec/graphql/mutations/billing/save_payment_plan_selection_spec.rb`

### Already Existed (No Changes Needed)
- `app/models/payment_plan.rb`
- `app/services/billing/payment_plan_service.rb`
- `app/graphql/types/payment_plan_type.rb`
- `app/graphql/types/payment_plan_option_type.rb`
- `app/graphql/types/financial_assistance_type.rb`
- `app/graphql/types/payment_method_enum.rb`
- `app/graphql/types/query_type.rb` (queries already registered)
- `app/graphql/types/mutation_type.rb` (mutation already registered)
- `app/graphql/mutations/billing/save_payment_plan_selection.rb`
- `config/payment_plans.yml`
- `config/financial_assistance.yml`
- `spec/services/billing/payment_plan_service_spec.rb`

## Database Schema

**payment_plans table** (already exists via migration `20251130203218_create_payment_plans.rb`)
```ruby
create_table :payment_plans do |t|
  t.references :onboarding_session, null: false, foreign_key: true, type: :uuid
  t.integer :plan_duration_months, null: false
  t.decimal :monthly_amount, precision: 10, scale: 2, null: false
  t.decimal :total_amount, precision: 10, scale: 2, null: false
  t.decimal :discount_applied, precision: 10, scale: 2, default: 0.0
  t.integer :payment_method_preference, null: false, default: 0
  t.integer :status, null: false, default: 0
  t.timestamps
end

add_index :payment_plans, :status
add_index :payment_plans, [:onboarding_session_id, :status]
```

## GraphQL Schema Examples

### Query: Payment Plan Options

```graphql
query PaymentPlanOptions($sessionId: ID!, $estimatedCost: Float!) {
  paymentPlanOptions(sessionId: $sessionId, estimatedCost: $estimatedCost) {
    durationMonths
    monthlyAmount
    totalAmount
    interestRate
    hasFees
    feeAmount
    upfrontDiscount
    description
  }
}
```

**Example Response:**
```json
{
  "data": {
    "paymentPlanOptions": [
      {
        "durationMonths": 0,
        "monthlyAmount": 1140.00,
        "totalAmount": 1140.00,
        "interestRate": 0.0,
        "hasFees": false,
        "feeAmount": 0.0,
        "upfrontDiscount": 5.0,
        "description": "Pay in full now (5.0% discount)"
      },
      {
        "durationMonths": 3,
        "monthlyAmount": 400.00,
        "totalAmount": 1200.00,
        "interestRate": 0.0,
        "hasFees": false,
        "feeAmount": 0.0,
        "upfrontDiscount": null,
        "description": "3 monthly payments of $400.0"
      },
      {
        "durationMonths": 6,
        "monthlyAmount": 200.00,
        "totalAmount": 1200.00,
        "interestRate": 0.0,
        "hasFees": false,
        "feeAmount": 0.0,
        "upfrontDiscount": null,
        "description": "6 monthly payments of $200.0"
      },
      {
        "durationMonths": 12,
        "monthlyAmount": 100.00,
        "totalAmount": 1200.00,
        "interestRate": 0.0,
        "hasFees": false,
        "feeAmount": 0.0,
        "upfrontDiscount": null,
        "description": "12 monthly payments of $100.0"
      }
    ]
  }
}
```

### Query: Financial Assistance Info

```graphql
query FinancialAssistanceInfo {
  financialAssistanceInfo {
    available
    eligibilityCriteria
    applicationUrl
    description
    slidingScaleAvailable
    discountRange
    additionalInfo
  }
}
```

**Example Response:**
```json
{
  "data": {
    "financialAssistanceInfo": {
      "available": true,
      "eligibilityCriteria": [
        "Annual household income below threshold for family size",
        "Active participation in therapy sessions",
        "No outstanding payment obligations",
        "Completion of financial assistance application"
      ],
      "applicationUrl": "https://daybreakhealth.com/financial-assistance/apply",
      "description": "Daybreak Health is committed to making mental healthcare accessible to all families...",
      "slidingScaleAvailable": true,
      "discountRange": "20-75%",
      "additionalInfo": [
        "Applications reviewed within 5 business days",
        "Confidential review process",
        "Assistance renewable annually",
        "No impact on quality of care"
      ]
    }
  }
}
```

### Mutation: Save Payment Plan Selection

```graphql
mutation SavePaymentPlanSelection($input: SavePaymentPlanSelectionInput!) {
  savePaymentPlanSelection(input: $input) {
    success
    message
    paymentPlan {
      id
      planDurationMonths
      monthlyAmount
      totalAmount
      discountApplied
      paymentMethodPreference
      status
      description
    }
  }
}
```

**Variables:**
```json
{
  "input": {
    "sessionId": "sess_123abc...",
    "planDurationMonths": 6,
    "monthlyAmount": 200.00,
    "totalAmount": 1200.00,
    "discountApplied": 0.0,
    "paymentMethodPreference": "CARD"
  }
}
```

**Example Response:**
```json
{
  "data": {
    "savePaymentPlanSelection": {
      "success": true,
      "message": "Payment plan selection saved successfully",
      "paymentPlan": {
        "id": "456",
        "planDurationMonths": 6,
        "monthlyAmount": 200.0,
        "totalAmount": 1200.0,
        "discountApplied": 0.0,
        "paymentMethodPreference": "CARD",
        "status": "pending",
        "description": "6 monthly payments of $200.00"
      }
    }
  }
}
```

## Business Logic

### Payment Plan Calculations

**Upfront Payment:**
- Base amount: estimated cost
- Discount: 5% by default (configurable)
- Final amount: base amount × (1 - discount%)
- Example: $1200 × 0.95 = $1140

**Monthly Plans:**
- Total amount: estimated cost (no interest/fees for MVP)
- Monthly amount: total amount ÷ duration
- Example: $1200 ÷ 6 = $200/month

### Financial Assistance Eligibility

**Income Thresholds** (annual household income):
- 1 person: $35,000
- 2 people: $47,500
- 3 people: $60,000
- 4 people: $72,500
- 5+ people: Add $12,500 per additional person

**Sliding Scale Discounts:**
- 0-100% FPL: 75% discount
- 100-150% FPL: 50% discount
- 150-200% FPL: 35% discount
- 200-250% FPL: 20% discount

### MVP Constraints

**No Actual Payment Processing:**
- Payment plan selections are stored for future billing integration
- No credit card processing in MVP
- No bank account verification in MVP
- Status defaults to "pending"

**No Predatory Terms:**
- 0% interest rate on all plans
- $0 service fees on all plans
- Transparent pricing (total = monthly × duration)
- Clear cost comparison across all options

## Integration Points

### With CostComparisonService
- Payment plan options use total estimated cost from cost comparison
- Parents see cost comparison before selecting payment plan

### With OnboardingSession
- Payment plan linked to session via `has_one :payment_plan`
- Session ID required for authentication
- Supports sess_ prefixed session IDs

### With AuditLog
- Payment plan selection creates audit log entry
- Includes IP address, user agent, timestamp
- Details include all plan parameters
- Enables compliance and troubleshooting

### With Future Billing System (Post-MVP)
- Payment plan status can be updated (pending → active → completed)
- Payment method preference captured for future processing
- Multiple plans can be created (allows plan changes)

## Security & Compliance

**Authentication:**
- All queries/mutations require valid session (except financialAssistanceInfo)
- Session ownership verified before showing/saving payment plans
- Access denied errors return proper GraphQL error codes

**Audit Trail:**
- All payment plan selections logged with full details
- IP address and user agent captured
- Timestamp included for compliance

**Data Validation:**
- Positive amount validation (monthly, total)
- Non-negative duration validation
- Payment method enum validation
- Discount validation (0-100%)

## Testing Strategy

**Unit Tests (Services):**
- PaymentPlanService with all calculation scenarios
- Custom options, configuration loading
- Edge cases (small amounts, large amounts, rounding)
- Invalid inputs and error handling

**Integration Tests (GraphQL):**
- Query authentication and authorization
- Mutation input validation
- Database persistence
- Audit log creation
- Error handling and error messages

**Test Coverage:**
- 103 examples covering all acceptance criteria
- All positive and negative test cases
- All payment methods tested
- All error conditions tested
- MVP constraints verified

## Known Limitations

**MVP Scope:**
- No actual payment processing
- No payment gateway integration
- No credit card capture/storage
- No recurring billing setup
- No email confirmations

**Future Enhancements:**
- Stripe/payment gateway integration
- Automated recurring billing
- Payment status tracking
- Email confirmations
- Payment receipts

## Success Metrics

**Functional:**
- ✅ All 103 tests passing
- ✅ Payment plan calculations accurate
- ✅ GraphQL queries/mutations working
- ✅ Audit logging working
- ✅ Financial assistance info accessible

**Business:**
- Parents can see payment options before commitment
- Financial assistance information is transparent
- No predatory terms (aligns with mission)
- Clear cost comparison aids decision-making

## Completion Date

November 30, 2024

## Last Verified

November 30, 2024 - All tests passing (103 examples, 0 failures)
