# Frontend API Integration

This directory contains TypeScript types and utilities for the Next.js frontend to integrate with the Daybreak Health backend API.

## Files

| File | Purpose |
|------|---------|
| `api-types.ts` | TypeScript type definitions matching the GraphQL schema |
| `api-client.ts` | Example GraphQL client with all queries/mutations |

## Quick Start

### 1. Copy to your Next.js project

```bash
# From your Next.js project root
cp path/to/daybreak-health-backend/docs/frontend/api-types.ts src/types/
cp path/to/daybreak-health-backend/docs/frontend/api-client.ts src/lib/
```

### 2. Update import paths

In `api-client.ts`, update the import:
```typescript
import type { ... } from '@/types/api-types';
```

### 3. Set environment variables

```bash
# .env.local
NEXT_PUBLIC_API_URL=http://localhost:3000/graphql
NEXT_PUBLIC_WS_URL=ws://localhost:3000/cable
```

## Usage Examples

### Start Onboarding

```typescript
import { api } from '@/lib/api-client';
import type { OnboardingSession } from '@/types/api-types';

async function handleStart() {
  const session: OnboardingSession = await api.startOnboarding({
    parentEmail: 'parent@example.com',
    childFirstName: 'Alex',
    childDateOfBirth: '2015-06-15',
  });

  // Store session ID and token
  localStorage.setItem('sessionId', session.id);
}
```

### Send AI Message

```typescript
import { api } from '@/lib/api-client';

async function sendMessage(sessionId: string, message: string) {
  const assessment = await api.submitAssessmentMessage({
    onboardingSessionId: sessionId,
    messageContent: message,
  });

  // Get the latest AI response
  const messages = assessment.conversationHistory;
  const aiResponse = messages[messages.length - 1];

  return aiResponse;
}
```

### Submit Insurance

```typescript
import { api } from '@/lib/api-client';

// Manual entry
async function submitInsuranceManual(sessionId: string) {
  await api.submitInsuranceInfo({
    onboardingSessionId: sessionId,
    provider: 'Anthem Blue Cross',
    memberId: 'ABC123456',
    groupId: 'GRP789',
  });
}

// Image upload with OCR
async function submitInsuranceImage(sessionId: string, frontImage: File, backImage: File) {
  const result = await api.submitInsuranceImage(
    sessionId,
    frontImage,
    backImage
  );

  // Result contains OCR-extracted data
  console.log(result.provider, result.memberId);
}
```

### Subscribe to Updates

```typescript
import { createSubscriptionClient } from '@/lib/api-client';
import type { ChatMessage } from '@/types/api-types';

function subscribeToChat(sessionId: string, onMessage: (msg: ChatMessage) => void) {
  const client = createSubscriptionClient();

  const subscription = client.subscribe<{ supportChatMessages: ChatMessage }>(
    `subscription { supportChatMessages(onboardingSessionId: "${sessionId}") { id sender content timestamp } }`,
    {},
    (data) => onMessage(data.supportChatMessages),
    (error) => console.error('Subscription error:', error)
  );

  // Cleanup
  return () => subscription.unsubscribe();
}
```

## Type Safety

All API responses are fully typed:

```typescript
import type {
  OnboardingSession,
  OnboardingStatus,
  InsuranceInformation,
  VerificationStatus
} from '@/types/api-types';

// TypeScript knows all the fields
function renderSession(session: OnboardingSession) {
  if (session.status === OnboardingStatus.INSURANCE_PENDING) {
    // Handle insurance step
  }

  if (session.insuranceInfo?.verificationStatus === VerificationStatus.VERIFIED) {
    // Show verified badge
  }
}
```

## Error Handling

```typescript
import { api } from '@/lib/api-client';

try {
  await api.startOnboarding({ ... });
} catch (error) {
  if (error instanceof ApiError) {
    switch (error.code) {
      case 'VALIDATION_ERROR':
        // Show form errors
        break;
      case 'SESSION_EXPIRED':
        // Redirect to start
        break;
      case 'RATE_LIMITED':
        // Show retry message
        break;
      default:
        // Generic error
    }
  }
}
```

## Mock Data

For development without the backend:

```typescript
import { mockSession, mockUser, mockChild } from '@/types/api-types';

// Use in tests or development
const session = mockSession;
```

## GraphQL Playground

Once the backend is running, visit:
- GraphQL Playground: `http://localhost:3000/graphiql`
- API Endpoint: `http://localhost:3000/graphql`
