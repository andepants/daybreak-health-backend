# Story 3.3: Help & Off-Topic Handling

**Status:** ready-for-dev

## Story

As a **parent**,
I want **to ask clarifying questions and get help when confused**,
So that **I understand what's being asked and feel supported**.

## Requirements Context

**From Epic 3 - Conversational AI Intake (epics.md):**

This story implements FR9 (Clarifying questions/help) and FR11 (Off-topic handling) from the PRD. The AI must recognize when a parent is asking for help versus providing an answer, handle off-topic responses gracefully, and maintain an empathetic, supportive tone.

**Functional Requirements Covered:**
- **FR9:** Parents can ask clarifying questions and receive contextual help
- **FR11:** System detects and handles off-topic or confused responses gracefully

**Key Architecture Constraints (from architecture.md):**
- Service layer: `app/services/ai/` for AI logic and prompts
- System prompts in `app/services/ai/prompts/intake_prompt.rb`
- Context manager tracks conversation state in `app/services/ai/context_manager.rb`
- Help interactions should be tracked via analytics/audit logging

## Acceptance Criteria

1. **Given** the AI conversation is active **When** parent asks a clarifying question **Then** AI recognizes question vs. answer intent

2. **Given** a clarifying question is asked **When** AI responds **Then** clarifying questions are answered with helpful context

3. **Given** parent goes off-topic **When** AI detects off-topic content **Then** off-topic responses are gently redirected to intake

4. **Given** parent expresses non-intake concerns **When** AI processes the message **Then** AI acknowledges concerns that aren't intake-related

5. **Given** parent asks "Why do you need this?" **When** AI responds **Then** "Why" questions are explained with empathy

6. **Given** various help intents **When** detected **Then** AI handles: "I don't understand", "What does X mean", "Why are you asking"

7. **Given** any help or off-topic interaction **When** completed **Then** conversation naturally returns to intake after addressing concerns

8. **Given** parent interaction **When** throughout conversation **Then** AI never makes parent feel judged or rushed

## Tasks / Subtasks

- [ ] **Task 1: Implement Intent Classification Service** (AC: 1, 6)
  - [ ] Create `app/services/ai/intent_classifier.rb`
  - [ ] Define intent types: `answer`, `question`, `help_request`, `off_topic`, `clarification`
  - [ ] Implement LLM-based classification via prompt
  - [ ] Add fallback keyword-based classification for common patterns
  - [ ] Add RSpec tests for intent classification

- [ ] **Task 2: Create Help Response Templates** (AC: 2, 5)
  - [ ] Create `app/services/ai/prompts/help_responses.rb`
  - [ ] Define canned explanations for common fields (SSN, DOB, why certain questions)
  - [ ] Add empathetic phrasing guidelines
  - [ ] Map field names to explanation templates
  - [ ] Add tests for response generation

- [ ] **Task 3: Implement Off-Topic Detection and Redirection** (AC: 3, 4, 7)
  - [ ] Extend `context_manager.rb` to track conversation state
  - [ ] Add off-topic detection logic
  - [ ] Create gentle redirection prompts
  - [ ] Implement acknowledgment patterns for non-intake concerns
  - [ ] Ensure smooth transition back to intake flow
  - [ ] Add integration tests for off-topic handling

- [ ] **Task 4: Update System Prompts for Help Handling** (AC: 2, 5, 8)
  - [ ] Update `intake_prompt.rb` with help-handling instructions
  - [ ] Add tone guidelines: never judgmental, never rushing
  - [ ] Include examples of empathetic responses
  - [ ] Define conversation recovery patterns
  - [ ] Test prompt effectiveness

- [ ] **Task 5: Track Help Requests for Analytics** (AC: all)
  - [ ] Create analytics tracking for help requests
  - [ ] Log which questions cause confusion (for UX improvement)
  - [ ] Store intent classification results in message metadata
  - [ ] Add audit logging for help interactions
  - [ ] Create report query for help request patterns

