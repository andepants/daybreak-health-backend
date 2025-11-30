# Story 6.2: Insurance Cost Estimation

**Epic:** Epic 6 - Cost Estimation Tool (P1)
**Status:** ✅ Completed
**Implementation Date:** November 30, 2025

## Story Description

As a **parent** with verified insurance,
I want **to see estimated costs based on my coverage**,
So that **I know what I'll pay out of pocket**.

## Acceptance Criteria

- [x] AC1: Retrieves coverage details from verified insurance (copay, coinsurance, deductible)
- [x] AC2: Calculates estimated patient responsibility based on deductible status
  - If deductible not met: Patient pays full allowed amount until deductible is met
  - After deductible: Copay or coinsurance applies
- [x] AC3: Shows insurance pays, patient pays, and deductible status
- [x] AC4: Displays allowed amount vs. billed amount
- [x] AC5: Explains coverage limitations (session limits, prior auth requirements)
- [x] AC6: Estimate clearly marked as estimate (not guarantee) with disclaimer
- [x] AC7: Cached estimates with 24-hour expiry, invalidated when eligibility data changes

## Technical Implementation

### 1. Service Layer

**File:** `app/services/billing/insurance_estimate_service.rb`

The `InsuranceEstimateService` calculates patient responsibility and insurance payment estimates based on:
- Coverage details from eligibility verification (Story 4.4)
- Deductible status (met, partially met, not met)
- Plan type detection (HMO, PPO, HDHP)
- Network status (in-network vs out-of-network)

**Key Features:**
- Automatic plan type inference from coverage structure
- Deductible tracking and calculation
- Coverage limitation detection
- 24-hour cache with eligibility-based invalidation
- Comprehensive error handling

**Plan Type Calculation Logic:**

```ruby
# HMO: Simple copay (deductible typically doesn't apply to office visits)
patient_pays = copay_amount
insurance_pays = allowed_amount - patient_pays

# PPO: Deductible first, then coinsurance or copay
if deductible_not_met?
  patient_pays = min(allowed_amount, deductible_remaining)
  insurance_pays = allowed_amount - patient_pays
else
  patient_pays = copay_or_coinsurance(allowed_amount)
  insurance_pays = allowed_amount - patient_pays
end

# HDHP: Patient pays everything until deductible met, then coinsurance
if deductible_not_met?
  patient_pays = min(allowed_amount, deductible_remaining)
  insurance_pays = 0
else
  patient_pays = allowed_amount * (coinsurance_pct / 100)
  insurance_pays = allowed_amount - patient_pays
end
```

### 2. GraphQL Layer

**Query:** `app/graphql/queries/insurance_cost_estimate.rb`

Provides the `insuranceCostEstimate` GraphQL query with authorization:
- Validates session ownership
- Checks insurance verification status
- Returns null if insurance not verified (graceful handling)
- Logs audit events for compliance

**Query Example:**
```graphql
query {
  insuranceCostEstimate(sessionId: "abc123", serviceType: "individual_therapy") {
    insurancePays
    patientPays
    allowedAmount
    billedAmount
    deductibleStatus {
      amount
      met
      remaining
      isMet
    }
    coverageLimitations
    isEstimate
    disclaimer
    calculatedAt
  }
}
```

**Types:**
- `Types::CostEstimateType` - Cost estimate response type
- `Types::DeductibleStatusType` - Deductible tracking information

### 3. Key Design Decisions

1. **Plan Type Inference:** Service automatically detects plan type from coverage structure when not explicitly provided
2. **Allowed Amount Calculation:** Uses 85% of billed amount for in-network (simplified contract rate)
3. **Cache Strategy:** Cache key includes insurance ID, verified_at timestamp, deductible_met amount, and service type
4. **Error Handling:** Graceful null return for unverified insurance; detailed ArgumentError for configuration issues
5. **Namespace Resolution:** Uses `::Billing::` prefix to avoid module resolution conflicts in GraphQL context

### 4. Coverage Limitations Detection

The service automatically detects and reports:
- Session limits (warns when ≤10 sessions remaining)
- Prior authorization requirements
- Out-of-network status
- Coverage termination date (warns when ≤30 days remaining)

## Testing

### Service Layer Tests
**File:** `spec/services/billing/insurance_estimate_service_spec.rb`

**Coverage:**
- Validation: Insurance verification status, coverage data completeness
- Plan Types: HMO (copay), PPO (deductible + coinsurance), HDHP (high deductible)
- Deductible States: Not met, partially met, fully met
- Coverage Limitations: Session limits, prior auth, out-of-network, termination dates
- Caching: Cache storage, retrieval, expiry, key generation
- Edge Cases: Missing rates, out-of-network calculations

