# daybreak-health-backend - Epic Breakdown

**Author:** BMad
**Date:** 2025-11-28
**Project Level:** Enterprise Healthcare API
**Target Scale:** HIPAA-compliant pediatric mental health onboarding

---

## Overview

This document provides the complete epic and story breakdown for daybreak-health-backend, decomposing the requirements from the [PRD](./prd.md) into implementable stories.

**Living Document Notice:** This is the initial version created with full context from PRD and Architecture documents.

## Epic Summary

| Epic | Title | User Value | FRs Covered | Stories |
|------|-------|------------|-------------|---------|
| 1 | Foundation & Infrastructure | Enables all development | Infrastructure | 4 |
| 2 | Session Lifecycle & Auth | Parents can start/resume onboarding | FR1-6, FR43, FR47 | 6 |
| 3 | Conversational AI Intake | Parents complete AI-guided intake | FR7-18 | 7 |
| 4 | Insurance Verification | Parents verify insurance coverage | FR19-25 | 6 |
| 5 | Clinical Assessment | Child ready for therapist matching | FR26-30 | 5 |
| 6 | Notifications & Alerts | Parents stay informed, team notified | FR31-35 | 5 |
| 7 | Admin Dashboard | Ops team manages pipeline | FR36-42, FR44 | 5 |
| 8 | Compliance & Data Rights | HIPAA compliance, parent data rights | FR44-46 | 4 |

**Total: 8 Epics, 42 Stories**

---

## Functional Requirements Inventory

### Onboarding Session Management (FR1-FR6)
- **FR1:** System can create a new anonymous onboarding session with unique identifier
- **FR2:** Parents can resume an in-progress session from any device using session recovery
- **FR3:** System automatically saves progress after each interaction
- **FR4:** Sessions expire after configurable period of inactivity with data retention
- **FR5:** Parents can explicitly abandon a session with confirmation
- **FR6:** System tracks session state (started, in-progress, insurance-pending, assessment-complete, submitted)

### Conversational AI Interface (FR7-FR12)
- **FR7:** System presents intake questions through conversational AI interface
- **FR8:** AI adapts follow-up questions based on parent responses
- **FR9:** Parents can ask clarifying questions and receive contextual help
- **FR10:** AI provides progress indicators and estimated time remaining
- **FR11:** System detects and handles off-topic or confused responses gracefully
- **FR12:** Parents can request to speak with a human at any point

### Parent & Child Data Collection (FR13-FR18)
- **FR13:** System collects parent contact information (name, email, phone)
- **FR14:** System collects parent relationship to child and legal guardian status
- **FR15:** System collects child demographic information (name, DOB, gender)
- **FR16:** System collects child's school information
- **FR17:** System captures parent's primary concerns about the child
- **FR18:** System collects relevant medical history with appropriate prompts

### Insurance Processing (FR19-FR25)
- **FR19:** Parents can upload photos of insurance card (front and back)
- **FR20:** System extracts insurance information from card images via OCR
- **FR21:** Parents can manually enter or correct insurance information
- **FR22:** System validates insurance data format and completeness
- **FR23:** System performs real-time insurance eligibility verification
- **FR24:** System communicates verification status and any issues clearly
- **FR25:** Parents can proceed with self-pay option if insurance fails

### Assessment Collection (FR26-FR30)
- **FR26:** System administers standardized screening questions conversationally
- **FR27:** System adapts assessment depth based on initial responses
- **FR28:** System detects risk indicators (self-harm, abuse) and triggers protocols
- **FR29:** System collects consent for treatment and data use
- **FR30:** System generates assessment summary for clinical review

### Notifications & Communication (FR31-FR35)
- **FR31:** System sends confirmation email upon session start
- **FR32:** System sends reminder for abandoned sessions (configurable timing)
- **FR33:** System sends completion confirmation with next steps
- **FR34:** System notifies care team of completed onboarding
- **FR35:** System alerts on detected risk indicators immediately

### Admin & Operations (FR36-FR42)
- **FR36:** Admins can view real-time onboarding pipeline dashboard
- **FR37:** Admins can search and filter sessions by status, date, and attributes
- **FR38:** Admins can view individual session details and progress
- **FR39:** Admins can manually update session status when needed
- **FR40:** System generates daily/weekly onboarding analytics reports
- **FR41:** Admins can configure AI prompts and assessment questions
- **FR42:** System logs all admin actions for audit purposes

### Data & Compliance (FR43-FR47)
- **FR43:** All PHI is encrypted at rest and in transit
- **FR44:** System maintains complete audit log of all data access
- **FR45:** Parents can request export of their submitted data
- **FR46:** System supports data deletion requests with appropriate retention rules
- **FR47:** System enforces role-based access controls on all endpoints

**Total: 47 Functional Requirements**

---

## FR Coverage Map

| FR | Description | Epic | Primary Story |
|----|-------------|------|---------------|
| FR1 | Create anonymous session | Epic 2 | 2.1 |
| FR2 | Resume session from any device | Epic 2 | 2.3 |
| FR3 | Auto-save progress | Epic 2 | 2.2 |
| FR4 | Session expiration | Epic 2 | 2.4 |
| FR5 | Explicit session abandonment | Epic 2 | 2.5 |
| FR6 | Session state tracking | Epic 2 | 2.2 |
| FR7 | Conversational AI interface | Epic 3 | 3.1 |
| FR8 | Adaptive follow-up questions | Epic 3 | 3.2 |
| FR9 | Clarifying questions/help | Epic 3 | 3.3 |
| FR10 | Progress indicators | Epic 3 | 3.4 |
| FR11 | Off-topic handling | Epic 3 | 3.3 |
| FR12 | Human escalation request | Epic 3 | 3.5 |
| FR13 | Parent contact collection | Epic 3 | 3.6 |
| FR14 | Parent relationship/guardian | Epic 3 | 3.6 |
| FR15 | Child demographics | Epic 3 | 3.7 |
| FR16 | Child school info | Epic 3 | 3.7 |
| FR17 | Parent concerns | Epic 3 | 3.7 |
| FR18 | Medical history | Epic 3 | 3.7 |
| FR19 | Insurance card upload | Epic 4 | 4.1 |
| FR20 | OCR extraction | Epic 4 | 4.2 |
| FR21 | Manual insurance entry | Epic 4 | 4.3 |
| FR22 | Insurance validation | Epic 4 | 4.3 |
| FR23 | Eligibility verification | Epic 4 | 4.4 |
| FR24 | Verification status display | Epic 4 | 4.5 |
| FR25 | Self-pay fallback | Epic 4 | 4.6 |
| FR26 | Screening questions | Epic 5 | 5.1 |
| FR27 | Adaptive assessment depth | Epic 5 | 5.2 |
| FR28 | Risk indicator detection | Epic 5 | 5.3 |
| FR29 | Consent collection | Epic 5 | 5.4 |
| FR30 | Assessment summary | Epic 5 | 5.5 |
| FR31 | Session start email | Epic 6 | 6.1 |
| FR32 | Abandoned session reminder | Epic 6 | 6.2 |
| FR33 | Completion confirmation | Epic 6 | 6.3 |
| FR34 | Care team notification | Epic 6 | 6.4 |
| FR35 | Risk alert notification | Epic 6 | 6.5 |
| FR36 | Pipeline dashboard | Epic 7 | 7.1 |
| FR37 | Session search/filter | Epic 7 | 7.2 |
| FR38 | Session detail view | Epic 7 | 7.3 |
| FR39 | Manual status update | Epic 7 | 7.3 |
| FR40 | Analytics reports | Epic 7 | 7.4 |
| FR41 | AI/assessment config | Epic 7 | 7.5 |
| FR42 | Admin action logging | Epic 7 | 7.3 |
| FR43 | PHI encryption | Epic 2 | 2.6 |
| FR44 | Audit logging | Epic 7 | 7.3 |
| FR45 | Data export | Epic 8 | 8.2 |
| FR46 | Data deletion | Epic 8 | 8.3 |
| FR47 | RBAC enforcement | Epic 2 | 2.6 |

