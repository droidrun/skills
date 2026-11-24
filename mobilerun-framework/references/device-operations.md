# Device operations

These calls act on a connected `Device`. Device actions mutate the phone; cloud operations access the cloud and can incur usage charges. Obtain authorization first. Check `device.supported_operations` and `device.supported_buttons`; a method existing on `Device` does not promise backend support. Handle `DeviceOperationNotSupported` rather than assuming a fallback.

## Settings, input and screenshots

```python
from pathlib import Path

from mobilerun import Device


async def settings_and_input(device: Device) -> None:
    await device.set_location(52.52, 13.405)
    location = await device.get_location()
    await device.reset_location()
    await device.set_timezone("Europe/Berlin")
    timezone = await device.get_timezone()
    await device.set_language("de-DE")
    language = await device.get_language()
    await device.set_clipboard("hello")
    clipboard = await device.get_clipboard()
    await device.open_url("https://example.com")
    await device.swipe(200, 700, 200, 300, duration_ms=500)
    await device.press_button("home")
    Path("screen.png").write_bytes(await device.screenshot())
    print(location, timezone, language, clipboard)
```

`swipe` duration is milliseconds; `drag` duration is seconds. The built-in Android, cloud and iOS drivers reject `drag`; visual remote implements it through swipe when supported. `press_button` uses a supported button name; `press_key_code(int)` sends a backend keycode where supported. The CLI's long press uses a same-point swipe; there is no public `Device.long_press` method. A screenshot returns PNG bytes. `RecordingDevice` records actions for macro replay, not a screen video. Check the selected backend before using any operation in this recipe.

Cloud implements location, language and timezone through its API. `get_location` returns `Location | None` on cloud and is unsupported on local Android, iOS and remote. Android emulator location uses ADB; timezone and URL use shell commands. iOS and visual remote support depend on their Portal/driver capabilities. Visual remote has no app inventory or UI tree. Cloud app/file operations and Portal HTTP support vary by endpoint; local iOS and remote may not support files or installation.

## Apps and files

```python
from pathlib import Path

from mobilerun import AndroidDevice, Workspace


async def transfer_and_install(device: AndroidDevice) -> None:
    app = await device.install_apk("app.apk", reinstall=True)
    await device.start_app(app.package)
    await device.stop_app(app.package)
    apps = await device.list_apps(include_system=False)
    uploaded = await device.push_file("photo.jpg")
    files = await device.list_files("/sdcard/DCIM/Camera")
    await device.pull_file(uploaded.path, Path("copy.jpg"))
    print(len(apps), len(files))
    # Cloud storage upload and push mutate the workspace and device.
    workspace_file = await Workspace.upload_file("photo.jpg")
    await Workspace.push_file(workspace_file, device, "/sdcard/Download")
```

`install_apk(path, ...)` installs a local APK. `install_app(app)` accepts an `App`: local Android needs an App with a local APK path; cloud can install a workspace App from `Workspace.get_app(id)` or `Workspace.upload_app(path)`. The recipe above is local Android only: cloud rejects `reinstall=True` and `grant_permissions=False`. Operation capability checks do not validate keyword support. Both return `App`. `start_app`, `stop_app`, and `uninstall_app(package)` return backend messages, not success booleans. `list_apps` returns dictionaries; `list_files` and `push_file` return `DeviceFile` values. `delete_file(remote_path)` deletes a device file. Workspace `download_file(id, dest)` and `delete_file(id)` act on cloud storage, not the phone; never delete a borrowed asset.

Android image/video pushes default to `/sdcard/DCIM/Camera` and trigger a media scan; other files default to `/sdcard/Download`. Cloud uploads do not expose media scanning. `Workspace.push_file` downloads to a temporary local file then calls the destination device's `push_file`; it is not a server-side transfer. Installing or removing apps changes device state. Uninstall only when explicitly authorized.

## Device facade support matrix

**Yes** means the facade has an implementation, not that a server, permission,
or device will succeed. **No** means the built-in facade raises
`DeviceOperationNotSupported` (possibly after connecting). **Conditional**
means the selected driver, server, state provider, operator or binding decides.
iOS has two auto-detected Portal protocols: **iOS HTTP** is Portal HTTP and
**iOS native** is the other iOS Portal driver. Remote is the visual remote
backend. A failure can occur after partial effects; cloud operations may cost
money and mutations require authorization.

