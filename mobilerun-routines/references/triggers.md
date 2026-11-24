# When a routine runs

Fetch the live document schema for trigger shapes. Manual work uses the custom
trigger kind. Scheduled work can run once, on cron, or using RRULE. Ask for an
IANA timezone, explain daylight-saving behavior, and confirm the next intended
local occurrence. A jitter window randomizes timing; add one only when wanted.
Do not copy raw trigger API fields into the document: their shapes differ.

For “every weekday at 08:00 Berlin time”, the schedule intent is five-field
cron `0 8 * * 1-5`, timezone `Europe/Berlin`. Discover its document representation
in the current schema. For once, use an unambiguous timestamp. For RRULE, check
the supported frequency and starting-time semantics before promising a time.
Use the dry-run report and the saved trigger to check configuration.

Scheduled inputs are stored on the trigger. Define their schema and values
using the live document contract. Schedule runs, including verification, use
those stored inputs; request overrides are ignored. Custom inputs are validated
against the configured custom input schema. Map inputs and earlier outputs
using the fetched template context, not guessed paths.

## An endpoint for a backend

A custom trigger exposes an **authenticated API call**, not a public webhook.
Create the routine with the document API, verify it, and enable it first. Save
`TRIGGER_ID` from the routine response. Keep the API key on the calling server;
never place it in a public page or callback URL.

```bash
FIRE_KEY=$(uuidgen)
curl --fail-with-body -sS "$BASE/triggers/$TRIGGER_ID/fire" -H @<(auth_header) \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $FIRE_KEY" \
  -d '{"payload":{}}' > fired.json
jq '{invocationId,enqueuedCount,deduplicated}' fired.json
INVOCATION_ID=$(jq -er '.invocationId' fired.json)
curl --fail-with-body -sS "$BASE/executions?invocationId=$INVOCATION_ID" -H @<(auth_header) | jq .
```

Fire returns HTTP 202 with no `data` envelope. Use the invocation ID to find the
actual executions; keep polling until each admitted execution is terminal.
`enqueuedCount: 0` is not success: inspect enabled state, health, bindings,
cooldown, and eligibility. One trigger may fan out to several routines/devices.
Reuse the same idempotency key and body for a retry; use a new key for new work.
Scheduled triggers cannot be fired through this route.

## Event triggers

App, device, and platform event triggers are **Soon**, even if discoverable
contracts expose them. Offer scheduling or custom fire as the available path.

More depth: https://docs.mobilerun.ai/agents/workflows.
