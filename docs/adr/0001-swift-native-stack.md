# 1. Native Swift stack across macOS, agent, and iOS

Date: 2026-08-26

## Status

Accepted

## Context

MyPorts needs a macOS menu-bar app now, and later a network agent, a small web
UI, and an iOS client that can view and kill ports on paired machines. We are a
single developer and want to ship a usable macOS tool quickly without carrying
four unrelated toolchains.

Options considered:

- **Electron / Tauri**: one web UI everywhere, but a heavy runtime for a
  menu-bar utility, no first-class `MenuBarExtra`, and still no path to a real
  iOS app.
- **Go / Rust core + platform UIs**: fast core, but the UI would be rewritten
  per platform and FFI adds friction for the kill/inspect syscalls.
- **Swift / SwiftUI end to end**: native `MenuBarExtra`, direct access to
  `libproc` and `kill(2)`, and the SwiftUI view layer is shared verbatim
  between macOS and iOS.

## Decision

Build everything in Swift:

- `PortsKit` — pure logic (enumerate, enrich, kill, monitor). No UI, no network.
- `PortsUI` — SwiftUI views shared by the macOS and iOS apps.
- `PortsRemote` — the HTTP+JSON agent library and its client models.
- `portsd` — a thin executable over `PortsRemote` (and, today, a standalone CLI
  over `PortsKit`).

The repository is a monorepo: a root SwiftPM package for the libraries and the
executable, plus an Xcode workspace for the two app targets that consume the
local packages.

## Consequences

- The macOS and iOS apps require full Xcode to build; the libraries and `portsd`
  build with the Command Line Tools alone. CI runs on GitHub's macOS runners,
  which have Xcode.
- The apps cannot be sandboxed (they run `lsof` and signal other processes), so
  distribution is Developer ID + notarization, not the App Store, for macOS.
- Reusing `PortsUI` keeps the iOS client cheap, at the cost of keeping those
  views free of macOS-only APIs.
