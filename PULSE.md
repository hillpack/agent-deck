---
project: "app-009-agent-deck"
name: Agent Deck
category: app
type: macOS + React Native
stack: [Swift, SwiftUI, TypeScript, "React Native", Expo, pnpm]
vision: >
  Stream Deck for AI agents. Monitor Claude Code, Cursor, and other agentic
  coding tools from your phone. Mac native Swift dock app + React Native mobile.
  Development 92% complete, awaiting integration testing and mobile builds.
status: archived
completion: 75
health: fair
personal: false
last_worked: 2026-01-15
last_updated: 2026-10-22T20:00:00
---

## Sub-Projects
- macOS: 87% (dev) - Swift dock app (all services working, UI functional, testing/signing pending)
- Mobile: 95% (dev) - React Native Expo (all screens/components done, device testing/builds pending)

## Where I Left Off

### Archived — Claude (2026-10-22)
- [@claude] Tony archived this project on 2026-10-22: abandoned for now, not deleted.
- [@claude] GitHub repo set to archived (read-only). The last uncommitted MacBook work is on branch `wip/macbook-2026-10-22`. Local copies moved to `~/dev/apps/archive/` on both machines.
- [@claude] To revive: unarchive the repo on GitHub, move the folder back to `~/dev/apps/`, set `status: active`, and point its `PROJECT_DIRS` entry in the pulse aggregator back at `apps/`.


### Development Complete (2026-01-15)
- All MVP features implemented: real-time monitoring, window switching, QR pairing, custom actions
- 122/132 dev tasks done (92%). Remaining: integration tests, mobile builds, code signing
- 44 uncommitted files with refinements to WebSocket protocol, process detection, transcript parsing
- Docs restructured into organized subdirectories

## Next Steps

1. [c:S u:S] Commit the 44 uncommitted files (refinements to services, protocol, docs)
2. [c:M u:M] Execute manual integration tests (20 test procedures, T118-T137)
3. [c:M u:S d:2] Fix bugs discovered during testing
4. [c:S u:M] Set up Expo EAS builds for iOS/Android (T146-T148)
5. [c:S u:M] Configure code signing and notarization for macOS distribution (T144)
6. [c:M u:S] Generate structured ROADMAP.md from template (`shared/templates/ROADMAP-template.md`)

## Recent Work

### 2026-01-15
- Restructured docs into organized subdirectories; added simulator isolation requirements
- Refined WebSocket protocol, process detection, transcript parsing (uncommitted)

### 2025-11-08
- Migrated to monorepo structure with React Native mobile app

## Blockers

None critical. Testing phase requires dedicated time (~8-12 hours manual validation).

## Notes

### 2026-10-22 — Security sweep: NOT patched (project on hold indefinitely)
- **2 criticals still open**, both Expo-CLI build tooling (not shipped to device): `tar` [GHSA-23hp-3jrh-7fpw](https://github.com/advisories/GHSA-23hp-3jrh-7fpw), `shell-quote` [GHSA-w7jw-789q-3m8p](https://github.com/advisories/GHSA-w7jw-789q-3m8p). Dependabot alerts + security updates now ON for this repo.
- **Why not patched — repo is uninstallable from GitHub:** `.gitignore:25` is `Packages/` (meant for the Swift/SPM dir). With `core.ignorecase=true` on macOS it also matches the JS `packages/` dir, so `packages/shared-types` has **never been committed**. `apps/mobile` depends on `@agent-deck/shared-types@workspace:*`, so a clean checkout of `001-mvp` fails `pnpm install` with `ERR_PNPM_WORKSPACE_PKG_NOT_FOUND`. No valid lockfile could be produced.
- Reminder: on re-engage, (1) anchor the ignore to the Swift path (e.g. `/Packages/` or the specific SPM dir) and commit `packages/shared-types`; (2) add root `pnpm.overrides`: `"tar": "^7.5.19"`, `"shell-quote": "^1.11.0"`; (3) `pnpm install` + `pnpm audit` to confirm 0 critical.
- Reminder: default branch is `001-mvp`. Local checkout is on unmerged `chore/add-dependabot` with ~52 dirty entries. Empty leftover local branch `security/build-tooling-criticals-oct2026` (no commits) — safe to delete.
- Full audit: `overseer/security/audit-2026-10-22.md`.


- macOS app: 5,411 lines Swift across 22 files. All core services (ProcessMonitor, WebSocketServer, TranscriptParser, WindowManager, ConfigManager) fully functional.
- Mobile app: 2,462 lines TypeScript across 17 files. 4 screens, 6 components, WebSocket hook with exponential backoff reconnect.
- 7 smoke test scripts ready to run. 20 manual test procedures documented in TEST_CHECKLIST.md.
- Release build (AgentDeck.app) exists but needs code signing for distribution.
- SLA targets: <500ms status updates, <1s window switching, <2s app launch, <100MB RAM.
- Estimated 12-22 hours (~2-3 days) to ship: testing + mobile builds + code signing + bug fixes.

## Model Updates
- [@claude] 2026-10-22: Set `status: archived`; added the archive note under Where I Left Off (repo archived, folder moved to apps/archive).
