# Tasks: Agent Deck MVP (Phases 0-2)

**Input**: Design documents from `/specs/001-mvp/`
**Prerequisites**: plan.md (required), spec.md (required), data-model.md, contracts/websocket-protocol.md

> **Architecture Note (Nov 2025):** Changed from menubar app to standard dock app due to menubar icon visibility issues on macOS. The app now displays in a standard window and lives in the Dock. Core functionality unchanged.

**Tests**: Manual testing only in Phase 1-2 (per constitution). No automated test tasks generated.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Project structure (monorepo):
- **Root**: pnpm workspace with apps/ and packages/
- **Mac app**: `apps/macos/` (Swift/SwiftUI dock app with standard window)
- **Mobile app**: `apps/mobile/` (React Native with Expo SDK 50+)
- **Shared types**: `packages/shared-types/` (TypeScript type definitions)
- **Package manager**: pnpm

---

## Phase 0: Monorepo Setup (Project Infrastructure)

**Purpose**: Set up monorepo structure with pnpm, reorganize project, and initialize React Native mobile app

**⚠️ CRITICAL**: This phase MUST be complete before ANY other work begins

- [x] T000 [P] Create pnpm workspace configuration
  - Create pnpm-workspace.yaml in repository root
  - Create root package.json with workspace configuration
  - Dependencies: none
  - Estimate: 1 hour

- [x] T001 Reorganize directory structure
  - Create apps/ and packages/ directories at repository root
  - Move Agent-Deck/ to apps/macos/ using `git mv Agent-Deck apps/macos`
  - Preserve git history during move
  - Dependencies: none
  - Estimate: 1 hour

- [x] T002 [P] Create shared-types package
  - Create packages/shared-types/ directory structure
  - Create packages/shared-types/package.json with name "@agent-deck/shared-types"
  - Create packages/shared-types/tsconfig.json
  - Create packages/shared-types/src/index.ts as main export
  - Dependencies: "Reorganize directory structure"
  - Estimate: 2 hours

- [x] T003 [P] Define TypeScript interfaces in shared-types
  - Create src/AgentInstance.ts with AgentInstance, AgentStatus types
  - Create src/StatusUpdate.ts with StatusUpdate, MessageType types
  - Create src/SubagentInfo.ts with SubagentInfo type
  - Create src/TodoItem.ts with TodoItem, TodoStatus types
  - Create src/WebSocketMessage.ts with all WebSocket message types
  - Export all types from src/index.ts
  - Dependencies: "Create shared-types package"
  - Estimate: 3 hours

- [x] T004 Initialize Expo React Native project
  - Run `npx create-expo-app@latest apps/mobile --template expo-template-blank-typescript`
  - Configure for TypeScript
  - Update apps/mobile/package.json to add "@agent-deck/shared-types": "workspace:*"
  - Update apps/mobile/tsconfig.json to include shared-types
  - Dependencies: "Define TypeScript interfaces in shared-types"
  - Estimate: 2 hours

- [x] T005 [P] Update .gitignore for monorepo
  - Add Node.js patterns (node_modules/, pnpm-debug.log, .pnpm-store/)
  - Add React Native patterns (.expo/, web-build/, dist/)
  - Add macOS patterns (.DS_Store, xcuserdata/)
  - Keep existing Swift/Xcode patterns
  - Dependencies: none
  - Estimate: 30 minutes

- [x] T006 Validate monorepo setup
  - Run `pnpm install` from repository root
  - Verify shared-types builds: `cd packages/shared-types && pnpm build`
  - Test Swift app builds: `xcodebuild -project apps/macos/Agent-Deck.xcodeproj -scheme Agent-Deck build`
  - Test Expo app starts: `cd apps/mobile && pnpm expo start`
  - Verify mobile app can import @agent-deck/shared-types
  - Dependencies: ALL Phase 0 tasks
  - Estimate: 1 hour

**Checkpoint**: Monorepo infrastructure ready - all subsequent work can now proceed

**Phase 0 Total Estimate**: ~11 hours (~1.5 days)

---

## Phase 1: Setup (Mac App Initialization)

**Purpose**: Mac app initialization and basic structure

**Dependencies**: Phase 0 complete

