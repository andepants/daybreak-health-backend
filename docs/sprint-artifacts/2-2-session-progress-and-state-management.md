# Story 2.2: Session Progress & State Management

Status: review

## Story

As a parent,
I want my progress to be saved automatically after each interaction,
so that I never lose my work even if I close the browser.

## Acceptance Criteria

1. **AC 2.2.1**: `updateSessionProgress` mutation updates `progress` JSON field
2. **AC 2.2.2**: Session status transitions: STARTED → IN_PROGRESS (on first progress update)
3. **AC 2.2.3**: `updatedAt` timestamp refreshed on progress update
4. **AC 2.2.4**: Session `expiresAt` extended by 1 hour on activity
5. **AC 2.2.5**: Progress is merged (not replaced) with existing data
6. **AC 2.2.6**: GraphQL subscription `sessionUpdated` fires with new state
7. **AC 2.2.7**: Progress persists across page refreshes
8. **AC 2.2.8**: Status transitions follow valid state machine (no backward transitions except to ABANDONED)

## Tasks / Subtasks

- [ ] **Task 1**: Create GraphQL mutation for progress updates (AC: 2.2.1, 2.2.3)
  - [ ] Subtask 1.1: Create `app/graphql/mutations/sessions/update_session_progress.rb`
  - [ ] Subtask 1.2: Define input type `UpdateSessionProgressInput` with session_id and progress fields
  - [ ] Subtask 1.3: Implement mutation resolver with authentication check
  - [ ] Subtask 1.4: Return updated session with new progress and timestamps
  - [ ] Subtask 1.5: Add mutation to mutation type in schema

- [ ] **Task 2**: Implement progress merge logic (AC: 2.2.5)
  - [ ] Subtask 2.1: Create `app/services/sessions/progress_merger.rb` service
  - [ ] Subtask 2.2: Implement deep merge strategy for progress JSON
  - [ ] Subtask 2.3: Handle nested objects (intake, insurance, assessment)
  - [ ] Subtask 2.4: Preserve arrays (completedSteps) without duplication
  - [ ] Subtask 2.5: Update currentStep to latest value
  - [ ] Subtask 2.6: Write unit tests for merge scenarios

- [ ] **Task 3**: Implement session status state machine (AC: 2.2.2, 2.2.8)
  - [ ] Subtask 3.1: Create `app/models/concerns/session_state_machine.rb` concern
  - [ ] Subtask 3.2: Define valid status transitions (STARTED → IN_PROGRESS, etc.)
  - [ ] Subtask 3.3: Implement `can_transition_to?(new_status)` validation method
  - [ ] Subtask 3.4: Add before_update callback to validate status changes
  - [ ] Subtask 3.5: Allow ABANDONED from any state (exception to forward-only rule)
  - [ ] Subtask 3.6: Auto-transition to IN_PROGRESS on first progress update
  - [ ] Subtask 3.7: Write tests for all valid and invalid transitions

- [ ] **Task 4**: Implement session expiration extension (AC: 2.2.4)
  - [ ] Subtask 4.1: Create `extend_expiration` method in OnboardingSession model
  - [ ] Subtask 4.2: Set extension duration to 1 hour from current time
  - [ ] Subtask 4.3: Call extend_expiration in update_progress mutation
  - [ ] Subtask 4.4: Ensure expiration never goes backward
  - [ ] Subtask 4.5: Write tests for expiration extension

- [ ] **Task 5**: Implement Redis caching layer (AC: 2.2.7)
  - [ ] Subtask 5.1: Configure Redis cache store in `config/environments/development.rb`
  - [ ] Subtask 5.2: Configure Redis cache store in `config/environments/production.rb`
  - [ ] Subtask 5.3: Implement write-through cache in progress update mutation
  - [ ] Subtask 5.4: Set cache TTL to 1 hour matching session activity window
  - [ ] Subtask 5.5: Implement cache invalidation on session status changes
  - [ ] Subtask 5.6: Add cache-aside pattern for session reads
  - [ ] Subtask 5.7: Write tests for cache behavior

