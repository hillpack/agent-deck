# Feature Specification: Agent Deck MVP (Phases 1-2)

**Feature Branch**: `001-mvp`
**Created**: 2025-01-02
**Status**: Draft
**Input**: Agent Deck MVP - Native Mac dock app + React Native mobile app (Expo) for monitoring AI coding agents with real-time status updates and window switching

> **Architecture Note (Nov 2025):** Changed from menubar app to standard dock app due to menubar icon visibility issues on macOS. The app now displays in a standard window and lives in the Dock. Core functionality unchanged. Menubar functionality can be added back later.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Monitor Running AI Agents from Mobile (Priority: P1) 🎯 MVP

Developer runs Claude Code on their Mac while working. They step away from desk but want to see if their agent is still working or has encountered an error. They open Agent Deck mobile app on their phone, see real-time status of their Claude Code instance with rich context including: current task being executed, AI model name, git branch, active subagents, todo list with progress, and whether it's idle, working, done, or errored.

**Why this priority**: Core value proposition. Without this, there's no product. Solves the primary pain point: "I can't monitor my agents when away from my desk." Enhanced visibility (model, branch, todos, subagents) provides actionable context for decision-making.

**Independent Test**: Install Mac app, run Claude Code, open mobile app on phone, verify real-time status with rich data (model, branch, todos, subagents) appears and updates within 500ms of changes.

**Acceptance Scenarios**:

1. **Given** Mac app is running and Claude Code is active, **When** user opens mobile app on device, **Then** mobile app displays Claude Code instance with current status, working directory, and last update timestamp
2. **Given** mobile app is connected, **When** Claude Code status changes from idle to working, **Then** mobile UI updates status indicator color and displays new current task within 500ms
3. **Given** multiple Claude Code instances are running, **When** user views mobile app, **Then** all instances appear in list with independent status indicators
4. **Given** Claude Code encounters an error, **When** mobile app receives update, **Then** status indicator turns red and displays error state
5. **Given** network connection is lost, **When** mobile app detects disconnection, **Then** connection status indicator shows "Disconnected" and attempts auto-reconnect

---

### User Story 2 - Switch Windows from Mobile Device (Priority: P1) 🎯 MVP

Developer is away from desk when they see an agent needs attention on their phone. They tap the agent card in the mobile app, and the Mac instantly brings that agent's window to the front and focuses it. When they return to their desk, the correct window is already visible and ready for interaction.

**Why this priority**: Critical differentiator from pure monitoring tools. Enables remote control workflow that transforms mobile device into action tool, not just dashboard.

**Independent Test**: Open mobile app on phone, tap agent instance card, verify Mac switches to that window within 1 second and window is frontmost.

**Acceptance Scenarios**:

1. **Given** Claude Code window is in background, **When** user taps that instance card on mobile, **Then** Mac brings Claude Code window to front within 1 second
2. **Given** Claude Code is on different macOS Space, **When** user taps instance, **Then** Mac switches to correct Space and focuses window
3. **Given** multiple agents are running in different windows, **When** user taps specific instance, **Then** only that instance's window comes to front
4. **Given** window switching fails (accessibility permissions not granted), **When** user taps instance, **Then** mobile app displays error message explaining permission requirement
5. **Given** Mac app is not running, **When** user attempts to tap instance, **Then** mobile app displays "Mac app disconnected" state

---

### User Story 3 - Quick Mobile Setup via QR Code (Priority: P1) 🎯 MVP

Developer installs Mac app for first time. They click menubar icon, select "View Mobile Interface", and see a QR code with local network URL. They open Agent Deck mobile app on their phone, tap the QR scanner button, scan the QR code using the native camera interface, and the app automatically connects. Total setup time: under 60 seconds.

**Why this priority**: Zero-friction mobile setup is critical for adoption. If setup takes more than 2 minutes or requires typing long URLs, users abandon the product.

**Independent Test**: Install Mac app, open mobile app, scan QR code from menubar dropdown using native QR scanner, verify connection establishes successfully.

**Acceptance Scenarios**:

1. **Given** Mac app is running, **When** user opens menubar dropdown, **Then** dropdown displays QR code for mobile pairing
2. **Given** QR code is displayed, **When** user scans with mobile app's native QR scanner (expo-camera), **Then** mobile app automatically connects to Mac WebSocket server
3. **Given** mobile app successfully connects, **When** scanning completes, **Then** app navigates to main monitoring screen and displays connected status
4. **Given** devices are on different WiFi networks, **When** user tries to connect, **Then** mobile app displays error explaining same network requirement
5. **Given** Mac app port 3000 is already in use, **When** Mac app starts, **Then** Mac app displays error with suggestion to change port in settings

