/**
 * Agent Deck Mobile - Settings Screen
 * Connection settings, keep awake toggle, and about info
 */

import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Switch,
  Alert,
  Platform,
  ScrollView,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { colors, spacing, borderRadius, fontSize } from '../theme';

const STORAGE_KEY = '@agent-deck:server-url';

interface SettingsScreenProps {
  serverUrl: string;
  onDisconnect: () => void;
  onClose: () => void;
}

export const SettingsScreen: React.FC<SettingsScreenProps> = ({
  serverUrl,
  onDisconnect,
  onClose,
}) => {
  const [keepAwake, setKeepAwake] = useState(true);

  const handleDisconnect = () => {
    Alert.alert(
      'Disconnect',
      'Are you sure you want to disconnect from this Mac?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Disconnect',
          style: 'destructive',
          onPress: async () => {
            try {
              await AsyncStorage.removeItem(STORAGE_KEY);
              onDisconnect();
            } catch (error) {
              console.error('[Settings] Failed to clear saved URL:', error);
              onDisconnect();
            }
          },
        },
      ]
    );
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={onClose} style={styles.closeButton}>
          <Text style={styles.closeButtonText}>Done</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Settings</Text>
        <View style={styles.placeholder} />
      </View>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentContainer}>
        {/* Connection Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Connection</Text>

          <View style={styles.card}>
            <View style={styles.row}>
              <Text style={styles.label}>Server URL</Text>
              <Text style={styles.value} numberOfLines={1}>
                {serverUrl}
              </Text>
            </View>

            <View style={styles.divider} />

            <TouchableOpacity style={styles.row} onPress={handleDisconnect}>
              <Text style={styles.disconnectText}>Disconnect</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Display Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Display</Text>

          <View style={styles.card}>
            <View style={styles.row}>
              <View style={styles.rowLeft}>
                <Text style={styles.label}>Keep Screen Awake</Text>
                <Text style={styles.description}>
                  Prevent screen from sleeping while monitoring
                </Text>
              </View>
              <Switch
                value={keepAwake}
                onValueChange={setKeepAwake}
                trackColor={{ false: colors.border, true: colors.primary }}
                thumbColor={colors.text}
              />
            </View>
          </View>
        </View>

        {/* About Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>About</Text>

          <View style={styles.card}>
            <View style={styles.row}>
              <Text style={styles.label}>Version</Text>
              <Text style={styles.value}>0.1.0 (MVP)</Text>
            </View>

            <View style={styles.divider} />

            <View style={styles.row}>
              <Text style={styles.label}>Platform</Text>
              <Text style={styles.value}>
                {Platform.OS === 'ios' ? 'iOS' : 'Android'}
              </Text>
            </View>
          </View>
        </View>

        {/* Help Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Help</Text>

          <View style={styles.card}>
            <View style={styles.helpItem}>
              <Text style={styles.helpTitle}>How to connect:</Text>
              <Text style={styles.helpText}>
                1. Open Agent Deck on your Mac{'\n'}
                2. Click the menubar icon{'\n'}
                3. Scan the QR code or enter the URL shown
              </Text>
            </View>

            <View style={styles.divider} />

            <View style={styles.helpItem}>
              <Text style={styles.helpTitle}>Troubleshooting:</Text>
              <Text style={styles.helpText}>
                • Make sure your phone and Mac are on the same WiFi network{'\n'}
                • Check that Agent Deck is running on your Mac{'\n'}
                • Try disconnecting and scanning QR code again
              </Text>
            </View>
          </View>
        </View>
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingTop: Platform.OS === 'ios' ? spacing.xl : spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  closeButton: {
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.sm,
  },
  closeButtonText: {
    color: colors.primary,
    fontSize: fontSize.lg,
    fontWeight: '600',
  },
  headerTitle: {
    color: colors.text,
    fontSize: fontSize.lg,
    fontWeight: '700',
  },
  placeholder: {
    width: 60,
  },
  content: {
    flex: 1,
  },
  contentContainer: {
    padding: spacing.md,
  },
  section: {
    marginBottom: spacing.xl,
  },
  sectionTitle: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    fontWeight: '600',
    textTransform: 'uppercase',
    marginBottom: spacing.sm,
    marginLeft: spacing.xs,
  },
  card: {
    backgroundColor: colors.backgroundElevated,
    borderRadius: borderRadius.md,
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.md,
  },
  rowLeft: {
    flex: 1,
    marginRight: spacing.md,
  },
  label: {
    color: colors.text,
    fontSize: fontSize.md,
  },
  value: {
    color: colors.textSecondary,
    fontSize: fontSize.md,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    maxWidth: '50%',
  },
  description: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    marginTop: spacing.xs,
  },
  divider: {
    height: 1,
    backgroundColor: colors.border,
    marginLeft: spacing.md,
  },
  disconnectText: {
    color: colors.statusError,
    fontSize: fontSize.md,
    fontWeight: '600',
  },
  helpItem: {
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.md,
  },
  helpTitle: {
    color: colors.text,
    fontSize: fontSize.md,
    fontWeight: '600',
    marginBottom: spacing.xs,
  },
  helpText: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    lineHeight: fontSize.sm * 1.6,
  },
});
