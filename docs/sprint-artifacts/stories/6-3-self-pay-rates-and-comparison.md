# Story 6.3: Self-Pay Rates & Comparison

**Epic**: Epic 6 - Cost Estimation Tool (P1)
**Status**: COMPLETED
**Priority**: P1 (Critical Path)
**Estimated Effort**: Medium
**Dependencies**: Story 6.1 (CostCalculationService), Story 6.2 (InsuranceEstimateService)

---

## User Story

**As a** parent considering self-pay,
**I want** to see transparent self-pay pricing and compare to insurance,
**So that** I can make the best financial decision.

---

## Acceptance Criteria

### AC 6.3.1: Self-Pay Rate Display
- [x] Clear self-pay rates per session type displayed
- [x] Rates retrieved from SelfPayRate model with effective date versioning
- [x] Default fallback rate ($75) if no active rate exists

### AC 6.3.2: Comparison Table
- [x] Side-by-side comparison table showing insurance estimate vs. self-pay
- [x] Comparison rows include:
  - Per Session Cost
  - Typical Treatment (8-12 sessions)
  - Out-of-Pocket Before Deductible Met (if applicable)
  - After Deductible Met (if applicable)

### AC 6.3.3: High Deductible Detection
- [x] Automatically highlight when self-pay might be cheaper
- [x] High deductible threshold: $1000 remaining
- [x] Calculate and display savings amount

### AC 6.3.4: Sliding Scale Information
- [x] Display sliding scale availability if configured in SelfPayRate
- [x] Show income-based discount information
- [x] Contact messaging for financial assistance

### AC 6.3.5: Package Pricing Options
- [x] Display package options (4-session, 8-session bundles) from SelfPayRate metadata
- [x] Show per-session cost within packages
- [x] Display total savings for package purchases

### AC 6.3.6: Transparent Pricing Messaging
- [x] "No surprise fees. Price shown is what you pay." message
- [x] What's included list (50-minute session, secure messaging, treatment planning)
- [x] What's not included list (medication management)

### AC 6.3.7: Personalized Recommendations
- [x] Generate recommendation when self-pay is more affordable
- [x] Provide context: "With your high deductible plan, you could save approximately $X"
- [x] Recommend insurance when copay is lower than self-pay

### AC 6.3.8: Easy Switching
- [x] selectSelfPay mutation to choose self-pay option
- [x] switchToInsurance mutation to revert to insurance verification
- [x] Bidirectional switching supported

### AC 6.3.9: Cost Comparison GraphQL Query
- [x] `costComparison(sessionId: ID!)` query implemented
- [x] Returns comprehensive comparison with both estimates
- [x] Handles unauthenticated and unauthorized access
- [x] Gracefully handles missing insurance verification

---

## Technical Implementation

### Models

#### SelfPayRate Model
- **File**: `app/models/self_pay_rate.rb`
- **Features**:
  - Session type enumeration (intake, individual_therapy, family_therapy)
  - Base rate with precision (8,2)
  - Effective date range versioning
  - Sliding scale and package pricing flags
  - JSONB metadata for tiers and package options
  - Scopes: `currently_active`, `effective_on`, `for_session_type`
  - Class method: `get_rate_for(session_type, date)`
  - Instance methods: `sliding_scale_tiers`, `package_options`

### Services

#### Billing::CostComparisonService
- **File**: `app/services/billing/cost_comparison_service.rb`
- **Responsibilities**:
  - Compare insurance estimates with self-pay rates
  - Generate side-by-side comparison table
  - Detect high deductible plans and recommend self-pay
  - Calculate savings when self-pay is more affordable
  - Format currency values consistently
- **Methods**:
  - `call` - Main orchestration method
  - `calculate_insurance_estimate` - Get insurance estimate or nil
  - `calculate_self_pay_estimate` - Get self-pay estimate (always available)
  - `generate_comparison_table` - Create comparison rows
  - `generate_recommendation` - Personalized financial recommendation
  - `calculate_savings_if_self_pay` - Savings calculation
  - `should_highlight_self_pay?` - Boolean decision logic

### GraphQL Schema

#### Types
- **CostComparisonType** (`app/graphql/types/cost_comparison_type.rb`)
  - insurance_estimate: InsuranceEstimateType (nullable)
  - self_pay_estimate: SelfPayEstimateType (required)
  - comparison_table: [ComparisonRowType] (required)
  - recommendation: String (nullable)
  - savings_if_self_pay: Float (nullable)
  - highlight_self_pay: Boolean (required)

