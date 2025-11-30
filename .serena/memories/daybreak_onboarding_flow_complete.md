# Daybreak Health - Complete Onboarding Flow Analysis

**Generated:** 2025-11-30  
**Scope:** Full onboarding flow from session creation through insurance submission

---

## 1. ONBOARDING FLOW OVERVIEW

The Daybreak Health onboarding is a **5-step sequential flow** with HIPAA-compliant data storage, AI-guided assessment, and state machine-enforced transitions.

```
START (Home Page)
  ↓
[STEP 1] Assessment Chat (AI-guided conversation)
  ↓
[STEP 2] Demographics - Parent Info (name, email, phone, relationship)
  ↓
[STEP 3] Demographics - Child Info (name, DOB, gender, concerns)
  ↓
[STEP 4] Demographics - Clinical Info (medical history, medications - optional)
  ↓
[STEP 5] Insurance (manual entry + OCR + eligibility verification)
  ↓
Scheduled Matching & Booking (TODO: Future Epic 5)
```

---

## 2. FRONTEND ROUTE STRUCTURE

### Route Hierarchy
```
/onboarding/[sessionId]
├── / (root - welcome page)
├── /assessment (chat conversation)
├── /demographics (multi-step form - URL params control which section)
│   └── ?section=parent (default - parent info)
│   └── ?section=child (child demographics)
│   └── ?section=clinical (clinical intake - optional)
├── /insurance (manual entry + OCR + verification)
├── /match (therapist matching - future)
└── /book (appointment booking - future)
```

### Layout Components
- **OnboardingLayout** (`app/onboarding/[sessionId]/layout.tsx`)
  - Header with logo and "Save & Exit" button
  - Progress bar showing current step (assessment → info → insurance → match → book)
  - Main content area (max-width 640px, centered)
  - Footer with legal links
  - ErrorBoundary for error handling
  - Tracks completed steps based on current route pathname

### Route-to-Step Mapping
```typescript
const ROUTE_TO_STEP = {
  assessment: "assessment",
  demographics: "info",
  insurance: "insurance",
  match: "match",
  book: "book"
};
```

---

## 3. ASSESSMENT CHAT FLOW (STEP 1)

### Frontend Components
- **Page:** `app/onboarding/[sessionId]/assessment/page.tsx` (Server component)
- **Client:** `app/onboarding/[sessionId]/assessment/AssessmentClient.tsx`
- **Hook:** `features/assessment/useAssessmentChat.ts` (manages all chat state)

### Chat UI Components
- **ChatWindow** - displays messages with typing indicators
- **ChatBubble** - individual messages (user/AI)
- **MessageInput** - text input + send button
- **QuickReplyChips** - suggested response buttons
- **TypingIndicator** - shows AI is responding
- **AssessmentSummary** - displays summary after completion

### What Happens During Assessment Chat

#### Phase 1: Initial Greeting & Consent
- AI introduces itself and Daybreak
- Requests parent consent to proceed
- Sets up context about what will be discussed

#### Phase 2: Child Information Collection (Adaptive)
- AI asks about child's primary concerns
- Collects key symptoms/challenges
- Adapts questions based on responses
- Uses **intent classification** to detect help requests, off-topic, questions

#### Phase 3: Parent/Family Context
- Questions about parent's role and stress level
- Family dynamics affecting child
- Previous help-seeking attempts

#### Phase 4: Clinical Context (if needed)
- Medical history questions
- Current medications
- School/academic performance
- Social/behavioral concerns

#### Message Flow
1. User sends message → stored in DB with role "user"
2. Backend calls intent classifier (Story 3.3)
3. **Intent types:** answer, question, help_request, off_topic, clarification
4. If help request → enter help mode (provide relevant info)
5. If off-topic → categorize (cost, scheduling, location, general)
6. If escalation detected → flag session for human contact (Story 3.5)
7. Backend calls AI with conversation context and detected intent
8. AI response stored with role "assistant"
9. GraphQL subscription triggers for real-time delivery
10. Frontend receives + displays response

### Assessment Completion
- AI determines when assessment is complete based on information collected
- Session marked as `assessment_complete` in DB
- Summary generated with:
  - Key concerns identified
  - Child's name
  - Recommended focus areas
  - Generated timestamp
- User confirms summary → proceeds to demographics
- Can edit/add more concerns before confirming

### Crisis Detection
- AI detects suicidal ideation or immediate danger
- Session flagged with `needs_human_contact = true`
- Red banner displayed with crisis resources
  - 988 - Suicide & Crisis Lifeline
  - Crisis Text Line (text HELLO to 741741)

