/**
 * app.js - Agent Deck PWA Client
 * Tasks: T034-T041 - WebSocket client with auto-reconnect
 */

class AgentDeckClient {
    constructor() {
        this.ws = null;
        this.reconnectDelay = 1000; // Start with 1s
        this.maxReconnectDelay = 16000; // Max 16s (per spec)
        this.reconnectAttempts = 0;
        this.instances = new Map(); // instanceId -> instance data
        this.serverUrl = null;

        this.init();
    }

    init() {
        // Get server URL from localStorage or show setup modal
        this.serverUrl = localStorage.getItem('agentdeck_server_url');

        if (!this.serverUrl) {
            this.showSetupModal();
        } else {
            this.connect(this.serverUrl);
        }

        // Setup UI event listeners
        this.setupEventListeners();
    }

    // Task: T035 - implement WebSocket connection logic
    connect(url) {
        this.updateConnectionStatus('connecting', 'Connecting...');

        try {
            this.ws = new WebSocket(url);

            this.ws.onopen = () => {
                this.onOpen();
            };

            this.ws.onmessage = (event) => {
                this.onMessage(event);
            };

            this.ws.onerror = (error) => {
                this.onError(error);
            };

            this.ws.onclose = () => {
                this.onClose();
            };

        } catch (error) {
            console.error('WebSocket connection error:', error);
            this.showError('Failed to connect', error.message);
            this.scheduleReconnect();
        }
    }

    onOpen() {
        console.log('WebSocket connected');
        this.updateConnectionStatus('connected', 'Connected');
        this.reconnectAttempts = 0;
        this.reconnectDelay = 1000;

        // Start ping interval (every 30 seconds per spec)
        this.startPingInterval();
    }

    // Task: T036 - implement status update handling
    onMessage(event) {
        try {
            const data = JSON.parse(event.data);
            console.log('Received message:', data.type);

            switch (data.type) {
                case 'initial_state':
                    this.handleInitialState(data);
                    break;

                case 'state_update':
                    // Real-time state updates (when ProcessMonitor.$instances changes)
                    this.handleStateUpdate(data);
                    break;

                case 'update':
                    this.handleUpdate(data);
                    break;

                case 'instance_added':
                    this.handleInstanceAdded(data);
                    break;

                case 'instance_removed':
                    this.handleInstanceRemoved(data);
                    break;

                case 'pong':
                    console.log('Pong received');
                    break;

                case 'focus_success':
                    this.handleFocusSuccess(data);
                    break;

                case 'focus_failure':
                    this.handleFocusFailure(data);
                    break;

                case 'error':
                    this.showError('Server Error', data.message);
                    break;

                default:
                    console.warn('Unknown message type:', data.type);
            }
        } catch (error) {
            console.error('Failed to parse message:', error);
        }
    }

    onError(error) {
        console.error('WebSocket error:', error);
        this.updateConnectionStatus('error', 'Connection Error');

        // Task: T063 - display error when devices are on different networks
        // If connection fails immediately, likely different networks or server not running
        if (this.reconnectAttempts === 0) {
            this.showError(
                'Connection Failed',
                'Ensure Mac and mobile are on the same WiFi network. Check that Agent Deck is running on your Mac.'
            );
        }
    }

    onClose() {
        console.log('WebSocket closed');
        this.updateConnectionStatus('disconnected', 'Disconnected');
        this.stopPingInterval();

        // Task: T041 - automatic reconnection with exponential backoff
        this.scheduleReconnect();
    }

    // Task: T041 - exponential backoff: 1s→2s→4s→8s→16s max
    scheduleReconnect() {
        this.reconnectAttempts++;
        const delay = Math.min(
            this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1),
            this.maxReconnectDelay
        );

