---
name: mobilerun-framework
description: Use when writing Python against mobilerun, using its CLI, controlling local or cloud devices, recording macros, adding framework features, or migrating droidrun imports.
---

# Mobilerun framework

Mobilerun is a Python framework for mobile device control, deterministic macros, sandbox cloud functions and coding-agent integration. LLM execution is in the separate `mobilerun-agents` package. A device performs actions and exposes cached state snapshots; a state provider fetches observations. An operator executes instructions against the device. Independently owned credentials, numbers, mailboxes and proxies bind as extensions. Recording wrappers capture actions for guarded macro replay.

## Architecture

Shared `models`, `core`, `clients`, `config`, `utils`, `errors` and `logs` support independent `macro`, `sandbox` and `skills` features. Shared packages must not import features; features must not import each other or agents. The root CLI registers features. Cloud SDK calls belong in `clients/cloud`. See the reference links below for boundaries and package roles.

## Install

Python 3.11–3.13: `pip install mobilerun`. Sandbox APIs require `pip install 'mobilerun[sandbox]'`. Development extra: `pip install 'mobilerun[dev]'`. For LLM operators and agent commands, install both local checkouts together: `uv pip install --python <venv>/bin/python -e <mobilerun> -e <mobilerun-agents checkout>`. This resolves both editable distributions in the same environment and prevents dependency resolution from replacing the local framework; LLM use can consume tokens. The base package defines no agent extra.

## Python quick start

Run within an async program. Local Android needs ADB and a connected phone or emulator. The cloud example **uses an existing cloud phone; cloud usage can incur charges**. Substitute its ID and configure credentials; never embed a key.

```python
import asyncio

from mobilerun import AndroidDevice, CloudDevice


async def main() -> None:
    async with AndroidDevice("emulator-5554") as phone:
        await phone.tap(200, 400)
        await phone.input_text("hello")
        await phone.wait(1)
        print((await phone.state.refresh()).formatted_text)

    async with CloudDevice(device_id="existing-device-id") as phone:
        await phone.tap(200, 400)
        print(len(await phone.screenshot()))


asyncio.run(main())
```

Context exit closes the handle. Existing cloud IDs are not automatically terminated; omitting an ID creates a phone and can incur charges. See the references below.

## CLI quick reference

| Task | Command |
| --- | --- |
| Find or select a device | `mobilerun device list`; `mobilerun device connect DEVICE` |
| Tap | `mobilerun device input tap 200 200 emulator-5554` |
| Inspect screen | `mobilerun device screen ui --help` |
| Replay a macro | `mobilerun macro replay macro.json emulator-5554` |
| Find the macro directory | `mobilerun macro path --json` |
| Inspect sandbox deployments | `mobilerun sandbox list --billing no_commerce` |
| Send function results to my server | `mobilerun webhook register`, then set `@cloud("name", webhook="ENDPOINT_ID")`; see [webhooks](references/webhooks.md) |
| Discover skills | `mobilerun skills list` |
| Manage MCP connection | `mobilerun mcp --help` |
| Cloud authentication | `mobilerun account --help` |

Cloud resources and tasks can cost money; agent execution can consume LLM tokens. For all base commands and flags, see the CLI reference below or run `mobilerun COMMAND --help`. Explicit device selection wins over a saved default, then discovery.

## Key concepts

- `Device` is the common interface. `supported_operations` and `supported_buttons` describe backend support. An exposed method may still raise `DeviceOperationNotSupported`.
- Use `await device.wait(seconds)`, not `asyncio.sleep()`, in device flows. `RecordingDevice` records waits; macro replay preserves them.
- `RecordingDevice` captures actions; `MacroPlayer` replays them with state guards. `MacroOperator` offers strict replay. Agent fallback belongs to the optional add-on.
- Resource billing defaults to `paid`; `MOBILERUN_BILLING` sets the default and explicit `billing=` overrides it. `no_commerce` blocks purchases; it is not a general read-only guarantee. Cloud client calls require an explicit billing mode.
- Cloud tasks use vault references via `CloudCredentials`, never local secret values. Bind providers from the resource side with `await provider.bind(device)`.
- Put configurable constants and environment-backed tunables in the relevant `settings.py`; keep settings declarative.

## Common mistakes

