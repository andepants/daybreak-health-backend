# Story 3.4: Progress Indicators

**Status:** ready-for-dev

## Story

As a **parent**,
I want **to see how far along I am in the onboarding process**,
So that **I know how much longer it will take**.

## Requirements Context

**From Epic 3 - Conversational AI Intake (epics.md):**

This story implements FR10 (Progress indicators) from the PRD. Parents need visibility into their onboarding progress to feel in control and understand time commitment.

**Functional Requirements Covered:**
- **FR10:** AI provides progress indicators and estimated time remaining

**Key Architecture Constraints (from architecture.md):**
- Session progress stored in `progress` JSONB field on OnboardingSession
- GraphQL subscriptions for real-time updates via Action Cable
- Progress calculation should be cached in Redis for performance

## Acceptance Criteria

1. **Given** conversation is in progress **When** session progress is queried **Then** progress percentage is calculated from completed vs. required fields

2. **Given** active session **When** progress is queried **Then** current phase is displayed (e.g., "Child Information")

3. **Given** ongoing intake **When** progress is calculated **Then** estimated time remaining is based on average completion times

4. **Given** multi-phase intake **When** viewing progress **Then** completed phases are shown as checkmarks

5. **Given** current phase **When** progress includes preview **Then** next phase preview is available

6. **Given** progress update occurs **When** subscribed to session **Then** progress updates in real-time via subscription

7. **Given** any progress state **When** calculating percentage **Then** progress never goes backward (monotonic)

8. **Given** user completing intake **When** measuring time **Then** time estimate adjusts based on actual progress rate

## Tasks / Subtasks

- [ ] **Task 1: Implement Progress Calculation Service** (AC: 1, 7)
  - [ ] Create `app/services/conversation/progress_service.rb`
  - [ ] Define intake phases: Welcome, Parent Info, Child Info, Concerns, Insurance, Assessment
  - [ ] Implement field tracking for each phase with required/completed counts
  - [ ] Calculate percentage: (completed_required_fields / total_required_fields) * 100
  - [ ] Ensure progress percentage never decreases (monotonic increase validation)
  - [ ] Add RSpec tests for progress calculation edge cases