- **SelfPayEstimateType** (`app/graphql/types/self_pay_estimate_type.rb`)
  - base_rate: String (e.g., "$75.00 per session")
  - total_for_typical_treatment: String
  - sliding_scale_info: String (nullable)
  - package_options: [PackageOptionType]
  - transparent_pricing_message: String
  - what_is_included: [String]
  - what_is_not_included: [String]

- **PackageOptionType** (`app/graphql/types/package_option_type.rb`)
  - sessions: Int
  - total_price: String
  - per_session_cost: String
  - savings: String
  - description: String

- **ComparisonRowType** (`app/graphql/types/comparison_row_type.rb`)
  - label: String
  - insurance_value: String (nullable)
  - self_pay_value: String
  - highlight_self_pay: Boolean

#### Queries
- **costComparison** (`app/graphql/queries/cost_comparison.rb`)
  - Arguments: `sessionId: ID!`
  - Returns: `CostComparisonType!`
  - Authorization: Requires matching current_session
  - Error handling: NOT_FOUND, UNAUTHENTICATED

#### Mutations
- **selectSelfPay** (`app/graphql/mutations/insurance/select_self_pay.rb`)
  - Sets insurance verification_status to :self_pay
  - Records verified_at timestamp
  - Returns session with success flag

- **switchToInsurance** (`app/graphql/mutations/insurance/switch_to_insurance.rb`)
  - Reverts from :self_pay to :pending or :unverified
  - Clears verified_at timestamp
  - Returns session with success flag

### Database Schema

#### self_pay_rates table
```ruby
create_table "self_pay_rates", id: :uuid do |t|
  t.string :session_type, null: false
  t.decimal :base_rate, precision: 8, scale: 2, null: false
  t.date :effective_date, null: false
  t.date :end_date
  t.boolean :sliding_scale_available, default: false, null: false
  t.boolean :package_pricing_available, default: false, null: false
  t.text :description
  t.jsonb :metadata, default: {}, null: false
  t.timestamps
end

add_index :self_pay_rates, :session_type
add_index :self_pay_rates, :effective_date
add_index :self_pay_rates, [:session_type, :effective_date]
```

---

## Testing

### Model Tests (`spec/models/self_pay_rate_spec.rb`)
- ✅ Validations (presence, numericality, date range)
- ✅ Scopes (currently_active, effective_on, for_session_type)
- ✅ Class method: get_rate_for
- ✅ Instance methods: sliding_scale_tiers, package_options
- ✅ Date range validation
- ✅ Historical rate lookup

**Coverage**: 19 examples, 0 failures

### Service Tests (`spec/services/billing/cost_comparison_service_spec.rb`)
- ✅ Unverified insurance returns nil estimate
- ✅ Self-pay estimate always available
- ✅ High deductible detection and highlighting
- ✅ Savings calculation
- ✅ Personalized recommendations
- ✅ Low copay insurance comparison
- ✅ Comparison table generation
- ✅ Transparent pricing messages
- ✅ Sliding scale and package options
- ✅ Default rate fallback

**Coverage**: 18 examples, 0 failures

### GraphQL Query Tests (`spec/graphql/queries/cost_comparison_spec.rb`)
- ✅ Returns self-pay estimate when insurance not verified
- ✅ Includes transparent pricing message
- ✅ Includes what is included/not included lists
- ✅ Includes package options with correct pricing
- ✅ Generates comparison table
- ✅ Returns both estimates for verified insurance
- ✅ Highlights self-pay for high deductible plans
- ✅ Calculates savings correctly
- ✅ Provides personalized recommendations
- ✅ Does not highlight when insurance is better
- ✅ Authorization: requires authentication
- ✅ Authorization: requires matching session
- ✅ Error handling: non-existent session

**Coverage**: 15 examples, 0 failures

**Total Coverage**: 52 examples, 0 failures

---

## API Examples

### Cost Comparison Query
```graphql
query CostComparison($sessionId: ID!) {
  costComparison(sessionId: $sessionId) {
    insuranceEstimate {
      perSessionCost
      totalEstimatedCost
      explanation
    }
    selfPayEstimate {
      baseRate
      totalForTypicalTreatment
      slidingScaleInfo
      transparentPricingMessage
      whatIsIncluded
      packageOptions {
        sessions
        totalPrice
        perSessionCost
        savings
        description
      }
    }
    comparisonTable {
      label
      insuranceValue
      selfPayValue
      highlightSelfPay
    }
    recommendation
    savingsIfSelfPay
    highlightSelfPay
  }
}
```

