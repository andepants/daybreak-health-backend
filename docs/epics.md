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

| Epic | Title | User Value | FRs Covered | Stories | MVP Status |
|------|-------|------------|-------------|---------|------------|
| 1 | Foundation & Infrastructure | Enables all development | Infrastructure | 4 | ✅ Complete |
| 2 | Session Lifecycle & Auth | Parents can start/resume onboarding | FR1-6, FR43, FR47 | 6 | ✅ Complete |
| 3 | Conversational AI Intake | Parents complete AI-guided intake | FR7-18 | 7 | ✅ Complete |
| 4 | Insurance Verification | Parents verify insurance coverage | FR19-25 | 6 | 🔄 In Progress |
| 5 | Clinical Assessment | Child ready for therapist matching | FR26-30 | 5 | ⏸️ DEFERRED |
| 6 | Notifications & Alerts | Team notified of completions/risks | FR34-35 | 5 | ⏸️ DEFERRED |
| 7 | Admin Dashboard | Ops team views pipeline | FR36-38, FR42 | 5 | ⏸️ DEFERRED |
| 8 | Compliance & Data Rights | HIPAA compliance | FR44 | 4 | ⏸️ DEFERRED |

**MVP Total: 4 Epics, 23 Stories** (Epics 1-4 only)

### Deferred to Post-MVP (Epics 5-8)
- **Epic 5:** Clinical Assessment - AI-powered mental health screening (deferred pending scheduling module)
- **Epic 6:** Notifications & Alerts - Email/SMS notifications, care team alerts
- **Epic 7:** Admin Dashboard - Pipeline visibility, search, analytics
- **Epic 8:** Compliance & Data Rights - Audit logging, data export/deletion/archival

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
| FR29 | Consent collection | Epic 5 | 5.5 |
| FR30 | Assessment summary | Epic 5 | 5.4 |
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

## Epic 5: Enhanced Scheduling Module (P0)

**Goal:** Enable AI-assisted therapist matching based on child's needs and assessment data, allowing parents to see recommended therapists and book appointments.

**User Value:** Parents are matched with the most appropriate therapist for their child's specific needs, reducing time to first appointment.

**Priority:** P0 (Must-have)

---

### Story 5.1: Therapist Data Model & Profiles

As a **system**,
I want **to store therapist information including specializations, credentials, and matching criteria**,
So that **the AI can make informed matching recommendations**.

**Acceptance Criteria:**

**Given** the system needs therapist data for matching
**When** therapist profiles are created
**Then**
- Therapist model with fields: name, credentials, specializations[], age_ranges[], treatment_modalities[]
- Specializations include: anxiety, depression, ADHD, trauma, behavioral issues, etc.
- Credentials stored: license type, license number, state, expiration
- Bio and photo URL for parent-facing display
- Active/inactive status for availability
- Languages spoken
- Insurance panels accepted

**And** therapist data can be seeded/imported from existing system
**And** admin can CRUD therapist profiles via GraphQL

**Prerequisites:** Epic 4 complete

**Technical Notes:**
- Create `Therapist` model with proper indexes
- Create `TherapistSpecialization` join table for many-to-many
- GraphQL types: `TherapistType`, `TherapistInput`
- **Test Data:** Use `docs/test-cases/clinicians_anonymized.csv` for seeding therapist profiles
- **Insurance Panels:** Use `docs/test-cases/clinician_credentialed_insurances.csv` joined with `credentialed_insurances.csv` for insurance acceptance

---

### Story 5.2: Availability Management

As a **therapist** (via admin),
I want **my availability to be tracked in the system**,
So that **parents can only book during times I'm available**.

**Acceptance Criteria:**

**Given** therapist profiles exist
**When** availability is configured
**Then**
- Weekly recurring availability slots (day, start_time, end_time)
- Specific date overrides (vacations, blocked times)
- Appointment duration configurable (default 50 min)
- Buffer time between appointments configurable
- Timezone support for therapist location
- Query available slots for date range

**And** availability updates in real-time
**And** no double-booking possible

**Prerequisites:** Story 5.1

