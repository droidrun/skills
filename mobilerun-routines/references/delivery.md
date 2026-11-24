# Delivery and notifications

Artifact delivery, function return values, and outcome notifications are
separate. Ask where the user wants results and whether an external write is
allowed. Execution history keeps each step's output by default: read its `body`
in `GET /executions/{EXECUTION_ID}`. Saving state, uploading files, or configuring
a delivery destination are opt-ins to choose with the user. For file creation,
follow [Save files](https://docs.mobilerun.ai/routines/functions#save-files-files-upload)
and fetch its current parameters from the catalog. An integration connection
does not make its operations available as steps; the live catalog decides that.

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

Choose a supported, connected destination using that response and the live
settings schema. A return value alone does not send a file or message. Add any
required steps from the catalog, then validate, Check, Test run, and confirm
arrival. Follow [delivery setup](https://docs.mobilerun.ai/routines/integrations#delivery);
obtain approval before connecting accounts or granting broader scopes.

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
https://docs.mobilerun.ai/notifications. Until notification delivery is
configured, report completion and output by polling the execution. Confirm
target ownership and effects before sending a webhook; preserve existing
notification settings when editing a routine.

More depth: https://docs.mobilerun.ai/routines/integrations and
https://docs.mobilerun.ai/webhooks.
