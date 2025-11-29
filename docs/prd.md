# Daybreak Health Backend - Product Requirements Document

**Author:** BMad
**Date:** 2025-11-28
**Version:** 1.0

---

## Executive Summary

The Parent Onboarding AI Backend is a GraphQL-based API service that powers Daybreak Health's next-generation parent onboarding experience. The system transforms a traditionally friction-heavy process—enrolling children in mental health services—into a streamlined, AI-assisted journey that reduces drop-off rates and accelerates time-to-care.

The backend serves as the intelligent core that orchestrates AI-powered assessments, simplifies insurance data capture, and provides real-time conversational support to parents navigating a stressful and unfamiliar process. Built as a greenfield system with a decoupled architecture, it enables rapid iteration while maintaining the security and compliance posture required for pediatric mental health data.

### What Makes This Special

**The Critical Moment:** Parents seeking mental health help for their children are often in crisis, overwhelmed, and time-constrained. Every friction point in onboarding represents a family that might give up—a child who doesn't get help.

This backend eliminates friction through:
- **AI-First Assessment:** Conversational AI guides parents through intake, replacing intimidating forms with natural dialogue
- **Insurance Intelligence:** Automated verification and simplified data entry reduce the #1 cause of onboarding abandonment
- **Real-Time Support:** Parents never feel lost—the system anticipates needs and provides contextual assistance
- **Speed to Care:** What traditionally takes days compresses to minutes, getting children into therapy faster

---

## Project Classification

**Technical Type:** API Backend (GraphQL)
**Domain:** Healthcare (Pediatric Mental Health)
**Complexity:** High

This is a healthcare backend service handling protected health information (PHI) for minors. The system operates at the intersection of multiple high-sensitivity domains:

- **Mental Health:** Requires careful handling of sensitive psychological information
- **Pediatric Data:** Additional protections for children's information (COPPA considerations)
- **Insurance/Financial:** PII and financial data from insurance processing
- **AI/ML:** Conversational AI and assessment algorithms require validation and explainability

### Domain Context

**Regulatory Landscape:**
- **HIPAA:** All patient data (PHI) must be encrypted, access-controlled, and audit-logged
- **COPPA:** Children under 13 require verifiable parental consent; data minimization required
- **State Mental Health Laws:** Varying requirements for minor consent and parental access by state
- **Insurance Regulations:** Compliance with payer requirements for eligibility verification

**Key Compliance Requirements:**
- Business Associate Agreements (BAAs) with all vendors handling PHI
- Minimum necessary standard for data access
- Complete audit trails for all PHI access
- Breach notification procedures
- Data retention and destruction policies

**Clinical Considerations:**
- AI assessments must not replace clinical judgment—they inform and streamline, not diagnose
- Clear boundaries between administrative AI and clinical decision support
- Escalation paths when AI detects risk indicators

---

## Success Criteria

**Primary Success Metric:** Onboarding completion rate increases from baseline to 80%+ within first quarter of launch.

**What Winning Looks Like:**

1. **Parents Complete Onboarding:** A parent starting the process finishes it—no drop-offs due to confusion, frustration, or complexity
2. **Children Get Care Faster:** Time from "parent decides to seek help" to "child's first therapy session scheduled" decreases by 50%+
3. **Insurance Isn't a Barrier:** Insurance verification no longer causes abandonment; parents feel supported not blocked
4. **AI Feels Helpful, Not Cold:** Parents report the AI assistant made them feel understood, not processed

**Measurable Outcomes:**
- Onboarding completion rate: >80%
- Average time to complete onboarding: <10 minutes
- Insurance verification success rate: >90%
- Parent satisfaction (post-onboarding survey): >4.5/5
- Zero HIPAA/compliance incidents

### Business Metrics

| Metric | Target | Why It Matters |
|--------|--------|----------------|
| Conversion Rate | 80%+ | Every completed onboarding = child getting help |
| Time to First Appointment | <48 hours | Speed to care is clinical outcome |
| Support Ticket Volume | -60% | AI handles common questions |
| Insurance Rejection Rate | <10% | Clean data = fewer denials |
| Cost per Onboarding | -40% | Efficiency enables serving more families |

