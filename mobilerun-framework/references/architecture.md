# Architecture and package map

The source checkout's `mobilerun/README.md` and package READMEs are the detailed source of truth. Import direction: features → shared/core/clients; core → clients. Arrows mean "may import". The CLI root discovers feature commands through distribution entry points.

| Package | Responsibility |
| --- | --- |
| `core/devices` | Device interface, platforms, pools and recording/stealth wrappers |
| `core/state` | State providers, models, filters and formatters |
| `core/operator` | Operator contract |
| `core/credentials`, `phone_number`, `mailbox`, `proxy` | Bindable resources; proxy and operator selection live on phones |
| `core/workspace.py` | Account-wide file and app operations |
| `core/webhooks` | [Cloud webhook endpoint management](webhooks.md) |
| `clients/cloud` | Cloud SDK boundary, auth, transport and billing guards |
| `clients/local` | Local emulator, APK, credential and polling helpers |
| `clients/portal` | Portal setup, HTTP and state transport |
| `models` | Shared value types, without IO or SDK |
| `config`, `utils`, `errors`, `logs` | Configuration, helpers, errors and logging |
| `macro` | Recording, state-guarded replay and macro operator |
| `sandbox` | Optional plugin for packaging typed `@cloud` functions, deploying endpoints or scheduled workflows, and invoking and polling runs |
| `skills` | Discover, install and remove bundled skills |
| `mcp` | Install and manage the public MCP server configuration |
| `addons` | Plugin discovery and entry-point group settings |
| `cli` | Root composition and command groups |
| `diagnostics`, `assets` | Diagnostics and bundled data |

`mobilerun.__version__` exposes the installed Mobilerun distribution version as a string.

The `sandbox` extra uses `mobilerun-functions[device]==0.1.0` (`mobilerun_functions`), replacing `mobilerun-routines`. See [sandbox cloud functions](sandbox.md).

`tests/unit/test_import_boundaries.py` defines the intended boundaries. Shared packages must not import features; features must not import each other or agents. Clients and utils must not import core; utils imports only utils within Mobilerun. SDK imports belong in cloud clients. Legacy aliases have specific test exceptions; feature CLI code may import `cli/base`. Clients never import core or the root `mobilerun` package (use `mobilerun.version` for the version); core and features may call clients.

`mobilerun-agents` is a separate install. It supplies LLM operators, integrations and agent CLI commands. Cloud phones default to a cloud task operator; strict macro execution and agent-based fallback are separate choices. The base CLI does not import `mobilerun.agents.*`. Legacy agent import paths are not supported; install the add-on and import `mobilerun.agents.*` directly. Do not invent add-on APIs: inspect the installed add-on or its documentation.

The repository `skills/` is a submodule, not the Python `mobilerun/skills/` package. `hatch_build.py` recursively bundles its files under `mobilerun/assets/skills` in wheels, excluding Git metadata, tests and caches. Markdown files directly under a skill's `references/` are also discoverable sub-skills.

## Where code goes

Shared `errors/`, `models/`, `utils/`, `cli/`, `config/` and `logs/` serve core and clients. Features (`macro`, `mcp`, `skills`, `sandbox`) own their CLI, errors, models and settings. Features may import shared, core and clients; core may import clients; clients never import core or the root package; shared code never imports features.

## Write an extension and actions

Extensions are standalone resources with optional device binding. `default_name`, `exclusive`, `role`, and `cloud_native` are class declarations; the default name is `extension`, other three default to `None`, `None`, and `False`. Names must match `[a-z][a-z0-9_]{0,31}`. An exclusive group conflicts with another extension in that group; roles drive device resource shortcuts. Set `cloud_native=True` only when the server can use the resource through supported reference-only task inputs, not to bypass local-extension rejection.

This extension does no I/O until its device action is called. Bind to a suitable device before tapping; the action changes its screen.

```python
from mobilerun import Device
from mobilerun.core.extensions import Extension, action, device_action


class Marker(Extension):
    default_name = "marker"

    @action
    async def label(self, value: str) -> str:
        """Return a display label."""
        return f"Marker: {value}"

    @device_action
    async def tap_point(self, device: Device, x: int, y: int) -> None:
        """Tap a point on the bound device."""
        await device.tap(x, y)


async def use_marker(device: Device) -> str:
    marker = Marker()
    await marker.bind(device)
    try:
        label = await marker.label("example")
        await device.actions.call("marker.tap_point", {"x": 1, "y": 2})
        return label
    finally:
        await marker.close()
```

Decorated methods must be async, documented, have typed arguments and return annotations, and use schema-compatible types. `@device_action` requires `device: Device` immediately after `self` and injects it; callers do not pass it. `@action` also works unbound. Decorators take `public=True` and `sensitive_parameters=frozenset({...})`; sensitive parameters must exist and have no defaults. They are redacted from recorded action arguments and scrubbed from schema examples/defaults; this does not make action return values, context, logs or arbitrary backend calls safe. Never return or log secrets.

`extension.name`, `extension.device` (bound facade or `None`; uncertain bindings raise), and `extension.actions` expose live state. `device.extensions.get(name)` dynamically looks up an extension; retain the typed handle for typed calls. `ActionSet(source)` accepts a device or extension; `list(audience="python" | "operator" | "cli")`, `get(name)`, and `await call(name, arguments, audience="python", timeout=None)` discover and invoke actions. Python sees private actions; operator and CLI audiences see only `public` actions. `get` itself uses Python visibility; `call` enforces the requested audience. `Action` metadata includes `name`, `owner`, `description`, `input_schema`, `output_schema`, `public`, `sensitive_parameters`, and `requires_device`. `validate(arguments)`, `validate_result(value)` and `serialize(value)` provide schema validation and JSON serialization. `Action.compile(owner, name, fn, Declaration(...), description=None)` is the lower-level catalog constructor; normally let decorators compile it. `Declaration` carries `public`, `sensitive_parameters` and `requires_device`.