- [ ] **Task 2: Add Time Estimation with Adaptive Learning** (AC: 3, 8)
  - [ ] Store baseline average phase durations in config
  - [ ] Track actual completion times per phase in `session.progress` JSONB
  - [ ] Calculate estimated time: sum of (remaining phases' avg duration)
  - [ ] Implement adaptive adjustment: update estimates based on user's actual pace
  - [ ] Add `estimatedMinutesRemaining` field to progress calculation
  - [ ] Test time estimation accuracy with sample data

- [ ] **Task 3: Create ProgressType GraphQL Type** (AC: 1, 2, 4, 5)
  - [ ] Create `app/graphql/types/progress_type.rb`
  - [ ] Define fields: `percentage`, `currentPhase`, `completedPhases`, `estimatedMinutesRemaining`
  - [ ] Add `nextPhase` field for preview
  - [ ] Add `progress` field to `OnboardingSessionType`
  - [ ] Implement resolver to call `ProgressService.calculate(session)`
  - [ ] Add GraphQL query tests

- [ ] **Task 4: Implement Real-Time Progress Subscription** (AC: 6)
  - [ ] Create `app/graphql/subscriptions/progress_updated.rb`
  - [ ] Subscribe by `session_id` with authorization check
  - [ ] Trigger subscription on session progress updates
  - [ ] Use Action Cable to broadcast progress changes
  - [ ] Add subscription integration tests

- [ ] **Task 5: Update Session Progress Mutation** (AC: 6)
  - [ ] Modify `Mutations::Sessions::UpdateProgress` to calculate progress after update
  - [ ] Trigger `ProgressUpdated` subscription with new progress data
  - [ ] Ensure transaction integrity (DB update + subscription trigger)
  - [ ] Add mutation tests verifying subscription trigger

- [ ] **Task 6: Configure Phase Definitions** (AC: 2, 4, 5)
  - [ ] Create `config/initializers/onboarding_phases.rb`
  - [ ] Define phase order and required fields per phase
  - [ ] Set baseline duration estimates per phase
  - [ ] Make configuration admin-updatable (preparatory for FR41)

- [ ] **Task 7: Add Redis Caching** (AC: 1, 3)
  - [ ] Cache progress calculations in Redis (1 hour TTL)
  - [ ] Invalidate cache on session progress update
  - [ ] Ensure cache miss falls back to DB calculation
  - [ ] Add cache tests

- [ ] **Task 8: Testing and Validation** (AC: all)
  - [ ] Test progress calculation for all phase transitions
  - [ ] Verify monotonic progress (no backward movement)
  - [ ] Test time estimation adapts to user pace
  - [ ] Integration test: complete full intake flow, verify progress updates
  - [ ] Test subscription broadcasts correctly

## Dev Notes

### Architecture Patterns

**Progress Service:**
```ruby
# app/services/conversation/progress_service.rb
class Conversation::ProgressService
  PHASES = %w[welcome parent_info child_info concerns insurance assessment].freeze

  def calculate(session)
    {
      percentage: calculate_percentage(session),
      current_phase: current_phase(session),
      completed_phases: completed_phases(session),
      next_phase: next_phase(session),
      estimated_minutes_remaining: estimate_remaining_time(session)
    }
  end

  private

  def calculate_percentage(session)
    completed = count_completed_fields(session)
    required = total_required_fields
    [(completed * 100 / required), session.progress['last_percentage'] || 0].max
  end
end
```

**Progress Type:**
```ruby
# app/graphql/types/progress_type.rb
module Types
  class ProgressType < BaseObject
    field :percentage, Integer, null: false
    field :current_phase, String, null: false
    field :completed_phases, [String], null: false
    field :next_phase, String, null: true
    field :estimated_minutes_remaining, Integer, null: false
  end
end
```

### Session Progress JSONB Structure

```ruby
{
  currentStep: "child_info",
  completedSteps: ["welcome", "parent_info"],
  last_percentage: 45,  # For monotonic enforcement
  intake: { /* collected data */ },
  phaseTimings: {
    "parent_info": { started_at: "...", completed_at: "..." }
  }
}
```

### Phase Configuration

```ruby
# config/initializers/onboarding_phases.rb
ONBOARDING_PHASES = {
  welcome: { required_fields: 0, baseline_minutes: 1 },
  parent_info: { required_fields: 6, baseline_minutes: 2 },  # firstName, lastName, email, phone, relationship, isGuardian
  child_info: { required_fields: 4, baseline_minutes: 3 },   # firstName, lastName, dateOfBirth, concerns
  concerns: { required_fields: 1, baseline_minutes: 2 },     # primaryConcerns
  insurance: { required_fields: 3, baseline_minutes: 4 },    # payerName, memberId, groupNumber OR selfPay
  assessment: { required_fields: nil, baseline_minutes: 5 }  # Variable based on branching
}.freeze
```

### Project Structure Notes

**Files to Create:**
- `app/services/conversation/progress_service.rb` - Core progress calculation
- `app/graphql/types/progress_type.rb` - GraphQL type definition
- `app/graphql/subscriptions/progress_updated.rb` - Real-time subscription
- `config/initializers/onboarding_phases.rb` - Phase configuration
- `spec/services/conversation/progress_service_spec.rb` - Service tests
- `spec/graphql/subscriptions/progress_updated_spec.rb` - Subscription tests

**Files to Modify:**
- `app/graphql/types/onboarding_session_type.rb` - Add `progress` field
- `app/graphql/mutations/sessions/update_progress.rb` - Trigger subscription
- `app/models/onboarding_session.rb` - Add progress helper methods

### References

- [Source: docs/epics.md#Story 3.4]
- [Source: docs/architecture.md#Real-Time: GraphQL Subscriptions]
- FR10: Progress indicators - percentage, phase, time remaining, real-time updates

## Dev Agent Record

### Context Reference

- docs/sprint-artifacts/3-4-progress-indicators.context.xml

### Agent Model Used

<!-- To be filled by dev agent -->

### Debug Log References

<!-- To be filled during development -->

### Completion Notes List

<!-- To be filled during development -->

### File List

<!-- To be filled during development - format: NEW/MODIFIED/DELETED: path -->

## Senior Developer Review (AI)

**Reviewer:** Senior Dev (AI)
**Date:** 2025-11-29 (Updated: 2025-11-29)
**Review Type:** Design Review (Pre-Implementation)
**Outcome:** ✅ **APPROVE WITH MINOR RECOMMENDATIONS**

### Summary

Story 3.4 demonstrates excellent structure and strong alignment with architecture principles. All 8 acceptance criteria map correctly to Epic 3 FR10 requirements. The technical approach using `Conversation::ProgressService`, GraphQL subscriptions via Action Cable, and Redis caching follows Rails 7 conventions and project architecture patterns correctly.

This comprehensive review validated **100% acceptance criteria coverage**, **100% architectural alignment**, and **complete task breakdown**. The story identified **zero HIGH severity issues** and is ready for implementation after addressing 3 MEDIUM severity clarifications and 3 LOW severity recommendations.

No implementation files exist yet (status: "drafted"), making this a design/readiness review rather than post-implementation code review.

### Key Findings by Severity

#### MEDIUM Severity Issues (3)

1. **[MED] Missing Model Update Task**
   - **Issue**: "Files to Modify" section lists `app/models/onboarding_session.rb` for progress helper methods, but no explicit task covers this modification
   - **Impact**: Developer may overlook this required change
   - **Evidence**: Story line 187 mentions model modification, but Tasks section (lines 45-101) has no corresponding subtask
   - **Recommendation**: Add subtask to Task 1: "Add progress calculation helper methods to OnboardingSession model"

2. **[MED] UpdateProgress Mutation Existence Unclear**
   - **Issue**: Task 5 (line 77) assumes "Modify `Mutations::Sessions::UpdateProgress`" but mutation existence from Epic 2 Story 2.2 is unverified
   - **Impact**: Developer may need to create (not modify) this mutation, affecting task effort
   - **Evidence**: Epic 2 Story 2.2 covers session progress but mutation implementation path unclear
   - **Recommendation**: Verify mutation exists from Epic 2 or update task to "Create or modify UpdateProgress mutation"

3. **[MED] Scope Creep in Configuration Task**
   - **Issue**: Task 6 (line 86) says "Make configuration admin-updatable (preparatory for FR41)" but FR41 is Epic 7 Story 7.5
   - **Impact**: Risk of overbuilding beyond current story scope, introducing unnecessary complexity
   - **Evidence**: FR41 (admin config UI) mapped to Epic 7 Story 7.5 per epics.md line 146
   - **Recommendation**: Clarify scope: "Externalize configuration to initializer (admin UI deferred to Epic 7 Story 7.5/FR41)"

#### LOW Severity Issues (3)

4. **[LOW] Cache TTL Strategy Not Session-Aligned**
   - **Issue**: Task 7 (line 89) specifies "1 hour TTL" without alignment to session expiration strategy (24 hours per architecture)
   - **Evidence**: Architecture.md shows sessions expire at 24 hours, but cache uses arbitrary 1-hour TTL
   - **Recommendation**: Consider session-scoped cache invalidation or document rationale for 1-hour TTL vs. session lifetime

5. **[LOW] Error Handling Strategy Not Specified**
   - **Issue**: No acceptance criterion or task covers error handling when progress calculation fails
   - **Impact**: Implementation may not handle edge cases gracefully (e.g., corrupted progress JSONB, missing phase data)
   - **Recommendation**: Add to Dev Notes: "ProgressService should return safe defaults (0%, 'unknown' phase) if calculation fails"

6. **[LOW] Subscription Authorization Logic Not Detailed**
   - **Issue**: Task 4 (line 71) mentions "authorization check" but doesn't specify validation logic
   - **Evidence**: Architecture.md lines 710-719 shows authorization pattern but story doesn't document specific check
   - **Recommendation**: Add to Task 4: "Subscription authorization must verify current_session.id matches requested session_id"

### Acceptance Criteria Coverage

All 8 acceptance criteria are **FULLY MAPPED** to Epic 3 FR10 requirements with complete implementation guidance:

| AC# | Description | Epic FR | Status | Evidence from Story | Implementation Task |
|-----|-------------|---------|--------|---------------------|-------------------|
| AC1 | Progress percentage from completed/required fields | FR10 | ✅ COVERED | Calculation formula provided (line 49) | Task 1: ProgressService |
| AC2 | Current phase display | FR10 | ✅ COVERED | Phase tracking with PHASES constant (line 48, 109) | Task 1: ProgressService |
| AC3 | Estimated time remaining from averages | FR10 | ✅ COVERED | Baseline + adaptive estimation (lines 54-59) | Task 2: Time estimation |
| AC4 | Completed phases as checkmarks | FR10 | ✅ COVERED | completedPhases array tracking (line 48, 115) | Task 1: ProgressService |
| AC5 | Next phase preview | FR10 | ✅ COVERED | nextPhase field in response (line 64, 116) | Task 3: ProgressType |
| AC6 | Real-time subscription updates | FR10 | ✅ COVERED | GraphQL subscription via Action Cable (lines 69-74) | Task 4: Subscription |
| AC7 | Monotonic progress (no backward) | FR10 | ✅ COVERED | Enforcement logic + last_percentage tracking (line 50, 126) | Task 1: ProgressService |
| AC8 | Adaptive time estimation | FR10 | ✅ COVERED | Pace-based adjustment (lines 57-58) | Task 2: Time estimation |

**Summary**: 8 of 8 acceptance criteria fully covered (100%) with clear implementation paths ✅

**Testability Analysis:**
- ✅ All ACs have specific, measurable verification criteria
- ✅ Progress calculation is deterministic and unit-testable
- ✅ Monotonic behavior can be verified with test sequences
- ✅ Subscription behavior testable with Action Cable testing gem
- ✅ Time estimation testable with time progression simulation

### Task Breakdown Validation

**Task Completeness**: 8 tasks covering all feature aspects with clear deliverables ✅

| Task | Description | Well-Sized? | Sequenced? | Architecture Aligned? | Issues Found |
|------|-------------|-------------|------------|----------------------|--------------|
| Task 1 | Progress calculation service | ✅ Yes (1 service) | ✅ First (foundation) | ✅ Service pattern (arch lines 230-263) | MED: Missing model helper subtask |
| Task 2 | Time estimation + adaptive | ✅ Yes (baseline + adaptation) | ✅ After Task 1 | ✅ JSONB structure (arch line 382) | None |
| Task 3 | ProgressType GraphQL | ✅ Yes (1 type + resolver) | ✅ After Tasks 1-2 | ✅ Type naming (arch lines 85-95) | None |
| Task 4 | Real-time subscription | ✅ Yes (1 subscription) | ✅ After Task 3 | ✅ Action Cable (arch lines 672-722) | LOW: Auth detail missing |
| Task 5 | Update mutation trigger | ✅ Yes (mutation mod) | ✅ After Task 4 | ✅ Mutation pattern (arch lines 267-298) | MED: Mutation existence unclear |
| Task 6 | Phase configuration | ✅ Yes (1 initializer) | ✅ Can parallel 1-3 | ✅ Initializer pattern (arch line 176) | MED: Scope creep risk (FR41) |
| Task 7 | Redis caching | ✅ Yes (cache layer) | ✅ After Tasks 1-3 | ✅ Redis usage (arch line 54) | LOW: TTL strategy unclear |
| Task 8 | Testing & validation | ✅ Yes (comprehensive suite) | ✅ Last (integration) | ✅ RSpec pattern (arch line 62) | None (broad by design) |

**Task Sequencing**: ✅ Logical progression with clear dependencies:
1. **Foundation** (Tasks 1-2): Core business logic (ProgressService + time estimation)
2. **API Layer** (Tasks 3-5): GraphQL types, subscriptions, mutations
3. **Configuration** (Task 6): Phase definitions (can parallel with 1-3)
4. **Performance** (Task 7): Caching layer (depends on service completion)
5. **Quality** (Task 8): Comprehensive testing (integration phase)

**Dependencies Validation**: ✅ All Epic 1 prerequisites satisfied
- ✅ OnboardingSession model exists (Epic 1 Story 1.2)
- ✅ GraphQL configured (Epic 1 Story 1.1)
- ✅ Redis available (Epic 1 Story 1.4)
- ✅ Action Cable configured (Epic 1 Story 1.1)
- ⚠️ **VERIFY**: UpdateProgress mutation from Epic 2 Story 2.2 (Task 5 dependency)

### Test Coverage Assessment

**Expected Test Coverage**: ✅ **COMPREHENSIVE** with clear test-to-AC mapping

**Planned Test Files** (from Task 8):
1. ✅ `spec/services/conversation/progress_service_spec.rb` - Core calculation logic
   - Tests: AC1 (percentage), AC2 (phase), AC4 (completed phases), AC7 (monotonic)
   - Edge cases: Empty progress, corrupted JSONB, phase transitions
2. ✅ `spec/graphql/types/progress_type_spec.rb` - Type structure validation
   - Tests: AC5 (next phase field), field presence, nullability
3. ✅ `spec/graphql/subscriptions/progress_updated_spec.rb` - Real-time updates
   - Tests: AC6 (subscription broadcasts), authorization, multi-client scenarios
4. ✅ Integration tests (Task 8) - Full intake flow with progress tracking
   - Tests: AC3 (time estimation), AC8 (adaptive adjustment), AC7 (monotonic across phases)

**Test-to-AC Coverage Matrix:**
| AC | Test File | Test Type | Verification Method |
|----|-----------|-----------|---------------------|
| AC1 | progress_service_spec.rb | Unit | Assert percentage = (completed/total) * 100 |
| AC2 | progress_service_spec.rb | Unit | Assert current_phase matches session.progress |
| AC3 | Integration test | E2E | Measure actual vs. estimated time |
| AC4 | progress_service_spec.rb | Unit | Assert completedPhases array contents |
| AC5 | progress_type_spec.rb | Unit | Assert nextPhase field returns correct value |
| AC6 | progress_updated_spec.rb | Integration | Assert subscription receives updates |
| AC7 | progress_service_spec.rb | Unit | Assert percentage never decreases |
| AC8 | Integration test | E2E | Simulate slow/fast pace, verify adjustment |

**Testability**: ✅ All 8 acceptance criteria fully testable with deterministic verification

**Test Quality Recommendations**:
- **Action Cable Testing**: Consider adding `gem 'action-cable-testing'` for subscription tests (AC6)
- **Time Simulation**: Use Timecop or ActiveSupport::Testing::TimeHelpers for AC3/AC8 time-based tests
- **Edge Cases**: Test corrupted progress JSONB, missing phases, phase ordering
- **Concurrency**: Test multiple simultaneous progress updates (Redis cache invalidation)
- **Monotonic Enforcement**: Test percentage never decreases even with field removal

### Architectural Alignment

**Architecture Compliance**: ✅ **FULLY COMPLIANT** with Rails 7 + GraphQL patterns

**Pattern Validation:**
| Pattern | Story Implementation | Architecture Reference | Status |
|---------|---------------------|------------------------|--------|
| Service Layer | `Conversation::ProgressService` (lines 106-128) | arch lines 230-263 | ✅ Correct namespace + pattern |
| GraphQL Types | `Types::ProgressType` (lines 131-142) | arch lines 85-95 | ✅ Naming + structure correct |
| GraphQL Mutations | Update via `Sessions::UpdateProgress` (line 77) | arch lines 267-298 | ✅ Pattern matches |
| GraphQL Subscriptions | `ProgressUpdated` (line 70) | arch lines 672-722 | ✅ Action Cable integration |
| Model Enums | Progress stored in JSONB (line 147) | arch line 382 | ✅ Session.progress structure |
| Redis Caching | 1-hour TTL write-through (line 89) | arch line 54 | ✅ Usage correct (TTL debatable) |
| File Naming | snake_case for files (line 46, 62, 70) | arch lines 219-232 | ✅ Conventions followed |
| Class Naming | PascalCase for classes (line 108, 134) | arch lines 219-232 | ✅ Conventions followed |

**Separation of Concerns**: ✅ **PROPER**
- **Business Logic**: `ProgressService` handles calculations (lines 106-128)
- **API Layer**: GraphQL types/subscriptions expose data (lines 131-142, 69-74)
- **Data Layer**: OnboardingSession model stores progress (line 147-157)
- **Caching**: Redis layer for performance (lines 88-92)

**Technology Stack Alignment**: ✅ **MATCHES** architecture.md
- Ruby on Rails 7.2 (confirmed via Gemfile)
- GraphQL via graphql-ruby 2.2
- PostgreSQL with JSONB support
- Redis for caching + Sidekiq backend
- Action Cable for WebSocket subscriptions
- RSpec for testing

**Epic 3 Context**:
- ⚠️ **No Epic Tech Spec found** - Unable to validate against epic-level technical specification
- ✅ **Epic 3 FR10 fully covered** - All progress indicator requirements from epics.md lines 597-623 mapped to ACs
- ✅ **Story fits Epic 3 scope** - Conversational AI Intake feature set (epics.md lines 491-721)

### Security Notes

**Security Assessment**: ✅ **NO CONCERNS** - Progress data properly scoped and non-sensitive

**Security Analysis:**
| Concern | Mitigation | Status | Evidence |
|---------|-----------|--------|----------|
| Unauthorized progress access | Subscription authorization check | ✅ Planned | Task 4 (line 71) - verify session_id |
| Session hijacking | JWT authentication required | ✅ Inherited | Epic 2 Story 2.6 (auth foundation) |
| PHI exposure in progress | No PHI in progress calculations | ✅ Safe | Progress shows percentages/phases only |
| Cache poisoning | Session-scoped cache keys | ✅ Safe | Redis key: `progress:#{session.id}` |
| Subscription DoS | Existing rate limiting | ✅ Inherited | Epic 2 Story 2.6 (100 req/min anonymous) |
| CORS issues | Existing CORS config | ✅ Inherited | Rack CORS gem configured (Gemfile line 39) |

**PHI Considerations**:
- ✅ **Progress data is metadata** - Contains NO PHI (only percentages, phase names, time estimates)
- ✅ **Session-scoped** - Progress tied to session.id, not directly to parent/child
- ✅ **Encrypted at rest** - Session.progress JSONB encrypted via Rails encryption (arch lines 303-329)
- ✅ **No audit logging required** - Progress updates don't access PHI fields

**Authorization Chain**:
1. Client authenticates with JWT (Epic 2 Story 2.1)
2. JWT contains session_id claim
3. Subscription verifies current_session.id == requested session_id (Task 4)
4. Only session owner can subscribe to progress updates

**Recommendations**:
- ✅ No additional security measures required
- 📝 Document subscription authorization logic (LOW priority finding #6)

### Best Practices and References

**Rails 7 + GraphQL Best Practices:**
- **GraphQL Subscriptions**: https://graphql-ruby.org/subscriptions/action_cable_implementation
  - ✅ Story uses Action Cable integration (Task 4, lines 69-74)
  - ✅ Subscription authorization pattern documented (arch lines 710-719)
  - 📝 Recommended: Implement `subscribe` method authorization check (LOW finding #6)
- **GraphQL Types**: https://graphql-ruby.org/type_definitions/objects.html
  - ✅ Story follows type-safe schema design (ProgressType, lines 131-142)
  - ✅ Resolver pattern for complex fields (calculate method, line 111)
- **GraphQL Mutations**: https://graphql-ruby.org/mutations/mutation_classes.html
  - ✅ Story uses mutation pattern for updates (Task 5, line 77)

**Action Cable Real-Time Updates:**
- **Rails Guides**: https://guides.rubyonrails.org/action_cable_overview.html
  - ✅ Proper channel-based broadcasting (arch lines 672-722)
  - ✅ Subscription lifecycle management in GraphQL channel
  - ✅ Redis backend for multi-server support (Gemfile line 12)

**Redis Caching with Rails:**
- **Caching Guide**: https://guides.rubyonrails.org/caching_with_rails.html#activesupport-cache-rediscachestore
  - ✅ Write-through cache pattern (Task 7, lines 88-92)
  - ✅ Cache invalidation on mutations (line 90)
  - 📝 Consider: Document TTL rationale (1h vs 24h session lifetime) - LOW finding #4

**RSpec Testing Patterns:**
- **Service Testing**: https://www.betterspecs.org/ + RSpec Rails docs
  - ✅ Story plans comprehensive service specs (Task 8, line 94-99)
  - 📝 Consider: Add `gem 'action-cable-testing'` for subscription tests
  - 📝 Consider: Use Timecop or ActiveSupport::Testing::TimeHelpers for time-based tests (AC3/AC8)
- **GraphQL Testing**: https://graphql-ruby.org/testing/integration_tests.html
  - ✅ Story includes GraphQL type and subscription tests

**Progressive Enhancement Patterns:**
- **Monotonic Progress**: Design pattern from UX best practices
  - ✅ Implemented via last_percentage tracking (line 126, 151)
  - Reference: Prevents user confusion from backward progress movement
- **Adaptive Estimation**: Machine learning principle (lightweight)
  - ✅ Pace-based adjustment using actual vs. baseline times (Task 2, lines 57-58)
  - Reference: Improves UX by personalizing time estimates

### Action Items

**IMPORTANT**: These are pre-implementation clarifications to improve the story before development begins. All items are story documentation updates, NOT code changes.

#### Code Changes Required (Story Clarifications Before Implementation)

- [ ] **[MED-1]** Add explicit subtask to Task 1: "Add progress calculation helper methods to OnboardingSession model"
  - **Location**: Story file, Tasks section (lines 45-51)
  - **Rationale**: Files to Modify section (line 187) mentions model helper methods but no task covers this
  - **Suggested Addition**: Add as final subtask under Task 1 after line 51

- [ ] **[MED-2]** Verify `Mutations::Sessions::UpdateProgress` existence from Epic 2 Story 2.2
  - **Location**: Story file, Task 5 (line 77)
  - **Action**: Check Epic 2 Story 2.2 implementation, then update Task 5 wording to either:
    - "Modify `UpdateProgress` mutation..." (if exists) OR
    - "Create or modify `UpdateProgress` mutation..." (if uncertain)
  - **Impact**: Affects task effort estimation

- [ ] **[MED-3]** Clarify Task 6 scope to prevent FR41 overbuilding
  - **Location**: Story file, Task 6, line 86
  - **Current**: "Make configuration admin-updatable (preparatory for FR41)"
  - **Recommended**: "Externalize configuration to initializer (admin UI deferred to Epic 7 Story 7.5/FR41)"
  - **Rationale**: FR41 is Epic 7 feature, should not be built in Epic 3

#### Documentation Improvements (Low Priority)

- [ ] **[LOW-4]** Document error handling strategy in Dev Notes
  - **Location**: Story file, Dev Notes section (after line 193)
  - **Addition**: "Error Handling: ProgressService should return safe defaults (percentage: 0, current_phase: 'unknown') if calculation fails due to corrupted JSONB or missing phase data"

- [ ] **[LOW-5]** Document subscription authorization logic in Task 4
  - **Location**: Story file, Task 4 (line 71)
  - **Addition**: Expand "authorization check" to: "Authorization check: verify current_session.id matches requested session_id per architecture pattern (arch lines 710-719)"

- [ ] **[LOW-6]** Document Redis cache key format and TTL rationale
  - **Location**: Story file, Task 7 Dev Notes (after line 92)
  - **Addition**: "Redis cache key format: `progress:#{session.id}` with 1-hour TTL (refresh on activity). Consider aligning with session lifetime (24h) or document rationale for shorter TTL."

- [ ] **[LOW-7]** Add testing dependency recommendation
  - **Location**: Story file, Task 4 or Task 8 notes
  - **Addition**: "Consider adding `gem 'action-cable-testing'` to Gemfile (development/test group) for robust subscription testing"

- [ ] **[LOW-8]** Add Epic 2 prerequisite verification
  - **Location**: Story file, Prerequisites section (after line 24)
  - **Addition**: "Verify `Mutations::Sessions::UpdateProgress` exists from Epic 2 Story 2.2 before starting Task 5"

#### Advisory Notes (Informational - No Action Required)

These are observations for future consideration, not blocking issues:

- **Performance Monitoring**: Consider adding logging for ProgressService.calculate execution time to identify optimization opportunities in production
- **Baseline Refinement**: Time estimation baselines in `config/initializers/onboarding_phases.rb` should start with conservative estimates, then refine using actual completion data analytics (Epic 7 Story 7.4)
- **Pattern Documentation**: Monotonic progress enforcement using `last_percentage` is an excellent UX pattern - consider documenting in architecture best practices for reuse in other features
- **Test Scope**: Integration test in Task 8 ("complete full intake flow") is appropriately broad for integration testing; unit tests handle granular scenarios
- **Cache Strategy**: 1-hour TTL may be conservative given 24-hour session lifetime; monitor cache hit rate and adjust if needed

### Review Validation Checklist

✅ **Story File**: Loaded from `/Users/andre/coding/daybreak/daybreak-health-backend/docs/sprint-artifacts/3-4-progress-indicators.md`
✅ **Story Status**: "drafted" (Pre-Implementation Design Review)
✅ **Epic/Story IDs**: Epic 3, Story 3.4 resolved
⚠️ **Story Context**: Not found (expected for drafted status)
⚠️ **Epic Tech Spec**: Not found for Epic 3 (warning only - epic context available from epics.md)
✅ **Architecture Docs**: Loaded from architecture.md (993 lines)
✅ **Tech Stack**: Detected - Ruby on Rails 7.2, GraphQL, PostgreSQL, Redis, Sidekiq, Action Cable
✅ **Epic Alignment**: All 8 ACs map to Epic 3 FR10 requirements (100% coverage)
✅ **Architecture Compliance**: Fully aligned with Rails 7 patterns (8/8 pattern validations passed)
✅ **AC Coverage**: 8 of 8 acceptance criteria fully covered with implementation guidance
✅ **Task Breakdown**: 8 well-sized, logically sequenced tasks covering all ACs
✅ **Dependencies**: All Epic 1 prerequisites satisfied, 1 Epic 2 dependency needs verification
✅ **Testability**: All 8 ACs testable with clear verification methods
✅ **Security**: No concerns identified, proper session scoping
✅ **Best Practices**: References provided for Rails 7, GraphQL, Action Cable, Redis, RSpec

**Systematic Validation Summary:**
- **HIGH Severity Issues**: 0 ✅
- **MEDIUM Severity Issues**: 3 (all story documentation clarifications)
- **LOW Severity Issues**: 3 (documentation improvements)
- **Blocking Issues**: 0 ✅

### Conclusion

**Story 3.4 is APPROVED for implementation** with confidence after addressing 3 MEDIUM severity story clarifications:

1. **[MED-1]** Add model helper methods subtask to Task 1
2. **[MED-2]** Verify/clarify UpdateProgress mutation existence from Epic 2
3. **[MED-3]** Adjust Task 6 scope to prevent FR41 overbuilding

**Strengths Identified:**
- ✅ **100% FR10 coverage** with precise AC-to-requirement mapping
- ✅ **Excellent architecture alignment** across all 8 Rails/GraphQL patterns
- ✅ **Comprehensive task breakdown** with clear deliverables and sequencing
- ✅ **Thorough technical guidance** including code examples and JSONB structures
- ✅ **Strong testability** with specific test files and verification methods
- ✅ **Monotonic progress pattern** is excellent UX design choice
- ✅ **Adaptive time estimation** adds personalization value

**Risk Assessment**: ✅ **LOW RISK**
- No HIGH severity issues blocking implementation
- All MEDIUM issues are documentation clarifications (not architectural flaws)
- Dependencies clearly identified with verification path
- Security properly scoped to existing authentication

**Recommendation**: Update story documentation per 3 MEDIUM action items, then proceed to implementation phase. Story is implementation-ready with minor clarification updates.

**Estimated Clarification Time**: 15-20 minutes to address all 8 documentation items

---

**Change Log**:
- 2025-11-29 (Initial): Design review completed - Story structure validated, minor clarifications recommended
- 2025-11-29 (Updated): Comprehensive review with systematic AC/task validation, enhanced evidence trail, architecture pattern validation, test coverage analysis, security assessment, and actionable items with specific line references