**Technical Notes:**
- `TherapistAvailability` model for recurring slots
- `TherapistTimeOff` model for exceptions
- `AvailabilityService` to calculate open slots
- **Test Data:** Use `docs/test-cases/clinician_availabilities.csv` for seeding availability slots
- Consider integration with external calendar (Google Calendar) - post-MVP

---

### Story 5.3: AI Matching Algorithm

As the **system**,
I want **to analyze child assessment data and recommend matching therapists**,
So that **parents receive personalized therapist suggestions**.

**Acceptance Criteria:**

**Given** child information and assessment data exists
**When** matching is requested
**Then**
- AI analyzes: child age, concerns, assessment scores, insurance
- Matching factors weighted:
  - Specialization match to child's concerns (high weight)
  - Age range fit (high weight)
  - Insurance acceptance (required filter)
  - Availability within 2 weeks (preferred)
  - Treatment modality fit
- Returns ranked list of therapists with match scores
- Match reasoning explained for each recommendation
- Minimum 3 recommendations when possible

**And** matching completes within 3 seconds
**And** match scores are explainable to parents

**Prerequisites:** Story 5.1, Story 5.2, Epic 3 (child data)

**Technical Notes:**
- `MatchingService` in `app/services/scheduling/`
- Use LLM for semantic matching of concerns to specializations
- Cache therapist profiles for performance
- Store match results for analytics

---

### Story 5.4: Matching Recommendations API

As a **parent**,
I want **to see recommended therapists with explanations**,
So that **I can make an informed choice about my child's therapist**.

**Acceptance Criteria:**

**Given** onboarding is complete (or insurance verified)
**When** parent requests therapist recommendations
**Then**
- GraphQL query returns matched therapists
- Each recommendation includes:
  - Therapist profile (name, photo, bio, credentials)
  - Match score and reasoning
  - Next available appointment slots (3-5)
  - Specializations relevant to child
- Parent can filter by: availability, gender preference, language
- Parent can request re-matching with different criteria

**And** recommendations personalized to session data
**And** response time < 2 seconds

**Prerequisites:** Story 5.3

**Technical Notes:**
- GraphQL: `therapistRecommendations(sessionId: ID!): [TherapistMatch!]!`
- `TherapistMatchType` includes score, reasoning, availability
- Lazy-load availability slots on expansion

---

### Story 5.5: Booking & Confirmation

As a **parent**,
I want **to book an appointment with my chosen therapist**,
So that **my child can begin therapy**.

**Acceptance Criteria:**

**Given** parent has selected a therapist and time slot
**When** booking is submitted
**Then**
- `bookAppointment` mutation creates appointment
- Slot availability verified (prevent race conditions)
- Appointment stored with: therapist_id, session_id, datetime, duration, status
- Confirmation shown to parent with details
- Session status updated to `APPOINTMENT_BOOKED`
- Therapist notified of new booking (internal)
- Parent receives confirmation (email if available)

**And** booking is atomic (no double-booking)
**And** parent can cancel/reschedule (within policy)

**Prerequisites:** Story 5.4

**Technical Notes:**
- `Appointment` model with proper constraints
- Use database transaction + row locking for slot reservation
- `BookingService` handles confirmation flow
- GraphQL subscription for real-time slot updates

---

## Epic 6: Cost Estimation Tool (P1)

**Goal:** Provide parents with transparent, detailed cost information including insurance estimates, self-pay rates, deductible tracking, and payment options.

**User Value:** Parents understand their financial responsibility upfront, reducing surprise bills and increasing trust.

**Priority:** P1 (Should-have)

---

### Story 6.1: Cost Calculation Engine

As the **system**,
I want **a flexible engine to calculate therapy session costs**,
So that **costs can be computed based on various factors**.

**Acceptance Criteria:**

**Given** session type and payer information
**When** cost calculation is requested
**Then**
- Base rate configurable per session type (intake, individual, family)
- Modifiers for: session duration, therapist tier, special services
- Tax calculations if applicable
- Discount application (promotional, hardship)
- Returns: gross cost, adjustments[], net cost

**And** calculation is deterministic and auditable
**And** rates easily configurable via admin

**Prerequisites:** Epic 4 complete

