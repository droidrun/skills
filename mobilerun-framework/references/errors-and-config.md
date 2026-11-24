# Errors, settings and models

## Handle errors by operation

Import shared exceptions from `mobilerun.errors`. `MobilerunError` is the common base; specific errors below inherit the group shown. Catch specific failures before a broad group. Do not log secrets or arbitrary backend details.

| When | Group and errors | Response |
| --- | --- | --- |
| Device selection or input | `DeviceError`: `DeviceNotFound`, `DeviceAuthError`, `DeviceNotReady`, `DeviceOperationNotSupported`, `NoFocusedInput`, `PortalApkNotFound`, `PortalInstallFailed` | Connect and refresh before cached state; check backend capabilities. Unsupported is not an invitation to guess another method. Focus an editable input before secret typing. |
| State | `DeviceError`: `StateFetchFailed`, `UnsupportedStateCapability` | Inspect provider capabilities and retry only when appropriate. |
| Extensions | `DeviceError`: `ExtensionConflict`, `UnmanagedProxyConflict`, `ExtensionNotSupported`, `ExtensionNotBound`, `ExtensionClosed`, `ExtensionActionError` | Bind a compatible resource; resolve conflicts deliberately. Action errors may wrap unsafe backend details. |
| Cloud transport | `CloudError` → `CloudAPIError`: `CloudAuthenticationError`, `CloudPermissionDenied`, `CloudResourceNotFound`, `CloudConflict`, `CloudValidationError`, `CloudRateLimited`, `CloudServiceUnavailable`, `CloudConnectionError`, `CloudTimeout` | Inspect typed status/request ID; do not blindly retry auth, validation or writes. `CloudAuthRequired`, `CloudDeviceNotFound`, `InvalidCloudDeviceId`, `CloudTaskTimeout`, `PurchaseInProgress` specialize these. `ProxyNotActive` is a `CloudError`. |
| Billing or checkout | `CloudAPIError` → `BillingError` → `IncludedCapacityUnavailable`, `PaymentRequired` | Respect the caller's billing ceiling. Never silently upgrade or purchase. `PaymentRequired.checkout` and `wait_until_paid()` support an explicitly approved checkout; resource cleanup and retention require care. |
| Credentials | `CredentialError`: `CredentialReadError`, `CredentialNotFoundError`, `CredentialFieldNotFound`, `CredentialFormatError`, `LocalCredentialsNotAllowed`, `InvalidAPIKeyError`, `PlaceholderError` | Fix the provider or stored identifiers; cloud tasks require vault references, not local values. |
| Operator | `OperatorError`: `OperatorNotAvailable`, `OperatorNotSupported` | Choose an operator that supports the operation and device. `ExpectationFailed` and `ExpectationInconclusive` are `DeviceError` subclasses. |
| Macro | `MacroError` and `MacroMismatch` from `mobilerun.macro.errors` | Stop on divergence, inspect `player.last_divergence`, reset the screen or rerecord. Never silently invoke an agent. |
| Sandbox | `SandboxError` and its subclasses from `mobilerun.sandbox.errors` | Distinguish declaration, packaging, consent, deployment and run errors. `SandboxDeploymentError.receipt` may record partially created resources; a `SandboxRunTimeout` does not cancel the run. |
| Other | `ConfigError`, `AgentError` | Correct config or consult the optional agent package. |

### Exported exception hierarchy

All names below import from `mobilerun.errors`. `—` means no additional named payload beyond inherited exception state. Cloud subclasses inherit `operation`, `status`, `code`, `request_id`, `detail`, `timeout`, `resource_id`, `required_billing`, `country`, and `value_safe`. Treat free text and identifiers as potentially sensitive; never log arbitrary responses or secrets. Multiple bases shown matter for existing handlers.

