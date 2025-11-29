# Story 3.1: Conversational AI Service Integration

**Status:** ready-for-dev

## Story

As a **parent**,
I want **to interact with an AI assistant that guides me through intake**,
So that **the process feels like a supportive conversation, not form-filling**.

## Requirements Context

**From Epic 3 - Conversational AI Intake (epics.md):**

This story implements FR7 (Conversational AI interface) from the PRD. It establishes the foundational AI service layer that enables natural language conversation between parents and the system during the onboarding intake process.

**Functional Requirements Covered:**
- **FR7:** System presents intake questions through conversational AI interface

**Key Architecture Constraints (from architecture.md):**
- Provider-agnostic AI client supporting OpenAI (primary) and Anthropic Claude (backup)
- Messages encrypted at rest using Rails 7 encryption (Encryptable concern)
- GraphQL subscriptions via Action Cable for real-time message streaming
- System prompts stored in `app/services/ai/prompts/`
- Context window: last 50 messages + session progress summary

## Acceptance Criteria

1. **Given** a session is active **When** the parent sends a message **Then** the `sendMessage` mutation accepts message content and stores it with role `USER` and timestamp

2. **Given** a message is received **When** AI processing completes **Then** AI service (OpenAI or Anthropic Claude) is called with conversation context and response is stored with role `ASSISTANT`

3. **Given** AI is responding **When** response is generated **Then** response is streamed via GraphQL subscription `messageReceived`

4. **Given** ongoing conversation **When** context is assembled **Then** conversation context is maintained across messages (up to 50 messages)

5. **Given** message content **When** stored in database **Then** all messages are encrypted at rest (PHI)

6. **Given** AI service call **When** measuring performance **Then** AI response time p95 < 2 seconds

7. **Given** AI provider rate limit **When** limit is reached **Then** exponential backoff with Sidekiq retries handles the situation gracefully

## Tasks / Subtasks

- [ ] **Task 1: Create AI Client Service with Provider Pattern** (AC: 2, 7)
  - [ ] Create `app/services/ai/client.rb` with provider selection logic
  - [ ] Create `app/services/ai/providers/base_provider.rb` interface
  - [ ] Create `app/services/ai/providers/anthropic_provider.rb` implementing base
  - [ ] Create `app/services/ai/providers/openai_provider.rb` implementing base
  - [ ] Add configuration in `config/initializers/ai_providers.rb`
  - [ ] Implement exponential backoff via Sidekiq retry for rate limits
  - [ ] Add RSpec tests for client and providers

- [ ] **Task 2: Create Message Model with Encryption** (AC: 1, 5)
  - [ ] Run migration `006_create_messages.rb` if not already applied
  - [ ] Implement `app/models/message.rb` with Encryptable concern
  - [ ] Add `role` enum: `user: 0, assistant: 1, system: 2`
  - [ ] Add `belongs_to :onboarding_session` association
  - [ ] Apply `encrypts_phi :content` for message content
  - [ ] Add model validations and RSpec tests

- [ ] **Task 3: Create SendMessage GraphQL Mutation** (AC: 1, 2, 4)
  - [ ] Create `app/graphql/mutations/conversation/send_message.rb`
  - [ ] Accept `sessionId` and `content` arguments
  - [ ] Store user message with timestamp
  - [ ] Call AI client with conversation context
  - [ ] Store assistant response
  - [ ] Return both messages in response
  - [ ] Add mutation integration tests

- [ ] **Task 4: Implement Context Assembly** (AC: 4)
  - [ ] Create `app/services/ai/context_manager.rb`
  - [ ] Load last 50 messages from session
  - [ ] Include session progress summary in context
  - [ ] Format messages for AI provider API
  - [ ] Add unit tests for context manager

- [ ] **Task 5: Create System Prompts** (AC: 2)
  - [ ] Create `app/services/ai/prompts/intake_prompt.rb`
  - [ ] Define system prompt for intake conversation
  - [ ] Include empathetic, supportive tone guidelines
  - [ ] Define conversation flow phases: Welcome, Parent Info, Child Info, Concerns
  - [ ] Make prompts configurable (preparatory for FR41)

