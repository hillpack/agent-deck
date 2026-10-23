/**
 * Agent Deck - Theme Colors
 * Dark mode color palette optimized for monitoring and focus
 */

export const colors = {
  // Background colors - matching UI design
  background: '#1A1B26', // primary-dark
  backgroundElevated: '#282A3A', // secondary-dark
  backgroundHighlight: '#32344A', // slightly lighter than secondary-dark

  // Text colors - matching UI design
  text: '#F8F8F2', // off-white
  textSecondary: '#ABB2BF', // muted-gray
  textTertiary: '#6B7280', // darker muted gray for tertiary text

  // Status colors - matching UI design
  statusIdle: '#ABB2BF', // muted-gray
  statusWorking: '#8BE9FD', // electric-blue
  statusDone: '#50FA7B', // accent-green
  statusError: '#FF5555', // red (adjusted to match design aesthetic)

  // Accent colors - matching UI design
  primary: '#8BE9FD', // electric-blue
  primaryDark: '#6BC9DD', // darker electric-blue
  accent: '#50FA7B', // accent-green

  // Border colors
  border: '#3A3C4E', // subtle border in design palette
  borderLight: '#4A4C5E', // lighter border
  borderRing: '#8BE9FD', // electric-blue for active agent rings

  // Connection status
  connected: '#50FA7B', // accent-green
  disconnected: '#FF5555', // red
  connecting: '#F1FA8C', // yellow (matching design aesthetic)

  // Subagent badge
  subagentBadge: '#BD93F9', // purple (adjusted to match design)

  // Todo status colors
  todoPending: '#ABB2BF', // muted-gray
  todoInProgress: '#8BE9FD', // electric-blue
  todoCompleted: '#50FA7B', // accent-green
} as const;

export type ColorKey = keyof typeof colors;