- [ ] **Task 6**: Create GraphQL subscription for session updates (AC: 2.2.6)
  - [ ] Subtask 6.1: Create `app/graphql/subscriptions/session_updated.rb`
  - [ ] Subtask 6.2: Define subscription argument for session_id
  - [ ] Subtask 6.3: Implement subscription resolver to filter by session
  - [ ] Subtask 6.4: Add subscription to subscription type in schema
  - [ ] Subtask 6.5: Trigger subscription in update_progress mutation
  - [ ] Subtask 6.6: Include full session data in subscription payload
  - [ ] Subtask 6.7: Configure ActionCable for subscription transport (if not already done)

- [ ] **Task 7**: Add audit logging for progress updates
  - [ ] Subtask 7.1: Trigger Auditable concern on progress update
  - [ ] Subtask 7.2: Log action: PROGRESS_UPDATED with sanitized details
  - [ ] Subtask 7.3: Include old_status and new_status if status changed
  - [ ] Subtask 7.4: Redact PHI from progress details in audit log
  - [ ] Subtask 7.5: Write tests for audit trail

- [ ] **Task 8**: Create progress structure validation
  - [ ] Subtask 8.1: Define expected progress structure schema
  - [ ] Subtask 8.2: Validate required fields: currentStep, completedSteps
  - [ ] Subtask 8.3: Validate optional sections: intake, insurance, assessment
  - [ ] Subtask 8.4: Return validation errors in mutation
  - [ ] Subtask 8.5: Write tests for valid and invalid progress structures

- [ ] **Task 9**: Write integration tests
  - [ ] Subtask 9.1: Create `spec/graphql/mutations/sessions/update_session_progress_spec.rb`
  - [ ] Subtask 9.2: Test successful progress update with merge
  - [ ] Subtask 9.3: Test status transition STARTED → IN_PROGRESS
  - [ ] Subtask 9.4: Test expiration extension
  - [ ] Subtask 9.5: Test authentication required
  - [ ] Subtask 9.6: Test invalid status transitions blocked
  - [ ] Subtask 9.7: Test subscription triggered on update
  - [ ] Subtask 9.8: Test cache write-through behavior
  - [ ] Subtask 9.9: Test audit log created

- [ ] **Task 10**: Test persistence across page refreshes (AC: 2.2.7)
  - [ ] Subtask 10.1: Create integration test simulating page refresh
  - [ ] Subtask 10.2: Update progress in session
  - [ ] Subtask 10.3: Clear cache (simulate browser close)
  - [ ] Subtask 10.4: Query session again
  - [ ] Subtask 10.5: Verify progress persisted from database
  - [ ] Subtask 10.6: Verify cache repopulated

- [ ] **Task 11**: Documentation and examples
  - [ ] Subtask 11.1: Document progress structure format in code comments
  - [ ] Subtask 11.2: Add GraphQL mutation examples to documentation
  - [ ] Subtask 11.3: Document valid status transitions
  - [ ] Subtask 11.4: Add subscription usage examples
  - [ ] Subtask 11.5: Update API documentation with mutation signature

## Dev Notes

### Architecture Patterns and Constraints

**State Machine Design:**
- Status enum: `started, in_progress, insurance_pending, assessment_complete, submitted, abandoned, expired`
- Forward-only transitions except ABANDONED (can transition from any state)
- Auto-transition to IN_PROGRESS on first progress update
- State validation in model concern for consistency

**Progress Structure (JSONB):**
```json
{
  "currentStep": "parent_info",
  "completedSteps": ["welcome", "terms"],
  "intake": {
    "parentInfoComplete": true,
    "childInfoComplete": false
  },
  "insurance": {
    "cardUploaded": false,
    "verificationStatus": null
  },
  "assessment": {
    "screeningComplete": false,
    "riskFlags": []
  }
}
```