---

## Product Scope

### MVP - Minimum Viable Product

**Core Capability:** A parent can complete the entire onboarding process through a conversational AI interface, with their insurance verified and their child ready to be matched with a therapist.

**MVP Features:**

1. **Conversational Intake Flow**
   - AI-guided collection of parent and child information
   - Natural language interaction (not form-filling)
   - Smart follow-up questions based on responses
   - Progress persistence (can pause and resume)

2. **Insurance Data Capture**
   - Guided insurance card photo upload
   - OCR extraction of insurance details
   - Manual entry fallback with field validation
   - Real-time eligibility verification

3. **Basic Assessment Collection**
   - Parent-reported child symptoms/concerns
   - Structured but conversational assessment questions
   - Risk indicator detection with escalation

4. **Session Management**
   - Secure session handling with timeout
   - Progress saving and restoration
   - Multi-device continuity

5. **Admin Visibility**
   - Dashboard showing onboarding pipeline
   - Stuck/abandoned session alerts
   - Basic analytics on completion rates

**MVP Boundaries (Explicitly NOT in MVP):**
- Therapist matching algorithm
- Appointment scheduling
- Payment processing
- Mobile native app (web responsive only)
- Multi-language support
- Parent portal post-onboarding

### Growth Features (Post-MVP)

**Phase 2 - Enhanced Intelligence:**
- Advanced NLP for free-form parent concerns
- Predictive insurance issue detection
- Smart therapist matching recommendations
- Automated follow-up for abandoned sessions

**Phase 3 - Ecosystem Integration:**
- Direct insurance API integrations (beyond eligibility)
- EHR system integration
- Referring provider portal
- Multi-language support (Spanish priority)

**Phase 4 - Advanced Capabilities:**
- Voice-based onboarding option
- Real-time chat support escalation
- Parent mobile app
- Outcomes tracking integration

### Vision (Future)

The Parent Onboarding AI becomes the trusted first point of contact for any family seeking mental health support for their child. It expands beyond Daybreak to serve as a universal intake system that:

- Understands each family's unique situation through empathetic AI
- Connects families to the right care regardless of payer or provider network
- Reduces systemic barriers to pediatric mental health access
- Serves as a model for how healthcare onboarding should feel

---

## Domain-Specific Requirements

### HIPAA Compliance Requirements

| Requirement | Implementation |
|-------------|----------------|
| PHI Encryption at Rest | AES-256 encryption for all stored PHI |
| PHI Encryption in Transit | TLS 1.3 for all data transmission |
| Access Controls | Role-based access with minimum necessary principle |
| Audit Logging | Complete audit trail of all PHI access |
| BAA Coverage | All third-party services must have signed BAAs |
| Breach Procedures | Documented incident response plan |

### COPPA Considerations

- Verifiable parental consent required before collecting child information
- Data minimization: collect only what's necessary
- No direct marketing to children
- Clear privacy policy in plain language
- Parental access to review/delete child data

### Mental Health Data Sensitivity

- Enhanced access restrictions for psychological assessments
- Clear consent for AI processing of sensitive information
- Escalation protocols for detected risk indicators (suicidal ideation, abuse)
- Audit trails specifically for clinical data access
- Data segregation between administrative and clinical information

### Insurance Data Handling

- PCI-adjacent security for insurance card images
- Secure deletion after verification complete
- No storage of full SSN (last 4 only if required)
- Compliance with payer data requirements

This section shapes all functional and non-functional requirements below.

---

## Innovation & Novel Patterns

### AI-First Onboarding

**What's Novel:** Traditional healthcare onboarding uses forms. This system uses conversational AI as the primary interface—not as a helper, but as the experience itself.

**Innovation Pattern:**
- AI conducts intake as a dialogue, not a questionnaire
- Context-aware follow-ups based on parent responses
- Emotional intelligence in tone and pacing
- Graceful handoff to human when needed

### Insurance Intelligence Layer

**What's Novel:** Instead of dumping insurance complexity on parents, AI handles the cognitive load:
- Interprets insurance card photos automatically
- Understands coverage implications
- Guides parents through edge cases
- Pre-validates before submission

