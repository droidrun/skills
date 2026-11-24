# CLI command index

Reflects the Mobilerun 0.7.4 CLI. Deprecated top-level and device aliases are unavailable; use the command paths below. Run `mobilerun <command> --help` for complete options and authoritative argument details. Macro, mcp, sandbox and skills register via `mobilerun.cli` entry points; sandbox deployments require the `sandbox` extra. The optional `agent` group requires `mobilerun-agents` and is not indexed here.

⚠ means a command can change local or remote state, destroy data, incur charges or consume credits. Unmarked does not guarantee read-only or free behavior; check help and billing policy. `number create`, `mailbox create` and `proxy buy` can purchase; `number bind` and `proxy bind` attach existing resources rather than purchase. Task execution can consume credits. `--billing no_commerce` is not a general read-only guard. `--yes` applies only where offered.

## account

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun account` | — | — |  Manage cloud authentication. |
| `mobilerun account login` | — | --api-key, --auth-url, --client-id, --billing | ⚠ Log in to Mobilerun Cloud |
| `mobilerun account logout` | — | — | ⚠ Remove the saved Mobilerun cloud login. |
| `mobilerun account status` | — | --json, --billing |  Show the current cloud account |
## completion

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun completion` | [[zsh|bash|fish]] | --print, --yes |  ⚠ Install completion for SHELL, or print it when output is redirected. |
## credentials

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun credentials` | — | — |  Manage credentials for agent tasks. |
| `mobilerun credentials delete` | [PACKAGE] [NAME] [FIELD] | --yes, --local | ⚠ Delete a credential or one field. |
| `mobilerun credentials list` | — | --package, --json, --local, --vault |  List names and field names without values. |
| `mobilerun credentials path` | — | --json | Show the local credentials file path. |
| `mobilerun credentials save` | [PACKAGE] [NAME] | --field, --from-json, --local | ⚠ Save fields from hidden prompts or a JSON object in FILE (or -). |
| `mobilerun credentials update` | [PACKAGE] [NAME] [FIELD] | --stdin, --local | ⚠ Update one field from a hidden prompt or stdin. |
## device

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun device` | — | — |  Manage and control devices. |
| `mobilerun device action` | — | — |  Inspect and invoke device and extension actions. |
| `mobilerun device action call` | [ACTION] [DEVICE] | --arg, --json, --android, --ios |  ⚠ Call an action on the selected device. |
| `mobilerun device action extensions` | [DEVICE] | --json, --android, --ios, --cloud |  List bound extensions and their context. |
| `mobilerun device action list` | [DEVICE] | --json, --android, --ios, --cloud |  List callable device and extension actions. |
| `mobilerun device app` | — | — |  Manage installed apps and open links. |
| `mobilerun device app install` | [APK] [DEVICE] | --app-id, --reinstall, --grant, --android | ⚠ Install an app on a device. |
| `mobilerun device app list` | [DEVICE] | --system, --json, --android, --ios |  List installed apps. |
| `mobilerun device app open` | URL [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Open a URL or deep link. |
| `mobilerun device app start` | [PACKAGE] [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Launch an app by package name. |
| `mobilerun device app stop` | [PACKAGE] [DEVICE] | --android, --ios, --cloud, --remote | ⚠ Stop an installed app. |
| `mobilerun device app uninstall` | [PACKAGE] [DEVICE] | --yes, --android, --ios, --cloud | ⚠ Uninstall an app by package name. |
| `mobilerun device cloud` | — | — |  Manage cloud phone lifecycle without connecting to the phone. |
| `mobilerun device cloud reboot` | [DEVICE] | --yes, --android, --ios, --cloud |  ⚠ Reboot a cloud phone. |
| `mobilerun device cloud rename` | [DEVICE] [NAME] | --json, --device, --cloud | ⚠ Rename a cloud phone without opening a device connection. |
| `mobilerun device cloud resume` | [DEVICE] | --yes, --android, --ios, --cloud |  ⚠ Resume a stopped cloud phone. |
| `mobilerun device cloud status` | [DEVICE] | --json, --android, --ios, --cloud |  Print cloud phone status. |
| `mobilerun device cloud stop` | [DEVICE] | --android, --ios, --cloud, --remote | ⚠ Stop a cloud phone without deleting it. |
| `mobilerun device cloud terminate` | [DEVICE] | --yes, --android, --ios, --cloud | ⚠ Permanently delete a cloud phone and its data. |
| `mobilerun device connect` | [TARGET] | — |  ⚠ Choose default device |
| `mobilerun device disconnect` | [TARGET] | — | ⚠ Clear the default, or disconnect a specific network device. |
| `mobilerun device file` | — | — |  Transfer and manage device files. |
| `mobilerun device file list` | [DIRECTORY] [DEVICE] | --json, --android, --ios, --cloud |  List files on a device. |
| `mobilerun device file pull` | REMOTE [LOCAL] [DEVICE] | --android, --ios, --cloud, --remote |  Pull a file from a device. |
| `mobilerun device file push` | [PATH] [DEVICE] | --dest, --file-id, --android, --ios | ⚠ Push a local or workspace file to a device. |
| `mobilerun device file rm` | REMOTE [DEVICE] | --yes, --android, --ios, --cloud | ⚠ Delete a file from a device. |
| `mobilerun device input` | — | — |  Send input and manage the clipboard. |
| `mobilerun device input clipboard` | — | — |  Read or set the device clipboard. |
| `mobilerun device input clipboard get` | [DEVICE] | --android, --ios, --cloud, --remote |  Print clipboard text. |
| `mobilerun device input clipboard set` | TEXT [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Set clipboard text. |
| `mobilerun device input long-press` | X Y [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Long press at screen coordinates. |
| `mobilerun device input press` | {back|home|enter} [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Press a system button. |
| `mobilerun device input swipe` | X1 Y1 X2 Y2 [DEVICE] | --duration, --android, --ios, --cloud |  ⚠ Swipe from (x1, y1) to (x2, y2). |
| `mobilerun device input tap` | X Y [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Tap at screen coordinates. |
| `mobilerun device input type` | TEXT [DEVICE] | --clear, --android, --ios, --cloud |  ⚠ Type text into the currently focused field. |
| `mobilerun device list` | — | --json, --cloud, --base-url, --billing |  List connected local devices and authenticated cloud devices. |
| `mobilerun device ping` | [DEVICE] | --debug, --android, --ios, --cloud |  Ping a device to check if it is ready and accessible. |
| `mobilerun device screen` | — | — |  Capture screenshots and inspect the UI. |
| `mobilerun device screen screenshot` | [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Take a screenshot and print the saved file path to stdout. |
| `mobilerun device screen ui` | [DEVICE] | --raw, --android, --ios, --cloud |  Print the UI accessibility tree with element bounds for targeting. |
| `mobilerun device settings` | — | — |  ⚠ Manage location, language and timezone. |
| `mobilerun device settings language` | — | — |  ⚠ Read or set the device language. |
| `mobilerun device settings language get` | [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Print the device language. |
| `mobilerun device settings language set` | LOCALE [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Set a locale such as de-DE. |
| `mobilerun device settings location` | — | — |  ⚠ Read, set or reset the device location. |
| `mobilerun device settings location get` | [DEVICE] | --json, --android, --ios, --cloud |  ⚠ Print the device location. |
| `mobilerun device settings location reset` | [DEVICE] | --android, --ios, --cloud, --remote | ⚠ Reset the device location. |
| `mobilerun device settings location set` | LATITUDE LONGITUDE [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Set latitude and longitude. |
| `mobilerun device settings timezone` | — | — |  ⚠ Read or set the device timezone. |
| `mobilerun device settings timezone get` | [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Print the IANA timezone. |
| `mobilerun device settings timezone set` | TIMEZONE [DEVICE] | --android, --ios, --cloud, --remote |  ⚠ Set the IANA timezone. |
| `mobilerun device setup` | [DEVICE] | --path, --portal-version, --latest, --debug | ⚠ Install and enable the Mobilerun Portal on a device. |
## doctor

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun doctor` | [DEVICE] | --debug, --fix, --android, --ios |  Check system health and diagnose issues. |
## macro

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun macro` | — | — |  Replay recorded automation sequences. |
| `mobilerun macro list` | [DIRECTORY] | --debug, --json |  List available trajectory folders in a directory. |
| `mobilerun macro path` | — | --json | Show the configured macro directory. |
| `mobilerun macro replay` | PATH [DEVICE] | --on-mismatch, --provider, --model, --delay | ⚠ Replay strictly |
## mailbox

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun mailbox` | — | — |  Manage cloud email mailboxes. |
| `mobilerun mailbox code` | MAILBOX | --sender, --timeout, --billing |  Wait for a verification code from MAILBOX, the mailbox ID. |
| `mobilerun mailbox create` | — | --json, --plan, --yes, --payment-timeout | ⚠ Create a cloud mailbox. |
| `mobilerun mailbox included` | — | --json, --billing |  Show remaining included mailboxes. |
| `mobilerun mailbox list` | — | --json, --billing |  List cloud mailboxes. |
| `mobilerun mailbox messages` | MAILBOX | --json, --billing | List received email summaries, not OTP values. |
| `mobilerun mailbox release` | MAILBOX... | --json, --yes, --billing | ⚠ Release one or more mailboxes. |
| `mobilerun mailbox status` | MAILBOX | --json, --billing |  Show a mailbox's lifecycle state. |
## mcp

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun mcp` | — | — |  Manage coding-agent MCP connections. |
| `mobilerun mcp install` | — | --agent, --project, --force, --api-key | ⚠ Install the public Mobilerun MCP server. |
| `mobilerun mcp list` | — | — |  Show installation status by agent and scope. |
| `mobilerun mcp uninstall` | — | --agent, --project | ⚠ Remove the Mobilerun MCP server. |
## number

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun number` | — | — |  Manage cloud phone numbers. |
| `mobilerun number bind` | NUMBER DEVICE | --json, --billing | ⚠ Bind NUMBER to cloud phone DEVICE. |
| `mobilerun number code` | NUMBER | --sender, --timeout, --billing |  Wait for an SMS code from NUMBER, the phone number ID. |
| `mobilerun number countries` | — | --json, --billing |  List supported number countries. |
| `mobilerun number create` | — | --country, --billing, --json, --plan, --yes, --payment-timeout | ⚠ Create a cloud phone number; interactive country picker if omitted. |
| `mobilerun number included` | — | --country, --json, --billing | Show remaining included quota for all countries or one country. |
| `mobilerun number list` | — | --json, --billing |  List cloud phone numbers. |
| `mobilerun number messages` | NUMBER | --json, --billing |  List SMS message history. |
| `mobilerun number release` | NUMBER... | --json, --yes, --billing | ⚠ Release one or more cancellable numbers. |
| `mobilerun number send` | NUMBER TO TEXT | --yes, --billing | ⚠ Send an SMS (may incur charges). |
| `mobilerun number status` | NUMBER | --json, --billing |  Show a number's lifecycle state and binding. |
| `mobilerun number unbind` | NUMBER... | --json, --yes, --billing | ⚠ Unbind one or more numbers from their cloud phones. |
## plugins

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun plugins` | — | — | Inspect installed plugins. |
| `mobilerun plugins list` | — | --check, --json | List plugins; --check imports plugin code. |
## proxy

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun proxy` | — | — |  Manage Connect proxies. |
| `mobilerun proxy bind` | PROXY_ID DEVICE_ID | --json, --force, --billing | ⚠ Bind an existing Connect proxy to a cloud phone. |
| `mobilerun proxy buy` | — | --json, --yes, --payment-timeout, --country | ⚠ Buy a Connect proxy. |
| `mobilerun proxy list` | — | --json, --billing |  List Connect proxies. |
| `mobilerun proxy release` | PROXY_ID... | --yes, --json, --billing | ⚠ Release proxies and disconnect phones using them. |
| `mobilerun proxy status` | PROXY_ID | --json, --billing |  Show status for PROXY_ID, the proxy ID. |

## sandbox

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun sandbox` | — | — | Deploy and run cloud functions. |
| `mobilerun sandbox deploy` | FILE | --device, --device-free, --billing, --yes, --json | ⚠ Deploy a declaration; may incur charges. |
| `mobilerun sandbox list` | — | --billing, --json | List cloud functions visible to the current credentials; listing does not establish ownership. |
| `mobilerun sandbox fire` | NAME | --input, --input-file, --billing, --yes, --json | ⚠ Invoke an endpoint and return its invocation ID without waiting. |
| `mobilerun sandbox runs` | NAME | --limit, --billing, --json | List recent runs (default limit: 10). |
| `mobilerun sandbox enable` | NAME... | --billing, --yes, --json | ⚠ Enable owned flows; future runs may incur charges. |
| `mobilerun sandbox disable` | NAME... | --billing, --yes, --json | ⚠ Disable owned flows. |
| `mobilerun sandbox path` | — | --json | Show the local sandbox store path. |

## skills

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun skills` | — | — |  Manage skills for coding agents. |
| `mobilerun skills install` | [NAMES]... | --all, --agent, --project, --dir | ⚠ Install skills for an agent |
| `mobilerun skills list` | — | --long, --json |  List skills and installed targets |
| `mobilerun skills show` | NAME | — |  Show a bundled skill's path and description. |
| `mobilerun skills uninstall` | NAMES... | --agent, --project, --dir | ⚠ Remove installed skills. |
## workspace

| Command | Arguments | Key flags | Purpose / risk |
| --- | --- | --- | --- |
| `mobilerun workspace` | — | — |  Manage workspace files and apps. |
| `mobilerun workspace apps` | — | — |  Manage the workspace app library. |
| `mobilerun workspace apps list` | — | --json |  List workspace apps. |
| `mobilerun workspace apps remove` | APP_ID... | --json, --yes | ⚠ Delete workspace apps. |
| `mobilerun workspace apps upload` | APK | --json | ⚠ Upload an APK to the workspace. |
| `mobilerun workspace files` | — | — |  Manage workspace files. |
| `mobilerun workspace files download` | FILE_ID [DEST] | --json |  Download a workspace file. |
| `mobilerun workspace files list` | — | --json |  List workspace files. |
| `mobilerun workspace files rm` | FILE_ID... | --json, --yes | ⚠ Delete workspace files (`remove` is a hidden alias). |
| `mobilerun workspace files upload` | PATHS... | --json | ⚠ Upload local files to the workspace. |

## Task workflows

### Device selection and replay

For device-aware commands, positional `DEVICE` or `--device` wins; conflicting explicit values are an error. Otherwise a saved default is used, then discovery. A saved non-URL default must still appear in discovery or selection fails; it does not silently switch phones. One discovered device is selected automatically; several prompt interactively or fail non-interactively with candidates. Explicit Android serials include `host:port`; a UUID is inferred as cloud. Non-UUID cloud IDs need `--cloud`. Explicit HTTP URLs require `--ios`, `--android` (Portal HTTP), or `--remote`, except when matching the saved URL/config platform. Type flags are mutually exclusive; `--tcp` is Android-only and `--base-url` cloud-only. `mobilerun device connect TARGET` saves the default; disconnect can clear it.

`mobilerun macro replay PATH --dry-run` loads the JSON file or trajectory folder and prints the selected actions without opening a device; it still resolves CLI configuration. `--start-from` is **1-based**, `--max-steps` limits the selected range (zero allowed); Python's `start_from_step` is zero-based. `--delay`, `--state-timeout`, and `--state-threshold` control replay. Default `--on-mismatch stop` is strict. `--on-mismatch agent` needs the optional agent handoff integration and can consume LLM tokens; without it the command errors, rather than silently falling back. `--provider` and `--model` must be supplied together. Reset to the recorded starting screen before real replay.

`mobilerun macro path --json` reports the default directory used by `macro list` without an explicit directory. `mobilerun device cloud rename DEVICE NAME --json` updates an existing phone's name and returns `{id, name}`; omitting `NAME` prompts only interactively.

### MCP and skills installation

`mobilerun mcp install --agent NAME` installs user scope by default; `--project` selects project scope, `--force` replaces an existing server entry. OAuth is the default: complete the agent's sign-in instructions. `--api-key` configures a reference to `MOBILERUN_API_KEY`, not a literal key; set it in the agent environment. Claude Code's user-scope API-key mode is rejected; use project scope or OAuth. Default agents: Claude Code (`/mcp`), Codex (`codex mcp login mobilerun`), OpenCode (`opencode mcp auth mobilerun`), Cursor (MCP settings). Codex project configuration requires trust. `mcp list` reports agent/scope status; `mcp uninstall --agent NAME [--project]` removes that scope's server entry. Missing agent prompts only interactively; non-interactive use must specify it. Paths and auth formats can be overridden with the `MOBILERUN_AGENTS` registry; see [settings](errors-and-config.md#configuration-apis).

`mobilerun skills install single NAME --agent NAME` installs individual skills; `skills install bundle FOLDER --agent NAME` installs a bundle folder. `--all` chooses all bundled folders; without names an interactive picker offers everything, bundle or single where applicable. Explicit names and `--all` conflict. `--project` changes scope; `--dir PATH` overrides the destination. Existing installs are left alone unless `--force`; force replaces only managed destinations, not arbitrary user directories. `skills uninstall NAME --agent NAME` removes managed installs only, reporting unmanaged or missing destinations without deleting them. Both commands mutate local files; inspect the destination first. The `.mobilerun-installed` marker or an exact match to a recognized source tree establishes ownership; symlinks are not managed. This is not a general backup.

### Confirmations

Mutation commands differ: some prompt, some act immediately, and only commands advertising `--yes` accept it. `--yes` skips that command's confirmation; it is not blanket consent for other commands or an override of billing guards. Non-interactive callers must provide required arguments and any applicable confirmation flag; do not assume a prompt is possible. Always check the individual `--help` and authorize destructive or paid operations before running them.

All commands require appropriate authorization. Substitute IDs; never release borrowed resources. `no_commerce` blocks purchases, not mutations or usage charges. Run each command with `--help` for complete options.

`number release`, `number unbind`, `mailbox release`, `proxy release`, `workspace files rm` and `workspace apps remove` accept multiple IDs, or offer interactive multiselect when none are given. They confirm once. With `--json` they return an array even for one ID: each row has `id` and `status`, with `error` on failure. A failed item does not stop the batch; any failure yields exit code 1. In automation, pass explicit IDs and `--yes` only after authorization.

- **Proxy:** `mobilerun proxy list --billing no_commerce` → `mobilerun proxy status PROXY_ID --billing no_commerce` → `mobilerun proxy bind PROXY_ID DEVICE_ID --force --billing no_commerce`. Binding changes the phone. **Paid:** `mobilerun proxy buy --country US --type dedicated_residential --billing paid`. Release is destructive.
- **Number:** `mobilerun number countries --billing no_commerce` → `mobilerun number create --country US --plan included --billing included` (creates an owned resource; included quota). **Paid rental:** use `--plan rent --billing paid`. Then `mobilerun number bind NUMBER DEVICE --billing no_commerce`, `mobilerun number messages NUMBER --billing no_commerce`, or `mobilerun number code NUMBER --sender Example --billing no_commerce`. **Paid SMS:** `mobilerun number send NUMBER TO TEXT --billing paid` prompts for confirmation. Release only your owned number.
- **Mailbox:** `mobilerun mailbox create --plan included --billing included` creates an owned mailbox from quota; rent with `--plan rent --billing paid` can cost money. Retrieve its ID, then `mobilerun mailbox code MAILBOX --sender Example --billing no_commerce`. `mobilerun mailbox release MAILBOX` is destructive.
- **Workspace:** `mobilerun workspace files upload PATH` mutates cloud storage → `mobilerun workspace files list` → `mobilerun workspace files download FILE_ID DEST`. `mobilerun workspace files rm FILE_ID` deletes; cloud storage may have costs. `mobilerun workspace apps upload APK` uploads an app.
- **Credentials:** `mobilerun credentials list --vault` shows metadata → `mobilerun credentials save PACKAGE NAME --field password` prompts for a secret. Do not put secrets in shell arguments or logs. `credentials update` changes and `credentials delete` destroys vault or local data; check `--help`.

Legacy `run` and `configure` forward to the installed `agent` plugin (`agent run` and `agent llm configure` respectively). Macro replay agent fallback loads the `agent_macro` operator entry point. LLM execution may incur token costs.