---

### User Story 4 - View Parsed Agent Output (Priority: P2)

Developer wants to see not just status, but what specific task Claude Code is working on. Mobile app displays parsed current task line extracted from Claude Code stdout (e.g., "Writing authentication tests"). This gives developer context about agent progress without returning to desk.

**Why this priority**: Enhances monitoring value with actionable context. P2 because basic status (P1) is sufficient for MVP validation, but parsed output significantly improves user experience.

**Independent Test**: Run Claude Code with active task output, verify mobile app displays current task description parsed from stdout.

**Acceptance Scenarios**:

1. **Given** Claude Code outputs "Currently: Writing tests", **When** mobile app receives update, **Then** current task section displays "Writing tests"
2. **Given** Claude Code output doesn't match expected pattern, **When** parser runs, **Then** current task shows "Unknown" or last known task
3. **Given** user toggles "Show current task" off, **When** mobile app refreshes, **Then** current task section is hidden from display
4. **Given** current task is very long text, **When** displayed on mobile, **Then** text truncates with ellipsis and remains readable

---

### User Story 5 - Install and Run Mac App Without Configuration (Priority: P2)

Developer downloads .app bundle, double-clicks to install, grants accessibility permissions when prompted, and Mac app immediately starts monitoring Claude Code instances without any configuration file editing or terminal commands. App appears in menubar with status icon.

**Why this priority**: Zero-config installation is critical for developer audience who value simplicity. P2 because early testers can handle basic setup, but production requires this.

**Independent Test**: Install Mac app on clean macOS system, verify it launches, appears in menubar, and detects running Claude Code without any configuration.

**Acceptance Scenarios**:

1. **Given** fresh Mac app install, **When** user double-clicks .app, **Then** app launches and menubar icon appears within 2 seconds
2. **Given** accessibility permissions not granted, **When** app needs window switching, **Then** macOS prompts user with permission dialog
3. **Given** no config file exists, **When** app starts, **Then** app creates default config at ~/.agent-deck/config.yaml
4. **Given** Claude Code is already running, **When** Mac app starts, **Then** app detects and lists instance in menubar dropdown within 2 seconds
5. **Given** app is running, **When** user quits, **Then** app stops cleanly without leaving background processes

---

### User Story 6 - Execute Custom Actions via Stream Deck Style Buttons (Priority: P3)

Developer wants quick access to frequently-used apps and commands while monitoring agents. Mobile app displays agent instances at the top, with an expandable panel below containing a 4-column grid of customizable square buttons. Each button has a label and icon. User can pull the panel up/down via a drag handle to reveal between 0 and 20 buttons. Tapping "Figma" button switches to Figma, tapping "Build" runs a build script, tapping "Browser" opens Chrome. Buttons are configured via YAML file with support for AppleScript, Bash, URL, and Apple Shortcuts.

**Why this priority**: Transforms Agent Deck from pure monitoring tool to productivity hub. P3 because agent monitoring (P1) and window switching (P1) must work first, but this significantly increases utility by enabling one-tap access to common workflows. Expandable panel maximizes screen real estate for monitoring while keeping quick actions accessible.

**Independent Test**: Configure 12 custom actions in YAML (Figma app launch, build script, browser), verify mobile app displays expandable panel with 4-column button grid, drag panel to show more/fewer buttons, tap buttons and confirm Mac executes commands within 1 second.

**Acceptance Scenarios**:

1. **Given** config contains custom action for Figma, **When** mobile app loads, **Then** mobile app displays "Figma" button with palette icon in 4-column custom actions grid below agent instances
2. **Given** custom action button is displayed, **When** user taps "Figma" button, **Then** Mac executes AppleScript to launch/focus Figma app within 1 second
3. **Given** custom action runs Bash script, **When** user taps button, **Then** Mac executes script and returns success/error status to mobile app
4. **Given** user has 12 custom actions configured, **When** viewing mobile app, **Then** all 12 buttons display in 4-column grid (3 rows) with labels and icons visible
5. **Given** custom action execution fails, **When** mobile app receives error response, **Then** mobile app shows toast notification with error message
6. **Given** no custom actions configured, **When** mobile app loads, **Then** custom actions section is hidden from display
7. **Given** custom action type is "url", **When** user taps button, **Then** Mac opens URL in default browser within 1 second
8. **Given** custom action type is "shortcut", **When** user taps button, **Then** Mac triggers named Apple Shortcut via assigned keyboard shortcut
9. **Given** target application is not installed, **When** mobile app displays action, **Then** button appears in disabled state with reduced opacity
10. **Given** custom actions panel is collapsed, **When** user drags handle upward, **Then** panel expands smoothly to reveal more buttons (up to 20 total)
11. **Given** custom actions panel is expanded, **When** user drags handle downward, **Then** panel collapses smoothly to show fewer buttons (down to 0)
12. **Given** user adjusts panel height, **When** mobile app reloads, **Then** panel restores previous height from AsyncStorage
13. **Given** 20+ custom actions are configured, **When** viewing mobile app, **Then** mobile app displays only first 20 buttons and ignores remainder

