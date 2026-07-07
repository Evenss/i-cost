# iCost

A minimal macOS menu bar app for tracking local and SSH remote AI agent usage costs.

iCost reads local and configured SSH remote AI agent usage logs, estimates cost, and shows today's
total in the macOS menu bar. Click the menu bar item to see recent daily trend
and per-agent totals.

The goal is to give developers a quick, low-noise view of AI agent spending
without opening dashboards or inspecting log files.

Currently supported sources:

![Claude Code](https://img.shields.io/badge/Claude%20Code-111111?style=flat&logo=claude&logoColor=white)
![Codex](https://img.shields.io/badge/Codex-111111?style=flat&logo=openai&logoColor=white)
![Cursor](https://img.shields.io/badge/Cursor-111111?style=flat&logo=cursor&logoColor=white)

## Requirements

- macOS 14 or later
- Key-based SSH access for remote sources

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

## Remote Sources

iCost can include usage logs from remote computers reachable through SSH. The
remote machine does not need iCost installed; it only needs readable agent log
directories and non-interactive SSH access from this Mac.

Open **Management > Sources > SSH Remote** to add or edit remote hosts. The app
writes the same settings to `~/Library/Application Support/iCost/remote-sources.json`.
You can also create that file manually:

```json
{
  "hosts": [
    {
      "id": "workstation",
      "host": "workstation.example.com",
      "user": "even",
      "port": 22,
      "identityFile": "~/.ssh/id_ed25519",
      "sources": ["claude_code", "codex"],
      "paths": {
        "claude_code": "~/.claude/projects",
        "codex": "~/.codex/sessions"
      }
    }
  ]
}
```

If `sources` is omitted, remote hosts default to Claude Code and Codex. Add
`"cursor"` explicitly for a remote macOS machine with Cursor data. You can also
set `I_COST_REMOTE_SOURCES=/path/to/remote-sources.json` before launching the app
to use a different config file.

Run `ssh workstation.example.com` once in Terminal first if the host key has not
been trusted yet. iCost uses `ssh` and `scp` with `BatchMode=yes`, so password
prompts are not shown inside the menu bar app.
