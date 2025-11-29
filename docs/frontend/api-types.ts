/**
 * Daybreak Health API Types
 *
 * TypeScript definitions for the GraphQL API.
 * Generated from docs/api_schema.graphql
 *
 * Usage in Next.js:
 *   import type { OnboardingSession, User, Assessment } from '@/types/api';
 */

// ============================================================================
// ENUMS
// ============================================================================

export enum OnboardingStatus {
  ASSESSMENT_STARTED = 'ASSESSMENT_STARTED',
  ASSESSMENT_COMPLETED = 'ASSESSMENT_COMPLETED',
  DEMOGRAPHICS_COMPLETED = 'DEMOGRAPHICS_COMPLETED',
  INSURANCE_PENDING = 'INSURANCE_PENDING',
  INSURANCE_COMPLETED = 'INSURANCE_COMPLETED',
  SCHEDULING_PENDING = 'SCHEDULING_PENDING',
  SCHEDULING_COMPLETED = 'SCHEDULING_COMPLETED',
  ONBOARDING_COMPLETE = 'ONBOARDING_COMPLETE',
}

export enum UserRole {
  PARENT = 'PARENT',
  SUPPORT_STAFF = 'SUPPORT_STAFF',
  ADMIN = 'ADMIN',
}

export enum MessageSender {
  USER = 'USER',
  AI = 'AI',
  SUPPORT = 'SUPPORT',
}

export enum VerificationStatus {
  PENDING = 'PENDING',
  IN_PROGRESS = 'IN_PROGRESS',
  VERIFIED = 'VERIFIED',
  FAILED = 'FAILED',
  MANUAL_REVIEW = 'MANUAL_REVIEW',
  SELF_PAY = 'SELF_PAY',
}

// ============================================================================
// CORE TYPES
// ============================================================================

export interface User {
  id: string;
  email: string;
  firstName?: string;
  lastName?: string;
  role: UserRole;
  createdAt: string;
  children?: Child[];
}

export interface Child {
  id: string;
  firstName: string;
  lastName?: string;
  dateOfBirth: string;
  pronouns?: string;
  gender?: string;
  schoolName?: string;
  grade?: string;
  concerns?: string[];
  createdAt: string;
}

export interface OnboardingSession {
  id: string;
  status: OnboardingStatus;
  parent: User;
  child: Child;
  assessment?: Assessment;
  insuranceInfo?: InsuranceInformation;
  appointment?: Appointment;
  createdAt: string;
  updatedAt: string;
}

export interface Assessment {
  id: string;
  conversationHistory: ChatMessage[];
  responses?: AssessmentResponses;
  summary?: string;
  isFitForDaybreak?: boolean;
  suggestedNextSteps?: string;
  riskFlags?: string[];
  consentGiven: boolean;
}

export interface AssessmentResponses {
  [questionId: string]: string | number | boolean;
}

export interface ChatMessage {
  id: string;
  sender: MessageSender;
  content: string;
  timestamp: string;
  metadata?: ChatMessageMetadata;
}

export interface ChatMessageMetadata {
  phase?: 'intake' | 'insurance' | 'assessment' | 'scheduling';
  intent?: string;
  questionId?: number;
  score?: number;
  [key: string]: unknown;
}

export interface InsuranceInformation {
  id: string;
  provider?: string;
  planName?: string;
  memberId?: string;
  groupId?: string;
  imageFileUrl?: string;
  verificationStatus: VerificationStatus;
  verificationResult?: InsuranceVerificationResult;
}

export interface InsuranceVerificationResult {
  inNetwork?: boolean;
  copay?: number;
  deductibleRemaining?: number;
  error?: string;
  code?: string;
}

export interface Appointment {
  id: string;
  therapistName: string;
  therapistId: string;
  startTime: string;
  endTime: string;
  confirmationId: string;
}

export interface CostEstimate {
  copayPerSession?: number;
  deductibleRemaining?: number;
  outOfPocketMax?: number;
  notes?: string;
}

export interface Therapist {
  id: string;
  firstName: string;
  lastName: string;
  title?: string;
  bio?: string;
  specialties?: string[];
  languages?: string[];
  imageUrl?: string;
}

export interface TimeSlot {
  id: string;
  therapistId: string;
  startTime: string;
  endTime: string;
  available: boolean;
}

// ============================================================================
// INPUT TYPES (for mutations)
// ============================================================================

export interface StartOnboardingInput {
  parentEmail: string;
  childFirstName: string;
  childDateOfBirth: string;
}

export interface SubmitAssessmentMessageInput {
  onboardingSessionId: string;
  messageContent: string;
}

export interface UpdateDemographicsInput {
  onboardingSessionId: string;
  parentFirstName?: string;
  parentLastName?: string;
  parentPhone?: string;
  childPronouns?: string;
  childGender?: string;
  childConcerns?: string[];
  childSchoolName?: string;
  childGrade?: string;
}