### Data Stored in Database
**Table: messages**
- id, onboarding_session_id, role (user/assistant/system), content (encrypted PHI)
- created_at, metadata (intent classification, confidence scores)

**Table: assessments**
- id, onboarding_session_id, responses (encrypted JSON)
- consent_given (boolean), score (0-100)

**Table: onboarding_sessions**
- id, status (started → in_progress), progress (JSONB)
- expires_at (1 hour from now, extended on each activity)
- needs_human_contact (boolean for escalation)
- escalation_requested_at (timestamp)

### Session Expiration & Auto-Extension
- Session expires 24 hours after creation
- Each activity extends expiration by 1 hour
- If user hasn't been active for 1 hour, session expires (backend cleanup)
- Users can request recovery via email link

---

## 4. DEMOGRAPHICS COLLECTION (STEPS 2-4)

### Page Structure
**Page:** `app/onboarding/[sessionId]/demographics/page.tsx` (Client component)

### Section 1: Parent Information
**Route:** `/onboarding/[sessionId]/demographics?section=parent` (default)

**Form Fields:**
- First Name (required, encrypted PHI)
- Last Name (required, encrypted PHI)
- Email (required, validated, encrypted PHI)
- Phone (required, E.164 format, encrypted PHI)
- Relationship (enum: parent, guardian, grandparent, foster_parent, other)
- Is Guardian? (boolean)

**On Submit:**
- Calls mutation: `submitParentInfo(sessionId, parentInfo)`
- Backend validates phone (E.164 format) and email (RFC 5322)
- Creates/updates Parent record linked to session
- Updates session progress: `{ intake: { parentInfoCollected: true } }`
- Extends session expiration by 1 hour
- Queues recovery email job for session resumption
- Navigates to child section

**Data Storage:**
- Table: `parents` (id, onboarding_session_id, first_name, last_name, email, phone, relationship, is_guardian)
- All text fields encrypted at rest

### Section 2: Child Information
**Route:** `/onboarding/[sessionId]/demographics?section=child`

**Form Fields:**
- First Name (required, encrypted PHI)
- Last Name (required, encrypted PHI)
- Date of Birth (required, ISO 8601 YYYY-MM-DD, encrypted PHI)
- Gender (optional, select)
- School Name (optional, text)
- Grade (optional, select)
- Primary Concerns (optional, array/text area, encrypted PHI)
  - Pre-populated from assessment summary if available
  - Extracted from localStorage: `onboarding_session_${sessionId}`

**Age Validation:**
- Child must be 5-18 years old for Daybreak services
- DOB cannot be in future
- Age calculated and stored in DB

**On Submit:**
- Calls mutation: `submitChildInfo(sessionId, childInfo)`
- Backend validates DOB format and age range
- Creates/updates Child record
- Calculates age from DOB
- Updates session progress: `{ intake: { childInfoCollected: true } }`
- Creates audit log with PHI-safe flags (has_first_name, age, etc.)
- Navigates to clinical intake section

**Data Storage:**
- Table: `children` (id, onboarding_session_id, first_name, last_name, date_of_birth, gender, school_name, grade, primary_concerns, medical_history)
- All text fields encrypted at rest

### Section 3: Clinical Intake (Optional)
**Route:** `/onboarding/[sessionId]/demographics?section=clinical`

**Form Fields (all optional):**
- Medical History (text area, encrypted PHI)
  - Can be stored as structured JSON: `{ medications: [], diagnoses: [], hospitalizations: [] }`
- Medications (optional, array, encrypted PHI)
- Previous diagnoses (optional, array, encrypted PHI)
- Hospitalizations (optional, array, encrypted PHI)
- Family history of mental health conditions (optional)
- Current therapy/treatment (optional)

**On Submit:**
- Calls mutation: `submitChildInfo` (same mutation, medical_history passed)
- All fields optional - allows skip
- Navigates to insurance page

**Data Storage:**
- Stored in `children.medical_history` as encrypted JSON
- Can be parsed with `child.parsed_medical_history` method

---

## 5. INSURANCE COLLECTION (STEP 5)

### Page Structure (PLANNED - Under Development)
**Route:** `/onboarding/[sessionId]/insurance`

### Insurance Flow (Multi-stage)

#### Stage 1: Card Image Upload (Optional OCR Path)
- User uploads front and/or back of insurance card
- Images stored in AWS S3 with Active Storage attachment (encrypted with SSE-KMS)
- Verification status: `pending` → triggers OCR processing job

#### Stage 2: OCR Processing (Story 4.2)
- Backend async job extracts fields from images using OCR provider
- Extracted fields: `payer_name`, `member_id`, `group_number`, `subscriber_name`
- Stores raw OCR response + extracted fields + confidence scores
- If any field has low confidence → status: `ocr_needs_review`
- If all good → status: `ocr_complete`
- Pre-populated data stored in `verification_result` JSONB

