/**
 * ActionButton Component
 * Square button for custom actions with loading/success/error states
 *
 * Features:
 * - 44x44 minimum touch target
 * - Emoji icon with label
 * - Scale animation on press
 * - States: idle, loading, success, error
 * - TouchableOpacity with haptic feedback
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Animated,
} from 'react-native';
import { colors, spacing, borderRadius } from '../theme';
import type { CustomAction } from '../types';

interface ActionButtonProps {
  action: CustomAction;
  onExecute: (actionId: string) => void;
}

type ButtonState = 'idle' | 'loading' | 'success' | 'error';

export const ActionButton: React.FC<ActionButtonProps> = ({ action, onExecute }) => {
  const [buttonState, setButtonState] = useState<ButtonState>('idle');
  const scaleAnim = React.useRef(new Animated.Value(1)).current;

  // Reset state after success/error
  useEffect(() => {
    if (buttonState === 'success' || buttonState === 'error') {
      const timer = setTimeout(() => {
        setButtonState('idle');
      }, 2000); // Show result for 2 seconds

      return () => clearTimeout(timer);
    }
  }, [buttonState]);

  const handlePressIn = () => {
    Animated.spring(scaleAnim, {
      toValue: 0.9,
      useNativeDriver: true,
      speed: 50,
      bounciness: 4,
    }).start();
  };

  const handlePressOut = () => {
    Animated.spring(scaleAnim, {
      toValue: 1,
      useNativeDriver: true,
      speed: 50,
      bounciness: 4,
    }).start();
  };

  const handlePress = async () => {
    if (buttonState !== 'idle') return; // Prevent multiple taps

    setButtonState('loading');

    try {
      // Execute action via WebSocket
      onExecute(action.id);

      // Simulate async operation (WebSocket sends but doesn't wait for response)
      // In a future phase, we could listen for action_success/action_failure messages
      setTimeout(() => {
        setButtonState('success');
      }, 500);
    } catch (error) {
      console.error('[ActionButton] Execute error:', error);
      setButtonState('error');
    }
  };

  // Get background color based on state
  const getBackgroundColor = (): string => {
    switch (buttonState) {
      case 'loading':
        return colors.backgroundElevated;
      case 'success':
        return 'rgba(80, 250, 123, 0.2)'; // accent-green/20
      case 'error':
        return 'rgba(255, 85, 85, 0.2)'; // red/20
      default:
        return colors.backgroundElevated;
    }
  };

  // Get border color based on state
  const getBorderColor = (): string => {
    switch (buttonState) {
      case 'success':
        return colors.statusDone;
      case 'error':
        return colors.statusError;
      default:
        return colors.border;
    }
  };

  // Render content based on state
  const renderContent = () => {
    if (buttonState === 'loading') {
      return (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="small" color={colors.primary} />
        </View>
      );
    }

    if (buttonState === 'success') {
      return (
        <View style={styles.iconContainer}>
          <Text style={styles.statusIcon}>✓</Text>
        </View>
      );
    }

    if (buttonState === 'error') {
      return (
        <View style={styles.iconContainer}>
          <Text style={styles.statusIcon}>✗</Text>
        </View>
      );
    }

    // Idle state - show action icon and label
    return (
      <View style={styles.contentContainer}>
        <Text style={styles.icon}>{action.icon}</Text>
        <Text style={styles.label} numberOfLines={2}>
          {action.label}
        </Text>
      </View>
    );
  };

  return (
    <Animated.View
      style={[
        styles.buttonWrapper,
        { transform: [{ scale: scaleAnim }] },
      ]}
    >
      <TouchableOpacity
        style={[
          styles.button,
          {
            backgroundColor: getBackgroundColor(),
            borderColor: getBorderColor(),
          },
        ]}
        onPress={handlePress}
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        activeOpacity={0.8}
        disabled={buttonState !== 'idle'}
      >
        {renderContent()}
      </TouchableOpacity>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  buttonWrapper: {
    width: '25%', // 4 columns (100% / 4)
    aspectRatio: 1, // Square
    padding: 4, // Small gap between buttons
  },
  button: {
    flex: 1,
    minWidth: 44, // Minimum touch target
    minHeight: 44, // Minimum touch target
    borderRadius: borderRadius.md,
    borderWidth: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xs,
  },
  contentContainer: {
    justifyContent: 'center',
    alignItems: 'center',
    gap: 4,
  },
  icon: {
    fontSize: 28,
    textAlign: 'center',
  },
  label: {
    fontSize: 10,
    color: colors.text,
    textAlign: 'center',
    fontWeight: '500',
  },
  loadingContainer: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  iconContainer: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  statusIcon: {
    fontSize: 32,
    color: colors.text,
    fontWeight: 'bold',
  },
});
