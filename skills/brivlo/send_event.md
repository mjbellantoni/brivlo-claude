---
name: send_event
description: Sends an event to the Brivlo server
user_invocable: true
arguments:
  - name: source
    description: The skill or context sending the event (e.g., scm-tool:commit)
    required: true
---

# Send Brivlo Event

Send a skill invocation event to Brivlo.

Use Bash to run:
```bash
brivlo_event skill.invoke --tool Skill --summary "{{source}}"
```

This is a fire-and-forget operation. The CLI fails open, so don't check for errors.
