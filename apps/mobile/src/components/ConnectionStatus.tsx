/**
 * Agent Deck Mobile - Connection Status Component
 * Displays current WebSocket connection state with visual indicator
 */

import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { colors, spacing, fontSize } from '../theme';
import type { ConnectionState } from '../types';

interface ConnectionStatusProps {
  connectionState: ConnectionState;
}

export const ConnectionStatus: React.FC<ConnectionStatusProps> = ({ connectionState }) => {
  const getStatusColor = (): string => {
    switch (connectionState) {
      case 'connected':
        return colors.connected;
      case 'connecting':
        return colors.connecting;
      case 'disconnected':
        return colors.disconnected;
      case 'error':
        return colors.statusError;
      default:
        return colors.disconnected;
    }
  };

  const getStatusLabel = (): string => {
    switch (connectionState) {
      case 'connected':
        return 'Connected';
      case 'connecting':
        return 'Connecting...';
      case 'disconnected':
        return 'Disconnected';
      case 'error':
        return 'Error';
      default:
        return 'Unknown';
    }
  };

  const statusColor = getStatusColor();

  return (
    <View style={styles.container}>
      <View style={[styles.indicator, { backgroundColor: statusColor }]} />
      <Text style={styles.label}>{getStatusLabel()}</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.sm,
  },
  indicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: spacing.xs,
  },
  label: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    fontWeight: '500',
  },
});