export interface SubmitInsuranceInfoInput {
  onboardingSessionId: string;
  provider: string;
  planName?: string;
  memberId: string;
  groupId?: string;
}

export interface SubmitInsuranceImageInput {
  onboardingSessionId: string;
  frontImage: File;
  backImage?: File;
}

export interface ScheduleAppointmentInput {
  onboardingSessionId: string;
  therapistId: string;
  timeSlotId: string;
}

// ============================================================================
// API RESPONSE TYPES
// ============================================================================

export interface GraphQLResponse<T> {
  data?: T;
  errors?: GraphQLError[];
}

export interface GraphQLError {
  message: string;
  locations?: Array<{ line: number; column: number }>;
  path?: string[];
  extensions?: {
    code: ErrorCode;
    timestamp: string;
    [key: string]: unknown;
  };
}

export type ErrorCode =
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'VALIDATION_ERROR'
  | 'SESSION_EXPIRED'
  | 'RATE_LIMITED'
  | 'INTERNAL_ERROR';

// Query responses
export interface GetOnboardingSessionResponse {
  getOnboardingSession: OnboardingSession | null;
}

export interface MeResponse {
  me: User | null;
}

export interface GetAvailableSlotsResponse {
  getAvailableSlots: TimeSlot[];
}

export interface GetCostEstimateResponse {
  getCostEstimate: CostEstimate | null;
}

// Mutation responses
export interface StartOnboardingResponse {
  startOnboarding: OnboardingSession;
}

export interface SubmitAssessmentMessageResponse {
  submitAssessmentMessage: Assessment;
}

export interface UpdateDemographicsResponse {
  updateDemographics: OnboardingSession;
}

export interface SubmitInsuranceInfoResponse {
  submitInsuranceInfo: OnboardingSession;
}

export interface SubmitInsuranceImageResponse {
  submitInsuranceImage: InsuranceInformation;
}

export interface ScheduleAppointmentResponse {
  scheduleAppointment: Appointment;
}

export interface SendSupportChatMessageResponse {
  sendSupportChatMessage: ChatMessage;
}

// ============================================================================
// SUBSCRIPTION TYPES
// ============================================================================

export interface SupportChatMessagesSubscription {
  supportChatMessages: ChatMessage;
}

export interface SessionUpdatedSubscription {
  sessionUpdated: OnboardingSession;
}

export interface EligibilityChangedSubscription {
  eligibilityChanged: InsuranceInformation;
}

// ============================================================================
// UTILITY TYPES
// ============================================================================

/** ISO 8601 date string */
export type ISODateString = string;

/** UUID string */
export type UUID = string;

/** Partial type for form state */
export type OnboardingFormState = Partial<{
  parent: Partial<User>;
  child: Partial<Child>;
  insurance: Partial<InsuranceInformation>;
  assessment: Partial<Assessment>;
}>;

/** Session status check helpers */
export const isSessionActive = (status: OnboardingStatus): boolean => {
  return ![
    OnboardingStatus.ONBOARDING_COMPLETE,
  ].includes(status);
};

export const canSubmitInsurance = (status: OnboardingStatus): boolean => {
  return [
    OnboardingStatus.DEMOGRAPHICS_COMPLETED,
    OnboardingStatus.INSURANCE_PENDING,
  ].includes(status);
};

export const canScheduleAppointment = (status: OnboardingStatus): boolean => {
  return [
    OnboardingStatus.INSURANCE_COMPLETED,
    OnboardingStatus.SCHEDULING_PENDING,
  ].includes(status);
};

// ============================================================================
// TYPE GUARDS
// ============================================================================

export const isUser = (obj: unknown): obj is User => {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    'id' in obj &&
    'email' in obj &&
    'role' in obj
  );
};

export const isOnboardingSession = (obj: unknown): obj is OnboardingSession => {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    'id' in obj &&
    'status' in obj &&
    'parent' in obj &&
    'child' in obj
  );
};

export const isChatMessage = (obj: unknown): obj is ChatMessage => {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    'id' in obj &&
    'sender' in obj &&
    'content' in obj &&
    'timestamp' in obj
  );
};

// ============================================================================
// MOCK DATA (for development/testing)
// ============================================================================

export const mockUser: User = {
  id: '1aae35f6-8fc9-4651-9f4d-cf0273599ec9',
  email: 'parent@example.com',
  firstName: 'Test',
  lastName: 'Parent',
  role: UserRole.PARENT,
  createdAt: new Date().toISOString(),
};

export const mockChild: Child = {
  id: 'bde9e7c9-63d8-4c64-8c10-dcae5da258f1',
  firstName: 'Test',
  lastName: 'Child',
  dateOfBirth: '2016-01-01',
  createdAt: new Date().toISOString(),
};

export const mockSession: OnboardingSession = {
  id: 'd389138c-b9b8-4a91-ad51-f0cf5584f0ef',
  status: OnboardingStatus.ASSESSMENT_STARTED,
  parent: mockUser,
  child: mockChild,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
};
