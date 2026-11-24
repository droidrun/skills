# Sandboxes

Use a sandbox when the user needs commands with shared files or a one-off Python
snippet. Use a Serverless Function for saved, typed, repeatable code. Sandbox
minutes include idle time: obtain permission for cost, set a short lifetime, and
stop promptly. No phone is needed for ordinary Python.

Create once and inspect readiness before execution. This example runs without
network access. Replace the command with the user's approved snippet, retaining
JSON escaping through `jq` when it contains quotes or newlines.

```bash
SANDBOX_KEY=$(uuidgen)
curl --fail-with-body -sS "$BASE/compute/sandboxes" -H @<(auth_header) \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $SANDBOX_KEY" \
  -d '{"name":"One-off Python","timeoutS":300,"idleTimeoutS":60}' > sandbox.json
SANDBOX_ID=$(jq -er '.data.id' sandbox.json)
curl --fail-with-body -sS "$BASE/compute/sandboxes/$SANDBOX_ID" -H @<(auth_header) > sandbox-state.json
jq '.data | {id,status}' sandbox-state.json
```

If `starting`, poll until `running` or a terminal failure with a bounded deadline.
Never exec before `running`. Then:

```bash
curl --fail-with-body -sS "$BASE/compute/sandboxes/$SANDBOX_ID/exec" -H @<(auth_header) \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $(uuidgen)" \
  -d '{"command":"python -c '\''print(6 * 7)'\''","timeoutS":30,"waitS":30}' > command.json
jq '.data' command.json
COMMAND_ID=$(jq -er '.data.commandId' command.json)
curl --fail-with-body -sS "$BASE/compute/sandboxes/$SANDBOX_ID/commands/$COMMAND_ID?waitS=30" -H @<(auth_header) > command-result.json
jq '.data | {status,exitCode,timedOut,stdout,stderr,truncated}' command-result.json
```

HTTP 202 means the command is still running; poll its command ID to completion.
Require `exitCode: 0`, no timeout, and the intended stdout. Check `truncated`;
download output files before stopping when inline output is incomplete. For
networking, declare only the required exact hosts in `allowedHosts`; HTTPS and
host restrictions apply. Do not put secrets in command arguments or logs.

Always stop after completion, including failure paths:

```bash
curl --fail-with-body -sS -X DELETE "$BASE/compute/sandboxes/$SANDBOX_ID" -H @<(auth_header)
STOP_DEADLINE=$((SECONDS + 60))
while :; do
  curl --fail-with-body -sS "$BASE/compute/sandboxes/$SANDBOX_ID" -H @<(auth_header) > sandbox-stopped.json
  [ "$(jq -r '.data.status' sandbox-stopped.json)" = stopped ] && break
  [ "$SECONDS" -lt "$STOP_DEADLINE" ] || { printf 'Sandbox has not stopped\n' >&2; exit 1; }
  sleep 1
done
jq '.data | {id,status}' sandbox-stopped.json
```

Stopping can be asynchronous. Confirm it is stopped rather than assuming HTTP
202 means cleanup has finished. A stopped history record can remain visible.
More depth: https://docs.mobilerun.ai/agents/workflows.
