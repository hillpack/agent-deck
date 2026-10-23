# Implementation Plan: Agent Deck MVP (Phases 1-2)

**Branch**: `001-mvp` | **Date**: 2025-01-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-mvp/spec.md`

> **Architecture Note (Nov 2025):** Changed from menubar app to standard dock app due to menubar icon visibility issues on macOS. The app now displays in a standard window and lives in the Dock. Core functionality unchanged.

## Summary

Agent Deck is a native macOS dock application with React Native mobile interface for monitoring AI coding agents (Claude Code, Cursor, Windsurf) with real-time status updates, remote window switching, and custom action execution. The Mac app runs as a standard window application, detects running agent processes, parses rich output (current task, model, git branch, todos, subagents), and broadcasts real-time updates via WebSocket to mobile React Native app. Users can tap agent cards to switch focus, scan QR codes for instant setup, and execute custom actions (AppleScript, Bash, URLs) via stream deck style buttons. MVP focuses on Claude Code monitoring only with zero-config installation, <500ms status latency, and <1s window switching.

**Primary Requirement**: Enable developers to monitor and control AI coding agents from mobile device while away from desk.

**Technical Approach**: Native Swift dock app with embedded WebSocket/HTTP server, React Native mobile app with TypeScript and shared type definitions via monorepo, FSEvents for real-time transcript monitoring, AppleScript for window management, YAML for configuration.

## Technical Context

**Monorepo Structure**: pnpm workspaces with shared TypeScript types
**Language/Version**:
- Swift 5.7+ (Swift 6 compatible targeting macOS 12+) for Mac app
- TypeScript 5.0+ for shared types
- React Native 0.73+ (Expo SDK 50+) for mobile app
- Node.js 18.0+ for development

**Primary Dependencies**:
- **Mac App (Swift)**: Combine, Network.framework, NSWorkspace, NSAppleScript, FSEvents
- **Mobile App (React Native)**: Expo SDK 50+, expo-keep-awake, expo-barcode-scanner, WebSocket API
- **Shared**: @agent-deck/shared-types (TypeScript interfaces via pnpm workspace)
- **Build Tools**: pnpm 8.0+, Xcode 14.0+, Expo CLI

**Storage**:
- Local files: ~/.agent-deck/config.yaml (YAML configuration)
- UserDefaults: Mac app preferences (port, auto-start)
- AsyncStorage: React Native app panel state, display settings
- No database required

**Testing**: Manual testing only in Phase 1-2 (per constitution), XCTest + Jest for Phase 3+

**Target Platform**:
- Mac: macOS 12+ (Monterey, Ventura, Sonoma)
- Mobile: iOS 15+, Android 8+ (API 26+)
- Network: Same WiFi/local network only

**Project Type**: Hybrid (native Mac app + React Native mobile app in monorepo)

**Performance Goals**:
- <500ms status update latency (Mac → mobile WebSocket)
- <1s window switching latency (mobile tap → Mac focus)
- <2s Mac app launch time
- <100MB RAM usage (monitoring 3 agents)
- <2% CPU idle, <5% CPU active

**Constraints**:
- No cloud dependencies (local network only)
- No authentication in Phase 1-2
- Accessibility permissions required (window switching)
- Single .app bundle (no Node.js runtime for Mac app)
- React Native app must work offline (cached data)
- 0-20 custom action buttons max (4-column grid)

**Scale/Scope**:
- 1-10 concurrent Claude Code instances supported
- 1-5 concurrent mobile React Native clients
- 24+ hour stability without crashes
- 10+ early testers for MVP validation

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Speed to Market ✅ PASS

**2.5-week MVP over perfection**

- ✅ Scope limited to Phase 0-2 (monorepo setup + monitoring + window switching + QR setup + basic custom actions)
- ✅ User Story 4 (advanced parsing) deferred to P2 (already implemented basic + rich parsing)
- ✅ User Story 6 (custom actions) included but limited to 20 buttons, 4 action types
- ✅ No automated tests in MVP (manual testing only)
- ✅ Working features prioritized over UI perfection
- ✅ Custom actions use simple YAML config (no UI builder)
- ✅ React Native via Expo (zero-config, fast iteration)

**Justification for User Story 6 inclusion**: Custom actions significantly increase utility without blocking MVP (P3 priority). Implementation is straightforward (AppleScript/Bash execution already researched), and 4-column grid with drag panel fits within 2.5-week timeline. Can be shipped with basic actions and iterated post-launch.

### Principle II: Mac-First Architecture ✅ PASS

**Native Swift menubar app is the core product**

- ✅ Mac app: Native Swift/SwiftUI
- ✅ Menubar integration: NSStatusBar, menubar-only (LSUIElement)
- ✅ System integration: AppleScript (window switching), NSWorkspace (process monitoring), FSEvents (file watching)
- ✅ Single .app bundle: All code embedded, no external runtime dependencies
- ✅ No Electron, no web wrappers
- ✅ HTTP/WebSocket servers embedded in Swift (Network.framework or Vapor)

### Principle III: Mobile Validation Strategy ✅ PASS

**React Native first, native refinement later**

- ✅ Mobile interface is React Native (Expo SDK 50+)
- ✅ Works on iOS 15+, Android 8+ (API 26+)
- ✅ Universal support via single codebase
- ✅ No native modules initially (pure JavaScript/TypeScript)
- ✅ Expo Go for rapid testing during development
- ✅ Native builds deferred until Phase 7+ (after user validation)

### Principle IV: Local-First ✅ PASS

**No cloud dependencies in Phase 1-6**

- ✅ Local network only (same WiFi)
- ✅ No authentication layer
- ✅ No external APIs (except monitoring Claude Code process)
- ✅ Configuration: Local YAML files (~/.agent-deck/config.yaml)
- ✅ WebSocket server binds to 0.0.0.0:3000 (local network)
- ✅ HTTP server serves initial connection URL

### Principle V: Developer Audience ✅ PASS

**Functionality over polish**

- ✅ Manual testing acceptable (no automated tests in MVP)
- ✅ Configuration via YAML files (text-based, version-controllable)
- ✅ Error messages actionable (accessibility permissions, port conflicts)
- ✅ Technical limitations documented (20 custom actions max, local network only)
- ✅ UI prioritizes functionality over aesthetics (developer dark mode theme)
- ✅ Custom actions require manual YAML editing (no UI builder in MVP)
- ✅ Monorepo structure familiar to developers (pnpm workspaces)

### SpecKit Workflow ✅ PASS

- ✅ `/speckit.constitution` - Completed (constitution.md v2.0.0)
- ✅ `/speckit.specify` - Completed (spec.md with User Story 6)
- 🔄 `/speckit.plan` - In progress (this file)
- ⏳ `/speckit.tasks` - Next step
- ⏳ `/speckit.implement` - After tasks

---

## Project Structure

### Monorepo Layout

```text
/Users/tonyofthehills/dev/apps/app-009-agent-deck/
├── apps/
│   ├── macos/                        # Swift menubar app
│   │   ├── Agent-Deck.xcodeproj
│   │   ├── Agent-Deck/
│   │   │   ├── Agent_DeckApp.swift
│   │   │   ├── AppDelegate.swift
│   │   │   ├── Info.plist
│   │   │   ├── Models/
│   │   │   ├── Services/
│   │   │   ├── Views/
│   │   │   ├── Utilities/
│   │   │   └── Resources/
│   │   └── Package.swift
│   └── mobile/                       # React Native app
│       ├── app.json                  # Expo configuration
│       ├── package.json
│       ├── tsconfig.json
│       ├── App.tsx                   # Main app entry
│       ├── src/
│       │   ├── screens/
│       │   │   ├── HomeScreen.tsx
│       │   │   ├── ActionsScreen.tsx
│       │   │   └── SettingsScreen.tsx
│       │   ├── components/
│       │   │   ├── AgentCard.tsx
│       │   │   ├── ActionButton.tsx
│       │   │   ├── StatusBadge.tsx
│       │   │   └── QRScanner.tsx
│       │   ├── hooks/
│       │   │   ├── useWebSocket.ts
│       │   │   ├── useKeepAwake.ts
│       │   │   └── useConnectionStatus.ts
│       │   ├── services/
│       │   │   └── websocket.ts
│       │   ├── utils/
│       │   │   └── formatting.ts
│       │   └── types/                # Re-export shared types
│       │       └── index.ts
│       └── assets/
│           └── icons/
├── packages/
│   └── shared-types/                 # TypeScript type definitions
│       ├── package.json
│       ├── tsconfig.json
│       ├── src/
│       │   ├── index.ts              # Main export
│       │   ├── AgentInstance.ts
│       │   ├── AgentStatus.ts
│       │   ├── StatusUpdate.ts
│       │   ├── CustomAction.ts
│       │   ├── Configuration.ts
│       │   ├── WebSocketMessages.ts
│       │   └── TodoItem.ts
│       └── dist/                     # Compiled JS (generated)
├── pnpm-workspace.yaml               # pnpm workspace config
├── package.json                      # Root package.json
├── .gitignore                        # Git ignore (Node.js + RN)
├── specs/001-mvp/                    # Feature specs
├── README.md
└── CLAUDE.md
```

### Documentation (this feature)

```text
specs/001-mvp/
├── spec.md                       # Feature specification (User Stories 1-6)
├── plan.md                       # This file (/speckit.plan command output)
├── research.md                   # Phase 0 output (custom actions research completed)
├── data-model.md                 # Phase 1 output (entities and relationships)
├── quickstart.md                 # Phase 1 output (setup guide)
├── contracts/                    # Phase 1 output (WebSocket protocol)
│   └── websocket-protocol.md
└── tasks.md                      # Phase 2 output (/speckit.tasks command - NOT created yet)
```

### Source Code - Mac App (apps/macos/)

```text
apps/macos/Agent-Deck/
├── Agent_DeckApp.swift               # Main app entry (@main)
├── AppDelegate.swift                 # Menubar app lifecycle
├── Info.plist                        # LSUIElement, permissions
├── Models/
│   ├── AgentInstance.swift           # Running agent representation
│   ├── AgentStatus.swift             # Status enum (idle/working/done/error)
│   ├── StatusUpdate.swift            # WebSocket status update model
│   ├── Configuration.swift           # App configuration (YAML)
│   ├── SubagentInfo.swift            # Active subagent model
│   ├── TodoItem.swift                # Todo list item with status
│   └── CustomAction.swift            # Custom action model (P3)
├── Services/
│   ├── ConfigManager.swift           # YAML configuration loader
│   ├── ProcessMonitor.swift          # NSWorkspace process detection
│   ├── TranscriptParser.swift        # JSONL transcript parsing (rich data)
│   ├── TranscriptWatcher.swift       # FSEvents file watching
│   ├── OutputParser.swift            # Basic stdout parsing (legacy)
│   ├── WebSocketServer.swift         # Network.framework WebSocket server
│   ├── HTTPServer.swift              # HTTP server for connection info
│   ├── WindowManager.swift           # AppleScript window switching
│   └── CustomActionManager.swift    # Action execution service (P3)
├── Views/
│   ├── MenuBarView.swift             # Menubar dropdown
│   ├── QRCodeView.swift              # QR code display
│   └── SettingsView.swift            # Settings window (4 tabs)
├── Utilities/
│   ├── QRGenerator.swift             # CoreImage QR code generation
│   └── Logger.swift                  # os.log logging
└── Resources/
    ├── Assets.xcassets               # App icons
    └── default-config.yaml           # Default YAML configuration template
