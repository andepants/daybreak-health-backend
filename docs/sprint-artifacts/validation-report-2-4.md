# Validation Report: Story 2.4 - Session Expiration & Cleanup

**Story Document:** `/Users/andre/coding/daybreak/daybreak-health-backend/docs/sprint-artifacts/2-4-session-expiration-and-cleanup.md`

**Validation Date:** 2025-11-29

**Validation Status:** PASSED WITH RECOMMENDATIONS

---

## Executive Summary

Story 2.4 demonstrates strong alignment with the create-story checklist. The story successfully covers all source requirements, provides clear task-to-AC mapping, and includes comprehensive dev notes. Several minor recommendations for enhancement are provided below.

**Overall Score:** 92/100

| Category | Score | Status |
|----------|-------|--------|
| Previous Story Continuity | 10/10 | PASS |
| Source Document Coverage | 18/20 | PASS |
| Acceptance Criteria Quality | 20/20 | PASS |
| Task-AC Mapping | 20/20 | PASS |
| Dev Notes Quality | 18/20 | PASS |
| Story Structure | 6/10 | PASS |

---

## 1. Previous Story Continuity

**Status:** PASS (10/10)

### Previous Story Reference
- Previous story: 2.3 Session Recovery & Multi-Device Support
- Status: drafted (not yet implemented)
- No implementation learnings to validate

### Continuity Check
Story 2.4 correctly positions itself in the Epic 2 sequence:
- Builds on session lifecycle foundation from 2.1 and 2.2
- Complements 2.3 by handling expired sessions
- Does not block or duplicate functionality from previous stories

**Finding:** No continuity issues identified. Story prerequisites are correctly documented (Story 2.2).

---

## 2. Source Document Coverage

**Status:** PASS (18/20)

### 2.1 docs/epics.md Coverage - CRITICAL

**Epic Source Text (lines 399-426):**

```markdown
### Story 2.4: Session Expiration & Cleanup

As the **system**,
I want **to expire inactive sessions after a configurable period**,
So that **resources are freed and abandoned data is handled per retention policy**.

**Acceptance Criteria:**

**Given** a session has been inactive beyond the expiration threshold
**When** the cleanup job runs
**Then**
- Sessions with `expiresAt` in the past marked as `EXPIRED`
- Expired sessions retained in database for 90 days (compliance)
- Associated data (messages, progress) retained with session
- No new activity allowed on expired sessions
- Cleanup job runs every 15 minutes via scheduled task

**And** attempting to update expired session returns `SESSION_EXPIRED` error
**And** audit log: `action: SESSION_EXPIRED`
```

**Story Document Coverage Analysis:**

| Epic AC | Story AC | Coverage | Notes |
|---------|----------|----------|-------|
| Sessions with expiresAt in past marked EXPIRED | AC 2.4.1 | EXACT MATCH | "Sessions with `expiresAt` in the past marked as `EXPIRED`" |
| Expired sessions retained 90 days | AC 2.4.2 | EXACT MATCH | "Expired sessions retained in database for 90 days (compliance)" |
| Associated data retained | AC 2.4.3 | EXACT MATCH | "Associated data (messages, progress) retained with session" |
| No new activity on expired sessions | AC 2.4.4 | EXACT MATCH | "No new activity allowed on expired sessions" |
| Cleanup job runs every 15 minutes | AC 2.4.5 | EXACT MATCH | "Cleanup job runs every 15 minutes via scheduled task" |
| SESSION_EXPIRED error | AC 2.4.6 | EXACT MATCH | "Attempting to update expired session returns `SESSION_EXPIRED` error" |
| Audit log SESSION_EXPIRED | AC 2.4.7 | EXACT MATCH | "Audit log: `action: SESSION_EXPIRED`" |

**Citation Quality:**
- References section includes: `[Source: docs/epics.md#Story 2.4: Session Expiration & Cleanup]`
- Citation is accurate and specific

**Finding:** All epic ACs covered exactly as specified.

---

### 2.2 docs/architecture.md Coverage

**Relevant Architecture Sections:**

1. **Session Lifecycle (lines 520-545):**
```ruby
class OnboardingSession < ApplicationRecord
  enum :status, {
    started: 0,
    in_progress: 1,
    insurance_pending: 2,
    assessment_complete: 3,
    submitted: 4,
    abandoned: 5,
    expired: 6  # <-- Story 2.4 introduces this status
  }
```