**Coverage Validation:** All 47 FRs mapped to epics and stories.

---

## Epic 1: Foundation & Infrastructure

**Goal:** Establish the NestJS project foundation with core patterns, database schema, and deployment pipeline that enables all subsequent development.

**User Value:** Enables all development work - this is the greenfield foundation exception.

**FRs Covered:** Infrastructure supporting all FRs

---

### Story 1.1: Project Scaffolding & Core Setup

As a **developer**,
I want **a properly configured Rails 7 API project with GraphQL**,
So that **I have a consistent foundation for building all features**.

**Acceptance Criteria:**

**Given** no existing project
**When** the project is initialized
**Then**
- Rails 7.x project created in API-only mode with PostgreSQL
- GraphQL configured via graphql-ruby gem
- Project structure matches architecture document (`app/graphql/`, `app/services/`, etc.)
- RuboCop configured with project conventions
- Docker Compose configured for local development
- `.env.example` created with all required environment variables

**And** running `rails server` starts the server on port 3000
**And** GraphiQL accessible at `/graphiql` in development

**Prerequisites:** None (first story)

**Technical Notes:**
- Execute: `rails new daybreak-health-backend --api --database=postgresql --skip-test`
- Install: `bundle add graphql sidekiq redis jwt pundit`
- Execute: `rails generate graphql:install`
- Follow naming conventions from Architecture doc (snake_case files, PascalCase classes)
- Configure `config/initializers/` for encryption and AI providers

---

### Story 1.2: Database Schema & Active Record Models

As a **developer**,
I want **the complete database schema with all core models**,
So that **I can persist onboarding data with proper relationships**.

**Acceptance Criteria:**

**Given** Rails is initialized with PostgreSQL
**When** the migrations are created and run
**Then**
- All models created: OnboardingSession, Parent, Child, Insurance, Assessment, Message, AuditLog
- All enums defined in models: status, verification_status, role
- Proper relationships with foreign keys (1:1 Session→Parent, Session→Child, etc.)
- Indexes on: `sessions.status`, `sessions.created_at`, `audit_logs.onboarding_session_id`
- UUID IDs used for all primary keys
- `created_at` and `updated_at` timestamps on all models

**And** `rails db:migrate` runs successfully
**And** models include associations and validations

**Prerequisites:** Story 1.1

**Technical Notes:**
- Migrations match Architecture doc section "Data Architecture"
- PHI fields stored as encrypted text using Rails 7 encryption
- Use `id: :uuid` in migrations for all tables
- Add Encryptable concern for PHI field encryption

---

### Story 1.3: Common Concerns & Core Patterns

As a **developer**,
I want **reusable concerns, policies, and error handling**,
So that **all modules follow consistent patterns for auth, logging, and error handling**.

**Acceptance Criteria:**

**Given** project scaffold exists
**When** common patterns are implemented
**Then**
- `current_session` helper extracts session from GraphQL context
- Pundit policies for role-based access control
- JWT authentication via `Auth::JwtService`
- `Encryptable` concern for PHI field encryption
- `Auditable` concern for automatic audit logging
- Custom GraphQL error handling with standard codes
- Request timeout middleware (default 30s)

**And** error responses follow standard format: `{ message, extensions: { code, timestamp, path } }`
**And** error codes match Architecture doc: UNAUTHENTICATED, FORBIDDEN, NOT_FOUND, VALIDATION_ERROR, etc.

**Prerequisites:** Story 1.1

**Technical Notes:**
- Implement concerns in `app/models/concerns/`
- Implement services in `app/services/auth/`
- Implement policies in `app/policies/`
- PHI-safe logging (never log actual PHI values, only existence flags)

---

### Story 1.4: Docker & Local Development Environment

As a **developer**,
I want **Docker Compose configuration for local development**,
So that **I can run PostgreSQL and Redis locally without manual setup**.

**Acceptance Criteria:**

**Given** project scaffold exists
**When** Docker configuration is added
**Then**
- `docker-compose.dev.yml` defines PostgreSQL 16.x and Redis 7.x services
- PostgreSQL exposed on port 5432 with persistent volume
- Redis exposed on port 6379
- Health checks configured for both services
- `Dockerfile` created for production builds (multi-stage, Ruby 3.3-alpine)
- `.dockerignore` excludes vendor/bundle, .env, tmp/, log/

**And** `docker-compose -f docker/docker-compose.dev.yml up -d` starts dependencies
**And** Application connects successfully to both services
**And** Sidekiq container configured for background job processing

**Prerequisites:** Story 1.1

**Technical Notes:**
- Use official postgres:16-alpine and redis:7-alpine images
- Configure volumes for data persistence and bundle caching
- Include Aptible Procfile for production deployment
- Match production environment configuration patterns

---

## Epic 2: Session Lifecycle & Authentication

**Goal:** Enable parents to start, save, resume, and manage onboarding sessions with secure authentication.

**User Value:** Parents can begin onboarding from any device and return to it later without losing progress.

**FRs Covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR43, FR47

---

### Story 2.1: Create Anonymous Session

As a **parent**,
I want **to start a new onboarding session without creating an account first**,
So that **I can begin immediately without friction**.

**Acceptance Criteria:**

**Given** a parent visits the onboarding page
**When** they initiate the process
**Then**
- `createSession` mutation creates new OnboardingSession with status `STARTED`
- Session ID is a CUID (e.g., `sess_clx123...`)
- Anonymous JWT token issued with session ID as subject
- Token expires in 1 hour (configurable)
- Session `expiresAt` set to 24 hours from creation
- `progress` JSON initialized as empty object `{}`
- Response includes: `{ session: { id, status, createdAt }, token }`

**And** the session can be queried with the returned token
**And** audit log entry created: `action: SESSION_CREATED`

**Prerequisites:** Epic 1 complete

**Technical Notes:**
- Implement in `app/graphql/mutations/sessions/`
- Use `Auth::JwtService` for token generation
- Token payload: `{ session_id: sessionId, role: 'anonymous' }`
- GraphQL mutation: `createSession(input: CreateSessionInput): SessionResponse!`

---

### Story 2.2: Session Progress & State Management

As a **parent**,
I want **my progress to be saved automatically after each interaction**,
So that **I never lose my work even if I close the browser**.

**Acceptance Criteria:**

