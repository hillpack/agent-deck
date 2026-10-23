/**
 * AgentCard Component
 * Displays an AgentInstance matching the UI design specification
 *
 * Design: Compact card with 3 lines:
 * - Line 1: Model icon + name | cwd | branch
 * - Line 2: Status text
 * - Line 3: Subagent icons + token count badge
 * - Optional: Todos section (collapsible)
 * - Optional: Last statement footer
 */

import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Pressable, Animated, LayoutAnimation, Platform, UIManager } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { AgentInstance, TodoItem } from '../types';
import { colors, spacing, borderRadius, fontSize } from '../theme';

// Enable LayoutAnimation on Android
if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

interface AgentCardProps {
  instance: AgentInstance;
  onFocus: (instanceId: string) => void;
}

export const AgentCard: React.FC<AgentCardProps> = ({ instance, onFocus }) => {
  const [todosExpanded, setTodosExpanded] = useState(false);

  // Load expand/collapse state from AsyncStorage
  useEffect(() => {
    const loadExpandState = async () => {
      try {
        const key = `todos_expanded_${instance.id}`;
        const value = await AsyncStorage.getItem(key);
        if (value !== null) {
          setTodosExpanded(value === 'true');
        }
      } catch (error) {
        console.error('Failed to load todos expand state:', error);
      }
    };
    loadExpandState();
  }, [instance.id]);

  // Save expand/collapse state to AsyncStorage
  const toggleTodos = async () => {
    const newState = !todosExpanded;
    setTodosExpanded(newState);

    // Animate the transition
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);

    try {
      const key = `todos_expanded_${instance.id}`;
      await AsyncStorage.setItem(key, newState.toString());
    } catch (error) {
      console.error('Failed to save todos expand state:', error);
    }
  };

  const handlePress = () => {
    onFocus(instance.id);
  };

  // Determine background and status color based on status
  const isWorking = instance.status === 'working';
  const isError = instance.status === 'error';
  const isDone = instance.status === 'done';
  const isIdle = instance.status === 'idle';

  const backgroundColor = isError
    ? 'rgba(255, 85, 85, 0.1)' // red-500/10 for error
    : isIdle || isDone
      ? 'rgba(40, 42, 58, 0.7)' // secondary-dark/70 for idle/done
      : colors.backgroundElevated; // secondary-dark for working

  const statusColor = isWorking
    ? colors.statusWorking
    : isError
      ? colors.statusError
      : isDone
        ? colors.statusDone
        : colors.statusIdle;

  const statusText = instance.currentTask || (isIdle ? 'Idle' : isDone ? 'Completed successfully' : 'Working');

  // Format token count (e.g., "14/200K")
  const formatTokenCount = (): string => {
    const used = instance.tokenCount?.used || 0;
    const total = instance.tokenCount?.total || 200000;
    const usedK = used < 1000 ? used.toString() : Math.round(used / 1000).toString();
    const totalK = Math.round(total / 1000) + 'K';
    return `${usedK}/${totalK}`;
  };

  // Format model name (e.g., "claude-sonnet-4-5-20250929" → "Sonnet 4.5")
  const formatModelName = (model: string): string => {
    if (model.includes('sonnet')) {
      const match = model.match(/sonnet-(\d)-(\d)/);
      if (match) return `Sonnet ${match[1]}.${match[2]}`;
      return 'Sonnet 4.5'; // fallback
    }
    if (model.includes('opus')) {
      const match = model.match(/opus-(\d)-(\d)/);
      if (match) return `Opus ${match[1]}.${match[2]}`;
      return 'Opus 3.0'; // fallback
    }
    if (model.includes('gpt-4o')) return 'GPT-4o';
    if (model.includes('gpt-4')) return 'GPT-4';
    if (model.includes('gpt-3.5')) return 'GPT-3.5';
    if (model.includes('gemini')) return 'Gemini 1.5';
    return 'Unknown';
  };

  // Truncate path to last 2 segments (e.g., "tests/api")
  const truncatePath = (path: string): string => {
    if (!path) return './';
    const segments = path.split('/').filter(Boolean);
    if (segments.length <= 2) return segments.join('/') || './';
    return segments.slice(-2).join('/');
  };

  // Get todo stats (e.g., "3/8 ✓")
  const getTodoStats = (): { completed: number; total: number } | null => {
    if (!instance.todos || instance.todos.length === 0) return null;
    const completed = instance.todos.filter(t => t.status === 'completed').length;
    const total = instance.todos.length;
    return { completed, total };
  };

  // Calculate todo progress percentage
  const getTodoProgress = (): number => {
    const stats = getTodoStats();
    if (!stats) return 0;
    return (stats.completed / stats.total) * 100;
  };

  // Render individual todo item
  const renderTodoItem = (todo: TodoItem) => {
    const isPending = todo.status === 'pending';
    const isInProgress = todo.status === 'in_progress';
    const isCompleted = todo.status === 'completed';

    const statusColor = isPending
      ? colors.todoPending
      : isInProgress
        ? colors.todoInProgress
        : colors.todoCompleted;

    const statusIcon = isPending ? '○' : isInProgress ? '◐' : '✓';

    return (
      <View key={todo.id} style={styles.todoItem}>
        <Text style={[styles.todoIcon, { color: statusColor }]}>{statusIcon}</Text>
        <Text
          style={[
            styles.todoText,
            { color: statusColor },
            isCompleted && styles.todoTextCompleted,
          ]}
          numberOfLines={2}
        >
          {isInProgress ? todo.activeForm : todo.content}
        </Text>
      </View>
    );
  };

  // Render todos section (collapsible)
  const renderTodosSection = () => {
    const stats = getTodoStats();
    if (!stats) return null;

    return (
      <View style={styles.todosSection}>
        {/* Todos header (always visible, clickable) */}
        <Pressable
          style={styles.todosHeader}
          onPress={toggleTodos}
          android_ripple={{ color: 'rgba(139, 233, 253, 0.1)' }}
        >
          <View style={styles.todosHeaderLeft}>
            <Text style={styles.todosLabel}>Tasks</Text>
            <View style={[styles.badge, { backgroundColor: colors.primary }]}>
              <Text style={styles.badgeTextWhite}>
                {stats.completed}/{stats.total} ✓
              </Text>
            </View>
          </View>
          <Text style={styles.expandIcon}>{todosExpanded ? '▼' : '▶'}</Text>
        </Pressable>

        {/* Progress bar */}
        <View style={styles.progressBarContainer}>
          <View
            style={[
              styles.progressBarFill,
              { width: `${getTodoProgress()}%`, backgroundColor: colors.todoCompleted },
            ]}
          />
        </View>

        {/* Todos list (collapsible) */}
        {todosExpanded && (
          <View style={styles.todosList}>
            {instance.todos?.map(renderTodoItem)}
          </View>
        )}
      </View>
    );
  };

  // Render last statement footer
  const renderLastStatement = () => {
    if (!instance.lastStatement) return null;

    return (
      <View style={styles.lastStatementContainer}>
        <Text style={styles.lastStatementText} numberOfLines={2}>
          {instance.lastStatement}
        </Text>
      </View>
    );
  };

  // Render subagent icons (Material Icons "smart_toy" filled)
  const renderSubagents = () => {
    if (!instance.subagents || instance.subagents.length === 0) return null;

    return (
      <View style={styles.subagentsContainer}>
        {instance.subagents.map((_, index) => (
          <Text key={index} style={styles.subagentIcon}>🤖</Text>
        ))}
      </View>
    );
  };

  return (
    <TouchableOpacity
      style={[
        styles.card,
        { backgroundColor },
        isWorking && styles.cardWorking, // Add ring for working status
      ]}
      onPress={handlePress}
      activeOpacity={0.8}
    >
      {/* Line 1: Model icon + name | cwd | branch */}
      <View style={styles.metadataLine}>
        {/* Model icon (Claude Anthropic symbol) */}
        <Text style={[styles.modelIcon, isError && { color: colors.statusError }]}>◆</Text>

        {/* Model name */}
        <Text style={styles.modelName}>
          {instance.model ? formatModelName(instance.model) : 'Unknown'}
        </Text>

        <Text style={styles.separator}>|</Text>

        {/* CWD */}
        <Text style={styles.cwd} numberOfLines={1}>
          {truncatePath(instance.cwd)}
        </Text>

        {/* Git Branch (only if available) */}
        {instance.gitBranch && (
          <>
            <Text style={styles.separator}>|</Text>
            <Text style={styles.branch} numberOfLines={1}>
              {instance.gitBranch}
            </Text>
          </>
        )}
      </View>

      {/* Line 2: Status text */}
      <Text style={[styles.statusText, { color: statusColor }]} numberOfLines={1}>
        {statusText}
      </Text>

      {/* Line 3: Subagents + token count */}
      <View style={styles.bottomLine}>
        {/* Subagent icons (left side) */}
        {renderSubagents()}

        {/* Right side badges */}
        <View style={styles.badgesContainer}>
          {/* Token count badge */}
          <View style={styles.tokenBadge}>
            <Text style={styles.tokenText}>{formatTokenCount()}</Text>
          </View>
        </View>
      </View>

      {/* Todos section (collapsible) */}
      {renderTodosSection()}

      {/* Last statement footer */}
      {renderLastStatement()}
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  card: {
    padding: 8, // p-2 (2 * 4px = 8px)
    borderRadius: 6, // rounded-md
    gap: 6, // gap-1.5 (1.5 * 4px = 6px)
    marginBottom: 8, // gap between cards
  },
  cardWorking: {
    // ring-1 ring-electric-blue
    borderWidth: 1,
    borderColor: colors.borderRing,
  },

  // Line 1: Metadata (model | cwd | branch)
  metadataLine: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6, // gap-1.5
  },
  modelIcon: {
    fontSize: 16, // h-4 w-4 (16px)
    color: colors.statusWorking,
    flexShrink: 0,
  },
  modelName: {
    fontFamily: 'monospace',
    fontSize: 11, // text-[11px]
    color: 'rgba(248, 248, 242, 0.9)', // text-off-white/90
    flexShrink: 0,
  },
  separator: {
    fontFamily: 'monospace',
    fontSize: 11,
    color: 'rgba(171, 178, 191, 0.5)', // text-muted-gray/50
    flexShrink: 0,
  },
  cwd: {
    fontFamily: 'monospace',
    fontSize: 11,
    color: colors.textSecondary, // text-muted-gray
    flex: 1,
    flexShrink: 1,
  },
  branch: {
    fontFamily: 'monospace',
    fontSize: 11,
    color: colors.textSecondary, // text-muted-gray
    flex: 1,
    flexShrink: 1,
  },

  // Line 2: Status text
  statusText: {
    fontSize: 13, // text-[13px]
    // color set dynamically based on status
  },

  // Line 3: Subagents + token count
  bottomLine: {
    flexDirection: 'row',
    alignItems: 'flex-end', // items-end
    justifyContent: 'space-between',
    marginTop: 4, // mt-1
  },
  subagentsContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2, // gap-0.5
  },
  subagentIcon: {
    fontSize: 12, // text-[12px]
    color: colors.statusWorking, // electric-blue
  },
  badgesContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  badge: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  badgeTextWhite: {
    fontFamily: 'monospace',
    fontSize: 10,
    color: colors.text,
    fontWeight: '600',
  },
  tokenBadge: {
    backgroundColor: 'rgba(26, 27, 38, 0.5)', // bg-primary-dark/50
    paddingHorizontal: 6, // px-1.5
    paddingVertical: 2, // py-0.5
    borderRadius: 4, // rounded
  },
  tokenText: {
    fontFamily: 'monospace',
    fontSize: 10, // text-[10px]
    color: colors.textSecondary, // text-muted-gray
  },

  // Todos section
  todosSection: {
    marginTop: 8,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    paddingTop: 8,
  },
  todosHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 4,
  },
  todosHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  todosLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  expandIcon: {
    fontSize: 10,
    color: colors.textSecondary,
  },

  // Progress bar
  progressBarContainer: {
    height: 3,
    backgroundColor: colors.border,
    borderRadius: 2,
    marginTop: 6,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: 2,
  },

  // Todo items
  todosList: {
    marginTop: 8,
    gap: 4,
  },
  todoItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 6,
    paddingVertical: 2,
  },
  todoIcon: {
    fontSize: 14,
    lineHeight: 18,
    flexShrink: 0,
  },
  todoText: {
    fontSize: 12,
    lineHeight: 18,
    flex: 1,
  },
  todoTextCompleted: {
    textDecorationLine: 'line-through',
    opacity: 0.7,
  },

  // Last statement footer
  lastStatementContainer: {
    marginTop: 8,
    padding: 8,
    backgroundColor: 'rgba(40, 42, 58, 0.5)', // secondary-dark/50
    borderRadius: 4,
    borderLeftWidth: 2,
    borderLeftColor: colors.primary,
  },
  lastStatementText: {
    fontFamily: 'monospace',
    fontSize: 11,
    lineHeight: 16,
    color: colors.textSecondary,
  },
});