2. **Background Jobs (lines 637-667):**
```ruby
# Pattern for Sidekiq jobs with retry logic
class OcrProcessingJob < ApplicationJob
  queue_as :default
  retry_on Aws::Textract::Errors::ServiceError
```

3. **Testing Standards (spec/ directory structure)**

**Story Coverage Analysis:**

| Architecture Component | Story Coverage | Location in Story |
|------------------------|----------------|-------------------|
| Session status enum (expired) | YES | Dev Notes line 151, Tasks refer to status transitions |
| Sidekiq job pattern | YES | Task 1 creates SessionCleanupJob, Task 2 configures Sidekiq-cron |
| Error handling pattern | YES | Task 4 implements SESSION_EXPIRED error |
| Audit logging pattern | YES | Task 5 implements audit logging via Auditable concern |
| RSpec testing | YES | Tasks 7-9 define comprehensive test coverage |
| Service organization | PARTIAL | Uses jobs/ correctly, but no explicit service layer |

**Citations:**
```markdown
- [Source: docs/sprint-artifacts/tech-spec-epic-1.md#Data Models]
- [Source: docs/architecture.md#Session Lifecycle]
- [Source: docs/epics.md#Epic 2: Session Lifecycle & Authentication]
```

**Findings:**
- Architecture patterns are followed correctly
- Minor gap: Does not reference architecture.md#Background Jobs section explicitly
- Recommendation: Add citation to architecture.md section on Sidekiq patterns

**Score Deduction:** -2 points for missing explicit architecture.md citation

---

## 3. Acceptance Criteria Quality

**Status:** PASS (20/20)

### AC Structure Review

All 7 ACs follow INVEST principles:

| AC | Independent | Negotiable | Valuable | Estimable | Small | Testable |
|----|-------------|------------|----------|-----------|-------|----------|
| 2.4.1 | YES | NO (core requirement) | YES | YES | YES | YES |
| 2.4.2 | YES | NO (compliance requirement) | YES | YES | YES | YES |
| 2.4.3 | YES | NO (data integrity) | YES | YES | YES | YES |
| 2.4.4 | YES | NO (security) | YES | YES | YES | YES |
| 2.4.5 | YES | PARTIAL (interval configurable) | YES | YES | YES | YES |
| 2.4.6 | YES | NO (error handling) | YES | YES | YES | YES |
| 2.4.7 | YES | NO (audit requirement) | YES | YES | YES | YES |

### Testability Analysis

Each AC has clear success criteria:

**AC 2.4.1:** Sessions with expiresAt in past marked EXPIRED
- **Test:** Create session with expires_at in past, run job, verify status = expired
- **Covered by:** Task 7 Subtask 7.2

**AC 2.4.2:** Expired sessions retained 90 days
- **Test:** Verify expired sessions not deleted before 90 days
- **Covered by:** Task 6 (retention cleanup job)

**AC 2.4.3:** Associated data retained with session
- **Test:** Verify messages, progress, parent, child, insurance, assessment records exist after expiration
- **Covered by:** Task 6 Subtasks 6.3-6.4

**AC 2.4.4:** No new activity on expired sessions
- **Test:** Attempt to update expired session, verify blocked
- **Covered by:** Task 8 Subtask 8.4

**AC 2.4.5:** Cleanup job runs every 15 minutes
- **Test:** Verify Sidekiq-cron schedule configuration
- **Covered by:** Task 9 Subtask 9.3-9.4

**AC 2.4.6:** SESSION_EXPIRED error on update
- **Test:** GraphQL mutation returns SESSION_EXPIRED error code
- **Covered by:** Task 8 Subtask 8.3

**AC 2.4.7:** Audit log SESSION_EXPIRED
- **Test:** Verify audit log entry created with correct action
- **Covered by:** Task 7 Subtask 7.4, Task 9 Subtask 9.5

**Finding:** All ACs are measurable, testable, and clearly defined.

---

## 4. Task-AC Mapping

**Status:** PASS (20/20)

### Mapping Matrix

