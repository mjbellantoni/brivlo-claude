---
name: help
description: Explains Brivlo integration configuration and troubleshooting
user_invocable: true
---

# Brivlo Integration Help

Brivlo is a control plane that tracks what your Claude Code instances are doing — waiting for permission, idle, running subagents, hitting errors.

## Required Environment Variables

| Variable | Required | Description |
|---|---|---|
| `BRIVLO_ENDPOINT` | Yes | Brivlo server URL (e.g. `http://localhost:9292`) |
| `BRIVLO_TOKEN` | Yes | Auth token (must match server's `BRIVLO_TOKEN`) |
| `BRIVLO_INSTANCE` | No | Instance name (auto-derived if absent) |
| `BRIVLO_DEBUG` | No | Set to `1` for stderr diagnostics |

## Instance Detection

If `BRIVLO_INSTANCE` is not set, the plugin derives it:
1. Current directory basename if it matches `wt-*` (e.g. `/path/to/wt-a` → `wt-a`)
2. `.brivlo.json` in the current directory: `{ "instance": "wt-a" }`
3. Fallback: `unknown`

## Events Emitted

| Event | When |
|---|---|
| `session.start` | Session begins |
| `session.end` | Session ends |
| `wait.permission` | Permission prompt shown |
| `wait.idle` | Idle prompt shown |
| `tool.invoke` | Bash, WebFetch, or Skill invoked |
| `tool.error` | Tool call fails |
| `phase.start` | Subagent spawned |
| `phase.end` | Subagent finished |

## Testing

1. Verify the sender CLI is installed: `which brivlo_event`
2. Verify env vars are set: `echo $BRIVLO_ENDPOINT`
3. Ping the server: `curl $BRIVLO_ENDPOINT/ping`
4. Send a test event: `brivlo_event session.start --instance test --host test`
5. Check the dashboard: open `$BRIVLO_ENDPOINT/board` in a browser

## Troubleshooting

- **No events appearing**: Check that `BRIVLO_ENDPOINT` and `BRIVLO_TOKEN` are set in your shell profile.
- **`brivlo_event` not found**: Install the `brivlo` gem: `gem install brivlo`
- **Server unreachable**: The plugin is fail-open — Claude is never blocked. Set `BRIVLO_DEBUG=1` to see warnings on stderr.