**Given** an active session exists
**When** progress is updated via conversation
**Then**
- `updateSessionProgress` mutation updates `progress` JSON field
- Session status transitions: STARTED → IN_PROGRESS (on first progress update)
- `updatedAt` timestamp refreshed
- Session `expiresAt` extended by 1 hour on activity
- Progress is merged (not replaced) with existing data
- GraphQL subscription `sessionUpdated` fires with new state

**And** progress persists across page refreshes
**And** status transitions follow valid state machine (no backward transitions except to ABANDONED)

**Prerequisites:** Story 2.1

**Technical Notes:**
- Status enum defined in OnboardingSession model: started, in_progress, insurance_pending, assessment_complete, submitted, abandoned, expired
- Use Rails cache with Redis backend (1 hour TTL, write-through to DB)
- Implement state machine validation in model or service layer
- Progress structure stored as JSONB: `{ currentStep, completedSteps[], intake: {}, insurance: {}, assessment: {} }`

---

### Story 2.3: Session Recovery & Multi-Device Support

As a **parent**,
I want **to resume my session from a different device**,
So that **I can start on my phone and finish on my computer**.

**Acceptance Criteria:**

**Given** a session exists with parent email collected
**When** the parent requests session recovery
**Then**
- `requestSessionRecovery` mutation sends magic link to email
- Magic link contains time-limited token (15 minutes)
- `sessionByRecoveryToken` query validates token and returns session
- New JWT issued for recovered session
- Previous tokens for this session are NOT invalidated (allow multiple devices)
- Recovery link works only once

**And** parent can continue from exact progress point
**And** audit log: `action: SESSION_RECOVERED, details: { device, ip }`

**Prerequisites:** Story 2.2, Epic 6 Story 6.1 (email service)

**Technical Notes:**
- Recovery token stored in Redis with 15-minute TTL
- Token format: cryptographically secure random string
- Email template: "Continue your Daybreak onboarding" with deep link
- Rate limit: 3 recovery requests per hour per email

---

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

**Prerequisites:** Story 2.2

**Technical Notes:**
- Implement `SessionCleanupJob` in `app/jobs/`
- Use Sidekiq-cron for scheduled job (cron: `*/15 * * * *`)
- Configurable expiration: `SESSION_EXPIRATION_HOURS` env var (default: 24)
- Retention period: `DATA_RETENTION_DAYS` env var (default: 90)

---

### Story 2.5: Explicit Session Abandonment

As a **parent**,
I want **to explicitly abandon my session if I decide not to continue**,
So that **my intent is clear and I can start fresh later if needed**.

**Acceptance Criteria:**

**Given** an active session exists
**When** the parent requests abandonment
**Then**
- Confirmation required before abandonment (client-side)
- `abandonSession` mutation sets status to `ABANDONED`
- Session data retained per policy (same as expiration)
- Parent can create new session immediately
- Abandoned session cannot be resumed
- Response confirms abandonment with session ID

**And** audit log: `action: SESSION_ABANDONED, details: { previousStatus }`

**Prerequisites:** Story 2.2