| Class | Base | When; payload; handling |
| --- | --- | --- |
| `MobilerunError` | `Exception` | Common framework failure; —; catch last. |
| `AgentError` | `MobilerunError` | Agent failure; —; inspect add-on. |
| `ConfigError` | `MobilerunError` | Invalid config; —; repair config. |
| `DeviceError` | `MobilerunError` | Device failure; —; handle specific cause. |
| `CloudError` | `MobilerunError` | Cloud failure; diagnostics above; handle specific cause. |
| `CredentialError` | `MobilerunError` | Credential failure; —; correct provider. |
| `OperatorError` | `MobilerunError` | Operator failure; —; check operator. |
| `DeviceAuthError` | `DeviceError` | OAuth response; `code`, `description`; correct authentication. |
| `DeviceNotFound` | `DeviceError`, `RuntimeError` | Android device unavailable; —; select an available device. |
| `DeviceNotReady` | `DeviceError`, `RuntimeError` | Device/state not ready; —; connect or refresh. |
| `DeviceOperationNotSupported` | `DeviceError`, `RuntimeError` | Unsupported action; —; use a supported backend. |
| `NoFocusedInput` | `DeviceError` | Secret typing lacks focused editable field; —; focus first. |
| `PortalApkNotFound` | `DeviceError`, `FileNotFoundError` | APK absent; —; fix path. |
| `PortalInstallFailed` | `DeviceError`, `RuntimeError` | Portal installation failed; `apk_path`; check install prerequisites. |
| `StateFetchFailed` | `DeviceError` | State retries exhausted; —; inspect connection. |
| `UnsupportedStateCapability` | `DeviceError`, `RuntimeError` | State capability absent; —; choose compatible provider. |
| `ExtensionConflict` | `DeviceError` | Binding/name occupied; —; resolve ownership. |
| `UnmanagedProxyConflict` | `ExtensionConflict` | Active unmanaged proxy; —; explicitly approve replacement. |
| `ExtensionNotSupported` | `DeviceError` | Device lacks required capabilities; —; choose compatible device. |
| `ExtensionNotBound` | `DeviceError` | Detached or uncertain extension; —; bind or reconcile. |
| `ExtensionClosed` | `DeviceError` | Extension closing/closed; —; create a fresh handle. |
| `ExtensionActionError` | `DeviceError` | Extension action failed; `cause_type`; inspect safely. |
| `ExpectationFailed` | `DeviceError` | Expectation failed; `result`, `condition`, `reason`; handle failed assertion. |
| `ExpectationInconclusive` | `DeviceError` | Expectation could not be assessed; `condition`, `task`; inspect task outcome. |
| `OperatorNotAvailable` | `OperatorError`, `NotImplementedError` | No operator; —; configure one. |
| `OperatorNotSupported` | `OperatorError` | Operator incompatible; —; select another. |
| `CredentialReadError` | `CredentialError` | Credential file unreadable; —; repair access. |
| `CredentialNotFoundError` | `CredentialError`, `KeyError` | Credential missing; —; select existing name. |
| `CredentialFieldNotFound` | `CredentialNotFoundError` | Field missing; —; fix field name. |
| `CredentialFormatError` | `CredentialError`, `ValueError` | Malformed file; —; repair format. |
| `LocalCredentialsNotAllowed` | `CredentialError`, `ValueError` | Local provider in cloud task; —; use vault references. |
| `InvalidAPIKeyError` | `CredentialError` | Invalid API key; —; replace securely. |
| `PlaceholderError` | `CredentialError`, `ValueError` | Unsupported placeholder; —; use credentials provider. |
| `CloudAPIError` | `CloudError` | API failure; inherited cloud diagnostics; handle typed subtype. |
| `CloudAuthenticationError` | `CloudAPIError` | Authentication rejected; inherited diagnostics; correct credentials. |
| `CloudAuthRequired` | `CloudAuthenticationError` | Cloud credentials absent; inherited diagnostics; authenticate. |
| `CloudPermissionDenied` | `CloudAPIError` | Permission denied; inherited diagnostics; request appropriate access. |
| `CloudResourceNotFound` | `CloudAPIError` | Resource missing; inherited diagnostics; verify ID. |
| `CloudDeviceNotFound` | `CloudResourceNotFound` | Phone missing; inherited diagnostics; verify ID. |
| `CloudConflict` | `CloudAPIError` | State conflict; inherited diagnostics; reconcile state. |
| `PurchaseInProgress` | `CloudConflict` | Existing purchase; `resource_id`, `checkout`; resume or reconcile, don't repurchase. |
| `CloudValidationError` | `CloudAPIError` | Invalid request; inherited diagnostics; correct input. |
| `InvalidCloudDeviceId` | `CloudValidationError` | Invalid phone ID; inherited diagnostics; correct ID. |
| `CloudRateLimited` | `CloudAPIError` | Rate limit; inherited diagnostics; retry safely with backoff. |
| `CloudServiceUnavailable` | `CloudAPIError` | Service unavailable; inherited diagnostics; retry safe operations. |
| `CloudConnectionError` | `CloudAPIError` | Network failure; inherited diagnostics; reconcile writes before retry. |
| `CloudTimeout` | `CloudAPIError`, `TimeoutError` | Request timed out; inherited diagnostics; reconcile before retry. |
| `CloudTaskTimeout` | `CloudTimeout` | Task wait timed out; inherited diagnostics; inspect task before rerunning. |
| `BillingError` | `CloudAPIError`, `ValueError` | Billing policy forbids operation; inherited diagnostics; do not upgrade silently. |
| `IncludedCapacityUnavailable` | `BillingError` | Included inventory exhausted; inherited diagnostics; ask before paid fallback. |
| `PaymentRequired` | `BillingError` | Checkout pending; `checkout`, `resource`, `resource_id`, `payment_url`, `checkout_expires_at`; see [payments](payments.md). |
| `ProxyNotActive` | `CloudError` | No active proxy after switch; inherited diagnostics; reconcile proxy state. |

