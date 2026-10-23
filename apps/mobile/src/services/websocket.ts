/**
 * Agent Deck Mobile - WebSocket Service
 * Manages WebSocket connection to Mac app
 */

import type { WebSocketMessage, AgentInstance } from '../types';

export class WebSocketService {
  private ws: WebSocket | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectDelay = 1000; // Start with 1s
  private maxReconnectDelay = 30000; // Max 30s
  private reconnectAttempts = 0;

  // Event handlers
  public onMessage: ((message: WebSocketMessage) => void) | null = null;
  public onConnectionChange: ((connected: boolean) => void) | null = null;
  public onError: ((error: string) => void) | null = null;

  connect(url: string): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      console.log('[WebSocket] Already connected');
      return;
    }

    console.log('[WebSocket] Connecting to:', url);
    this.cleanup();

    try {
      this.ws = new WebSocket(url);

      this.ws.onopen = () => {
        console.log('[WebSocket] Connected successfully!');
        this.reconnectAttempts = 0;
        this.reconnectDelay = 1000;
        this.onConnectionChange?.(true);
      };

      this.ws.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data) as WebSocketMessage;
          console.log('[WebSocket] Message:', message.type);
          this.onMessage?.(message);
        } catch (error) {
          console.error('[WebSocket] Failed to parse message:', error);
          this.onError?.('Failed to parse message from server');
        }
      };

      this.ws.onerror = (error: any) => {
        console.error('[WebSocket] Error event:', JSON.stringify({
          type: error?.type,
          message: error?.message,
          readyState: this.ws?.readyState,
        }));
        this.onError?.('WebSocket connection error');
      };

      this.ws.onclose = (event: any) => {
        console.log('[WebSocket] Close event:', JSON.stringify({
          code: event?.code,
          reason: event?.reason,
          wasClean: event?.wasClean,
          readyState: this.ws?.readyState,
        }));
        this.onConnectionChange?.(false);
        this.scheduleReconnect(url);
      };
    } catch (error) {
      console.error('[WebSocket] Failed to create connection:', error);
      this.onError?.('Failed to connect to server');
      this.scheduleReconnect(url);
    }
  }

  disconnect(): void {
    console.log('[WebSocket] Disconnecting');
    this.cleanup();
  }

  sendFocusRequest(instanceId: string): void {
    this.send({
      type: 'focus',
      instanceId,
    });
  }

  sendCustomAction(actionId: string): void {
    this.send({
      type: 'action',
      actionId,
    });
  }

  private send(message: any): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      try {
        this.ws.send(JSON.stringify(message));
        console.log('[WebSocket] Sent:', message.type);
      } catch (error) {
        console.error('[WebSocket] Failed to send message:', error);
        this.onError?.('Failed to send message');
      }
    } else {
      console.warn('[WebSocket] Cannot send - not connected');
      this.onError?.('Not connected to server');
    }
  }

  private scheduleReconnect(url: string): void {
    if (this.reconnectTimer) {
      return; // Already scheduled
    }

    this.reconnectAttempts++;
    const delay = Math.min(
      this.reconnectDelay * Math.pow(1.5, this.reconnectAttempts),
      this.maxReconnectDelay
    );

    console.log(`[WebSocket] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect(url);
    }, delay);
  }

  private cleanup(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    if (this.ws) {
      this.ws.onopen = null;
      this.ws.onmessage = null;
      this.ws.onerror = null;
      this.ws.onclose = null;

      if (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING) {
        this.ws.close();
      }

      this.ws = null;
    }
  }

  isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }
}

// Singleton instance
export const websocketService = new WebSocketService();