### Validation Approach

**AI Assessment Validation:**
- All AI-collected assessments reviewed by clinical staff before use
- A/B testing AI recommendations vs. clinician judgments
- Continuous monitoring for bias or gaps
- Clear labeling that AI assists, doesn't diagnose

**Insurance Accuracy Validation:**
- Comparison of AI-extracted data vs. manual verification
- Error rate tracking by insurance type
- Feedback loop for OCR improvements

---

## API Backend Specific Requirements

This backend serves a decoupled frontend (web, mobile-first responsive) via GraphQL API.

### API Specification

**Protocol:** GraphQL over HTTPS
**Authentication:** JWT tokens with refresh mechanism
**Real-time:** GraphQL Subscriptions for live updates

**Core API Domains:**

1. **Onboarding Session Management**
   - Create/resume/complete sessions
   - Progress tracking and state management
   - Timeout and expiration handling

2. **Conversational AI Interface**
   - Message send/receive
   - Context management
   - Assessment state tracking

3. **Insurance Operations**
   - Image upload and OCR trigger
   - Manual data entry
   - Eligibility verification status

4. **Admin Operations**
   - Session monitoring
   - Analytics queries
   - Configuration management

### Authentication & Authorization

**Authentication Flow:**
1. Anonymous session created at onboarding start
2. Parent identity established during intake
3. Session upgraded to authenticated on completion
4. Admin users authenticate via SSO/OAuth

**Authorization Model:**
| Role | Permissions |
|------|-------------|
| Anonymous | Create session, submit responses |
| Parent (in-progress) | Own session read/write |
| Parent (completed) | Read own data, limited updates |
| Care Coordinator | Read assigned sessions, update status |
| Admin | Full read, config management |
| System | Integrations, background jobs |

### Permissions & Roles

**Data Access Matrix:**

| Data Type | Parent | Coordinator | Admin | System |
|-----------|--------|-------------|-------|--------|
| Own onboarding data | RW | R | R | R |
| Child assessment | R | R | R | R |
| Insurance details | RW | R | R | RW |
| Session analytics | - | - | R | RW |
| System config | - | - | RW | R |

---

## Functional Requirements

### Onboarding Session Management

- **FR1:** System can create a new anonymous onboarding session with unique identifier
- **FR2:** Parents can resume an in-progress session from any device using session recovery
- **FR3:** System automatically saves progress after each interaction
- **FR4:** Sessions expire after configurable period of inactivity with data retention
- **FR5:** Parents can explicitly abandon a session with confirmation
- **FR6:** System tracks session state (started, in-progress, insurance-pending, assessment-complete, submitted)

### Conversational AI Interface

- **FR7:** System presents intake questions through conversational AI interface
- **FR8:** AI adapts follow-up questions based on parent responses
- **FR9:** Parents can ask clarifying questions and receive contextual help
- **FR10:** AI provides progress indicators and estimated time remaining
- **FR11:** System detects and handles off-topic or confused responses gracefully
- **FR12:** Parents can request to speak with a human at any point

### Parent & Child Data Collection

- **FR13:** System collects parent contact information (name, email, phone)
- **FR14:** System collects parent relationship to child and legal guardian status
- **FR15:** System collects child demographic information (name, DOB, gender)
- **FR16:** System collects child's school information
- **FR17:** System captures parent's primary concerns about the child
- **FR18:** System collects relevant medical history with appropriate prompts

### Insurance Processing

- **FR19:** Parents can upload photos of insurance card (front and back)
- **FR20:** System extracts insurance information from card images via OCR
- **FR21:** Parents can manually enter or correct insurance information
- **FR22:** System validates insurance data format and completeness
- **FR23:** System performs real-time insurance eligibility verification
- **FR24:** System communicates verification status and any issues clearly
- **FR25:** Parents can proceed with self-pay option if insurance fails

### Assessment Collection

- **FR26:** System administers standardized screening questions conversationally
- **FR27:** System adapts assessment depth based on initial responses
- **FR28:** System detects risk indicators (self-harm, abuse) and triggers protocols
- **FR29:** System collects consent for treatment and data use
- **FR30:** System generates assessment summary for clinical review

