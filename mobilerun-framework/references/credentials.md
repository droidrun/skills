# Credentials and vaults

Credentials are extensions, not device constructor arguments. A **package** is the app identifier, a **name** distinguishes accounts, and a **field** identifies a string value. Use stored identifiers, not guessed domain names. Do not print, log, interpolate, record or serialize secret values. These examples define functions; running them changes a device or store and requires authorization. Cloud calls access the service; cloud tasks consume credits.

## Choose a provider

Import from `mobilerun.core.credentials`.

| Provider | Constructor and behavior | Writes and ownership |
| --- | --- | --- |
| `CredentialProvider` | Abstract extension contract: `list(package=None)` and `type_field(package, field, name=None)`. | Not instantiated directly. |
| `DictCredentials` | `DictCredentials(mapping, *, name=None)`. Copies and normalizes a mapping at construction. | In-memory snapshot; no public CRUD. |
| `EnvCredentials` | `EnvCredentials(prefix="MOBILERUN_SECRET_", *, name=None)`. Snapshots matching environment variables at construction. `MOBILERUN_SECRET_GMAIL_PASSWORD` becomes a general credential named `GMAIL_PASSWORD` with field `password`. | No public CRUD; construct again to see environment changes. |
| `FileCredentials` | `FileCredentials(path, *, name=None)` reads YAML or JSON immediately; an absent file starts empty. `~` expands. | `save`, `update`, `delete` write YAML atomically using a private file and lock. Reconstruct to see external changes. Files readable by group/others raise `PermissionError`; symlinks are rejected where `O_NOFOLLOW` is available. |
| `CloudCredentials` | `CloudCredentials(api_key=None, base_url=None, *, billing=None, name=None)` constructs a cloud client immediately. Explicit API key wins; otherwise `MOBILERUN_API_KEY`, then saved cloud login. `billing=None` snapshots `MOBILERUN_BILLING` (default `paid`). | Cloud vault read/write operations require at least `no_commerce`; this mode is not read-only. Includes Mobilerun and 1Password-backed entries. Lists are cached per instance; writes invalidate its caches. Close the client. |

Providers are **not awaitable or async context managers**. Construct normally; `await provider.bind(device)` when needed; always `await provider.close()` in `finally`. `close()` unbinds and closes the handle, not the saved credential. By default device close unbinds a borrowed provider without closing it; `bind(device, close_on_device_close=True)` makes device cleanup close it. A provider can bind to one device at a time. Use distinct `name=` values for multiple providers: default name is `vault`. `device.extensions` is a read-only mapping in binding order; retain typed provider handles. This checkout does **not** expose a `device.credentials` tuple.

## Data shape, fields and lookup

A structured mapping is `{package: {name: {field: value}}}`. A flat `{name: value}` creates an unbound `package=None` credential with a `password` field. Local providers accept string-valued fields with arbitrary field names; cloud writes and the CLI accept only `email`, `username`, `password`, `api_token`, `phone_number`, `two_factor_secret`, and `backup_codes`. `two_factor_secret` is stored and typed as a string; this package does not generate TOTP codes. For SMS/email codes, use the number or mailbox `wait_for_code` API instead.

`await provider.list()` returns metadata dictionaries with `package`, `name`, and a list of field names under `fields`, never values. `list(package)` filters by package; `None` means all packages, not only general credentials. Cloud entries can also include `source: "1password"`. The cloud all-packages endpoint paginates; a missing package produces an empty list. Listing the vault fetches and caches credential values internally even though its return value omits them. There is no public provider `get` or `retrieve` method for values; `_find` and `_list_credentials` are private. `Credential.fields` itself contains raw values, so its value-safe `repr` is **not** protection against `dataclasses.asdict`, direct access, or arbitrary serialization.

`type_field` searches within the selected provider, taking the first matching field and optional name in provider order. `package=None` does not restrict matches to general credentials. Specify both package and name to avoid ambiguity. No general automatic cross-provider precedence exists for direct calls: choose the provider handle explicitly. For recorded `type_secret` macro actions, replay prefers a credential provider named `vault`; otherwise exactly one credential provider must be bound. Multiple non-default providers are ambiguous.

## Recipe: bind a local secret and type it

The caller supplies the value from a secure source and has already focused an editable field. This performs device IO. `type_field` returns `None`, not the secret or a success flag.

```python
from mobilerun import Device
from mobilerun.core.credentials import DictCredentials


async def type_local(device: Device, password: str) -> None:
    vault = DictCredentials({"com.example.app": {"work": {"password": password}}})
    try:
        await vault.bind(device)
        await vault.type_field("com.example.app", "password", name="work")
    finally:
        await vault.close()
```