| AC | Implementing Tasks | Verification | Complete Coverage |
|----|-------------------|--------------|-------------------|
| 2.4.1 | Task 1 (Subtasks 1.2-1.3) | Task 7 (Subtask 7.2) | YES |
| 2.4.2 | Task 6 (Subtasks 6.1-6.4) | Task 7, Task 9 | YES |
| 2.4.3 | Task 6 (Subtasks 6.3-6.4) | Task 7, Task 9 | YES |
| 2.4.4 | Task 4 (Subtasks 4.1-4.4) | Task 8 (Subtask 8.4) | YES |
| 2.4.5 | Task 2 (All subtasks) | Task 9 (Subtasks 9.3-9.4) | YES |
| 2.4.6 | Task 4 (Subtasks 4.2-4.3) | Task 8 (Subtask 8.3) | YES |
| 2.4.7 | Task 5 (All subtasks) | Task 7 (Subtask 7.4) | YES |

### Testing Subtasks Present

**Testing Coverage:**
- **Task 7:** RSpec tests for SessionCleanupJob (5 subtasks)
- **Task 8:** RSpec tests for expired session validation (5 subtasks)
- **Task 9:** Integration testing and verification (6 subtasks)

**Total Testing Subtasks:** 16 out of 59 total subtasks (27% dedicated to testing)

**Finding:** Comprehensive testing coverage with multiple testing approaches (unit, integration, manual verification).

---

## 5. Dev Notes Quality

**Status:** PASS (18/20)

### 5.1 SessionCleanupJob Location

**Required:** `app/jobs/` directory

**Story Documentation:**
```
daybreak-health-backend/
├── app/
│   ├── jobs/
│   │   ├── session_cleanup_job.rb (create)
│   │   └── session_retention_cleanup_job.rb (create - optional)
```

**Finding:** Correctly documented in Dev Notes line 107-108

---

### 5.2 Sidekiq-cron Configuration

**Required:** Sidekiq-cron configuration documented

**Story Documentation (lines 163-177):**
```ruby
# config/initializers/sidekiq_cron.rb
schedule = {
  'session_cleanup' => {
    'cron' => '*/15 * * * *',  # Every 15 minutes
    'class' => 'SessionCleanupJob',
    'queue' => 'default'
  }
}

Sidekiq::Cron::Job.load_from_hash(schedule)
```

**Finding:** Complete Sidekiq-cron configuration example provided.

---

### 5.3 Environment Variables

**Required:** Environment variables documented

**Story Documentation (lines 155-161):**
```bash
# Session expiration (hours since last activity)
SESSION_EXPIRATION_HOURS=24

# Data retention period (days to keep expired sessions)
DATA_RETENTION_DAYS=90
```

**Task Coverage:**
- Task 3 explicitly creates these environment variables
- Task 3 Subtask 3.4: "Document environment variables in README or SETUP.md"

**Finding:** Environment variables documented with clear examples.

---

### 5.4 Architecture Patterns

**Dev Notes Section Analysis:**

```markdown
### Architecture Patterns and Constraints

- **Session Expiration**: Sessions automatically expire after configurable period (default 24 hours)
- **Retention Policy**: Expired sessions retained for 90 days for compliance before deletion
- **Job Scheduling**: Sidekiq-cron runs cleanup job every 15 minutes
- **Error Handling**: GraphQL mutations return SESSION_EXPIRED error code for expired sessions
- **Audit Trail**: All session expirations logged to audit_logs table
- **Data Integrity**: Associated data (messages, progress, parent, child, insurance, assessment) retained with session
```

**Quality Assessment:**
- Patterns are clearly described
- Rationale provided for each decision
- Aligns with architecture.md patterns

---

### 5.5 Session Lifecycle State Machine

**Dev Notes Section (lines 141-152):**

```markdown
#### Session Lifecycle State Machine

Sessions follow this lifecycle:
STARTED → IN_PROGRESS → INSURANCE_PENDING → ASSESSMENT_COMPLETE → SUBMITTED
                ↓                ↓                    ↓                 ↓
            ABANDONED        ABANDONED           ABANDONED         ABANDONED
                ↓                ↓                    ↓                 ↓
            EXPIRED          EXPIRED              EXPIRED           EXPIRED
```

**Finding:** Excellent visual representation of state transitions. Clarifies that any non-SUBMITTED session can expire.