```

### Source Code - Mobile App (apps/mobile/)

```text
apps/mobile/
├── app.json                          # Expo configuration
├── package.json                      # Dependencies (expo, expo-keep-awake, etc.)
├── tsconfig.json                     # TypeScript configuration
├── App.tsx                           # Main app entry point
├── src/
│   ├── screens/
│   │   ├── HomeScreen.tsx            # Agent list view
│   │   ├── ActionsScreen.tsx         # Custom actions grid
│   │   └── SettingsScreen.tsx        # App settings
│   ├── components/
│   │   ├── AgentCard.tsx             # Agent status card
│   │   ├── ActionButton.tsx          # Custom action button
│   │   ├── StatusBadge.tsx           # Status indicator
│   │   ├── QRScanner.tsx             # QR code scanner (expo-barcode-scanner)
│   │   └── ConnectionIndicator.tsx   # WebSocket connection status
│   ├── hooks/
│   │   ├── useWebSocket.ts           # WebSocket connection hook
│   │   ├── useKeepAwake.ts           # Screen awake toggle (expo-keep-awake)
│   │   └── useConnectionStatus.ts    # Connection state management
│   ├── services/
│   │   └── websocket.ts              # WebSocket client implementation
│   ├── utils/
│   │   └── formatting.ts             # Date, time, status formatting
│   └── types/
│       └── index.ts                  # Re-export from @agent-deck/shared-types
└── assets/
    └── icons/
        ├── icon.png
        ├── adaptive-icon.png
        └── splash.png
