# iCost

A lightweight macOS menu bar app for tracking AI agent token costs.

iCost reads local or SSH remote usage records and shows today's cost, recent trends, and per-agent totals without opening a dashboard.

![Claude Code](https://img.shields.io/badge/Claude%20Code-111111?style=flat&logo=claude&logoColor=white)
![Codex](https://img.shields.io/badge/Codex-111111?style=flat&logo=openai&logoColor=white)
![Cursor](https://img.shields.io/badge/Cursor-111111?style=flat&logo=cursor&logoColor=white)

## Features

- Menu bar cost overview and daily trends
- Local Claude Code, Codex, and Cursor support
- SSH remote source support
- Local processing with no conversation content uploads

## Requirements

- macOS 14 or later
- Key-based SSH access when using remote sources

## Install

Download the latest DMG from GitHub Releases, then move `iCost.app` to `/Applications`.

After launch, iCost stays in the menu bar. Open **Management > Sources** to view local sources or add an SSH remote device.

If `ssh workstation` already works in Terminal, enter `workstation` in iCost. Existing `~/.ssh/config` settings are used automatically.

## Build

Requires Swift 6 and Xcode 16 or later.

```bash
scripts/package-dmg.sh
```