- [x] T007 Create Xcode project AgentDeck-Mac in apps/macos/ directory
- [x] T008 Configure project settings: Bundle ID com.agentdeck.mac, macOS 12+ deployment target
- [x] T009 Edit Info.plist to add LSUIElement=true and NSAllowsLocalNetworking=true
- [x] T010 [P] Add Swift Package dependency: Yams (https://github.com/jpsim/Yams.git, version 5.0+)
- [x] T011 [P] Create folder structure: Sources/{Models,Services,Views,Utilities}, Resources/
- [x] T012 [P] Create Resources/Assets.xcassets for app icons
- [x] T013 Create default YAML configuration template in Resources/default-config.yaml

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

**Dependencies**: Phase 1 complete

- [x] T014 [P] Create AgentInstance model in apps/macos/Sources/Models/AgentInstance.swift
- [x] T015 [P] Create AgentStatus enum in apps/macos/Sources/Models/AgentStatus.swift with values: idle, working, done, error
- [x] T016 [P] Create StatusUpdate model in apps/macos/Sources/Models/StatusUpdate.swift
- [x] T017 [P] Create Configuration model in apps/macos/Sources/Models/Configuration.swift
- [x] T018 Implement ConfigManager service in apps/macos/Sources/Services/ConfigManager.swift with YAML loading
- [x] T019 Create default config file at runtime in ~/.agent-deck/config.yaml if missing
- [x] T020 Implement Logger utility in apps/macos/Sources/Utilities/Logger.swift using os.log
- [x] T021 Create AppDelegate in apps/macos/Sources/AppDelegate.swift for menubar app lifecycle
- [x] T022 Configure NSStatusBar menubar item with icon in AppDelegate
- [x] T023 Create AgentDeckApp.swift with @main entry point setting LSUIElement policy

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Monitor Running AI Agents from Mobile (Priority: P1) 🎯 MVP

**Goal**: Enable real-time monitoring of Claude Code instances from React Native mobile app with status updates under 500ms and basic task parsing

**Independent Test**: Install Mac app, run Claude Code, open React Native app on phone, verify real-time status and current task appear and update within 500ms

**Dependencies**: Phase 2 complete

### Implementation for User Story 1

#### Mac App Backend (Swift)

- [x] T024 [P] [US1] Implement ProcessMonitor service in apps/macos/Sources/Services/ProcessMonitor.swift using NSWorkspace
- [x] T025 [P] [US1] Implement polling timer (every 500ms) using Combine in ProcessMonitor
- [x] T026 [US1] Add process detection logic filtering by executable name pattern "claude.*code"
- [x] T027 [US1] Extract PID, working directory, and window ID for detected processes
- [x] T028 [US1] Create and update AgentInstance objects when process state changes
- [x] T029 [US1] Remove AgentInstance from list when process terminates
- [x] T030 [P] [US1] Implement WebSocketServer service in apps/macos/Sources/Services/WebSocketServer.swift using Network.framework
- [x] T031 [US1] Implement WebSocket handshake and connection management in WebSocketServer
- [x] T032 [US1] Implement initial_state message broadcast on client connect
- [x] T033 [US1] Implement update message broadcast on status change (within 500ms requirement)
- [x] T034 [US1] Implement instance_added and instance_removed message types
- [x] T035 [P] [US1] Create MenuBarView in apps/macos/Sources/Views/MenuBarView.swift with agent list display
- [x] T036 [US1] Display detected agent instances in menubar dropdown with status indicators

#### React Native Mobile App

- [x] T037 [P] [US1] Create AgentListScreen component in apps/mobile/src/screens/AgentListScreen.tsx
  - Import AgentInstance, AgentStatus types from @agent-deck/shared-types
  - Display agent instances in FlatList with color-coded status
  - Show agent type, working directory, last activity timestamp
  - Dependencies: "Define TypeScript interfaces in shared-types"
  - Estimate: 4 hours

- [x] T038 [P] [US1] Implement useWebSocket custom hook in apps/mobile/src/hooks/useWebSocket.ts
  - Use React Native WebSocket API (native support)
  - Handle connection, reconnection with exponential backoff (1s→2s→4s→8s→16s max)
  - Parse incoming WebSocket messages (initial_state, update, instance_added, instance_removed)
  - Import WebSocketMessage types from @agent-deck/shared-types
  - Dependencies: "Define TypeScript interfaces in shared-types"
  - Estimate: 5 hours

- [x] T039 [US1] Implement WebSocket connection logic in AgentListScreen
  - Use useWebSocket hook with URL from QR code scanner or manual entry
  - Display connection status indicator ("Connected" / "Disconnected")
  - Handle initial_state message to populate agent list
  - Update agent list on update, instance_added, instance_removed messages
  - Ensure UI updates appear within 500ms of receiving message
  - Dependencies: "Implement useWebSocket custom hook"
  - Estimate: 3 hours

- [x] T040 [P] [US1] Create AgentCard component in apps/mobile/src/components/AgentCard.tsx
  - Display agent status with color-coded indicator (idle:gray, working:blue, done:green, error:red)
  - Show agent metadata: name, type, working directory
  - Show last activity timestamp
  - Touchable area for tap interaction (User Story 2)
  - Dependencies: "Define TypeScript interfaces in shared-types"
  - Estimate: 3 hours

- [x] T041 [P] [US1] Create dark mode styles in apps/mobile/src/styles/theme.ts
  - Define color palette for dark mode
  - Export theme object for use across components
  - Dependencies: none
  - Estimate: 1 hour

- [x] T042 [US1] Apply dark mode theme to AgentListScreen and AgentCard
  - Use theme colors for background, text, borders
  - Ensure readability and touch target sizes (44px minimum)
  - Dependencies: "Create dark mode styles", "Create AgentCard component"
  - Estimate: 2 hours

#### Basic Output Parsing (Mac App)

- [x] T043 [P] [US1] Implement basic OutputParser service in apps/macos/Sources/Services/OutputParser.swift
- [x] T044 [US1] Implement regex pattern matching for "Currently:" prefix in Claude Code stdout
- [x] T045 [US1] Extract task description from matched line (max 200 chars, truncate if longer)
- [x] T046 [US1] Handle unparseable output gracefully (show "Unknown" or last known task)
- [x] T047 [US1] Store parsed currentTask in AgentInstance model
- [x] T048 [US1] Include currentTask in StatusUpdate WebSocket messages
- [x] T049 [US1] Display currentTask in React Native UI below agent status indicator
  - Update AgentCard component to show currentTask field
  - Handle truncation for long task descriptions
  - Dependencies: "Create AgentCard component"
  - Estimate: 1 hour

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently (monitoring + basic parsing)

### Rich Data Enhancement (Phase 3 Extension)

**Purpose**: Add enhanced parsing for model name, git branch, subagents, and todo list

#### Mac App Rich Data Parsing

- [x] T050 [P] [US1] Create SubagentInfo model in apps/macos/Sources/Models/SubagentInfo.swift
- [x] T051 [P] [US1] Create TodoItem model in apps/macos/Sources/Models/TodoItem.swift with TodoStatus enum
- [x] T052 [US1] Add rich data fields to AgentInstance: modelName, gitBranch, activeSubagents, todos, currentTaskDescription
- [x] T053 [P] [US1] Create TranscriptParser service in apps/macos/Sources/Services/TranscriptParser.swift
- [x] T054 [US1] Implement parseModelName() to extract model from transcript JSON
- [x] T055 [US1] Implement parseSubagents() to extract active subagents from Task tool invocations
- [x] T056 [US1] Implement parseTodos() to extract todo list with status from TodoWrite tool
- [x] T057 [US1] Implement parseActiveForm() to extract currentTaskDescription from in_progress todos
- [x] T058 [P] [US1] Implement git branch detection using git commands in working directory
- [x] T059 [US1] Integrate TranscriptParser into ProcessMonitor for real-time parsing
- [x] T060 [US1] Update WebSocket messages to include rich data fields

#### React Native Rich Data Display

- [x] T061 [P] [US1] Update AgentCard to display model name and git branch
  - Show model name as badge (e.g., "claude-sonnet-4-5")
  - Show git branch with icon (e.g., " main")
  - Dependencies: "Create AgentCard component"
  - Estimate: 2 hours

- [x] T062 [P] [US1] Create SubagentsSection component in apps/mobile/src/components/SubagentsSection.tsx
  - Display active subagents in expandable/collapsible section
  - Show subagent type and status
  - Import SubagentInfo type from @agent-deck/shared-types
  - Dependencies: "Define TypeScript interfaces in shared-types"
  - Estimate: 3 hours

- [x] T063 [P] [US1] Create TodosSection component in apps/mobile/src/components/TodosSection.tsx
  - Display todo list in expandable/collapsible section
  - Color-code todos by status (pending, in_progress, completed)
  - Import TodoItem type from @agent-deck/shared-types
  - Dependencies: "Define TypeScript interfaces in shared-types"
  - Estimate: 3 hours

- [x] T064 [US1] Integrate SubagentsSection and TodosSection into AgentCard
  - Add expand/collapse functionality
  - Ensure smooth animations
  - Persist expand/collapse state to AsyncStorage
  - Dependencies: "Create SubagentsSection component", "Create TodosSection component"
  - Estimate: 2 hours

**Checkpoint**: Rich data enhancement complete - User Story 1 now includes comprehensive context

---

## Phase 4: User Story 2 - Switch Windows from Mobile Device (Priority: P1) 🎯 MVP

**Goal**: Enable remote window switching from mobile tap to Mac window focus within 1 second

**Independent Test**: Open React Native app on phone, tap agent instance card, verify Mac switches to that window within 1 second

**Dependencies**: User Story 1 complete

### Implementation for User Story 2

#### Mac App Window Management

- [x] T065 [P] [US2] Implement WindowManager service in apps/macos/Sources/Services/WindowManager.swift
- [x] T066 [US2] Implement AppleScript window focus by PID in WindowManager
- [x] T067 [US2] Handle cross-macOS Space window switching in AppleScript
- [x] T068 [US2] Return success/failure status after window switch attempt
- [x] T069 [US2] Check for accessibility permissions before window switch
- [x] T070 [US2] Add focus message handler in WebSocketServer receiving instanceId
- [x] T071 [US2] Call WindowManager.focusWindow on receiving focus message
- [x] T072 [US2] Send focus_success message to client within 1 second of receiving focus command
- [x] T073 [US2] Send focus_failure message with error code and actionable message on failure

#### React Native Tap Interaction

- [x] T074 [US2] Implement tap event handler on AgentCard component
  - Make AgentCard touchable using TouchableOpacity
  - Add visual feedback on press (scale animation)
  - Send focus WebSocket message with instanceId on tap
  - Dependencies: "Create AgentCard component", "Implement useWebSocket custom hook"
  - Estimate: 2 hours

- [x] T075 [US2] Display success/failure feedback in React Native UI
  - Show toast notification on focus_success
  - Show error alert on focus_failure
  - Use react-native-toast-message or similar library
  - Dependencies: "Implement tap event handler on AgentCard"
  - Estimate: 2 hours

- [x] T076 [US2] Show accessibility permissions error message
  - Display actionable error when focus_failure indicates missing permissions
  - Provide instructions to enable accessibility in macOS System Settings
  - Dependencies: "Display success/failure feedback"
  - Estimate: 1 hour

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Quick Mobile Setup via QR Code (Priority: P1) 🎯 MVP

**Goal**: Enable mobile setup in under 60 seconds via QR code pairing

**Independent Test**: Install Mac app, scan QR code from menubar dropdown, verify React Native app loads and connects

**Dependencies**: User Story 1 complete

### Implementation for User Story 3

#### Mac App QR Code Generation

- [x] T077 [P] [US3] Implement QR code generation in apps/macos/Sources/Utilities/QRGenerator.swift using CoreImage
- [x] T078 [US3] Implement local IP address discovery using getifaddrs() filtering en0 interface
- [x] T079 [US3] Generate QR code containing local network URL (http://<ip>:3000)
- [x] T080 [US3] Create QRCodeView in apps/macos/Sources/Views/QRCodeView.swift displaying QR code
- [x] T081 [US3] Add "View Mobile Interface" menu item in MenuBarView showing QR code
- [x] T082 [US3] Display local network URL text alongside QR code for manual entry
- [x] T083 [US3] Add error handling for missing WiFi connection (no IP available)
- [x] T084 [US3] Add error handling for port 3000 already in use (suggest port change)

#### React Native QR Code Scanner

- [x] T085 [P] [US3] Implement QR code scanner screen in apps/mobile/src/screens/QRScannerScreen.tsx
  - Use expo-camera package (expo-barcode-scanner is deprecated)
  - Request camera permissions on mount
  - Parse scanned QR code for WebSocket URL
  - Navigate to AgentListScreen on successful scan
  - Dependencies: "Initialize Expo React Native project"
  - Estimate: 4 hours

- [x] T086 [US3] Create app navigation structure in apps/mobile/src/navigation/
  - Use @react-navigation/native-stack (v7)
  - Create stack navigator with QRScannerScreen, AgentListScreen, SettingsScreen
  - Set QRScannerScreen as initial route if no saved connection
  - Dependencies: "Implement QR code scanner screen"
  - Estimate: 2 hours

- [x] T087 [US3] Implement manual URL entry fallback in QRScannerScreen
  - Add TextInput for manual WebSocket URL entry
  - Validate URL format before connecting
  - Save URL to AsyncStorage for auto-connect on next launch
  - Dependencies: "Implement QR code scanner screen"
  - Estimate: 2 hours

- [x] T088 [US3] Display connection error messages in React Native app
  - Show error when devices on different networks
  - Show error when Mac app is not running (connection refused)
  - Provide troubleshooting tips
  - Dependencies: "Create app navigation structure"
  - Estimate: 1 hour

**Checkpoint**: All P1 user stories (MVP core) should now be fully functional

---

## Phase 6: React Native App Polish

**Purpose**: Essential mobile app features and user experience improvements

**Dependencies**: User Story 3 complete

- [x] T089 [P] Create keep screen awake toggle in apps/mobile/src/hooks/useKeepAwake.ts
  - Use expo-keep-awake package
  - Add toggle in settings/preferences screen
  - Persist setting to AsyncStorage
  - Dependencies: "Initialize Expo React Native project"
  - Estimate: 2 hours

- [x] T090 [P] Create app icon and splash screen
  - Design 1024x1024 app icon
  - Configure app.json with icon and splash screen
  - Use expo-splash-screen for native splash
  - Dependencies: "Initialize Expo React Native project"
  - Estimate: 2 hours

- [x] T091 [P] Implement pull-to-refresh in AgentListScreen
  - Use RefreshControl component
  - Trigger manual reconnection on pull
  - Show loading indicator
  - Dependencies: "Create AgentListScreen component"
  - Estimate: 1 hour

- [x] T092 [P] Add connection status header in AgentListScreen
  - Show WebSocket connection state (connecting, connected, disconnected)
  - Display Mac app IP address
  - Add reconnect button
  - Dependencies: "Create AgentListScreen component"
  - Estimate: 2 hours

- [x] T093 Create settings/preferences screen in apps/mobile/src/screens/SettingsScreen.tsx
  - Add WebSocket URL configuration
  - Add keep awake toggle
  - Add disconnect/reconnect functionality
  - Add about/version information
  - Dependencies: "Create app navigation structure"
  - Estimate: 3 hours

---

## Phase 7: User Story 4 - Advanced Parsed Output (Todo List + Status Line) (Priority: P2)

**Goal**: Display advanced parsed output (todo list, status line) from Claude Code for comprehensive context

**Independent Test**: Run Claude Code with todo list output, verify React Native app displays todo items and status line

**Note**: Basic parsing (current task) is part of User Story 1 (Phase 3). This phase adds todo list and status line parsing.

**Dependencies**: User Story 1 complete

### Implementation for User Story 4

- [x] T094 [P] [US4] Extend OutputParser service to parse todo list (markdown checkboxes)
  - ✅ Implemented via TranscriptParser.swift using TodoWrite JSON (superior to markdown regex)
- [x] T095 [US4] Implement regex pattern matching for todo items (lines starting with `- [ ]` or `- [x]`)
  - ✅ Superseded by TranscriptParser JSON parsing from TodoWrite tool calls
- [x] T096 [US4] Extract todo list with completion status (checked vs unchecked)
  - ✅ TranscriptParser.extractTodos() extracts status (pending/in_progress/completed)
- [x] T097 [US4] Handle multi-line todo items
  - ✅ TodoWrite JSON format handles multi-line content natively
- [x] T098 [P] [US4] Implement status line extraction (last line of output or designated marker)
  - ✅ TranscriptParser.extractLastStatement() captures Claude's last message
- [x] T099 [US4] Store todo list and status line separately in AgentInstance model
  - ✅ AgentInstance has todos: [TodoItem] and lastStatement: String? fields
- [x] T100 [US4] Include todo list and status line in StatusUpdate WebSocket messages
  - ✅ AgentInstance.toDictionary() serializes todos array to WebSocket
- [x] T101 [US4] Update TodosSection component to display advanced todo list
  - ✅ Collapsible todos section with badge showing "N/M ✓" count
  - ✅ Color-coded by status (pending=gray, in_progress=blue, completed=green)
  - ✅ Progress bar showing completion percentage
  - ✅ Multi-line todo support with status icons (○ pending, ◐ in_progress, ✓ completed)
  - ✅ Shows activeForm for in_progress tasks, content for others
  - Dependencies: "Create TodosSection component"
  - Actual: 2 hours
- [x] T102 [US4] Display status line in React Native UI as footer in AgentCard
  - ✅ lastStatement field added to AgentInstance in shared-types
  - ✅ Footer section with monospace font and electric-blue left border
  - ✅ Truncates to 2 lines with numberOfLines={2}
  - ✅ Subtle background color (secondary-dark/50)
  - Dependencies: "Create AgentCard component"
  - Actual: 1 hour
- [x] T103 [US4] Implement toggle to show/hide advanced sections
  - ✅ Expand/collapse toggle for todos section (▶/▼ icon)
  - ✅ Smooth height animation with LayoutAnimation
  - ✅ Persists expand/collapse state to AsyncStorage per agent
  - ✅ Android LayoutAnimation support enabled via UIManager
  - Dependencies: "Update TodosSection component", "Display status line"
  - Actual: 1 hour

**Checkpoint**: User Story 4 adds advanced parsing, enhancing basic monitoring from US1

---

## Phase 8: User Story 5 - Install and Run Mac App Without Configuration (Priority: P2)

**Goal**: Zero-config installation with automatic Claude Code detection

**Independent Test**: Install Mac app on clean macOS, verify it launches and detects Claude Code without configuration

**Dependencies**: User Stories 1, 2 complete

### Implementation for User Story 5

- [x] T104 [P] [US5] Implement first-launch detection in AppDelegate
- [x] T105 [US5] Create default config file at ~/.agent-deck/config.yaml on first launch
- [x] T106 [US5] Load default agent patterns (claude.*code) from Resources/default-config.yaml
- [x] T107 [US5] Implement accessibility permissions check on first window switch attempt
- [x] T108 [US5] Display macOS permission dialog prompt when accessibility needed
- [x] T109 [US5] Implement clean shutdown in AppDelegate.applicationWillTerminate
- [x] T110 [US5] Verify no background processes left after quit
- [x] T111 [P] [US5] Create SettingsView in apps/macos/Sources/Views/SettingsView.swift with tabs
- [x] T112 [US5] Implement General settings tab (port configuration, auto-start)
- [x] T113 [US5] Implement Agents settings tab (enable/disable monitoring)
- [x] T114 [US5] Implement Mobile settings tab (show QR code, connection status)
- [x] T115 [US5] Implement About settings tab (version, credits)
- [x] T116 [US5] Persist port and auto-start settings to UserDefaults
- [x] T117 [US5] Reload configuration when settings change

**Checkpoint**: All user stories (P1 + P2) should now be independently functional

---

## Phase 9: Integration Testing & Bug Fixes

**Purpose**: End-to-end validation, smoke test scripts for latency validation, and critical bug fixes

**Dependencies**: All desired user stories complete

- [ ] T118 Test Mac app launch and menubar icon appearance (target: <2s)
- [ ] T119 Test Claude Code process detection (multiple instances, different working directories)
- [ ] T120 Test status update latency Mac → React Native app (target: <500ms)
- [ ] T121 Test window switching latency mobile tap → Mac focus (target: <1s)
- [ ] T122 Test cross-macOS Space window switching
- [ ] T123 Test QR code scanning and React Native app connection
- [ ] T124 Test React Native app on iOS 14+ (real device - iPhone)
- [ ] T125 Test React Native app on Android 10+ (real device)
- [ ] T126 Test multiple concurrent Claude Code instances (3-10)
- [ ] T127 Test multiple concurrent React Native clients (1-5 connections)
- [ ] T128 Test network interruption and auto-reconnection (target: <5s)
- [ ] T129 Test Mac sleep/wake cycle with React Native app connected
- [ ] T130 Test process termination while monitored
- [ ] T131 Test port 3000 already in use error handling
- [ ] T132 Test different WiFi networks error handling
- [ ] T133 Test accessibility permissions missing error message
- [ ] T134 Validate Mac app resource usage (<100MB RAM, <2% CPU idle, <5% CPU active)
- [ ] T135 Validate 24-hour stability test (no crashes, no memory leaks)
- [ ] T136 Fix critical bugs discovered during testing
- [ ] T137 Optimize performance bottlenecks if any criteria fail
- [x] T138 [P] Create smoke test script test-latency.sh to validate <500ms status update SLA
- [x] T139 [P] Create smoke test script test-window-switch.sh to validate <1s window focus SLA
- [x] T140 [P] Create smoke test script test-stability.sh to monitor 24-hour resource usage
- [x] T141 [P] Create smoke test scripts for validation (test-multi-instance.sh, test-cli-detection.sh, test-first-run.sh, test-resilience.sh exist)

---

## Phase 10: Documentation & Deployment Preparation

**Purpose**: Final documentation and Show HN launch preparation

**Dependencies**: Integration testing passing

- [x] T142 [P] Update README.md with installation instructions
- [x] T143 [P] Create Show HN post draft with GIF demo
- [x] T144 [P] Archive Mac .app for distribution using Xcode
  - ✅ Release build created at DerivedData/AgentDeck-.../Build/Products/Release/AgentDeck.app
  - ⚠️ Code signing needed for public distribution
- [ ] T145 Test Mac .app on clean macOS system (or VM)
- [ ] T146 [P] Create Expo build for iOS (EAS Build or TestFlight)
- [ ] T147 [P] Create Expo build for Android (EAS Build or APK)
- [ ] T148 Test React Native builds on real devices
- [x] T149 Create GitHub release with Mac .app and mobile app download links
  - ✅ RELEASE_NOTES.md created with comprehensive v0.1.0 release notes
  - ✅ LICENSE file created (MIT)
- [x] T150 Prepare feedback collection mechanism (GitHub Issues)
  - ✅ GitHub Issues referenced in RELEASE_NOTES.md and README.md
  - ✅ TEST_CHECKLIST.md created for QA validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Monorepo Setup (Phase 0)**: No dependencies - MUST complete first
- **Setup (Phase 1)**: Depends on Phase 0 completion
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion - No dependencies on other stories
- **User Story 2 (Phase 4)**: Depends on Foundational + US1 (requires WebSocketServer) - Can integrate with US1
- **User Story 3 (Phase 5)**: Depends on Foundational + US1 (requires WebSocketServer)
- **React Native Polish (Phase 6)**: Depends on US1 + US3 (React Native app exists)
- **User Story 4 (Phase 7)**: Depends on Foundational + US1 (enhances monitoring)
- **User Story 5 (Phase 8)**: Depends on Foundational + US1 + US2 (requires full app structure)
- **Integration Testing (Phase 9)**: Depends on all desired user stories being complete
- **Documentation (Phase 10)**: Depends on Integration Testing passing

### User Story Dependencies

**Independent Stories** (can develop in parallel after Foundational):
- User Story 1: No dependencies (core monitoring)

**Dependent Stories** (require User Story 1):
- User Story 2: Requires US1 (WebSocketServer, AgentInstance model)
- User Story 3: Requires US1 (WebSocketServer)
- User Story 4: Requires US1 (OutputParser enhances monitoring)
- User Story 5: Requires US1 + US2 (full app infrastructure)

### Within Each User Story

**User Story 1** (Monitor from Mobile):
1. Foundational models complete (T014-T017)
2. ProcessMonitor (T024-T029) - can run parallel with WebSocketServer
3. WebSocketServer (T030-T034) - can run parallel with ProcessMonitor
4. MenuBarView (T035-T036) - can run parallel with React Native app
5. React Native app (T037-T064) - depends on WebSocketServer being ready and shared-types package

**User Story 2** (Window Switching):
1. WindowManager (T065-T069) - can run parallel with WebSocket handlers
2. WebSocket focus handlers (T070-T073) - depends on WindowManager
3. React Native tap handlers (T074-T076) - depends on WebSocket handlers

**User Story 3** (QR Code Setup):
1. QR code generation (T077-T084) - can run in parallel
2. QR code scanner (T085-T088) - depends on React Native app setup

**User Story 4** (Parsed Output):
1. OutputParser (T094-T097) - can run in parallel
2. Integration with AgentInstance (T098-T100) - depends on OutputParser
3. React Native display (T101-T103) - depends on WebSocket integration

**User Story 5** (Zero Config):
1. First-launch logic (T104-T110) - depends on ConfigManager
2. SettingsView (T111-T117) - can develop in parallel with first-launch

### Parallel Opportunities

**Within Monorepo Setup Phase** (some can run in parallel):
- T000: pnpm workspace config (can run parallel with T001)
- T001: Reorganize directories
- T002-T003: Create shared-types (sequential)
- T005: Update .gitignore (can run parallel with T002-T004)

**Within Setup Phase** (all can run in parallel):
- T010: Add Yams dependency
- T011: Create folder structure
- T012: Create Assets.xcassets

**Within Foundational Phase** (all models can run in parallel):
- T014-T017: All 4 model files (AgentInstance, AgentStatus, StatusUpdate, Configuration)

**Within User Story 1**:
- T024-T025: ProcessMonitor (developer A)
- T030-T031: WebSocketServer (developer B)
- T035-T036: MenuBarView (developer C)
- T037-T042: React Native UI (developer D)
- T043-T049: Basic parsing (developer E)

**Within React Native Polish Phase** (all can run in parallel):
- T089: Keep awake toggle
- T090: App icon/splash
- T091: Pull-to-refresh
- T092: Connection status header

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 + 3 Only)

1. Complete Phase 0: Monorepo Setup (T000-T006) - **CRITICAL: ~1.5 days**
2. Complete Phase 1: Setup (T007-T013)
3. Complete Phase 2: Foundational (T014-T023) - CRITICAL blocking phase
4. Complete Phase 3: User Story 1 (T024-T064)
5. Complete Phase 4: User Story 2 (T065-T076)
6. Complete Phase 5: User Story 3 (T077-T088)
7. Complete Phase 6: React Native Polish (T089-T093)
8. **STOP and VALIDATE**: Test P1 stories independently (Day 13-14)
9. If passing: Proceed to Phase 9-10 (integration testing, deploy)
10. If failing: Fix critical issues, re-test

**Timeline**: Week 1 (Phases 0-3), Week 2 (Phases 4-6), Week 3 (Phases 9-10)

### Incremental Delivery

**Week 1 Milestone** (End of Day 7):
- Monorepo + Foundation + User Story 1 complete
- Can monitor Claude Code from Mac menubar
- Can see status updates on React Native app (if deployed)
- Demo: Mac app detecting agents, mobile showing real-time updates

**Week 2 Milestone** (End of Day 14):
- User Stories 2 + 3 + React Native polish complete
- Full MVP ready: monitoring + window switching + QR setup
- React Native app installable on iOS/Android
- Ready for Show HN launch

### Full Feature Set (Optional Post-MVP)

After MVP validation (Week 3+):
1. Add User Story 4 (parsed output) if users request context
2. Add User Story 5 (zero config) if installation friction reported
3. Iterate based on Show HN feedback

---

## Parallel Team Strategy

With multiple developers (or agents):

**Week 1: After Monorepo + Foundational Complete**
- Developer A: ProcessMonitor (T024-T029)
- Developer B: WebSocketServer (T030-T034)
- Developer C: MenuBarView (T035-T036)
- Developer D: React Native app setup + AgentListScreen (T037-T042)
- Developer E: Basic parsing (T043-T049)

**Week 2: After US1 Complete**
- Developer A: WindowManager + AppleScript (T065-T069)
- Developer B: WebSocket focus handlers (T070-T073)
- Developer C: React Native tap handlers (T074-T076)
- Developer D: QR code generation (T077-T084)
- Developer E: QR scanner + navigation (T085-T088)

**Week 2 End: Polish & Integration**
- Developers A-E: React Native polish (T089-T093)
- All developers: Integration testing (T118-T141)
- Developer A: Documentation (T142-T143)
- Developer B: Deployment (T144-T150)

---

## Notes

- **[P]** tasks = different files, no dependencies (safe for parallel execution)
- **[Story]** label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Manual testing only (per constitution: automated tests in Phase 3+)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- **Phase 0 is CRITICAL**: Monorepo setup must complete before ANY other work
- **Shared types package** enables type safety between Mac app (Swift) and mobile app (TypeScript via WebSocket)
- **React Native over PWA**: Native mobile experience, better performance, offline capability, app store distribution

---

## Phase 11: Custom Actions Mobile UI (Priority: P3)

**Purpose**: Stream deck style custom action buttons in React Native mobile app

**Dependencies**: User Story 1 complete, Custom Actions backend (Mac app) complete

**Note**: This is a P3 feature - NOT blocking MVP. Can be implemented post-launch.

- [x] T160 [P] [US6] Create ActionsScreen in apps/mobile/src/screens/ActionsScreen.tsx
  - 4-column grid layout for action buttons
  - Import CustomAction type from @agent-deck/shared-types
  - Receive actions from WebSocket initial_state message
  - Dependencies: "useWebSocket hook complete"
  - Estimate: 3 hours
  - ✅ Completed: Nov 25, 2025 (158 lines, FlatList with numColumns=4, empty state, connection status)

- [x] T161 [P] [US6] Create ActionButton component in apps/mobile/src/components/ActionButton.tsx
  - Square button with icon (emoji) and label
  - Minimum 44x44px touch target
  - Visual feedback on press (scale animation)
  - Loading state during execution
  - Success/error state after completion
  - Dependencies: "Theme complete"
  - Estimate: 3 hours
  - ✅ Completed: Nov 25, 2025 (166 lines, scale animation, 4 states: idle/loading/success/error)

- [ ] T162 [US6] Implement expandable panel with drag handle in ActionsScreen
  - Draggable panel between agent list and action grid
  - Smooth expand/collapse animation (300ms)
  - Support 0-20 visible buttons
  - Dependencies: "Create ActionsScreen"
  - Estimate: 4 hours
  - ⚠️ Deferred: More complex feature, can add later

- [x] T163 [US6] Wire action button tap to WebSocket execute_action message
  - Send execute_action message with actionId on tap
  - Handle action_result message response
  - Update button state based on result
  - Dependencies: "Create ActionButton component", "useWebSocket hook"
  - Estimate: 2 hours
  - ✅ Completed: Nov 25, 2025 (Uses executeAction from useWebSocket hook)

- [x] T164 [US6] Show loading/success/error states on action buttons
  - Loading spinner while action executes
  - Green checkmark on success (2s then reset)
  - Red X on error with toast message
  - Dependencies: "Wire action button tap"
  - Estimate: 2 hours
  - ✅ Completed: Nov 25, 2025 (Loading spinner, green ✓ success, red ✗ error, auto-reset)

- [ ] T165 [US6] Persist panel height to AsyncStorage
  - Save panel expanded/collapsed state
  - Restore state on app reload
  - Debounce saves during drag interaction
  - Dependencies: "Implement expandable panel"
  - Estimate: 1 hour

---

## Task Count Summary

- **Monorepo Setup**: 7 tasks (T000-T006) - **NEW**
- **Setup**: 7 tasks (T007-T013)
- **Foundational**: 10 tasks (T014-T023)
- **User Story 1**: 51 tasks (T024-T064, T050-T064) - **includes basic + rich data parsing + React Native UI**
- **User Story 2**: 12 tasks (T065-T076) - **includes React Native tap interaction**
- **User Story 3**: 12 tasks (T077-T088) - **includes React Native QR scanner**
- **React Native Polish**: 5 tasks (T089-T093) - **NEW**
- **User Story 4**: 10 tasks (T094-T103) - **advanced parsing + React Native display**
- **User Story 5**: 14 tasks (T104-T117)
- **Integration Testing**: 24 tasks (T118-T141) - **includes smoke tests**
- **Documentation**: 9 tasks (T142-T150) - **includes React Native builds**
- **Custom Actions Mobile UI**: 6 tasks (T160-T165) - **NEW P3 feature**

**Total**: 167 tasks

**MVP Core** (P1 only): 7 + 7 + 10 + 51 + 12 + 12 + 5 + 24 + 9 = **137 tasks**
**Post-MVP** (P2): 10 + 14 = **24 tasks**

---

## Completion Status (November 25, 2025)

### ✅ Fully Completed Phases
- **Phase 0**: Monorepo Setup (T000-T006) - 7/7 tasks
- **Phase 1**: Setup (T007-T013) - 7/7 tasks
- **Phase 2**: Foundational (T014-T023) - 10/10 tasks
- **Phase 3**: User Story 1 (T024-T064) - 41/41 tasks (includes rich data)
- **Phase 4**: User Story 2 (T065-T076) - 12/12 tasks
- **Phase 5**: User Story 3 (T077-T088) - 12/12 tasks
- **Phase 6**: React Native Polish (T089-T093) - 5/5 tasks
- **Phase 7**: User Story 4 (T094-T103) - 10/10 tasks
- **Phase 8**: User Story 5 (T104-T117) - 14/14 tasks
- **Phase 11**: Custom Actions UI (T160-T165) - 4/6 tasks (T162, T165 deferred)

### 🟡 Partially Complete (Requires External Setup)
- **Phase 9**: Integration Testing (T118-T141)
  - ✅ Smoke test scripts created (T138-T141)
  - ⏳ Manual tests need execution (T118-T137) - TEST_CHECKLIST.md created
- **Phase 10**: Documentation & Deployment (T142-T150)
  - ✅ README, Show HN draft, Mac Release build, Release notes, LICENSE (T142-T144, T149-T150)
  - ⏳ Clean macOS test (T145) - requires VM or clean system
  - ⏳ Expo iOS/Android builds (T146-T148) - requires EAS setup

### 📊 Summary
- **Development tasks completed**: 122/132 (92%)
- **Manual testing/deployment tasks pending**: 10 tasks (require external setup)
- **Deferred P3 features**: 2 tasks (T162, T165 - expandable panel)

**Critical Updates**:
- **Phase 0 added**: Monorepo setup with pnpm, shared-types package, React Native initialization (~1.5 days)
- **PWA → React Native**: All mobile tasks converted to React Native with Expo
- **Shared types**: TypeScript interfaces shared between platforms via workspace package
- **Path updates**: Agent-Deck/ → apps/macos/, new apps/mobile/ directory
- **React Native specific tasks**: QR scanner, keep awake, pull-to-refresh, AsyncStorage
- **Deployment tasks**: Added Expo builds for iOS/Android (T146-T148)
- Rich data enhancement (T050-T064) completed as part of User Story 1 (P1 MVP)
- Basic parsing (current task) moved to User Story 1 (P1 MVP)
- Advanced parsing (status line, multi-line) remains User Story 4 (P2)
- Polling interval updated to 500ms (from 1-2s) to meet <500ms latency SLA
- Smoke test scripts added for latency/stability validation