```

### Source Code - Shared Types (packages/shared-types/)

```text
packages/shared-types/
├── package.json                      # Package metadata
├── tsconfig.json                     # TypeScript config
├── src/
│   ├── index.ts                      # Main export (all types)
│   ├── AgentInstance.ts              # Agent instance interface
│   ├── AgentStatus.ts                # Status enum
│   ├── StatusUpdate.ts               # Status update interface
│   ├── CustomAction.ts               # Custom action interface
│   ├── Configuration.ts              # App configuration interface
│   ├── WebSocketMessages.ts          # WebSocket message types
│   ├── TodoItem.ts                   # Todo item interface
│   └── SubagentInfo.ts               # Subagent info interface
└── dist/                             # Compiled JavaScript (generated by tsc)
```

**Structure Decision**: Monorepo with pnpm workspaces. Mac app remains independent Swift project. React Native app shares TypeScript types via `@agent-deck/shared-types` package. No separate backend repository - server logic is embedded in Swift services.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations detected.** All constitution principles pass.

**Minor justification** (User Story 6 inclusion in MVP):
- **What**: Custom actions (stream deck buttons) included in MVP as P3 feature
- **Why**: Significantly increases utility, leverages existing WebSocket infrastructure, fits 2.5-week timeline
- **Simpler approach rejected**: Deferring to Phase 3+ would reduce MVP value proposition
- **Why rejected approach insufficient**: Early users expect productivity shortcuts, competitive differentiation
- **Compliance**: Still within 2.5-week scope, working features over polish, local-first YAML config

---

## Phase 0: Monorepo Setup & Research

**Duration**: 4 days (Day 1-4)
**Status**: ✅ REQUIRED BEFORE PHASE 1

### Research Topics Identified

From Technical Context unknowns:

1. ✅ **COMPLETED**: Swift AppleScript execution patterns
2. ✅ **COMPLETED**: Swift Bash script execution with Process
3. ✅ **COMPLETED**: Swift URL opening with NSWorkspace
4. ✅ **COMPLETED**: Apple Shortcuts integration approaches (deferred to Phase 5+)
5. ✅ **COMPLETED**: React Native touch interactions for mobile panel expand/collapse
6. ✅ **COMPLETED**: WebSocket protocol for action broadcasting and execution
7. ✅ **COMPLETED**: FSEvents C pointer handling for transcript watching
8. ✅ **COMPLETED**: @Published Combine triggering with struct replacement
9. ⏳ **PENDING**: pnpm workspaces configuration
10. ⏳ **PENDING**: TypeScript type sharing strategy
11. ⏳ **PENDING**: Expo SDK 50+ setup and configuration

### Monorepo Setup Tasks

**Day 1-2: Directory Structure & Package Management**

1. Create monorepo structure
   - Create `apps/`, `packages/` directories
   - Move existing Swift app to `apps/macos/`
   - Create `apps/mobile/` for React Native
   - Create `packages/shared-types/` for TypeScript types

2. Set up pnpm workspace
   - Create `pnpm-workspace.yaml` at root
   - Create root `package.json` with workspace configuration
   - Configure workspace protocol (`workspace:*`) for internal dependencies

3. Initialize Expo project
   - Run `npx create-expo-app@latest apps/mobile --template blank-typescript`
   - Configure `app.json` with app name, slug, version
   - Add required Expo packages (expo-keep-awake, expo-barcode-scanner)

4. Create shared types package
   - Initialize `packages/shared-types/package.json`
   - Configure TypeScript (`tsconfig.json`)
   - Create type definition files (AgentInstance, StatusUpdate, etc.)
   - Set up build script (`tsc` compilation)

**Day 3-4: Configuration & Validation**

5. Update .gitignore
   - Add Node.js patterns (`node_modules/`, `.expo/`, `dist/`)
   - Add React Native patterns (`*.jks`, `*.p8`, `*.p12`, etc.)
   - Keep Swift patterns (`.xcodeproj/xcuserdata/`, `*.swiftpm/`)

6. Configure TypeScript
   - Set up path aliases (`@agent-deck/shared-types`)
   - Configure strict mode
   - Set up compilation targets (ES2020, ESNext modules)

7. Test monorepo setup
   - Run `pnpm install` from root (verify workspace resolution)
   - Build Swift app from `apps/macos/` (verify Xcode still works)
   - Run `pnpm build` in `packages/shared-types/` (verify TypeScript compilation)
   - Run `npx expo start` in `apps/mobile/` (verify Expo launches)

### Research Agents Dispatched

**Agent 1**: Custom Actions Implementation Research ✅ COMPLETED
- Task: Research AppleScript, Bash, URL, Shortcuts execution from Swift
- Task: Research React Native touch interactions and AsyncStorage persistence
- Task: Research WebSocket protocol for action broadcasting
- Output: `/specs/001-mvp/research.md` (see subagent output above)

**Agent 2**: FSEvents and Real-Time Monitoring ✅ COMPLETED (from previous session)
- Task: FSEvents C pointer handling for transcript file watching
- Task: Combine @Published triggering patterns with structs
- Output: `LESSONS_LEARNED.md` (3 Pieces memories created)

### Research Findings Consolidated

**Output**: `research.md` (custom actions research above)

**Key Decisions**:

1. **AppleScript Execution**: Use `NSAppleScript.executeAndReturnError()` with error dictionary
   - Rationale: Structured errors, synchronous execution acceptable for MVP
   - Alternative rejected: NSTask with osascript (unnecessary overhead)

2. **Bash Execution**: Use `Process` with separate stdout/stderr pipes
   - Rationale: Standard Swift API, security via argument arrays
   - Alternative rejected: Shell wrappers (hide security concerns)

3. **URL Opening**: Use `NSWorkspace.shared.open()` with scheme validation
   - Rationale: Respects user defaults, built-in macOS handling
   - Alternative rejected: Direct browser launch (breaks preferences)

4. **Shortcuts**: DEFERRED to Phase 5+ (no stable macOS API)
   - Rationale: URL scheme unreliable, keyboard simulation fragile
   - Alternative: Use AppleScript/Bash for equivalent functionality

5. **React Native Touch Panel**: TouchableOpacity + Animated API
   - Rationale: Universal mobile support, 60fps animations
   - Alternative rejected: Gesture handlers (overkill for MVP, additional dependency)

6. **WebSocket Protocol**: JSON with action list on connect
   - Rationale: Human-readable, easy to debug, universal
   - Alternative rejected: Binary protocol (unnecessary complexity)

7. **Monorepo Architecture**: pnpm workspaces with workspace:* protocol
   - Rationale: Fast, efficient, TypeScript type sharing
   - Alternative rejected: npm/yarn (slower, larger node_modules)

8. **React Native Framework**: Expo SDK 50+ for zero-config
   - Rationale: No native build setup, fast iteration, Expo Go testing
   - Alternative rejected: React Native CLI (requires Xcode/Android Studio setup)

### Success Criteria (Phase 0)

- [ ] pnpm workspace resolution works (`pnpm install` succeeds)
- [ ] Swift app builds from `apps/macos/` directory
- [ ] Expo app launches with `npx expo start` in `apps/mobile/`
- [ ] TypeScript types compile in `packages/shared-types/`
- [ ] Mobile app can import types from `@agent-deck/shared-types`
- [ ] .gitignore correctly excludes Node.js and React Native artifacts

---

## Phase 1: Design & Contracts

### Data Model (`data-model.md`)

**See separate file**: [data-model.md](data-model.md)

**Key Entities**:
- AgentInstance (running AI agent process)
- AgentStatus (idle/working/done/error enum)
- StatusUpdate (real-time WebSocket update)
- Configuration (YAML app settings)
- SubagentInfo (active subagents)
- TodoItem (todo list with status)
- **CustomAction (NEW)**: User-defined commands/scripts

**Relationships**:
- AgentInstance → many SubagentInfo
- AgentInstance → many TodoItem
- Configuration → many CustomAction
- StatusUpdate → one AgentInstance

**State Transitions**:
- AgentStatus: idle → working → done|error → idle
- TodoItem: pending → in_progress → completed
- CustomAction: idle → executing → success|error → idle

**TypeScript Type Sharing**:
- All entities defined in `packages/shared-types/src/`
- Exported as ES modules
- Imported in React Native via `@agent-deck/shared-types`
- Swift uses separate Swift structs (no code sharing across Swift/TS)

### API Contracts (`contracts/websocket-protocol.md`)

**See separate file**: [contracts/websocket-protocol.md](contracts/websocket-protocol.md)

**WebSocket Protocol**:

**Server → Client Messages**:
1. `initial_state` - Agent list + custom actions on connect
2. `update` - Agent status change
3. `instance_added` - New agent detected
4. `instance_removed` - Agent terminated
5. `focus_success` - Window switch succeeded
6. `focus_failure` - Window switch failed
7. **`actions` (NEW)** - Custom action list
8. **`action_result` (NEW)** - Action execution result

**Client → Server Messages**:
1. `focus` - Request window switch
2. **`execute_action` (NEW)** - Execute custom action

**Message Schemas**: See contracts/websocket-protocol.md for full JSON schemas

**TypeScript Types**: All WebSocket message types defined in `packages/shared-types/src/WebSocketMessages.ts`

### Quickstart Guide (`quickstart.md`)

**See separate file**: [quickstart.md](quickstart.md)

**Developer Setup** (10 minutes):
1. Clone repository
2. Install pnpm (`npm install -g pnpm`)
3. Run `pnpm install` from root (installs all workspaces)
4. Open `apps/macos/Agent-Deck.xcodeproj` in Xcode
5. Add Yams Swift Package dependency to Mac app
6. Build and run Mac app (Cmd+R)
7. Grant accessibility permissions
8. Run `cd apps/mobile && npx expo start` (start Metro bundler)
9. Scan QR code with Expo Go app
10. Test connection

**User Installation** (60 seconds):
1. Download Agent-Deck.app
2. Move to /Applications/
3. Launch (right-click → Open to bypass Gatekeeper)
4. Grant accessibility permissions when prompted
5. Download Expo Go from App Store (iOS) or Google Play (Android)
6. Scan QR code from menubar dropdown
7. App opens in Expo Go
8. Done!

**Production Installation** (Phase 6+):
1. Download Agent-Deck.app
2. Move to /Applications/
3. Launch and grant permissions
4. Download Agent Deck from App Store (iOS/Android)
5. Scan QR code or enter connection URL
6. Done!

### Agent Context Update

Running agent context update script...

---

## Phase 2: Implementation Architecture

### Monorepo Architecture

**Package Management**: pnpm workspaces

```yaml
# pnpm-workspace.yaml
packages:
  - 'apps/*'
  - 'packages/*'