---

### 5.6 Missing Elements (Minor)

**Recommendation 1:** Add explicit reference to architecture.md#Background Jobs section

**Recommendation 2:** Consider adding example of error response format:
```ruby
{
  "errors": [{
    "message": "Session has expired",
    "extensions": {
      "code": "SESSION_EXPIRED",
      "session_id": "sess_clx123..."
    }
  }]
}
```

**Score Deduction:** -2 points for missing explicit architecture pattern references

---

## 6. Story Structure

**Status:** PASS (6/10)

### 6.1 Status Field

**Required:** `Status: drafted`

**Story Document (line 3):**
```markdown
Status: drafted
```

**Finding:** PASS - Status correctly set

---

### 6.2 Dev Agent Record

**Required:** Dev Agent Record section initialized

**Story Document (lines 186-201):**
```markdown
## Dev Agent Record

### Context Reference
TBD - will be created when story moves to ready-for-dev

### Agent Model Used
TBD

### Debug Log References
TBD

### Completion Notes List
TBD

### File List
TBD
```

**Finding:** PASS - Dev Agent Record initialized with TBD placeholders

---

### 6.3 Senior Developer Review Section

**Required:** Senior Developer Review section present

**Story Document (lines 203-240):**
```markdown
## Senior Developer Review (AI)

**Reviewer:** TBD
**Date:** TBD
**Review Type:** TBD

### Outcome: PENDING

Story drafted and ready for technical context creation. Review will be completed after implementation.
```

**Finding:** PASS - Review section initialized

---

### 6.4 Missing GraphQL Schema Definition (Recommendation)

**Current State:** Story documents mutations and queries but does not show GraphQL schema types.

**Recommendation:** Add GraphQL schema examples for:
- `SESSION_EXPIRED` error code enum
- Session type with `expired?` field

**Example:**
```ruby
# app/graphql/types/enums/error_code_enum.rb
module Types
  module Enums
    class ErrorCodeEnum < Types::BaseEnum
      value "SESSION_EXPIRED", "Session has expired and cannot be accessed"
      # ... other codes
    end
  end
end
```

**Score Deduction:** -4 points for missing GraphQL schema specifics (not critical but would enhance clarity)

---

## Detailed Findings Summary

### Strengths

1. **Comprehensive AC Coverage:** All 7 epic ACs translated exactly into story ACs
2. **Clear Task Breakdown:** 10 tasks with 59 subtasks provide granular implementation guidance
3. **Excellent Testing Strategy:** 27% of subtasks dedicated to testing (unit, integration, manual)
4. **Environment Configuration:** Complete environment variable documentation
5. **State Machine Visualization:** Clear diagram of session lifecycle with expiration paths
6. **Retention Policy:** Compliance-aware retention handling (90 days)
7. **Sidekiq-cron Configuration:** Complete working example provided

---

### Recommendations

#### Priority 1: Add Missing Citations

**Issue:** Missing explicit citation to architecture.md#Background Jobs

**Action:**
```markdown
### References

- [Source: docs/epics.md#Story 2.4: Session Expiration & Cleanup]
- [Source: docs/sprint-artifacts/tech-spec-epic-1.md#Data Models]
- [Source: docs/architecture.md#Session Lifecycle]
+ [Source: docs/architecture.md#Background Jobs (Sidekiq)]
- [Source: docs/epics.md#Epic 2: Session Lifecycle & Authentication]
```

---

#### Priority 2: Add GraphQL Error Code Schema

**Issue:** SESSION_EXPIRED error mentioned but schema not defined

**Action:** Add to Dev Notes:
```markdown
### GraphQL Error Codes

```ruby
# app/graphql/errors/error_codes.rb
module Errors
  SESSION_EXPIRED = "SESSION_EXPIRED"
end

# Usage in mutation/query:
raise GraphQL::ExecutionError.new(
  "Session has expired",
  extensions: { code: Errors::SESSION_EXPIRED }
)
```
```

---

#### Priority 3: Clarify Retention vs Cleanup Jobs

**Issue:** Task 6 creates SessionRetentionCleanupJob but distinction from SessionCleanupJob could be clearer