- [ ] **Task 6: Create MessageReceived GraphQL Subscription** (AC: 3)
  - [ ] Create `app/graphql/subscriptions/message_received.rb`
  - [ ] Subscribe by `session_id` with authorization check
  - [ ] Trigger subscription when assistant message is created
  - [ ] Configure Action Cable channel for GraphQL subscriptions
  - [ ] Add subscription integration tests

- [ ] **Task 7: Create MessageType GraphQL Type** (AC: 1, 3)
  - [ ] Create `app/graphql/types/message_type.rb`
  - [ ] Define fields: `id`, `role`, `content`, `createdAt`, `metadata`
  - [ ] Add to OnboardingSessionType as `messages` connection

- [ ] **Task 8: Add Audit Logging** (AC: all)
  - [ ] Log MESSAGE_SENT action for user messages
  - [ ] Log AI_RESPONSE action for assistant messages
  - [ ] Include session_id, message_id in audit details
  - [ ] Never log actual message content (PHI)

- [ ] **Task 9: Performance Testing** (AC: 6)
  - [ ] Create benchmark tests for AI response time
  - [ ] Test with mock AI provider for consistent timing
  - [ ] Document baseline metrics
  - [ ] Set up monitoring hooks for p95 tracking

## Dev Notes

### Architecture Patterns

**AI Client Provider Pattern:**
```ruby
# app/services/ai/client.rb
class Ai::Client
  def initialize(provider: nil)
    @provider = provider || default_provider
  end

  def chat(messages:, context:)
    @provider.chat(messages: messages, context: context)
  end

  def stream(messages:, context:, &block)
    @provider.stream(messages: messages, context: context, &block)
  end
end
```

**Message Model:**
```ruby
# app/models/message.rb
class Message < ApplicationRecord
  include Encryptable
  include Auditable

  enum :role, { user: 0, assistant: 1, system: 2 }
  belongs_to :onboarding_session
  encrypts_phi :content
end
```

### Project Structure Notes

**Files to Create:**
- `app/services/ai/client.rb` - Main AI client service
- `app/services/ai/providers/base_provider.rb` - Provider interface
- `app/services/ai/providers/anthropic_provider.rb` - Anthropic implementation
- `app/services/ai/providers/openai_provider.rb` - OpenAI implementation
- `app/services/ai/context_manager.rb` - Conversation context assembly
- `app/services/ai/prompts/intake_prompt.rb` - System prompts
- `app/graphql/mutations/conversation/send_message.rb` - GraphQL mutation
- `app/graphql/subscriptions/message_received.rb` - GraphQL subscription
- `app/graphql/types/message_type.rb` - GraphQL type
- `config/initializers/ai_providers.rb` - AI configuration
- `spec/services/ai/client_spec.rb` - Client tests
- `spec/services/ai/providers/anthropic_provider_spec.rb` - Provider tests
- `spec/graphql/mutations/conversation/send_message_spec.rb` - Mutation tests
- `spec/graphql/subscriptions/message_received_spec.rb` - Subscription tests

**Files to Modify:**
- `app/models/onboarding_session.rb` - Add `has_many :messages`
- `app/graphql/types/onboarding_session_type.rb` - Add messages field
- `app/graphql/types/mutation_type.rb` - Register sendMessage mutation
- `app/graphql/types/subscription_type.rb` - Register messageReceived subscription

### Security Considerations

- All message content encrypted using Rails 7 encryption via Encryptable concern
- PHI-safe logging: never log actual message content, only metadata
- Authorization check in subscription to prevent cross-session access
- API keys stored in Rails credentials or environment variables

### Dependencies

- **Prerequisites:** Epic 2 complete (session management, auth)
- **Gems Required:**
  - `ruby-openai` - OpenAI Ruby SDK (primary)
  - `anthropic` - Anthropic Ruby SDK (backup)
- **Environment Variables:**
  - `AI_PROVIDER` - 'openai' (default) or 'anthropic' (backup)
  - `OPENAI_API_KEY` - OpenAI API key (primary)
  - `ANTHROPIC_API_KEY` - Anthropic API key (backup provider)

### References

