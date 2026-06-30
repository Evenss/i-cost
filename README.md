# TokenCostBar

A minimal macOS menu bar app for local AI agent usage cost statistics.

It reads local Claude Code and Codex usage logs, maps model names to an embedded price catalog, estimates USD cost, converts CNY with a fixed `USD × 7` rule, and shows only the essentials:

- Today
- Daily Trend
- Agents

## Run

```bash
swift run TokenCostBar
```

## Package

```bash
chmod +x scripts/package-app.sh
scripts/package-app.sh
open build/TokenCostBar.app
```

For everyday use, move the packaged app to `/Applications` and add it to Login Items in System Settings.

To create an installable DMG:

```bash
chmod +x scripts/package-dmg.sh
scripts/package-dmg.sh
open dist/TokenCostBar-0.1.0.dmg
```

## Scan Once

```bash
swift run TokenCostBar --scan-once
```

For a temporary database during development:

```bash
TOKEN_COST_BAR_DATABASE=/tmp/token-cost.sqlite swift run TokenCostBar --scan-once
```

## Test

```bash
swift test
```

## Scope

The app intentionally does not show projects, sessions, models, token types, pricing settings, currency settings, subscription amortization, payback ratios, or CSV export.
