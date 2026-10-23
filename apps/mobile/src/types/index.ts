/**
 * Agent Deck Mobile - Local Types
 * Re-exports from @agent-deck/shared-types with mobile-specific additions
 */

export type {
  AgentInstance,
  AgentStatus,
  SubagentInfo,
  TodoItem,
  StatusUpdateMessage,
  FocusRequestMessage,
  CustomActionRequestMessage,
  ConnectedMessage,
  ErrorMessage,
  FocusSuccessMessage,
  FocusFailureMessage,
  PongMessage,
  WebSocketMessage,
  CustomAction,
  CustomActionType,
  Configuration,
} from '@agent-deck/shared-types';

// Mobile-specific types

export type ConnectionState = 'disconnected' | 'connecting' | 'connected' | 'error';

export interface AppSettings {
  serverUrl: string;
  keepScreenAwake: boolean;
  enableNotifications: boolean;
  theme: 'dark' | 'light' | 'auto';
}