- [Source: docs/epics.md#Story 3.1]
- [Source: docs/architecture.md#Service Pattern]
- [Source: docs/architecture.md#Real-Time: GraphQL Subscriptions]
- [Source: docs/architecture.md#ADR-002: Agnostic AI Provider]
- FR7: Conversational AI interface

## Dev Agent Record

### Context Reference

- docs/sprint-artifacts/3-1-conversational-ai-service-integration.context.xml

### Agent Model Used

<!-- To be filled by dev agent -->

### Debug Log References

<!-- To be filled during development -->

### Completion Notes List

<!-- To be filled during development -->

### File List

<!-- To be filled during development - format: NEW/MODIFIED/DELETED: path -->

## Senior Developer Review (AI)

**Reviewer:** Claude Code (Senior Developer Review Agent)
**Date:** 2025-11-29
**Review Type:** Pre-Implementation Story Definition & Architecture Alignment Review
**Outcome:** **APPROVED WITH OBSERVATIONS - Ready for Implementation**

### Executive Summary

This story is **well-defined and architecturally sound**, with clear acceptance criteria, comprehensive task breakdown, and excellent alignment with the architecture document. The story is currently in "drafted" status with foundational work already complete (Task 2: Message Model with Encryption).

**Overall Assessment: 9/10**
- ✅ **Completeness**: All Epic 3.1 requirements from epics.md fully captured
- ✅ **Technical Accuracy**: 100% aligned with architecture.md specifications
- ✅ **Task Breakdown**: Appropriately sized with clear dependencies
- ✅ **Testability**: All acceptance criteria are verifiable
- ⚠️ **Implementation Status**: Foundation complete (Message Model), remaining work clearly scoped

**Key Strength**: The Message model foundation (Task 2) has been implemented to exemplary standards - proper PHI encryption, comprehensive tests including database-level verification, and full alignment with architecture patterns.

### 1. Completeness Review (vs. Epic 3.1 Requirements)

**FR7 Coverage: Conversational AI Interface** ✅

Story fully addresses Epic 3.1 requirements from epics.md (lines 501-530):

| Epic Requirement | Story Coverage | Verification |
|-----------------|----------------|--------------|
| "sendMessage mutation accepts message content" | AC1, Task 3 | ✓ Explicitly defined |
| "Message stored with role USER and timestamp" | AC1, Task 2 | ✓ Model + mutation specified |
| "AI service (Anthropic Claude) called with conversation context" | AC2, Task 1 | ✓ Provider pattern specified |
| "AI response stored with role ASSISTANT" | AC2, Task 3 | ✓ Mutation behavior defined |
| "Response streamed via GraphQL subscription" | AC3, Task 6 | ✓ Subscription specified |
| "Conversation context maintained (up to 50 messages)" | AC4, Task 4 | ✓ Context manager specified |
| "Messages encrypted at rest (PHI)" | AC5, Task 2 | ✓ Implemented with Encryptable |
| "AI response time p95 < 2 seconds" | AC6, Task 9 | ✓ Performance testing included |
| "Handle rate limits with exponential backoff" | AC7, Task 1 | ✓ Sidekiq retries specified |

**Epic 3.1 Prerequisites** ✅
- Epic 2 complete (session management, auth): Properly noted in Dependencies section
- No missing dependencies or assumptions

**Scope Boundary** ✅
- Story correctly scoped to AI service integration only
- Does NOT overreach into adaptive flow (Story 3.2) or help handling (Story 3.3)
- Clean handoff points to subsequent stories

### 2. Technical Accuracy (Architecture Alignment)

**Score: 10/10** - Perfect alignment with architecture.md

#### AI Service Layer Architecture ✅

**Specified in Story** (lines 113-128):
```ruby
class Ai::Client
  def chat(messages:, context:)
    @provider.chat(messages: messages, context: context)
  end
end
```

**Matches Architecture** (architecture.md:236-263):
- Provider pattern with pluggable backends ✓
- Support for Anthropic and OpenAI ✓
- Configuration-driven provider selection ✓

**ADR-002 Compliance** ✓ (architecture.md:939-950):
- Agnostic AI provider pattern correctly applied
- Supports vendor flexibility and A/B testing

#### Message Model Architecture ✅

**Implemented Model** (app/models/message.rb):
```ruby
class Message < ApplicationRecord
  include Encryptable
  include Auditable

  enum :role, { user: 0, assistant: 1, system: 2 }
  belongs_to :onboarding_session
  encrypts_phi :content
end
```

**Architecture Specification** (architecture.md:566-574):
- Encryptable concern ✓
- Correct enum values ✓
- PHI encryption via encrypts_phi ✓
- Proper associations ✓

**Database Schema** (db/migrate/20251129153426_create_messages.rb):
- UUID primary key ✓ (architecture.md:476-491)
- References onboarding_session (type: :uuid, foreign_key) ✓
- Role as integer enum ✓
- Content as encrypted text ✓
- JSONB metadata ✓
- Composite index [onboarding_session_id, created_at] ✓

**Encryption Implementation** (ADR-003, architecture.md:952-962):
- Rails 7 built-in encryption ✓
- Encryptable concern pattern ✓
- No external dependencies ✓

#### GraphQL Layer Architecture ✅

**Story Specification**:
- SendMessage mutation (Task 3) → architecture.md:96-115
- MessageReceived subscription (Task 6) → architecture.md:673-722
- MessageType (Task 7) → architecture.md:83-91

**Action Cable Integration** (architecture.md:976-987, ADR-005):
- Built-in Rails WebSocket support ✓
- Redis backend for multi-server ✓
- JWT authentication for WebSocket connections ✓

#### Background Jobs Architecture ✅

**Story Specification** (Task 1):
- "Implement exponential backoff via Sidekiq retry for rate limits"

**Architecture Pattern** (architecture.md:640-666):
- Sidekiq for background processing ✓
- Exponential backoff with retry_on ✓
- Queue prioritization (critical, default, low) ✓

#### Security Architecture ✅

**PHI Encryption** (architecture.md:626-634):
- Message content encrypted at rest ✓
- Rails 7 encryption (AES-256-GCM) ✓
- Encryptable concern pattern ✓

**Authentication** (architecture.md:598-622):
- JWT validation for GraphQL operations ✓
- Session ownership verification required ✓

**Audit Logging** (Task 8):
- MESSAGE_SENT and AI_RESPONSE actions ✓
- PHI-safe logging (no content logged) ✓
- Session and message IDs tracked ✓

#### File Structure Compliance ✅

All specified files match architecture.md:67-198:

**Services** (architecture.md:130-150):
- ✓ app/services/ai/client.rb
- ✓ app/services/ai/providers/base_provider.rb
- ✓ app/services/ai/providers/anthropic_provider.rb
- ✓ app/services/ai/providers/openai_provider.rb
- ✓ app/services/ai/context_manager.rb
- ✓ app/services/ai/prompts/intake_prompt.rb

**GraphQL** (architecture.md:78-115):
- ✓ app/graphql/mutations/conversation/send_message.rb
- ✓ app/graphql/subscriptions/message_received.rb
- ✓ app/graphql/types/message_type.rb

**Models** (architecture.md:117-128):
- ✓ app/models/message.rb (already implemented)

**Configuration** (architecture.md:169-176):
- ✓ config/initializers/ai_providers.rb

### 3. Task Breakdown Quality

**Score: 9/10** - Excellent sizing and sequencing

#### Task Sizing Analysis ✅

All tasks are appropriately sized for single development sessions:

| Task | Estimated Complexity | Files to Create/Modify | Status |
|------|---------------------|------------------------|--------|
| 1. AI Client & Providers | High (4-6 hours) | 5 files | Not started |
| 2. Message Model | Medium (2-3 hours) | 3 files | **✅ COMPLETE** |
| 3. SendMessage Mutation | High (3-4 hours) | 1 file + tests | Not started |
| 4. Context Manager | Medium (2-3 hours) | 1 file + tests | Not started |
| 5. System Prompts | Low (1-2 hours) | 1 file | Not started |
| 6. MessageReceived Subscription | Medium (2-3 hours) | 1 file + channel | Not started |
| 7. MessageType | Low (1 hour) | 1 file | Not started |
| 8. Audit Logging | Low (1-2 hours) | Modifications | Not started |
| 9. Performance Testing | Medium (2-3 hours) | Test files | Not started |

**Total Estimated Effort**: 18-27 hours (realistic for complex story)

#### Task Sequencing ✅

Dependency order is logical:

```
Task 2 (Message Model) ✅ COMPLETE
    ↓
Task 1 (AI Client) ← Task 5 (Prompts) ← Task 4 (Context Manager)
    ↓
Task 3 (SendMessage Mutation) → Task 7 (MessageType)
    ↓
Task 6 (MessageReceived Subscription)
    ↓
Task 8 (Audit Logging) | Task 9 (Performance Tests)
```

**Parallel Work Opportunities**:
- Tasks 4, 5 can be done in parallel with Task 1
- Tasks 7, 8, 9 can be done in parallel after core functionality

#### Subtask Clarity ✅

Example from Task 1 (lines 45-52):
- ✓ Specific file paths provided
- ✓ Clear implementation steps
- ✓ Configuration details included
- ✓ Testing requirements explicit

### 4. Dependencies & Prerequisites

**Score: 10/10** - All dependencies correctly identified

#### Story Dependencies ✅

**Epic 2 Prerequisites** (line 522):
- Session management complete ✓
- Authentication framework in place ✓
- Audit logging foundation ✓

**Verification**:
- OnboardingSession model exists ✓
- JWT authentication patterns defined ✓
- AuditLog model exists ✓

#### External Dependencies ✅

**Required Gems** (lines 178-184):
```ruby
gem "anthropic", "~> 0.1"
gem "ruby-openai", "~> 6.0"
```

**Status**: Not yet added to Gemfile
**Action Required**: Add before Task 1 implementation

**Environment Variables** (lines 181-184):
```bash
AI_PROVIDER=anthropic  # or 'openai'
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```

**AWS Services** (architecture.md:14-17):
- S3 for potential file storage (future)
- No AWS dependencies for this story ✓

#### Internal Dependencies ✅

**Models Required**:
- ✓ OnboardingSession (exists)
- ✓ Message (exists, Task 2 complete)

**Concerns Required**:
- ✓ Encryptable (exists)
- ✓ Auditable (exists)

**Services Required**:
- Auth::JwtService (exists per architecture.md:602-622) ✓

### 5. Testability & Acceptance Criteria

**Score: 10/10** - All criteria are verifiable with clear test strategies

#### Acceptance Criteria Quality ✅

All 7 acceptance criteria follow **Given-When-Then** BDD format:

**AC1: Message Storage** (line 29) ✅
```
Given: session is active
When: parent sends message
Then: sendMessage mutation accepts content, stores with role USER
```
**Testability**: GraphQL mutation test + model persistence test
**Verification Method**: RSpec mutation spec with database assertions

**AC2: AI Service Integration** (line 31) ✅
```
Given: message is received
When: AI processing completes
Then: AI service called, response stored with role ASSISTANT
```
**Testability**: Service integration test with mocked AI provider
**Verification Method**: VCR cassette or provider mock, verify service call + response storage

**AC3: Real-time Streaming** (line 33) ✅
```
Given: AI is responding
When: response is generated
Then: response streamed via GraphQL subscription
```
**Testability**: Subscription test with Action Cable test helpers
**Verification Method**: GraphQL subscription spec, verify WebSocket delivery

**AC4: Context Maintenance** (line 35) ✅
```
Given: ongoing conversation
When: context is assembled
Then: last 50 messages included
```
**Testability**: Context manager unit test
**Verification Method**: Create 60 messages, verify only last 50 included

**AC5: Encryption at Rest** (line 37) ✅
```
Given: message content
When: stored in database
Then: all messages encrypted (PHI)
```
**Testability**: Database-level encryption verification
**Verification Method**: ✅ **ALREADY TESTED** (spec/models/message_spec.rb:31-44)

**AC6: Performance** (line 39) ✅
```
Given: AI service call
When: measuring performance
Then: AI response time p95 < 2 seconds
```
**Testability**: Performance benchmark test
**Verification Method**: RSpec benchmark with mock provider, percentile calculation

**AC7: Rate Limiting** (line 41) ✅
```
Given: AI provider rate limit
When: limit is reached
Then: exponential backoff with Sidekiq retries
```
**Testability**: Sidekiq job test with simulated rate limit
**Verification Method**: Mock rate limit error, verify retry behavior

#### Test Coverage Plan ✅

**Already Implemented** (Task 2):
- ✅ Message model specs (spec/models/message_spec.rb)
- ✅ Message factory (spec/factories/messages.rb)
- ✅ Database-level encryption verification

**Required for Completion** (Task 1, 3, 4, 6, 9):

**Unit Tests**:
- [ ] AI Client spec (provider selection, error handling)
- [ ] Anthropic Provider spec (API integration, mocking)
- [ ] OpenAI Provider spec (API integration, mocking)
- [ ] Context Manager spec (50-message window, formatting)

**Integration Tests**:
- [ ] SendMessage mutation spec (full flow: store user → call AI → store assistant)
- [ ] MessageReceived subscription spec (WebSocket delivery)

**Performance Tests**:
- [ ] AI response time benchmark (p95 < 2s verification)

**Coverage Target**: 90%+ for all new service code

### 6. Implementation Status & Quality

**Current Status**: Foundation Complete (1/9 tasks)

#### Task 2: Message Model with Encryption ✅ **EXEMPLARY QUALITY**

**Implementation Files**:
1. ✅ **Model**: app/models/message.rb (18 lines)
2. ✅ **Migration**: db/migrate/20251129153426_create_messages.rb
3. ✅ **Tests**: spec/models/message_spec.rb (59 lines)
4. ✅ **Factory**: spec/factories/messages.rb

**Code Quality Assessment**:

**Strengths**:
1. **Security**: Proper PHI encryption via Encryptable concern
2. **Testing**: Comprehensive coverage including:
   - Associations and validations (lines 6-29)
   - **Database-level encryption verification** (lines 31-44)
   - UUID primary key validation (lines 46-51)
   - Timestamp validation (lines 53-59)
3. **Architecture Compliance**: 100% aligned with architecture.md:566-574
4. **Rails Conventions**: Correct enum syntax, proper associations

**Code Example** (app/models/message.rb):
```ruby
class Message < ApplicationRecord
  include Encryptable
  include Auditable

  enum :role, { user: 0, assistant: 1, system: 2 }

  belongs_to :onboarding_session

  encrypts_phi :content

  validates :role, presence: true
  validates :content, presence: true
  validates :onboarding_session, presence: true
end
```

**Test Example** (spec/models/message_spec.rb:31-44):
```ruby
describe 'PHI encryption' do
  it 'encrypts content field at database level' do
    message = create(:message, content: 'This is sensitive PHI')

    # Verify encrypted in database
    raw_content = ActiveRecord::Base.connection.execute(
      "SELECT content FROM messages WHERE id = '#{message.id}'"
    ).first['content']

    expect(raw_content).not_to eq('This is sensitive PHI')
    expect(message.content).to eq('This is sensitive PHI')
  end
end
```

**Quality Rating**: 10/10
- Database-level encryption verification is **best practice**
- Tests verify both encrypted storage AND decrypted retrieval
- Comprehensive edge case coverage

#### Remaining Implementation (Tasks 1, 3-9)

**Status**: Not started
**Readiness**: All tasks have clear specifications and can proceed

**Recommended Implementation Order**:
1. Task 5 (System Prompts) - No dependencies, sets up prompts for testing
2. Task 1 (AI Client) - Core service layer
3. Task 4 (Context Manager) - Depends on Task 1
4. Task 7 (MessageType) - GraphQL type definition
5. Task 3 (SendMessage Mutation) - Depends on Tasks 1, 4, 7
6. Task 6 (MessageReceived Subscription) - Depends on Task 7
7. Task 8 (Audit Logging) - Add to existing functionality
8. Task 9 (Performance Testing) - Final validation

### 7. Security & Compliance Review

**Score: 10/10** - HIPAA-compliant with proper PHI handling

#### PHI Protection ✅

**Encryption at Rest** (AC5):
- ✅ Message content encrypted via Rails 7 encryption
- ✅ Encryptable concern applied
- ✅ Database-level verification in tests

**Encryption in Transit**:
- ✓ TLS 1.3 for GraphQL API (architecture.md:626-634)
- ✓ WebSocket encryption via Action Cable

**PHI-Safe Logging** (lines 170-171, 360-368):
```ruby
# CORRECT (specified in story):
audit_log.details = { session_id: session.id, message_id: message.id }

# NEVER:
# audit_log.details = { content: message.content }  # PHI!
```

✓ Story explicitly specifies: "Never log actual message content (PHI)"

#### Authorization ✅

**Session Ownership Verification** (lines 435-440):
- ✓ SendMessage mutation MUST verify session ownership
- ✓ MessageReceived subscription MUST check session access

**GraphQL Context Pattern** (architecture.md:268-298):
```ruby
def resolve(session_id:, content:)
  session = OnboardingSession.find(session_id)
  raise GraphQL::ExecutionError, "Unauthorized" unless authorized?(session)
  # ...
end
```

#### API Key Security ✅

**Storage** (line 174, architecture.md:899-920):
- ✓ Rails credentials for production
- ✓ Environment variables for development
- ✓ Never committed to repository

#### Audit Trail ✅

**Task 8 Specification** (lines 98-101):
- ✓ MESSAGE_SENT action for user messages
- ✓ AI_RESPONSE action for assistant messages
- ✓ Session and message IDs tracked
- ✓ PHI content excluded from logs

#### HIPAA Compliance Checklist ✅

- [x] PHI encrypted at rest (AC5, Task 2)
- [x] PHI encrypted in transit (TLS 1.3)
- [x] Access control via JWT + session ownership
- [x] Complete audit logging (Task 8)
- [x] Data retention policy (architecture.md:1598-1619)
- [x] Encryption key management (Rails credentials)

### 8. Key Findings & Recommendations

#### Strengths ✅

1. **Architectural Excellence**
   - 100% alignment with architecture.md
   - Proper separation of concerns (Services, GraphQL, Models)
   - ADR compliance (ADR-002, ADR-003, ADR-005)

2. **Security First**
   - PHI encryption implemented correctly
   - Database-level encryption verification (best practice)
   - PHI-safe logging specified throughout

3. **Comprehensive Testing Strategy**
   - All acceptance criteria verifiable
   - Unit, integration, and performance tests planned
   - Existing tests demonstrate high quality

4. **Clear Task Breakdown**
   - Appropriate sizing (18-27 hours total)
   - Logical dependencies identified
   - Specific file paths and patterns provided

5. **Foundation Quality**
   - Message model implementation is exemplary
   - Sets high quality bar for remaining work

#### Minor Observations ⚠️

1. **Missing Gemfile Dependencies** (Non-blocking)
   - `anthropic` and `ruby-openai` gems not yet added
   - **Action**: Add before Task 1 implementation
   - **Impact**: Low - straightforward addition

2. **Task 2 Checkbox** (Documentation)
   - Task 2 complete but not marked [x]
   - **Action**: Update line 54 to `- [x] **Task 2:`
   - **Impact**: None - documentation hygiene

3. **Story Complexity** (Advisory)
   - 9 tasks, 18-27 hour estimate is substantial
   - **Consideration**: Could split into sub-stories for iterative delivery:
     - Story 3.1a: "AI Client Foundation" (Tasks 1, 4, 5)
     - Story 3.1b: "GraphQL Message Integration" (Tasks 3, 7)
     - Story 3.1c: "Real-time Subscriptions" (Tasks 6, 8, 9)
   - **Impact**: Low - current structure is valid, splitting is optional

4. **Integration Test Coverage** (Enhancement)
   - End-to-end flow test not explicitly listed
   - **Recommendation**: Add integration test:
     ```ruby
     # spec/integration/conversation_flow_spec.rb
     it "completes full message flow" do
       # 1. User sends message
       # 2. AI processes with context
       # 3. Subscription delivers response
     end
     ```
   - **Impact**: Low - improves confidence but not required

#### Best Practices Demonstrated ✅

1. **Database-Level Encryption Verification**
   - Tests verify encryption at storage layer (not just application)
   - Exemplary security testing practice

2. **Provider Pattern Implementation**
   - Enables vendor flexibility (ADR-002)
   - Clear interface contract (base_provider.rb)

3. **BDD Acceptance Criteria**
   - All criteria in Given-When-Then format
   - Clear verification methods

4. **PHI-Safe Audit Logging**
   - Metadata logged, content excluded
   - Compliance-focused design

### 9. Action Items for Implementation

#### Prerequisites (Before Task 1)

**HIGH PRIORITY:**

- [ ] Add AI provider gems to Gemfile
  ```ruby
  # Gemfile
  gem "ruby-openai", "~> 6.0"  # Primary provider
  gem "anthropic", "~> 0.1"     # Backup provider
  ```
  **File**: /Users/andre/coding/daybreak/daybreak-health-backend/Gemfile

- [ ] Run bundle install
  ```bash
  bundle install
  ```

- [ ] Add environment variables to .env.example
  ```bash
  # .env.example (already updated)
  AI_PROVIDER=openai  # default, or 'anthropic' for backup
  OPENAI_API_KEY=your_key_here
  ANTHROPIC_API_KEY=your_key_here  # backup
  ```

- [ ] Mark Task 2 as complete
  **File**: docs/sprint-artifacts/3-1-conversational-ai-service-integration.md
  **Line**: 54
  **Change**: `- [ ] **Task 2:` → `- [x] **Task 2:`

#### Implementation Roadmap

**Phase 1: Service Layer (Tasks 1, 4, 5)** - Estimated 8-12 hours
1. Task 5: System Prompts (low complexity, no dependencies)
2. Task 1: AI Client & Providers (high complexity)
3. Task 4: Context Manager (depends on Task 1)

**Phase 2: GraphQL Layer (Tasks 3, 7)** - Estimated 4-5 hours
4. Task 7: MessageType (low complexity)
5. Task 3: SendMessage Mutation (high complexity, depends on Tasks 1, 4, 7)

**Phase 3: Real-time & Integration (Tasks 6, 8)** - Estimated 4-5 hours
6. Task 6: MessageReceived Subscription (depends on Task 7)
7. Task 8: Audit Logging (modifications to existing)

**Phase 4: Validation (Task 9)** - Estimated 2-3 hours
8. Task 9: Performance Testing (final validation)

#### Testing Checklist

**Unit Tests Required:**
- [ ] AI::Client spec (provider selection, error handling)
- [ ] AI::Providers::AnthropicProvider spec (API integration, mocks)
- [ ] AI::Providers::OpenaiProvider spec (API integration, mocks)
- [ ] AI::ContextManager spec (50-message window, formatting)

**Integration Tests Required:**
- [ ] SendMessage mutation spec (full flow verification)
- [ ] MessageReceived subscription spec (WebSocket delivery)

**Performance Tests Required:**
- [ ] AI response time benchmark (p95 < 2s)

**Optional Enhancement:**
- [ ] End-to-end conversation flow integration test

### 10. Conclusion

**Final Verdict: APPROVED FOR IMPLEMENTATION**

This story demonstrates **exceptional quality** in both definition and foundational implementation. The comprehensive task breakdown, clear acceptance criteria, and perfect architectural alignment make this story **ready for immediate development** once prerequisites are satisfied.

**Quality Metrics:**
- Completeness: 10/10
- Technical Accuracy: 10/10
- Task Breakdown: 9/10
- Dependencies: 10/10
- Testability: 10/10
- Security: 10/10

**Overall Score: 9.8/10**

**Recommendation**: Proceed with implementation following the phased roadmap. The Message model foundation sets an excellent quality standard for the remaining work.

**Success Criteria for Story Completion:**
- [ ] All 9 tasks completed and tested
- [ ] All 7 acceptance criteria verified
- [ ] Test coverage > 90% for new code
- [ ] Performance benchmark shows p95 < 2s
- [ ] Security review passed (PHI encryption, authorization, audit logging)
- [ ] GraphQL subscriptions functioning via Action Cable
- [ ] AI provider integration working with both Anthropic and OpenAI

**Estimated Time to Completion**: 18-27 hours of focused development

---

**Review Sign-off**: This story is architecturally sound, security-compliant, and ready for implementation. The existing Message model implementation sets a high quality bar. No blocking issues identified.

**Next Steps**:
1. Add AI provider gems to Gemfile
2. Begin Phase 1 implementation (Service Layer)
3. Follow recommended implementation order
4. Verify all acceptance criteria upon completion