Before typing, the device refreshes state and requires an observable focused, editable field. Screenshot-only providers cannot establish that and raise `DeviceOperationNotSupported`; an unfocused field raises `NoFocusedInput`. The root device's input lock prevents competing Mobilerun input during the focus check and typing. It cannot prevent the app, OS or another process changing focus. Avoid logging or exposing screen contents after typing.

## Recipe: manage a private local file

This writes a local file and deletes one field. Use a dedicated path; never overwrite or delete someone else's credentials. The caller supplies values without placing them in source code or shell history.

```python
from pathlib import Path

from mobilerun.core.credentials import FileCredentials


async def manage_local(path: Path, username: str, password: str) -> None:
    vault = FileCredentials(path)
    try:
        await vault.save(
            "com.example.app", "work", {"username": username, "password": password}
        )
        entries = await vault.list("com.example.app")
        assert any(entry["name"] == "work" for entry in entries)
        await vault.update("com.example.app", "work", "username", username)
        await vault.delete("com.example.app", "work", "username")
    finally:
        await vault.close()
```

`save(package, name, fields)` merges fields and creates missing entries. `update(package, name, field, value)` requires an existing field. `delete(package, name, field)` deletes one field; omit `field` to delete the entire credential. For local files, `package=None` supports general credentials. Missing fields/credentials in local writes raise `ValueError`. The file stores values in plaintext YAML despite restrictive permissions; protect backups and disk access. `FileCredentials` inherits the in-memory snapshot for reads and reloads the file on writes. Writes may create parent directories and a `.lock` file.

## Recipe: use an existing cloud vault entry in a cloud task

This accesses cloud and runs a task that consumes credits. Use a known existing device ID. Creation occurs when the ID is omitted or `None`; an empty ID is invalid, not a request to create. Validate attachment inputs before constructing a device. This function receives an already connected, caller-owned device and never terminates it.

```python
from pydantic import BaseModel

from mobilerun import CloudDevice
from mobilerun.core.credentials import CloudCredentials
from mobilerun.models import ExecutionResult


async def cloud_login(device: CloudDevice, package: str, name: str) -> bool:
    vault = CloudCredentials(billing="no_commerce")
    try:
        entries = await vault.list(package)
        if not any(entry["name"] == name for entry in entries):
            raise ValueError("Vault credential not found")
        await vault.bind(device)
        result: ExecutionResult[BaseModel] = await device.do(
            f"Sign in to {package} using credential {name}"
        )
        return result.success
    finally:
        await vault.close()
```

The device's cloud task operator needs `included` or `paid` billing even though the vault uses `no_commerce`. `CloudTaskOperator` rejects **any** bound non-cloud-native extension, including local credential providers. It collects references for **all package-bound credentials** exposed by bound cloud-native providers, deduplicates package/name pairs, and sends references, not field values, to the cloud task endpoint. The instruction chooses the desired account; it does not filter the transmitted references. General (`package=None`) credentials are not included. The optional `mobilerun-agents` add-on supplies local operators that can use local providers on local or cloud phones; those tasks may consume LLM tokens. Inspect the installed add-on for its API.

## Recipe: write cloud vault fields

Cloud access and vault writes; deleting a field is destructive. Get approval first. No values are returned or printed.

```python
from mobilerun.core.credentials import CloudCredentials


async def update_vault(package: str, name: str, password: str) -> None:
    vault = CloudCredentials(billing="no_commerce")
    try:
        await vault.save(package, name, {"password": password})
        await vault.update(package, name, "password", password)
    finally:
        await vault.close()
```

Cloud `save` creates a missing package and credential, or updates existing fields and creates missing fields. `update` targets one existing field. `delete(package, name, field=None)` deletes one field or the entire credential. These APIs use cloud requests; inspect errors before retrying writes. Cloud `save` may perform several requests and is not documented as atomic. Package-level low-level client helpers exist, but the provider has no public package-delete API.

### Package names and extension authors

Cloud package matching normalizes dots to hyphens internally. The provider remembers a dotted name supplied to package lookup or save and maps the corresponding slug back to it for metadata and task references. Do not infer a dotted package from an arbitrary slug; provide the actual stored identifier.