---

### Edge Cases

- What happens when Mac goes to sleep while mobile app is connected? (Expected: Mobile app shows disconnected, auto-reconnects on wake)
- What happens when Claude Code process terminates while being monitored? (Expected: Instance removed from list or marked as terminated)
- What happens when 10+ Claude Code instances are running simultaneously? (Expected: All listed, UI remains performant, scrollable list)
- What happens when user taps instance repeatedly within 1 second? (Expected: Debounce duplicate requests, execute once)
- What happens when WiFi network changes on either device? (Expected: Connection drops, user must re-scan QR code)
- What happens when port 3000 is already in use by another service? (Expected: Mac app shows error, offers to change port)
- What happens when custom action button is tapped while previous action still executing? (Expected: Queue or ignore until completion)
- What happens when custom action AppleScript references non-existent application? (Expected: Return error to mobile app with descriptive message)
- What happens when custom action Bash script has syntax errors or permission issues? (Expected: Return execution error to mobile app)
- What happens when user configures 20+ custom actions? (Expected: Mobile app displays first 20 in 4-column grid, ignores remainder)
- What happens when user drags custom actions panel handle rapidly up and down? (Expected: Smooth animation, no UI glitches, debounce panel state saves)
- What happens when user collapses panel to 0 buttons visible and reloads mobile app? (Expected: Panel remains collapsed at 0, AsyncStorage persists state)
- What happens when user is dragging panel and loses WebSocket connection? (Expected: Drag interaction continues, panel state persists independently)

## Requirements *(mandatory)*

### Functional Requirements

