# TokenCostBar

Track AI usage costs from the macOS menu bar.

TokenCostBar is a small macOS utility that reads local AI agent usage logs,
estimates cost with an embedded model price catalog, and keeps the result in the
menu bar. It is meant to answer one quiet question: how much have my local AI
agents cost today?

## Features

- Menu bar display for today's estimated USD cost
- Lightweight popover with today, recent daily trend, and per-agent totals
- Management window for source status and broader stats
- Local SQLite storage
- GitHub Actions packaging for `.app`, `.app.zip`, and `.dmg` artifacts

## Supported Sources

The current build includes adapters for:

- Claude Code logs under `~/.claude/projects`
- Codex logs under `~/.codex/sessions`

TokenCostBar only uses local log data. It does not call provider billing APIs.

## Install

Download a packaged build from GitHub:

- Tagged versions publish files on the Releases page.
- Main-branch builds upload artifacts from the Package workflow.

For everyday use, move `TokenCostBar.app` to `/Applications` and add it to Login
Items in System Settings.

## Run From Source

Requirements:

- macOS 14 or later
- Swift 6 / Xcode 16 toolchain

```bash
swift run TokenCostBar
```

Run one scan from the command line:

```bash
swift run TokenCostBar --scan-once
```

Use a temporary database during development:

```bash
TOKEN_COST_BAR_DATABASE=/tmp/token-cost.sqlite swift run TokenCostBar --scan-once
```

## Package Locally

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

Override the packaged version when needed:

```bash
TOKEN_COST_BAR_VERSION=0.1.0 TOKEN_COST_BAR_BUILD_NUMBER=1 scripts/package-dmg.sh
```

## Development

```bash
swift test
```

## Scope

TokenCostBar intentionally keeps the UI small. It does not show project,
session, model, or token-type breakdowns, and it does not provide pricing
settings, currency settings, subscription amortization, payback calculations, or
CSV export.
