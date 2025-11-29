# Story 3.2: Adaptive Question Flow

Status: ready-for-dev

## Story

As a **parent**,
I want **the AI to ask relevant follow-up questions based on my responses**,
so that **I only answer what's necessary and the conversation feels natural**.

## Acceptance Criteria

**Given** parent has provided initial information
**When** they respond to a question
**Then**
- AI analyzes response for completeness and relevance
- Follow-up questions adapt based on:
  - Missing required information
  - Clarification needed for ambiguous responses
  - Related topics that should be explored
- Conversation flows through intake phases: Welcome → Parent Info → Child Info → Concerns
- AI doesn't repeat questions already answered
- Progress updates reflect completed topics

**And** AI maintains empathetic, supportive tone throughout
**And** Conversation stays focused on intake goals

## Tasks / Subtasks

- [ ] Task 1: Implement Context Manager Service (AC: Phase tracking, field collection, pending questions)
  - [ ] Create `app/services/ai/context_manager.rb` service class
  - [ ] Implement phase state tracking (welcome, parent_info, child_info, concerns)
  - [ ] Implement collected fields tracking with validation
  - [ ] Implement pending questions queue management
  - [ ] Add session progress JSON structure management
  - [ ] Write unit tests for context manager

- [ ] Task 2: Implement Response Analysis (AC: Completeness and relevance detection)
  - [ ] Create response analyzer in context manager
  - [ ] Implement completeness detection logic
  - [ ] Implement ambiguity detection
  - [ ] Add related topic exploration logic
  - [ ] Write tests for response analysis

- [ ] Task 3: Implement Adaptive Follow-up Logic (AC: Dynamic question generation)
  - [ ] Create follow-up question generator
  - [ ] Implement missing information detection
  - [ ] Implement clarification question generation
  - [ ] Add related topic question generation
  - [ ] Ensure no question repetition logic
  - [ ] Write tests for follow-up generation

- [ ] Task 4: Implement Phase Transition Management (AC: Conversation flow)
  - [ ] Create phase transition validator
  - [ ] Implement Welcome → Parent Info transition
  - [ ] Implement Parent Info → Child Info transition
  - [ ] Implement Child Info → Concerns transition
  - [ ] Add automatic phase progression based on completion
  - [ ] Write tests for phase transitions

- [ ] Task 5: Update AI Prompts for Adaptive Behavior (AC: Empathetic tone, focused conversation)
  - [ ] Update system prompts in `app/services/ai/prompts/intake_prompt.rb`
  - [ ] Add context manager instructions to prompts
  - [ ] Implement empathetic response guidelines
  - [ ] Add conversation focus constraints
  - [ ] Test tone and focus with sample conversations

- [ ] Task 6: Integrate with Session Progress Updates (AC: Progress reflects completed topics)
  - [ ] Update session progress JSON on field collection
  - [ ] Implement progress percentage calculation
  - [ ] Add current phase tracking to session
  - [ ] Update `updateSessionProgress` mutation integration
  - [ ] Write integration tests

- [ ] Task 7: Integration Testing (AC: All criteria)
  - [ ] Create end-to-end conversation flow tests
  - [ ] Test phase transitions with real AI responses
  - [ ] Verify no question repetition across conversation
  - [ ] Test missing information detection scenarios
  - [ ] Verify progress updates accuracy
  - [ ] Test empathetic tone maintenance

## Dev Notes

### Architecture Patterns

**Context Manager Pattern:**
- Service class manages conversation state separate from message history
- Tracks structural progress (phases, fields, questions) not just dialogue
- Enables deterministic phase transitions and validation
- Integrates with session.progress JSONB field for persistence

**Structured Output Prompting:**
- Use structured output prompting to extract data from natural language responses
- Parse parent responses to identify collected fields (name, email, etc.)
- Update context manager with extracted information
- Validate completeness before phase transitions

**State Machine for Phases:**
- Phases: welcome → parent_info → child_info → concerns
- Each phase has required fields and optional fields
- Transition triggers when required fields collected
- Prevents backward transitions to maintain conversation flow

### Source Tree Components

**New Files:**
- `app/services/ai/context_manager.rb` - Core context management service
- `app/services/ai/prompts/intake_prompt.rb` - AI system prompts (may already exist from 3.1)
- `spec/services/ai/context_manager_spec.rb` - Context manager tests

