/**
 * Agent Deck Mobile - Agent List Screen
 * Main screen displaying all agent instances with real-time updates
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  FlatList,
  StyleSheet,
  RefreshControl,
  Platform,
} from 'react-native';
import { useWebSocket } from '../hooks/useWebSocket';
import { AgentCard } from '../components';
import { colors, spacing, borderRadius, fontSize } from '../theme';
import type { AgentInstance } from '../types';

interface AgentListScreenProps {
  serverUrl: string;
  onSettingsPress: () => void;
}

export const AgentListScreen: React.FC<AgentListScreenProps> = ({
  serverUrl,
  onSettingsPress,
}) => {
  const {
    instances,
    connectionState,
    connect,
    focusAgent,
  } = useWebSocket();

  const [isRefreshing, setIsRefreshing] = useState<boolean>(false);

  // Connect on mount with provided URL
  useEffect(() => {
    if (serverUrl) {
      console.log('[AgentListScreen] Connecting to:', serverUrl);
      connect(serverUrl);
    }
  }, [serverUrl]);

  const handleReconnect = () => {
    if (serverUrl) {
      connect(serverUrl);
    }
  };

  const handleRefresh = async () => {
    setIsRefreshing(true);

    // Reconnect to server
    handleReconnect();

    // Simulate refresh delay for UX
    setTimeout(() => {
      setIsRefreshing(false);
    }, 1000);
  };

  const handleFocusAgent = (instanceId: string) => {
    console.log('[AgentListScreen] Focus agent:', instanceId);
    focusAgent(instanceId);
  };

  // Calculate summary counts
  const activeCount = instances.filter(i => i.status === 'working').length;
  const idleCount = instances.filter(i => i.status === 'idle' || i.status === 'done').length;

  // Determine connection dot color
  const getConnectionDotColor = (): string => {
    switch (connectionState) {
      case 'connected':
        return colors.primary; // electric-blue
      case 'connecting':
        return colors.connecting; // yellow
      case 'error':
        return colors.statusError; // red
      default:
        return colors.textSecondary; // muted-gray
    }
  };

  const renderHeader = () => (
    <View style={styles.header}>
      {/* Left: Connection dot */}
      <View style={styles.headerLeft}>
        <View style={styles.connectionDotContainer}>
          <View style={[styles.connectionDot, { backgroundColor: getConnectionDotColor() }]} />
        </View>
      </View>

      {/* Center: Summary text */}
      <View style={styles.headerCenter}>
        <Text style={styles.summaryText}>
          <Text style={styles.activeCount}>{activeCount} active</Text>
          <Text style={styles.summarySeparator}> - </Text>
          <Text style={styles.idleCount}>{idleCount} idle</Text>
        </Text>
      </View>

      {/* Right: Settings button */}
      <View style={styles.headerRight}>
        <TouchableOpacity style={styles.settingsButton} onPress={onSettingsPress}>
          <Text style={styles.settingsIcon}>⚙️</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  const renderEmptyState = () => (
    <View style={styles.emptyContainer}>
      <Text style={styles.emptyTitle}>No agents running</Text>
      <Text style={styles.emptySubtitle}>
        Start Claude Code or another supported agent on your Mac
      </Text>
    </View>
  );

  const renderAgentList = () => (
    <FlatList
      data={instances}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => (
        <AgentCard instance={item} onFocus={handleFocusAgent} />
      )}
      contentContainerStyle={styles.listContent}
      ItemSeparatorComponent={() => <View style={styles.cardSeparator} />}
      ListEmptyComponent={renderEmptyState}
      refreshControl={
        <RefreshControl
          refreshing={isRefreshing}
          onRefresh={handleRefresh}
          tintColor={colors.textSecondary}
        />
      }
    />
  );

  return (
    <View style={styles.container}>
      {/* Header - always visible */}
      {renderHeader()}

      {/* Content - always show agent list */}
      {renderAgentList()}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },

  // Header styles - matching design specification
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.background, // primary-dark
    paddingHorizontal: spacing.md, // 16px
    paddingTop: Platform.OS === 'ios' ? spacing.xl : spacing.xs, // Safe area
    paddingBottom: spacing.xs,
    height: Platform.OS === 'ios' ? 48 + spacing.xl : 48, // h-12 = 48px + safe area
  },

  // Left: Connection dot (w-12 = 48px width)
  headerLeft: {
    width: 48,
    alignItems: 'flex-start',
    justifyContent: 'center',
  },
  connectionDotContainer: {
    position: 'relative',
    height: 8,
    width: 8,
    alignItems: 'flex-start',
    justifyContent: 'center',
  },
  connectionDot: {
    height: 8,
    width: 8,
    borderRadius: 4, // rounded-full
  },

  // Center: Summary text
  headerCenter: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  summaryText: {
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 12, // text-xs
    color: colors.textSecondary, // muted-gray
  },
  activeCount: {
    color: colors.accent, // accent-green
  },
  summarySeparator: {
    color: colors.textSecondary, // muted-gray
  },
  idleCount: {
    color: colors.textSecondary, // muted-gray
  },

  // Right: Settings button (w-12 = 48px width)
  headerRight: {
    width: 48,
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
  settingsButton: {
    height: 40, // h-10
    width: 40, // w-10
    borderRadius: borderRadius.md, // rounded-lg
    backgroundColor: 'transparent',
    alignItems: 'center',
    justifyContent: 'center',
  },
  settingsIcon: {
    fontSize: 24, // text-2xl
    color: colors.textSecondary, // muted-gray
  },

  // Agent list styles
  listContent: {
    paddingHorizontal: 10, // px-2.5
    paddingTop: spacing.sm,
    flexGrow: 1,
  },
  cardSeparator: {
    height: 8, // gap-2
  },

  // Empty state styles
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
  },
  emptyTitle: {
    fontSize: fontSize.xl,
    fontWeight: '700',
    color: colors.text,
    marginBottom: spacing.sm,
    textAlign: 'center',
  },
  emptySubtitle: {
    fontSize: fontSize.md,
    color: colors.textSecondary,
    textAlign: 'center',
  },
});
