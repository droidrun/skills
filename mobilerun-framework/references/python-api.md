# Devices, state and workspace

## Connect and close

`connect()` is idempotent; awaiting a device, calling `await device.connect()`, and entering its async context all connect. Context exit calls `close()`. Exiting any wrapper context also closes its wrapped device, even inside an outer device context. Do not reuse the wrapped handle after wrapper exit; keep work inside its lifetime or open a fresh device. Use one lifecycle form and clean up in `finally` when not using a context.

```python
from mobilerun import AndroidDevice


async def lifecycle() -> None:
    phone = await AndroidDevice("emulator-5554")
    try:
        await phone.connect()  # Safe to call again.
        await phone.tap(200, 400)
    finally:
        await phone.close()
```

`AndroidDevice(serial)` uses an attached ADB device; `AndroidDevice(avd="Pixel_API_35", headless=True)` starts or reuses an AVD. An instance stops only an emulator it started; `keep=True` retains it. `IOSDevice(url, token=...)` connects to Portal; supply tokens separately, not in URLs. `RemoteDevice(url=...)` defaults to screenshot-only state. Features differ by backend: check `supported_operations` and `supported_buttons`; unavailable operations raise `DeviceOperationNotSupported` from `mobilerun.errors`.

`CloudDevice(device_id="id")` reuses a phone; exiting closes its handle, not the borrowed phone. Without an ID it creates a phone, potentially incurring charges; `keep=True` retains a created phone. Creation options such as `proxy=`, `name=` and `country=` are rejected with an existing ID. See [resources and billing](resources-and-billing.md) before cloud use.

### Attach to an existing cloud device only

Cloud use requires authorization. Validate external IDs before constructing the device: `None` selects creation; blank IDs are invalid attachment inputs, not a way to request creation. This example uses `no_commerce` and does not run tasks; it still connects to a cloud resource and closes its local handle.

```python
from mobilerun import CloudDevice


async def inspect_existing(device_id: str | None) -> int:
    if not isinstance(device_id, str) or not device_id.strip():
        raise ValueError("An existing cloud device ID is required")
    async with CloudDevice(device_id=device_id.strip(), billing="no_commerce") as phone:
        return len(await phone.screenshot())
```

## Inspect state

```python
from typing import Any

from mobilerun import AndroidDevice
from mobilerun.core.state import StateProviderOptions
from mobilerun.core.state.filters import DetailedFilter


def find_text(elements: list[dict[str, Any]], text: str) -> dict[str, Any] | None:
    for element in elements:
        if text.lower() in str(element.get("text") or "").lower():
            return element
        found = find_text(element.get("children") or [], text)
        if found is not None:
            return found
    return None


async def inspect_screen() -> None:
    options = StateProviderOptions(tree_filter=DetailedFilter())
    async with AndroidDevice("emulator-5554", state_options=options) as phone:
        snapshot = await phone.state.refresh()
        element = find_text(snapshot.elements, "Settings")
        if element is not None and element.get("index") is not None:
            x, y = snapshot.get_element_coords(element["index"])
            await phone.tap(x, y)
        assert phone.state.current is snapshot
```

`snapshot.elements` is `list[dict[str, Any]]`; element dictionaries can contain nested `children`, `text`, `index`, and `bounds`. Coordinate lookup returns a two-integer tap point, not bounds; it raises `ValueError` for absent or unbounded elements. `tree_filter` takes a `TreeFilter` object, such as `DetailedFilter()` or `ConciseFilter()`, never a string; `get_filter()` accepts only `"concise"` or `"detailed"`.

`snapshot.phone_state` is a dictionary. Backends may expose `packageName` and/or `currentApp`; either may be absent or empty, so use `snapshot.phone_state.get("packageName") or snapshot.phone_state.get("currentApp") or "unknown"`. Do not infer a portable interactive-element count: normalized element dictionaries have no cross-platform clickability flag. Native iOS state ignores `tree_filter`; iOS Portal HTTP uses the Android-compatible provider and can apply it.

