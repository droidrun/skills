# Runs, health, and repair

Keep the routine, execution, invocation, function, function-run, and sandbox IDs
separate. A successful API request proves acceptance; inspect the work's outcome.

## Watch an execution

Set `EXECUTION_ID` from verification, a manual run, or the invocation's execution
list. Poll with a bounded deadline and a small delay until terminal. Inspect the
full saved response, especially each step's error and output:

```bash
curl --fail-with-body -sS "$BASE/executions/$EXECUTION_ID" -H @<(auth_header) > execution.json
jq '.data' execution.json
curl --fail-with-body -sS "$BASE/executions?flowId=$FLOW_ID" -H @<(auth_header) | jq .
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID" -H @<(auth_header) > flow-state.json
jq '.data' flow-state.json
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
MANUAL_KEY=$(uuidgen)
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID/run" -H @<(auth_header) \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $MANUAL_KEY" \
  -d '{"payload":{}}' > manual-run.json
jq '.data' manual-run.json
EXECUTION_ID=$(jq -er '.data.executionIds[0]' manual-run.json)
```

Inspect all returned execution IDs. Zero admissions or `enqueueFailed` requires
investigation, not a success report. Use Test run for disabled routine testing.

## Diagnose, repair, re-test

1. Read routine health and the failing execution, then its step error, input,
   resolved parameters, output, and relevant function logs. Health is `healthy`,
   `failing`, or `blocked`; blocked work cannot resume normally.
2. Pause recurring work before changing it. Export its canonical document as
   a backup ([documents](documents.md)). Separate invalid inputs, stale/deleted
   function versions, device issues, missing connections, and capacity errors.
3. Refresh live contracts, fix the smallest cause, show the change, validate,
   and replace while disabled. Never broaden permissions or purchase resources
   to conceal a failure. Treat authentication failures as a user action.
4. Check and Test run again. Failed verification does not update live health;
   inspect the actual execution, rather than waiting for health to change.
5. Inspect repairs; automatic repair is conditional, not guaranteed. Once the
   cause is fixed, unblock if blocked. A `still_broken` response means more work
   is needed. Activate only with a successful verification of the current graph.

```bash
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID/repairs" -H @<(auth_header) | jq .
curl --fail-with-body -sS -X POST "$BASE/flows/$FLOW_ID/unblock" -H @<(auth_header) | jq .
```

Do not unblock repeatedly without fixing the cause. If an agent-managed routine
needs a new deployed version, use its owner/agent workflow; do not force owner
replacement. Report an unresolved error with its IDs and observed response.

## Capacity and cleanup

Fetch live capacity before creating or cloning. Disabled routines still consume
slots; pausing does not free one. Let the API decide capacity. On refusal, show
its response and ask about removing an explicitly disposable routine or changing
the plan; never invent a quota or auto-upgrade.

To pause a routine and remove **only disposable artifacts created for this task**:

```bash
curl --fail-with-body -sS -X PATCH "$BASE/flows/$FLOW_ID" -H @<(auth_header) \
  -H 'Content-Type: application/json' -d '{"enabled":false}' | jq '.data'
curl --fail-with-body -sS -X DELETE "$BASE/flows/$FLOW_ID" -H @<(auth_header)
curl --fail-with-body -sS "$BASE/flows" -H @<(auth_header) | jq .
curl --fail-with-body -sS "$BASE/flows/capacity" -H @<(auth_header) | jq '.data'
```

Check the saved trigger and action IDs too: deletion can retain definitions.
Remove only owned test definitions after confirming no retained routine uses them:

```bash
curl --fail-with-body -sS -X DELETE "$BASE/triggers/$TRIGGER_ID" -H @<(auth_header)
```

If the task created other action definitions, list them and compare their IDs
with your task's saved artifacts. Set `ACTION_ID` to one confirmed unused test
definition; repeat deletion only for those confirmed IDs. Never delete a whole
account's actions just because a test finished.

```bash
curl --fail-with-body -sS "$BASE/actions" -H @<(auth_header) > actions.json
jq '[.items[] | {id,name}]' actions.json
curl --fail-with-body -sS -X DELETE "$BASE/actions/$ACTION_ID" -H @<(auth_header)
```

Keep the user's intended
routine, function versions, connections, and devices intact.
More depth: https://docs.mobilerun.ai/agents/workflows.