**Technical Notes:**
- `CostCalculationService` in `app/services/billing/`
- `SessionRate` model for configurable rates
- Store calculation breakdown for transparency
- **Test Data:** Use `docs/test-cases/contracts.csv` for service pricing terms (individual_therapy, family_therapy, etc.)

---

### Story 6.2: Insurance Cost Estimation

As a **parent** with verified insurance,
I want **to see estimated costs based on my coverage**,
So that **I know what I'll pay out of pocket**.

**Acceptance Criteria:**

**Given** insurance is verified (from Epic 4)
**When** cost estimate is requested
**Then**
- Retrieves coverage details: copay, coinsurance, deductible
- Calculates estimated patient responsibility:
  - If deductible not met: full allowed amount until met
  - After deductible: copay or coinsurance applies
- Shows: insurance pays, patient pays, deductible status
- Displays allowed amount vs. billed amount
- Explains any coverage limitations (session limits, prior auth)

**And** estimate clearly marked as estimate (not guarantee)
**And** updated when eligibility data changes

**Prerequisites:** Story 6.1, Epic 4 (eligibility verification)

**Technical Notes:**
- `InsuranceEstimateService` uses eligibility data
- Handle various plan types: HMO, PPO, high-deductible
- Cache estimates with eligibility data
- **Test Data:** Use `docs/test-cases/insurance_coverages.csv` for coverage details and eligibility scenarios
- **Test Data:** Use `docs/test-cases/credentialed_insurances.csv` for payer/network information

---

### Story 6.3: Self-Pay Rates & Comparison

As a **parent** considering self-pay,
I want **to see transparent self-pay pricing and compare to insurance**,
So that **I can make the best financial decision**.

**Acceptance Criteria:**

**Given** parent is viewing cost options
**When** self-pay rates are displayed
**Then**
- Clear self-pay rates per session type
- Comparison table: insurance estimate vs. self-pay
- Highlight when self-pay might be cheaper (high deductible plans)
- Sliding scale information if applicable
- Package pricing options (e.g., 4-session bundle)
- No hidden fees messaging

**And** rates competitive and transparent
**And** easy to switch between insurance and self-pay

**Prerequisites:** Story 6.1, Story 6.2

**Technical Notes:**
- `SelfPayRate` model with effective dates
- Comparison logic in `CostComparisonService`
- GraphQL: `costComparison(sessionId: ID!): CostComparison!`

---

### Story 6.4: Deductible & Out-of-Pocket Tracking

As a **parent**,
I want **to track my deductible progress and out-of-pocket spending**,
So that **I can plan my healthcare expenses**.

**Acceptance Criteria:**

**Given** parent has insurance with deductible
**When** viewing cost information
**Then**
- Current deductible status: amount met, remaining
- Out-of-pocket max tracking: spent, remaining
- Family vs. individual deductible distinction
- Projection: "X more sessions until deductible met"
- Visual progress indicator
- Year reset date shown

**And** data synced with eligibility when available
**And** manual entry option if data not available

**Prerequisites:** Story 6.2

**Technical Notes:**
- `DeductibleTracker` service
- Store snapshots from eligibility checks
- Allow manual override with audit trail
- GraphQL: `deductibleStatus(sessionId: ID!): DeductibleStatus!`

---

### Story 6.5: Payment Plan Options

As a **parent** with financial concerns,
I want **to see payment plan options**,
So that **I can afford care for my child**.

**Acceptance Criteria:**

**Given** estimated costs are calculated
**When** payment options are displayed
**Then**
- Upfront payment option with any discount
- Monthly payment plan: 3, 6, 12 month options
- Calculate monthly amount based on total estimate
- Interest/fee disclosure (if any)
- Financial assistance program information
- Link to apply for hardship consideration
- Payment method options (card, HSA/FSA, bank)

**And** no predatory terms
**And** clear total cost comparison

**Prerequisites:** Story 6.3

**Technical Notes:**
- `PaymentPlanService` calculates options
- `FinancialAssistance` eligibility rules in config
- Store payment plan selection for billing integration
- Note: Actual payment processing is post-MVP

---

## Epic 7: Support Interface (P1)

**Goal:** Provide real-time chat support via Intercom integration, with full session context passed to support staff.