- [ ] **Task 6: Integration with SendMessage Mutation** (AC: all)
  - [ ] Update `send_message.rb` to classify intent before AI call
  - [ ] Route help requests through intent classifier
  - [ ] Include help context in AI prompt when applicable
  - [ ] Ensure conversation state is maintained
  - [ ] Add integration tests

- [ ] **Task 7: Testing and Validation** (AC: all)
  - [ ] Test clarification question flows
  - [ ] Test off-topic detection accuracy
  - [ ] Test conversation recovery (return to intake)
  - [ ] Validate empathetic tone in responses
  - [ ] Test edge cases (repeated help requests, complex questions)

## Dev Notes

### Architecture Patterns

**Intent Classifier:**
```ruby
# app/services/ai/intent_classifier.rb
class Ai::IntentClassifier
  INTENTS = %i[answer question help_request off_topic clarification].freeze

  HELP_KEYWORDS = [
    "i don't understand",
    "what does",
    "what is",
    "why are you asking",
    "why do you need",
    "help",
    "confused"
  ].freeze

  def classify(message, context:)
    # First try keyword matching for speed
    return keyword_intent(message) if obvious_intent?(message)

    # Fall back to LLM classification
    llm_classify(message, context)
  end
end
```

**Help Response Structure:**
```ruby
# app/services/ai/prompts/help_responses.rb
class Ai::Prompts::HelpResponses
  FIELD_EXPLANATIONS = {
    email: "We need your email to send you a confirmation and allow you to resume your session from any device. We will never share your information.",
    phone: "Your phone number helps us reach you quickly if there's anything urgent about your child's care.",
    date_of_birth: "We need your child's date of birth to ensure we match them with age-appropriate care and assessments.",
    # ... more explanations
  }

  def explain_field(field_name)
    FIELD_EXPLANATIONS[field_name.to_sym] || generic_explanation
  end
end
```

### Project Structure Notes

**Files to Create:**
- `app/services/ai/intent_classifier.rb` - Intent detection service
- `app/services/ai/prompts/help_responses.rb` - Help response templates
- `spec/services/ai/intent_classifier_spec.rb` - Classifier tests
- `spec/services/ai/prompts/help_responses_spec.rb` - Response tests

**Files to Modify:**
- `app/services/ai/context_manager.rb` - Add state tracking for help flow
- `app/services/ai/prompts/intake_prompt.rb` - Add help-handling instructions
- `app/graphql/mutations/conversation/send_message.rb` - Integrate intent classification
- `app/models/message.rb` - Add metadata field for intent tracking

### Message Metadata Structure

```ruby
# Store intent classification in message.metadata
{
  intent: "help_request",
  confidence: 0.92,
  detected_pattern: "why do you need",
  field_context: "email",
  redirected_from_topic: nil
}
```

### References