#### Stage 3: Manual Entry Form (Story 4.3)
**Form Fields:**
- Payer Name (required, select from known list or "Other")
- Member ID (required, 6-20 alphanumeric)
- Group Number (optional, 4-15 alphanumeric)
- Subscriber Name (optional)
- Subscriber DOB (optional, YYYY-MM-DD)

**On Submit:**
- Calls mutation: `submitInsuranceInfo(sessionId, payerName, memberId, groupNumber, ...)`
- Backend validates formats and known payer list
- Tracks data source: `manual` vs `ocr`
- Updates verification status to `manual_entry` or `manual_entry_complete`
- Stores in `verification_result`: `{ data_sources: { field: "manual" }, manual_entry_at: timestamp }`

#### Stage 4: Eligibility Verification (Story 4.4)
- Auto-triggered after manual entry complete OR OCR complete
- Backend calls insurance eligibility API (third-party provider like Change Healthcare, Evernorth, etc.)
- Verification result includes:
  - `eligible` (boolean)
  - `coverage.mental_health_covered` (boolean)
  - `coverage.copay.amount` (float)
  - `coverage.deductible.amount` (float)
  - `coverage.deductible.met` (float)
  - `coverage.coinsurance.percentage` (integer)
  - `coverage.effective_date` (date)
  - `coverage.termination_date` (date)
  - `verified_at` (timestamp)
  - `api_response_id` (for support debugging)
  - `error` (if verification failed)

**Verification Statuses:**
- `pending` - Card uploaded, awaiting OCR
- `in_progress` - OCR processing
- `ocr_complete` - OCR finished, ready for manual review
- `ocr_needs_review` - OCR has low confidence fields
- `manual_entry` - Manual entry in progress
- `manual_entry_complete` - Manual entry complete, ready for verification
- `verified` - Eligibility verified successfully
- `failed` - Eligibility verification failed
- `manual_review` - Needs human review
- `self_pay` - User selected self-pay option

**Self-Pay Option:**
- User can select self-pay to skip insurance verification
- Session status transitions to `insurance_pending`

**Error Handling:**
- Retryable errors (network, timeout): up to 3 retry attempts
- Non-retryable errors (coverage inactive, out of network): fail with message
- High severity errors: no retry suggested
- Stores full retry history with timestamps and previous errors

**Data Storage:**
- Table: `insurances` (id, onboarding_session_id, payer_name, member_id, group_number, subscriber_name, subscriber_dob)
- All fields encrypted PHI except payer_name
- Active Storage: `card_image_front`, `card_image_back` (S3 + SSE-KMS)
- JSONB: `verification_result` (OCR data, eligibility info, errors, retry history)
- Enum: `verification_status` (10 possible values)
- Integer: `retry_attempts` (tracking for Story 4.5)

### Cost Estimation
- After insurance verified, system calculates expected patient cost
- Displayed to user before scheduling
- Query: `getCostEstimate(onboardingSessionId)`
- Returns: copay per session, deductible remaining, notes/disclaimers

---

## 6. BACKEND DATA STORAGE & SCHEMA

### Database Models

#### OnboardingSession (Primary Aggregate Root)
```ruby
# Table: onboarding_sessions
id: uuid (primary key)
status: integer enum (0-6) - state machine enforced
progress: jsonb - tracks intake phase, collected fields
expires_at: datetime - 1 hour from now, extended on each activity
referral_source: string - how parent found Daybreak
role: integer enum - anonymous(0), parent(1), coordinator(2), admin(3), system(4)
needs_human_contact: boolean - escalation flag
escalation_requested_at: datetime - when escalation detected
escalation_reason: text encrypted - explicit user reason for escalation
created_at, updated_at: timestamps

# Associations
has_one :parent (dependent: :destroy)
has_one :child (dependent: :destroy)
has_one :insurance (dependent: :destroy)
has_one :assessment (dependent: :destroy)
has_many :messages (dependent: :destroy)
has_many :audit_logs (dependent: :nullify)
has_many :refresh_tokens (dependent: :destroy)
```

#### Status State Machine (Immutable Transitions)
```
started → in_progress (auto on first progress update)
started → abandoned (explicit)
started → expired (system)
in_progress → insurance_pending (manual, when assessment done)
in_progress → abandoned (explicit)
in_progress → expired (system)
insurance_pending → assessment_complete (manual)
insurance_pending → abandoned (explicit)
insurance_pending → expired (system)
assessment_complete → submitted (manual, when all steps done)
assessment_complete → abandoned (explicit)
assessment_complete → expired (system)
ANY → abandoned (exception - explicit abandonment)
ANY → expired (exception - timeout)
Terminal states (abandoned, expired, submitted) - no further transitions
```