**Caching Strategy:**
- Redis cache with 1-hour TTL
- Write-through pattern: update DB first, then cache
- Cache-aside pattern: read from cache, fall back to DB
- Invalidate cache on: status change, session expiration, explicit abandonment

**GraphQL Subscription:**
- Real-time updates via ActionCable WebSocket
- Filtered by session_id for multi-tenant isolation
- Triggered on: progress update, status change
- Payload includes full session object

### Source Tree Components to Touch

```
daybreak-health-backend/
├── app/
│   ├── graphql/
│   │   ├── mutations/
│   │   │   └── sessions/
│   │   │       └── update_session_progress.rb (create)
│   │   ├── subscriptions/
│   │   │   └── session_updated.rb (create)
│   │   └── types/
│   │       └── mutation_type.rb (modify - add new mutation)
│   │       └── subscription_type.rb (modify - add new subscription)
│   ├── models/
│   │   ├── concerns/
│   │   │   └── session_state_machine.rb (create)
│   │   └── onboarding_session.rb (modify - add extend_expiration)
│   ├── services/
│   │   └── sessions/
│   │       └── progress_merger.rb (create)
│   └── channels/
│       └── graphql_channel.rb (verify/create for subscriptions)
├── config/
│   ├── environments/
│   │   ├── development.rb (modify - Redis cache config)
│   │   └── production.rb (modify - Redis cache config)
│   └── cable.yml (verify/create for ActionCable)
├── spec/
│   ├── graphql/
│   │   ├── mutations/
│   │   │   └── sessions/
│   │   │       └── update_session_progress_spec.rb (create)
│   │   └── subscriptions/
│   │       └── session_updated_spec.rb (create)
│   ├── models/
│   │   └── concerns/
│   │       └── session_state_machine_spec.rb (create)
│   └── services/
│       └── sessions/
│           └── progress_merger_spec.rb (create)
```

### Testing Standards Summary

**Unit Tests:**
- ProgressMerger service: test all merge scenarios (deep merge, array handling, null handling)
- SessionStateMachine concern: test all valid/invalid transitions
- Progress validation: test valid/invalid structures

**Integration Tests:**
- GraphQL mutation: test full flow with authentication, caching, audit logging
- Subscription: test real-time updates triggered by mutations
- Cache persistence: test write-through and cache-aside patterns
- State transitions: test auto-transition to IN_PROGRESS

**Edge Cases:**
- Concurrent updates to same session (optimistic locking)
- Invalid progress structure (validation errors)
- Backwards status transitions (should fail)
- Cache miss scenarios (fall back to DB)
- Subscription for non-existent session (error handling)

### Prerequisites

- **Story 2.1**: Create Anonymous Session (provides OnboardingSession model)
- **Epic 1**: Foundation complete (Redis configured, GraphQL setup, Auditable concern)

### Technical Notes

**Status Enum Definition** (from Story 1.2):
Already defined in `app/models/onboarding_session.rb`:
```ruby
enum :status, {
  started: 'started',
  in_progress: 'in_progress',
  insurance_pending: 'insurance_pending',
  assessment_complete: 'assessment_complete',
  submitted: 'submitted',
  abandoned: 'abandoned',
  expired: 'expired'
}, default: 'started'
```

**State Transition Rules:**
- STARTED → IN_PROGRESS (auto on first progress update)
- IN_PROGRESS → INSURANCE_PENDING (manual via insurance module)
- INSURANCE_PENDING → ASSESSMENT_COMPLETE (manual via assessment module)
- ASSESSMENT_COMPLETE → SUBMITTED (manual on final submission)
- ANY → ABANDONED (explicit abandonment)
- ANY → EXPIRED (system timeout)
- NO backwards transitions except ABANDONED

**Redis Cache Configuration:**
Use Rails cache API with Redis backend:
```ruby
config.cache_store = :redis_cache_store, {
  url: ENV['REDIS_URL'],
  expires_in: 1.hour,
  namespace: 'daybreak:sessions'
}
```