### Notifications & Communication

- **FR31:** System sends confirmation email upon session start
- **FR32:** System sends reminder for abandoned sessions (configurable timing)
- **FR33:** System sends completion confirmation with next steps
- **FR34:** System notifies care team of completed onboarding
- **FR35:** System alerts on detected risk indicators immediately

### Admin & Operations

- **FR36:** Admins can view real-time onboarding pipeline dashboard
- **FR37:** Admins can search and filter sessions by status, date, and attributes
- **FR38:** Admins can view individual session details and progress
- **FR39:** Admins can manually update session status when needed
- **FR40:** System generates daily/weekly onboarding analytics reports
- **FR41:** Admins can configure AI prompts and assessment questions
- **FR42:** System logs all admin actions for audit purposes

### Data & Compliance

- **FR43:** All PHI is encrypted at rest and in transit
- **FR44:** System maintains complete audit log of all data access
- **FR45:** Parents can request export of their submitted data
- **FR46:** System supports data deletion requests with appropriate retention rules
- **FR47:** System enforces role-based access controls on all endpoints

---

## Non-Functional Requirements

### Performance

| Metric | Requirement | Rationale |
|--------|-------------|-----------|
| API Response Time | p95 < 500ms | Conversational feel requires snappy responses |
| AI Response Time | p95 < 2s | Acceptable for "thinking" indicator |
| Insurance OCR | < 10s | With progress indicator |
| Eligibility Check | < 30s | External dependency; show status |
| Concurrent Sessions | 1000+ | Handle traffic spikes |

### Security

- **SEC1:** All endpoints require TLS 1.3
- **SEC2:** JWT tokens expire in 1 hour; refresh tokens in 7 days
- **SEC3:** Rate limiting on all public endpoints (100 req/min default)
- **SEC4:** Input validation and sanitization on all user inputs
- **SEC5:** SQL injection and XSS prevention measures
- **SEC6:** Secrets management via secure vault (not environment variables)
- **SEC7:** Regular security scanning and penetration testing
- **SEC8:** WAF protection against common attack vectors
- **SEC9:** Session tokens invalidated on security events

### Scalability

- **SCA1:** Horizontal scaling capability for API tier
- **SCA2:** Database connection pooling with auto-scaling
- **SCA3:** Caching layer for configuration and static data
- **SCA4:** Queue-based processing for async operations (OCR, eligibility)
- **SCA5:** Stateless API design enabling load balancing

### Reliability

- **REL1:** 99.9% uptime target (8.7 hours/year downtime max)
- **REL2:** Graceful degradation when external services fail
- **REL3:** Automated failover for critical components
- **REL4:** Data backup with point-in-time recovery
- **REL5:** Disaster recovery plan with <4 hour RTO

### Integration

**External System Integrations:**

| System | Purpose | Priority |
|--------|---------|----------|
| Insurance Eligibility API | Real-time verification | MVP |
| OCR Service | Insurance card processing | MVP |
| Email Service | Notifications | MVP |
| LLM Provider | Conversational AI | MVP |
| Analytics Platform | Usage tracking | MVP |
| EHR System | Patient data sync | Post-MVP |
| Scheduling System | Appointment booking | Post-MVP |

---

## Summary

This PRD defines the Parent Onboarding AI Backend for Daybreak Health—a GraphQL API service that transforms pediatric mental health onboarding from a friction-heavy form-filling exercise into a supportive, AI-guided conversation.

**47 Functional Requirements** covering:
- Session management and persistence
- Conversational AI interface
- Parent and child data collection
- Insurance capture and verification
- Clinical assessment collection
- Notifications and communications
- Admin operations and compliance

**Key Success Metrics:**
- 80%+ onboarding completion rate
- <10 minute average completion time
- Zero compliance incidents

**What Makes This Special:** Every friction point removed is a child who gets help. This backend makes seeking mental health care feel supported, not bureaucratic.

---

_This PRD captures the essence of Daybreak Health Backend - transforming pediatric mental health onboarding through AI-powered empathy and intelligence._

_Created through collaborative discovery between BMad and AI facilitator._