#### Parent
```ruby
# Table: parents
id: uuid (primary key)
onboarding_session_id: uuid (foreign key, not null)
first_name: text encrypted PHI
last_name: text encrypted PHI
email: text encrypted PHI (validated RFC 5322)
phone: text encrypted PHI (E.164 format)
relationship: integer enum (0-4) - parent, guardian, grandparent, foster_parent, other
is_guardian: boolean
created_at, updated_at: timestamps

# Validations
- email: required, RFC 5322 format
- phone: required, E.164 format, phonelib validated
- first_name: required
- last_name: required
- relationship: required
- is_guardian: inclusion [true, false]
```

#### Child
```ruby
# Table: children
id: uuid (primary key)
onboarding_session_id: uuid (foreign key, not null)
first_name: text encrypted PHI
last_name: text encrypted PHI
date_of_birth: string YYYY-MM-DD encrypted PHI
gender: string (optional)
school_name: text (optional)
grade: string (optional)
primary_concerns: text array encrypted PHI
medical_history: text JSON encrypted PHI (optional)
created_at, updated_at: timestamps

# Methods
age - calculated from DOB, cached
parsed_medical_history - parses JSON medical history
set_medical_history(data) - sets from hash

# Validations
- first_name: required
- last_name: required
- date_of_birth: required, not in future, age 5-18
- onboarding_session: required
```

#### Message
```ruby
# Table: messages
id: uuid (primary key)
onboarding_session_id: uuid (foreign key, not null)
role: integer enum (0-2) - user(0), assistant(1), system(2)
content: text encrypted PHI
metadata: jsonb - intent classification, confidence, detected_method, classified_at
created_at: timestamp

# Methods
intent - get stored intent classification
intent_confidence - get confidence score
help_request? - check if intent is help request
off_topic? - check if intent is off-topic
question? - check if intent is question
store_intent(intent_result) - stores classification in metadata
```

#### Assessment
```ruby
# Table: assessments
id: uuid (primary key)
onboarding_session_id: uuid (foreign key, not null)
responses: jsonb encrypted PHI - all assessment answers
consent_given: boolean - parent consent flag
score: integer (0-100, optional) - assessment severity score
created_at, updated_at: timestamps

# Validations
- responses: required
- consent_given: inclusion [true, false]
- onboarding_session: required
- score: integer, 0-100, optional
```

#### Insurance
```ruby
# Table: insurances
id: uuid (primary key)
onboarding_session_id: uuid (foreign key, not null)
payer_name: string
member_id: string encrypted PHI (6-20 alphanumeric)
group_number: string encrypted PHI (4-15 alphanumeric, optional)
policy_number: string encrypted PHI
subscriber_name: string encrypted PHI
subscriber_dob: date encrypted PHI
verification_status: integer enum (0-9) - 10 statuses (see above)
verification_result: jsonb - OCR, eligibility, errors, retry history
retry_attempts: integer (tracking for retries, default 0)
created_at, updated_at: timestamps

# Active Storage
card_image_front - S3 (SSE-KMS encrypted)
card_image_back - S3 (SSE-KMS encrypted)
(Purged automatically after verification complete)

# Methods
ocr_data, ocr_extracted, ocr_confidence - getters for OCR fields
ocr_low_confidence_fields - fields needing review
needs_ocr_review? - check if review needed
ocr_processed?, ocr_completed_at, ocr_error - OCR status
pre_populate_from_ocr - returns extracted fields for form
eligibility_verified?, eligibility_failed?, needs_eligibility_review? - status checks
eligible?, mental_health_covered?, copay_amount, deductible_amount, coinsurance_percentage - coverage getters
coverage_effective_date, coverage_termination_date - coverage dates
error_category, error_message - error info
can_retry_verification? - check if retryable
increment_retry_attempts!, error_severity_level, max_retry_attempts, record_retry_history - retry logic
cached_result_valid? - 24-hour cache check
verified_at, eligibility_response_id - verification info
front_image_url(expires_in), back_image_url(expires_in) - presigned S3 URLs
```

#### AuditLog
```ruby
# Table: audit_logs
id: uuid (primary key)
onboarding_session_id: uuid (foreign key, optional)
action: string - SESSION_CREATED, MESSAGE_SENT, AI_RESPONSE, PARENT_INFO_SUBMITTED, CHILD_INFO_SUBMITTED, INSURANCE_MANUAL_ENTRY, ESCALATION_DETECTED, SESSION_ABANDONED, etc.
resource: string - OnboardingSession, Message, Parent, Child, Insurance
resource_id: uuid - which record was modified
details: jsonb - context-specific info (never PHI)
ip_address: string
user_agent: string
created_at: timestamp
```