**Technical Notes:**
- GraphQL mutation: `abandonSession(sessionId: ID!): Session!`
- Requires valid session token (cannot abandon others' sessions)
- Consider triggering FR32 abandoned session reminder workflow

---

### Story 2.6: Authentication & Authorization Foundation

As a **developer**,
I want **JWT authentication and role-based access control implemented**,
So that **all endpoints are properly secured per HIPAA requirements**.

**Acceptance Criteria:**

**Given** the auth module is implemented
**When** requests are made to protected endpoints
**Then**
- JWT validation using RS256 algorithm
- Token refresh mechanism with 7-day refresh tokens
- Roles: `anonymous`, `parent`, `coordinator`, `admin`, `system`
- `@Roles()` decorator enforces permission checks
- Rate limiting: 100 requests/minute for anonymous, 1000 for authenticated
- All PHI fields encrypted at rest using AES-256-GCM
- Encryption key managed via AWS Secrets Manager (or env for local dev)

**And** unauthorized requests return `UNAUTHENTICATED` (401)
**And** forbidden requests return `FORBIDDEN` (403)
**And** audit log captures all authentication events

**Prerequisites:** Story 1.3, Story 2.1

**Technical Notes:**
- Implement `Encryptable` concern for transparent PHI encryption/decryption
- PHI fields: Parent (email, phone, first_name, last_name), Child (first_name, last_name, date_of_birth), etc.
- Use `Auth::JwtService` with JWT gem
- Store refresh tokens in database with device fingerprint

---

## Epic 3: Conversational AI Intake

**Goal:** Enable AI-powered conversational intake that collects parent and child information naturally.

**User Value:** Parents experience a supportive, dialogue-based intake instead of intimidating forms.

**FRs Covered:** FR7, FR8, FR9, FR10, FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18

---

### Story 3.1: Conversational AI Service Integration

As a **parent**,
I want **to interact with an AI assistant that guides me through intake**,
So that **the process feels like a supportive conversation, not form-filling**.

**Acceptance Criteria:**

**Given** a session is active
**When** the parent sends a message
**Then**
- `sendMessage` mutation accepts message content
- Message stored with role `USER` and timestamp
- AI service (Anthropic Claude) called with conversation context
- AI response stored with role `ASSISTANT`
- Response streamed via GraphQL subscription `messageReceived`
- Conversation context maintained across messages (up to 50 messages)

**And** AI response time p95 < 2 seconds
**And** Messages encrypted at rest (PHI)

**Prerequisites:** Epic 2 complete

**Technical Notes:**
- Implement `app/services/ai/client.rb` with provider pattern
- Support Anthropic and OpenAI via agnostic interface
- System prompts in `app/services/ai/prompts/intake_prompt.rb`
- Context window: last 50 messages + session progress summary
- Handle rate limits with exponential backoff via Sidekiq retries

---

### Story 3.2: Adaptive Question Flow

As a **parent**,
I want **the AI to ask relevant follow-up questions based on my responses**,
So that **I only answer what's necessary and the conversation feels natural**.

**Acceptance Criteria:**

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

**Prerequisites:** Story 3.1

**Technical Notes:**
- Context manager tracks: `{ phase, collectedFields[], pendingQuestions[] }`
- Implement in `app/services/ai/context_manager.rb`
- Use structured output prompting to extract data from responses
- Phase transitions update session progress automatically

---

### Story 3.3: Help & Off-Topic Handling

As a **parent**,
I want **to ask clarifying questions and get help when confused**,
So that **I understand what's being asked and feel supported**.

**Acceptance Criteria:**

**Given** the AI conversation is active
**When** parent asks a clarifying question or goes off-topic
**Then**
- AI recognizes question vs. answer intent
- Clarifying questions answered with helpful context
- Off-topic responses gently redirected to intake
- AI acknowledges concerns that aren't intake-related
- "Why do you need this?" questions explained with empathy
- Help intents: "I don't understand", "What does X mean", "Why are you asking"

**And** AI never makes parent feel judged or rushed
**And** Conversation naturally returns to intake after addressing concerns

**Prerequisites:** Story 3.2

**Technical Notes:**
- Intent classification in prompt or via separate classifier
- Canned explanations for common fields (SSN, DOB, etc.)
- Track help requests for analytics (which questions cause confusion)

---

### Story 3.4: Progress Indicators

As a **parent**,
I want **to see how far along I am in the onboarding process**,
So that **I know how much longer it will take**.

**Acceptance Criteria:**

**Given** conversation is in progress
**When** session progress is queried
**Then**
- Progress percentage calculated from completed vs. required fields
- Current phase displayed (e.g., "Child Information")
- Estimated time remaining based on average completion times
- Completed phases shown as checkmarks
- Next phase preview available
- Progress updates in real-time via subscription

**And** progress never goes backward
**And** time estimate adjusts based on actual progress rate

**Prerequisites:** Story 3.2

**Technical Notes:**
- Progress calculation: `{ percentage: number, currentPhase: string, completedPhases: string[], estimatedMinutesRemaining: number }`
- Store average phase durations, update with each completion
- GraphQL: `session.progress { percentage, currentPhase, estimatedMinutesRemaining }`

---

### Story 3.5: Human Escalation Request

As a **parent**,
I want **to request to speak with a human at any point**,
So that **I can get help if the AI isn't meeting my needs**.

**Acceptance Criteria:**

**Given** conversation is active
**When** parent requests human assistance
**Then**
- AI acknowledges request empathetically
- Session flagged for human follow-up: `needsHumanContact: true`
- Contact options provided (phone number, email, chat hours)
- Session continues with AI for data collection if parent agrees
- Care team notified of escalation request (FR34 integration)
- Escalation reason captured if provided

**And** parent never feels trapped in AI-only flow
**And** escalation doesn't lose collected data

**Prerequisites:** Story 3.1, Story 6.4 (care team notification)

**Technical Notes:**
- Detect phrases: "speak to human", "talk to person", "real person", "not a bot"
- Store escalation: `session.escalationRequested: true, escalationReason: string`
- Notification via notification module

---

### Story 3.6: Parent Information Collection

As a **parent**,
I want **to provide my contact information through natural conversation**,
So that **Daybreak can reach me about my child's care**.

**Acceptance Criteria:**

**Given** intake has reached parent information phase
**When** parent provides their details
**Then**
- Fields collected: firstName, lastName, email, phone
- Relationship to child collected (parent, guardian, grandparent, etc.)
- Legal guardian status confirmed (boolean)
- Email validated (RFC 5322 format)
- Phone validated (E.164 format)
- Data extracted from natural language responses
- Confirmation shown before saving

**And** all PHI encrypted before storage
**And** data stored in Parent entity linked to session

**Prerequisites:** Story 3.2

**Technical Notes:**
- Create Parent record when sufficient data collected
- Validation: `class-validator` decorators on DTO
- Email regex: RFC 5322 compliant
- Phone: libphonenumber-js for parsing/validation
- Trigger session recovery email capability once email known

---

### Story 3.7: Child Information Collection

As a **parent**,
I want **to provide my child's information conversationally**,
So that **Daybreak understands who needs care**.

**Acceptance Criteria:**

**Given** parent info is collected
**When** conversation moves to child information
**Then**
- Fields collected: firstName, lastName, dateOfBirth, gender (optional)
- School information: name, grade level (optional)
- Primary concerns captured in parent's own words
- Medical history collected with appropriate prompting
- Age verified (service appropriate range, e.g., 5-18)
- Sensitive topics handled with extra care (trauma, abuse history)
- Multiple children scenario handled (one session per child)

**And** child's age calculated and stored
**And** data stored in Child entity linked to session
**And** concerns stored for clinical review

**Prerequisites:** Story 3.6

**Technical Notes:**
- Create Child record when sufficient data collected
- DOB validation: not in future, within service age range
- Concerns stored as text, also parsed for keywords
- Medical history: structured prompts for medications, diagnoses, hospitalizations
- Gender: optional field with inclusive options

---

## Epic 4: Insurance Verification

**Goal:** Streamline insurance capture and verification to remove the #1 cause of onboarding abandonment.

**User Value:** Parents can verify their insurance coverage quickly and understand their options.

**FRs Covered:** FR19, FR20, FR21, FR22, FR23, FR24, FR25

---

### Story 4.1: Insurance Card Upload

As a **parent**,
I want **to upload photos of my insurance card**,
So that **I don't have to manually type all the details**.

**Acceptance Criteria:**

**Given** intake has reached insurance phase
**When** parent uploads card images
**Then**
- `uploadInsuranceCard` mutation accepts file upload (front and back)
- Images uploaded to S3 with server-side encryption (SSE-KMS)
- Supported formats: JPEG, PNG, HEIC (converted to JPEG)
- Max file size: 10MB per image
- Images stored with session-scoped path: `insurance/{sessionId}/{front|back}.jpg`
- Presigned URL returned for upload confirmation
- Insurance record created with status `PENDING`
- OCR job queued for processing

**And** upload completes within 5 seconds
**And** images auto-deleted after verification complete (30 days max retention)

**Prerequisites:** Epic 3 complete, Story 1.4 (S3 config)

**Technical Notes:**
- Implement in `app/graphql/mutations/insurance/`
- Use Active Storage with S3 backend for uploads
- S3 bucket with HIPAA-compliant configuration
- HEIC conversion via MiniMagick or ImageProcessing gem
- Presigned URLs expire in 15 minutes

---

### Story 4.2: OCR Insurance Card Extraction

As the **system**,
I want **to extract insurance details from card images automatically**,
So that **parents don't need to type information that's on their card**.

**Acceptance Criteria:**

**Given** insurance card images are uploaded
**When** OCR processing runs
**Then**
- AWS Textract analyzes both front and back images
- Extracted fields: payerName, memberId, groupNumber, planType, subscriberName
- Confidence scores returned for each extracted field
- Low-confidence extractions flagged for manual review
- Insurance record updated with extracted data
- Status updated to `OCR_COMPLETE`
- Parent notified to review/confirm extracted data

**And** OCR completes within 10 seconds (p95)
**And** extraction accuracy > 90% for standard card formats

**Prerequisites:** Story 4.1

**Technical Notes:**
- Implement `OcrProcessingJob` in `app/jobs/`
- Use AWS Textract AnalyzeDocument with FORMS feature type
- Custom parser in `app/services/insurance/card_parser.rb`
- Map Textract key-value pairs to insurance fields
- Handle rotated/skewed images

---

### Story 4.3: Manual Insurance Entry & Correction

As a **parent**,
I want **to manually enter or correct my insurance information**,
So that **I can proceed even if OCR isn't accurate or I prefer typing**.

**Acceptance Criteria:**

**Given** insurance phase is active
**When** parent enters insurance data manually
**Then**
- `submitInsuranceInfo` mutation accepts manual entry
- All fields editable: payerName, memberId, groupNumber, subscriberName, subscriberDOB
- Input validation:
  - Member ID: alphanumeric, 6-20 characters
  - Group number: alphanumeric, 4-15 characters
  - Payer name: from known payers list or "Other"
- OCR-extracted values pre-populated if available
- Manual entry overrides OCR values
- Status updated to `MANUAL_ENTRY_COMPLETE`

**And** validation errors shown inline with field
**And** parent can skip and return later

**Prerequisites:** Story 4.1

**Technical Notes:**
- Known payers list stored in config (updatable by admin - FR41)
- Validation in DTO with custom decorators
- Store both OCR and manual values for audit trail

---

### Story 4.4: Real-Time Eligibility Verification

As a **parent**,
I want **to know immediately if my insurance will cover services**,
So that **I understand my financial situation before proceeding**.

**Acceptance Criteria:**

**Given** insurance information is provided
**When** eligibility check is triggered
**Then**
- `verifyEligibility` mutation initiates verification
- External eligibility API called with insurance details
- Results returned: eligible (boolean), copay, deductible, coinsurance
- Coverage details for mental health services specifically
- Verification status updated: VERIFIED, FAILED, MANUAL_REVIEW
- Results cached for 24 hours
- Failure reasons categorized (invalid member, not covered, etc.)

**And** verification completes within 30 seconds
**And** subscription `eligibilityStatusChanged` fires with results

**Prerequisites:** Story 4.3

**Technical Notes:**
- Implement adapter pattern for multiple payers: `app/services/insurance/eligibility/`
- Generic adapter for standard EDI 270/271 transactions
- Sidekiq-based processing with progress updates
- Handle timeouts gracefully with Sidekiq retry

---

### Story 4.5: Verification Status Communication

As a **parent**,
I want **to clearly understand my insurance verification status**,
So that **I know what to do next**.

**Acceptance Criteria:**

**Given** eligibility verification has completed
**When** results are displayed
**Then**
- Clear status: "Verified", "Needs Attention", "Unable to Verify"
- For verified: coverage details shown (copay, services covered)
- For issues: specific problem explained in plain language
- Next steps provided for each status
- Option to correct information and retry
- Support contact provided for complex issues
- Self-pay option always visible as alternative

**And** no insurance jargon without explanation
**And** parent never stuck without a path forward

**Prerequisites:** Story 4.4

**Technical Notes:**
- Status messages in `src/modules/insurance/eligibility/status-messages.ts`
- Map API error codes to user-friendly messages
- Include "Why?" expandable explanations

---

### Story 4.6: Self-Pay Option

As a **parent**,
I want **to proceed with self-pay if insurance verification fails**,
So that **I can still get help for my child regardless of insurance**.

**Acceptance Criteria:**

**Given** insurance verification has failed or parent chooses self-pay
**When** self-pay is selected
**Then**
- `selectSelfPay` mutation marks session as self-pay
- Insurance data retained but marked not-for-billing
- Self-pay rates and payment information provided
- Financial assistance options mentioned if applicable
- Session can proceed to assessment phase
- Payment collection deferred (post-MVP per PRD)

**And** self-pay is not presented as "lesser" option
**And** parent can switch back to insurance if they get new info

**Prerequisites:** Story 4.5

**Technical Notes:**
- Store: `insurance.verificationStatus: SELF_PAY_SELECTED`
- Rate card stored in config
- Financial assistance eligibility criteria in config

---

## Epic 5: Clinical Assessment

**Goal:** Collect standardized mental health screening information conversationally with appropriate safety protocols.

**User Value:** Assessment complete, child is ready to be matched with a therapist.

**FRs Covered:** FR26, FR27, FR28, FR29, FR30

---

### Story 5.1: Conversational Screening Questions

As a **parent**,
I want **to answer mental health screening questions through natural conversation**,
So that **the assessment doesn't feel clinical or intimidating**.

**Acceptance Criteria:**

**Given** insurance phase is complete
**When** assessment begins
**Then**
- AI presents standardized screening questions conversationally
- Standard instruments adapted: PHQ-A, GAD-7 (age-appropriate versions)
- Questions presented one at a time with context
- Likert scale options offered naturally (not as numbered list)
- Responses mapped to standardized scores
- All responses stored for clinical review
- Assessment status: `IN_PROGRESS`

**And** screening feels like caring conversation, not clinical test
**And** all required questions eventually asked

**Prerequisites:** Epic 4 complete

**Technical Notes:**
- Assessment prompts in `src/modules/conversation/ai/prompt-templates/assessment.prompt.ts`
- Store responses in Assessment entity: `responses: JSON`
- Scoring logic in `src/modules/assessment/assessment.service.ts`
- Required questions defined in config (admin-configurable - FR41)

---

### Story 5.2: Adaptive Assessment Depth

As a **parent**,
I want **the assessment to go deeper on relevant concerns**,
So that **Daybreak fully understands my child's needs**.

**Acceptance Criteria:**

**Given** initial screening responses indicate specific concerns
**When** follow-up questions are needed
**Then**
- AI identifies areas requiring deeper exploration
- Additional questions asked for flagged domains (anxiety, depression, trauma, etc.)
- Assessment adapts to child's age and reported issues
- Exploration depth limited to avoid parent fatigue
- Branch logic based on severity scores
- Summary includes areas explored vs. skipped

**And** assessment stays focused on clinically relevant topics
**And** parent can request to skip sensitive areas (logged)

**Prerequisites:** Story 5.1

**Technical Notes:**
- Branching rules in assessment config
- Track: `{ domain, depthLevel, questionsAsked, skipped }`
- Implement skip with acknowledgment: "I understand, we can discuss with therapist"

---

### Story 5.3: Risk Indicator Detection & Protocols

As the **system**,
I want **to detect risk indicators in assessment responses**,
So that **immediate safety protocols can be triggered when needed**.

**Acceptance Criteria:**

**Given** assessment is in progress
**When** risk indicators are detected
**Then**
- Real-time analysis of all responses for risk keywords/patterns
- Risk categories: suicidal ideation, self-harm, abuse, neglect, violence
- Detection triggers immediate protocol:
  1. AI acknowledges with empathy and safety resources
  2. Crisis hotline numbers provided (988, Crisis Text Line)
  3. Session flagged: `riskFlags: ['SELF_HARM_INDICATED']`
  4. Immediate alert to clinical team (FR35)
  5. Session can continue with enhanced monitoring
- False positive handling (asking about past resolved issues)

**And** no response to risk indicator takes > 2 seconds
**And** audit trail of all risk detections and responses

**Prerequisites:** Story 5.1, Story 6.5 (risk alerts)

**Technical Notes:**
- Implement `src/modules/assessment/risk-detector/risk-detector.service.ts`
- Keyword lists + LLM classification for context
- Protocols in `risk-protocols.ts`
- Override: clinical staff can clear false positives

---

### Story 5.4: Treatment Consent Collection

As a **parent**,
I want **to provide consent for my child's treatment and data use**,
So that **Daybreak can legally and ethically proceed with care**.

**Acceptance Criteria:**

**Given** assessment questions are complete
**When** consent is requested
**Then**
- Required consents presented clearly:
  - Consent to treat minor
  - Consent for telehealth services
  - Consent for AI-assisted intake (data processing)
  - HIPAA acknowledgment
  - Privacy policy acceptance
- Each consent captured individually with timestamp
- Guardian status verified (must match FR14)
- Digital signature captured (typed name + checkbox)
- Consents stored with immutable audit trail
- Assessment status: `CONSENT_COLLECTED`

**And** consents presented in plain language
**And** links to full legal documents provided

**Prerequisites:** Story 5.2

**Technical Notes:**
- Store in Assessment: `consents: { type, timestamp, ipAddress, userAgent }`
- Consent text versioned and stored
- Legal review required for consent language (placeholder for now)

---

### Story 5.5: Assessment Summary Generation

As a **clinical reviewer**,
I want **a comprehensive summary of the parent's assessment**,
So that **I can quickly understand the child's situation**.

**Acceptance Criteria:**

**Given** all assessment questions and consent collected
**When** summary is generated
**Then**
- AI generates clinical summary from all responses
- Summary includes:
  - Child demographics and presenting concerns
  - Screening scores with interpretation
  - Risk flags with context
  - Parent quotes for significant concerns
  - Recommended focus areas for therapy
- Summary stored in Assessment entity
- Status updated: `ASSESSMENT_COMPLETE`
- Session status: `ASSESSMENT_COMPLETE`
- Care team notified (FR34)

**And** summary is structured for clinical workflow
**And** AI summary clearly labeled as AI-generated (not diagnosis)

**Prerequisites:** Story 5.4

**Technical Notes:**
- Summary generation in assessment service
- Template: clinical intake summary format
- Include disclaimer: "AI-generated summary for clinical review"
- Trigger session completion flow

---

## Epic 6: Notifications & Alerts

**Goal:** Keep parents informed and notify care team of important events.

**User Value:** Parents stay informed throughout the process; care team is alerted to completed onboarding and risks.

**FRs Covered:** FR31, FR32, FR33, FR34, FR35

---

### Story 6.1: Session Start Email

As a **parent**,
I want **to receive a confirmation email when I start onboarding**,
So that **I have a record and can return to complete it later**.

**Acceptance Criteria:**

**Given** a new session is created with parent email
**When** email is collected
**Then**
- Confirmation email queued immediately
- Email includes:
  - Welcome message with Daybreak branding
  - Session recovery link (magic link)
  - What to expect in onboarding
  - Support contact information
  - Estimated time to complete (10 minutes)
- Email sent via AWS SES
- Delivery tracked and logged

**And** email delivered within 2 minutes
**And** email renders correctly on mobile

**Prerequisites:** Story 3.6 (parent email collected)

**Technical Notes:**
- Implement `app/services/notification/email_service.rb`
- Templates in `app/views/notification_mailer/`
- Use Sidekiq for async sending via Action Mailer
- Track: sent, delivered, bounced, opened (if tracking enabled)

---

### Story 6.2: Abandoned Session Reminder

As a **parent**,
I want **to receive a reminder if I don't complete onboarding**,
So that **I'm encouraged to return and finish**.

**Acceptance Criteria:**

**Given** a session is IN_PROGRESS but inactive
**When** configured reminder threshold is reached
**Then**
- Reminder email sent at configurable intervals:
  - First reminder: 2 hours after last activity
  - Second reminder: 24 hours after last activity
  - Final reminder: 72 hours before expiration
- Email includes:
  - "We noticed you haven't finished..."
  - Progress summary (where they left off)
  - Recovery link
  - Support offer
- No reminder sent if session completed or explicitly abandoned
- Reminder count tracked (max 3)

**And** reminders are helpful, not annoying
**And** unsubscribe option available (marks session preference)

**Prerequisites:** Story 6.1, Story 2.4 (session cleanup knows about reminders)

**Technical Notes:**
- Scheduled job checks for abandoned sessions
- Reminder config in env: `REMINDER_HOURS_1=2`, `REMINDER_HOURS_2=24`, etc.
- Deduplication: don't re-send within 1 hour of activity
- Track: `session.remindersSent: number`

---

### Story 6.3: Completion Confirmation Email

As a **parent**,
I want **to receive confirmation when my onboarding is complete**,
So that **I know what happens next**.

**Acceptance Criteria:**

**Given** assessment is complete and submitted
**When** session status becomes SUBMITTED
**Then**
- Completion email sent immediately
- Email includes:
  - Thank you message
  - Summary of what was submitted (no PHI details)
  - Next steps timeline
  - What to expect (therapist matching, scheduling)
  - Contact information for questions
- Session marked as complete in all systems
- Parent can access read-only summary via link

**And** email delivers within 2 minutes of completion
**And** parent feels confident about next steps

**Prerequisites:** Story 5.5, Story 6.1

**Technical Notes:**
- Trigger from session status change to SUBMITTED
- Template: `completion.template.ts`
- Include secure link to view submission (requires re-auth)

---

### Story 6.4: Care Team Notification

As a **care coordinator**,
I want **to be notified when an onboarding is complete**,
So that **I can begin the therapist matching process**.

**Acceptance Criteria:**

**Given** a session is submitted
**When** care team notification is triggered
**Then**
- Internal notification sent to care team channel/queue
- Notification includes:
  - Session ID and completion timestamp
  - Child's age and primary concerns (summary)
  - Insurance status (verified/self-pay)
  - Any flags (risk indicators, escalation requests)
  - Link to admin session detail view
- Notification methods: email to care team + internal dashboard alert
- Priority elevated if risk flags present

**And** care team receives within 5 minutes of completion
**And** all necessary context provided without clicking through

**Prerequisites:** Story 5.5, Epic 7 Story 7.1 (admin dashboard for context)

**Technical Notes:**
- Care team distribution list in config
- Internal notification via GraphQL subscription to admin dashboard
- Priority: normal (no flags) vs. high (with flags)

---

### Story 6.5: Risk Alert Notification

As a **clinical supervisor**,
I want **to be immediately alerted when risk indicators are detected**,
So that **I can ensure appropriate follow-up and safety**.

**Acceptance Criteria:**

**Given** risk indicators are detected in assessment
**When** risk detection triggers
**Then**
- Immediate alert (not queued) to clinical escalation contacts
- Alert includes:
  - Session ID and timestamp
  - Specific risk indicators detected
  - Context (exact response that triggered)
  - Current session status
  - Parent contact information
  - Direct link to session details
- Multiple channels: email + SMS to on-call + dashboard alert
- Acknowledgment required from recipient
- Escalation if not acknowledged within 15 minutes

**And** alert delivered within 30 seconds of detection
**And** audit trail of alert, delivery, and acknowledgment

**Prerequisites:** Story 5.3

**Technical Notes:**
- Bypass normal queue for immediate delivery
- On-call rotation in config or integration with PagerDuty
- Acknowledgment tracked: `riskAlert.acknowledgedAt, acknowledgedBy`
- Escalation: secondary contact if primary doesn't acknowledge

---

## Epic 7: Admin Dashboard & Analytics

**Goal:** Provide operations team with visibility and control over the onboarding pipeline.

**User Value:** Operations can manage onboarding pipeline, identify issues, and optimize the process.

**FRs Covered:** FR36, FR37, FR38, FR39, FR40, FR41, FR42, FR44

---

### Story 7.1: Real-Time Pipeline Dashboard

As an **admin**,
I want **to see a real-time view of the onboarding pipeline**,
So that **I can understand current volume and identify bottlenecks**.

**Acceptance Criteria:**

**Given** admin is authenticated with appropriate role
**When** they access the dashboard
**Then**
- Dashboard shows:
  - Total sessions by status (funnel visualization data)
  - Sessions started today/this week/this month
  - Completion rate (completed/started)
  - Average time to complete
  - Currently active sessions count
  - Sessions needing attention (stuck, flagged)
- Data refreshes every 30 seconds via subscription
- Filters: date range, status, source

**And** dashboard loads within 2 seconds
**And** only accessible to admin/coordinator roles

**Prerequisites:** Epic 2 (sessions exist)

**Technical Notes:**
- GraphQL queries: `sessionAnalytics(dateRange: DateRangeInput!): Analytics!`
- Aggregation queries optimized with materialized views or Redis cache
- Subscription: `dashboardUpdated`

---

### Story 7.2: Session Search & Filtering

As an **admin**,
I want **to search and filter sessions by various criteria**,
So that **I can find specific sessions or cohorts**.

**Acceptance Criteria:**

**Given** admin is on dashboard
**When** they use search/filter
**Then**
- Search by: session ID, parent email, parent name, child name
- Filter by: status, date range, insurance status, risk flags, source
- Sort by: created date, updated date, status
- Results paginated (20 per page)
- Export results to CSV (limited fields, no PHI in export)
- Saved filter presets supported

**And** search results return within 1 second
**And** PHI fields only visible to authorized roles

**Prerequisites:** Story 7.1

**Technical Notes:**
- GraphQL: `sessions(filter: SessionFilter, pagination: Pagination): SessionConnection!`
- Use Prisma full-text search or dedicated search index
- PHI visibility based on role in resolver

---

### Story 7.3: Session Detail View & Status Management

As an **admin**,
I want **to view full details of a session and update its status if needed**,
So that **I can resolve issues and manage edge cases**.

**Acceptance Criteria:**

**Given** admin selects a session
**When** detail view is accessed
**Then**
- Full session details displayed:
  - Status and timeline
  - Parent and child information (PHI with access logging)
  - Insurance details and verification status
  - Assessment summary and any risk flags
  - Conversation history (collapsed by default)
  - Audit log of all actions on this session
- Manual status update available with reason required
- Notes can be added to session (internal only)
- All views logged to audit trail

**And** status changes require confirmation
**And** audit log entry: `action: ADMIN_STATUS_UPDATE, details: { from, to, reason }`

**Prerequisites:** Story 7.2

**Technical Notes:**
- Mutation: `updateSessionStatus(sessionId: ID!, status: SessionStatus!, reason: String!): Session!`
- Audit every PHI field access, not just mutations
- Internal notes stored separately from parent-visible data

---

### Story 7.4: Analytics & Reporting

As an **operations manager**,
I want **daily and weekly analytics reports**,
So that **I can track trends and make data-driven decisions**.

**Acceptance Criteria:**

**Given** sufficient session data exists
**When** reports are generated
**Then**
- Automated reports generated:
  - Daily summary: sessions started/completed, conversion rate, avg time
  - Weekly summary: trends, comparison to previous week, top issues
- Report includes:
  - Funnel analysis (drop-off points)
  - Insurance verification success rate
  - Average completion time by step
  - Risk flag frequency
  - Top parent concerns (anonymized word cloud data)
- Reports emailed to configured recipients
- Historical reports accessible in dashboard

**And** reports generated at configured time (e.g., 6 AM daily)
**And** data anonymized appropriately for reporting

**Prerequisites:** Story 7.1

**Technical Notes:**
- Scheduled job for report generation
- Store reports as JSON in database for historical access
- Email report as PDF attachment or HTML
- Implement `src/modules/admin/reports/analytics.service.ts`

---

### Story 7.5: AI & Assessment Configuration

As an **admin**,
I want **to configure AI prompts and assessment questions**,
So that **I can iterate on the experience without code changes**.

**Acceptance Criteria:**

**Given** admin has configuration access
**When** they update configuration
**Then**
- Configurable elements:
  - AI system prompts (intake, insurance, assessment)
  - Assessment questions and branching logic
  - Risk detection keywords and thresholds
  - Known insurance payers list
  - Email template content
  - Session timeout durations
- Changes require approval workflow (maker-checker)
- Version history maintained for all configs
- Changes take effect on new sessions (not mid-session)
- Rollback capability to previous version

**And** config changes logged to audit trail
**And** validation prevents invalid configurations

**Prerequisites:** Story 7.3

**Technical Notes:**
- Config stored in database, not files
- Cache config in Redis, invalidate on update
- Approval workflow: changes go to "pending" until approved by different admin
- GraphQL mutations for CRUD on config items

---

## Epic 8: Compliance & Data Rights

**Goal:** Complete HIPAA compliance implementation and enable parent data rights.

**User Value:** Full regulatory compliance, parents can access and control their data.

**FRs Covered:** FR44, FR45, FR46 (FR43, FR47 largely covered in Epic 2)

---

### Story 8.1: Comprehensive Audit Logging

As a **compliance officer**,
I want **complete audit logs of all data access and actions**,
So that **we can demonstrate HIPAA compliance and investigate incidents**.

**Acceptance Criteria:**

**Given** any action occurs in the system
**When** the action involves PHI or security-relevant operations
**Then**
- Audit log entry created with:
  - Timestamp (UTC)
  - User/session ID
  - Action type (CREATE, READ, UPDATE, DELETE)
  - Resource type and ID
  - Relevant details (fields accessed, before/after for updates)
  - IP address and user agent
  - Request ID for correlation
- Logs immutable (append-only)
- Logs retained for 7 years (HIPAA requirement)
- Logs searchable by all fields
- Logs exportable for compliance review

**And** every PHI read is logged, not just writes
**And** log storage encrypted and access-controlled

**Prerequisites:** Story 1.3 (AuditLogInterceptor foundation)

**Technical Notes:**
- AuditLog table partitioned by month
- Archive to S3 Glacier after 1 year
- Implement field-level tracking for PHI
- Consider separate audit database for isolation

---

### Story 8.2: Parent Data Export

As a **parent**,
I want **to export all data I've submitted**,
So that **I can review what Daybreak has about my child**.

**Acceptance Criteria:**

**Given** parent has completed onboarding
**When** they request data export
**Then**
- Export request submitted via authenticated request
- Request queued and processed within 24 hours (HIPAA allows 30 days)
- Export includes:
  - All parent-provided information
  - Child information
  - Insurance information (masked appropriately)
  - Assessment responses
  - Conversation history
  - Consent records
- Export format: JSON or PDF
- Secure download link sent to email (expires in 48 hours)
- Export logged to audit trail

**And** export excludes: internal notes, AI analysis, clinical summaries
**And** identity verification required before export delivered

**Prerequisites:** Epic 5 complete, Story 6.1 (email)

**Technical Notes:**
- Mutation: `requestDataExport(sessionId: ID!): ExportRequest!`
- Background job generates export
- Verification: re-authenticate via magic link before download
- Rate limit: 1 export per session per 24 hours

---

### Story 8.3: Data Deletion Request

As a **parent**,
I want **to request deletion of my data**,
So that **I can exercise my privacy rights**.

**Acceptance Criteria:**

**Given** parent wants to delete their data
**When** deletion request is submitted
**Then**
- Request requires authentication and confirmation
- Request queued for processing
- Compliance team notified to review
- Data eligible for deletion:
  - PHI (parent info, child info)
  - Conversation history
  - Assessment responses
- Data NOT deleted (compliance retention):
  - Audit logs (anonymized reference retained)
  - Consent records (legal requirement)
  - Session metadata (anonymized)
- Deletion completed within 30 days
- Confirmation sent to parent
- Deletion logged to audit trail

**And** partial deletion supported (e.g., keep insurance for billing)
**And** active treatment data subject to clinical review

**Prerequisites:** Story 8.2

**Technical Notes:**
- Mutation: `requestDataDeletion(sessionId: ID!): DeletionRequest!`
- Soft delete with 30-day grace period before hard delete
- Anonymize rather than delete for audit references
- Clinical hold capability: data in active treatment cannot be auto-deleted

---

### Story 8.4: Data Retention & Archival

As the **system**,
I want **to manage data retention according to policy**,
So that **we comply with regulations and minimize data liability**.

**Acceptance Criteria:**

**Given** data exists in the system
**When** retention thresholds are reached
**Then**
- Retention policies applied:
  - Active sessions: indefinite (until completed/expired)
  - Completed sessions: 7 years (HIPAA)
  - Expired/abandoned sessions: 90 days then archive
  - Insurance card images: 30 days then delete
  - Audit logs: 7 years then archive
- Archived data moved to cold storage (S3 Glacier)
- Archived data retrievable within 24 hours if needed
- Deletion job runs weekly
- Retention policy configurable per data type

**And** retention compliant with HIPAA and state laws
**And** deletion logged to audit trail

**Prerequisites:** Story 8.1

**Technical Notes:**
- Scheduled job: `data-retention.processor.ts`
- S3 lifecycle policies for automatic archival
- Restore process documented and tested
- Legal hold capability: pause retention for litigation

---

## FR Coverage Matrix

| FR | Description | Epic | Story | Verified |
|----|-------------|------|-------|----------|
| FR1 | Create anonymous session | 2 | 2.1 | ✓ |
| FR2 | Resume session from any device | 2 | 2.3 | ✓ |
| FR3 | Auto-save progress | 2 | 2.2 | ✓ |
| FR4 | Session expiration | 2 | 2.4 | ✓ |
| FR5 | Explicit session abandonment | 2 | 2.5 | ✓ |
| FR6 | Session state tracking | 2 | 2.2 | ✓ |
| FR7 | Conversational AI interface | 3 | 3.1 | ✓ |
| FR8 | Adaptive follow-up questions | 3 | 3.2 | ✓ |
| FR9 | Clarifying questions/help | 3 | 3.3 | ✓ |
| FR10 | Progress indicators | 3 | 3.4 | ✓ |
| FR11 | Off-topic handling | 3 | 3.3 | ✓ |
| FR12 | Human escalation request | 3 | 3.5 | ✓ |
| FR13 | Parent contact collection | 3 | 3.6 | ✓ |
| FR14 | Parent relationship/guardian | 3 | 3.6 | ✓ |
| FR15 | Child demographics | 3 | 3.7 | ✓ |
| FR16 | Child school info | 3 | 3.7 | ✓ |
| FR17 | Parent concerns | 3 | 3.7 | ✓ |
| FR18 | Medical history | 3 | 3.7 | ✓ |
| FR19 | Insurance card upload | 4 | 4.1 | ✓ |
| FR20 | OCR extraction | 4 | 4.2 | ✓ |
| FR21 | Manual insurance entry | 4 | 4.3 | ✓ |
| FR22 | Insurance validation | 4 | 4.3 | ✓ |
| FR23 | Eligibility verification | 4 | 4.4 | ✓ |
| FR24 | Verification status display | 4 | 4.5 | ✓ |
| FR25 | Self-pay fallback | 4 | 4.6 | ✓ |
| FR26 | Screening questions | 5 | 5.1 | ✓ |
| FR27 | Adaptive assessment depth | 5 | 5.2 | ✓ |
| FR28 | Risk indicator detection | 5 | 5.3 | ✓ |
| FR29 | Consent collection | 5 | 5.4 | ✓ |
| FR30 | Assessment summary | 5 | 5.5 | ✓ |
| FR31 | Session start email | 6 | 6.1 | ✓ |
| FR32 | Abandoned session reminder | 6 | 6.2 | ✓ |
| FR33 | Completion confirmation | 6 | 6.3 | ✓ |
| FR34 | Care team notification | 6 | 6.4 | ✓ |
| FR35 | Risk alert notification | 6 | 6.5 | ✓ |
| FR36 | Pipeline dashboard | 7 | 7.1 | ✓ |
| FR37 | Session search/filter | 7 | 7.2 | ✓ |
| FR38 | Session detail view | 7 | 7.3 | ✓ |
| FR39 | Manual status update | 7 | 7.3 | ✓ |
| FR40 | Analytics reports | 7 | 7.4 | ✓ |
| FR41 | AI/assessment config | 7 | 7.5 | ✓ |
| FR42 | Admin action logging | 7 | 7.3 | ✓ |
| FR43 | PHI encryption | 2 | 2.6 | ✓ |
| FR44 | Audit logging | 8 | 8.1 | ✓ |
| FR45 | Data export | 8 | 8.2 | ✓ |
| FR46 | Data deletion | 8 | 8.3 | ✓ |
| FR47 | RBAC enforcement | 2 | 2.6 | ✓ |

**Coverage: 47/47 FRs (100%)**

---

## Summary

This epic breakdown transforms the 47 functional requirements from the Daybreak Health Backend PRD into **8 epics with 42 stories**, each sized for single dev agent implementation sessions.

**Epic Structure:**
1. **Foundation & Infrastructure** (4 stories) - Greenfield setup enabling all development
2. **Session Lifecycle & Auth** (6 stories) - Parents can start/resume onboarding securely
3. **Conversational AI Intake** (7 stories) - AI-guided data collection
4. **Insurance Verification** (6 stories) - Streamlined insurance capture and verification
5. **Clinical Assessment** (5 stories) - Screening with risk detection
6. **Notifications & Alerts** (5 stories) - Communication throughout the process
7. **Admin Dashboard** (5 stories) - Operations visibility and control
8. **Compliance & Data Rights** (4 stories) - HIPAA compliance and parent rights

**Key Design Decisions:**
- Each epic delivers user value (not technical layers)
- Stories are vertically sliced for independent deployment
- BDD acceptance criteria enable automated testing
- Architecture document patterns referenced throughout
- Prerequisites ensure logical build order
- Technical notes provide implementation guidance

**Recommended Implementation Order:**
Epic 1 → Epic 2 → Epic 3 → Epic 4 → Epic 5 → Epic 6 → Epic 7 → Epic 8

Epics 6-8 can partially parallel Epics 4-5 after Epic 3 is complete.

---

_For implementation: Use the `create-story` workflow to generate individual story implementation plans from this epic breakdown._

_This document includes interaction details and technical decisions from the Architecture document._