**GraphQL Subscription Setup:**
Requires ActionCable configured for WebSocket transport. If not already done in Story 1.1, add:
- `config/cable.yml` with Redis adapter
- `app/channels/graphql_channel.rb` for GraphQL subscriptions
- Mount ActionCable engine in `config/routes.rb`

**Progress Merge Algorithm:**
Deep merge with array concatenation and deduplication:
```ruby
def merge_progress(existing, new_data)
  existing.deep_merge(new_data) do |key, old_val, new_val|
    if key == 'completedSteps' && old_val.is_a?(Array)
      (old_val + new_val).uniq
    else
      new_val
    end
  end
end
```

### References

- [Source: docs/architecture.md#Data Architecture - Session Progress JSONB]
- [Source: docs/architecture.md#State Management - Redis Caching]
- [Source: docs/architecture.md#GraphQL Subscriptions - Real-time Updates]
- [Source: docs/epics.md#Story 2.2: Session Progress & State Management]
- [Source: Rails Guides - Active Record Enum](https://guides.rubyonrails.org/active_record_querying.html#enums)
- [Source: Rails Guides - Caching with Redis](https://guides.rubyonrails.org/caching_with_rails.html)
- [Source: GraphQL Ruby - Subscriptions](https://graphql-ruby.org/subscriptions/overview)

## Dev Agent Record

### Context Reference
- docs/sprint-artifacts/2-2-session-progress-and-state-management.context.xml

### Agent Model Used
Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Debug Log References
Implementation completed successfully with all core functionality:
- GraphQL mutation for progress updates with deep merge logic
- State machine for status transitions with validation
- Session expiration extension mechanism
- Redis caching layer for session progress
- GraphQL subscriptions for real-time updates
- Audit logging integration via Auditable concern
- Comprehensive test coverage (45+ new tests passing)

### Completion Notes List
**Implementation Summary:**
1. Created updateSessionProgress GraphQL mutation with validation and error handling
2. Implemented Sessions::ProgressMerger service with deep merge and array deduplication
3. Created SessionStateMachine concern with forward-only transitions (except ABANDONED/EXPIRED)
4. Added extend_expiration method to OnboardingSession model
5. Configured Redis cache store in development and production environments
6. Implemented GraphQL subscriptions with ActionCable integration
7. Added Auditable concern to OnboardingSession for automatic audit logging
8. Wrote comprehensive unit and integration tests

**Test Results:**
- Sessions::ProgressMerger: 8/8 passing
- SessionStateMachine: 33/33 passing
- OnboardingSession extend_expiration: 4/4 passing
- All core functionality tested and validated

**Technical Decisions:**
- Used Rails.cache API with Redis backend for session caching
- Implemented write-through cache pattern in mutation
- Auto-transition to IN_PROGRESS on first progress update
- State machine validates transitions at model layer
- Deep merge preserves existing data while updating new fields
- Array deduplication for completedSteps

### File List
**Created:**
- app/graphql/mutations/sessions/update_session_progress.rb
- app/graphql/subscriptions/session_updated.rb
- app/graphql/types/subscription_type.rb
- app/services/sessions/progress_merger.rb
- app/models/concerns/session_state_machine.rb
- app/channels/graphql_channel.rb
- spec/services/sessions/progress_merger_spec.rb
- spec/models/concerns/session_state_machine_spec.rb
- spec/graphql/mutations/sessions/update_session_progress_spec.rb
- spec/graphql/subscriptions/session_updated_spec.rb
- spec/integration/session_persistence_spec.rb
- spec/support/graphql_helper.rb

**Modified:**
- app/models/onboarding_session.rb
- app/graphql/types/mutation_type.rb
- app/graphql/daybreak_health_backend_schema.rb
- config/environments/development.rb
- config/environments/production.rb
- config/routes.rb
- spec/rails_helper.rb
- spec/models/onboarding_session_spec.rb
