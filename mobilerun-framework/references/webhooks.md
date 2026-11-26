# Webhooks

## Send sandbox results to your server

1. After approval, run `mobilerun webhook register` and enter the receiver's HTTPS URL. Copy the endpoint UUID and store the one-time signing secret securely on the receiver. Registration does not send a test request.
2. Put the UUID in `webhook=` on a named `@cloud` declaration. Save as `report.py` and replace the example UUID with the registered one. The declaration needs an endpoint (the default) or a schedule.

```python
from pydantic import BaseModel

from mobilerun.sandbox import cloud


class ReportInput(BaseModel):
    count: int


class ReportOutput(BaseModel):
    count: int


@cloud("daily-report", webhook="12345678-1234-4abc-8def-123456789abc")
def report(input: ReportInput) -> ReportOutput:
    return ReportOutput(count=input.count)
```

The endpoint must be active, not blocked, and subscribed to `workflow.step.emit` or all events. A URL fails declaration validation; an unknown UUID fails deployment preflight before resources are deployed. See [sandbox deployment](sandbox.md#declare-and-deploy). Deploy, fire and enable require `paid` and can incur charges.

Endpoint management works under `no_commerce`, but it is not a dry run: registration creates a cloud resource, and ping sends a real outbound POST. Get approval before running either. If asked to display the signing secret, show it once in a private terminal, never in logs, CI output, or a saved transcript.

## CLI

| Command | Behavior |
| --- | --- |
| `mobilerun webhook register [URL]` | Prompts only for the URL if omitted. Defaults to `workflow.step.emit`; repeat `--event-type EVENT` to override. Reuses a compatible endpoint for the same URL without changing it. Shows the signing secret only on creation, including with `--json`; never log that output. |
| `mobilerun webhook list` | Lists endpoints; `--json` returns metadata. |
| `mobilerun webhook get [ID]` | Inspects one endpoint; `--json` returns metadata. |
| `mobilerun webhook ping [ID]` | Sends a signed `webhook.test` POST and reports the HTTP result if available. Exits nonzero on failure. |
| `mobilerun webhook delete [ID]` | Deletes an endpoint. Confirms by default; `--yes` (or `-y`) skips confirmation and is required non-interactively. Only delete endpoints you own or are authorized to remove. |

`get`, `ping` and `delete` offer an interactive picker without an ID; scripts must pass one. List, get and the picker mask URL query values, not paths. Omitting the URL keeps it out of shell history, but the prompt echoes it.

## Python API

All `CloudWebhooks` methods are async. Register only when authorized to create an endpoint:

```python
from mobilerun.core.webhooks import DEFAULT_WEBHOOK_EVENT, CloudWebhooks, WebhookEndpoint


async def get_or_register_results(url: str, creation_key: str) -> WebhookEndpoint:
    hooks = CloudWebhooks(billing="no_commerce")
    existing = await hooks.find_by_url(url)
    if existing is not None:
        accepts_results = (
            not existing.event_types or DEFAULT_WEBHOOK_EVENT in existing.event_types
        )
        usable = existing.state == "ACTIVE" and existing.health != "blocked"
        if not (usable and accepts_results):
            raise RuntimeError("Existing webhook is incompatible with flow results")
        return existing
    return await hooks.register(
        url, event_types=[DEFAULT_WEBHOOK_EVENT], idempotency_key=creation_key
    )
```

Call with `await get_or_register_results(...)` from async code. Use `endpoint.id` in the declaration. If `endpoint.secret` is not `None`, store `endpoint.secret.get_secret_value()` securely; an idempotent replay does not reveal it again. The `event_types` filter is required: `DEFAULT_WEBHOOK_EVENT` is `workflow.step.emit`; `[]` subscribes to **all** deliverable events.

`register` accepts an optional idempotency key. Generate a new key per creation attempt and reuse it only to retry that attempt with the same request body. Use a new key to intentionally recreate an endpoint after deletion; replaying the old key returns HTTP 404.

- `await hooks.list()` returns all pages, including non-HTTP destinations; `await hooks.get(endpoint_id)` returns endpoint metadata.
- `await hooks.find_by_url(url)` can return a disabled, blocked, or differently subscribed endpoint. Before reuse, confirm it is `ACTIVE`, not blocked, and subscribed to `workflow.step.emit` or all events. Report an incompatible match without mutating it. A match does not grant ownership. Unlike CLI registration, Python `register` does not reuse a match automatically.
- `await hooks.ping(endpoint_id)` returns `(success, http_status)`; the status can be `None`. A successful ping proves test connectivity, not eligibility to receive flow results. `await hooks.delete(endpoint_id)` deletes by UUID.
- `validate_webhook_url(url)` is synchronous: it returns the normalized HTTPS URL without network I/O or raises `CloudValidationError` for invalid input.

## Payload and verification

After a successful function step, the flow queues an HTTP POST. Relevant JSON fields (the envelope can include other metadata):

```json
{"type": "workflow.step.emit", "data": {"result": {"count": 3}}}
```

`data.result` is the serialized return value. If the function declares `files`, the flow uploads them first and replaces each configured base64 image in the payload with an object containing `path` and `fileId`. Failed functions do not emit a result.

Before parsing JSON, verify `x-mobilerun-signature` (`sha256=<hex>`). Use the endpoint's signing secret as the HMAC-SHA256 key and sign the exact `x-mobilerun-timestamp` header bytes, a literal `.` and the unmodified request body bytes (backend signing contract). Compare in constant time. Reject missing or malformed headers and timestamps more than about five minutes from the current time; the timestamp is Unix milliseconds. Do not reserialize JSON to verify it. Bearer auth is not supported.

Use `x-mobilerun-event-id` as the deduplication key before processing retries. Deliveries also include `x-mobilerun-event-type`, `x-mobilerun-delivery-id` and `x-mobilerun-source`.

## Common mistakes

- Passing a URL or leaving out the name: use `@cloud("name", webhook="ENDPOINT_ID")` with the registered UUID.
- Treating the signing secret as a bearer token: use it only to verify the HMAC.
- Treating flow success as confirmed delivery: a succeeded webhook step only confirms queuing. Check receiver logs or delivery history for the actual event; ping only verifies a separate test delivery.