        console.log(`Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

        setTimeout(() => {
            if (this.serverUrl) {
                this.connect(this.serverUrl);
            }
        }, delay);
    }

    // Handle initial_state message
    handleInitialState(data) {
        console.log('Initial state received:', data.instances.length, 'instances');
        this.instances.clear();

        data.instances.forEach(instance => {
            this.instances.set(instance.id, instance);
        });

        this.renderAgentList();
    }

    // Handle state_update message (real-time broadcast from ProcessMonitor changes)
    handleStateUpdate(data) {
        console.log('State update received:', data.instances.length, 'instances');
        this.instances.clear();

        data.instances.forEach(instance => {
            this.instances.set(instance.id, instance);
        });

        this.renderAgentList();
    }

    // Handle update message - Task: T036
    // Supports both array format (data.instances) and single instance format (data.instanceId)
    handleUpdate(data) {
        if (data.instances && Array.isArray(data.instances)) {
            // Server sends array format - handle like state_update
            console.log('Update received with', data.instances.length, 'instances');
            this.instances.clear();
            data.instances.forEach(instance => {
                this.instances.set(instance.id, instance);
            });
            this.renderAgentList();
        } else if (data.instanceId) {
            // Single instance update format
            const instance = this.instances.get(data.instanceId);
            if (instance) {
                instance.status = data.status;
                instance.currentTask = data.currentTask;
                instance.lastActivityTimestamp = data.timestamp;
                this.renderAgentList();
            }
        }
    }

    // Handle instance_added message
    handleInstanceAdded(data) {
        console.log('New instance added:', data.instance.id);
        this.instances.set(data.instance.id, data.instance);
        this.renderAgentList();
    }

    // Handle instance_removed message
    handleInstanceRemoved(data) {
        console.log('Instance removed:', data.instanceId);
        this.instances.delete(data.instanceId);
        this.renderAgentList();
    }

    // Task: T037 - create agent list UI with color-coded status
    renderAgentList() {
        const emptyState = document.getElementById('empty-state');
        const agentList = document.getElementById('agent-list');

        if (this.instances.size === 0) {
            emptyState.classList.remove('hidden');
            agentList.classList.add('hidden');
            return;
        }

        emptyState.classList.add('hidden');
        agentList.classList.remove('hidden');

        // Clear existing cards
        agentList.innerHTML = '';

        // Render each instance
        this.instances.forEach((instance, id) => {
            const card = this.createAgentCard(instance);
            agentList.appendChild(card);
        });
    }

    // Create agent card element - Task: T037, T038
    createAgentCard(instance) {
        const card = document.createElement('div');
        card.className = `agent-card status-${instance.status}`;
        card.dataset.instanceId = instance.id;

        // Card header
        const header = document.createElement('div');
        header.className = 'card-header';

        const title = document.createElement('div');
        title.className = 'card-title';
        title.textContent = instance.agentType;

        const badge = document.createElement('div');
        badge.className = 'card-badge';
        badge.textContent = `PID ${instance.pid}`;

        header.appendChild(title);
        header.appendChild(badge);

        // Card body
        const body = document.createElement('div');
        body.className = 'card-body';

        // Agent info (type + working directory on one line)
        const infoDiv = document.createElement('div');
        infoDiv.className = 'card-info';
        const workDir = instance.workingDirectory || instance.cwd || 'Unknown';
        infoDiv.innerHTML = `<span class="card-type">${instance.agentType}</span> <span class="card-separator">•</span> <span class="card-working-dir">${workDir}</span>`;

        // Current task - PROMINENT (what user wants to see)
        const taskDiv = document.createElement('div');
        taskDiv.className = 'current-task';
        if (instance.currentTaskDescription) {
            // Active task in progress
            taskDiv.textContent = instance.currentTaskDescription;
        } else if (instance.currentTask) {
            // Fallback to basic task text
            taskDiv.textContent = instance.currentTask;
        } else if (instance.lastStatement) {
            // Show last thing Claude said (when idle but has previous output)
            taskDiv.textContent = instance.lastStatement;
            taskDiv.classList.add('idle');
        } else {
            // Brand new session or after /clear
            taskDiv.textContent = 'Waiting for input';
            taskDiv.classList.add('idle');
        }

        // Active subagents section (expandable)
        const subagentsSection = this.createSubagentsSection(instance);

        // Todos section (expandable)
        const todosSection = this.createTodosSection(instance);

        // Metadata footer (model + git branch + directory)
        const metadataDiv = this.createMetadataFooter(instance);

        // Status footer (status + timestamp)
        const footerDiv = document.createElement('div');
        footerDiv.className = 'card-footer';

        const statusDot = document.createElement('div');
        statusDot.className = `status-indicator-small ${instance.status}`;

        const statusText = document.createElement('span');
        statusText.className = 'status-text';
        statusText.textContent = instance.status.charAt(0).toUpperCase() + instance.status.slice(1);

        const separator = document.createElement('span');
        separator.className = 'footer-separator';
        separator.textContent = '•';

        const timestamp = document.createElement('span');
        timestamp.className = 'timestamp-text';
        // Server sends "lastActivity", handle both field names for robustness
        const lastActivity = instance.lastActivity || instance.lastActivityTimestamp;
        timestamp.textContent = this.formatTimestamp(lastActivity);

        footerDiv.appendChild(statusDot);
        footerDiv.appendChild(statusText);
        footerDiv.appendChild(separator);
        footerDiv.appendChild(timestamp);

        // Assemble card body
        body.appendChild(infoDiv);
        body.appendChild(taskDiv);
        if (subagentsSection) body.appendChild(subagentsSection);
        if (todosSection) body.appendChild(todosSection);
        body.appendChild(metadataDiv);
        body.appendChild(footerDiv);

        card.appendChild(header);
        card.appendChild(body);

        // Task: T051 - tap event handler for window switching
        card.addEventListener('click', (e) => {
            // Don't trigger focus if clicking on expandable sections
            if (e.target.tagName === 'SUMMARY' || e.target.closest('details')) {
                return;
            }
            this.handleCardTap(instance.id);
        });

        return card;
    }

    // Create active subagents expandable section
    createSubagentsSection(instance) {
        // Server sends "subagents", handle both field names for robustness
        const subagents = instance.subagents || instance.activeSubagents;
        if (!subagents || subagents.length === 0) {
            return null;
        }

        const details = document.createElement('details');
        details.className = 'subagents-section';

        // Restore expansion state from localStorage
        const expansionKey = `agentdeck_subagents_${instance.id}`;
        if (localStorage.getItem(expansionKey) === 'true') {
            details.open = true;
        }

        // Save expansion state when toggled
        details.addEventListener('toggle', () => {
            localStorage.setItem(expansionKey, details.open);
        });

        const summary = document.createElement('summary');
        summary.innerHTML = `🤖 Active Subagents (${subagents.length})`;

        const list = document.createElement('ul');
        list.className = 'subagents-list';

        subagents.forEach(subagent => {
            const item = document.createElement('li');
            item.className = 'subagent-item';

            const typeSpan = document.createElement('span');
            typeSpan.className = 'subagent-type';
            typeSpan.textContent = subagent.type;

            const descSpan = document.createElement('span');
            descSpan.className = 'subagent-description';
            descSpan.textContent = subagent.description;

            item.appendChild(typeSpan);
            item.appendChild(document.createTextNode(': '));
            item.appendChild(descSpan);

            list.appendChild(item);
        });

        details.appendChild(summary);
        details.appendChild(list);

        return details;
    }

    // Create todos expandable section
    createTodosSection(instance) {
        if (!instance.todos || instance.todos.length === 0) {
            return null;
        }

        const details = document.createElement('details');
        details.className = 'todos-section';

        // Restore expansion state from localStorage
        const expansionKey = `agentdeck_todos_${instance.id}`;
        if (localStorage.getItem(expansionKey) === 'true') {
            details.open = true;
        }

        // Save expansion state when toggled
        details.addEventListener('toggle', () => {
            localStorage.setItem(expansionKey, details.open);
        });

        // Count completed tasks
        const completedCount = instance.todos.filter(t => t.status === 'completed').length;
        const totalCount = instance.todos.length;

        const summary = document.createElement('summary');
        summary.innerHTML = `✅ Tasks (${completedCount} of ${totalCount} complete)`;

        const list = document.createElement('ul');
        list.className = 'todos-list';

        instance.todos.forEach(todo => {
            const item = document.createElement('li');
            item.className = `todo-item ${todo.status}`;

            // Status icon
            const icon = document.createElement('span');
            icon.className = 'todo-icon';
            if (todo.status === 'completed') {
                icon.textContent = '✓';
            } else if (todo.status === 'in_progress') {
                icon.textContent = '⏳';
            } else {
                icon.textContent = '☐';
            }

            // Content
            const content = document.createElement('span');
            content.className = 'todo-content';
            // Show activeForm for in_progress, otherwise show content
            content.textContent = todo.status === 'in_progress' ? todo.activeForm : todo.content;

            item.appendChild(icon);
            item.appendChild(content);

            list.appendChild(item);
        });

        details.appendChild(summary);
        details.appendChild(list);

        return details;
    }

    // Create metadata footer (model + branch + directory)
    createMetadataFooter(instance) {
        const metadata = document.createElement('div');
        metadata.className = 'metadata';

        const parts = [];

        // Server sends "model", handle both field names for robustness
        const modelName = instance.model || instance.modelName;
        if (modelName) {
            const modelSpan = document.createElement('span');
            modelSpan.className = 'metadata-model';
            // Shorten model name (e.g., "claude-sonnet-4-5-20250929" → "Sonnet 4.5")
            const shortModel = this.shortenModelName(modelName);
            modelSpan.textContent = shortModel;
            parts.push(modelSpan);
        }

        if (instance.gitBranch) {
            const branchSpan = document.createElement('span');
            branchSpan.className = 'metadata-branch';
            branchSpan.textContent = instance.gitBranch;
            parts.push(branchSpan);
        }

        // Add working directory (basename only)
        const workingDir = instance.workingDirectory || instance.cwd || 'Unknown';
        const dirSpan = document.createElement('span');
        dirSpan.className = 'metadata-directory';
        const dirName = workingDir.split('/').pop() || workingDir;
        dirSpan.textContent = dirName;
        parts.push(dirSpan);

        // Assemble with separators
        parts.forEach((part, index) => {
            metadata.appendChild(part);
            if (index < parts.length - 1) {
                const sep = document.createElement('span');
                sep.className = 'metadata-separator';
                sep.textContent = ' • ';
                metadata.appendChild(sep);
            }
        });

        return metadata;
    }

    // Shorten model name for display
    shortenModelName(modelName) {
        // Handle undefined or null input
        if (!modelName) {
            return 'Unknown';
        }

        // Normalize to lowercase for matching
        const lowerName = modelName.toLowerCase();

        // Convert "claude-sonnet-4-5-20250929" or "Sonnet 4.5" to "Sonnet 4.5"
        if (lowerName.includes('sonnet')) {
            const match = modelName.match(/sonnet[- ]?(\d)[- .]?(\d)/i);
            if (match) {
                return `Sonnet ${match[1]}.${match[2]}`;
            }
            return 'Sonnet';
        }
        if (lowerName.includes('opus')) {
            return 'Opus';
        }
        if (lowerName.includes('haiku')) {
            return 'Haiku';
        }
        return modelName.substring(0, 20); // Fallback: truncate
    }

    /// Handle card tap event - send focus message to server
    /// Task: T051-T052 - send focus WebSocket message with instanceId
    handleCardTap(instanceId) {
        console.log('Card tapped:', instanceId);

        // Visual feedback - add tapped class for animation
        const card = document.querySelector(`[data-instance-id="${instanceId}"]`);
        if (card) {
            card.classList.add('tapped');
            setTimeout(() => {
                card.classList.remove('tapped');
            }, 200);
        }

        // Task: T052 - send focus WebSocket message
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            const message = {
                type: 'focus',
                timestamp: new Date().toISOString(),
                instanceId: instanceId
            };

            this.ws.send(JSON.stringify(message));
            console.log('Focus message sent for instance:', instanceId);
        } else {
            this.showError('Not Connected', 'Cannot switch windows while disconnected');
        }
    }

    /// Handle focus_success message from server
    /// Task: T053 - display success feedback
    handleFocusSuccess(data) {
        console.log('Focus success for instance:', data.instanceId);

        // Show success feedback
        this.showSuccessToast('Window switched successfully');

        // Visual feedback on card
        const card = document.querySelector(`[data-instance-id="${data.instanceId}"]`);
        if (card) {
            card.classList.add('focus-success');
            setTimeout(() => {
                card.classList.remove('focus-success');
            }, 1000);
        }
    }

    /// Handle focus_failure message from server
    /// Task: T053-T054 - display error feedback
    handleFocusFailure(data) {
        console.error('Focus failure:', data.error, data.message);

        // Task: T054 - show error message for missing accessibility permissions
        if (data.error === 'accessibility_permissions_required') {
            this.showError('Permissions Required', data.message);
        } else {
            this.showError('Window Switch Failed', data.message);
        }

        // Visual feedback on card
        const card = document.querySelector(`[data-instance-id="${data.instanceId}"]`);
        if (card) {
            card.classList.add('focus-error');
            setTimeout(() => {
                card.classList.remove('focus-error');
            }, 1000);
        }
    }

    // Task: T040 - connection status indicator
    updateConnectionStatus(state, text) {
        const statusDot = document.getElementById('status-dot');
        const statusText = document.getElementById('status-text');

        statusDot.className = 'status-dot';
        statusText.textContent = text;

        switch (state) {
            case 'connected':
                statusDot.classList.add('connected');
                break;
            case 'connecting':
                statusDot.classList.add('connecting');
                break;
            case 'disconnected':
            case 'error':
                // Default red color (no additional class)
                break;
        }
    }

    // Show error toast
    showError(title, message) {
        const toast = document.createElement('div');
        toast.className = 'error-toast';
        toast.innerHTML = `<strong>${title}:</strong> ${message}`;
        document.body.appendChild(toast);

        setTimeout(() => {
            toast.remove();
        }, 5000);
    }

    // Show success toast
    showSuccessToast(message) {
        const toast = document.createElement('div');
        toast.className = 'success-toast';
        toast.innerHTML = message;
        document.body.appendChild(toast);

        setTimeout(() => {
            toast.remove();
        }, 2000);
    }

    // Setup modal
    showSetupModal() {
        const modal = document.getElementById('setup-modal');
        const input = document.getElementById('server-url');
        const connectBtn = document.getElementById('connect-btn');

        // Try to auto-detect from current page URL
        const currentHost = window.location.hostname || 'localhost';
        input.value = `ws://${currentHost}:3001`; // WebSocket on port 3001, HTTP on 3000

        modal.classList.add('show');

        connectBtn.addEventListener('click', () => {
            const url = input.value.trim();
            if (url) {
                localStorage.setItem('agentdeck_server_url', url);
                this.serverUrl = url;
                modal.classList.remove('show');
                this.connect(url);
            }
        });

        // Allow Enter key to submit
        input.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                connectBtn.click();
            }
        });
    }

    // Setup event listeners
    setupEventListeners() {
        // Future: Add settings button, etc.
    }

    // Ping interval to keep connection alive
    startPingInterval() {
        this.pingInterval = setInterval(() => {
            if (this.ws && this.ws.readyState === WebSocket.OPEN) {
                this.ws.send(JSON.stringify({
                    type: 'ping',
                    timestamp: new Date().toISOString()
                }));
            }
        }, 30000); // 30 seconds per spec
    }

    stopPingInterval() {
        if (this.pingInterval) {
            clearInterval(this.pingInterval);
            this.pingInterval = null;
        }
    }

    // Format timestamp as relative time
    formatTimestamp(timestamp) {
        // Handle missing or undefined timestamp
        if (!timestamp) {
            return 'Just now';
        }

        const date = new Date(timestamp);

        // Handle invalid date (e.g., from undefined or malformed input)
        if (isNaN(date.getTime())) {
            return 'Just now';
        }

        const now = new Date();
        const seconds = Math.floor((now - date) / 1000);

        // Handle future dates or negative values
        if (seconds < 0) {
            return 'Just now';
        }

        if (seconds < 60) return `${seconds}s ago`;
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
        if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
        return `${Math.floor(seconds / 86400)}d ago`;
    }
}

// Initialize client when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    console.log('Agent Deck PWA initializing...');
    window.agentDeckClient = new AgentDeckClient();

    // Register service worker for offline capability (T092-T095)
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('/service-worker.js')
            .then((registration) => {
                console.log('Service Worker registered successfully:', registration.scope);

                // Check for updates periodically
                setInterval(() => {
                    registration.update();
                }, 60000); // Check every minute

                // Listen for updates
                registration.addEventListener('updatefound', () => {
                    const newWorker = registration.installing;
                    console.log('Service Worker update found');

                    newWorker.addEventListener('statechange', () => {
                        if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                            console.log('New Service Worker available. Reload to update.');
                            // Optionally show notification to user about update
                        }
                    });
                });
            })
            .catch((error) => {
                console.error('Service Worker registration failed:', error);
            });

        // Handle controller change (new service worker activated)
        navigator.serviceWorker.addEventListener('controllerchange', () => {
            console.log('Service Worker controller changed. Reloading...');
            window.location.reload();
        });
    } else {
        console.warn('Service Workers not supported in this browser');
    }
});
