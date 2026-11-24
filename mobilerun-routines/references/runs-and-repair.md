# Runs, health, and repair

Keep the routine, execution, invocation, function, function-run, and sandbox IDs
separate. A successful API request proves acceptance; inspect the work's outcome.

## Watch an execution

Set `EXECUTION_ID` from verification, a manual run, or the invocation's execution
list. Poll completion using `finishedAt`, with a bounded deadline. Inspect each
step's error and output:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
DEADLINE=$((SECONDS + 300))
until curl --fail-with-body -sS "$BASE/executions/$EXECUTION_ID" -H @<(auth_header) > execution.json \
  && jq -e '.data.finishedAt != null' execution.json > /dev/null; do
  [ "$SECONDS" -lt "$DEADLINE" ] || { printf 'Execution still running\n' >&2; exit 1; }
  sleep 3
done
jq '.data | {status,error,steps:[.result.steps[]? | {name,status,body}]}' execution.json
curl --fail-with-body -sS "$BASE/executions?flowId=$FLOW_ID" -H @<(auth_header) | jq .
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID" -H @<(auth_header) > flow-state.json
jq '.data | {enabled,status,blockedAt,lastFailureCode,consecutiveFailures}' flow-state.json
)
```

Use the API's execution status; require `success` before verified activation.
Do not mistake a running step, empty list, or successful function upload for a
successful execution. If a list is empty immediately after enqueue, keep
polling rather than asserting no work happened. Page through history when needed.

## Run now

After verified activation, a manual live run uses this route. It can also start
a scheduled routine immediately. Custom payloads must match its input schema;
scheduled routines use their stored inputs. This can fan out over bound devices.

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
MANUAL_KEY=$(uuidgen)
jq -n --slurpfile payload payload.json '{payload:$payload[0]}' > manual-body.json
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID/run" -H @<(auth_header) \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $MANUAL_KEY" \
  --data-binary @manual-body.json > manual-run.json
jq '.data' manual-run.json
EXECUTION_ID=$(jq -er '.data.executionIds[0]' manual-run.json)
printf 'EXECUTION_ID=%q\n' "$EXECUTION_ID" >> mobilerun-state.sh
)
```

Inspect all returned execution IDs. Zero admissions or `enqueueFailed` requires
investigation, not a success report. Use Test run for disabled routine testing.

## Diagnose, repair, re-test

1. Read health from `GET /flows/$FLOW_ID`: `.data.status`, `blockedAt`,
   `lastFailureCode`, and `consecutiveFailures`, alongside `enabled`. Check also
   exposes `.data.gates.blocked`. Health is `healthy`, `failing`, or `blocked`.
   A blocked routine admits then skips new runs (`skipped`, "Flow is blocked"),
   even if fire reports `enqueuedCount: 1`. Find the cause in the last `failed`
   execution that started at or before `blockedAt`, rather than the latest
   skipped run. Its `finishedAt` may fall just after the block was recorded.
   Preserve that response before changing health. For a function step, read
   `stdout`, `stderr`, `errorCode`, and `errorText` from the execution's step body.
   Routine-started function runs are unavailable on the direct-run routes; their
   logs are retained only when the routine's log setting is on.
2. Pause recurring work before changing it. Export its canonical document as
   a backup ([documents](documents.md)). Separate invalid inputs, stale/deleted
   function versions, device issues, missing connections, and capacity errors.
   Check does not prove referenced functions or devices still exist.
3. Refresh live contracts, fix the smallest cause, show the change, validate,
   and replace while disabled. Never broaden permissions or purchase resources
   to conceal a failure. Treat authentication failures as a user action.
4. Check and Test run again. Verification does not update live health; inspect
   the actual execution and require success before continuing.
5. After the fixed document passes Test run: **unblock only if blocked**. If
   unblocked, repeat Test run and wait for success, then activate with that
   fresh execution ID. Unblocking changes the routine and can make the earlier
   verification stale. Confirm `enabled: true` and `status: healthy` afterward;
   activation does not clear a block. If unblocking returns `still_broken`, fix
   the cause and re-test before trying again. On activation `verification_stale`,
   repeat Check and Test run, then use the fresh execution ID.