`await provider.cloud_task_inputs()` returns `CloudTaskInputs` containing `credential_references`, a tuple of `CloudCredentialReference(package, name)`; `CloudCredentials` contributes all package-bound entries, not values. Custom cloud-native providers can override this hook. See [extension authoring](architecture.md#write-an-extension-and-actions); non-cloud-native providers cannot accompany a cloud task.

### Low-level vault client boundary

`mobilerun.clients.cloud.secrets` functions require an already managed `mobilerun_sdk.AsyncMobilerun` as the first argument and keyword `billing=Billing.NO_COMMERCE` or higher. Close the client you create. Unlike `CloudCredentials`, these functions do not implement provider cache or merge policy, and responses can contain secret values. Never log them. Cloud writes and deletes require authorization.

| Function (after `client`) | Result / effect |
| --- | --- |
| `list_secrets(*, billing=...)` | `list[Item]`, all pages. |
| `list_package(package, *, billing=...)` | `list[Data]` for the package. |
| `create_package(package, *, billing=...)` | `PackageCreateResponse`; creates a package. |
| `save(package, name, fields, *, billing=...)` | `CredentialCreateResponse`; creates a credential in an existing package. |
| `create_field(package, name, field, value, *, billing=...)` | `FieldCreateResponse`. |
| `update(package, name, field, value, *, billing=...)` | `FieldUpdateResponse`. |
| `delete(package, name, field=None, *, billing=...)` | `CredentialDeleteResponse` or `FieldDeleteResponse`; destructive. |

Fields use the cloud `FieldType` literals listed above. These helpers expose SDK models, not the metadata-only provider interface.

## CLI workflow

Cloud is the default for writes. `list` without a selector queries cloud **then** local; use `--local` to avoid cloud. Local CLI storage uses `MOBILERUN_CREDENTIALS_FILE` or `<user config dir>/credentials.yaml`; it is separate from the saved cloud login at `<user config dir>/credentials/mobilerun-cloud.json`.

| Task | Command | Effect |
| --- | --- | --- |
| Find local path | `mobilerun credentials path --json` | Reports `path`, `exists`, and `source` (`env` or `default`), not credential contents. Omit `--json` for text. |
| Inspect | `mobilerun credentials list --local --json` or `mobilerun credentials list --vault --package com.example.app` | Metadata only. `--vault` accesses cloud; `--local` and `--vault` are mutually exclusive. |
| Save | `mobilerun credentials save com.example.app work --field password --local` | Writes local file and prompts with hidden input. Omit `--local` for cloud. Repeat `--field`, or use `--from-json FILE` / `--from-json -` instead; protect the JSON input. Existing entries require interactive confirmation; non-interactive overwrite aborts. |
| Update | `mobilerun credentials update com.example.app work password --local` | Writes one field from a hidden prompt; `--stdin` reads the value from stdin. Omit `--local` for cloud. |
| Delete | `mobilerun credentials delete com.example.app work password --local` | **Destructive**: deletes the named field. Omit field to delete the credential; `--yes` bypasses confirmation. Omit `--local` for cloud. |

Missing identifiers can be selected interactively. A general, no-package local entry is selectable interactively; noninteractive `save` requires package and name. Never pass values as command arguments or put them in shell history. CLI `--local` describes the store, not a restriction on which device a local operator can control.

## Errors, security and migration

- `ExtensionNotBound` means bind before `type_field`; `ExtensionClosed` means create a fresh provider. `ExtensionConflict` indicates a duplicate name or conflicting lifecycle.
- `CredentialFieldNotFound` means the selected provider has no matching field; inspect metadata, not values. `NoFocusedInput` and `DeviceOperationNotSupported` require an observable focused editable field. A rejected device input becomes `ExtensionActionError`.
- Invalid local file content or permissions can raise `CredentialFormatError`, `ValueError`, or `PermissionError`. Cloud authentication, permissions, validation and transport failures use typed cloud errors; `OperatorNotSupported` flags incompatible cloud task extensions. Do not broaden billing or retry a destructive write blindly.
- The public `list`, `context` and `Credential.__repr__` omit values, but internal memory, file serialization, vault transport and device input necessarily handle them. Cloud vault writes send values to the vault; direct typing sends a value to the device backend. Cloud task requests send vault references. Protected action boundaries sanitize error chains; cloud write helpers redact active values. This is not a guarantee that all arbitrary user logging, serialization, backend errors or debug tooling are safe.
- Placeholder expansion is removed. Replace `{{secret:…}}` input with a bound provider's `type_field`; replace `{{code:sms}}` with a number's `wait_for_code()` followed by `device.input_text(code)`. Codes are ordinary values; credential fields are not returned by `type_field`.
