---
title: REBUILD spawns two app instances — LaunchAgent KeepAlive races with manual open call
date: 2026-06-05
category: docs/solutions/runtime-errors
module: wispr
problem_type: runtime_error
component: development_workflow
severity: medium
symptoms:
  - Two wispr processes visible in ps/Activity Monitor after every REBUILD
  - App appears to launch twice on each build cycle
  - Second instance accumulates with repeated builds
root_cause: async_timing
resolution_type: config_change
tags:
  - launchagent
  - keepalive
  - rebuild
  - double-instance
  - pkill
  - process-lifecycle
  - macos
---

# REBUILD spawns two app instances — LaunchAgent KeepAlive races with manual open call

## Problem

Every `bash REBUILD` left two `wispr` processes running. The REBUILD script killed the running app and launched a new one, but the LaunchAgent (`com.hull.wispr.plist`) with `KeepAlive=true` was already restarting the process in parallel — causing both to land at the same time.

## Symptoms

```bash
ps aux | grep wispr | grep -v grep
# stephen  38831  ... /Applications/Wispr.app/Contents/MacOS/wispr start
# stephen  38828  ... /Applications/Wispr.app/Contents/MacOS/wispr start
```

The issue recurred on every REBUILD run — baked into the script, not a one-time race.

## What Didn't Work

No intermediate fix was attempted. The bug was structural: REBUILD was calling `open` to launch the app while the LaunchAgent was already guaranteed to restart it after the `pkill`. Both fired within the same ~1s window.

## Solution

Remove the manual `open` call from REBUILD entirely. Replace it with a `pgrep` verification that confirms the LaunchAgent brought the app back up.

**Before (REBUILD step 6):**

```bash
echo "===== 6. launch ====="
open "/Applications/Wispr.app" --args start
sleep 2
if pgrep -qf "wispr"; then
    echo "running."
else
    echo "WARNING: app didn't stay running — check Console for crash logs."
fi
```

**After:**

```bash
echo "===== 6. verify running ====="
sleep 2
if pgrep -qf "wispr"; then
    echo "running (started by LaunchAgent)."
else
    echo "WARNING: app didn't start — check Console for crash logs."
fi
```

## Why This Works

The LaunchAgent's `KeepAlive=true` makes launchd responsible for keeping exactly one instance running. When REBUILD kills the process with `pkill`, launchd detects the exit and restarts within ~1 second. A manual `open` call after that window is redundant and produces a second instance.

Removing `open` leaves launchd as the sole launch authority. REBUILD's only job is to install the new binary and verify the LaunchAgent revived it.

## Prevention

Any script managing a process owned by a `KeepAlive` LaunchAgent should **never manually launch** that process. The correct pattern:

```bash
# ✓ Correct — kill, wait, verify
pkill -x wispr 2>/dev/null || true
sleep 2
pgrep -qf wispr && echo "running" || echo "WARNING: not running"

# ✗ Wrong — kill then manually launch (races with LaunchAgent restart)
pkill -x wispr 2>/dev/null || true
sleep 0.5
open "/Applications/Wispr.app" --args start  # ← produces second instance
```

If you need to suppress auto-restart during a test run:

```bash
launchctl unload ~/Library/LaunchAgents/com.hull.wispr.plist
# ... do work that should not auto-restart ...
launchctl load ~/Library/LaunchAgents/com.hull.wispr.plist
```

This same constraint applies to all other always-on apps managed by LaunchAgents in this project (Network CRM on port 3001, St. Laurence on port 3000).

## Related Issues

- Session history: the same `KeepAlive` restart pattern was used earlier for VP Rewriter's `server.js` — kill the process, let the LaunchAgent revive it. That established pattern was correctly copied to Wispr but the REBUILD script added a redundant manual launch step on top of it.
- `com.hull.wispr.plist` was written fresh during the v2.0 merge session (2026-06-05) — this is a first-occurrence bug, not a regression.
