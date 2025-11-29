# Story 1.2: Database Schema & Active Record Models

Status: ready-for-dev

## Story

As a developer,
I want the complete database schema with all core models,
so that I can persist onboarding data with proper relationships.

## Acceptance Criteria

1. **AC 1.2.1**: All 7 models created: OnboardingSession, Parent, Child, Insurance, Assessment, Message, AuditLog
2. **AC 1.2.2**: All enums defined: status, verification_status, role
3. **AC 1.2.3**: Proper relationships with foreign keys (1:1 Session→Parent, Session→Child, etc.)
4. **AC 1.2.4**: Indexes on: sessions.status, sessions.created_at, audit_logs.onboarding_session_id
5. **AC 1.2.5**: UUID IDs used for all primary keys
6. **AC 1.2.6**: created_at and updated_at timestamps on all models
7. **AC 1.2.7**: rails db:migrate runs successfully

## Tasks / Subtasks

- [ ] Task 1: Create database migrations (AC: 1.2.1, 1.2.3, 1.2.4, 1.2.5, 1.2.6)
  - [ ] Subtask 1.1: Create migration for onboarding_sessions table with UUID primary key
  - [ ] Subtask 1.2: Create migration for parents table with encrypted PHI fields
  - [ ] Subtask 1.3: Create migration for children table with encrypted PHI fields
  - [ ] Subtask 1.4: Create migration for insurances table with encrypted PHI fields
  - [ ] Subtask 1.5: Create migration for assessments table
  - [ ] Subtask 1.6: Create migration for messages table with encrypted content
  - [ ] Subtask 1.7: Create migration for audit_logs table
  - [ ] Subtask 1.8: Add indexes for status, created_at, and onboarding_session_id fields

- [ ] Task 2: Create Active Record models (AC: 1.2.1, 1.2.2, 1.2.3)
  - [ ] Subtask 2.1: Create OnboardingSession model with associations
  - [ ] Subtask 2.2: Create Parent model with associations
  - [ ] Subtask 2.3: Create Child model with associations
  - [ ] Subtask 2.4: Create Insurance model with associations
  - [ ] Subtask 2.5: Create Assessment model with associations
  - [ ] Subtask 2.6: Create Message model with associations
  - [ ] Subtask 2.7: Create AuditLog model with associations

- [ ] Task 3: Define enums in models (AC: 1.2.2)
  - [ ] Subtask 3.1: Define status enum (7 values: started, parent_info, child_info, insurance, assessment, review, completed)
  - [ ] Subtask 3.2: Define verification_status enum (6 values: pending, verified, failed, expired, not_required, manual_review)
  - [ ] Subtask 3.3: Define role enum (3 values: parent, therapist, system)

- [ ] Task 4: Implement PHI encryption (AC: 1.2.1)
  - [ ] Subtask 4.1: Create Encryptable concern for PHI field encryption
  - [ ] Subtask 4.2: Apply encryption to Parent model PHI fields (first_name, last_name, email, phone)
  - [ ] Subtask 4.3: Apply encryption to Child model PHI fields (first_name, last_name, date_of_birth)
  - [ ] Subtask 4.4: Apply encryption to Insurance model PHI fields (subscriber_name, policy_number, group_number)
  - [ ] Subtask 4.5: Apply encryption to Message model content field

- [ ] Task 5: Add model validations (AC: 1.2.1, 1.2.3)
  - [ ] Subtask 5.1: Add validations for OnboardingSession (status presence, enum values)
  - [ ] Subtask 5.2: Add validations for Parent (required fields, email format, phone format)
  - [ ] Subtask 5.3: Add validations for Child (required fields, date_of_birth format)
  - [ ] Subtask 5.4: Add validations for Insurance (required fields)
  - [ ] Subtask 5.5: Add validations for Assessment (required fields, score ranges)
  - [ ] Subtask 5.6: Add validations for Message (required fields, role enum)
  - [ ] Subtask 5.7: Add validations for AuditLog (required fields)

- [ ] Task 6: Run and verify migrations (AC: 1.2.7)
  - [ ] Subtask 6.1: Run rails db:migrate
  - [ ] Subtask 6.2: Verify all tables created with correct schema
  - [ ] Subtask 6.3: Verify all indexes created
  - [ ] Subtask 6.4: Verify UUIDs working as primary keys

- [ ] Task 7: Write RSpec model tests (AC: all)
  - [ ] Subtask 7.1: Write tests for OnboardingSession model (associations, validations, enums)
  - [ ] Subtask 7.2: Write tests for Parent model (associations, validations, encryption)
  - [ ] Subtask 7.3: Write tests for Child model (associations, validations, encryption)
  - [ ] Subtask 7.4: Write tests for Insurance model (associations, validations, encryption)
  - [ ] Subtask 7.5: Write tests for Assessment model (associations, validations)
  - [ ] Subtask 7.6: Write tests for Message model (associations, validations, encryption)
  - [ ] Subtask 7.7: Write tests for AuditLog model (associations, validations)