Feature exception bases and subclasses live in `mobilerun.macro.errors` and `mobilerun.sandbox.errors`, not `mobilerun.errors`.

## Environment and precedence

Shared `get_settings()` and package settings read fresh, case-sensitive environment snapshots. Environment values override declared defaults. Most explicit operation/constructor arguments override settings when that argument is supported; confirm each signature. Empty `MOBILERUN_CLOUD_BASE_URL`, `MOBILERUN_AUTH_URL` and `MOBILERUN_MCP_URL` fall back to defaults. JSON is required for structured settings such as `MOBILERUN_AGENTS` and retry delays. No `.env` file is loaded by these settings classes.

| Name | Default | Effect and precedence |
| --- | --- | --- |
| `MOBILERUN_API_KEY` | unset | Cloud credential; explicit `api_key=` wins, then environment, then saved login. Never print it. |
| `MOBILERUN_DEVICE_TOKEN` | unset | Device auth token; overrides `DeviceConfig.auth_token`. |
| `MOBILERUN_USER_CONFIG_DIR` | platform user config for `droidrun` | User config and credential directory. |
| `MOBILERUN_CONFIG` | unset | Existing user config file override, below explicit `ConfigLoader.load(config_path=...)`. |
| `MOBILERUN_CREDENTIALS_FILE` | unset | Overrides `<user config dir>/credentials.yaml`; `~` expands. |
| `MOBILERUN_LOG_LEVEL` | unset | Log-level override: quiet, normal, verbose, debug. |
| `MOBILERUN_PORTAL_REMOTE_PORT` | 8080 | Portal port. |
| `MOBILERUN_AGENTS` | claude-code, codex, opencode, cursor registry | JSON registry of skill/MCP user and project paths and formats; replaces the default registry. |
| `ANDROID_HOME`, `ANDROID_SDK_ROOT` | unset | Android SDK location. |
| `MOBILERUN_SMOKE_APK` | `/tmp/mobilerun-smoke/counter.apk` | Smoke-test APK. |
| `MOBILERUN_ANDROID_DEVICE_TYPE` | unset | Default Android device type. |
| `MOBILERUN_CLOUD_DEVICE_TYPE` | `android_cloud_phone` | Default cloud device type. |
| `MOBILERUN_BILLING` | `paid` | Default resource charge ceiling; explicit `billing=` wins. `no_commerce` is not read-only. Workspace defaults separately to `no_commerce`. |
| `MOBILERUN_CLOUD_PROXY_COUNTRY`, `MOBILERUN_CLOUD_PROXY_SMART_IP` | `us`, `true` | Default cloud proxy country and smart IP. Provisioning can cost money. |
| `MOBILERUN_CLOUD_BASE_URL` | `https://api.mobilerun.ai/v1` | Cloud API endpoint; explicit `base_url=` where accepted wins. |
| `MOBILERUN_CLOUD_API_TIMEOUT` | 10 seconds | Cloud API timeout. |
| `MOBILERUN_CLOUD_NUMBER_READY_TIMEOUT_SECONDS`, `MOBILERUN_CLOUD_APP_INSTALL_TIMEOUT_SECONDS` | 600, 180 seconds | Number readiness and app installation timeouts; explicit timeout overrides where offered. |
| `MOBILERUN_CLOUD_TASK_TIMEOUT_SECONDS`, `MOBILERUN_CLOUD_TASK_POLL_INTERVAL_SECONDS` | 1800, 2 seconds | Cloud task deadline and polling. |
| `MOBILERUN_AUTH_URL` | `https://cloud.mobilerun.ai/api/auth` | Device authentication endpoint. |
| `MOBILERUN_DEVICE_AUTH_REQUEST_TIMEOUT`, `MOBILERUN_DEVICE_AUTH_MIN_POLL_INTERVAL`, `MOBILERUN_DEVICE_AUTH_SLOW_DOWN_BUMP` | 10, 5, 5 seconds | Authentication request timeout and polling controls. |
| `MOBILERUN_STATE_RETRY_DELAYS`, `MOBILERUN_STATE_MAX_RETRIES`, `MOBILERUN_STATE_RECOVERY_AFTER_ATTEMPT`, `MOBILERUN_STATE_MAX_TIMEOUT_ATTEMPTS`, `MOBILERUN_STATE_SLOW_FETCH_NOTICE_S` | `[1,2,3,5,8,10]`, 7, 5, 2, 3 seconds | State retry, recovery and slow-fetch controls. |
| `MOBILERUN_MODEL_SCREENSHOT_MAX_SIDE` | 2048 | Fallback model screenshot maximum side; resize policy may select dimensions. |
| `MOBILERUN_MACRO_DELAY`, `MOBILERUN_MACRO_STATE_TIMEOUT`, `MOBILERUN_MACRO_STATE_THRESHOLD`, `MOBILERUN_MACRO_POLL_INTERVAL` | 1, 5, 0.85, 0.5 | Macro replay defaults; explicit `MacroPlayer` options win. Times are seconds. |
| `MOBILERUN_MACRO_DIRECTORY` | `<MOBILERUN_USER_CONFIG_DIR>/macros` | Default macro-list directory; explicit CLI directory wins. Empty uses the default. |
| `MOBILERUN_SANDBOX_DIRECTORY` | `<MOBILERUN_USER_CONFIG_DIR>/sandbox` | Local sandbox receipts and flow documents; empty uses the default. |
| `MOBILERUN_MCP_URL`, `MOBILERUN_MCP_SERVER_NAME` | `https://cloud.mobilerun.ai/api/mcp`, `mobilerun` | MCP connection URL and server key. |