Subclass hooks are async: `check_bind(device)` returns conflicting extensions (call the base implementation to preserve exclusivity), `on_bind(device)` and `on_unbind(device)` perform backend linking without mutating the local registry, and `on_close()` releases only owned resources. Do not call lifecycle hooks directly; use `bind`, `unbind`, and `close`. A binding is to one device at a time; device closure unbinds without closing by default, or closes when `close_on_device_close=True`. `force=True` detaches conflicting extensions without closing them. Lifecycle changes cannot occur inside an action. `context()` returns public `ContextItem` values; `cloud_task_inputs()` returns reference-only `CloudTaskInputs`. Built-in credential, mailbox, number and proxy classes inherit these rules but add backend-specific checks and hooks; for example a cloud number checks compatibility and binds server-side, cloud proxy replacement has special switching rules, and closing cloud resources releases only owned resources. Their overridden hooks are implementation details, not direct APIs.

## Python skills and MCP management

The Python package `mobilerun.skills` exports `Skill`, `InstallResult`, `list_skills`, `installed`, `install`, and `uninstall`. `list_skills()` discovers bundled skills and direct reference sub-skills. `Skill` has `name`, `description`, `path`, `source`, `relative_path`, `parent`, and `source_file`. `installed(agent, scope="user", directory=None)` lists installed names. `install(skill_names, agent, scope="user", dir=None, force=False)` installs and may include a parent; `uninstall(skill_names, agent, scope="user", dir=None)` removes only managed copies. Both return `InstallResult(name, status, path)` records. `mobilerun.skills.bundle.install_bundles(names, agent, scope="user", dir=None, force=False)` installs whole bundle folders. Installing or uninstalling writes or removes local files; obtain authorization and inspect targets first. Force does not authorize replacing unmanaged content.

`mobilerun.mcp.installer.config_path(agent, scope)` gives the agent config path; `status(agent, scope)` reads whether the server is installed. `install(agent, scope, api_key=False, force=False)` writes configuration, returning `installed` or `exists`; it refuses different existing settings without force. `uninstall(agent, scope)` removes the named server entry and returns `removed` or `not installed`. These are config changes, not MCP tool execution; do not expose API keys or overwrite another configuration without permission.

Plugin discovery uses `mobilerun.addons.plugins` and entry-point groups `mobilerun.cli` and `mobilerun.operators` from `mobilerun.addons.settings`. Availability is `"agent" in plugins.discover(CLI_ENTRY_POINT_GROUP)`; discovery reads metadata without importing implementations and prefers the first-party `mobilerun` distribution on a name clash; other duplicate names are skipped. The asset migration discovers optional add-on assets with `importlib.util.find_spec`.

For a plugin, declare a Click command/group under `mobilerun.cli`; `agent_macro` under `mobilerun.operators` must be a plain callable. Built-ins win name conflicts. `mobilerun plugins list [--json] [--check]` lists distributions and status; `--check` imports unshadowed plugins and can execute their import code. The full write-a-plugin guide (entry-point declaration, replay callable contract, test template) is `mobilerun/addons/README.md` in the mobilerun source checkout.

## Low-level cloud and auth

These modules are adapter-level APIs: prefer device/resource interfaces for ordinary work. Their SDK request and response types track the installed `mobilerun_sdk`, not an independent stable wire contract. Leading-underscore helpers and backend component methods are internal; package-level and documented extension/operator contracts are the intended integration surface, not a promise that arbitrary internal imports remain stable. Check installed signatures and release notes before relying on SDK models.

`mobilerun.clients.cloud.client.cloud_client(api_key=None, base_url=None, *, billing=...)` returns a caller-owned `AsyncMobilerun`; explicit key wins over configured login. Close it with `await client.close()` or an async context. `mobilerun.clients.cloud.api_keys.validate_api_key(api_key, *, billing=...)` validates via the service and returns `None`; do not print the key. Device OAuth helpers in `mobilerun.clients.cloud.device_flow` are `await request_code(auth_url, client_id, billing=...)` (returns a code response), `await poll_token(auth_url, client_id, code, billing=...)` (waits for user authorization, returns a secret token), and `await fetch_session(auth_url, token, billing=...)` (session dict or `None`). These calls use `no_commerce` but access cloud services. Never log codes or tokens.

Supplemental pure helpers: `mobilerun.utils.codes.extract_code(text)` extracts an OTP and `wait_for_code` polls for one; `mobilerun.utils.redaction.secret_scope` scopes active secret redaction; `coordinates.to_absolute`, `to_normalized`, `bounds_to_normalized` convert coordinate representations; `geometry.rects_overlap`, `find_uncovered_point`, `find_clear_point` work with rectangles; `images.image_dimensions`, `anthropic_resized_size`, `fit_dimensions_to_max_side`, `resize_image_to_max_side`, `resize_image_to_max_side_with_grid`, `resize_image_to_dimensions_with_grid` inspect or resize image bytes; `timestamps.to_api_timestamp(datetime)` formats a timestamp for the API. These module-level helpers are lower-level than device/state APIs; inspect signatures and handle malformed data.
