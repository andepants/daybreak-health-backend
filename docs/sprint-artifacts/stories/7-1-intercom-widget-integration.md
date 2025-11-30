# Story 7.1: Intercom Widget Integration

Status: review

## Story

As a **developer**,
I want **Intercom chat widget integrated into the application**,
So that **parents can access live support**.

## Acceptance Criteria

1. **Intercom JavaScript SDK Integration**
   - Intercom JavaScript SDK installed and initialized
   - Widget appears on onboarding pages
   - Widget configured with Daybreak branding colors and styling
   - Widget loads asynchronously without blocking page render
   - Graceful degradation if Intercom service unavailable

2. **HIPAA Compliance**
   - HIPAA-compliant Intercom plan configured with signed BAA
   - No PHI transmitted to Intercom in clear text
   - Only session IDs and non-PHI metadata passed to Intercom

3. **Widget Control**
   - Widget can be shown/hidden programmatically
   - Mobile-responsive widget behavior
   - Widget positioned appropriately on all screen sizes
   - Widget state persists across page navigation

4. **Backend Support**
   - Backend GraphQL endpoint provides Intercom identity verification hash
   - Environment-based configuration (dev/staging/prod)
   - Intercom app ID and workspace configuration per environment

5. **Security**
   - CSP (Content Security Policy) headers updated to allow Intercom domains
   - Identity verification enabled to prevent user impersonation
   - Secure API key management via environment variables

## Tasks / Subtasks