#### RefreshToken
```ruby
# Table: refresh_tokens
id: uuid (primary key)
onboarding_session_id: uuid (foreign key, not null)
device_fingerprint: string - SHA256 of device identifiers
ip_address: string
user_agent: string
is_revoked: boolean
created_at, updated_at: timestamps
expires_at: datetime
```

---

## 7. BACKEND API ENDPOINTS

### GraphQL Mutations (Resolvers)

#### Session Management
- `createSession(referralSource?, deviceFingerprint?)` → returns `{ session, token, refreshToken }`
  - Creates anonymous session with status "started"
  - Session expires in 24 hours
  - Token expires in 1 hour (configurable via ENV)
  - Refresh token generated for device
  - Audit log created

- `abandonSession(sessionId)` → returns `{ success, session, previousStatus }`
  - Idempotent - abandoning already abandoned is no-op
  - Data retained (90-day policy)
  - Audit log created with previousStatus
  - Optional: triggers abandonment reminder notification

- `requestRecovery(email)` → returns `{ success, recoveryToken }`
  - Emails session recovery link
  - Token valid for 1 hour
  - Allows resuming session without account

- `updateSessionProgress(sessionId, progress)` → returns `{ session, success }`
  - Updates progress JSONB field
  - Auto-transitions status from "started" to "in_progress"
  - Extends session expiration

- `requestHumanContact(sessionId, reason?)` → returns `{ success, session }`
  - Marks `needs_human_contact = true`
  - Sets `escalation_requested_at`
  - Stores optional `escalation_reason` (encrypted)
  - Triggers care team notification async job
  - Creates audit log with escalation detection info

#### Authentication
- `refreshToken(refreshToken)` → returns `{ token, newRefreshToken }`
  - Validates refresh token is not revoked
  - Device fingerprint matches
  - Generates new access token
  - Optionally generates new refresh token

#### Conversation/Assessment
- `sendMessage(sessionId, content)` → returns `{ userMessage, assistantMessage, errors }`
  - Stores user message with encrypted content
  - Classifies intent (answer, question, help_request, off_topic)
  - Detects escalation phrases (Story 3.5)
  - Calls AI service with conversation context + detected intent
  - Stores AI response
  - Extends session expiration
  - Triggers GraphQL subscription for real-time delivery
  - Creates audit logs (MESSAGE_SENT, AI_RESPONSE)
  - Returns both messages for UI optimistic update

#### Demographics/Intake
- `submitParentInfo(sessionId, parentInfo)` → returns `{ parent, errors }`
  - Input: `{ firstName, lastName, email, phone, relationship, isGuardian }`
  - Validates: email RFC 5322, phone E.164 (Phonelib)
  - Creates/updates Parent record
  - Updates session progress: `{ intake: { parentInfoCollected: true } }`
  - Extends session expiration
  - Queues recovery email
  - Creates audit log
  - Returns parent or validation errors

- `submitChildInfo(sessionId, childInfo)` → returns `{ child, session, errors }`
  - Input: `{ firstName, lastName, dateOfBirth, gender?, schoolName?, grade?, primaryConcerns?, medicalHistory? }`
  - Validates: DOB format (ISO 8601), age 5-18, not in future
  - Creates/updates Child record
  - Updates session progress: `{ intake: { childInfoCollected: true } }`
  - Creates audit log with PHI-safe flags
  - Returns child + updated session or validation errors

#### Insurance
- `submitInsuranceInfo(sessionId, payerName, memberId, groupNumber?, subscriberName?, subscriberDob?)` → returns `{ insurance, prePopulatedFromOcr, errors }`
  - Validates: member_id format (6-20 alphanumeric), group_number format (4-15), payer in known list
  - Creates/updates Insurance record
  - Tracks data source (manual vs OCR pre-populated)
  - Sets status to `manual_entry_complete` if all required fields present
  - Creates audit log
  - Can be called multiple times for partial saves

- `uploadInsuranceCard(sessionId, frontImage, backImage?)` → returns `{ insurance, uploadedAt }`
  - Stores images in AWS S3 with Active Storage (SSE-KMS encrypted)
  - Sets verification_status to `pending`
  - Triggers async OCR processing job
  - Returns insurance record with image URLs

