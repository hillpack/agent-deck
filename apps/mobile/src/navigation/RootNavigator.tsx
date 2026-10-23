/**
 * Agent Deck Mobile - Root Navigator
 * Stack navigation with QRScanner -> AgentList -> Settings flow
 */

import React, { useState, useEffect, useCallback } from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import AsyncStorage from '@react-native-async-storage/async-storage';

import { QRScannerScreen } from '../screens/QRScannerScreen';
import { AgentListScreen } from '../screens/AgentListScreen';
import { SettingsScreen } from '../screens/SettingsScreen';
import { colors } from '../theme';

const STORAGE_KEY = '@agent-deck:server-url';

export type RootStackParamList = {
  QRScanner: undefined;
  AgentList: { serverUrl: string };
  Settings: { serverUrl: string };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export const RootNavigator: React.FC = () => {
  const [initialRoute, setInitialRoute] = useState<keyof RootStackParamList | null>(null);
  const [savedUrl, setSavedUrl] = useState<string | null>(null);

  useEffect(() => {
    checkSavedConnection();
  }, []);

  const checkSavedConnection = async () => {
    try {
      const url = await AsyncStorage.getItem(STORAGE_KEY);
      if (url) {
        setSavedUrl(url);
        setInitialRoute('AgentList');
      } else {
        setInitialRoute('QRScanner');
      }
    } catch (error) {
      console.error('[RootNavigator] Failed to check saved connection:', error);
      setInitialRoute('QRScanner');
    }
  };

  // Wait for initial route to be determined
  if (!initialRoute) {
    return null;
  }

  return (
    <Stack.Navigator
      initialRouteName={initialRoute}
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: colors.background },
        animation: 'slide_from_right',
      }}
    >
      <Stack.Screen name="QRScanner">
        {({ navigation }) => (
          <QRScannerScreen
            onConnect={(url) => {
              navigation.replace('AgentList', { serverUrl: url });
            }}
          />
        )}
      </Stack.Screen>

      <Stack.Screen name="AgentList">
        {({ route, navigation }) => (
          <AgentListScreen
            serverUrl={route.params?.serverUrl || savedUrl || ''}
            onSettingsPress={() => {
              navigation.navigate('Settings', {
                serverUrl: route.params?.serverUrl || savedUrl || '',
              });
            }}
          />
        )}
      </Stack.Screen>

      <Stack.Screen
        name="Settings"
        options={{
          presentation: 'modal',
          animation: 'slide_from_bottom',
        }}
      >
        {({ route, navigation }) => (
          <SettingsScreen
            serverUrl={route.params?.serverUrl || ''}
            onDisconnect={() => {
              navigation.replace('QRScanner');
            }}
            onClose={() => {
              navigation.goBack();
            }}
          />
        )}
      </Stack.Screen>
    </Stack.Navigator>
  );
};