- Assuming every device supports every action. Check capabilities and handle unsupported operations.
- Assuming an existing cloud device is owned by your context. Close the handle; do not terminate a borrowed resource.
- Calling `asyncio.sleep()` during a recording, or reading snapshot fields directly from the state controller. Use `device.wait()` and `await device.state.refresh()`.
- Passing local credentials to cloud tasks, or assuming `no_commerce` protects against all destructive operations.
- Assuming `@cloud` deploys on import. Ordinary calls run locally; deploy, fire and enable can incur charges even without a phone.
- Passing a URL to `@cloud` or omitting the name. Use `@cloud("name", webhook="ENDPOINT_ID")` with the registered endpoint UUID.
- Importing agents from shared framework packages.

## Contracts agents get wrong

- [State](references/python-api.md#inspect-state): elements are nested dictionaries; filters are objects; coordinates are a pair.
- [Device operations](references/device-operations.md): methods do not guarantee backend support; check `supported_operations`. Swipe duration is milliseconds; drag duration is seconds.
- [Resources](references/resources-and-billing.md): binding borrows by default; `close_on_device_close=True` changes cleanup ownership.
- [Credentials](references/credentials.md): providers are not awaitable; close them in `finally`. `type_field` returns `None`, never the value. Cloud tasks reject local providers and send references for all package-bound vault credentials.
- [Mailbox](references/resources-and-billing.md#cloud-task-with-mailbox-otp): initialize it and keep it unbound during cloud tasks.
- [Macros](references/operators-and-macros.md#record-and-replay-a-macro): capture guards and reset the initial screen before replay.
- [Device CLI](references/contributing.md#device-aware-cli-skeleton): use `DeviceTarget` and its selector, not direct Android construction.
- [Billing](references/resources-and-billing.md#billing-decisions): cloud tasks require at least `included`; SMS sending may cost money even in `no_commerce`.
- [Checkout](references/payments.md): `PaymentRequired` can be resumed; closing an owned pending resource may release it.
- [Cloud IDs](references/python-api.md#attach-to-an-existing-cloud-device-only): validate IDs before attachment.
- [OTP](references/resources-and-billing.md#sms-otp-on-an-existing-number): capture a pre-request UTC timestamp and pass `after=` for SMS and mailbox.
- [Foreground state](references/python-api.md#inspect-state): read `phone_state`; no portable element clickability flag exists.
- [Failed initialization](references/resources-and-billing.md#creation-and-failed-initialization): close created resources even if initialization raises.

## Before you hand back code

- Run Ruff (including B905), mypy and Black on the change and its examples.
- Check wrapper exit does not close a device before its last use.
- Check resource ownership and cleanup, including failure paths.
- Validate cloud IDs before constructing `CloudDevice`; count all recorded actions, including waits, when attaching guards.
- Use `await device.wait(...)` in recorded device flows, not `asyncio.sleep(...)`.

## References

- [Architecture](references/architecture.md) — Read when: tracing package layers, boundaries and add-on responsibilities.
- [Devices and state](references/python-api.md) — Read when: connecting devices, inspecting state, using pools or managing apps and files.
- [Device operations](references/device-operations.md) — Read when: changing device settings, gestures, screenshots, apps, files or checking backend limits.
- [Operators and macros](references/operators-and-macros.md) — Read when: executing instructions, recording actions or replaying guarded macros.
- [Sandbox cloud functions](references/sandbox.md) — Read when: deploying `@cloud` endpoints or schedules, invoking remotely, inspecting runs or managing owned flows.
- [Webhooks](references/webhooks.md) — Read when: sending sandbox results to a server, managing webhook endpoints or verifying signed deliveries.
- [Resources and billing](references/resources-and-billing.md) — Read when: using cloud vaults, numbers, mailboxes or billing guards.
- [Proxies](references/proxies.md) — Read when: creating, binding or switching cloud and local proxies.
- [Payments](references/payments.md) — Read when: handling checkout, payment approval or pending-resource cleanup.
- [Credentials and vaults](references/credentials.md) — Read when: saving, listing or deleting credentials, binding providers, typing secrets or using vault references in cloud tasks.
- [Errors and configuration](references/errors-and-config.md) — Read when: handling exceptions, environment precedence or shared models.
- [CLI command index](references/cli.md) — Read when: choosing CLI commands, arguments and cost or destructive-action safeguards.
- [Contributing and migration](references/contributing.md) — Read when: adding a feature or CLI, running checks or migrating droidrun imports.
