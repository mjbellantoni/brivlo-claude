# brivlo-claude

Claude Code plugin that sends lifecycle events to a Brivlo server. Provides visibility into what your Claude instances are doing: waiting for permission, idle, spawning subagents, encountering errors.

This repo contains only the Claude Code integration — no server, no database.

## Installation

1. Add the plugin marketplace (once):
   ```
   /plugin marketplace add mjbellantoni/brivlo-claude
   ```

2. Enable in your user-level Claude Code settings (`~/.claude/settings.json`):
   ```json
   {
     "enabledPlugins": {
       "brivlo-claude@brivlo-claude": true
     }
   }
   ```

3. Ensure the `brivlo_event` CLI is installed:
   ```bash
   gem install brivlo
   ```

## Configuration

Set these environment variables in your shell profile:

| Variable | Required | Description |
|---|---|---|
| `BRIVLO_ENDPOINT` | Yes | Brivlo server URL (e.g. `http://localhost:9292`) |
| `BRIVLO_TOKEN` | Yes | Auth token (must match server) |
| `BRIVLO_INSTANCE` | No | Instance name; auto-derived if absent |
| `BRIVLO_DEBUG` | No | Set to `1` for stderr diagnostics |

### Instance Detection

If `BRIVLO_INSTANCE` is not set, the plugin derives it automatically:

1. Current directory basename if it matches `wt-*` (e.g. `/path/to/wt-a` → `wt-a`)
2. `.brivlo.json` in the current directory: `{ "instance": "wt-a" }`
3. Fallback: `unknown`

## Events

| Event | Trigger | Fields |
|---|---|---|
| `session.start` | Session begins | instance, host |
| `session.end` | Session ends | instance, host |
| `wait.permission` | Permission prompt shown | instance, host, tool, summary |
| `wait.idle` | Idle prompt shown | instance, host |
| `tool.invoke` | Bash, WebFetch, or Skill invoked | instance, host, tool, summary |
| `tool.error` | Tool call fails | instance, host, tool, summary |
| `phase.start` | Subagent spawned | instance, host, meta (subagent type) |
| `phase.end` | Subagent finished | instance, host, meta (subagent type) |

Every event includes `instance`, `host`, and `ts` (ISO 8601 timestamp, added by `brivlo_event`).

## How It Works

Claude Code hooks fire on lifecycle events and pipe JSON to `scripts/brivlo_emit.rb`. The script reads the JSON, maps the hook event to a Brivlo event, sanitizes the summary, and execs `brivlo_event` with the appropriate flags.

**Summary sanitization:**
- Bash commands: first 80 characters, first line only
- Edit/Write/Read: file path only
- WebFetch: domain only
- Skill: skill name only
- Full prompts and secrets are never included

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| No events appearing | Env vars not set | Add `BRIVLO_ENDPOINT` and `BRIVLO_TOKEN` to shell profile |
| `brivlo_event` not found | Gem not installed | `gem install brivlo` |
| Server unreachable | Server down or wrong URL | Check `$BRIVLO_ENDPOINT/ping` |
| Events sent but not visible | Wrong token | Ensure `BRIVLO_TOKEN` matches server |

**Fail-open guarantee:** The plugin never blocks Claude. If `brivlo_event` is missing, env vars are absent, or the server is unreachable, the hook exits 0 silently. Set `BRIVLO_DEBUG=1` to see warnings on stderr.

## Skills

### `brivlo:help`

Run `/brivlo:help` for configuration and troubleshooting guidance.

### `brivlo:send_event`

Allows other skills to emit events to Brivlo. This enables visibility into skill invocations beyond the automatic hook-based tracking.

**Usage from another skill:**

Add this line to your skill's instructions:

```markdown
If `brivlo:send_event` is available, use `brivlo:send_event your-skill:name` as your first step.
```

For example, a `scm-tool:commit` skill might include:

```markdown
If `brivlo:send_event` is available, use `brivlo:send_event scm-tool:commit` as your first step.
```

This sends a `skill.invoke` event with the skill name as the summary. The check for availability ensures skills work normally even when brivlo-claude isn't installed.