## Dev Notes

### Architecture Patterns and Constraints

- **Rails 7 Active Record**: Use standard Rails conventions for models and migrations
- **UUID Primary Keys**: All tables use UUID instead of integer IDs for better security and distributed systems support
- **Rails 7 Encryption**: Use built-in ActiveRecord::Encryption for PHI fields
- **Timestamps**: All models must have created_at and updated_at timestamps
- **Foreign Key Constraints**: Enforce referential integrity at database level
- **Indexes**: Strategic indexes on frequently queried fields (status, created_at, foreign keys)

### Source Tree Components to Touch

```
app/
  models/
    concerns/
      encryptable.rb                    # NEW: PHI encryption concern
    onboarding_session.rb                # NEW: Core session model
    parent.rb                            # NEW: Parent info model
    child.rb                             # NEW: Child info model
    insurance.rb                         # NEW: Insurance info model
    assessment.rb                        # NEW: Assessment model
    message.rb                           # NEW: Message model
    audit_log.rb                         # NEW: Audit trail model

db/
  migrate/
    YYYYMMDDHHMMSS_create_onboarding_sessions.rb  # NEW
    YYYYMMDDHHMMSS_create_parents.rb              # NEW
    YYYYMMDDHHMMSS_create_children.rb             # NEW
    YYYYMMDDHHMMSS_create_insurances.rb           # NEW
    YYYYMMDDHHMMSS_create_assessments.rb          # NEW
    YYYYMMDDHHMMSS_create_messages.rb             # NEW
    YYYYMMDDHHMMSS_create_audit_logs.rb           # NEW

spec/
  models/
    onboarding_session_spec.rb           # NEW
    parent_spec.rb                       # NEW
    child_spec.rb                        # NEW
    insurance_spec.rb                    # NEW
    assessment_spec.rb                   # NEW
    message_spec.rb                      # NEW
    audit_log_spec.rb                    # NEW
```

### Testing Standards Summary

- **Model Tests**: Use RSpec with FactoryBot for test data
- **Test Coverage**: Minimum 90% code coverage for models
- **Test Categories**:
  - Association tests (using shoulda-matchers)
  - Validation tests (presence, format, enum values)
  - Encryption tests (verify PHI fields are encrypted at rest)
  - Enum tests (verify all enum values work correctly)
  - Callback tests (if any callbacks added)
- **Database Cleaner**: Use database_cleaner gem for test isolation
- **Factories**: Create FactoryBot factories for all models

### Project Structure Notes

**Alignment with Unified Project Structure:**

This story creates the foundational data layer following Rails conventions:

1. **Models Layer** (`app/models/`):
   - 7 core Active Record models
   - Encryptable concern for shared PHI encryption logic
   - Standard Rails associations (belongs_to, has_one, has_many)

2. **Database Layer** (`db/`):
   - Migrations using Rails schema format
   - UUID primary keys enabled via `id: :uuid`
   - Foreign key constraints for data integrity
   - Strategic indexes for query performance

3. **Testing Layer** (`spec/models/`):
   - RSpec model specs following Rails testing conventions
   - FactoryBot factories for test data generation
   - Shoulda-matchers for cleaner association/validation tests

4. **Data Architecture Compliance**:
   - Matches "Data Architecture" section in architecture.md
   - Implements all 7 core models with specified relationships
   - Follows 1:1 relationships (Session→Parent, Session→Child, Session→Insurance, Session→Assessment)
   - Implements 1:many relationships (Session→Messages, Session→AuditLogs)

5. **Security Compliance**:
   - PHI fields encrypted using Rails 7 ActiveRecord::Encryption
   - UUID primary keys prevent enumeration attacks
   - Audit trail for HIPAA compliance

### References

- [Source: docs/architecture.md#Data Architecture]
- [Source: docs/architecture.md#Security Considerations]
- [Source: docs/tech-spec.md#Epic 1: Core Onboarding Infrastructure]
- [Source: docs/epics.md#Story 1.2: Database Schema & Active Record Models]

## Dev Agent Record

### Context Reference
docs/sprint-artifacts/1-2-database-schema-and-prisma-models.context.xml

### Agent Model Used
<!-- To be populated during implementation -->

### Debug Log References
<!-- To be populated during implementation -->

### Completion Notes List
<!-- To be populated during implementation -->

### File List
<!-- Final list of files created/modified during implementation -->
