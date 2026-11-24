# Delivery and notifications

Artifact delivery, function return values, and outcome notifications are
separate. Ask where the user wants results and whether an external write is
allowed. An integration connection does not imply its operations are available
as routine steps; the live action catalog decides that.

After creating a disabled routine, discover its supported destinations and
connection readiness:

```bash
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID/delivery-options" -H @<(auth_header) > delivery-options.json
jq '.data' delivery-options.json
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
curl --fail-with-body -sS "$BASE/webhooks" -H @<(auth_header) > webhooks.json
jq '[.items[] | {id,state,health}]' webhooks.json
```

A restricted API key may lack access to discovery or a destination. Ask for an
appropriate authorized key or dashboard setup; do not bypass its permissions.
Choose a result-sending step from the live action catalog when the receiver
needs the actual result; use its input schema to bind the output. Completion
notifications report the outcome and do not replace result delivery.

Success/failure webhook notifications report routine outcomes. They are separate
from the authenticated custom trigger that starts work. The document schema may
not represent every notification setting; do not invent a `notifications` field.
Use the public API contract described in the notification documentation, and
confirm target ownership and effects before sending a webhook. Preserve existing
notification settings when editing a routine.

More depth: https://docs.mobilerun.ai/webhooks and
https://docs.mobilerun.ai/agents/notifications.