| Public `Device` method | Android | Cloud | iOS native | iOS HTTP | Remote |
|---|---|---|---|---|---|
| `connect`, `close` | yes | yes | yes | yes | yes |
| `wait` | yes | yes | yes | yes | yes |
| `tap`, `swipe`, `input_text`, `press_button`, `screenshot` | yes | yes | yes | yes | conditional: server capabilities |
| `drag` | no | no | no | no | conditional: swipe capability |
| `press_key_code` | yes | no | no | yes | no |
| `start_app` | yes | yes | yes | yes | conditional: server app-launch capability |
| `stop_app` | yes | yes | no | yes | no |
| `list_apps` | yes | yes | yes: configured bundles, not discovery | yes | no |
| `install_apk`, `install_app` | yes: local APK required | yes: local APK or workspace app | no | no | no |
| `uninstall_app` | yes | yes | no | no | no |
| `push_file`, `list_files`, `pull_file`, `delete_file` | yes | yes | no | no | no |
| `set_location` | emulator only | yes | no | no | no |
| `get_location`, `reset_location` | no | yes | no | no | no |
| `set_timezone`, `open_url` | yes | yes | no | no | no |
| `get_timezone`, `set_language`, `get_language`, `set_clipboard`, `get_clipboard` | no | yes | no | no | no |
| `tap_element` | state capability + cached index | state capability + cached index | state capability + cached index | state capability + cached index | custom provider required |
| `do`, `expect` | conditional: operator | conditional: operator | conditional: operator | conditional: operator | conditional: operator |
| `context`, `unbind_extension` | binding-dependent | binding-dependent | binding-dependent | binding-dependent | binding-dependent |

`actions`, `state`, `extensions`, `number`, `mailbox`, `platform`,
`identifier`, `cloud_id`, `supported_operations`, and `supported_buttons` are
properties, not device actions. Resource shortcuts require a matching bound
extension; `state.refresh()` needs a working provider. `tap_element` requires
`element_index` and a refreshed snapshot. Cloud additionally exposes `info`,
`rename`, `resume`, `stop`, `terminate`, `wait_ready`, `reboot`, and `reset`;
Android exposes `terminate` only for its own started emulator.

`device.supported_operations` is a driver-advertised set, not this facade
matrix: cloud install/uninstall are available despite being absent from the set;
Android/cloud declare no `drag`, which indeed raises. Remote support is populated
on connection. iOS HTTP advertises `install_app` at the driver level, but the
public `IOSDevice.install_app` still raises. The iOS native driver returns the
configured bundle identifiers from `list_apps`, not a real full inventory.
Buttons vary by backend; check `supported_buttons`.

`input_text(text, clear=False, stealth=False, wpm=0)` returns a bool. Android
forwards `text` and `clear` only; iOS and remote accept but ignore `stealth` and
`wpm`. Cloud forwards them. `screenshot(hide_overlay=True)` accepts the option;
individual drivers may ignore it. Android `install_apk` and `install_app` accept
`reinstall` and `grant_permissions`; its driver ignores `timeout`. Cloud
accepts a positive `timeout`, rejects `reinstall=True` and
`grant_permissions=False`, and rejects unknown install keywords. Capability
checks do not validate options. `Location` is importable from
`mobilerun.models.location`; `latitude` and `longitude` are floats.

### Low-level cloud client functions

`mobilerun.clients.cloud.devices`, `.apps`, and `.files` are the internal SDK
boundary, not the application-facing API. Their public operation helpers require
keyword-only `billing=`; app code should use `Device` and `Workspace` instead.
See `mobilerun/clients/cloud/README.md` in the repository for the client boundary.

## Identity, indexed input, and cloud lifecycle

`platform` and `identifier` describe the backend; `cloud_id` is the cloud ID or
`None`. Cloud's `device_id` may be `None` before creation and `name` is cached.
`number` and `mailbox` are bound-extension shortcuts; `unbind_extension(name)`
detaches by name. Call `await device.state.refresh()` immediately before
`await device.tap_element(index)`: it uses the cached snapshot and requires the
`element_index` state capability, not just a tap-capable backend. A stale index
can target the wrong element.

**Cloud access requires authorization; lifecycle calls mutate the phone, can
incur charges, and may destroy data.** `await phone.info()` retrieves metadata;
`await phone.rename(name)` updates it and the cached name. `await phone.resume()`
starts a stopped phone; `await phone.wait_ready()` waits for readiness;
`await phone.stop()` stops it; `await phone.reboot()` restarts it;
`await phone.reset()` resets it; `await phone.terminate()` destroys the remote
phone but leaves bound extensions open and registered. Exit the device context or
call `await phone.close()` for handle teardown: by default this detaches borrowed
extensions; bindings with `close_on_device_close=True` are closed instead. These operations ensure the handle is connected and forward
optional backend parameters. Explicit termination affects even a borrowed phone;
context exit alone closes a borrowed handle without terminating it. Android's
`terminate()` applies to its owned emulator, not an arbitrary attached device.
