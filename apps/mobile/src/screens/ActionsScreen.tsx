/**
 * Agent Deck Mobile - Actions Screen
 * Display custom actions in a 4-column grid with tap-to-execute
 *
 * Features:
 * - 4-column FlatList grid
 * - Empty state when no actions configured
 * - Pull to refresh
 * - Dark theme styling
 */

import React from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  RefreshControl,
  Platform,
} from 'react-native';
import { useWebSocket } from '../hooks/useWebSocket';
import { ActionButton } from '../components/ActionButton';
import { colors, spacing, fontSize } from '../theme';
import type { CustomAction } from '../types';

interface ActionsScreenProps {
  onSettingsPress?: () => void;
}

export const ActionsScreen: React.FC<ActionsScreenProps> = ({ onSettingsPress }) => {
  const { customActions, executeAction, connectionState } = useWebSocket();
  const [isRefreshing, setIsRefreshing] = React.useState(false);

  const handleRefresh = async () => {
    setIsRefreshing(true);

    // Simulate refresh delay for UX
    setTimeout(() => {
      setIsRefreshing(false);
    }, 1000);
  };

  const handleExecuteAction = (actionId: string) => {
    console.log('[ActionsScreen] Execute action:', actionId);
    executeAction(actionId);
  };

  // Filter enabled actions
  const enabledActions = customActions.filter(action => action.enabled !== false);

  // Render empty state
  const renderEmptyState = () => (
    <View style={styles.emptyContainer}>
      <Text style={styles.emptyIcon}>⚡</Text>
      <Text style={styles.emptyTitle}>No Custom Actions</Text>
      <Text style={styles.emptySubtitle}>
        Configure custom actions in the Mac app's config file to see them here
      </Text>
      <Text style={styles.emptyHint}>
        Add actions to default-config.yaml
      </Text>
    </View>
  );

  // Render header with connection status
  const renderHeader = () => (
    <View style={styles.header}>
      <Text style={styles.headerTitle}>Custom Actions</Text>
      <View style={styles.connectionStatus}>
        <View
          style={[
            styles.connectionDot,
            { backgroundColor: connectionState === 'connected' ? colors.connected : colors.disconnected },
          ]}
        />
        <Text style={styles.connectionText}>
          {connectionState === 'connected' ? 'Connected' : 'Disconnected'}
        </Text>
      </View>
    </View>
  );

  return (
    <View style={styles.container}>
      {renderHeader()}

      <FlatList
        data={enabledActions}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <ActionButton action={item} onExecute={handleExecuteAction} />
        )}
        numColumns={4}
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={renderEmptyState}
        refreshControl={
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={handleRefresh}
            tintColor={colors.textSecondary}
          />
        }
        showsVerticalScrollIndicator={false}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },

  // Header styles
  header: {
    backgroundColor: colors.background,
    paddingHorizontal: spacing.md,
    paddingTop: Platform.OS === 'ios' ? spacing.xl : spacing.xs,
    paddingBottom: spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  headerTitle: {
    fontSize: fontSize.xl,
    fontWeight: '700',
    color: colors.text,
    marginBottom: spacing.xs,
  },
  connectionStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  connectionDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  connectionText: {
    fontSize: fontSize.xs,
    color: colors.textSecondary,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
  },

  // List styles
  listContent: {
    padding: spacing.sm,
    flexGrow: 1,
  },

  // Empty state styles
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.xxl,
  },
  emptyIcon: {
    fontSize: 64,
    marginBottom: spacing.md,
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
    marginBottom: spacing.md,
    lineHeight: 22,
  },
  emptyHint: {
    fontSize: fontSize.sm,
    color: colors.textTertiary,
    textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
  },
});