- [x] Backend: Create Intercom configuration (AC: #2, #4, #5)
  - [x] Add Intercom gem to Gemfile (`intercom-rails` or custom implementation)
  - [x] Create `config/initializers/intercom.rb` with environment-based config
  - [x] Add Intercom app ID and secret to `.env.example`
  - [ ] Configure Intercom workspace for dev/staging/prod environments (out-of-scope: deployment configuration, not code)

- [x] Backend: Implement identity verification (AC: #2, #5)
  - [x] Create `app/services/support/intercom_service.rb`
  - [x] Implement HMAC-SHA256 identity verification hash generation
  - [x] Add GraphQL query `intercomIdentity` to provide user hash
  - [x] Return: `{ appId: String!, userHash: String!, userId: String! }`

- [ ] Frontend: Install Intercom SDK (AC: #1)
  - [ ] Install Intercom JavaScript SDK in Next.js frontend
  - [ ] Create Intercom provider/wrapper component
  - [ ] Initialize Intercom with app ID from backend config
  - [ ] Load SDK asynchronously with error handling

- [ ] Frontend: Configure widget styling (AC: #1, #3)
  - [ ] Apply Daybreak brand colors to widget
  - [ ] Configure widget positioning and z-index
  - [ ] Implement mobile-responsive behavior
  - [ ] Add show/hide controls for programmatic widget control

- [x] Security: Update CSP headers (AC: #5)
  - [x] Update `config/initializers/content_security_policy.rb`
  - [x] Allow Intercom domains: `*.intercom.io`, `*.intercomcdn.com`
  - [x] Test CSP compliance in dev and staging

- [ ] Testing: Widget functionality (AC: #1, #3, #4)
  - [ ] Test widget loads on all onboarding pages
  - [ ] Test widget appearance matches Daybreak branding
  - [ ] Test mobile responsiveness
  - [ ] Test graceful degradation when Intercom unavailable
  - [ ] Verify no page render blocking

- [ ] Documentation: Configuration guide (AC: #4)
  - [ ] Document Intercom setup in README
  - [ ] Document environment variable configuration
  - [ ] Document identity verification flow
  - [ ] Add troubleshooting guide

## Dev Notes

### Architecture Patterns

**Backend Service Pattern:**
- Create `app/services/support/intercom_service.rb` following existing service patterns
- Use HMAC-SHA256 for identity verification per Intercom security docs
- Store Intercom configuration in `config/initializers/intercom.rb`

**Frontend Integration:**
- Intercom SDK should be loaded asynchronously to avoid blocking page render
- Use React context or provider pattern for Intercom integration
- Widget state should be managed at application level

### Project Structure Notes

**Files to Create:**
- `app/services/support/intercom_service.rb` - Identity verification service
- `app/graphql/types/intercom_identity_type.rb` - GraphQL type for Intercom data
- Add `intercomIdentity` query to `app/graphql/types/query_type.rb`
- `config/initializers/intercom.rb` - Configuration initializer

**Files to Modify:**
- `Gemfile` - Add intercom dependencies if using Ruby gem
- `.env.example` - Add Intercom environment variables
- `config/initializers/content_security_policy.rb` - Add Intercom domains

### Security Considerations

**HIPAA Compliance:**
- **REQUIRED**: Ensure Daybreak has signed BAA (Business Associate Agreement) with Intercom before production deployment
  - BAA documentation must be reviewed and signed by compliance team
  - Confirm Intercom HIPAA plan is active for the workspace
  - Store BAA documentation in compliance records
- Never pass PHI (names, DOB, medical info) to Intercom
- Only pass: session ID, current step, status flags, timestamps
- Use Intercom's "Bring Your Own Key" encryption if required for additional security

**Identity Verification:**
- Implement server-side HMAC generation to prevent user impersonation
- User hash formula: `HMAC-SHA256(user_id, secret_key)`
- Secret key must be stored securely in environment variables

**CSP Configuration:**
Required domains:
- `https://widget.intercom.io`
- `https://js.intercomcdn.com`
- `https://*.intercom.io`
- `https://*.intercomcdn.com`

### Testing Standards

**Unit Tests:**
- Test IntercomService generates correct HMAC hash
- Test GraphQL query returns proper identity data
- Test graceful handling of missing Intercom configuration

**Integration Tests:**
- Test identity verification flow end-to-end
- Test CSP headers allow Intercom resources
- Test widget loads without errors

**Manual Testing:**
- Test widget appearance on desktop and mobile
- Test widget show/hide functionality
- Test widget persists across page navigation
- Test behavior when Intercom service is down

### Environment Configuration

```
# .env.example additions
INTERCOM_APP_ID=your_app_id_here
INTERCOM_SECRET_KEY=your_secret_key_here
INTERCOM_ENABLED=true  # false in test environment
```

### References

- [Intercom Developer Docs - Identity Verification](https://developers.intercom.com/installing-intercom/docs/enable-identity-verification)
- [Intercom JavaScript API Reference](https://developers.intercom.com/installing-intercom/docs/intercom-javascript)
- [HIPAA Compliance with Intercom](https://www.intercom.com/help/en/articles/1908-hipaa-compliance)
- [Source: docs/epics.md#Story-7.1-Intercom-Widget-Integration]
- [Source: docs/architecture.md#Project-Structure]

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context XML will be added here by context workflow -->
No context file found - proceeded with story file and architecture documentation.

### Agent Model Used

Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Debug Log References

**Implementation Plan:**
1. Created Support::IntercomService for HMAC-SHA256 identity verification
2. Implemented graceful degradation when Intercom is not configured
3. Created GraphQL IntercomIdentityType and query
4. Added CSP headers for Intercom domains
5. Comprehensive test coverage (36 tests, all passing)

**Key Decisions:**
- Used Rails service pattern (inherits from BaseService)
- Graceful degradation: returns `enabled: false` when not configured instead of raising errors
- Secret key validation: minimum 32 characters required
- HIPAA compliance: only session IDs passed, no PHI
- Test environment: Intercom disabled by default unless explicitly enabled

### Completion Notes List

**Backend Implementation Complete:**
- Created `app/services/support/intercom_service.rb` with HMAC-SHA256 identity verification
- Created `app/graphql/types/intercom_identity_type.rb` for GraphQL type definition
- Added `intercomIdentity` query to `app/graphql/types/query_type.rb`
- Created `config/initializers/intercom.rb` for configuration management
- Created `config/initializers/content_security_policy.rb` for CSP headers
- Environment variables already present in `.env.example`
- Comprehensive test coverage: 25 service specs + 11 GraphQL specs (36 total, all passing)

**Security Implementation:**
- HMAC-SHA256 identity verification prevents user impersonation
- Minimum 32-character secret key enforcement
- Only session IDs transmitted (no PHI)
- CSP headers configured for Intercom domains
- Graceful degradation when not configured

**Frontend Tasks Remaining:**
- Install Intercom JavaScript SDK in Next.js frontend
- Create Intercom provider/wrapper component
- Configure widget styling and positioning
- Test widget functionality

### File List

**Created:**
- `app/services/support/intercom_service.rb` - Intercom identity verification service
- `app/graphql/types/intercom_identity_type.rb` - GraphQL type for Intercom identity
- `config/initializers/intercom.rb` - Intercom configuration initializer
- `config/initializers/content_security_policy.rb` - CSP headers for Intercom
- `spec/services/support/intercom_service_spec.rb` - Service specs (25 tests)
- `spec/graphql/queries/intercom_identity_query_spec.rb` - GraphQL query specs (11 tests)

**Modified:**
- `app/graphql/types/query_type.rb` - Added `intercomIdentity` query
- `.env.example` - Already contained Intercom configuration variables
