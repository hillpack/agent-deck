# Agent Deck

**Stream Deck for AI agents** - Monitor Claude Code from your phone with a native mobile app, switch windows with one tap, all from your pocket.

![Demo](docs/demo.gif)
*Coming soon: Demo GIF showing QR code scan → mobile connect → window switching*

---

## 🎯 What is Agent Deck?

**The Problem:**
You're running agentic coding tools like Claude Code, but you're stuck at your desk constantly checking: Has my agent finished? Did it hit an error? What's it working on now?

**The Solution:**
Agent Deck is a Mac menubar app that monitors your agents and streams real-time status to your phone. One tap switches focus to any agent window. Think Stream Deck, but for AI coding agents.

---

## ✨ Features

### 🔍 Real-Time Monitoring
- See what your agents are doing (current task, todos, git branch, model)
- Track agent status (idle, working, done, error)
- Monitor subagent activity
- Updates appear on mobile in < 500ms

### 📱 Mobile Control
- **Native React Native App (Expo)** - iOS 15+ and Android 8+ native apps
- **One-tap window switching** - Tap agent card → Mac switches to that window instantly
- **Touch-optimized interface** - Dark mode, expandable sections
- **Native features** - Keep screen awake, QR scanner, push notifications (future)

### 🔒 Privacy-First
- **Fully local** - Everything stays on your WiFi network
- **Zero cloud dependencies** - No subscription, no data sent anywhere
- **Open source** - Audit the code, see exactly what it does

### ⚡ Zero-Config Setup
- Launch Mac app
- Scan QR code with your phone (via Expo Go or native app)
- Start monitoring!
- Done! (60 seconds total)

---

## 📦 Installation

### Requirements
- **macOS 12+** (Monterey or later)
- **WiFi network** (Mac and phone on same network)
- **Claude Code** installed and running
- **For development:** Node.js 18+, pnpm 8+

### Step 1: Download Agent Deck