```

```json
// Root package.json
{
  "name": "agent-deck-monorepo",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "build:types": "pnpm --filter @agent-deck/shared-types build",
    "mobile:start": "pnpm --filter mobile start",
    "mobile:ios": "pnpm --filter mobile ios",
    "mobile:android": "pnpm --filter mobile android"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
```

**Code Sharing Strategy**:
- TypeScript interfaces shared via `@agent-deck/shared-types` package
- React Native imports types using `workspace:*` protocol
- Swift code remains independent (no cross-language sharing)
- WebSocket protocol defined in TypeScript, manually mirrored in Swift

**Workflow**:
1. Developer modifies types in `packages/shared-types/src/`
2. Run `pnpm build:types` to compile TypeScript
3. React Native automatically picks up changes (workspace link)
4. Swift types manually updated to match (Phase 3+: consider codegen)

### Mac Application Architecture

**Pattern**: MVVM with Combine reactive state management

**Layers**:

1. **App Layer** (`Agent_DeckApp.swift`, `AppDelegate.swift`)
   - LSUIElement policy (menubar-only)
   - Menubar status item creation
   - Service initialization
   - Lifecycle management

2. **Model Layer** (`Models/`)
   - `AgentInstance`: @Published properties for Combine reactivity
   - `Configuration`: Codable for YAML deserialization
   - `CustomAction`: Action type, params, execution state

3. **Service Layer** (`Services/`)
   - `ProcessMonitor`: NSWorkspace + FSEvents + Combine Timer
   - `TranscriptParser`: JSONL parsing (model, branch, todos, subagents)
   - `WebSocketServer`: Network.framework server + connection pool
   - `HTTPServer`: Connection info endpoint
   - `WindowManager`: AppleScript window focus execution
   - **`CustomActionManager` (NEW)**: Action execution orchestration

4. **View Layer** (`Views/`)
   - `MenuBarView`: SwiftUI popover with agent list
   - `QRCodeView`: CoreImage QR generation + display
   - `SettingsView`: 4-tab settings window

5. **Utility Layer** (`Utilities/`)
   - `Logger`: os.log wrapper with categories
   - `QRGenerator`: CoreImage CIFilter wrapper

**Data Flow**:
```
ProcessMonitor (NSWorkspace poll every 2s)
  → FSEvents (transcript file changes)
    → TranscriptParser (parse JSONL)
      → @Published instances array update
        → Combine sink
          → WebSocketServer broadcast
            → React Native clients receive update
```

**Custom Actions Flow**:
```
React Native button tap
  → WebSocket execute_action message
    → CustomActionManager.execute()
      → AppleScript/Bash/URL execution
        → Result (success/error)
          → WebSocket action_result message
            → React Native shows success/error state
```

### React Native Mobile App Architecture

**Pattern**: Functional components with hooks + context

**Tech Stack**:
- React Native 0.73+ (Expo SDK 50+)
- TypeScript 5.0+
- Expo Router for navigation
- AsyncStorage for persistence
- expo-keep-awake for screen management
- expo-barcode-scanner for QR scanning

**Components**:

1. **Screens** (`src/screens/`)
   - `HomeScreen.tsx`: Agent list with status cards
   - `ActionsScreen.tsx`: Custom action grid (4 columns)
   - `SettingsScreen.tsx`: Connection settings, keep awake toggle

2. **Components** (`src/components/`)
   - `AgentCard.tsx`: Agent instance display (status, model, branch, todos)
   - `ActionButton.tsx`: Custom action button (icon, label, feedback)
   - `StatusBadge.tsx`: Color-coded status indicator
   - `QRScanner.tsx`: QR code scanner for setup
   - `ConnectionIndicator.tsx`: WebSocket connection status

3. **Hooks** (`src/hooks/`)
   - `useWebSocket.ts`: WebSocket connection management, auto-reconnect
   - `useKeepAwake.ts`: Screen awake toggle (expo-keep-awake)
   - `useConnectionStatus.ts`: Connection state + latency tracking

4. **Services** (`src/services/`)
   - `websocket.ts`: WebSocket client implementation

5. **Utils** (`src/utils/`)
   - `formatting.ts`: Date, time, status text formatting

**Data Flow**:
```
WebSocket onmessage
  → useWebSocket hook
    → Context update (agents, actions, connection state)
      → Components re-render
        → AgentCard displays new status
        → ActionButton shows execution result
```

**Touch Interaction Flow**:
```
TouchableOpacity onPress
  → executeAction(actionId)
    → WebSocket send execute_action
      → Wait for action_result
        → Show success/error animation
          → Reset after 2s
```

**State Management**:
- WebSocket connection: Context API
- Agent instances: Context API (from WebSocket updates)
- Custom actions: Context API (from WebSocket updates)
- Settings: AsyncStorage + local state
- Keep awake: expo-keep-awake activated state

### Shared Types Package

**Package Structure**:
```typescript
// packages/shared-types/src/index.ts
export * from './AgentInstance';
export * from './AgentStatus';
export * from './StatusUpdate';
export * from './CustomAction';
export * from './Configuration';
export * from './WebSocketMessages';
export * from './TodoItem';
export * from './SubagentInfo';
```

**Build Configuration**:
```json
// packages/shared-types/package.json
{
  "name": "@agent-deck/shared-types",
  "version": "1.0.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "watch": "tsc --watch"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
```

**Usage in React Native**:
```typescript
// apps/mobile/src/types/index.ts
export * from '@agent-deck/shared-types';

// apps/mobile/src/components/AgentCard.tsx
import { AgentInstance, AgentStatus } from '../types';

interface AgentCardProps {
  agent: AgentInstance;
}

export const AgentCard: React.FC<AgentCardProps> = ({ agent }) => {
  // Component implementation
};
```

### WebSocket Protocol Implementation

**Swift Server** (`WebSocketServer.swift`):

```swift
class WebSocketServer {
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    // Phase 3: Custom Actions
    private var customActions: [CustomAction] = []

    func start(port: UInt16) {
        let parameters = NWParameters.tcp
        listener = try? NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
        listener?.newConnectionHandler = handleNewConnection
        listener?.start(queue: .main)
    }

    func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)

        // Send initial state (agents + actions)
        let initialState: [String: Any] = [
            "type": "initial_state",
            "instances": instances.map { $0.toDictionary() },
            "actions": customActions.map { $0.toDictionary() }
        ]
        sendJSON(initialState, to: connection)

        // Start receiving messages
        receive(on: connection)
    }

    func handleClientMessage(_ data: Data, from connection: NWConnection) {
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = message["type"] as? String else {
            return
        }

        switch type {
        case "focus":
            guard let instanceId = message["instanceId"] as? String else { return }
            handleFocusRequest(instanceId, connection: connection)

        case "execute_action":
            guard let actionId = message["action_id"] as? String else { return }
            handleActionExecution(actionId, connection: connection)

        default:
            Logger.error("Unknown message type: \(type)", log: .network)
        }
    }

    func handleActionExecution(_ actionId: String, connection: NWConnection) {
        // Delegate to CustomActionManager
        let result = CustomActionManager.shared.execute(actionId: actionId)

        let message: [String: Any] = [
            "type": "action_result",
            "action_id": actionId,
            "success": result.success,
            "output": result.output ?? "",
            "error": result.error as Any
        ]

        sendJSON(message, to: connection)
    }
}
```

**TypeScript Client** (`apps/mobile/src/hooks/useWebSocket.ts`):

```typescript
import { useEffect, useState, useRef } from 'react';
import { AgentInstance, CustomAction, WebSocketMessage } from '../types';