**Files to Modify:**
- `app/graphql/mutations/conversation/send_message.rb` - Integrate context manager
- `app/graphql/mutations/sessions/update_progress.rb` - Update with phase tracking
- `app/services/ai/client.rb` - Pass context to AI provider
- `app/models/onboarding_session.rb` - Add phase enum or validation

### Testing Standards

**Unit Tests:**
- Test context manager phase transitions in isolation
- Test field collection tracking logic
- Test question deduplication
- Test completeness detection algorithms

**Integration Tests:**
- Full conversation flows through all phases
- Verify AI responses adapt based on context
- Test progress persistence across messages
- Verify no regression in empathetic tone

**Test Data:**
- Create fixtures for various response patterns
- Include ambiguous responses for clarification testing
- Include incomplete responses for follow-up testing
- Include complete responses for phase transition testing

### Security & Compliance

- Context manager state stored in session.progress (encrypted JSONB)
- No PHI logged directly - only field existence flags
- Audit trail for phase transitions via existing audit log
- Rate limiting on message sends to prevent abuse

### Project Structure Notes

**Alignment with Unified Structure:**
- Follows Rails service object pattern in `app/services/`
- GraphQL mutations in `app/graphql/mutations/` per architecture
- Active Record models use JSONB for flexible progress tracking
- RSpec tests in `spec/` mirror source structure

**Context Manager State Schema:**
```ruby
{
  phase: "parent_info",  # welcome, parent_info, child_info, concerns
  collected_fields: ["first_name", "email"],
  pending_questions: ["What is your relationship to the child?"],
  field_metadata: {
    "first_name": { collected_at: "2025-11-29T...", confidence: "high" },
    "email": { collected_at: "2025-11-29T...", confidence: "high" }
  }
}
```

### References