- [Source: docs/epics.md#Story 3.3]
- [Source: docs/architecture.md#Service Pattern]
- FR9: Clarifying questions/help
- FR11: Off-topic handling

## Dev Agent Record

### Context Reference

- docs/sprint-artifacts/3-3-help-and-off-topic-handling.context.xml

### Agent Model Used

<!-- To be filled by dev agent -->

### Debug Log References

<!-- To be filled during development -->

### Completion Notes List

<!-- To be filled during development -->

### File List

<!-- To be filled during development - format: NEW/MODIFIED/DELETED: path -->

## Senior Developer Review (AI)

**Reviewer:** Claude Code (Senior Developer AI Agent)
**Review Date:** 2025-11-29
**Story Status:** drafted
**Outcome:** ❌ **BLOCKED - NOT IMPLEMENTED**

---

### Summary

This story **cannot be reviewed** because it has not been implemented. The story status is "drafted" with zero code changes, no completed tasks, and no implementation artifacts.

**Required Action:** Execute the `/bmad:bmm:workflows:dev-story` workflow to implement this story before requesting code review.

---

### Review Verification Process

**Files Checked:**
- ✓ Story file: `/Users/andre/coding/daybreak/daybreak-health-backend/docs/sprint-artifacts/3-3-help-and-off-topic-handling.md`
- ✓ Epic context: `/Users/andre/coding/daybreak/daybreak-health-backend/docs/epics.md` (Epic 3, FR9 & FR11)
- ✓ Architecture: `/Users/andre/coding/daybreak/daybreak-health-backend/docs/architecture.md`
- ✗ Implementation files: None found (expected)

**Implementation Status Verification:**
```bash
# Checked for expected service files
app/services/ai/intent_classifier.rb          → NOT FOUND
app/services/ai/prompts/help_responses.rb     → NOT FOUND
app/services/ai/context_manager.rb            → NOT FOUND

# Checked for directory structure
app/services/ai/                               → DOES NOT EXIST
app/graphql/mutations/conversation/            → DOES NOT EXIST

# Git status check
No tracked changes related to Story 3.3
```

**Task Completion Status:**
- Task 1: Intent Classification Service → 0/5 subtasks complete
- Task 2: Help Response Templates → 0/5 subtasks complete
- Task 3: Off-Topic Detection → 0/6 subtasks complete
- Task 4: System Prompts Update → 0/5 subtasks complete
- Task 5: Analytics Tracking → 0/5 subtasks complete
- Task 6: SendMessage Integration → 0/5 subtasks complete
- Task 7: Testing & Validation → 0/5 subtasks complete

**Total: 0/36 subtasks completed (0%)**

---

### Outcome Justification

**BLOCKED** - Story is in "drafted" status with zero implementation:
- All 7 tasks and 36 subtasks marked incomplete `[ ]`
- Dev Agent Record section is empty (no model, no debug logs, no completion notes)
- File List section is empty (no NEW/MODIFIED/DELETED entries)
- Story status is "drafted" (must be "review" or "ready-for-review" for code review)
- No code artifacts exist in repository

---

### Key Findings

#### HIGH SEVERITY

**H1. Story Not Implemented**
- **Description**: Story 3.3 has not been developed. All tasks are incomplete, no code has been written.
- **Evidence**:
  - Status: "drafted"
  - All tasks show `[ ]` (0 of 29 tasks/subtasks completed)
  - File List: Empty (no files created/modified)
  - Completion Notes: Empty
- **Impact**: Cannot perform code review on non-existent implementation
- **Required Action**: Execute `/bmad:bmm:workflows:dev-story` to implement this story

**H2. Incorrect Workflow Invocation**
- **Description**: Code review workflow was invoked on a drafted story instead of a story ready for review
- **Evidence**: Story status field shows "drafted" not "review" or "ready-for-review"
- **Impact**: Wasted review effort on unimplemented story
- **Required Action**: Only invoke code-review workflow on stories with status "review" or "ready-for-review"

---

### Acceptance Criteria Coverage

⚠️ **Cannot validate acceptance criteria - story not implemented**

| AC # | Description | Status | Evidence |
|------|-------------|--------|----------|
| AC1 | AI recognizes question vs. answer intent | NOT IMPLEMENTED | No code found |
| AC2 | Clarifying questions answered with helpful context | NOT IMPLEMENTED | No code found |
| AC3 | Off-topic responses gently redirected | NOT IMPLEMENTED | No code found |
| AC4 | AI acknowledges non-intake concerns | NOT IMPLEMENTED | No code found |
| AC5 | "Why" questions explained with empathy | NOT IMPLEMENTED | No code found |
| AC6 | AI handles various help intents | NOT IMPLEMENTED | No code found |
| AC7 | Conversation returns to intake after addressing concerns | NOT IMPLEMENTED | No code found |
| AC8 | AI never makes parent feel judged or rushed | NOT IMPLEMENTED | No code found |

**Summary**: 0 of 8 acceptance criteria implemented (0% coverage)

---

### Task Completion Validation

⚠️ **Cannot validate task completion - all tasks marked incomplete**

| Task | Marked As | Verified As | Evidence |
|------|-----------|-------------|----------|
| Task 1: Implement Intent Classification Service | INCOMPLETE | CORRECT | No implementation found |
| Task 2: Create Help Response Templates | INCOMPLETE | CORRECT | No implementation found |
| Task 3: Implement Off-Topic Detection and Redirection | INCOMPLETE | CORRECT | No implementation found |
| Task 4: Update System Prompts for Help Handling | INCOMPLETE | CORRECT | No implementation found |
| Task 5: Track Help Requests for Analytics | INCOMPLETE | CORRECT | No implementation found |
| Task 6: Integration with SendMessage Mutation | INCOMPLETE | CORRECT | No implementation found |
| Task 7: Testing and Validation | INCOMPLETE | CORRECT | No implementation found |

**Summary**: 0 of 7 tasks completed, 0 verified, 0 questionable, 0 falsely marked complete

**✅ Good Practice**: All tasks are correctly marked as incomplete, which accurately reflects the story's unimplemented state.

---

### Test Coverage and Gaps

⚠️ **Cannot assess test coverage - no implementation exists**

**Expected Test Files** (based on story requirements):
- `spec/services/ai/intent_classifier_spec.rb`
- `spec/services/ai/prompts/help_responses_spec.rb`
- `spec/graphql/mutations/conversation/send_message_spec.rb` (integration tests)
- `spec/services/ai/context_manager_spec.rb` (state tracking tests)

**Status**: None of these test files exist yet

---

### Architectural Alignment

**Architecture Compliance**: ✅ Story design aligns with architecture

The story's planned implementation matches the architecture document:
- ✅ Service layer pattern: `app/services/ai/intent_classifier.rb`
- ✅ Prompt organization: `app/services/ai/prompts/help_responses.rb`
- ✅ Context manager extension: `app/services/ai/context_manager.rb`
- ✅ GraphQL mutation integration: `app/graphql/mutations/conversation/send_message.rb`
- ✅ Proper use of concerns and service objects
- ✅ Follows Rails conventions (snake_case files, PascalCase classes)

**Notes**: The planned structure in Dev Notes section demonstrates good understanding of the architecture. Once implemented, files should be created in the exact locations specified.

---

### Security Notes

⚠️ **Cannot perform security review - no code to review**

**Future Security Considerations** (for implementation phase):
1. **Intent Classification Security**: Ensure intent classifier cannot be manipulated to bypass validation
2. **Prompt Injection Protection**: Help responses must sanitize any user input included in prompts
3. **PII Handling**: Help interactions may reference sensitive data - ensure logging doesn't expose PII
4. **Analytics Data**: Intent classification results stored in message metadata should be encrypted (message content is PHI)

---

### Best-Practices and References

**Ruby on Rails 7 Best Practices**:
- [Rails Service Objects Pattern](https://www.toptal.com/ruby-on-rails/rails-service-objects-tutorial) - Service layer organization
- [Rails 7 Encryption](https://guides.rubyonrails.org/active_record_encryption.html) - For PHI field encryption
- [GraphQL Ruby Best Practices](https://graphql-ruby.org/schema/class_based_api.html) - Mutation patterns
- [RSpec Best Practices](https://rspec.info/documentation/) - Testing service objects

**AI/LLM Integration**:
- [Anthropic Claude Best Practices](https://docs.anthropic.com/claude/docs/introduction-to-prompt-design) - Prompt engineering
- [OpenAI Best Practices](https://platform.openai.com/docs/guides/prompt-engineering) - Intent classification patterns

**HIPAA Compliance**:
- Ensure all help interactions (which may contain PHI) are encrypted at rest
- Audit log all help requests and intent classifications
- Never log actual message content, only metadata about intents

---

### Action Items

#### Code Changes Required

**⚠️ No code changes to review - story must be implemented first**

#### Pre-Implementation Planning

- [ ] [High] Execute `/bmad:bmm:workflows:dev-story` to implement Story 3.3
- [ ] [High] Ensure story status is updated to "in-progress" during implementation
- [ ] [High] Mark story status as "review" when implementation is complete
- [ ] [Medium] Consider creating Epic 3 tech spec before implementing remaining stories
- [ ] [Medium] Create story context file for better implementation guidance

#### Advisory Notes

- Note: This review detected that the story has not been implemented. No code issues found because no code exists.
- Note: Story structure and acceptance criteria are well-defined and ready for implementation
- Note: Dev Notes section provides good implementation guidance with code examples
- Note: Architecture alignment is excellent - planned structure matches architecture document perfectly
- Note: When implementing, pay special attention to AC8 (empathetic tone) - this is critical for user experience but hard to test automatically

---

### Recommendations for Implementation

When you're ready to implement this story:

1. **Start with Intent Classifier** (Task 1):
   - Create `app/services/ai/intent_classifier.rb` with keyword fallback first
   - Add comprehensive test coverage before integrating with LLM
   - Test with real user messages from parent personas

2. **Build Help Response Library** (Task 2):
   - Start with core fields: email, phone, DOB, medical history
   - Include empathetic phrasing - have examples reviewed by UX
   - Make responses configurable (FR41 - admin can update)

3. **Integration Testing is Critical** (Task 7):
   - Test full conversation flows: question → help → answer → redirect back
   - Test edge cases: repeated help requests, off-topic tangents
   - Validate tone remains empathetic throughout

4. **Metadata Structure** (Task 5):
   - Intent classification results should include confidence scores
   - Track which fields cause most confusion (analytics goldmine)
   - Ensure metadata is encrypted along with message content

---

### Workflow Guidance

**Current Workflow State:**
```
[✓] Story Created (3-3-help-and-off-topic-handling.md)
[✓] Epic Context Available (epics.md, architecture.md)
[✗] Story Implementation ← YOU ARE HERE
[✗] Code Review
[✗] Story Completion
```

**Correct Workflow Sequence:**
1. **Draft Story** → ✅ COMPLETE (this file exists)
2. **Implement Story** → ❌ REQUIRED NEXT (use `/bmad:bmm:workflows:dev-story`)
3. **Review Code** → ⏸️ BLOCKED (cannot review non-existent code)
4. **Mark Complete** → ⏸️ BLOCKED (cannot complete unimplemented story)

---

### Next Steps

**Immediate Actions Required:**

1. **❌ STOP** - Do not proceed with code review on unimplemented story
2. **✅ EXECUTE** - Run `/bmad:bmm:workflows:dev-story` workflow for Story 3.3
3. **⏳ WAIT** - Allow dev-story workflow to complete all 7 tasks
4. **📝 VERIFY** - Confirm story status changed from "drafted" to "review"
5. **🔄 RETRY** - Re-run `/bmad:bmm:workflows:code-review` after implementation

**Implementation Checklist (for dev-story workflow):**
- [ ] Create `app/services/ai/intent_classifier.rb` with tests
- [ ] Create `app/services/ai/prompts/help_responses.rb` with tests
- [ ] Extend `app/services/ai/context_manager.rb` for state tracking
- [ ] Update `app/services/ai/prompts/intake_prompt.rb` with help handling
- [ ] Add analytics tracking for help requests
- [ ] Integrate intent classification into `send_message.rb` mutation
- [ ] Add comprehensive test coverage (RSpec)
- [ ] Update story status to "review"
- [ ] Document changes in File List and Dev Agent Record

---

**Review Status**: ❌ BLOCKED - Story Not Implemented
**Blocker Reason**: Cannot perform code review on non-existent implementation
**Required Action**: Execute `/bmad:bmm:workflows:dev-story` to implement Story 3.3
**Estimated Implementation Time**: 2-4 hours (based on 7 tasks, 36 subtasks)