**Action:** Add to Dev Notes:
```markdown
### Job Responsibilities

**SessionCleanupJob** (runs every 15 minutes):
- Marks sessions with expires_at < now as EXPIRED
- Does NOT delete data

**SessionRetentionCleanupJob** (runs daily):
- Hard deletes sessions where status = EXPIRED and updated_at < 90.days.ago
- Respects retention policy
```

---

#### Priority 4: Add Rollback Considerations

**Issue:** No mention of how to handle if job fails mid-execution

**Action:** Add to Task 1 Subtask 1.5:
```markdown
- [ ] Subtask 1.5: Add error handling with retry logic
  - Use Sidekiq retry with exponential backoff
  - Log failures to error monitoring system
  - Use database transaction to ensure atomic updates
  - Consider batch processing for large volumes (UPDATE in batches of 1000)
```

---

## Checklist Validation Results

### 1. Previous Story Continuity
- [x] Previous story identified: 2.3
- [x] No implementation learnings to validate (story drafted, not implemented)
- [x] Prerequisites documented (Story 2.2)

### 2. Source Document Coverage
- [x] docs/epics.md - ALL ACs covered (7/7)
- [x] Epic AC citations accurate
- [x] docs/architecture.md - Patterns followed
- [ ] Missing explicit architecture.md#Background Jobs citation (-2 points)

### 3. Acceptance Criteria Quality
- [x] All ACs testable
- [x] All ACs measurable
- [x] All ACs aligned with epic source
- [x] No ambiguous acceptance criteria

### 4. Task-AC Mapping
- [x] Every AC has implementing task(s)
- [x] Testing subtasks present (16 testing subtasks)
- [x] No orphaned ACs
- [x] No orphaned tasks (all map to ACs or infrastructure)

### 5. Dev Notes Quality
- [x] SessionCleanupJob in app/jobs/ documented
- [x] Sidekiq-cron configuration complete
- [x] Environment variables documented
- [x] Architecture patterns referenced
- [ ] Minor: Missing GraphQL schema details (-2 points)

### 6. Story Structure
- [x] Status = "drafted"
- [x] Dev Agent Record initialized
- [x] Senior Developer Review section present
- [ ] Missing GraphQL schema specifics (-4 points)

---

## Validation Verdict

**PASSED WITH RECOMMENDATIONS**

**Overall Score:** 92/100

Story 2.4 meets all critical validation criteria and demonstrates strong adherence to the create-story checklist. The story is ready for implementation with the following caveats:

**Before Moving to Ready-for-Dev:**
1. Add architecture.md#Background Jobs citation to References
2. Consider adding GraphQL error code schema examples to Dev Notes
3. Clarify distinction between SessionCleanupJob and SessionRetentionCleanupJob

**During Implementation:**
1. Ensure Sidekiq-cron gem is added to Gemfile (Task 2 Subtask 2.1)
2. Verify SESSION_EXPIRED error code exists in GraphQL error handling
3. Document retention job schedule (daily/weekly) in Task 6 Subtask 6.5

---

## Quality Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Epic AC Coverage | 7/7 (100%) | 100% | PASS |
| Task-AC Mapping | 7/7 ACs mapped | 100% | PASS |
| Testing Coverage | 16/59 subtasks (27%) | >20% | PASS |
| Architecture Alignment | High | High | PASS |
| Citation Completeness | 3/4 sections | 100% | MINOR GAP |
| Subtask Granularity | 5.9 avg/task | 3-8 | OPTIMAL |

---

## Appendix: Task Execution Order Recommendation

**Suggested Implementation Sequence:**

1. **Foundation (Days 1-2):**
   - Task 3: Environment configuration
   - Task 2: Sidekiq-cron setup

2. **Core Logic (Days 3-4):**
   - Task 1: SessionCleanupJob implementation
   - Task 5: Audit logging

3. **Validation (Day 5):**
   - Task 4: Expired session validation

4. **Retention (Day 6):**
   - Task 6: Retention cleanup job

5. **Testing (Days 7-8):**
   - Task 7: Unit tests
   - Task 8: Integration tests
   - Task 9: Manual verification

6. **Documentation (Day 9):**
   - Task 10: Documentation updates

**Estimated Story Completion:** 9-10 dev days

---

**Validator:** BMad Validation Agent
**Validation Checklist Version:** create-story-v1
**Date:** 2025-11-29