`current` raises `DeviceNotReady` before the first refresh and is a cached snapshot, not live state. `get_clear_point(index)` and `convert_point(...)` are snapshot coordinate helpers. Configure `state_options=StateProviderOptions(...)`, `state_provider=provider`, or `state_provider_factory=factory`; a factory receives `(device, options)` and returns a provider. Instance and factory are mutually exclusive. `vision`, `normalized`, `stealth`, `vision_resize_policy` and `tree_filter` are options. `device.state` exposes `refresh`, `current`, and `capabilities`, not snapshot fields. Close the device after use; refreshing can involve device/network IO.

## Pools, wrappers, apps and files

```python
from mobilerun import AndroidDevice, Device, DevicePool


async def inspect_devices(serials: list[str]) -> None:
    devices: list[Device] = [AndroidDevice(serial) for serial in serials]
    async with DevicePool(devices, concurrency=2) as pool:
        states = await pool.state.refresh()
        images = await pool.screenshot()
        print(
            [
                (state.formatted_text, len(image))
                for state, image in zip(states, images, strict=True)
            ]
        )
```

Pool broadcasts return results in input-device order; `concurrency` limits pool broadcasts, not arbitrary `asyncio.gather` over members. Use pool methods as above for bounded per-device work. For different operations per member, iterate sequentially or use your own semaphore. Pool entry is all-or-fail: it connects members and cleans them up if any entry fails; exit closes members. A broadcast raises an exception group if any member fails. Pool calls can affect all members, including cloud billing. `StealthDevice(device)` humanizes swipes and splits text into words with randomized pauses; closing the wrapper closes its inner device. `RecordingDevice` wraps and records actions; see [operators and macros](operators-and-macros.md).


For independent outcomes when one connection fails, avoid pool entry. This example bounds the *whole lifecycle* of each device and closes even after a failed connect. It returns one error or screenshot per input, in order. This helper creates no cloud resources itself. Supplied cloud devices still perform cloud operations and require authorization.

```python
import asyncio

from mobilerun import Device


async def screenshots_independently(
    devices: list[Device], limit: int = 2
) -> list[bytes | Exception]:
    if limit < 1:
        raise ValueError("limit must be positive")
    semaphore = asyncio.Semaphore(limit)

    async def capture(device: Device) -> bytes | Exception:
        async with semaphore:
            try:
                try:
                    await device.connect()
                    return await device.screenshot()
                finally:
                    await device.close()
            except Exception as error:
                return error

    return list(await asyncio.gather(*(capture(device) for device in devices)))
```

`Workspace` manages cloud account-wide uploaded app/file objects; `device` manages installed apps and device files. Uploading or deleting workspace objects mutates cloud storage; installing, uninstalling and pushing files mutate the device. Do not delete borrowed objects.

```python
from mobilerun import CloudDevice, Workspace


async def install_existing_app(device: CloudDevice) -> None:
    app = await Workspace.get_app("app-id")
    await device.install_app(app)
    await device.start_app(app.package)
```

This workspace-only `App` has no local APK path and cannot be installed on local Android. For local Android use `await device.install_apk("app.apk", reinstall=True)` or an `App` with a local path; for workspace assets use `Workspace.upload_app`, `Workspace.upload_file`, and `Workspace.push_file`. Per-device methods include `list_apps`, `uninstall_app`, `push_file`, `list_files` and `pull_file`; not all backends support all methods. `Workspace` defaults to `no_commerce`, which is not a read-only mode.

`await device.screenshot()` returns PNG `bytes`; `await device.list_apps(include_system=False)` returns `list[dict[str, str]]`. These can perform device IO; do not assume installed-app entries are objects.

For settings, gestures, app and file recipes and backend limits, see [device operations](device-operations.md).

### State options and coordinate contract

`StateProviderOptions(vision=False, normalized=False, stealth=False, vision_resize_policy=None, tree_filter=None)` configures built-in providers. Android uses `ConciseFilter` by default in vision mode and `DetailedFilter` otherwise, then `IndexedFormatter`; a supplied filter overrides that choice. The native iOS provider ignores `tree_filter` and `stealth`; iOS Portal HTTP uses the Android-compatible provider and honors them. The screenshot-only provider uses neither a tree nor element indexes. It honors `normalized` and resize policy.