**Epic Details:**
- [Source: docs/epics.md#Story 3.2: Adaptive Question Flow]
  - FR8: AI adapts follow-up questions based on parent responses
  - Context manager tracks: { phase, collectedFields[], pendingQuestions[] }
  - Conversation phases: Welcome → Parent Info → Child Info → Concerns
  - No question repetition requirement
  - Progress updates reflect completed topics

**Architecture Constraints:**
- [Source: docs/architecture.md#Service Pattern]
  - Services in `app/services/` with class-based organization
  - Provider pattern for AI abstraction
- [Source: docs/architecture.md#Data Architecture]
  - Session.progress as JSONB for flexible state
  - Rails 7 encryption for PHI fields
- [Source: docs/architecture.md#Implementation Patterns]
  - snake_case for files, PascalCase for classes
  - GraphQL mutations pattern with BaseMutation inheritance

**PRD Requirements:**
- [Source: docs/PRD.md#FR8]
  - Adaptive follow-up questions based on responses
- [Source: docs/PRD.md#FR10]
  - Progress indicators integration
- [Source: docs/PRD.md#Conversational AI Interface]
  - Natural language interaction, not form-filling
  - Smart follow-up based on responses

## Dev Agent Record

### Context Reference

- docs/sprint-artifacts/3-2-adaptive-question-flow.context.xml

### Agent Model Used

Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Debug Log References

### Completion Notes List

### File List

---

## Senior Developer Review (AI)

**Reviewer:** Claude Code (Sonnet 4.5)
**Review Date:** 2025-11-29 (Updated)
**Review Scope:** Story completeness, technical accuracy, task breakdown, dependencies, testability

### 1. Completeness - Epic Acceptance Criteria Coverage

**Epic 3 Story 3.2 Requirements (from epics.md lines 533-563):**

✅ **COMPLETE** - All epic acceptance criteria are properly addressed:

- ✅ AI analyzes response for completeness and relevance (AC lines 16, 44)
- ✅ Follow-up questions adapt based on missing information, clarification needs, and related topics (AC lines 17-20, Tasks 2-3)
- ✅ Conversation flows through phases: Welcome → Parent Info → Child Info → Concerns (AC line 21, Task 4)
- ✅ No question repetition (AC line 22, Task 3 line 50)
- ✅ Progress updates reflect completed topics (AC line 23, Task 6)
- ✅ Empathetic, supportive tone (AC line 25, Task 5)
- ✅ Conversation stays focused on intake goals (AC line 26, Task 5)

**Epic Technical Notes (epics.md lines 557-562) - Alignment:**

✅ Context manager pattern implemented with correct state structure (`{ phase, collectedFields[], pendingQuestions[] }`)
✅ Service location correct (`app/services/ai/context_manager.rb`)
✅ Structured output prompting for data extraction (Dev Notes line 95)
✅ Phase transitions with automatic progress updates (Task 4, Task 6)

**Verdict:** Story comprehensively covers all Epic 3 Story 3.2 acceptance criteria.

---

### 2. Technical Accuracy - Architecture Alignment

**Architecture Document Compliance:**

✅ **Service Pattern (architecture.md lines 236-263):**
- Context manager correctly placed in `app/services/ai/` (Task 1 line 31)
- Follows Rails service object class-based organization
- Proper integration with existing AI client structure (line 115)

✅ **Naming Conventions (architecture.md lines 218-232):**
- Files: `context_manager.rb` (snake_case) ✓
- Classes: Implied `Ai::ContextManager` following Rails namespace convention (PascalCase module) ✓
- Methods: `update_session_progress` (snake_case) ✓

✅ **Data Architecture (architecture.md lines 373-515, specifically 380-387):**
- Correctly uses `session.progress` JSONB field from OnboardingSession model
- State machine pattern for phases aligns with Rails enum pattern (architecture lines 519-545)
- Context Manager State Schema (lines 154-164) perfectly matches Rails JSONB storage conventions

✅ **GraphQL Integration (architecture.md lines 66-115, 266-299):**
- Mutation paths are correct:
  - `app/graphql/mutations/conversation/send_message.rb` (line 112)
  - `app/graphql/mutations/sessions/update_progress.rb` (line 114)
- Follows BaseMutation inheritance pattern (architecture lines 266-299)

✅ **Security & Compliance (architecture.md lines 580-633):**
- Context manager state in encrypted JSONB field (OnboardingSession.progress)
- Explicit PHI-safe logging: only field existence flags, never PHI values (Dev Notes line 141)
- Audit trail integration via existing Auditable concern (architecture line 128)

**Technical Accuracy Assessment:**

✅ **EXCELLENT**: All file paths, patterns, and integrations match the architecture document precisely.

**Minor Clarifications Needed:**

⚠️ **MINOR** (Task 1): Should explicitly state class name `Ai::ContextManager` (not `AI::ContextManager`) to match Rails convention where modules use PascalCase but prefer `Ai::` over `AI::` for readability.

⚠️ **MINOR** (Line 109): References to `intake_prompt.rb` existing from Story 3.1 should be verified against Story 3.1's actual deliverables before implementation begins.

---

### 3. Task Breakdown - Sizing and Sequencing

**Task 1: Context Manager Service** (Lines 30-36)
- **Size:** ✅ Appropriate (6 subtasks, ~3-4 hours)
- **Sequence:** ✅ Correct (foundational, must be first)
- **Issue:** ⚠️ Subtask "Add session progress JSON structure management" (line 35) overlaps with Task 6 (lines 68-73)
- **Recommendation:** Clarify that Task 1 *defines* the structure schema, Task 6 *integrates* it with GraphQL mutation

**Task 2: Response Analysis** (Lines 38-44)
- **Size:** ✅ Good (focused scope, ~2 hours)
- **Sequence:** ✅ Depends on Task 1 ✓
- **Specification Gap:** ⚠️ "Completeness detection logic" (line 40) - is this regex-based, LLM classification, or hybrid? Needs clarification.

**Task 3: Adaptive Follow-up Logic** (Lines 46-51)
- **Size:** ✅ Appropriate (~3 hours)
- **Sequence:** ✅ Depends on Tasks 1 & 2 ✓
- **Critical Gap:** ⚠️ "No question repetition logic" (line 50) is underspecified. Mechanisms could include:
  - Simple: Hash-based deduplication on question text
  - Advanced: Semantic similarity with embeddings
  - Context-aware: Track asked questions in context manager state
- **Recommendation:** Specify exact mechanism in task or accept that implementation will choose approach

**Task 4: Phase Transition Management** (Lines 53-59)
- **Size:** ✅ Good (state machine, ~3 hours)
- **Sequence:** ✅ Logical after context manager ✓
- **Alignment:** ✅ Perfectly matches architecture's OnboardingSession enum pattern (architecture lines 519-545)
- **Missing Detail:** What happens if parent refuses to answer required fields? Should phase stay or escalate?

**Task 5: Update AI Prompts** (Lines 61-66)
- **Size:** ✅ Appropriate (~2-3 hours)
- **Sequence Issue:** ⚠️ Should explicitly depend on Tasks 1-4 (prompts use context manager output)
- **Ambiguity:** "Test tone and focus with sample conversations" (line 66) - manual QA or automated test fixtures?
- **Recommendation:** Specify: "Create RSpec test fixtures with expected empathetic responses"

**Task 6: Session Progress Integration** (Lines 68-73)
- **Size:** ✅ Good (~2 hours)
- **Overlap:** ⚠️ Clarify distinction from Task 1 subtask (see Task 1 issue above)
- **Clarity:** ✅ Integration with `updateSessionProgress` mutation is well-defined

**Task 7: Integration Testing** (Lines 75-81)
- **Size:** ✅ Comprehensive (~4 hours)
- **Sequence:** ✅ Correctly last ✓
- **Coverage:** ✅ Covers all ACs including AI behavior, phase flow, deduplication, progress accuracy

**Overall Sizing Assessment:** ✅ Tasks well-sized for 1-2 day implementation (16-20 hours total estimated).

---

### 4. Dependencies - Prerequisites and Integration Points

**Explicitly Declared Prerequisites:**

✅ **Story 3.1** (Conversational AI Service Integration):
- Required for: AI client, message storage, conversation history
- Correctly identified at line 522 (epics.md)

**CRITICAL Missing Prerequisites:**

❌ **Epic 2 Stories 2.1, 2.2, 2.6 (Session Lifecycle)**:
- **2.1** - OnboardingSession model must exist
- **2.2** - Session.progress JSONB field required (architecture line 382)
- **2.6** - Encryptable concern for PHI fields (architecture lines 304-329)

**Recommendation:** Add to Prerequisites section:
```
**Prerequisites:**
- Story 3.1 (Conversational AI Service Integration)
- Epic 2 Stories 2.1, 2.2, 2.6 (Session models, progress tracking, encryption)
```

**Integration Points:**

✅ **Correctly Identified:**
- `app/graphql/mutations/conversation/send_message.rb` (line 112)
- `app/graphql/mutations/sessions/update_progress.rb` (line 114)
- `app/services/ai/client.rb` (line 115)
- `app/models/onboarding_session.rb` (line 116)

⚠️ **Missing Forward Integration:**
- **Story 3.4** (Progress Indicators): Will consume context manager's phase tracking and completedFields data
- Should note this in Dev Notes as "Forward Integration" so Story 3.4 knows to use this API

**Lateral Integration (Same Epic):**

✅ **Story 3.6** (Parent Info Collection): Context manager tracks parent fields
✅ **Story 3.7** (Child Info Collection): Context manager tracks child fields

---

### 5. Testability - Verification of Acceptance Criteria

**Unit Test Coverage Analysis:**

✅ **Task 1 Tests** (Line 36): Context manager unit tests
- Phase state tracking ✓
- Collected fields tracking with validation ✓
- Pending questions queue management ✓
- JSON structure persistence ✓

✅ **Task 2 Tests** (Line 44): Response analysis tests
- Completeness detection ✓
- Ambiguity detection ✓
- Related topic exploration ✓

✅ **Task 3 Tests** (Line 51): Follow-up generation tests
- Missing information detection ✓
- Clarification question generation ✓
- No question repetition ✓

✅ **Task 4 Tests** (Line 59): Phase transition tests
- State machine validation ✓
- Phase progression logic ✓

✅ **Task 6 Tests** (Line 73): Integration tests
- Progress persistence across messages ✓

**Integration Test Coverage:**

✅ **Task 7** (Lines 75-81): E2E conversation flow tests
- Full phase transitions with real AI responses ✓
- No question repetition verification across full conversation ✓
- Missing information detection scenarios ✓
- Progress update accuracy ✓
- Empathetic tone maintenance ✓

**Test Data Strategy:**

✅ **Excellent** (Lines 132-137): Comprehensive test fixtures defined
- Ambiguous responses for clarification testing ✓
- Incomplete responses for follow-up testing ✓
- Complete responses for phase transition testing ✓

**Testability Challenges:**

⚠️ **MODERATE** - AC "AI doesn't repeat questions already answered" (line 22):
- **Challenge:** How to verify without brittle prompt assertions or manual review?
- **Recommendation:**
  ```ruby
  # spec/services/ai/context_manager_spec.rb
  it "prevents re-asking collected fields" do
    context_manager.mark_field_collected("parent_email")
    pending_questions = context_manager.generate_follow_ups
    expect(pending_questions).not_to include(/email/i)
  end
  ```

⚠️ **SUBJECTIVE** - AC "Empathetic, supportive tone" (line 25):
- **Challenge:** Tone is subjective and AI-generated
- **Options:**
  1. Manual QA only (not in automated suite)
  2. Keyword verification: Check for empathy markers ("I understand", "Thank you for sharing")
  3. LLM-as-judge: Use separate AI to rate tone (complex)
- **Recommendation:** Combine manual QA with keyword spot-checks in Task 7 integration tests

**Overall Testability:** ✅ **STRONG** - Well-defined test strategy with appropriate coverage at unit, integration, and E2E levels.

---

### 6. Additional Observations

**Strengths:**

1. ✅ **Exemplary Technical Documentation**:
   - Context Manager State Schema (lines 154-164) provides exact JSON contract
   - Architectural pattern explanations (lines 86-104) are clear and actionable
   - Security considerations explicitly documented (lines 139-143)

2. ✅ **Architecture Alignment**:
   - Perfect adherence to architecture.md Service Pattern (lines 236-263)
   - Correct usage of Rails conventions (snake_case files, PascalCase classes)
   - Proper integration with existing GraphQL mutation patterns

3. ✅ **Comprehensive Reference Linking**:
   - Lines 167-195 provide exact line references to source documents
   - Makes verification and implementation guidance very efficient

**Improvement Opportunities:**

1. **Task Overlap Resolution** (Task 1 ↔ Task 6):
   - **Current:** Both mention "session progress JSON structure"
   - **Recommendation:**
     - Task 1: "Define Context Manager State Schema structure (lines 154-164)"
     - Task 6: "Integrate schema with updateSessionProgress GraphQL mutation"

2. **Specification Gaps to Address**:
   - **Task 2:** Specify completeness detection approach (LLM-based vs rule-based)
   - **Task 3:** Define question deduplication mechanism (see Testability section)
   - **Task 4:** Add edge case handling: "What if parent refuses required field after 3 attempts?"
   - **Task 5:** Clarify tone testing: manual QA + keyword spot-checks

3. **Error Handling Strategy** (Missing):
   - What if AI fails to extract data from response after structured prompting?
   - **Recommendation:** Add to Task 2:
     ```
     - Implement extraction confidence scoring
     - Add fallback: If confidence < 0.7, ask clarifying question
     - Add escape hatch: After 3 failed extractions, offer manual input option
     ```

4. **Phase Transition Validation** (Incomplete):
   - Story doesn't specify validation rules:
     - Can phases be skipped? (Probably no)
     - Can phases go backward? (Only to ABANDONED per architecture)
     - What's minimum data for phase completion?
   - **Recommendation:** Add to Task 4:
     ```
     - Define required fields per phase (welcome: [], parent_info: [first_name, email], ...)
     - Implement phase completion validator
     - Prevent backward transitions except ABANDONED
     ```

---

### 7. Risk Assessment

**Low Risks (Well-Mitigated):**

✅ Context manager pattern is standard Rails service object
✅ JSONB storage is proven Rails pattern with strong support
✅ GraphQL integration points are clearly defined and tested
✅ Security model (encryption, audit logging) uses established patterns

**Medium Risks (Manageable with Mitigation):**

⚠️ **LLM Data Extraction Reliability**:
- **Risk:** Structured output prompting may fail to extract fields from natural language
- **Impact:** Phase transitions blocked, poor UX
- **Mitigation:** Implement confidence scoring + fallback to clarifying questions (see Improvement Opportunities #3)
- **Severity:** Medium (can degrade UX but won't break system)

⚠️ **Phase Transition Edge Cases**:
- **Risk:** Parent refuses to answer required fields
- **Impact:** Conversation gets stuck, session abandoned
- **Mitigation:** Add Task 4 subtask for incomplete data handling (see Improvement Opportunities #4)
- **Severity:** Medium (affects conversion rate but has workarounds)

⚠️ **Question Deduplication Complexity**:
- **Risk:** Semantic similarity is hard (same question, different wording)
- **Impact:** AI repeats questions, poor UX
- **Mitigation Options:**
  - Simple: Exact text matching (fast, limited effectiveness)
  - Advanced: Question embedding similarity (slower, more effective)
  - Hybrid: Text matching + field tracking in context
- **Recommendation:** Start with field tracking (if "parent_email" collected, don't generate email questions)
- **Severity:** Low-Medium (annoying but not blocking)

**Risk Mitigation Summary:**

Add to Task 2:
```
- Implement extraction confidence scoring (0-1 scale)
- Add fallback for low-confidence extractions (< 0.7): generate clarifying question
- Add escape hatch: After 3 failed extractions, offer manual input
```

Add to Task 3:
```
- Implement field-based deduplication: Track collected_fields in context
- Generate questions only for uncollected fields
- (Optional) Add semantic similarity for question text if needed
```

Add to Task 4:
```
- Define required fields map: { welcome: [], parent_info: [first_name, email, relationship], ... }
- Handle incomplete data: If stuck after 3 attempts, escalate to human or allow skip
- Validate phase completeness before transition
```

---

### 8. Final Verdict

**Overall Assessment:** ✅ **APPROVED - READY FOR DEVELOPMENT WITH MINOR CLARIFICATIONS**

**Summary:**
- **Completeness:** 100% - All epic acceptance criteria covered
- **Technical Accuracy:** 98% - Excellent architecture alignment (minor namespacing clarification needed)
- **Task Breakdown:** 90% - Well-sized tasks with minor overlap and specification gaps
- **Dependencies:** 85% - Story 3.1 identified, but Epic 2 prerequisite missing
- **Testability:** 95% - Strong test strategy with clear coverage (subjective criteria need approach defined)

**Story Quality Score: 93/100 (Excellent)**

---

**REQUIRED Changes Before Implementation:**

1. ✅ **Add Prerequisites**:
   ```
   **Prerequisites:**
   - Story 3.1 (Conversational AI Service Integration)
   - Epic 2 Stories 2.1, 2.2, 2.6 (Session models, progress JSONB, encryption)
   ```

2. ✅ **Clarify Task 1/Task 6 Overlap**:
   - Task 1 subtask: "Define Context Manager State Schema (lines 154-164)"
   - Task 6: "Integrate schema with updateSessionProgress mutation"

3. ✅ **Specify Deduplication Mechanism (Task 3)**:
   - Add subtask: "Implement field-based deduplication using collected_fields tracking"

4. ✅ **Clarify Tone Testing (Task 5)**:
   - Update subtask: "Manual QA tone validation + create RSpec fixtures with empathy keywords"

---

**RECOMMENDED Enhancements (Non-Blocking):**

1. Specify completeness detection approach in Task 2 (LLM vs rule-based)
2. Add error handling for failed AI data extraction (Task 2)
3. Define phase transition validation rules and edge case handling (Task 4)
4. Add quantitative success metrics: "< 5% question repetition rate" (AC enhancement)
5. Note forward integration with Story 3.4 (Progress Indicators) in Dev Notes

---

**Implementation Guidance:**

**Priority Focus Areas:**
1. **Context Manager State Schema** (lines 154-164): This is the contract - implement exactly as specified
2. **Phase State Machine** (Task 4): Follow architecture OnboardingSession enum pattern (architecture lines 519-545)
3. **PHI-Safe Logging** (Dev Notes line 141): NEVER log PHI values, only existence flags
4. **Field Tracking**: Use `collected_fields` array to prevent question repetition

**Code Quality Checkpoints:**
- [ ] Context manager passes all unit tests (Task 1 tests)
- [ ] Phase transitions validated and logged (Task 4 tests)
- [ ] Integration tests verify no question repetition (Task 7)
- [ ] Progress updates persist correctly (Task 6 tests)
- [ ] Security audit: No PHI in logs, all fields encrypted

**Testing Strategy:**
- Unit tests: Context manager logic in isolation
- Integration tests: Full conversation flows through all phases (Task 7)
- Manual QA: Tone and empathy validation with real AI responses
- Use test fixtures from lines 132-137 for comprehensive coverage

---

**Estimated Implementation Effort:** 2-3 dev days (16-24 hours)

**Breakdown:**
- Day 1: Tasks 1-2 (Context manager + response analysis) - 6-8 hours
- Day 2: Tasks 3-5 (Follow-ups + phase transitions + prompts) - 6-8 hours
- Day 3: Tasks 6-7 (Integration + testing) - 4-8 hours

**Confidence Level:** High (90%) - Story is well-defined, risks are identified and mitigatable, architecture alignment is excellent.

---

**Review Completed:** 2025-11-29
**Recommendation:** ✅ **READY FOR DEVELOPMENT** (implement required changes above first)
**Next Steps:**
1. Update Prerequisites section per Required Change #1
2. Clarify Task 1/6 overlap per Required Change #2
3. Begin implementation with Task 1 (Context Manager Service)
4. Reference Context Manager State Schema (lines 154-164) as implementation contract
