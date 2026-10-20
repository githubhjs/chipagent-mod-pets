---
description: "Show your chip-pet, or pet, feed, rename or switch it"
argument-hint: "[show|pet|feed|name <new name>|adopt <species>|help]"
---

# Pet

The user wants to see or play with their chip-pet. Do not explain, plan or
read files: run exactly one shell command, then show its output.

Run this, with `$ARGUMENTS` passed through unchanged (empty means `show`):

```bash
P="$(cat "${CHIPAGENTS_HOME:-$HOME/.chipagents}/pet/plugin_root" 2>/dev/null)/bin/chip-pet"; [ -f "$P" ] || P="$(command -v chip-pet)"; bash "$P" slash $ARGUMENTS
```

Then reply with the command's output inside one fenced code block, exactly as
printed, and nothing else. If the command is not found, say that chip-pet is
not set up yet and that ChipAgents must be restarted once after installing the
plugin, or `chip-pet` put on PATH.