**User Value:** Parents can get immediate help from Daybreak staff without leaving the onboarding flow.

**Priority:** P1 (Should-have)

---

### Story 7.1: Intercom Widget Integration

As a **developer**,
I want **Intercom chat widget integrated into the application**,
So that **parents can access live support**.

**Acceptance Criteria:**

**Given** Intercom account is configured
**When** widget is integrated
**Then**
- Intercom JavaScript SDK installed and initialized
- Widget appears on onboarding pages
- Widget styled to match Daybreak branding
- HIPAA-compliant Intercom plan configured
- Widget can be shown/hidden programmatically
- Mobile-responsive widget behavior

**And** widget loads without blocking page render
**And** graceful degradation if Intercom unavailable

**Prerequisites:** Intercom account with HIPAA BAA

**Technical Notes:**
- Add Intercom SDK to frontend (React/Next.js)
- Backend provides Intercom identity verification
- Environment-based configuration (dev/staging/prod)
- CSP headers updated for Intercom domains

---

### Story 7.2: Session Context Passing

As a **support agent**,
I want **to see the parent's onboarding context when they start a chat**,
So that **I can help them effectively without asking repetitive questions**.

**Acceptance Criteria:**

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

**Prerequisites:** Story 7.1

**Technical Notes:**
- Use Intercom `update` method to pass attributes
- Define standard attribute schema
- Backend endpoint to generate context payload
- Sanitize all data before sending to Intercom

---

### Story 7.3: Support Request Tracking

As a **system**,
I want **to track support requests and link them to onboarding sessions**,
So that **we can analyze support needs and improve the flow**.

**Acceptance Criteria:**

**Given** parent interacts with support
**When** chat is initiated or completed
**Then**
- Support request logged in our database
- Fields: session_id, timestamp, source (widget location), resolved
- Intercom conversation ID stored for reference
- Session flagged as "contacted support"
- Analytics: support requests by onboarding step
- Webhook receives Intercom events (optional)

**And** support patterns inform UX improvements
**And** follow-up possible via session link

**Prerequisites:** Story 7.2

**Technical Notes:**
- `SupportRequest` model
- Intercom webhook integration (conversations.created, etc.)
- Analytics query for support hotspots
- GraphQL: `supportRequests(sessionId: ID!): [SupportRequest!]!`

---

## Test Data Reference

The following test data files in `docs/test-cases/` should be used for seeding and testing:

| File | Purpose | Used By |
|------|---------|---------|
| `clinicians_anonymized.csv` | Therapist profiles, credentials, specializations | Epic 5 (5.1) |
| `clinician_availabilities.csv` | Therapist availability slots | Epic 5 (5.2) |
| `clinician_credentialed_insurances.csv` | Which insurances each therapist accepts | Epic 5 (5.1, 5.3) |
| `credentialed_insurances.csv` | Insurance payer/network definitions | Epic 5, Epic 6 |
| `insurance_coverages.csv` | Patient insurance coverage details | Epic 6 (6.2) |
| `contracts.csv` | Service pricing terms (individual_therapy, family_therapy) | Epic 6 (6.1) |
| `patients_and_guardians_anonymized.csv` | Test patient/parent data | All epics |

---

## Summary

**Current MVP Scope: 7 Epics, 36 Stories**

**Completed Epics:**
1. **Foundation & Infrastructure** (4 stories) ✅ Complete
2. **Session Lifecycle & Auth** (6 stories) ✅ Complete
3. **Conversational AI Intake** (7 stories) ✅ Complete

**In Progress:**
4. **Insurance Verification** (6 stories) 🔄 In Progress

**Upcoming (New):**
5. **Enhanced Scheduling Module** (5 stories) - P0: AI-assisted therapist matching
6. **Cost Estimation Tool** (5 stories) - P1: Detailed cost breakdown with payment plans
7. **Support Interface** (3 stories) - P1: Intercom live chat integration

**Recommended Implementation Order:**
Epic 1 → Epic 2 → Epic 3 → Epic 4 → Epic 5 → Epic 6 → Epic 7

---

_For implementation: Use the `create-story` workflow to generate individual story implementation plans from this epic breakdown._
