# Cloud resources, vault and billing

## Vault references in cloud tasks

Full provider, CRUD, binding, CLI and security reference: [credentials](credentials.md).

The package and name are stored vault identifiers; a website domain does not determine either. Look up the exact stored values and pass them as configuration. Create the vault credential ahead of time, e.g. via `mobilerun credentials save --help` or `CloudCredentials.save(package, name, fields)`; saving changes the vault. `list(package)` returns metadata, not values. The following uses an existing vault entry and existing cloud phone. A cloud task consumes credits; no purchase is implied by binding. The provider sends references for **all package-bound credentials visible in the bound vault**, not just the one inspected below. The instruction identifies which credential to use; this is not an API-side filter.

```python
from pydantic import BaseModel

from mobilerun import CloudDevice
from mobilerun.core.credentials import CloudCredentials


class AccountStatus(BaseModel):
    signed_in: bool


async def use_vault(package: str, name: str, device_id: str | None) -> bool:
    if not isinstance(device_id, str) or not device_id.strip():
        raise ValueError("An existing cloud device ID is required")
    if not package.strip() or not name.strip():
        raise ValueError("Stored vault package and credential name are required")
    vault = CloudCredentials(billing="included")
    try:
        entries = await vault.list(package)
        if not any(entry["name"] == name for entry in entries):
            raise ValueError("Expected vault credential not found")
        async with CloudDevice(device_id=device_id.strip(), billing="included") as phone:
            await vault.bind(phone)
            try:
                result = await phone.do(
                    f"Sign in to {package} using credential {name} and report status",
                    output=AccountStatus,
                )
                if not result.success or result.output is None:
                    raise RuntimeError("Cloud task did not return account status")
                return result.output.signed_in
            finally:
                await vault.unbind()
    finally:
        await vault.close()
```

