# Operators and macros

## Execute instructions

A device executes actions; an operator implements task execution. `device.do(instruction, *, output=None, max_steps=None, operator=None, timeout=None)` returns `ExecutionResult[T]` with `success`, `answer`, `output`, `steps`, `task_id`, `trajectory_path`, and `device`. `device.expect(condition, *, operator=None, timeout=None)` returns `ExpectationResult` with `passed`, `condition`, `reason`, and the underlying `task`. `output` is a Pydantic model class; `result.output` is an instance or `None`. The chosen operator must support that operation.

Cloud tasks can consume credits. This example borrows an existing phone and does not terminate it. Install credentials first through the vault when the task needs secrets.

```python
from pydantic import BaseModel

from mobilerun import CloudDevice


class Screen(BaseModel):
    description: str


async def describe() -> None:
    async with CloudDevice(device_id="existing-id", billing="included") as phone:
        result = await phone.do(
            "Describe the screen", output=Screen, max_steps=5, timeout=120
        )
        print(result.success, result.output)
        verdict = await phone.expect("Settings is visible", timeout=120)
        print(verdict.passed, verdict.reason)
```

`CloudDevice` defaults to `CloudTaskOperator`, which requires a cloud device and rejects local extensions. Supply `operator=` at construction or override per call. The separate `mobilerun-agents` package provides `AgentOperator` for LLM execution and `AgentMacroOperator` for agent fallback; using these may consume LLM tokens. For strict replay use `MacroOperator(macro_file="macro.json", state_timeout=10)` as the constructor or per-call operator. Strict replay rejects structured `output`; if `macro_file` is omitted, the instruction is interpreted as the file path. It does not provide LLM fallback. See the add-on's own docs for its configuration.

## Record and replay a macro

Record on a local emulator and replay on that device; actions change the device. Waits must use `device.wait()`, not `asyncio.sleep()`, so they are recorded. Secret actions store references, not secret values; bind the appropriate provider before replay.

```python
import json
from pathlib import Path
from typing import Any

from mobilerun import AndroidDevice, RecordingDevice
from mobilerun.macro import MacroPlayer
from mobilerun.macro.errors import MacroError, MacroMismatch
from mobilerun.macro.models import MACRO_SCHEMA_VERSION, build_screen_snapshot


async def record(serial: str, path: Path) -> None:
    device = AndroidDevice(serial)
    async with RecordingDevice(device) as phone:
        before_start = build_screen_snapshot(await device.state.refresh())
        message = await phone.start_app("com.android.settings")  # Returns str.
        print(message)
        before_input = build_screen_snapshot(await device.state.refresh())
        if not await phone.input_text("wifi"):  # False means stop dependent work.
            raise RuntimeError("Text input failed; macro not saved")
        # Independent dictionaries can hold the optional pre_state key.
        actions: list[dict[str, Any]] = [
            dict(action) for action in phone.recorded_actions
        ]
        actions[0]["pre_state"] = before_start
        actions[1]["pre_state"] = before_input
        path.write_text(
            json.dumps(
                {"macro_schema_version": MACRO_SCHEMA_VERSION, "actions": actions}
            )
        )


async def replay(serial: str, path: Path) -> bool:
    # The caller MUST reset the emulator to the initial recorded screen first.
    async with AndroidDevice(serial) as phone:
        player = MacroPlayer(phone, state_timeout=10, state_threshold=0.8)
        try:
            return await player.replay_macro(player.load_macro_from_file(path))
        except MacroMismatch:
            print("State diverged:", player.last_divergence)
            raise
        except MacroError:
            print("Macro could not be replayed")
            raise
```

Run `await record("emulator-5554", Path("macro.json"))`, then manually reset the emulator to the exact initial state captured before recording. Only then call `await replay("emulator-5554", Path("macro.json"))`. These are separate phases: `record` exits the recorder context and closes its wrapped device; `replay` constructs a fresh device handle. Never reuse the closed handle, even if an outer device context is still open. Replaying on the final recorded screen can fail its first guard. Unsupported actions raise `DeviceOperationNotSupported`; let it abort rather than continuing dependent steps. `start_app` returns a backend message, not a success boolean; `input_text` returns a boolean.

Replay compares an action's `pre_state` when present; a mismatch raises `MacroMismatch` and populates `last_divergence`. Recording alone does not capture `pre_state`: the example explicitly adds snapshots before both actions. Capture and attach a snapshot before each action that needs a guard. Reset the device to that expected state before replay. An unsupported schema or invalid action raises `MacroError`; framework exceptions from the backend propagate unchanged, while other action exceptions are wrapped in `MacroError`. Replay discards the boolean from `input_text`: even `False` is reported as a successful action. Check input separately where correctness matters; replay success alone does not prove text was entered. `start_from_step` and `max_steps` restrict replay. Strict replay does not silently invoke an agent. CLI replay with `--on-mismatch agent` hands off through the `agent_macro` operator entry point; this can consume LLM tokens. The CLI has `mobilerun macro list` and `mobilerun macro replay FILE [DEVICE]`; there is no `macro record` command. Record with Python as above.