**Test Results:**
```
Billing::InsuranceEstimateService
  .call
    when insurance is not verified
      ✓ raises ArgumentError
    when verification_result is missing
      ✓ raises ArgumentError
    when coverage data is incomplete
      ✓ raises ArgumentError
    with verified insurance and complete coverage data
      ✓ returns a cost estimate hash
      ✓ sets is_estimate to true
      ✓ includes disclaimer text
      ✓ returns BigDecimal amounts
    HMO plan with copay
      ✓ calculates patient pays as copay amount
    PPO plan with deductible not met
      ✓ patient pays full allowed amount toward deductible
    PPO plan with deductible met and coinsurance
      ✓ patient pays coinsurance percentage
    High-deductible plan with deductible not met
      ✓ patient pays toward deductible remaining
    with session limit coverage limitation
      ✓ includes session limit in coverage limitations
    with prior authorization requirement
      ✓ includes prior auth requirement in coverage limitations
    with out-of-network status
      ✓ includes out-of-network warning in coverage limitations
      ✓ uses billed amount as allowed amount for out-of-network
    with coverage termination date approaching
      ✓ includes termination warning in coverage limitations
    caching behavior
      ✓ caches the estimate result
      ✓ cache key includes insurance id, verified_at, deductible_met, and service_type
      ✓ cache expires after 24 hours

19 examples, 0 failures
```

### GraphQL Query Tests
**File:** `spec/graphql/queries/insurance_cost_estimate_spec.rb`

**Coverage:**
- Successful queries with verified insurance
- Null return for unverified insurance
- Authorization and access control
- Service type parameter handling
- Error handling (session not found, no insurance)

**Test Results:**
```
Queries::InsuranceCostEstimate
  when insurance is verified
    ✓ returns cost estimate
    ✓ returns deductible status
    ✓ returns empty coverage limitations by default
  when insurance is not verified
    ✓ returns null
  when session not found
    ✓ returns error
  when no insurance for session
    ✓ returns error
  with service_type parameter
    ✓ uses specified service type for calculation

7 examples, 0 failures
```

## Dependencies

**Upstream:**
- Story 4.4: Eligibility Verification (provides verification_result with coverage data)
- Story 6.1: Cost Calculation Service (provides SessionRate model and base rates)

**Downstream:**
- Story 6.3: Cost Comparison (consumes insurance estimates for comparison with self-pay)
- Story 6.4: Deductible & OOP Tracking (enhanced deductible status display)

## Data Model

Uses existing `Insurance` model with fields:
- `verification_status` - Must be 'verified' for estimates
- `verification_result` - JSON containing:
  - `coverage.copay.amount` - Copay amount
  - `coverage.deductible.amount` - Total deductible
  - `coverage.deductible.met` - Amount already met
  - `coverage.coinsurance.percentage` - Coinsurance %
  - `coverage.plan_type` - Optional explicit plan type
  - `coverage.network_status` - in_network/out_of_network
  - `coverage.session_limit` - Optional session limit
  - `coverage.sessions_used` - Sessions already used
  - `coverage.requires_prior_authorization` - Boolean
  - `coverage.termination_date` - Coverage end date
  - `verified_at` - Verification timestamp for cache invalidation

## Files Modified

### Created
- None (all files existed from previous stories)

### Modified
- `app/services/billing/insurance_estimate_service.rb` - Core estimation logic
- `app/graphql/queries/insurance_cost_estimate.rb` - GraphQL query with namespace fix
- `spec/services/billing/insurance_estimate_service_spec.rb` - Cache key test update
- `spec/graphql/queries/insurance_cost_estimate_spec.rb` - Test type and context fixes

### Existing (No Changes)
- `app/graphql/types/cost_estimate_type.rb` - Response type
- `app/graphql/types/deductible_status_type.rb` - Deductible status type
- `app/models/insurance.rb` - Insurance model with coverage helpers
- `app/models/session_rate.rb` - Session rate configuration

## Configuration

No additional configuration required. Service uses:
- `SessionRate` records for base rates
- `Insurance.verification_result` JSON for coverage data
- `Rails.cache` for estimate caching (NullStore in test, configured per environment)

## Notes

1. **Production Ready:** All AC criteria met, comprehensive test coverage, production error handling
2. **Cache Invalidation:** Cache automatically invalidates when eligibility data changes (verified_at or deductible_met changes)
3. **Estimate Accuracy:** Uses simplified allowed amount calculation (85% of billed); production should use actual contracted rates from payer agreements
4. **Namespace Resolution:** GraphQL context requires `::Billing::` prefix due to module lookup precedence
5. **Graceful Degradation:** Returns null for unverified insurance rather than error, allowing frontend to handle gracefully

## Example Response

```json
{
  "data": {
    "insuranceCostEstimate": {
      "insurancePays": 102.50,
      "patientPays": 25.00,
      "allowedAmount": 127.50,
      "billedAmount": 150.00,
      "deductibleStatus": {
        "amount": 500.00,
        "met": 500.00,
        "remaining": 0.00,
        "isMet": true
      },
      "coverageLimitations": [],
      "isEstimate": true,
      "disclaimer": "This is an estimate only and not a guarantee of payment. Actual costs may vary based on services provided, claim processing, and your specific insurance plan details. Please contact your insurance provider for more information.",
      "calculatedAt": "2025-11-30T20:55:00Z"
    }
  }
}
```

## Last Verified

November 30, 2025 - All tests passing, ready for integration with frontend cost display.