### Select Self-Pay Mutation
```graphql
mutation SelectSelfPay($sessionId: ID!) {
  selectSelfPay(sessionId: $sessionId) {
    session {
      id
      insurance {
        verificationStatus
      }
    }
    success
  }
}
```

### Switch to Insurance Mutation
```graphql
mutation SwitchToInsurance($sessionId: ID!) {
  switchToInsurance(sessionId: $sessionId) {
    session {
      id
      insurance {
        verificationStatus
      }
    }
    success
  }
}
```

---

## Example Response

```json
{
  "data": {
    "costComparison": {
      "insuranceEstimate": {
        "perSessionCost": "$127.50",
        "totalEstimatedCost": "$2000.00",
        "explanation": "Based on your verified coverage details. You have a high-deductible plan with $2000.00 remaining to meet."
      },
      "selfPayEstimate": {
        "baseRate": "$75.00 per session",
        "totalForTypicalTreatment": "$600.00",
        "slidingScaleInfo": "Sliding scale available based on household income. Discounts from 10-50% may apply. Contact us to discuss financial assistance options.",
        "transparentPricingMessage": "No surprise fees. Price shown is what you pay.",
        "whatIsIncluded": [
          "50-minute session",
          "Secure messaging between sessions",
          "Treatment planning and notes"
        ],
        "packageOptions": [
          {
            "sessions": 4,
            "totalPrice": "$280.00",
            "perSessionCost": "$70.00",
            "savings": "$20.00",
            "description": "4-session bundle"
          },
          {
            "sessions": 8,
            "totalPrice": "$560.00",
            "perSessionCost": "$70.00",
            "savings": "$40.00",
            "description": "8-session bundle"
          }
        ]
      },
      "comparisonTable": [
        {
          "label": "Per Session Cost",
          "insuranceValue": "$127.50",
          "selfPayValue": "$75.00",
          "highlightSelfPay": true
        },
        {
          "label": "Typical Treatment (8-12 sessions)",
          "insuranceValue": "$2000.00",
          "selfPayValue": "$600.00",
          "highlightSelfPay": true
        }
      ],
      "recommendation": "Self-pay may be more affordable. With your high deductible plan, you could save approximately $1400.00 by choosing self-pay for the first 8 sessions.",
      "savingsIfSelfPay": 1400.0,
      "highlightSelfPay": true
    }
  }
}
```

---

## Key Design Decisions

1. **Rate Versioning**: SelfPayRate uses effective_date and end_date for historical rate tracking, ensuring accurate cost display for past dates

2. **Default Fallback**: $75 default rate ensures self-pay option is always available even without configured rates

3. **High Deductible Threshold**: $1000 remaining deductible triggers self-pay recommendation logic

4. **Metadata Flexibility**: JSONB metadata allows flexible configuration of sliding scale tiers and package options without schema changes

5. **Boolean Safety**: All comparison table `highlight_self_pay` fields explicitly return boolean false instead of nil to prevent GraphQL non-nullable field errors

6. **Bidirectional Switching**: Parents can freely switch between insurance and self-pay options without data loss

7. **Transparent Messaging**: Explicit "no surprise fees" messaging and detailed inclusion lists build trust

---

## Integration Points

- **Story 6.1**: Uses SessionRate model for provider billed amounts in comparison
- **Story 6.2**: Calls InsuranceEstimateService for insurance cost estimates
- **Story 6.4**: Deductible status feeds into high deductible detection
- **Story 6.5**: Package pricing complements payment plan options

---

## Future Enhancements

1. Income-based sliding scale calculation with household income input
2. Real-time package purchase with payment processing
3. Financial assistance application workflow
4. Seasonal promotional pricing in metadata
5. Per-therapist custom self-pay rates
6. Self-pay subscription models (monthly therapy membership)

---

## Story Completion Checklist

- [x] SelfPayRate model with effective date versioning
- [x] Cost comparison service with recommendation logic
- [x] GraphQL types: CostComparisonType, SelfPayEstimateType, PackageOptionType, ComparisonRowType
- [x] GraphQL query: costComparison
- [x] GraphQL mutations: selectSelfPay, switchToInsurance
- [x] Sliding scale information display
- [x] Package pricing options
- [x] High deductible detection and highlighting
- [x] Savings calculation
- [x] Personalized recommendations
- [x] Transparent pricing messaging
- [x] Comprehensive RSpec tests (52 examples, 0 failures)
- [x] Story documentation

---

**Story Sign-off**:
- Implementation: Complete
- Tests: Passing (52/52)
- Documentation: Complete
- Code Review: Ready
- Status: READY FOR MERGE
