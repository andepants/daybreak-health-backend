# Story 7.2: Session Context Passing

Status: drafted

## Story

As a **support agent**,
I want **to see the parent's onboarding context when they start a chat**,
So that **I can help them effectively without asking repetitive questions**.

## Acceptance Criteria

**Given** parent initiates chat from onboarding
**When** chat opens in Intercom
**Then**
- Custom attributes passed to Intercom:
  - Session ID
  - Current onboarding step/phase
  - Parent name (if collected)
  - Child age (if collected)
  - Insurance status (verified/pending/self-pay)
  - Any error states or blockers
- Agent sees context in Intercom dashboard
- Deep link to admin session view (if available)
- Context updates as parent progresses

**And** no PHI sent to Intercom (only IDs and status)
**And** context helps agent assist faster

## Tasks / Subtasks

- [ ] Task 1: Define Intercom context attribute schema (AC: Custom attributes)
  - [ ] Subtask 1.1: Create context payload structure with PHI-safe fields
  - [ ] Subtask 1.2: Define attribute naming conventions for Intercom
  - [ ] Subtask 1.3: Document attribute schema in code comments

- [ ] Task 2: Implement backend context generation endpoint (AC: Backend endpoint)
  - [ ] Subtask 2.1: Create GraphQL query `generateIntercomContext(sessionId: ID!): IntercomContextPayload!`
  - [ ] Subtask 2.2: Implement service `app/services/support/intercom_context_service.rb`
  - [ ] Subtask 2.3: Extract session data (status, phase, progress)
  - [ ] Subtask 2.4: Extract parent name (first name only, no PII)
  - [ ] Subtask 2.5: Calculate child age from DOB (no DOB itself)
  - [ ] Subtask 2.6: Extract insurance status enum (verified/pending/self-pay)
  - [ ] Subtask 2.7: Detect and include error states or blockers
  - [ ] Subtask 2.8: Sanitize all data before returning (validate no PHI leakage)

- [ ] Task 3: Implement context update mechanism (AC: Context updates as parent progresses)
  - [ ] Subtask 3.1: Add Intercom update hooks to session progress mutations
  - [ ] Subtask 3.2: Trigger context refresh on status transitions
  - [ ] Subtask 3.3: Implement debouncing for frequent updates (max 1 update per 30s)
  - [ ] Subtask 3.4: Use Intercom `update` method via API

- [ ] Task 4: Generate deep link to admin session view (AC: Deep link to admin session view)
  - [ ] Subtask 4.1: Construct admin URL pattern: `{ADMIN_URL}/sessions/{sessionId}`
  - [ ] Subtask 4.2: Include deep link in custom attributes
  - [ ] Subtask 4.3: Handle cases where admin dashboard not available

- [ ] Task 5: PHI compliance validation (AC: No PHI sent to Intercom)
  - [ ] Subtask 5.1: Audit all attributes to ensure no PHI (email, phone, DOB, SSN, addresses)
  - [ ] Subtask 5.2: Use only: session ID, phase name, first name, age (number), status enums
  - [ ] Subtask 5.3: Add automated test to validate payload against PHI checklist
  - [ ] Subtask 5.4: Document PHI-safe vs PHI fields in service

- [ ] Task 6: Testing (AC: All)
  - [ ] Subtask 6.1: Unit tests for IntercomContextService
  - [ ] Subtask 6.2: Test PHI sanitization with various session states
  - [ ] Subtask 6.3: Test context updates on session transitions
  - [ ] Subtask 6.4: Integration test with Intercom API (test mode)
  - [ ] Subtask 6.5: Verify context visible in Intercom dashboard (manual verification)

## Dev Notes

### Requirements Context Summary

This story builds upon Story 7.1 (Intercom Widget Integration) to pass contextual onboarding data to support agents without exposing PHI.

**Key Requirements from Epic 7:**
- Story 7.2 enables support agents to see onboarding context in Intercom
- Prerequisite: Story 7.1 (Intercom widget integration)
- Must comply with HIPAA: no PHI transmitted to Intercom
- Context should update as parent progresses through onboarding

**Architecture Constraints:**
- Use GraphQL for backend API (graphql-ruby)
- Services in `app/services/support/` directory
- Follow Rails conventions and existing patterns
- PHI sanitization is CRITICAL - only IDs and status allowed

**Testing Standards:**
- RSpec for all service and GraphQL tests
- Minimum 80% coverage on new code
- Integration test with Intercom test environment
- Manual verification in Intercom dashboard

### Project Structure Notes

**Expected File Structure:**
```
app/
├── graphql/
│   ├── types/
│   │   └── intercom_context_type.rb          # NEW: GraphQL type for context payload
│   └── queries/
│       └── generate_intercom_context.rb       # NEW: GraphQL query
│
├── services/
│   └── support/
│       └── intercom_context_service.rb        # NEW: Core context generation logic
│
spec/
├── graphql/
│   └── queries/
│       └── generate_intercom_context_spec.rb  # NEW: Query tests
└── services/
    └── support/
        └── intercom_context_service_spec.rb   # NEW: Service tests
```

**Alignment with Project Structure:**
- Services layer: `app/services/support/` (new subdirectory for support-related services)
- GraphQL layer: queries for read-only context generation
- No database changes required (read-only from existing models)
- Use existing concerns: `Encryptable` (to verify PHI fields), `Auditable` (for context access logging)

### References

**Epic & Story Sources:**
- [Source: docs/epics.md#Epic-7-Story-7.2]
- FR Coverage: FR12 (human escalation), indirectly supports FR34 (care team notification)

**Architecture References:**
- [Source: docs/architecture.md#Project-Structure] - Services directory structure
- [Source: docs/architecture.md#Technology-Requirements] - GraphQL via graphql-ruby
- [Source: docs/architecture.md#Decision-Summary] - HIPAA compliance requirements

**Technical Specifications:**
- Intercom API: Use `update` method to set custom user attributes
- PHI-safe fields: session_id (CUID), phase (enum string), first_name (string), age (integer), status (enum)
- Prohibited fields: email, phone, DOB, last_name, child_name, addresses, SSN, member_id
- Update frequency: Debounce to max 1 update per 30 seconds per session
- Deep link format: `{ADMIN_URL}/sessions/{session_id}` (configurable via ENV)

**Standard Attribute Schema:**
```ruby
{
  session_id: "sess_clx123...",           # CUID
  onboarding_phase: "insurance_pending",  # Enum: started, in_progress, insurance_pending, etc.
  parent_first_name: "Jane",              # First name only (no last name)
  child_age: 12,                          # Calculated age (not DOB)
  insurance_status: "pending",            # Enum: verified, pending, self_pay
  has_errors: false,                      # Boolean
  error_type: nil,                        # String (if has_errors: true)
  admin_link: "https://admin.daybreak.com/sessions/sess_clx123"  # Deep link
}
```

**Error States to Detect:**
- OCR extraction failed
- Eligibility verification timeout
- Missing required fields blocking progress
- Session expired

### Learnings from Previous Story

**No previous story context available** - Story 7.1 (Intercom Widget Integration) has not been implemented yet (status: ready-for-dev in sprint-status.yaml).

**Note for Developer:**
Since Story 7.1 is the prerequisite and hasn't been completed:
1. This story assumes Story 7.1 provides the Intercom SDK integration on the frontend
2. This story focuses on the backend context generation only
3. Frontend integration of the context payload will depend on Story 7.1's Intercom boot/update implementation
4. Coordinate with Story 7.1 developer to ensure context payload format matches frontend expectations

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context XML will be added here by context workflow -->

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