## Discover and invoke extensions

`device.extensions` maps registered names to bound extensions. `device.actions.list()` returns `Action` metadata including name, owner, schemas and whether a device is required; `device.actions.get(name)` selects one. Invoke dynamically with `await device.actions.call(name, {"argument": "value"})`. Arguments and results are validated. `await device.context()` returns public context. Keep the original typed extension handle for direct calls; there is no typed `Device.get` API.

An extension binds with `await extension.bind(device)`; by default closing the device unbinds but does not close the extension. Pass `close_on_device_close=True` to transfer cleanup. `force=True` unbinds exclusive conflicts but does not close them. `@action` permits standalone calls; `@device_action` requires binding and injects the device. Do not expose secret values through action results or context. Cloud tasks reject bound extensions not marked `cloud_native`; vault references are supported, local secret providers are not.

## Replay options and format

`MacroPlayer(device, delay_between_actions=None, state_timeout=None, state_threshold=None, state_poll_interval=None)` takes explicit options in seconds except the similarity threshold. `None` uses macro settings: delay 1.0, timeout 5.0, threshold 0.85, poll interval 0.5. `load_macro_from_file(path)` accepts a JSON file or folder containing `macro.json`; `load_macro_from_folder(folder)` loads the same format. The document has `macro_schema_version` equal to `MACRO_SCHEMA_VERSION` (`"2.0"`) and an `actions` list. Each optional `pre_state` comes from `build_screen_snapshot`, which normalizes screen dimensions, phone state and nodes. `replay_macro(data, start_from_step=0, max_steps=None)` replays a range. `get_current_state_snapshot()` inspects the current state; `wait_for_pre_state` and `replay_action` are lower-level replay primitives. `MacroRecorder` is separate from `RecordingDevice`: it enriches supplied action dictionaries with snapshots and timing; the wrapper appends raw action dictionaries. Use the wrapper to capture calls and the recorder when explicitly building enriched entries. `replay_macro_file` and `replay_macro_folder` are also exported from `mobilerun.macro`.


## Expectation failures and custom operators

`expect()` returns only a passing verdict: a negative verdict raises `ExpectationFailed`, and a failed task or absent verdict raises `ExpectationInconclusive`. Both are `DeviceError` subclasses; distinguish them from operator or transport failures. Cloud execution consumes task credits.

```python
from mobilerun import Device
from mobilerun.errors import ExpectationFailed, ExpectationInconclusive


async def check_screen(device: Device) -> str:
    try:
        result = await device.expect("Settings is visible")
        return result.reason
    except ExpectationFailed:
        return "Condition was false"
    except ExpectationInconclusive:
        return "No reliable verdict"
```

To implement an operator, subclass `mobilerun.core.operator.Operator`. Override synchronous `check(device) -> None` to reject unsupported pairings, then async `execute(device, instruction, *, output=None, max_steps=None, timeout=None) -> ExecutionResult[T]`; honor or explicitly reject options, validate structured `output`, and respect timeout and ownership. The base `check` is a no-op; base `execute` raises `OperatorNotAvailable`. `device.do` calls the chosen operator; `expect` requests `ExpectationVerdict` as structured output, so a strict macro operator cannot provide it. `CloudTaskOperator(billing=...)` from `mobilerun.core.operator.cloud` snapshots the billing default at construction; `check` rejects non-cloud devices and local extensions and `execute` collects reference-only cloud inputs. `MacroOperator` inherits the no-op check; its zero-based `start_from_step` and `player_options` (`delay_between_actions`, `state_timeout`, `state_threshold`, `state_poll_interval`) pass through to replay. Both operators expose `check` and `execute` directly.

A deterministic operator can reject structured output rather than pretending to produce it. This example performs no device or network I/O:

```python
from typing import TypeVar

from pydantic import BaseModel

from mobilerun import Device
from mobilerun.core.operator import Operator
from mobilerun.models.results import ExecutionResult

T = TypeVar("T", bound=BaseModel)


class EchoOperator(Operator):
    async def execute(
        self,
        device: Device,
        instruction: str,
        *,
        output: type[T] | None = None,
        max_steps: int | None = None,
        timeout: float | None = None,
    ) -> ExecutionResult[T]:
        if output is not None or max_steps is not None or timeout is not None:
            raise ValueError("EchoOperator does not support these options")
        return ExecutionResult[T](
            success=True, answer=instruction, steps=0, device=type(device).__name__
        )
```

## Macro format and low-level replay

`RecordingDevice` implements `ActionRecording.recorded_actions: Sequence[RecordedAction]`. It forwards `identifier`, `platform`, `cloud_id`, `number`, and `mailbox` to the wrapped device. Its inherited `expect` uses the wrapper's selected operator; entering/exiting it closes the wrapped device. Actions are recorded after the underlying call returns, including `input_text(False)`; recording does not prove success. Plain text is recorded verbatim: never use `input_text` for secrets. Secret typing uses a provider reference.

A schema-v2 document has `macro_schema_version: "2.0"`, `actions: [...]`, and optional `description`. Each entry uses `action_type` (`type` is a replay alias), optionally `description` and `pre_state`. Supported action fields:

| Action | Fields |
| --- | --- |
| `tap` | `x`, `y` |
| `swipe` | `start_x`, `start_y`, `end_x`, `end_y`, `duration_ms` |
| `drag` | same coordinates, `duration` in seconds; `duration_ms` is a legacy fallback |
| `input_text` | `text`, `clear` |
| `button_press`, `press_key_code`, `key_press` | `button`, `key_code`, or legacy `keycode`, respectively |
| `start_app`, `stop_app` | `package`; `start_app` also accepts `activity` |
| `open_url`, `wait`, `back` | `url`, `duration` in seconds, or no fields, respectively |
| `type_secret` | `package`, `field`, `name`; `secret` and `secret_id` are legacy name aliases. Bind exactly one appropriate credential provider. |
| `extension_call` | `name` (qualified extension action), `arguments` mapping. The action must be bound, public to operators and not contain sensitive parameters. |

`MacroRecorder()` does not execute actions. `record_action(action, pre_ui=None, post_ui=None)` appends and returns an enriched dictionary; `record_wait(duration, pre_ui=None, post_ui=None)` adds a wait. `actions` contains the accumulated entries. Enrichment adds `pre_state`, `post_state`, `screen`, `recorded_at_ms` and `elapsed_since_previous_ms`; replay guards only `pre_state`. Record state before the action and optionally after it. Snapshot contents can contain sensitive screen text: store and share them carefully.

`MacroPlayer.driver` is the caller-owned device; optional `state_provider` overrides state capture. `executed_steps` resets per replay and counts successful dispatched actions, not verified UI outcomes. `await player.get_current_state_snapshot()` returns a normalized dictionary. `await player.wait_for_pre_state(pre_state, step_number)` returns `(matched, current_state, match_result)`; an absent pre-state yields `(True, None, None)`. `await player.replay_action(action, current_state=None)` dispatches one action and returns bool, without applying its pre-state guard. `MacroMismatch(step_index, remaining_actions, current_state, reason)` exposes these attributes: index is zero-based, unlike the one-based `last_divergence["step"]`; the remaining list starts with the failed action.

`mobilerun.macro.models.normalize_ui_state(state)` and `build_screen_snapshot(state)` normalize state; `node_semantic_key(node)` returns its comparison key. `mobilerun.macro.utils.compare_states(saved, current, threshold)` returns `StateMatchResult(matches, score, reason)`; `configure_macro_logging(debug=False)` configures the macro logger. `await replay_macro_file(path, device, delay_between_actions=None, start_from_step=0, max_steps=None, state_timeout=None, state_threshold=None)` and `replay_macro_folder(folder, ...)` return bool, retain caller ownership and wrap load `OSError`/`ValueError` as `MacroError`. Use `MacroPlayer` for `state_poll_interval` or divergence details.

## Low-level cloud tasks and inputs

**Cloud tasks consume credits and can change a device.** Use only with approval; use `cloud_client` and close its caller-owned client as described in [architecture](architecture.md#low-level-cloud-and-auth). `mobilerun.clients.cloud.tasks` accepts that SDK client and keyword-only `billing`:

| Operation | Contract |
| --- | --- |
| `await run(client, device_id=..., task=..., billing=...)` | Starts task, returns SDK `TaskRunResponse` with `id`; requires `included`. Optional SDK run parameters include `max_steps`, `output_schema`, `credentials`, `vision`, `recording_enabled`, `execution_timeout`. |
| `progress(client, task_id, billing=...)` | Async iterator of raw SSE lines, not parsed task objects. |
| `await status(client, task_id, billing=...)` | SDK status response; terminal statuses include `completed`, `failed`, `cancelled`. |
| `await stop(client, task_id, billing=...)` | Cancels a running task; mutates remote state. Only stop authorized tasks. |
| `await trajectory(client, task_id, billing=...)` | SDK trajectory response; may contain sensitive screen/action data. |
| `await screenshots(client, task_id, billing=..., **request_options)` | SDK screenshot-list response; request options include `timeout`, `extra_headers`, `extra_query`, `extra_body`. Images can be sensitive. |
| `await run_task(client, device_id=..., task=..., billing=..., output=None, max_steps=None, timeout=None, poll_interval=None, on_task_started=None, credentials=None)` | Starts, streams and polls to terminal state, returning `ExecutionResult` including task ID; requires `included`. On timeout, cancellation or other error it attempts to stop the task; cleanup is best effort. |

The other five operations use `no_commerce`, which is not read-only: `stop` still mutates. API/transport failures are mapped where implemented. Treat progress, trajectory and screenshots as sensitive; do not log blindly.

`CloudCredentialReference(package: str, name: str)` identifies an existing vault entry, not its contents. `CloudTaskInputs(credential_references=(reference, ...))` requires a tuple and is the return type of `Extension.cloud_task_inputs()`. `ContextItem(source: str, kind: str, data: Mapping[str, JSONValue])` copies and validates JSON-safe public metadata; never put secrets in it.
