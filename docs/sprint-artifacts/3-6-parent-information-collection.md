# Story 3.6: Parent Information Collection

Status: ready-for-dev

## Story

As a **parent**,
I want **to provide my contact information through natural conversation**,
so that **Daybreak can reach me about my child's care**.

## Acceptance Criteria

**Given** intake has reached parent information phase
**When** parent provides their details
**Then**

1. Fields collected: firstName, lastName, email, phone
2. Relationship to child collected (parent, guardian, grandparent, etc.)
3. Legal guardian status confirmed (boolean)
4. Email validated (RFC 5322 format)
5. Phone validated (E.164 format)
6. Data extracted from natural language responses
7. Confirmation shown before saving
8. All PHI encrypted before storage
9. Data stored in Parent entity linked to session
10. Session recovery email capability triggered once email known

## Tasks / Subtasks

- [ ] **Task 1: Create Parent GraphQL Type and Input** (AC: #1, #2, #3)
  - [ ] Define `ParentType` in `app/graphql/types/parent_type.rb` with fields: id, firstName, lastName, email, phone, relationship, isGuardian
  - [ ] Create `ParentInput` input type with all required fields
  - [ ] Add `parent` field to `OnboardingSessionType` (1:1 relationship)
  - [ ] Implement field-level resolver to decrypt PHI fields transparently

- [ ] **Task 2: Create Parent Model with Encryption** (AC: #8)
  - [ ] Generate Parent migration with UUID primary key
  - [ ] Add encrypted text columns: email, phone, first_name, last_name
  - [ ] Add string columns: relationship (enum), is_guardian (boolean)
  - [ ] Add foreign key to onboarding_sessions with unique index
  - [ ] Create Parent model with `Encryptable` and `Auditable` concerns
  - [ ] Define `encrypts_phi :email, :phone, :first_name, :last_name`
  - [ ] Add relationship enum: parent, guardian, grandparent, foster_parent, other
  - [ ] Run migration

- [ ] **Task 3: Implement Validation Logic** (AC: #4, #5)
  - [ ] Add email validation using Rails URI::MailTo::EMAIL_REGEXP (RFC 5322)
  - [ ] Install and configure `phonelib` gem for E.164 phone validation
  - [ ] Add custom validator for phone format in Parent model
  - [ ] Ensure relationship is one of allowed enum values
  - [ ] Ensure is_guardian is boolean (true/false)
  - [ ] Add presence validations for required fields

- [ ] **Task 4: Create SubmitParentInfo Mutation** (AC: #1-#7, #9)
  - [ ] Create `app/graphql/mutations/intake/submit_parent_info.rb`
  - [ ] Accept ParentInput argument
  - [ ] Verify session exists and is in correct state
  - [ ] Extract and normalize phone number to E.164 format
  - [ ] Validate email and phone formats before saving
  - [ ] Create or update Parent record associated with session
  - [ ] Return parent object with success/error response
  - [ ] Trigger audit log entry: PARENT_INFO_SUBMITTED

- [ ] **Task 5: AI Context Manager Integration** (AC: #6)
  - [ ] Update `app/services/ai/context_manager.rb` to track parent info phase
  - [ ] Implement natural language extraction for parent fields
  - [ ] Parse responses to identify: name components, email, phone, relationship
  - [ ] Handle variations: "I'm her mom" → relationship: parent, "my email is..." → extract email
  - [ ] Mark parent info fields as collected in session progress
  - [ ] Transition to confirmation step when all required fields present

- [ ] **Task 6: Confirmation Flow** (AC: #7)
  - [ ] Add confirmation step to AI prompt flow
  - [ ] Present collected information to parent for review
  - [ ] Format confirmation message: "I've got: [name], [email], [phone], [relationship]"
  - [ ] Allow parent to correct individual fields
  - [ ] Only call SubmitParentInfo mutation after explicit confirmation
  - [ ] Handle corrections by re-prompting for specific field

- [ ] **Task 7: Session Recovery Email Trigger** (AC: #10)
  - [ ] Create session recovery token service in `app/services/auth/token_service.rb`
  - [ ] Generate cryptographically secure recovery token (32 bytes)
  - [ ] Store token in Redis with 15-minute TTL, keyed by session_id
  - [ ] Queue `SessionRecoveryEmailJob` when email is saved
  - [ ] Email should include magic link: `/onboarding/recover?token=...`
  - [ ] Note: Full email sending implementation in Story 6.1

- [ ] **Task 8: Update Session Progress** (AC: #9)
  - [ ] Add `parentInfoCollected: true` to session.progress JSON
  - [ ] Update session.updatedAt timestamp
  - [ ] Extend session.expiresAt by 1 hour on activity
  - [ ] Mark phase transition: started → in_progress (if not already)
  - [ ] Trigger sessionUpdated GraphQL subscription

- [ ] **Task 9: RSpec Tests** (All ACs)
  - [ ] Model tests: Parent model validations (email format, phone format, relationships)
  - [ ] Model tests: Encryption works (save PHI, reload, verify encrypted in DB)
  - [ ] Mutation tests: submitParentInfo success case with valid data
  - [ ] Mutation tests: submitParentInfo validation failures (invalid email, invalid phone)
  - [ ] Mutation tests: submitParentInfo creates audit log entry
  - [ ] Integration tests: AI context manager extracts parent info from natural language
  - [ ] Integration tests: Confirmation flow requires explicit approval

## Dev Notes

### Architecture Patterns

**From Architecture Doc:**
- Use `Encryptable` concern for PHI field encryption (email, phone, names)
- Use `Auditable` concern for automatic audit logging
- Follow Rails Active Record conventions for models
- GraphQL types in `app/graphql/types/`, mutations in `app/graphql/mutations/intake/`
- Services in `app/services/` for business logic (AI, auth, validation)

**PHI Fields to Encrypt:**
- Parent: email, phone, first_name, last_name
- All encrypted using Rails 7 encryption: `encrypts_phi :email, :phone, :first_name, :last_name`

**Validation Standards:**
- Email: RFC 5322 compliant (Rails `URI::MailTo::EMAIL_REGEXP`)
- Phone: E.164 format (use `phonelib` gem: `Phonelib.parse(phone).valid?`)

### Project Structure Notes

**Files to Create:**
```
app/graphql/types/parent_type.rb
app/graphql/types/inputs/parent_input.rb
app/graphql/mutations/intake/submit_parent_info.rb
app/models/parent.rb
app/services/auth/token_service.rb
app/jobs/session_recovery_email_job.rb
db/migrate/TIMESTAMP_create_parents.rb
spec/models/parent_spec.rb
spec/graphql/mutations/intake/submit_parent_info_spec.rb
spec/services/ai/context_manager_spec.rb (update)
```

**Files to Modify:**
```
app/graphql/types/onboarding_session_type.rb (add parent field)
app/services/ai/context_manager.rb (add parent info extraction)
app/services/ai/prompts/intake_prompt.rb (add parent collection flow)
```

### AI Context Manager Integration

The AI service should:
1. Detect when conversation reaches parent info phase
2. Extract structured data from natural language:
   - "My name is Sarah Johnson" → firstName: Sarah, lastName: Johnson
   - "I'm her mother" → relationship: parent
   - "my email is sarah@example.com" → email: sarah@example.com
   - "you can reach me at 555-123-4567" → phone: +15551234567 (normalize to E.164)
3. Track collected fields in context
4. Prompt for missing required fields
5. Present confirmation with all collected data
6. Wait for explicit "yes" or "that's correct" before calling mutation

### Relationship Enum Values

```ruby
enum relationship: {
  parent: 0,
  guardian: 1,
  grandparent: 2,
  foster_parent: 3,
  other: 4
}
```

### Phone Normalization

Use `phonelib` gem for parsing and validation:
```ruby
# Example usage
parsed = Phonelib.parse(phone, 'US') # default country: US
parsed.valid? # => true/false
parsed.e164 # => "+15551234567"
```

### Session Recovery Email

Email template (Story 6.1 will implement full sending):
- Subject: "Continue your Daybreak onboarding"
- Body: "Hi [firstName], you can continue where you left off: [magic link]"
- Magic link valid for 15 minutes
- Token stored in Redis: `session_recovery:#{session_id}` → token

### Security Considerations

- Never log actual PHI values (names, email, phone) - only log flags like `has_email: true`
- Audit log should capture action but NOT PHI content
- All PHI fields must be encrypted before `save` is called
- Magic link tokens must be cryptographically secure (use `SecureRandom.urlsafe_base64(32)`)

### Testing Standards

**From Architecture:**
- Use RSpec for all tests
- Model specs: validations, associations, encryption
- Mutation specs: authorization, input validation, success/error cases
- Integration specs: end-to-end flows with AI context manager

**Coverage Requirements:**
- All acceptance criteria must have corresponding test
- Test both happy path and error cases
- Verify encryption: save, reload, check DB has encrypted value
- Test edge cases: malformed email, international phone numbers

### References

- [Source: docs/epics.md#Story-3.6]
- [Source: docs/architecture.md#Data-Architecture]
- [Source: docs/architecture.md#Security-Architecture]
- [Source: docs/architecture.md#Implementation-Patterns]
- [Source: docs/epics.md#FR13-FR14] (Parent contact collection, relationship/guardian status)

## Dev Agent Record

### Context Reference

- docs/sprint-artifacts/3-6-parent-information-collection.context.xml

### Agent Model Used

<!-- Will be populated during dev-story execution -->

### Debug Log References

<!-- Will be populated during dev-story execution -->

### Completion Notes List

<!-- Will be populated during dev-story execution -->

### File List

<!-- Will be populated during dev-story execution -->

## Senior Developer Review (AI)

**Reviewer:** Claude Code (Sonnet 4.5)
**Date:** 2025-11-29
**Review Type:** Comprehensive Code Review per BMM Workflow
**Outcome:** ❌ **BLOCKED** - Story implementation is incomplete and not ready for review

### Summary

This story was submitted for code review with status "drafted" instead of the expected "review" or "ready-for-review" status. Upon comprehensive validation against all 10 acceptance criteria and 9 task groups, the implementation is in **early foundational stage** with only **2 of 10 acceptance criteria** fully implemented (AC8: PHI encryption, AC9: Parent entity storage). The remaining **8 acceptance criteria** are missing implementation, representing approximately **75% incomplete work**.

**Positive Finding**: Task completion tracking is **100% accurate** - no tasks are falsely marked as complete. All checkboxes correctly reflect actual implementation state, demonstrating good project management hygiene.

**Critical Finding**: Story is in early implementation stage (foundation only), not ready for senior developer code review. Should remain in "drafted" or "in-progress" status until all tasks are completed and status updated to "review".

### Outcome Justification

**BLOCKED** due to:
1. **80% of acceptance criteria missing implementation** (8 of 10 ACs not implemented)
2. **No GraphQL API layer** (Tasks 1, 4 missing - zero GraphQL types or mutations exist)
3. **No AI integration** (Task 5 missing - AI context manager not implemented)
4. **No E.164 phone validation** (AC5 not met - using inadequate regex instead of phonelib gem)
5. **No confirmation flow** (AC7 missing - no user review/correction capability)
6. **No session recovery capability** (AC10 missing - no email job or token generation)
7. **Missing relationship enum** (Task 2 incomplete - string field instead of enum constraint)
8. **Story status incorrect** (status "drafted" indicates work in progress, not ready for review)

### Key Findings

#### HIGH Severity

- **[HIGH]** AC1: Parent data collection via GraphQL mutation not implemented
  - Missing: `app/graphql/types/parent_type.rb`
  - Missing: `app/graphql/types/inputs/parent_input.rb`
  - Missing: `app/graphql/mutations/intake/submit_parent_info.rb`

- **[HIGH]** AC5: Phone validation uses regex instead of E.164 standard via phonelib
  - Location: `app/models/parent.rb:14`
  - Current: `/\A\+?[\d\s\-\(\)]+\z/` (accepts invalid formats)
  - Required: Phonelib gem for proper E.164 validation per story spec
  - Impact: Could accept invalid international phone numbers, HIPAA compliance risk

- **[HIGH]** AC6: No AI context manager integration for natural language extraction
  - Missing: Updates to `app/services/ai/context_manager.rb`
  - Missing: Natural language parsing logic for parent fields
  - Missing: Integration with conversation flow

- **[HIGH]** AC7: No confirmation flow implementation
  - Missing: Confirmation step in AI prompt flow
  - Missing: Ability to review and correct information before saving

- **[HIGH]** AC10: Session recovery email capability not implemented
  - Missing: `app/services/auth/token_service.rb`
  - Missing: `app/jobs/session_recovery_email_job.rb`
  - Missing: Token generation and Redis storage logic

- **[HIGH]** Task 2: Parent model missing relationship enum definition
  - Location: `app/models/parent.rb`
  - Required per spec: `enum relationship: { parent: 0, guardian: 1, grandparent: 2, foster_parent: 3, other: 4 }`
  - Current: Plain string field with no enum constraints

#### MEDIUM Severity

- **[MEDIUM]** AC4: Email validation present but not explicitly tested for RFC 5322 edge cases
  - Location: `app/models/parent.rb:13`
  - Test coverage: Basic invalid email test exists
  - Recommendation: Add tests for edge cases (e.g., special chars, internationalized emails)

- **[MEDIUM]** Task 3: Phonelib gem not installed per story requirements
  - Required gem: `phonelib` for E.164 phone validation
  - Current: Gemfile does not include phonelib
  - Action required: Add `gem "phonelib"` to Gemfile

- **[MEDIUM]** Test coverage incomplete - only model tests exist
  - Present: `spec/models/parent_spec.rb` ✅
  - Missing: `spec/graphql/mutations/intake/submit_parent_info_spec.rb`
  - Missing: `spec/services/ai/context_manager_spec.rb` (update tests)
  - Missing: Integration tests for AI extraction flow

#### LOW Severity

- **[LOW]** Factory uses string 'mother' instead of enum value
  - Location: `spec/factories/parents.rb:10`
  - Once enum is added, this should use symbol: `relationship { :parent }`

### Acceptance Criteria Coverage

**Summary**: **2 of 10** acceptance criteria fully implemented, **1 partial**, **7 missing**

**Verification Method:** Direct code inspection of models, migrations, GraphQL layer, services, and jobs directories. Evidence links reference actual file locations and line numbers.

| AC# | Description | Status | Evidence / Gaps |
|-----|-------------|--------|------------------|
| 1 | Fields collected: firstName, lastName, email, phone | ❌ MISSING | No GraphQL mutation exists. Zero files in `app/graphql/mutations/intake/` |
| 2 | Relationship to child collected | ❌ MISSING | No GraphQL API, no AI extraction logic |
| 3 | Legal guardian status confirmed (boolean) | ❌ MISSING | No GraphQL API, no confirmation flow |
| 4 | Email validated (RFC 5322 format) | 🟡 PARTIAL | Model validation exists (`app/models/parent.rb:13`) but no end-to-end collection flow |
| 5 | Phone validated (E.164 format) | ❌ MISSING | Wrong validator: regex pattern at line 14 instead of phonelib gem |
| 6 | Data extracted from natural language | ❌ MISSING | No AI integration. `app/services/ai/` directory does not exist |
| 7 | Confirmation shown before saving | ❌ MISSING | No confirmation flow, no AI prompts |
| 8 | All PHI encrypted before storage | ✅ IMPLEMENTED | `encrypts_phi` at line 10, verified in tests (lines 37-71) |
| 9 | Data stored in Parent entity linked to session | ✅ IMPLEMENTED | Migration `20251129153420_create_parents.rb`, unique FK index |
| 10 | Session recovery email capability triggered | ❌ MISSING | No `SessionRecoveryEmailJob` in `app/jobs/` |

### Task Completion Validation

**Summary**: **0 of 9** tasks fully completed, **2 partially completed**, **0 falsely marked complete**

**✅ ACCURATE TASK MARKING**: All tasks correctly marked as incomplete. No false completions detected. This demonstrates excellent project tracking discipline.

**Verification Method:** Direct filesystem inspection and code analysis against story task requirements.

| Task | Marked Complete? | Actual Status | Evidence |
|------|------------------|---------------|----------|
| Task 1: GraphQL Type/Input | ☐ No | ✅ ACCURATE | `app/graphql/types/` has only 16 base files, no parent_type.rb or parent_input.rb |
| Task 2: Parent Model with Encryption | ☐ No | ⚠️ PARTIAL (30%) | Model exists at `app/models/parent.rb` with encryption, **but** missing relationship enum (required at line 43 of story) |
| Task 3: Validation Logic | ☐ No | ⚠️ PARTIAL (60%) | Email validation exists (RFC 5322), **but** phonelib gem not installed, E.164 validation missing |
| Task 4: SubmitParentInfo Mutation | ☐ No | ✅ ACCURATE | `app/graphql/mutations/` directory exists but no intake/ subfolder |
| Task 5: AI Context Manager Integration | ☐ No | ✅ ACCURATE | `app/services/ai/` directory does not exist |
| Task 6: Confirmation Flow | ☐ No | ✅ ACCURATE | No AI prompt files exist |
| Task 7: Session Recovery Email Trigger | ☐ No | ✅ ACCURATE | `app/jobs/` only has application_job.rb, no email job. Token service exists for different purpose (refresh tokens, not recovery) |
| Task 8: Update Session Progress | ☐ No | ✅ ACCURATE | No session update logic in mutations |
| Task 9: RSpec Tests | ☐ No | ⚠️ PARTIAL (33%) | Model tests excellent (`spec/models/parent_spec.rb`), mutation tests missing, AI tests missing |

**Files Implemented (4 new files, 1 existing concern):**
- ✅ `app/models/parent.rb` (20 lines) - Parent model with Encryptable concern, basic validations
- ✅ `db/migrate/20251129153420_create_parents.rb` (20 lines) - Database migration with UUID, encrypted text columns, unique FK
- ✅ `spec/models/parent_spec.rb` (88 lines) - Comprehensive model tests including PHI encryption verification via raw SQL
- ✅ `spec/factories/parents.rb` (14 lines) - FactoryBot test data factory
- ✅ `app/models/concerns/encryptable.rb` - Pre-existing concern (from Epic 1)

**Files Missing (per story specification lines 126-144):**
- ❌ `app/graphql/types/parent_type.rb` - GraphQL type definition with PHI field decryption
- ❌ `app/graphql/types/inputs/parent_input.rb` - GraphQL input type for mutation
- ❌ `app/graphql/mutations/intake/submit_parent_info.rb` - Main mutation for parent data submission
- ❌ `app/services/ai/context_manager.rb` - AI service for natural language extraction (update to existing)
- ❌ `app/services/auth/token_service.rb` - **EXISTS** but for refresh tokens (7 days), not session recovery (15 min). Needs separate recovery token logic.
- ❌ `app/jobs/session_recovery_email_job.rb` - Background job for magic link emails
- ❌ `spec/graphql/mutations/intake/submit_parent_info_spec.rb` - Mutation tests
- ❌ Updates to `app/graphql/types/onboarding_session_type.rb` (add parent field)
- ❌ Updates to `app/services/ai/prompts/intake_prompt.rb` (add parent collection flow)

### Test Coverage and Gaps

**Implemented Tests:**
- ✅ Model associations (`spec/models/parent_spec.rb:6-8`)
- ✅ Model validations - presence checks (`spec/models/parent_spec.rb:10-16`)
- ✅ Email format validation (`spec/models/parent_spec.rb:18-22`)
- ✅ Phone format validation (`spec/models/parent_spec.rb:24-28`)
- ✅ Boolean validation for is_guardian (`spec/models/parent_spec.rb:30-34`)
- ✅ PHI encryption verification (`spec/models/parent_spec.rb:37-71`)
- ✅ UUID primary key generation (`spec/models/parent_spec.rb:73-77`)
- ✅ Timestamp generation (`spec/models/parent_spec.rb:80-86`)

**Test Quality**: Model tests are well-structured and comprehensive for the model layer, including critical PHI encryption verification that reads raw database values to ensure encryption is working.

**Missing Test Coverage:**
- ❌ GraphQL mutation tests (no mutation exists yet)
- ❌ AI context manager integration tests
- ❌ Natural language extraction accuracy tests
- ❌ Confirmation flow tests
- ❌ Session recovery token generation tests
- ❌ E.164 phone validation tests (once phonelib added)
- ❌ International phone number format tests

### Architectural Alignment

**✅ Compliant Areas:**
- **PHI Encryption**: Correctly uses `Encryptable` concern with `encrypts_phi` macro per architecture spec
- **Model Structure**: Follows Rails Active Record conventions
- **UUID Primary Keys**: Migration correctly uses `id: :uuid` as required
- **Foreign Keys**: Proper relationship to `onboarding_session` with unique index
- **Testing Framework**: Uses RSpec as specified in architecture
- **Timestamps**: Includes `created_at` and `updated_at` as required

**❌ Non-Compliant Areas:**
- **Validation Library**: Story specifies phonelib gem for E.164 validation, but model uses custom regex
  - Story spec (line 48): "Install and configure `phonelib` gem for E.164 phone validation"
  - Current implementation: Uses regex `/\A\+?[\d\s\-\(\)]+\z/` which is insufficient

- **Enum Definition**: Story specifies relationship enum with specific values, missing in model
  - Story spec (lines 161-170): Explicit enum values required
  - Current: Plain string field with no constraints

- **GraphQL Structure**: No GraphQL types/mutations follow the documented structure in architecture
  - Expected location: `app/graphql/types/parent_type.rb`
  - Expected location: `app/graphql/mutations/intake/submit_parent_info.rb`
  - Expected pattern: Field-level resolver for PHI field decryption

### Security Notes

**✅ Security Strengths:**
- **PHI Encryption at Rest**: All sensitive fields (email, phone, first_name, last_name) properly encrypted using Rails 7 encryption with non-deterministic mode
- **Encryption Testing**: Tests verify encryption by reading raw database values - excellent security practice
- **No PHI Logging**: Factory and model don't appear to log PHI values

**⚠️ Security Concerns:**
- **Phone Validation Weakness**: Current regex accepts malformed phone numbers
  - Example: "+1 555-1234" (too short) would pass validation
  - Example: "++1234567890" (double plus) might pass validation
  - Impact: Could store invalid contact information, affecting care coordination
  - Risk Level: MEDIUM (functional issue, not direct security vulnerability)

- **Missing Input Sanitization**: No GraphQL mutation exists yet to validate sanitization of user input
  - Recommendation: When implementing mutation, ensure all inputs are sanitized
  - Watch for: SQL injection (Active Record handles this), XSS in stored data

### Best Practices and References

**Ruby on Rails 7 Best Practices:**
- ✅ Using Rails 7 built-in encryption for PHI (no third-party gems needed)
  - Reference: [Rails Encryption Guide](https://guides.rubyonrails.org/active_record_encryption.html)
- ✅ Concerns pattern for reusable model behavior (`Encryptable`)
  - Reference: [Rails Concerns](https://api.rubyonrails.org/classes/ActiveSupport/Concern.html)

**GraphQL Ruby Best Practices:**
- 📚 Use field-level resolvers for automatic PHI decryption in GraphQL types
  - Reference: [graphql-ruby Field Extensions](https://graphql-ruby.org/fields/field_extensions.html)
- 📚 Input object validation patterns for mutations
  - Reference: [graphql-ruby Mutations Guide](https://graphql-ruby.org/mutations/mutation_root.html)

**Phone Number Validation:**
- 📚 **Phonelib gem** (required per story spec)
  - GitHub: https://github.com/daddyz/phonelib
  - Usage: `Phonelib.parse(phone, 'US').valid?` and `.e164` for normalization
  - Version: Latest stable (7.1.x as of 2025)

**HIPAA Compliance:**
- ✅ Encryption at rest implemented correctly
- ⚠️ Need proper data validation to ensure contact accuracy for care coordination
- 📚 Reference: [HIPAA Technical Safeguards](https://www.hhs.gov/hipaa/for-professionals/security/laws-regulations/index.html)

### Action Items

#### Code Changes Required

- [ ] **[High]** Install and configure phonelib gem for E.164 phone validation (AC #5) [file: Gemfile]
  - Add `gem "phonelib"` to Gemfile
  - Run `bundle install`
  - Update validation in Parent model

- [ ] **[High]** Implement proper E.164 phone validation in Parent model (AC #5) [file: app/models/parent.rb:14]
  - Replace regex with: `validate :phone_must_be_valid_e164`
  - Add custom validator method using `Phonelib.parse(phone).valid?`
  - See story Dev Notes lines 173-180 for implementation example

- [ ] **[High]** Add relationship enum to Parent model (Task #2) [file: app/models/parent.rb]
  - Add after associations: `enum relationship: { parent: 0, guardian: 1, grandparent: 2, foster_parent: 3, other: 4 }`
  - Update migration if not yet run, or add migration to convert string to integer enum

- [ ] **[High]** Create ParentType GraphQL type (Task #1, AC #1) [file: app/graphql/types/parent_type.rb]
  - Define fields: id, firstName, lastName, email, phone, relationship, isGuardian
  - Implement field-level resolver to decrypt PHI fields transparently
  - Add parent field to OnboardingSessionType

- [ ] **[High]** Create ParentInput input type (Task #1) [file: app/graphql/types/inputs/parent_input.rb]
  - Accept all required fields from AC #1-3

- [ ] **[High]** Create SubmitParentInfo mutation (Task #4, AC #1-7, #9) [file: app/graphql/mutations/intake/submit_parent_info.rb]
  - Accept ParentInput argument
  - Validate email and phone formats before saving
  - Extract and normalize phone to E.164
  - Create or update Parent record
  - Trigger audit log: PARENT_INFO_SUBMITTED

- [ ] **[High]** Implement AI context manager integration (Task #5, AC #6) [file: app/services/ai/context_manager.rb]
  - Add parent info phase tracking
  - Implement natural language extraction for name, email, phone, relationship
  - Handle variations like "I'm her mom" → relationship: parent

- [ ] **[High]** Implement confirmation flow (Task #6, AC #7) [file: app/services/ai/prompts/intake_prompt.rb]
  - Add confirmation step presenting collected info
  - Allow corrections before calling mutation
  - Only submit after explicit confirmation

- [ ] **[High]** Create session recovery token service (Task #7, AC #10) [file: app/services/auth/token_service.rb]
  - Generate cryptographically secure 32-byte token
  - Store in Redis with 15-minute TTL
  - Key format: `session_recovery:#{session_id}`

- [ ] **[High]** Create SessionRecoveryEmailJob (Task #7) [file: app/jobs/session_recovery_email_job.rb]
  - Queue when parent email is saved
  - Email with magic link: `/onboarding/recover?token=...`
  - Note: Full email sending in Story 6.1

- [ ] **[High]** Implement session progress update (Task #8) [file: app/graphql/mutations/intake/submit_parent_info.rb]
  - Add `parentInfoCollected: true` to session.progress JSON
  - Update session.updatedAt
  - Extend session.expiresAt by 1 hour
  - Trigger sessionUpdated subscription

- [ ] **[Medium]** Add mutation tests (Task #9) [file: spec/graphql/mutations/intake/submit_parent_info_spec.rb]
  - Test success case with valid data
  - Test validation failures (invalid email, invalid phone)
  - Test audit log creation

- [ ] **[Medium]** Add AI integration tests (Task #9) [file: spec/services/ai/context_manager_spec.rb]
  - Test natural language extraction accuracy
  - Test confirmation flow requires approval

- [ ] **[Medium]** Update factory to use enum symbol (Low priority) [file: spec/factories/parents.rb:10]
  - Change `relationship { 'mother' }` to `relationship { :parent }`
  - Do this after enum is added to model

#### Advisory Notes

- Note: Story status should be "drafted" or "in-progress", not submitted for "review" until all tasks complete
- Note: Consider edge case testing for international phone numbers once phonelib integrated
- Note: Ensure OnboardingSession model exists and has proper associations before GraphQL implementation
- Note: Session recovery email (AC #10) noted as "Story 6.1 will implement full sending" - verify if placeholder is acceptable for this story
- Note: All GraphQL work depends on having OnboardingSessionType already defined from earlier stories
- Note: The model-level work (Task 2-3 partially) is solid foundation - encryption tests are exemplary

### Recommendation

**DECISION: DO NOT MERGE** - Story is in early foundational stage (~20-25% complete).

**STORY STATUS ACTION REQUIRED:**
- Current status: "drafted" ✅ CORRECT - accurately reflects incomplete state
- Do NOT change to "review" until all tasks complete
- Expected progression: drafted → in-progress → review → done

**IMPLEMENTATION ROADMAP (Priority Order):**

**Phase 1: Complete Foundation (1-2 hours)**
1. Install phonelib gem: Add to Gemfile, run `bundle install`
2. Update Parent model phone validation to use Phonelib.parse().valid? and .e164
3. Add relationship enum to Parent model (lines 162-170 of story spec)
4. Update factory to use enum symbol (`:parent` instead of `'mother'`)
5. Add E.164 phone validation tests

**Phase 2: Build GraphQL API Layer (2-3 hours)**
6. Create `app/graphql/types/parent_type.rb` with field-level PHI decryption
7. Create `app/graphql/types/inputs/parent_input.rb`
8. Update `app/graphql/types/onboarding_session_type.rb` (add parent field)
9. Create `app/graphql/mutations/intake/submit_parent_info.rb` with validation, normalization, audit logging
10. Write comprehensive mutation tests in `spec/graphql/mutations/intake/submit_parent_info_spec.rb`

**Phase 3: AI Integration & Flow (2-3 hours)**
11. Create `app/services/ai/` directory structure
12. Implement `context_manager.rb` with parent info extraction logic
13. Create `prompts/intake_prompt.rb` with parent collection conversation flow
14. Add confirmation flow to AI prompts
15. Write AI integration tests

**Phase 4: Session Recovery & Completion (1-2 hours)**
16. Extend `Auth::TokenService` with session recovery token generation (15-min TTL, separate from 7-day refresh tokens)
17. Create `SessionRecoveryEmailJob` in `app/jobs/`
18. Implement session progress update logic in mutation
19. Add subscription trigger for `sessionUpdated`

**TOTAL ESTIMATED EFFORT:** 6-10 hours of focused development

**QUALITY GATES BEFORE "REVIEW" STATUS:**
- ✅ All 9 task checkboxes marked complete
- ✅ All 10 acceptance criteria verifiable through tests
- ✅ RSpec suite passes with new tests
- ✅ No RuboCop violations in new code
- ✅ GraphQL schema introspection includes new types/mutations
- ✅ Manual smoke test: Create session → Submit parent info via GraphQL → Verify encryption → Trigger recovery email

**BLOCKERS/DEPENDENCIES:**
- None identified - all prerequisites from Epic 2 appear to be in place
- OnboardingSession model must exist (verify before starting Phase 2)

---

**Review Completed:** 2025-11-29 by Claude Code (Sonnet 4.5)
**Review Type:** Comprehensive BMM Code Review Workflow
**Files Analyzed:** 4 implementation files, 1 migration, 19 GraphQL base files, Gemfile, directory structure
**Acceptance Criteria Verified:** 10/10 individually validated
**Tasks Verified:** 9/9 individually validated
**Architecture Alignment:** Cross-referenced with `/docs/architecture.md` and `/docs/epics.md` Epic 3

**Next Action:** Continue implementation per roadmap above. Re-submit for review when status changes to "review" and all tasks marked complete.