Inspect repair history separately; automatic repair is conditional, not guaranteed:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID/repairs" -H @<(auth_header) | jq .
)
```

Only after fixing the cause and passing Test run, run this guarded unblock.
If the routine is not blocked, it does nothing. Unblocking resets failure
counters; never use it to make an unfixed `failing` routine look healthy.

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID" -H @<(auth_header) > health-before-unblock.json
if jq -e '.data.status == "blocked"' health-before-unblock.json > /dev/null; then
  curl --fail-with-body -sS -X POST "$BASE/flows/$FLOW_ID/unblock" -H @<(auth_header) \
    | jq '.data | {status,blockedAt}'
fi
)
```

Do not unblock repeatedly without fixing the cause. If an agent-managed routine
needs a new deployed version, use its owner/agent workflow; do not force owner
replacement. Report an unresolved error with its IDs and observed response.

## Capacity and cleanup

Fetch live capacity before creating or cloning. Disabled routines still consume
slots; pausing does not free one. Let the API decide capacity. On refusal, show
its response and ask about removing an explicitly disposable routine or changing
the plan; never invent a quota or auto-upgrade. See
[capacity and cost](https://docs.mobilerun.ai/routines/runs#capacity-and-cost)
and [credits and usage](https://docs.mobilerun.ai/credits).

Before the **first create**, save a paginated action snapshot. Do this once per
task; do not overwrite it after creating or replacing a document. Both operations
create action definitions, including definitions retained after replacements.

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
if [ ! -f actions-before.json ]; then
  PAGE=1
  : > actions-before.ndjson
  while :; do
    curl --fail-with-body -sS "$BASE/actions?page=$PAGE&pageSize=100" -H @<(auth_header) > actions-page.json
    jq -c '.items[]' actions-page.json >> actions-before.ndjson
    [ "$(jq -r '.pagination.hasNext' actions-page.json)" = true ] || break
    PAGE=$((PAGE + 1))
  done
  jq -s . actions-before.ndjson > actions-before.json
fi
)
```

Wait for all task-created runs to finish. Pause and remove **only disposable
routines created for this task**; retain the user's intended routine:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
curl --fail-with-body -sS -X PATCH "$BASE/flows/$FLOW_ID" -H @<(auth_header) \
  -H 'Content-Type: application/json' -d '{"enabled":false}' | jq '.data'
curl --fail-with-body -sS -X DELETE "$BASE/flows/$FLOW_ID" -H @<(auth_header)
curl --fail-with-body -sS "$BASE/flows" -H @<(auth_header) | jq .
curl --fail-with-body -sS "$BASE/flows/capacity" -H @<(auth_header) | jq '.data'
)
```

Delete the saved test trigger only after confirming no retained routine uses it:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
curl --fail-with-body -sS -X DELETE "$BASE/triggers/$TRIGGER_ID" -H @<(auth_header)
)
```

Fetch every current action page and compute new IDs relative to the snapshot:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
PAGE=1
: > actions-after.ndjson
while :; do
  curl --fail-with-body -sS "$BASE/actions?page=$PAGE&pageSize=100" -H @<(auth_header) > actions-page.json
  jq -c '.items[]' actions-page.json >> actions-after.ndjson
  [ "$(jq -r '.pagination.hasNext' actions-page.json)" = true ] || break
  PAGE=$((PAGE + 1))
done
jq -s . actions-after.ndjson > actions-after.json
jq -n --slurpfile before actions-before.json --slurpfile after actions-after.json \
  '($before[0] | map(.id)) as $old | [$after[0][] | select(.id as $id | $old | index($id) | not)]' \
  > action-candidates.json
jq '[.[] | {id,name,createdAt}]' action-candidates.json
)
```

Candidates are not permission to delete everything: another caller may have
created an action during this task. Confirm each candidate belongs to this task
and is unused by every routine you keep. Set `ACTION_ID` to one confirmed ID in
`mobilerun-state.sh`, then repeat this guarded deletion only for confirmed IDs:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
jq -e --arg id "$ACTION_ID" 'any(.[]; .id == $id)' action-candidates.json > /dev/null
curl --fail-with-body -sS -X DELETE "$BASE/actions/$ACTION_ID" -H @<(auth_header)
)
```

List again to confirm the deleted IDs are absent. Keep the user's retained
routine, function versions, connections, and devices intact.
More depth: https://docs.mobilerun.ai/routines/runs.
