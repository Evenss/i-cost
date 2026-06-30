# TokenCostBar

A minimal macOS menu bar app for tracking local AI agent usage costs.

TokenCostBar reads local AI agent usage logs, estimates cost, and shows today's
total in the macOS menu bar. Click the menu bar item to see recent daily trend
and per-agent totals.

The goal is to give developers a quick, low-noise view of AI agent spending
without opening dashboards or inspecting log files.

Currently supported sources:

- Claude Code: `~/.claude/projects`
- Codex: `~/.codex/sessions`

## Requirements

- macOS 14 or later
- Swift 6 / Xcode 16 or later for building from source

## Use

Download a packaged build from GitHub Releases or the Package workflow
artifacts. Move `TokenCostBar.app` to `/Applications`, then add it to Login
Items in System Settings if you want it to start automatically.

Run from source:

```bash
swift run TokenCostBar
```

Run one scan from the command line:

```bash
swift run TokenCostBar --scan-once
```

## Package

Build a `.app` bundle:

```bash
scripts/package-app.sh
open build/TokenCostBar.app
```

Build a DMG:

```bash
scripts/package-dmg.sh
open dist/TokenCostBar-0.1.0.dmg
```