**Mac Application Core**:
- **FR-001**: System MUST detect running Claude Code processes using macOS process monitoring APIs
- **FR-002**: System MUST run as dock application with standard window (menubar functionality optional) that displays agent activity status
- **FR-003**: System MUST provide menubar dropdown showing list of detected agent instances with status
- **FR-004**: System MUST start embedded WebSocket server on configurable port (default 3000) for real-time communication
- **FR-005**: System MUST expose WebSocket server on local network for mobile app connections
- **FR-006**: System MUST generate QR code containing local network URL (ws://[IP]:3000) for mobile device pairing
- **FR-007**: System MUST broadcast agent status updates via WebSocket when any instance state changes
- **FR-008**: System MUST execute AppleScript to focus/activate window when receiving focus command from mobile
- **FR-009**: System MUST create default YAML configuration file at ~/.agent-deck/config.yaml if none exists
- **FR-010**: System MUST persist user preferences (port, auto-start on login) using UserDefaults

**Mobile Interface (React Native)**:
- **FR-011**: Mobile app MUST connect to Mac WebSocket server using URL from QR code or manual entry
- **FR-012**: Mobile app MUST display list of agent instances with color-coded status indicators (idle: gray, working: blue, done: green, error: red)
- **FR-013**: Mobile app MUST show per-instance metadata: agent type, working directory, timestamp of last activity
- **FR-014**: Mobile app MUST update display within 500ms when receiving status change via WebSocket
- **FR-015**: Mobile app MUST send window focus command to Mac when user taps agent instance card
- **FR-016**: Mobile app MUST display connection status indicator and show "Disconnected" when WebSocket connection lost
- **FR-017**: Mobile app MUST attempt automatic reconnection with exponential backoff when connection drops
- **FR-018**: Mobile app MUST be native iOS/Android application built with React Native (Expo SDK 50+)
- **FR-019**: Mobile app MUST provide native offline capabilities with AsyncStorage for connection persistence
- **FR-020**: Mobile app MUST persist display settings (show/hide sections) to AsyncStorage

**Agent Output Parsing**:
- **FR-021**: System MUST parse Claude Code stdout to extract current task line (e.g., line starting with "Currently:")
- **FR-022**: System MUST store parsed current task separately from raw status for independent display toggling
- **FR-023**: System MUST handle unparseable output gracefully by showing last known task or "Unknown"
- **FR-065**: System MUST parse and display active subagents from Claude Code transcript
- **FR-066**: System MUST parse and display todo list with status indicators (pending, in_progress, completed) from transcript
- **FR-067**: System MUST extract and display AI model name and current git branch from transcript

**Process Monitoring**:
- **FR-024**: System MUST poll for process changes every 1-2 seconds to detect new instances and terminated processes
- **FR-025**: System MUST track per-instance: PID, executable path, working directory, window ID for focus switching
- **FR-026**: System MUST remove instances from list when process terminates
- **FR-027**: System MUST support monitoring Claude Code only in Phase 1-2 (Cursor/Windsurf in Phase 3+)

**Window Management**:
- **FR-028**: System MUST use AppleScript to focus window by process PID
- **FR-029**: System MUST switch to correct macOS Space if target window is on different Space
- **FR-030**: System MUST return success/failure status to mobile client after window switch attempt
- **FR-031**: System MUST provide clear error message when accessibility permissions not granted

**Configuration**:
- **FR-032**: System MUST load configuration from ~/.agent-deck/config.yaml with schema: server port, host, agent patterns
- **FR-033**: System MUST provide settings window accessible from menubar with tabs: General, Agents, Mobile, About
- **FR-034**: Users MUST be able to configure server port and auto-start on login via settings UI

**Custom Actions**:
- **FR-035**: System MUST load custom actions from YAML configuration with schema: action id, label, icon (emoji), action type (applescript/bash/url/shortcut), and command/script content
- **FR-036**: System MUST broadcast custom actions list to mobile app via WebSocket on initial connection
- **FR-037**: System MUST execute AppleScript commands when receiving custom action request with type "applescript"
- **FR-038**: System MUST execute Bash scripts when receiving custom action request with type "bash"
- **FR-039**: System MUST return execution result (success/error) to mobile app within 2 seconds of action execution
- **FR-040**: System MUST prevent concurrent execution of the same custom action (queue or reject duplicate requests)
- **FR-041**: System MUST provide error messages when custom action fails (e.g., "Application 'Figma' not found", "Script execution failed: permission denied")
- **FR-042**: Mobile app MUST display custom actions as grid of square buttons with label and emoji icon, with minimum touch target size of 44×44 pixels
- **FR-043**: Mobile app MUST send custom action execution request to Mac when user taps action button
- **FR-044**: Mobile app MUST show loading indicator on button while action executes
- **FR-045**: Mobile app MUST display toast notification with success/error message after action completes
- **FR-046**: Mobile app MUST hide custom actions section when no actions are configured
- **FR-047**: System MUST open URLs in default browser when receiving custom action request with type "url"
- **FR-048**: System MUST trigger Apple Shortcuts via assigned keyboard shortcut when receiving custom action request with type "shortcut"
- **FR-049**: Mobile app MUST display button disabled state (reduced opacity) when action prerequisites not met
- **FR-050**: System MUST validate action prerequisites before execution and return disabled state to mobile app (e.g., check if target application is installed)
- **FR-051**: Mobile app MUST display custom actions in 4-column grid layout below agent instances section
- **FR-052**: Mobile app MUST provide expandable/collapsible panel with visual drag handle positioned between agent instances and custom actions grid
- **FR-053**: Mobile app MUST support displaying 0-20 custom action buttons with smooth expand/collapse animation via drag interaction
- **FR-054**: Mobile app MUST persist panel state (height, visible button count) to AsyncStorage and restore on reload
- **FR-055**: Mobile app MUST position agent instances section above custom actions panel with clear visual separator (drag handle)

**Native Mobile Features**:
- **FR-056**: Mobile app MUST provide keep screen awake toggle for continuous monitoring without device sleep
- **FR-057**: Mobile app MUST use native QR code scanner (expo-camera with barcode scanning) for pairing with Mac app
- **FR-058**: Mobile app MUST support development via Expo Go for rapid iteration during Phase 1-2
- **FR-059**: Mobile app MUST build for iOS 15+ and Android 8+ (API level 26+) minimum targets per constitution

### Key Entities

- **AgentInstance**: Represents a running AI coding agent process
  - Attributes: unique ID (UUID), PID, agent type (e.g., "claude-code"), working directory path, current status (idle/working/done/error), current task description (nullable), last activity timestamp, window identifier for focus switching, model name (nullable), git branch (nullable), active subagents array (nullable), todos array (nullable), current task description from activeForm (nullable)

- **SubagentInfo**: Represents an active subagent spawned by the main agent
  - Attributes: agent ID, type (e.g., "Explore", "general-purpose"), description

- **TodoItem**: Represents a task from the agent's todo list
  - Attributes: id, content (imperative form), status (pending/in_progress/completed), activeForm (present continuous form)

- **StatusUpdate**: Real-time status change event
  - Attributes: instance ID, new status value, current task text (nullable), timestamp
  - Broadcast via WebSocket when any tracked field changes

- **Configuration**: Application settings
  - Attributes: server port number, server host address, auto-start enabled flag, agent monitoring patterns (process name regexes)
  - Persisted to YAML file, loaded on app start

- **CustomAction**: User-defined command or script executable from PWA
  - Attributes: unique action ID, display label, icon (emoji or Material Symbol), action type (applescript/bash/url/shortcut), command or script content, target URL (for url type), keyboard shortcut (for shortcut type), execution status, prerequisites validation (e.g., is target app installed)
  - Loaded from YAML configuration, broadcast to PWA on connection
  - PWA displays in 4-column grid with expandable panel (0-20 buttons visible)

- **WebSocketConnection**: Active connection from mobile client
  - Attributes: connection ID, remote IP address, connected timestamp
  - Multiple concurrent connections supported

## Success Criteria *(mandatory)*

### Measurable Outcomes

**Performance & Responsiveness**:
- **SC-001**: Status updates appear on mobile device within 500ms of agent state change on Mac
- **SC-002**: Window switching executes within 1 second from mobile tap to Mac window focus
- **SC-003**: Mac app uses less than 100MB RAM during normal operation (monitoring 3 agents)
- **SC-004**: Mac app uses less than 2% CPU when idle, less than 5% when actively monitoring
- **SC-005**: Mac app launches and appears in menubar within 2 seconds of user double-clicking .app
- **SC-019**: Custom action execution completes within 2 seconds from mobile tap to Mac execution (excluding long-running scripts)

**User Experience & Setup**:
- **SC-006**: Users complete mobile setup (QR scan to connection) in under 60 seconds
- **SC-007**: Mac app detects running Claude Code instances within 2 seconds of app startup
- **SC-008**: Mobile app loads and displays agent list within 3 seconds of connection
- **SC-009**: 90% of users successfully install and connect mobile device on first attempt without documentation

**Reliability & Stability**:
- **SC-010**: System handles 3+ concurrent Claude Code instances without performance degradation
- **SC-011**: Mobile app reconnects automatically within 5 seconds after network interruption
- **SC-012**: System runs continuously for 24+ hours without crashes or memory leaks
- **SC-013**: Window switching succeeds 95%+ of attempts when accessibility permissions granted
- **SC-020**: Custom actions fail gracefully with descriptive error messages when execution errors occur (app not found, permission denied, etc.)
- **SC-021**: Custom action buttons meet minimum 44×44 pixel touch target size for accessibility compliance

**Platform Compatibility**:
- **SC-014**: Mac app runs on macOS 12 (Monterey) through macOS 14 (Sonoma) without compatibility issues
- **SC-015**: React Native mobile app works on iOS 15+ and Android 8+ (API level 26+) without functionality loss
- **SC-016**: Native mobile app installs via Expo Go (development) or app stores (future production)

**Adoption & Validation** (Phase 1-2 End Goal):
- **SC-017**: 10+ early testers successfully run Agent Deck MVP without critical bugs
- **SC-018**: Positive feedback from Show HN launch indicating product-market fit potential

## Assumptions *(optional)*

### Custom Actions Configuration Format

Custom actions are configured via YAML at `~/.agent-deck/config.yaml`. The configuration supports four action types with the following schema:

```yaml
custom_actions:
  - id: "focus-ide"
    label: "Focus IDE"
    icon: "code_blocks"  # Material Symbol or emoji
    type: "applescript"
    command: |
      tell application "Visual Studio Code"
        activate
      end tell

  - id: "run-tests"
    label: "Run Tests"
    icon: "bug_report"
    type: "bash"
    command: "cd ~/project && npm test"

  - id: "open-docs"
    label: "Docs"
    icon: "description"
    type: "url"
    url: "https://docs.example.com"

  - id: "deploy"
    label: "Deploy"
    icon: "rocket_launch"
    type: "shortcut"
    shortcut: "cmd+shift+d"  # Triggers named Apple Shortcut
```

**Validation Rules**:
- Maximum 20 custom actions supported (PWA displays first 20, ignores remainder)
- Action IDs must be unique within configuration
- Icons can be Material Symbol names or single emoji characters
- AppleScript and Bash commands execute on Mac with user's permissions
- URL type opens in default browser
- Shortcut type requires corresponding Apple Shortcut configured on Mac

**Default Actions** (if user does not provide custom configuration):
- No default actions are provided
- Custom actions section is hidden when none configured
- Users must manually add actions to YAML to enable feature
