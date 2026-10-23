/**
 * Agent Deck Mobile - QR Scanner Screen
 * Scans QR code from Mac menubar app to get WebSocket URL
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Platform,
  Alert,
  Linking,
} from 'react-native';
import { CameraView, useCameraPermissions, BarcodeScanningResult } from 'expo-camera';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { colors, spacing, borderRadius, fontSize } from '../theme';

const STORAGE_KEY = '@agent-deck:server-url';

interface QRScannerScreenProps {
  onConnect: (url: string) => void;
}

export const QRScannerScreen: React.FC<QRScannerScreenProps> = ({ onConnect }) => {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const [manualUrl, setManualUrl] = useState('');
  const [showManualEntry, setShowManualEntry] = useState(false);

  // Check for saved URL on mount
  useEffect(() => {
    checkSavedUrl();
  }, []);

  const checkSavedUrl = async () => {
    try {
      const savedUrl = await AsyncStorage.getItem(STORAGE_KEY);
      if (savedUrl) {
        setManualUrl(savedUrl);
      }
    } catch (error) {
      console.error('[QRScanner] Failed to load saved URL:', error);
    }
  };

  const handleBarCodeScanned = async (result: BarcodeScanningResult) => {
    if (scanned) return;
    setScanned(true);

    const { data } = result;
    console.log('[QRScanner] Scanned:', data);

    // Validate URL format
    if (!data.startsWith('ws://') && !data.startsWith('wss://')) {
      Alert.alert(
        'Invalid QR Code',
        'The QR code does not contain a valid WebSocket URL. Expected ws:// or wss:// URL.',
        [{ text: 'OK', onPress: () => setScanned(false) }]
      );
      return;
    }

    // Save URL and connect
    try {
      await AsyncStorage.setItem(STORAGE_KEY, data);
      onConnect(data);
    } catch (error) {
      console.error('[QRScanner] Failed to save URL:', error);
      onConnect(data); // Connect anyway
    }
  };

  const handleManualConnect = async () => {
    const url = manualUrl.trim();

    if (!url) {
      Alert.alert('Error', 'Please enter a WebSocket URL');
      return;
    }

    // Validate URL format
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      Alert.alert('Invalid URL', 'URL must start with ws:// or wss://');
      return;
    }

    // Save URL and connect
    try {
      await AsyncStorage.setItem(STORAGE_KEY, url);
      onConnect(url);
    } catch (error) {
      console.error('[QRScanner] Failed to save URL:', error);
      onConnect(url); // Connect anyway
    }
  };

  const openSettings = () => {
    Linking.openSettings();
  };

  // Permission handling
  if (!permission) {
    return (
      <View style={styles.container}>
        <Text style={styles.message}>Requesting camera permission...</Text>
      </View>
    );
  }

  if (!permission.granted) {
    return (
      <View style={styles.container}>
        <View style={styles.permissionContainer}>
          <Text style={styles.title}>Camera Permission Required</Text>
          <Text style={styles.subtitle}>
            Agent Deck needs camera access to scan the QR code from your Mac's menubar app.
          </Text>

          <TouchableOpacity style={styles.button} onPress={requestPermission}>
            <Text style={styles.buttonText}>Grant Permission</Text>
          </TouchableOpacity>

          {permission.canAskAgain === false && (
            <TouchableOpacity style={styles.settingsButton} onPress={openSettings}>
              <Text style={styles.settingsButtonText}>Open Settings</Text>
            </TouchableOpacity>
          )}

          <TouchableOpacity
            style={styles.manualEntryLink}
            onPress={() => setShowManualEntry(true)}
          >
            <Text style={styles.linkText}>Enter URL manually instead</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  // Manual entry mode
  if (showManualEntry) {
    return (
      <View style={styles.container}>
        <View style={styles.manualContainer}>
          <Text style={styles.title}>Connect Manually</Text>
          <Text style={styles.subtitle}>
            Enter the WebSocket URL shown in your Mac's Agent Deck menubar
          </Text>

          <TextInput
            style={styles.input}
            value={manualUrl}
            onChangeText={setManualUrl}
            placeholder="ws://192.168.1.100:3001"
            placeholderTextColor={colors.textSecondary}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
          />

          <TouchableOpacity style={styles.button} onPress={handleManualConnect}>
            <Text style={styles.buttonText}>Connect</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.manualEntryLink}
            onPress={() => setShowManualEntry(false)}
          >
            <Text style={styles.linkText}>← Back to QR scanner</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  // QR Scanner mode
  return (
    <View style={styles.container}>
      {/* Camera layer */}
      <CameraView
        style={styles.camera}
        facing="back"
        barcodeScannerSettings={{
          barcodeTypes: ['qr'],
        }}
        onBarcodeScanned={scanned ? undefined : handleBarCodeScanned}
      />

      {/* Overlay layer - positioned absolutely on top of camera */}
      <View style={styles.overlay}>
        {/* Top section */}
        <View style={styles.overlayTop}>
          <Text style={styles.instructionText}>
            Point your camera at the QR code in the Agent Deck menubar
          </Text>
        </View>

        {/* Center - scanner frame */}
        <View style={styles.scannerFrame}>
          <View style={styles.cornerTL} />
          <View style={styles.cornerTR} />
          <View style={styles.cornerBL} />
          <View style={styles.cornerBR} />
        </View>

        {/* Bottom section */}
        <View style={styles.overlayBottom}>
          {scanned ? (
            <TouchableOpacity
              style={styles.rescanButton}
              onPress={() => setScanned(false)}
            >
              <Text style={styles.rescanButtonText}>Tap to Scan Again</Text>
            </TouchableOpacity>
          ) : (
            <TouchableOpacity
              style={styles.manualEntryLink}
              onPress={() => setShowManualEntry(true)}
            >
              <Text style={styles.linkText}>Enter URL manually</Text>
            </TouchableOpacity>
          )}
        </View>
      </View>
    </View>
  );
};