See [structured output](operators-and-macros.md#execute-instructions) for the result contract. Cloud task transport sends vault package/name references, never local secret values. A local provider is rejected by cloud task execution. For direct secret input, focus an editable field first, bind the provider and call `await vault.type_field("com.example.app", "password", name="work")`; the provider types without returning the secret. Focus and editability must be observable. Closing the provider closes its client, not the stored credential; deletion is explicit.

## Number and mailbox

Creation without an ID may spend money; an existing ID is borrowed. A context closes the resource; created resources are released unless `keep=True`, existing IDs are not released automatically. Number binding changes server association and requires a telephony-capable cloud phone, but binding an existing number is not a purchase. Mailbox binding is a local association and also works with local typing devices.

```python
from mobilerun.core.mailbox import CloudMailbox
from mobilerun.core.phone_number import CloudPhoneNumber


async def get_codes() -> tuple[str, str]:
    async with CloudPhoneNumber(
        number_id="existing-number-id", billing="no_commerce"
    ) as number:
        sms = await number.wait_for_code(sender="Example", timeout=60)
    async with CloudMailbox(
        mailbox_id="existing-mailbox-id", billing="no_commerce"
    ) as mailbox:
        email_code = await mailbox.wait_for_code(timeout=60)
    return sms, email_code
```

Use `await number.bind(phone)` / `await number.unbind()` or `await mailbox.bind(device)` / `await mailbox.unbind()`. Enter received codes with `await device.input_text(code)`. Binding defaults to `close_on_device_close=False`: closing the phone unbinds the number but does not release it, even if the phone is owned. Close the number separately, e.g. with its own context as above, or use `finally: await number.close()`. Alternatively, `await number.bind(phone, close_on_device_close=True)` makes phone cleanup close the bound number. Its own `keep=True` retains an owned number; the phone’s `keep` does not control number release.

### Rent a number and use SMS

**Paid operation:** `plan="rent"` with `billing="paid"` rents a number. SMS sending may incur additional charges even though the Python client permits `no_commerce` for sends; the CLI requires `paid` and confirmation. Obtain approval first. This pattern closes an owned number even if initialization fails; it deliberately releases a pending checkout rather than resuming it. See [payments](payments.md) to keep a pending purchase for resumption.

```python
import sys

from mobilerun.core.phone_number import CloudPhoneNumber


async def rent_and_send(country: str, destination: str) -> int:
    number = CloudPhoneNumber(country=country, plan="rent", billing="paid")
    try:
        await number
        await number.wait_ready()
        await number.send(destination, "Example message")
        messages = await number.messages()
        return len(messages)
    finally:
        original = sys.exception()
        try:
            await number.close()
        except Exception as cleanup_error:
            if original is None:
                raise
            original.add_note(f"Number cleanup failed: {cleanup_error}")
```

`messages(after=None)` returns inbound `MessageItem` records; `send(to, text)` returns a send response. Message bodies and phone numbers may be sensitive; do not log them. Number creation and readiness are separate; `wait_ready()` polls provisioning. A number ID retrieves an existing resource, whereas no ID creates one. `keep=True` retains owned numbers; do not release borrowed IDs. The number interface exposes SMS, not a voice-call method. Device call actions, if a backend exposes them, are separate.

Interactive `mobilerun number create` without `--country` shows in-stock countries and their remaining included quota (a snapshot, not a reservation). Pass `--country` explicitly to select it in automation. `mobilerun number included --json` returns an array of `{country, remaining}` rows for all supported countries (`null` if a count is unavailable); adding `--country US` returns one object. A `not_cancellable` conflict on `number release` means: “This number can't be released: only unpaid pending purchases and active rented numbers can be cancelled.” Do not retry blindly.

### Mailbox limits

`CloudMailbox.list()` lists mailbox resources, not inbox messages. To read received email summaries, use `mobilerun mailbox messages MAILBOX --json` or the low-level `mailboxes.messages` helper below, not `CloudMailbox.messages()`. Summaries include sender, subject, preview and OTP availability, not the OTP value. Use `wait_for_code(sender=...)` for filtered code polling. Treat summaries as sensitive. Creating a mailbox may incur charges; existing IDs are borrowed.

### Resource inventory and controls

All operations below access cloud. `release()` is destructive, including on borrowed handles: only call it for resources whose release is authorized. Closing a borrowed handle does not release it.

| API | Contract |
| --- | --- |
| `await CloudPhoneNumber.list(billing=...)` / `await CloudMailbox.list(billing=...)` | Lists of borrowed handles populated with available metadata; close handles after use. |
| `await CloudPhoneNumber.included_available(country, billing=...)` / `await CloudMailbox.included_available(billing=...)` | Integer remaining included capacity snapshot, not a reservation. |
| `number.id`, `mailbox.id` | Existing supplied IDs are available immediately; new IDs raise until assigned during initialization. |
| `number.phone_number`, `mailbox.address` | Optional strings populated by initialization or list; check for `None`. |
| `number.device_id` | Last loaded remote phone association, or `None`; distinct from the local extension binding. |
| `await number.release()` / `await mailbox.release()` | Unbinds then deletes the remote resource regardless of whether the handle was borrowed or kept. |

Constructors accept ID, `billing`, `plan`, `label`, `keep`, `on_checkout`, `checkout`, `payment_timeout`, extension `name`, and connection options `client`, `api_key`, `base_url`. Number additionally accepts `country`; mailbox accepts `ready_timeout=60`. Number `wait_ready(timeout=...)` separately waits for provisioning. Omitted/`None` ID creates; an empty string is invalid. IDs from outside your process should be checked for whitespace before attachment. A number that resumed an existing pending purchase has `resumed_existing=True` and is borrowed; see [payments](payments.md).

### Low-level number and mailbox operations

Import modules from `mobilerun.clients.cloud`. Calls require keyword `billing=Billing.NO_COMMERCE` or higher; creation requires `INCLUDED`, or `PAID` for rent. They accept `client=AsyncMobilerun` or `api_key`/`base_url`; caller-owned clients must be closed by the caller. Return types are SDK models, not extension handles. Create can trigger checkout and charges; delete is destructive; SMS may incur charges.

| Module | Async functions and results |
| --- | --- |
| `numbers` | `create(plan=..., country=..., label=..., billing=...)` → `NumberCreateResponse`; `list_numbers(billing=...)` → `list[NumberItem]`; `retrieve(number_id, billing=...)` → `NumberRetrieveResponse`; `delete(number_id, billing=...)` → `NumberDeleteResponse`. |
| `numbers` | `countries(billing=...)` → `NumberCountriesResponse`; `capacity(country, billing=...)` → `NumberCapacityResponse`; `messages(number_id, after=..., billing=...)` → `list[MessageItem]`; `send(number_id, to, text, billing=...)` → `MessageSendResponse`. |
| `mailboxes` | `create(plan=..., label=..., billing=...)` → `MailboxCreateResponse`; `list_mailboxes(billing=...)` → `list[Item]`; `retrieve(mailbox_id, billing=...)` → `MailboxRetrieveResponse`; `delete(mailbox_id, billing=...)` → `MailboxDeleteResponse`. |
| `mailboxes` | `capacity(billing=...)` → `MailboxCapacityResponse`; `otp(mailbox_id, billing=..., **params)` → `MailboxOtpResponse` or `None`; `messages(mailbox_id, billing=...)` → `list[MessageItem]` across all pages. |

Creation supports `keep`, checkout callback/mode and `payment_timeout`; see [payments](payments.md). Direct low-level deletion and creation do not provide the extension's ownership lifecycle.

### SMS OTP on an existing number

An existing number must be initialized by awaiting it or entering its context. `number.phone_number` is `str | None`, so check it before use. `wait_for_code(*, sender=None, timeout=60, after=None)` returns a string. When provided, `sender` is matched case-insensitively as a substring of the detected sender or peer number. Capture a UTC timestamp **before** requesting delivery, then pass it as `after`. The example borrows a number and phone, performs a cloud task and can consume task credits; obtain authorization first.

```python
from datetime import datetime, timezone

from pydantic import BaseModel

from mobilerun import CloudDevice
from mobilerun.core.phone_number import CloudPhoneNumber
from mobilerun.models.results import ExecutionResult


async def receive_sms(number_id: str, device_id: str, sender: str) -> str:
    if not number_id.strip() or not device_id.strip():
        raise ValueError("Existing number and device IDs are required")
    async with CloudPhoneNumber(
        number_id=number_id.strip(), billing="no_commerce"
    ) as number:
        phone_number = number.phone_number
        if not phone_number:
            raise RuntimeError("Number is not available")
        async with CloudDevice(
            device_id=device_id.strip(), billing="included"
        ) as device:
            after = datetime.now(timezone.utc)
            result: ExecutionResult[BaseModel] = await device.do(
                f"Enter {phone_number} and request the SMS verification code"
            )
            if not result.success:
                raise RuntimeError("SMS request task failed")
            return await number.wait_for_code(sender=sender, timeout=60, after=after)
```

Both IDs are borrowed; context exit closes local handles without releasing the existing number or terminating the phone. Pass a nonblank known `device_id`; validate external IDs before constructing a `CloudDevice` as shown in [attachment-only safety](python-api.md#attach-to-an-existing-cloud-device-only).

### Cloud task with mailbox OTP

Creating a mailbox uses included quota; tasks consume credits. A `CloudMailbox` is a **local extension**, and binding it while a cloud task runs makes `CloudTaskOperator` reject the task. Await it to initialize; constructing or binding alone does not provision it. Construct before the `try` so cleanup also runs if initialization fails. Keep it unbound, pass its address in the task, and retrieve the code in Python. Capture UTC time before the task triggers delivery to exclude old messages.

```python
import sys
from datetime import datetime, timezone

from pydantic import BaseModel

from mobilerun import CloudDevice
from mobilerun.core.mailbox import CloudMailbox
from mobilerun.models.results import ExecutionResult


class SignupStatus(BaseModel):
    verified: bool


async def complete_signup(device_id: str) -> bool:
    if not device_id.strip():
        raise ValueError("An existing cloud device ID is required")
    mailbox = CloudMailbox(plan="included", billing="included")
    try:
        await mailbox
        address = mailbox.address
        if not address:
            raise RuntimeError("Mailbox address unavailable")
        async with CloudDevice(
            device_id=device_id.strip(), billing="included"
        ) as phone:
            after = datetime.now(timezone.utc)
            result: ExecutionResult[BaseModel] = await phone.do(
                f"Enter {address} and request the verification email"
            )
            if not result.success:
                raise RuntimeError("Verification email was not requested")
            code = await mailbox.wait_for_code(after=after, timeout=60)
            if not await phone.input_text(code):
                raise RuntimeError("Could not enter verification code")
            confirmation = await phone.do(
                "Submit the entered verification code and report whether signup is verified",
                output=SignupStatus,
            )
            if not confirmation.success or confirmation.output is None:
                raise RuntimeError("Verification task did not return a result")
            return confirmation.output.verified
    finally:
        original = sys.exception()
        try:
            await mailbox.close()
        except Exception as cleanup_error:
            if original is None:
                raise
            original.add_note(f"Mailbox cleanup failed: {cleanup_error}")
```

`input_text` returns whether typing succeeded. `ExecutionResult.success` reports task execution success; only the returned `SignupStatus.verified` reports business success. A successful task can still return `verified=False`. This `finally` closes the created mailbox even when initialization fails; `keep=True` retains it. If initialization raised `PaymentRequired`, closing an owned pending mailbox releases it: omit that cleanup only when intentionally retaining the pending purchase for resumption, and manage its lifecycle explicitly. It closes but does not terminate the borrowed phone. Real tasks and mailbox creation require authorization; this example is not free of resource or credit use.


### Creation and failed initialization

An `async with` calls `__aexit__` only after `__aenter__` succeeds. For newly created mailboxes **and numbers**, construct first and cover `await resource` with `try`/`finally` as above; cleanup can release an owned resource that exists before readiness fails. Preserve the original error if cleanup fails. `keep=True` intentionally retains an owned resource. No example here creates a new number in an `async with`.

New cloud phones follow a different path: their `connect()` attempts to terminate an owned, non-kept phone when readiness or capability checks fail. Cleanup itself can fail, and failures before an ID is received may require checking the service. Retain the handle and arrange explicit cleanup and reconciliation where appropriate; never terminate a borrowed ID. No example here creates a new cloud phone in an `async with`.

## Proxies and checkout

See [proxies](proxies.md) for setup, replacement, costs and cleanup, and [payments](payments.md) for checkout and resumption.

## Billing decisions

| Operation | Minimum billing | Notes |
| --- | --- | --- |
| Read an existing resource | `no_commerce` | Read/attach does not purchase; operations may still access cloud services. |
| Cloud task via `CloudDevice.do()` or `expect()` | `included` | Consumes task credits; cloud device/task billing governs the operator. |
| Create a number or mailbox with `plan="included"` | `included` | Uses included quota; no paid fallback. |
| Create a number or mailbox with `plan="rent"` | `paid` | Rental is a paid purchase. |

Billing is set per resource, not inherited from another resource: the SMS example uses `no_commerce` for the existing number and `included` for the phone's task. Phone creation has separate plan/proxy guards.

Resource constructors snapshot `MOBILERUN_BILLING`, default `paid`; explicit `billing=` wins. Client functions require keyword-only `billing`. Modes ascend `no_commerce < included < paid` and guards fail before transport. `no_commerce` allows login, reads, binding existing numbers/proxies and many writes/deletes; it blocks new phones, numbers and mailboxes and purchases. It is **not** a destructive-action or zero-usage-cost guard. `included` permits included resource creation and cloud tasks, which consume task credits; it does not allow paid rotating-country proxy purchases or phone `auto`/`minute` plans. `paid` allows purchases and paid fallback. Existing phone IDs are not purchases. Cloud phone creation has plan/proxy-specific minimums; numbers and mailboxes support `plan="included"`, `"auto"`, or `"rent"`. Check current prices and get approval before paid actions.

Import enum members from `mobilerun.models.billing`: `Billing.NO_COMMERCE`, `Billing.INCLUDED`, `Billing.PAID`; `ResourcePlan.AUTO`, `ResourcePlan.INCLUDED`, `ResourcePlan.RENT`; `Plan.AUTO`, `Plan.MINUTE`, `Plan.SUBSCRIPTION`. For number/mailbox allocation, omitted plan means `AUTO`: under included billing it requests included-only, under paid billing it can fall back to rent. `INCLUDED` never falls back; `RENT` requires paid. Cloud phone `Plan.AUTO` prefers subscription then minutes; `MINUTE` uses minutes only and `SUBSCRIPTION` never falls back. Its omitted plan defaults to subscription with included billing, auto with paid billing.