export const useWebSocket = (url: string) => {
  const [agents, setAgents] = useState<AgentInstance[]>([]);
  const [actions, setActions] = useState<CustomAction[]>([]);
  const [connected, setConnected] = useState(false);
  const ws = useRef<WebSocket | null>(null);

  useEffect(() => {
    const connect = () => {
      ws.current = new WebSocket(url);

      ws.current.onopen = () => {
        console.log('Connected to Agent Deck');
        setConnected(true);
      };

      ws.current.onmessage = (event) => {
        const message: WebSocketMessage = JSON.parse(event.data);

        switch (message.type) {
          case 'initial_state':
            setAgents(message.instances);
            setActions(message.actions);
            break;

          case 'update':
            setAgents(prev =>
              prev.map(a => a.id === message.instance.id ? message.instance : a)
            );
            break;

          case 'actions':
            setActions(message.actions);
            break;

          case 'action_result':
            // Handle action result (show toast, update button state)
            break;

          default:
            console.warn('Unknown message type:', message.type);
        }
      };

      ws.current.onerror = (error) => {
        console.error('WebSocket error:', error);
        setConnected(false);
      };

      ws.current.onclose = () => {
        console.log('Disconnected, reconnecting...');
        setConnected(false);
        setTimeout(connect, 1000);
      };
    };

    connect();

    return () => {
      ws.current?.close();
    };
  }, [url]);

  const executeAction = (actionId: string) => {
    ws.current?.send(JSON.stringify({
      type: 'execute_action',
      action_id: actionId
    }));
  };

  const focusAgent = (instanceId: string) => {
    ws.current?.send(JSON.stringify({
      type: 'focus',
      instanceId: instanceId
    }));
  };

  return {
    agents,
    actions,
    connected,
    executeAction,
    focusAgent
  };
};
```

---

## Implementation Phases Summary

### Phase 0: Monorepo Setup (4 Days) ⏳ REQUIRED FIRST

**Day 1-2: Structure & Packages**
- Create apps/, packages/ directories
- Move Swift app to apps/macos/
- Initialize Expo project at apps/mobile/
- Create packages/shared-types/
- Set up pnpm-workspace.yaml

**Day 3-4: Configuration & Validation**
- Configure TypeScript for shared types
- Update .gitignore for Node.js + React Native
- Test pnpm install
- Verify Swift build from apps/macos/
- Verify Expo launch from apps/mobile/
- Verify TypeScript compilation in shared-types

### Phase 1-2 (MVP - 2 Weeks) ✅ CURRENT SCOPE

**Week 1** (Foundational + User Story 1):
- Setup project structure (COMPLETED in Phase 0)
- Implement models (AgentInstance, Configuration, StatusUpdate, SubagentInfo, TodoItem)
- Implement ProcessMonitor + TranscriptParser (FSEvents + JSONL parsing)
- Implement WebSocketServer + HTTPServer
- Create React Native screens (HomeScreen, ActionsScreen, SettingsScreen)
- Implement useWebSocket hook
- QR code generation + QR scanner component

**Week 2** (User Stories 2, 3, 5, 6):
- WindowManager (AppleScript window switching)
- SettingsView (4 tabs: General, Agents, Mobile, About)
- First-launch detection + default config creation
- **CustomAction model + CustomActionManager service**
- **React Native ActionPanel component (touch interactions)**
- **WebSocket action protocol (execute_action, action_result)**
- **Keep awake toggle (expo-keep-awake)**
- React Native polish (app.json, icons, splash screen)
- Manual testing + bug fixes

### Phase 3+ (Post-MVP)

**Deferred Features**:
- User Story 4 (status line parsing) - basic + rich parsing already complete
- Multi-agent support (Cursor, Windsurf, Aider)
- Advanced custom actions (categories, colors, confirmation prompts)
- Automated testing (XCTest, Jest)
- Code signing + notarization
- Auto-updates
- Native iOS/Android builds (Phase 7+)

---

## Risk Assessment

### High Risk ⚠️

1. **Monorepo Complexity**
   - Risk: pnpm workspace resolution issues, path mapping errors
   - Mitigation: Test early in Phase 0, use standard Expo + pnpm patterns
   - Fallback: Separate repositories if workspace blocked by Day 4

2. **Accessibility Permissions Complexity**
   - Risk: Users may not understand permission prompts
   - Mitigation: Clear error messages with FR-031, documented in README
   - Fallback: Window switching optional feature

3. **React Native Installation Friction**
   - Risk: Users may not want to install Expo Go (Phase 1-2)
   - Mitigation: QR code shows clear instructions, quickstart.md guide
   - Fallback: Standalone builds in Phase 6+ (App Store distribution)

4. **Custom Action Security**
   - Risk: Malicious YAML could execute dangerous commands
   - Mitigation: Only execute from ~/.agent-deck/config.yaml, document security
   - Fallback: Disable custom actions if not configured

### Medium Risk

1. **TypeScript Type Synchronization**
   - Risk: Swift and TypeScript types may drift out of sync
   - Mitigation: Manual review of types, document in contracts/
   - Future: Consider code generation (quicktype, etc.)

2. **Network.framework vs Vapor Decision**
   - Risk: Network.framework may be complex for HTTP + WebSocket
   - Mitigation: Vapor fallback if Network.framework blocked by Day 3
   - Current: Using Network.framework (researched patterns available)

3. **FSEvents C Pointer Handling**
   - Risk: Memory safety issues with C APIs
   - Mitigation: Researched patterns in LESSONS_LEARNED.md, Pieces memories
   - Current: Implemented and stable

4. **Mobile Device Compatibility**
   - Risk: Expo Go version mismatch, SDK compatibility
   - Mitigation: Test on iOS 13+, Android 5.0+, document minimum versions
   - Fallback: Standalone builds if Expo Go issues

### Low Risk

1. **YAML Parsing**
   - Risk: Invalid YAML crashes app
   - Mitigation: Yams library with error handling, default config fallback
   - Current: Well-tested library

2. **QR Code Generation**
   - Risk: CoreImage CIFilter not available
   - Mitigation: Standard macOS API, highly stable
   - Current: Low risk

3. **Expo SDK Updates**
   - Risk: Breaking changes in Expo SDK
   - Mitigation: Pin Expo SDK 50+ in package.json, test before upgrading
   - Current: Expo has stable API

---

## Success Metrics (from spec.md Success Criteria)

**Performance** (measurable):
- SC-001: <500ms status update latency ✅ TARGET
- SC-002: <1s window switching latency ✅ TARGET
- SC-003: <100MB RAM usage ✅ TARGET
- SC-004: <2% CPU idle, <5% active ✅ TARGET
- SC-005: <2s app launch time ✅ TARGET
- SC-019: <2s custom action execution (excluding long scripts) ✅ TARGET

**User Experience** (measurable):
- SC-006: <60s mobile setup (QR scan to app open) ✅ TARGET
- SC-007: <2s agent detection on startup ✅ TARGET
- SC-008: <3s React Native app load time ✅ TARGET
- SC-009: 90% successful first-time setup ✅ TARGET

**Reliability** (measurable):
- SC-010: 3+ concurrent agents without degradation ✅ TARGET
- SC-011: <5s auto-reconnection after network drop ✅ TARGET
- SC-012: 24+ hour stability (no crashes/leaks) ✅ TARGET
- SC-013: 95%+ window switch success rate ✅ TARGET
- SC-020: Custom actions fail gracefully with errors ✅ TARGET
- SC-021: 44×44px minimum touch targets ✅ TARGET

**Platform Compatibility**:
- SC-014: macOS 12-14 support ✅ TARGET
- SC-015: iOS 15+, Android 8+ (API 26+) ✅ TARGET
- SC-016: React Native app works on iOS + Android ✅ TARGET

**Adoption** (qualitative):
- SC-017: 10+ early testers without critical bugs ✅ TARGET
- SC-018: Positive Show HN feedback ✅ TARGET

---

## Next Steps

1. ✅ **Phase 0 Research Complete**: Custom actions patterns researched
2. ⏳ **Phase 0 Setup**: Monorepo structure + pnpm workspaces (Day 1-4)
3. ✅ **Phase 1 In Progress**: Generate data-model.md (next)
4. ✅ **Phase 1 In Progress**: Generate contracts/websocket-protocol.md (next)
5. ✅ **Phase 1 In Progress**: Generate quickstart.md (next)
6. ⏳ **Phase 1 Final**: Update agent context (`.specify/scripts/bash/update-agent-context.sh`)
7. ⏳ **Phase 2**: Run `/speckit.tasks` to generate tasks.md
8. ⏳ **Phase 3**: Run `/speckit.implement` to start coding

---

**Plan Status**: Phase 0 setup required, Phase 1 design in progress
**Next Command**: Complete Phase 0 monorepo setup, then generate data-model.md, contracts/, quickstart.md
**Ready for Tasks**: After Phase 0 + Phase 1 artifacts complete
**Implementation Start**: After `/speckit.tasks` generates tasks.md

---

**Document Version**: 2.0 (Monorepo + React Native)
**Created**: 2025-01-08
**Updated**: 2025-01-08 (Added Phase 0: Monorepo Setup, React Native migration)
**Branch**: 001-mvp
**Spec Version**: 1.1 (includes User Story 6 - Custom Actions)
**Timeline**: 2.5 weeks (4 days setup + 2 weeks implementation)