`normalized=True` selects the provider's normalized 0–1000 coordinate contract; use the snapshot's coordinate conversion rather than treating model coordinates as native device pixels. `vision_resize_policy` is an object implementing `effective_dims(width, height) -> tuple[int, int]`; it sets model-facing screenshot dimensions. Without one, screenshot-only mode uses `MOBILERUN_MODEL_SCREENSHOT_MAX_SIDE` (2048 by default). `stealth` affects Android state coordinate resolution, not the same thing as wrapping input with `StealthDevice`. `TreeFormatter` and `IndexedFormatter` live in `mobilerun.core.state.formatters`; a custom formatter requires a custom provider, not a `StateProviderOptions` argument.

### Workspace inventory and account selection

All `Workspace` methods accept keyword-only `api_key`, `base_url`, and `billing`
(default `no_commerce`). Credentials otherwise resolve from the environment or
saved login. Overrides select the **source workspace**; a destination device
keeps its own account and billing. Never print credentials. These methods access
cloud storage, and uploads, deletion, and device pushes mutate resources.

| Method | Result and effect |
|---|---|
| `list_apps()` / `list_files()` | `list[App]` / `list[WorkspaceFile]` for the selected account |
| `get_app(app_id)` | Workspace `App` with cloud ID, not a local APK path |
| `upload_app(path)` / `upload_file(path)` | Upload and return `App` / `WorkspaceFile` |
| `download_file(file_id, dest=".")` | Download to a local `Path`; a directory destination uses the workspace filename |
| `push_file(file, device, dest=None)` | Download temporarily then push to device; returns `DeviceFile` |
| `delete_app(app_id)` / `delete_file(file_id)` | Delete workspace assets, not installed apps or device files; authorize first |

### Snapshot details and provider customization

`UIState` is importable from `mobilerun.core.state.ui_state`. Snapshot fields:
`elements`, `formatted_text`, `focused_text`, `phone_state`, `screen_width`,
`screen_height`, `use_normalized`, `coordinate_scale_x`, `coordinate_scale_y`,
`coordinate_contract_active`, `model_screenshot_width`, and
`model_screenshot_height`. `get_element(index)` returns a dict or `None`;
`get_element_info(index)` returns display fields or `{}`;
`get_element_coords(index)` avoids declared tap blockers and can raise
`ValueError`; `get_clear_point(index)` considers overlapping elements and raises
`ValueError` when the target is missing, unbounded or fully obscured. `convert_point(x, y)` converts from the snapshot's declared
coordinate space to device input coordinates. Refresh after a screen change.
`UIElement` from `mobilerun.models.ui` describes optional `index`,
`text`, `className`, `resourceId`, `bounds`, `checkedState`, `displayBounds`,
`tapBlockers`, and recursive `children`.

If a target is obscured, refresh and reselect a visible target; do not guess a
tap point. The selector below must inspect each fresh snapshot and return an
appropriate visible element index, or `None`. If the reselected target is still
obscured, the second `ValueError` propagates to the caller.

```python
from collections.abc import Callable

from mobilerun import Device
from mobilerun.core.state.ui_state import UIState


async def clear_visible_point(
    device: Device, select_visible: Callable[[UIState], int | None]
) -> tuple[int, int] | None:
    snapshot = await device.state.refresh()
    index = select_visible(snapshot)
    if index is None:
        return None
    try:
        return snapshot.get_clear_point(index)
    except ValueError:
        snapshot = await device.state.refresh()
        index = select_visible(snapshot)
        if index is None:
            return None
        return snapshot.get_clear_point(index)
```

A custom `StateProvider` from `mobilerun.core.state.base` takes a `Device` in
its constructor and implements async `get_state() -> UIState`;
`get_final_state()` defaults to `get_state()` and may be overridden. Its
`capabilities` are strings consumed by state-dependent features; built-ins
include `element_index` where available. Set the provider's coordinate contract
consistently: `use_normalized`, `requires_active_contract_for_coords`,
`screenshot_matches_input_coords`, `resize_model_screenshot`,
`requires_coordinate_tools`, `model_screenshot_width`,
`model_screenshot_height`, and `model_screenshot_grid`. Screenshot and input
coordinates are not interchangeable on iOS without the active conversion
contract. The built-in `AndroidStateProvider`, `IOSStateProvider`, and
`ScreenshotOnlyStateProvider` are importable from their respective state
modules; the options factories `android_state_provider`, `ios_state_provider`,
`screenshot_state_provider` take `(device, options)`.

