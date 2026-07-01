# iCost

A minimal macOS menu bar app for tracking local AI agent usage costs.

iCost reads local AI agent usage logs, estimates cost, and shows today's
total in the macOS menu bar. Click the menu bar item to see recent daily trend
and per-agent totals.

The goal is to give developers a quick, low-noise view of AI agent spending
without opening dashboards or inspecting log files.

Currently supported sources:

- Claude Code: `~/.claude/projects`
- Codex: `~/.codex/sessions`

## Requirements

- macOS 14 or later

## Download and Install

Download a packaged build from GitHub Releases. For unreleased builds, use the
latest Package workflow artifact.

- Open the downloaded DMG, or unzip the `.app.zip` artifact.
- Move `iCost.app` to `/Applications`.
- Add it to Login Items in System Settings if you want it to start automatically.

After launch, iCost stays in the macOS menu bar. Click the menu bar item
to view today's cost, recent trend, and per-agent totals.

## Build Package

Local packaging requires Swift 6 / Xcode 16 or later.

```bash
scripts/package-dmg.sh
open dist/i-cost-0.1.0.dmg
```
