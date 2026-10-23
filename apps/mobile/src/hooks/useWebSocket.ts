/**
 * Agent Deck Mobile - useWebSocket Hook
 * React hook for WebSocket connection management
 */

import { useState, useEffect, useCallback, useRef } from 'react';
import { websocketService } from '../services/websocket';
import type {
  AgentInstance,
  CustomAction,
  WebSocketMessage,
  ConnectionState,
} from '../types';

interface FocusResult {
  instanceId: string;
  success: boolean;
  error?: string;
  message?: string;
}

interface UseWebSocketReturn {
  instances: AgentInstance[];
  customActions: CustomAction[];
  connectionState: ConnectionState;
  error: string | null;
  focusResult: FocusResult | null;
  connect: (url: string) => void;
  disconnect: () => void;
  focusAgent: (instanceId: string) => void;
  executeAction: (actionId: string) => void;
  clearFocusResult: () => void;
}

export function useWebSocket(): UseWebSocketReturn {
  const [instances, setInstances] = useState<AgentInstance[]>([]);
  const [customActions, setCustomActions] = useState<CustomAction[]>([]);
  const [connectionState, setConnectionState] = useState<ConnectionState>('disconnected');
  const [error, setError] = useState<string | null>(null);
  const [focusResult, setFocusResult] = useState<FocusResult | null>(null);
  const currentUrl = useRef<string | null>(null);

  const handleMessage = useCallback((message: WebSocketMessage) => {
    switch (message.type) {
      case 'connected':
        console.log('[useWebSocket] Connected message received');
        setConnectionState('connected');
        setError(null);
        if (message.customActions) {
          setCustomActions(message.customActions);
        }
        break;

      case 'update':
        console.log('[useWebSocket] Update:', message.instances.length, 'instances');
        setInstances(message.instances);
        break;

      case 'error':
        console.error('[useWebSocket] Error:', message.message);
        setError(message.message);
        break;

      case 'focus_success':
        console.log('[useWebSocket] Focus success:', message.instanceId);
        setFocusResult({
          instanceId: message.instanceId,
          success: true,
        });
        break;

      case 'focus_failure':
        console.error('[useWebSocket] Focus failure:', message.error, message.message);
        setFocusResult({
          instanceId: message.instanceId,
          success: false,
          error: message.error,
          message: message.message,
        });
        break;

      case 'pong':
        console.log('[useWebSocket] Pong received');
        break;

      default:
        console.warn('[useWebSocket] Unknown message type:', (message as any).type);
    }
  }, []);

  const handleConnectionChange = useCallback((connected: boolean) => {
    console.log('[useWebSocket] Connection state:', connected ? 'connected' : 'disconnected');
    setConnectionState(connected ? 'connected' : 'disconnected');
    if (!connected) {
      setConnectionState('connecting'); // Will try to reconnect
    }
  }, []);

  const handleError = useCallback((errorMessage: string) => {
    console.error('[useWebSocket] Error:', errorMessage);
    setError(errorMessage);
  }, []);

  useEffect(() => {
    // Set up event handlers
    websocketService.onMessage = handleMessage;
    websocketService.onConnectionChange = handleConnectionChange;
    websocketService.onError = handleError;

    return () => {
      // Cleanup on unmount
      websocketService.onMessage = null;
      websocketService.onConnectionChange = null;
      websocketService.onError = null;
      websocketService.disconnect();
    };
  }, [handleMessage, handleConnectionChange, handleError]);

  const connect = useCallback((url: string) => {
    console.log('[useWebSocket] Connecting to:', url);
    currentUrl.current = url;
    setConnectionState('connecting');
    setError(null);
    websocketService.connect(url);
  }, []);

  const disconnect = useCallback(() => {
    console.log('[useWebSocket] Disconnecting');
    currentUrl.current = null;
    setConnectionState('disconnected');
    websocketService.disconnect();
  }, []);

  const focusAgent = useCallback((instanceId: string) => {
    console.log('[useWebSocket] Focus agent:', instanceId);
    websocketService.sendFocusRequest(instanceId);
  }, []);

  const executeAction = useCallback((actionId: string) => {
    console.log('[useWebSocket] Execute action:', actionId);
    websocketService.sendCustomAction(actionId);
  }, []);

  const clearFocusResult = useCallback(() => {
    setFocusResult(null);
  }, []);

  return {
    instances,
    customActions,
    connectionState,
    error,
    focusResult,
    connect,
    disconnect,
    focusAgent,
    executeAction,
    clearFocusResult,
  };
}
