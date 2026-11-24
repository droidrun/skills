# Delivery and notifications

Artifact delivery, function return values, and outcome notifications are
separate. Ask where the user wants results and whether an external write is
allowed. Execution history keeps each step's output by default: read its `body`
in `GET /executions/{EXECUTION_ID}`. Saving state, uploading files, or configuring
a delivery destination are opt-ins to choose with the user. **Example — check
the catalog:** `state.save` and `files.upload` are possible steps, not defaults.
An integration connection does not imply its operations are available
as routine steps; the live action catalog decides that.

After creating a disabled routine, discover its supported destinations and
connection readiness:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID/delivery-options" -H @<(auth_header) > delivery-options.json
jq '.data' delivery-options.json
)
```

Read that response and the live document settings schema. Choose only a supported,
connected destination; do not copy a destination catalog or guess connection
IDs. A plain function result does not automatically become an artifact or an
email. If delivery needs additional supported steps, add them using the live
catalog, validate the document again, and repeat Check and Test run. Confirm the
actual output reached the intended destination before claiming delivery works.
Do not connect accounts or grant broader scopes without the user's approval.

Fetch existing webhook subscriptions before choosing notifications or a
webhook result step. Exhaust the returned pagination before concluding a
destination is missing. Fetch step parameters from the live action catalog.

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
PAGE=1
: > webhooks.ndjson
while :; do
  curl --fail-with-body -sS "$BASE/webhooks?page=$PAGE&pageSize=100" -H @<(auth_header) > webhooks-page.json
  jq -c '.items[]' webhooks-page.json >> webhooks.ndjson
  [ "$(jq -r '.pagination.hasNext' webhooks-page.json)" = true ] || break
  PAGE=$((PAGE + 1))
done
jq -s . webhooks.ndjson > webhooks.json
jq '[.[] | {id,state,health}]' webhooks.json
)
```

A restricted API key may lack access to discovery or a destination. Ask for an
appropriate authorized key or dashboard setup; do not bypass its permissions.
Choose a result-sending step from the live action catalog when the receiver
needs the actual result; use its input schema to bind the output. Completion
notifications report the outcome and do not replace result delivery.

Success/failure webhook notifications report routine outcomes. They are separate
from the authenticated custom trigger that starts work. The document schema may
not represent every notification setting; do not invent a `notifications` field.
For completion notifications, follow the exact setup guide at
https://docs.mobilerun.ai/agents/notifications. Until notification delivery is
configured, report completion and output by polling the execution. Confirm
target ownership and effects before sending a webhook; preserve existing
notification settings when editing a routine.

More depth: https://docs.mobilerun.ai/webhooks and
https://docs.mobilerun.ai/agents/notifications.