- `verifyInsuranceEligibility(sessionId, memberId, groupNumber?, payerName)` → returns `{ insurance, verified, errors }`
  - Calls third-party eligibility API
  - Stores full result in verification_result JSONB
  - Sets status to `verified` or `failed`
  - 24-hour cache of verification results
  - Retry logic: up to 3 retries, respects retryable flag, checks error severity

#### Booking/Matching (TODO - Future)
- `getAvailableTherapists(sessionId, filters?)` → returns `{ therapists, count }`
- `scheduleAppointment(sessionId, therapistId, timeSlot)` → returns `{ appointment, confirmationId }`
- `requestTherapistReschedule(appointmentId, reason)` → returns `{ success }`

### GraphQL Subscriptions
- `messageReceived(sessionId)` - Real-time message delivery when AI responds
- `sessionUpdated(sessionId)` - Session status changes
- `progressUpdated(sessionId)` - Progress tracking updates
- `insuranceStatusChanged(sessionId)` - Insurance verification status changes

### GraphQL Queries
- `getOnboardingSession(id)` → returns full session + related data
- `me()` → returns current user (if authenticated)
- `getAvailableSlots(therapistId?, startDate?, endDate?)` → returns available time slots
- `getCostEstimate(onboardingSessionId)` → returns `{ copayPerSession, deductibleRemaining, notes }`

---

## 8. FRONTEND API INTEGRATION

### Apollo Client Setup
- Configured with `@apollo/client@v4.0.9`
- GraphQL WebSocket support via `graphql-ws@v6.0.6`
- Code generation with `graphql-code-generator@v5-6`