The framework normally selects the provider through `state_options` or a
factory. Direct constructors (from the named state modules) are useful for
custom providers and formatters:

| Provider | Constructor parameters | Choose when |
|---|---|---|
| `AndroidStateProvider` (`mobilerun.core.state.android`) | `driver`, `tree_filter`, `tree_formatter`, `use_normalized=False`, `stealth=False`, `ui_cls=None`, `vision_enabled=False`, `vision_resize_policy=None` | Android-compatible accessibility trees, including cloud and iOS Portal HTTP; use a custom filter/formatter or snapshot class when needed. |
| `IOSStateProvider` (`mobilerun.core.state.ios`) | `driver`, `use_normalized=False`, `vision_enabled=False`, `vision_resize_policy=None` | Native iOS Portal accessibility state. |
| `ScreenshotOnlyStateProvider` (`mobilerun.core.state.screenshot`) | `driver`, `vision_resize_policy=None`, `use_normalized=False` | Visual remote or another screenshot-only backend; no element-index capability. |

All take a `Device` as `driver`. An explicit `ui_cls` overrides Android's
stealth snapshot selection. Default `IOSDevice` chooses the appropriate state
provider after detecting its Portal protocol.

A `TreeFilter` implements `filter(a11y_tree, device_context) -> dict | None`
and `get_name() -> str`. `DetailedFilter(visibility_threshold=0.1,
filter_keyboard=True, clip_bounds=False)` controls visibility, keyboard
filtering and clipping; `ConciseFilter()` offers a smaller tree. `get_filter`
accepts `"concise"` or `"detailed"` (case-insensitive), forwards keyword options
to the selected constructor, and returns a `TreeFilter`; unknown names raise
`ValueError`. Import both from `mobilerun.core.state.filters`. A `TreeFormatter` implements
`format(filtered_tree, phone_state)` returning `(formatted_text, focused_text,
elements, phone_state)`; its `screen_width`, `screen_height`, `use_normalized`,
`display_scale_x`, and `display_scale_y` describe formatting geometry.
`IndexedFormatter()` implements it. Install a custom formatter via a custom
provider rather than passing it to `StateProviderOptions`.

### Pool discovery and resource shortcuts

`pool.devices` is a tuple. `platform`, `supported_operations`,
`supported_buttons`, `extensions`, `number`, and `mailbox` return one value per
member; resource shortcuts require those bindings. `await pool.context()` and
`pool.actions.list(audience="python")` return per-member tuples inside a list.
`await pool.actions.call(name, arguments, audience="python", timeout=None)`
validates each action and matching input schemas before broadcasting, and
returns one result per member. `await pool.bind_each(factory, force=False,
close_on_device_close=False)` calls `factory(device)` for each member; each
extension must be a distinct instance. `unbind_extension(name)` broadcasts.
`tap_element(index)`, `do(...)`, and `expect(...)` broadcast to each device;
each member needs a suitable current snapshot or operator. File inventory is
nested: `list_files` returns `list[list[DeviceFile]]`; `push_file` returns
`list[DeviceFile]`. Mutations can partially succeed before an exception group;
no rollback is implied.

Value types are importable from `mobilerun.models`: `App(package, version,
name, id=None, version_code=None, path=None)` (`path` is a `Path | None`),
`WorkspaceFile(id, name, mime_type, size_bytes, created_at)`, and
`DeviceFile(path, name, size_bytes, modified_at)`. The latter two timestamps
are `datetime` values; device size and modification time may be `None`.

To construct a snapshot in a provider, `UIState(elements, formatted_text,
focused_text, phone_state, screen_width, screen_height, use_normalized=False,
coordinate_scale_x=1.0, coordinate_scale_y=1.0,
coordinate_contract_active=False, model_screenshot_width=None,
model_screenshot_height=None)` accepts the fields listed above.
`StealthUIState` from `mobilerun.core.state.stealth` shares this constructor and
randomizes element and clear-point resolution. In normalized mode
`convert_point(1000, 1000)` maps to the last pixel, not one past the edge;
otherwise it applies the snapshot's coordinate scales.