**Option A: GitHub Release (Recommended)**
1. Go to [Releases](https://github.com/tonyofthehills/agent-deck/releases)
2. Download latest `Agent-Deck-v0.1.0.app.zip`
3. Unzip the file

**Option B: Build from Source**
```bash
git clone https://github.com/tonyofthehills/agent-deck.git
cd agent-deck

# Install dependencies (monorepo)
pnpm install

# Open macOS app in Xcode
cd apps/macos
open Agent-Deck.xcodeproj

# Product → Build (Cmd+B)
# Product → Run (Cmd+R)
```

### Step 2: Install on Mac

```bash
# Move to Applications folder
unzip Agent-Deck-v0.1.0.app.zip
mv Agent-Deck.app /Applications/

# Launch Agent Deck
open /Applications/Agent-Deck.app
```

**First launch:**
- Right-click → Open (to bypass Gatekeeper warning)
- Click "Open" in the dialog

### Step 3: Grant Permissions

**Accessibility Permissions** (required for window switching):
1. System Settings → Privacy & Security → Accessibility
2. Click the lock icon to make changes
3. Click "+" and add Agent-Deck.app
4. Ensure checkbox is enabled

**Why needed:** Agent Deck uses AppleScript to switch windows, which requires accessibility access.

### Step 4: Connect Mobile Device

**Development (via Expo Go):**
1. Install Expo Go app on your phone (App Store/Play Store)
2. Click Agent Deck menubar icon → "Show QR Code"
3. Open Expo Go app → Scan QR code
4. Agent Deck mobile app loads in Expo Go
5. Start monitoring!

**Production (future - Phase 3+):**
- Download Agent Deck mobile app from App Store (iOS)
- Download Agent Deck mobile app from Google Play (Android)

### Step 5: Start Using

1. **Launch Claude Code** on your Mac (run your coding tasks)
2. **Open Agent Deck mobile app** (via Expo Go or native app)
3. **Monitor agents** from anywhere in your house
4. **Tap agent cards** to instantly switch windows on your Mac

---

## 🚀 Quick Start

### First-Time Setup (60 seconds)

```bash
# 1. Launch Agent-Deck.app (grant permissions)
open /Applications/Agent-Deck.app

# 2. Click menubar icon → Scan QR code with phone (Expo Go app)

# 3. Mobile app loads in Expo Go

# 4. Done! Start monitoring.
```

### Daily Workflow

1. **Mac:** Launch Claude Code, start your coding tasks
2. **Phone:** Open Agent Deck mobile app (Expo Go or native app)
3. **Monitor:** See agent status, current tasks, todos
4. **Control:** Tap agent card to switch Mac windows instantly

---

## 📖 Usage

### Menubar Controls

**Click Agent Deck icon** (top right) to see:
- **Show QR Code** - Display QR code for mobile pairing
- **Settings** - Configuration options (coming in Phase 2)
- **Quit** - Exit Agent Deck

### Mobile Interface

**Agent Cards:**
- **Status indicator** - Color-coded (green = working, gray = idle, etc.)
- **Agent name** - Claude Code instance
- **Current task** - What the agent is working on
- **Tap to focus** - Switch to this agent's window on Mac

**Expandable Sections** (tap to reveal):
- **📋 Todos** - Agent's todo list with completion status
- **🎯 Model** - AI model being used (e.g., claude-sonnet-4-5)
- **🌿 Branch** - Git branch agent is working in
- **🤖 Subagents** - Active subagent count

### Keyboard Shortcuts

- **⌘ Q** - Quit Agent Deck
- **⌘ ,** - Open Settings (when implemented)

---

## 🐛 Troubleshooting

### Agent Deck won't launch

**Problem:** "Agent-Deck.app can't be opened because Apple cannot check it for malicious software"

**Solution:**
1. Right-click Agent-Deck.app → Open
2. Click "Open" in the dialog
3. Grant permissions when prompted

**Why:** Agent Deck is not notarized yet (coming in Phase 3). This is safe to bypass.

---

### Window switching doesn't work

**Problem:** Tapping agent card on mobile does nothing

**Solutions:**
1. **Check accessibility permissions:**
   - System Settings → Privacy & Security → Accessibility
   - Ensure Agent-Deck.app is enabled
2. **Restart Agent Deck:**
   - Click menubar icon → Quit
   - Relaunch from Applications folder
3. **Check Claude Code is running:**
   - Agent Deck can only switch to running apps
   - Launch Claude Code first

---

### Mobile can't connect

**Problem:** Expo Go app shows "Connecting..." or "Connection lost"

**Solutions:**
1. **Check WiFi network:**
   - Mac and phone must be on same WiFi
   - Disable cellular data on phone (force WiFi)
2. **Check firewall:**
   - System Settings → Network → Firewall
   - Ensure Agent Deck is allowed (or disable firewall temporarily)
3. **Restart WebSocket server:**
   - Quit and relaunch Agent Deck
4. **Try different port:**
   - Default is 3000, but may conflict
   - Edit config (Phase 2 feature)

---

### Agent not detected

**Problem:** Mobile shows "No agents detected"

**Solutions:**
1. **Check Claude Code is running:**
   - Launch Claude Code in Terminal
   - Verify it's actively working on a task
2. **Check transcript file location:**
   - Agent Deck watches `~/.claude/transcripts/`
   - If Claude Code changed locations, monitoring may fail
   - Report as bug on GitHub
3. **Check logs:**
   - Open Console.app
   - Filter by: `subsystem == "com.agentdeck.app"`
   - Look for errors related to FSEvents or transcript parsing

---

### Expo Go app not working

**Problem:** QR code scan fails or app doesn't load

**Solutions:**
1. **Update Expo Go app:**
   - Ensure you have the latest version from App Store/Play Store
2. **Check Expo CLI version:**
   - Development: Ensure Expo SDK version matches
   - Run `pnpm mobile` from monorepo root
3. **Network issues:**
   - Ensure Mac and phone are on same WiFi
   - Check firewall isn't blocking Metro bundler (port 8081)
4. **Restart Metro bundler:**
   - Ctrl+C in terminal running `pnpm mobile`
   - Run `pnpm mobile` again
   - Scan QR code again

---

### General Troubleshooting

**Enable debug logging:**
```bash
# In Terminal:
log stream --predicate 'subsystem == "com.agentdeck.app"' --level debug

# Then use Agent Deck and watch for errors
```

**Reset Agent Deck:**
```bash
# Quit Agent Deck
# Delete preferences:
rm -rf ~/Library/Preferences/com.agentdeck.Agent-Deck.plist
# Relaunch Agent Deck
```

**Still having issues?**
[Report a bug on GitHub](https://github.com/tonyofthehills/agent-deck/issues/new?template=bug_report.md)

---

## ⚠️ Known Limitations

**MVP Release - These are intentional tradeoffs to ship fast:**

1. **macOS only** - Mac app required (cannot run on Windows/Linux)
2. **Claude Code only** - Cursor, Windsurf, Aider support coming in Phase 2
3. **Local network only** - Mac and phone must be on same WiFi
4. **No authentication** - Assumes trusted local network (add auth in Phase 3)
5. **Monitoring only** - Cannot approve/reject agent actions yet (Phase 5)
6. **Development via Expo Go only** - App Store/Play Store distribution in Phase 3+

**Roadmap:** See [ROADMAP.md](ROADMAP.md) for planned features

---

## 🛣️ Roadmap

### Phase 1 (MVP) - ✅ Development Complete (92%)
- Real-time monitoring with rich data parsing (model, branch, todos, subagents)
- Window switching from mobile (<1s latency)
- React Native mobile app (~2,160 lines): AgentListScreen, QRScannerScreen, SettingsScreen, ActionsScreen
- QR code pairing with manual URL fallback
- Custom Actions UI (stream deck style buttons)
- Mac release build ready
- **Remaining**: Manual testing (TEST_CHECKLIST.md), Expo builds (EAS setup)

### Phase 2 (Next 2-4 weeks)
- Support for Cursor and Windsurf agents
- Multiple agent instance tracking
- Custom actions (run bash scripts, open apps)
- Configuration UI (settings window)

### Phase 3 (Month 2-3)
- App Store and Play Store distribution
- Enhanced parsing (approval prompts, file diffs)
- Authentication layer (secure non-local access)
- Code signing and notarization

### Future Ideas (Phase 4+)
- Mobile approval/rejection of agent actions
- Agent interaction (pause, resume, send commands)
- Integrations (Slack notifications, webhooks)
- Windows support (if demand exists)

**Full Roadmap:** [ROADMAP.md](ROADMAP.md)

---

## 🤝 Contributing

**Contributions welcome!** Agent Deck is open source.

### Ways to Contribute

1. **Report bugs** - [Bug report template](https://github.com/tonyofthehills/agent-deck/issues/new?template=bug_report.md)
2. **Request features** - [Feature request template](https://github.com/tonyofthehills/agent-deck/issues/new?template=feature_request.md)
3. **Submit PRs** - See [CLAUDE.md](CLAUDE.md) for developer guide
4. **Share feedback** - What works? What doesn't? What's missing?

### Development Setup

**Requirements:**
- Xcode 15+ (for Swift 5.7+)
- macOS 12+ (Monterey or later)
- Node.js 18+
- pnpm 8+
- Claude Code (for testing)

**Quick Start:**
```bash
git clone https://github.com/tonyofthehills/agent-deck.git
cd agent-deck

# Install dependencies (monorepo)
pnpm install

# Start mobile app (Expo)
pnpm mobile

# Start macOS app (Xcode)
cd apps/macos && open Agent-Deck.xcodeproj
# Then Command+R in Xcode
```

**Developer Documentation:**
- [CLAUDE.md](CLAUDE.md) - Comprehensive developer guide
- [specs/001-mvp/contracts/websocket-protocol.md](specs/001-mvp/contracts/websocket-protocol.md) - WebSocket protocol
- [LESSONS_LEARNED.md](LESSONS_LEARNED.md) - Implementation insights

---

## 🙏 Acknowledgments

**Built with:**
- [Swift](https://swift.org/) 5.7+ / [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [React Native](https://reactnative.dev/) 0.73+
- [Expo](https://expo.dev/) SDK 50+
- [TypeScript](https://www.typescriptlang.org/) 5.0+
- [pnpm](https://pnpm.io/) 8+
- [FSEvents](https://developer.apple.com/documentation/coreservices/file_system_events) (file system monitoring)
- [Combine](https://developer.apple.com/documentation/combine) (reactive state management)
- [Network.framework](https://developer.apple.com/documentation/network) (WebSocket server)
- [expo-keep-awake](https://docs.expo.dev/versions/latest/sdk/keep-awake/) (prevent screen sleep)
- [expo-camera](https://docs.expo.dev/versions/latest/sdk/camera/) (QR code scanning)

**Inspired by:**
- [Elgato Stream Deck](https://www.elgato.com/stream-deck) (UX paradigm)
- [Touch Portal](https://www.touch-portal.com/) (remote control concept)
- Agentic coding tools (Claude Code, Cursor, Windsurf)

**Special Thanks:**
- Anthropic (Claude Code)
- SpecKit project (spec-driven development workflow)

---

## 📜 License

**MIT License** - See [LICENSE](LICENSE) file

**Open Source, Free Forever**

---

## 📊 Project Stats

![GitHub Stars](https://img.shields.io/github/stars/tonyofthehills/agent-deck?style=social)
![GitHub Forks](https://img.shields.io/github/forks/tonyofthehills/agent-deck?style=social)
![GitHub Issues](https://img.shields.io/github/issues/tonyofthehills/agent-deck)
![GitHub License](https://img.shields.io/github/license/tonyofthehills/agent-deck)
![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-blue)
![React Native](https://img.shields.io/badge/React_Native-0.73+-61dafb)
![Expo](https://img.shields.io/badge/Expo-SDK_50+-000020)
![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-3178c6)

---

## 📞 Contact & Support

**GitHub Issues:** [Report bugs or request features](https://github.com/tonyofthehills/agent-deck/issues)
**GitHub Discussions:** [Community Q&A and ideas](https://github.com/tonyofthehills/agent-deck/discussions)
**Built by:** [@tonyofthehills](https://github.com/tonyofthehills)
**Website:** Coming soon (agent-deck.dev)

---

## 📚 Additional Resources

- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **[ROADMAP.md](ROADMAP.md)** - Planned features
- **[CLAUDE.md](CLAUDE.md)** - Developer guide
- **[agent-deck-spec-final.md](agent-deck-spec-final.md)** - Full product specification

---

**Built with ❤️ by developers, for developers.**

*Monitor your agents. Stay productive. Work from anywhere.*
