/**
 * Daybreak Health API Client
 *
 * Example GraphQL client wrapper for Next.js frontend.
 * Uses the types from api-types.ts
 *
 * Usage:
 *   import { api } from '@/lib/api-client';
 *   const session = await api.startOnboarding({ ... });
 */

import type {
  GraphQLResponse,
  GraphQLError,
  OnboardingSession,
  Assessment,
  InsuranceInformation,
  Appointment,
  CostEstimate,
  TimeSlot,
  User,
  StartOnboardingInput,
  SubmitAssessmentMessageInput,
  UpdateDemographicsInput,
  SubmitInsuranceInfoInput,
  ScheduleAppointmentInput,
} from './api-types';

// ============================================================================
// CONFIGURATION
// ============================================================================

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/graphql';
const WS_URL = process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:3000/cable';

// ============================================================================
// BASE CLIENT
// ============================================================================

class ApiError extends Error {
  constructor(
    message: string,
    public code: string,
    public errors: GraphQLError[]
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

async function graphqlRequest<T>(
  query: string,
  variables?: Record<string, unknown>,
  token?: string
): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(API_URL, {
    method: 'POST',
    headers,
    body: JSON.stringify({ query, variables }),
  });

  const result: GraphQLResponse<T> = await response.json();

  if (result.errors && result.errors.length > 0) {
    const firstError = result.errors[0];
    throw new ApiError(
      firstError.message,
      firstError.extensions?.code || 'UNKNOWN_ERROR',
      result.errors
    );
  }

  return result.data as T;
}

// ============================================================================
// QUERIES
// ============================================================================

const GET_ONBOARDING_SESSION = `
  query GetOnboardingSession($id: ID!) {
    getOnboardingSession(id: $id) {
      id
      status
      parent {
        id
        email
        firstName
        lastName
        role
        createdAt
      }
      child {
        id
        firstName
        dateOfBirth
        pronouns
        concerns
        createdAt
      }
      assessment {
        id
        conversationHistory {
          id
          sender
          content
          timestamp
        }
        summary
        isFitForDaybreak
        suggestedNextSteps
      }
      insuranceInfo {
        id
        provider
        planName
        memberId
        groupId
        imageFileUrl
      }
      appointment {
        id
        therapistName
        startTime
        endTime
        confirmationId
      }
      createdAt
      updatedAt
    }
  }
`;

const GET_ME = `
  query Me {
    me {
      id
      email
      firstName
      lastName
      role
      createdAt
      children {
        id
        firstName
        dateOfBirth
      }
    }
  }
`;

const GET_AVAILABLE_SLOTS = `
  query GetAvailableSlots($therapistId: ID, $startDate: String, $endDate: String) {
    getAvailableSlots(therapistId: $therapistId, startDate: $startDate, endDate: $endDate) {
      id
      therapistName
      startTime
      endTime
      confirmationId
    }
  }
`;

const GET_COST_ESTIMATE = `
  query GetCostEstimate($onboardingSessionId: ID!) {
    getCostEstimate(onboardingSessionId: $onboardingSessionId) {
      copayPerSession
      deductibleRemaining
      notes
    }
  }
`;

// ============================================================================
// MUTATIONS
// ============================================================================

const START_ONBOARDING = `
  mutation StartOnboarding($input: StartOnboardingInput!) {
    startOnboarding(input: $input) {
      id
      status
      parent {
        id
        email
      }
      child {
        id
        firstName
        dateOfBirth
      }
      createdAt
    }
  }
`;

const SUBMIT_ASSESSMENT_MESSAGE = `
  mutation SubmitAssessmentMessage($input: SubmitAssessmentMessageInput!) {
    submitAssessmentMessage(input: $input) {
      id
      conversationHistory {
        id
        sender
        content
        timestamp
      }
      summary
      isFitForDaybreak
    }
  }
`;

const UPDATE_DEMOGRAPHICS = `
  mutation UpdateDemographics($input: UpdateDemographicsInput!) {
    updateDemographics(input: $input) {
      id
      status
      parent {
        id
        firstName
        lastName
      }
      child {
        id
        pronouns
        concerns
      }
    }
  }
`;

const SUBMIT_INSURANCE_INFO = `
  mutation SubmitInsuranceInfo($input: SubmitInsuranceInfoInput!) {
    submitInsuranceInfo(input: $input) {
      id
      status
      insuranceInfo {
        id
        provider
        memberId
        groupId
      }
    }
  }
`;

const SUBMIT_INSURANCE_IMAGE = `
  mutation SubmitInsuranceImage($onboardingSessionId: ID!) {
    submitInsuranceImage(onboardingSessionId: $onboardingSessionId) {
      id
      provider
      planName
      memberId
      groupId
      imageFileUrl
    }
  }
`;

const SCHEDULE_APPOINTMENT = `
  mutation ScheduleAppointment($input: ScheduleAppointmentInput!) {
    scheduleAppointment(input: $input) {
      id
      therapistName
      startTime
      endTime
      confirmationId
    }
  }
`;

const SEND_SUPPORT_CHAT_MESSAGE = `
  mutation SendSupportChatMessage($onboardingSessionId: ID!, $content: String!) {
    sendSupportChatMessage(onboardingSessionId: $onboardingSessionId, content: $content) {
      id
      sender
      content
      timestamp
    }
  }
`;

// ============================================================================
// API CLIENT
// ============================================================================

export const api = {
  // Queries
  async getOnboardingSession(id: string, token?: string): Promise<OnboardingSession | null> {
    const data = await graphqlRequest<{ getOnboardingSession: OnboardingSession | null }>(
      GET_ONBOARDING_SESSION,
      { id },
      token
    );
    return data.getOnboardingSession;
  },

  async me(token: string): Promise<User | null> {
    const data = await graphqlRequest<{ me: User | null }>(GET_ME, {}, token);
    return data.me;
  },

  async getAvailableSlots(
    params: { therapistId?: string; startDate?: string; endDate?: string },
    token?: string
  ): Promise<TimeSlot[]> {
    const data = await graphqlRequest<{ getAvailableSlots: TimeSlot[] }>(
      GET_AVAILABLE_SLOTS,
      params,
      token
    );
    return data.getAvailableSlots;
  },

  async getCostEstimate(onboardingSessionId: string, token?: string): Promise<CostEstimate | null> {
    const data = await graphqlRequest<{ getCostEstimate: CostEstimate | null }>(
      GET_COST_ESTIMATE,
      { onboardingSessionId },
      token
    );
    return data.getCostEstimate;
  },

  // Mutations
  async startOnboarding(input: StartOnboardingInput): Promise<OnboardingSession> {
    const data = await graphqlRequest<{ startOnboarding: OnboardingSession }>(
      START_ONBOARDING,
      { input }
    );
    return data.startOnboarding;
  },

  async submitAssessmentMessage(input: SubmitAssessmentMessageInput, token?: string): Promise<Assessment> {
    const data = await graphqlRequest<{ submitAssessmentMessage: Assessment }>(
      SUBMIT_ASSESSMENT_MESSAGE,
      { input },
      token
    );
    return data.submitAssessmentMessage;
  },

  async updateDemographics(input: UpdateDemographicsInput, token?: string): Promise<OnboardingSession> {
    const data = await graphqlRequest<{ updateDemographics: OnboardingSession }>(
      UPDATE_DEMOGRAPHICS,
      { input },
      token
    );
    return data.updateDemographics;
  },

  async submitInsuranceInfo(input: SubmitInsuranceInfoInput, token?: string): Promise<OnboardingSession> {
    const data = await graphqlRequest<{ submitInsuranceInfo: OnboardingSession }>(
      SUBMIT_INSURANCE_INFO,
      { input },
      token
    );
    return data.submitInsuranceInfo;
  },

  async submitInsuranceImage(
    onboardingSessionId: string,
    frontImage: File,
    backImage?: File,
    token?: string
  ): Promise<InsuranceInformation> {
    // For file uploads, we need multipart form data
    const formData = new FormData();
    formData.append('operations', JSON.stringify({
      query: SUBMIT_INSURANCE_IMAGE,
      variables: { onboardingSessionId },
    }));
    formData.append('map', JSON.stringify({ '0': ['variables.frontImage'], '1': ['variables.backImage'] }));
    formData.append('0', frontImage);
    if (backImage) {
      formData.append('1', backImage);
    }

    const headers: Record<string, string> = {};
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch(API_URL, {
      method: 'POST',
      headers,
      body: formData,
    });

    const result = await response.json();
    if (result.errors) {
      throw new ApiError(result.errors[0].message, result.errors[0].extensions?.code, result.errors);
    }
    return result.data.submitInsuranceImage;
  },

  async scheduleAppointment(input: ScheduleAppointmentInput, token?: string): Promise<Appointment> {
    const data = await graphqlRequest<{ scheduleAppointment: Appointment }>(
      SCHEDULE_APPOINTMENT,
      { input },
      token
    );
    return data.scheduleAppointment;
  },

  async sendSupportChatMessage(
    onboardingSessionId: string,
    content: string,
    token?: string
  ): Promise<{ id: string; sender: string; content: string; timestamp: string }> {
    const data = await graphqlRequest<{ sendSupportChatMessage: { id: string; sender: string; content: string; timestamp: string } }>(
      SEND_SUPPORT_CHAT_MESSAGE,
      { onboardingSessionId, content },
      token
    );
    return data.sendSupportChatMessage;
  },
};

// ============================================================================
// WEBSOCKET SUBSCRIPTION CLIENT
// ============================================================================

export function createSubscriptionClient(token?: string) {
  // Action Cable connection for GraphQL subscriptions
  const url = token ? `${WS_URL}?token=${token}` : WS_URL;

  return {
    subscribe<T>(
      query: string,
      variables: Record<string, unknown>,
      onData: (data: T) => void,
      onError?: (error: Error) => void
    ) {
      const ws = new WebSocket(url);

      ws.onopen = () => {
        // Subscribe command for Action Cable
        ws.send(JSON.stringify({
          command: 'subscribe',
          identifier: JSON.stringify({ channel: 'GraphqlChannel' }),
        }));

        // Execute GraphQL subscription
        ws.send(JSON.stringify({
          command: 'message',
          identifier: JSON.stringify({ channel: 'GraphqlChannel' }),
          data: JSON.stringify({ query, variables }),
        }));
      };

      ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.message?.result?.data) {
          onData(data.message.result.data);
        }
      };

      ws.onerror = (event) => {
        onError?.(new Error('WebSocket error'));
      };

      return {
        unsubscribe: () => ws.close(),
      };
    },
  };
}

// ============================================================================
// REACT HOOKS (optional, for use with React Query or SWR)
// ============================================================================

/**
 * Example usage with React Query:
 *
 * import { useQuery, useMutation } from '@tanstack/react-query';
 * import { api } from '@/lib/api-client';
 *
 * export function useOnboardingSession(id: string) {
 *   return useQuery({
 *     queryKey: ['onboarding-session', id],
 *     queryFn: () => api.getOnboardingSession(id),
 *   });
 * }
 *
 * export function useStartOnboarding() {
 *   return useMutation({
 *     mutationFn: api.startOnboarding,
 *   });
 * }
 */

export default api;