const FRAME_SIZE = 250;
const CORNER_SIZE = 30;
const CORNER_THICKNESS = 4;

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  camera: {
    ...StyleSheet.absoluteFillObject,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'transparent',
  },
  overlayTop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    justifyContent: 'flex-end',
    alignItems: 'center',
    paddingBottom: spacing.xl,
  },
  overlayBottom: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    justifyContent: 'flex-start',
    alignItems: 'center',
    paddingTop: spacing.xl,
  },
  scannerFrame: {
    width: FRAME_SIZE,
    height: FRAME_SIZE,
    alignSelf: 'center',
    backgroundColor: 'transparent',
  },
  cornerTL: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: CORNER_SIZE,
    height: CORNER_SIZE,
    borderTopWidth: CORNER_THICKNESS,
    borderLeftWidth: CORNER_THICKNESS,
    borderColor: colors.primary,
  },
  cornerTR: {
    position: 'absolute',
    top: 0,
    right: 0,
    width: CORNER_SIZE,
    height: CORNER_SIZE,
    borderTopWidth: CORNER_THICKNESS,
    borderRightWidth: CORNER_THICKNESS,
    borderColor: colors.primary,
  },
  cornerBL: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    width: CORNER_SIZE,
    height: CORNER_SIZE,
    borderBottomWidth: CORNER_THICKNESS,
    borderLeftWidth: CORNER_THICKNESS,
    borderColor: colors.primary,
  },
  cornerBR: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: CORNER_SIZE,
    height: CORNER_SIZE,
    borderBottomWidth: CORNER_THICKNESS,
    borderRightWidth: CORNER_THICKNESS,
    borderColor: colors.primary,
  },
  instructionText: {
    color: colors.text,
    fontSize: fontSize.md,
    textAlign: 'center',
    paddingHorizontal: spacing.xl,
  },
  message: {
    color: colors.text,
    fontSize: fontSize.md,
    textAlign: 'center',
  },
  permissionContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: spacing.xl,
  },
  manualContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: spacing.xl,
  },
  title: {
    fontSize: fontSize.xxl,
    fontWeight: '700',
    color: colors.text,
    marginBottom: spacing.sm,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: fontSize.md,
    color: colors.textSecondary,
    marginBottom: spacing.xl,
    textAlign: 'center',
    lineHeight: fontSize.md * 1.5,
  },
  input: {
    width: '100%',
    backgroundColor: colors.backgroundElevated,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: borderRadius.md,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.md,
    fontSize: fontSize.md,
    color: colors.text,
    marginBottom: spacing.lg,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
  },
  button: {
    width: '100%',
    backgroundColor: colors.primary,
    borderRadius: borderRadius.md,
    paddingVertical: spacing.md,
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  buttonText: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.text,
  },
  settingsButton: {
    width: '100%',
    backgroundColor: 'transparent',
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: borderRadius.md,
    paddingVertical: spacing.md,
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  settingsButtonText: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.textSecondary,
  },
  manualEntryLink: {
    marginTop: spacing.lg,
  },
  linkText: {
    color: colors.primary,
    fontSize: fontSize.md,
    textDecorationLine: 'underline',
  },
  rescanButton: {
    backgroundColor: colors.primary,
    borderRadius: borderRadius.md,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.xl,
  },
  rescanButtonText: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.text,
  },
});