### Key Apollo Configuration (`lib/apollo/client.ts`)
- HTTP endpoint: `process.env.NEXT_PUBLIC_API_URL` (default: http://localhost:3000/graphql)
- WS endpoint: `process.env.NEXT_PUBLIC_WS_URL` (default: ws://localhost:3000/cable)
- Auth token stored in localStorage: `daybreak_auth_token`
- Refresh token stored in localStorage: `daybreak_refresh_token`
- Automatic token injection in GraphQL headers
- GraphQL subscriptions via WebSocket

### Key Hooks & Custom Hooks

#### useOnboardingSession (Session State)
- Fetches session data from backend
- Checks if user is returning (session exists in localStorage)
- Restores session from recovery token if provided
- Used for: parent email pre-fill, session recovery, progress tracking

#### useAutoSave (Persistence Layer)
- Auto-saves assessment chat messages to backend
- Tracks save status (idle, saving, saved, error)
- Retry mechanism for failed saves
- Persists to both backend + localStorage

#### useAssessmentChat (Assessment State Machine)
- Main hook for assessment chat management
- Message state with optimistic updates
- Session loading + restoration
- Mode switching (chat ↔ structured questions)
- Answer history for back navigation
- Crisis detection state
- Assessment completion logic
- Summary generation + confirmation flow
- Mutations for completing, confirming, resetting assessment
- Real-time message reception via GraphQL subscription
- Error handling + retry logic

#### useDemographicsForm (Demographics Validation)
- Validates parent info, child info, clinical intake forms
- Uses Zod schemas for runtime validation
- Error reporting with field-level granularity
- Form state management + submission handling

#### useInsuranceFlow (Insurance State Machine)
- Image upload handling (front/back card images)
- OCR processing with polling
- Manual entry form validation
- Eligibility verification status tracking
- Retry management for failed verifications
- Cost estimation loading
- Self-pay selection

---

## 9. WHAT HAPPENS AFTER ASSESSMENT IS COMPLETE

### Frontend Flow
1. **Assessment Marked Complete** - Session status changes to "assessment_complete"
2. **Summary Generated** - AI generates summary with key concerns, child name, recommended focus
3. **User Confirms** - User reviews and confirms summary (or edits concerns)
4. **Confirmation Stored** - Summary confirmation creates audit log
5. **Redirect to Demographics** - Router navigates to `/onboarding/[sessionId]/demographics` (defaults to parent section)

### Backend State Changes
```
Session Status: in_progress → assessment_complete
Progress Update: { assessment: { completed: true, summary_confirmed_at: timestamp } }
Session Expiration: Extended by 1 hour on confirmation
```

### Data Persisted
- Assessment record created with responses (encrypted)
- All messages persisted with timestamps + metadata
- Assessment summary stored (location: TODO - need to determine if in Assessment table or separate Summary table)
- Audit log: ACTION = ASSESSMENT_COMPLETED

### Next Steps in Demographics
1. Parent info collected
2. Child info collected (pre-populated with assessment summary concerns)
3. Optional clinical intake
4. Proceeds to insurance

---

## 10. EXPIRATION & SESSION RECOVERY

### Session Lifecycle
- Created with 24-hour expiration
- Extended 1 hour on any user activity (message, form submit)
- Expires if user inactive for 1+ hours
- Expired sessions cannot be edited, but data is retained

### Recovery Flow
1. User opens saved link: `/onboarding/[sessionId]?recovery_token=xyz`
2. Frontend verifies recovery token on backend
3. Token valid for 1 hour
4. Session restored to user's browser (re-authenticate with JWT)
5. User can resume from last completed step
6. Session expiration extended by 24 hours

### Recovery Email
- Sent to parent email when parent info submitted
- Contains session URL + recovery token
- Valid for 1 hour
- Job: `SessionRecoveryEmailJob`
- Can be resent via "Request Recovery Email" button

---

## 11. ENCRYPTION & SECURITY

### PHI Encryption (At Rest)
- Implemented via `Encryptable` concern in Rails
- Encrypts all `encrypts_phi :field_name` declarations
- Fields encrypted:
  - **OnboardingSession**: escalation_reason
  - **Parent**: email, phone, first_name, last_name
  - **Child**: first_name, last_name, date_of_birth, primary_concerns, medical_history
  - **Message**: content (conversation)
  - **Insurance**: member_id, group_number, policy_number, subscriber_name, subscriber_dob
  - **Assessment**: responses (full questionnaire responses)

### Database Encryption
- PostgreSQL native encryption with PGCrypto extension
- Keys stored in AWS Secrets Manager or similar
- Encrypted fields cannot be searched directly

### Insurance Card Images
- Stored in AWS S3 with bucket-level encryption
- SSE-KMS encryption enabled
- Images auto-purged after verification complete
- Presigned URLs with 15-minute expiry for viewing

### JWT Authentication
- Access tokens expire in 1 hour (configurable)
- Refresh tokens stored securely with device fingerprint
- Tokens validate session_id + role
- GraphQL resolver checks current_session from JWT context

### Audit Logging
- Every action logged with timestamp, IP, user agent
- Contains: action type, resource, resource_id, details (no PHI)
- Immutable (append-only)
- Retention: 90 days (matches session data retention)

---

## 12. FLOW CONTROLLERS & STATE MANAGEMENT

### Frontend State Management
- **React Hooks** for local component state
- **Apollo Client Cache** for GraphQL data + mutations
- **localStorage** for session persistence (recovery)
- **URL Search Params** for demographics section navigation
- **useAutoSave** for chat persistence

### Backend State Management
- **Database Status Enum** - state machine enforcer on OnboardingSession
- **VALID_TRANSITIONS** - immutable transition map
- **Session Concern** - validates transitions, records in audit log
- **Progress JSONB** - tracks which sections completed
- **Verification Status Enum** - for insurance workflow

### Progress Tracking
```json
{
  "assessment": {
    "started_at": "2025-11-30T12:00:00Z",
    "completed_at": "2025-11-30T12:15:00Z",
    "summary_confirmed_at": "2025-11-30T12:16:00Z"
  },
  "intake": {
    "parentInfoCollected": true,
    "parent_collected_at": "2025-11-30T12:17:00Z",
    "childInfoCollected": true,
    "child_collected_at": "2025-11-30T12:20:00Z",
    "clinicalInfoCollected": false
  },
  "insurance": {
    "status": "manual_entry_complete",
    "verification_initiated_at": "2025-11-30T12:25:00Z",
    "verification_completed_at": "2025-11-30T12:30:00Z",
    "verified": true
  }
}
```

---

## 13. KEY FILES & LOCATIONS

### Frontend
**Routes:**
- `/app/onboarding/[sessionId]/page.tsx` - Welcome page
- `/app/onboarding/[sessionId]/assessment/page.tsx` + `AssessmentClient.tsx` - Chat
- `/app/onboarding/[sessionId]/demographics/page.tsx` - Demographics (all 3 sections)
- `/app/onboarding/[sessionId]/layout.tsx` - Layout wrapper

**Features:**
- `/features/assessment/` - All chat components, hook, types
- `/features/demographics/` - Forms for parent, child, clinical intake
- `/features/insurance/` - (TODO) Insurance forms + OCR/verification

**Hooks:**
- `/hooks/useOnboardingSession.ts` - Session loading + recovery
- `/hooks/useAutoSave.ts` - Auto-persistence to backend
- `/features/assessment/useAssessmentChat.ts` - Assessment state machine

**API:**
- `/frontend/api-client.ts` - Example GraphQL client (reference only)
- `/lib/apollo/client.ts` - Actual Apollo Client setup
- `/lib/validations/demographics.ts` - Zod schemas for forms

### Backend
**Models:**
- `/app/models/onboarding_session.rb` - Primary aggregate + state machine
- `/app/models/parent.rb` - Parent/guardian info
- `/app/models/child.rb` - Child demographics + age calc
- `/app/models/message.rb` - Messages + intent tracking
- `/app/models/assessment.rb` - Assessment responses
- `/app/models/insurance.rb` - Insurance + verification logic
- `/app/models/audit_log.rb` - Immutable audit trail
- `/app/models/refresh_token.rb` - Device-specific refresh tokens

**GraphQL:**
- `/app/graphql/mutations/sessions/create_session.rb` - Session creation
- `/app/graphql/mutations/sessions/abandon_session.rb` - Session abandonment
- `/app/graphql/mutations/conversation/send_message.rb` - Message sending + AI integration
- `/app/graphql/mutations/intake/submit_parent_info.rb` - Parent data submission
- `/app/graphql/mutations/intake/submit_child_info.rb` - Child data submission
- `/app/graphql/mutations/insurance/submit_info.rb` - Insurance manual entry
- `/app/graphql/mutations/insurance/upload_card.rb` - Image upload
- `/app/graphql/mutations/insurance/verify_eligibility.rb` - Eligibility check

**Types:**
- `/app/graphql/types/onboarding_session_type.rb` - Session type definition
- `/app/graphql/types/message_type.rb` - Message type
- `/app/graphql/types/insurance_type.rb` - Insurance type
- `/app/graphql/types/parent_type.rb`, `child_type.rb`, `assessment_type.rb`

**Jobs:**
- `SessionRecoveryEmailJob` - Sends recovery email
- `EscalationNotificationJob` - Notifies care team of escalation
- (TODO) `OcrProcessingJob` - Async OCR processing

**Database:**
- `/db/migrate/` - All schema migrations (18 total)
- Schema includes: onboarding_sessions, parents, children, messages, assessments, insurances, audit_logs, refresh_tokens, active_storage_*

---

## 14. OPEN QUESTIONS & TODO ITEMS

### Backend TODO
- [ ] Assessment summary storage location (Assessment table vs separate Summary table)
- [ ] Complete assessment completeness logic (exact AI prompt for determination)
- [ ] Insurance eligibility API integration details (which provider, rate limits, error handling)
- [ ] OCR provider integration (Textract, etc.)
- [ ] Email delivery service (SendGrid, AWS SES, etc.)
- [ ] Care team notification system (Epic 6 integration)
- [ ] Therapist matching algorithm
- [ ] Appointment booking system
- [ ] Cost estimation logic

### Frontend TODO
- [ ] Insurance form implementation (upload, manual entry, OCR display, verification polling)
- [ ] Match page (therapist search, filtering, selection)
- [ ] Book page (calendar, time slot selection, confirmation)
- [ ] Session recovery page (login with recovery token)
- [ ] User account creation (post-onboarding)
- [ ] Session abandonment UI + recovery email sending
- [ ] Cost estimation display + approval flow

### Integration TODO
- [ ] GraphQL schema finalization (currently basic MVP types)
- [ ] Code generation setup (GraphQL-codegen)
- [ ] Apollo Client configuration testing
- [ ] WebSocket subscription testing
- [ ] End-to-end flow testing (all 5 steps)
- [ ] HIPAA compliance verification
- [ ] PII/PHI handling audit
- [ ] Load testing (concurrent sessions)

---

## 15. SUMMARY

The Daybreak Health onboarding is a sophisticated, HIPAA-compliant, multi-step flow:

1. **Assessment Chat** - AI-guided conversation with intent classification + escalation detection
2. **Demographics** - 3-part form collection (parent, child, clinical) with validation + pre-population
3. **Insurance** - OCR + manual entry + eligibility verification with retry logic
4. **Matching** - (TODO) Therapist search + filtering + matching algorithm
5. **Booking** - (TODO) Calendar + appointment scheduling

**Key Technologies:**
- Frontend: Next.js 15, React 19, TypeScript, Apollo Client, Tailwind CSS, shadcn/ui
- Backend: Rails 7, PostgreSQL, GraphQL, Sidekiq (async jobs)
- Infrastructure: AWS (S3, KMS, Secrets Manager, RDS)

**Core Patterns:**
- State machine for session lifecycle + insurance workflow
- Optimistic UI updates for chat + forms
- Auto-saving to backend + localStorage
- Async job processing (emails, OCR, notifications)
- Immutable audit logging
- Encrypted PHI at rest + in transit

**Next Steps:**
- Complete insurance form UI
- Implement insurance eligibility API integration
- Build therapist matching + booking
- Add user account creation (post-onboarding)
- Full end-to-end testing