`ConfigLoader.load()` resolves explicit path, existing `MOBILERUN_CONFIG`, user config, then package defaults. Loading may create or migrate files and write a backup. `DeviceConfig.device_id` defaults to `auto`; this config is distinct from an explicit device constructor argument and cloud creation behavior. See [device lifecycle](python-api.md#connect-and-close) before constructing a cloud device.

`mobilerun macro path --json`, `mobilerun sandbox path --json`, and `mobilerun credentials path --json` report the expanded absolute `path`, `exists`, and `source` (`env` or `default`) without creating the store.

## Shared models

`mobilerun.models` exports `Billing` (`no_commerce`, `included`, `paid`), phone `Plan` (`auto`, `minute`, `subscription`), and number/mailbox `ResourcePlan` (`auto`, `included`, `rent`). It also exports `App`, `DeviceFile`, `WorkspaceFile`, `Credential`, `Checkout`, `CloudCredentialReference`, `CloudTaskInputs`, `ExecutionResult`, `ExpectationResult` and `ExpectationVerdict`. These are value types, not clients. See [operators](operators-and-macros.md) for result handling and [billing](resources-and-billing.md) before cloud use.

| Model | Constructor fields (no default means required) |
| --- | --- |
| `App` | `package`, `version`, `name`; `id=None`, `version_code=None`, `path=None` (`Path`). |
| `DeviceFile` | `path`, `name`, nullable `size_bytes: int`, nullable `modified_at: datetime`. |
| `WorkspaceFile` | `id`, `name`, `mime_type`, `size_bytes`, `created_at: datetime`. |
| `Credential` | Nullable `package: str`, `name`, `fields: dict[str, str]`; representation hides field values. |
| `Checkout` | `url`, nullable `expires_at: datetime`, `resource`, `resource_id`; URL is sensitive. |
| `CloudCredentialReference` | `package: str`, `name: str`; frozen reference, not values. |
| `CloudTaskInputs` | `credential_references: tuple[CloudCredentialReference, ...] = ()`; validates tuple and reference fields. |
| `ExecutionResult[T]` | Required `success: bool`, `device: str`; optional `answer`, `output: T`, `steps`, `task_id`, `trajectory_path` default to `None`. `T` is a Pydantic model. |
| `ExpectationVerdict` | `passed: bool`, `reason: str`. |
| `ExpectationResult` | `passed: bool`, `condition: str`, `reason: str`, `task: ExecutionResult[ExpectationVerdict]`. Failed or inconclusive expectations may raise rather than return. |

## Configuration APIs

Import dataclasses from `mobilerun.config.user_config` (or root exports where available). `DeviceConfig` defaults: `serial=None`, `control_backend=None`, `device_id="auto"`, `use_tcp=False`, `platform="android"`, `portal_mode="auto"` (`auto`, `required`, `disabled`), `auto_setup=True`, `auth_token=None`. `resolve_auth_token()` uses a nonempty `MOBILERUN_DEVICE_TOKEN` before `auth_token`.

`TelemetryConfig(enabled=True)`; `TracingConfig(enabled=False, provider="phoenix", langfuse_screenshots=False, langfuse_secret_key="", langfuse_public_key="", langfuse_host="", langfuse_user_id="anonymous", langfuse_session_id="")`; `LoggingConfig(debug=False, level="normal", save_trajectory="none", trajectory_path="trajectories", rich_text=False, trajectory_gifs=True)`; level is quiet/normal/verbose/debug. Treat tracing credentials as secrets.

`MobileConfig` holds `device`, `telemetry`, `tracing`, `logging`, plus opaque dictionaries `agent`, `llm_profiles`, `tools`, `credentials`, `external_agents`, `mcp`. Direct construction defaults `agent` to `{"streaming": True}` and the others to empty dictionaries. `to_dict()` recursively serializes; `from_dict(data)` copies input, migrates an explicitly old `_version`, and validates opaque sections as mappings. Missing opaque sections become empty, including `agent`. `from_yaml(path)` reads YAML and delegates to `from_dict`; neither serialization method writes files. Do not mistake these opaque sections for validated agent settings.

`ConfigLoader.get_user_config_dir()` and `get_user_config_path()` return paths. `ConfigLoader.save(config)` writes the current version to the user path, creates its directory, and returns the path; it does not save back to an explicit load path. `ConfigLoader.load(path)` may initialize or migrate and rewrite files; migrations create an exclusive `.v<old>.bak` backup. Invalid or unreadable config raises `OutdatedConfigError`, a `ConfigError`; an existing backup can also prevent migration. `mobilerun.config.migrations.runner.get_migrations()` discovers versioned modules in order; `migrate(dict)` runs pending migrations through `CURRENT_VERSION` (currently 8). Treat migration as potentially modifying its input.

`PathResolver` lives in `mobilerun.utils.paths`; `PromptLoader` and `load_prompt_text` live in `mobilerun.utils.prompts`. `PathResolver.get_project_root()` returns the installed package root. `resolve(path, create_if_missing=False, must_exist=False)` expands `~`; absolute paths are used directly, relative reads prefer the working directory then package assets, and creation mode returns a working-directory path without creating it. `must_exist=True` raises `FileNotFoundError` for missing read paths. `PromptLoader.load_prompt(path, variables=None)` asynchronously reads and renders a template; `render_template(text, variables=None)` renders directly in an immutable Jinja sandbox. Missing variables render empty; unsafe access can raise a Jinja security error. Do not insert secrets into prompts or logs.

`Settings()` / `get_settings()` from `mobilerun.config.settings`, `Secrets()` / `get_secrets()` from `mobilerun.config.env`, `MacroSettings()` / `get_macro_settings()` from `mobilerun.macro.settings`, and `MCPSettings()` / `get_mcp_settings()` from `mobilerun.mcp.settings` create fresh snapshots. Secret fields are `SecretStr`; use `secret_value()` only at the point needed, never print it. `Settings.local_credentials_path` and `mobilerun_cloud_credential_path` expose resolved path properties.

The `MOBILERUN_AGENTS` JSON maps agent names to `AgentPaths(skills, mcp, mcp_format=None)`: each path pair is `(user, project)` with optional project path. `mobilerun.mcp.settings.MCPFormat` requires `servers_key` and accepts `entry_type=None`, `api_key_ref=None`, `bearer_token_env_var=False`, `user_api_key=True`, `nested_servers=False`, `disable_oauth_with_api_key=False`, `jsonc_alternative=False`, `oauth_sign_in=None`. These describe agent-specific config and auth formats; they do not store an API key.
