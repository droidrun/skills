# Sandbox cloud functions

Install `pip install 'mobilerun[sandbox]'` and configure Mobilerun Cloud credentials. The plugin uses `mobilerun-functions[device]==0.1.0` (`mobilerun_functions`), not `mobilerun-routines`.

## Declare and deploy

Save as `hello.py`. Importing or running the file does not deploy it; calling `hello(Input())` runs locally.

```python
from pydantic import BaseModel

from mobilerun.sandbox import cloud


class Input(BaseModel):
    name: str = "world"


class Output(BaseModel):
    message: str


@cloud("hello")
def hello(input: Input) -> Output:
    return Output(message=f"Hello, {input.name}!")
```

| Declaration | Deployment |
| --- | --- |
| `@cloud("hello")` | Authenticated endpoint by default. |
| `@cloud("hello", schedule="0 6 * * *")` | Five-field UTC cron instead of an endpoint; `fire` does not trigger cron. |
| `@cloud("hello", endpoint=False)` | Function only; omit `schedule` for no flow. |

Use one top-level declaration per file, the canonical import above, literal decorator arguments and in-file Pydantic models. Put helpers, constants and lazy imports used by the function in its body; sibling files, assets and arbitrary dependencies are not bundled. Endpoint input schemas containing `$ref` are rejected. Deploy only trusted source: local inspection executes generated Python.

For phone access, add `ctx: Context` (`from mobilerun_functions import Context`) and use `ctx.device()`. Set `device=` on the declaration or override it with `--device ID` or `--device-free`. With no device, endpoints default to device-free; for a schedule with no decorator device, choose via the interactive picker or pass an explicit flag in automation. Sandbox does not provision or delete phones.

**Deploy, fire and enable require `paid` and can incur charges even without a phone. An enabled schedule can incur future charges after the CLI exits.** `MOBILERUN_BILLING` defaults to `paid`; explicit `--billing` or `billing=` wins. Reads, polling, disable and owned cleanup permit `no_commerce`. CLI mutations require interactive consent or `--yes`; pass `--yes` only after approval. Python deployment is explicit: `deploy("hello.py", yes=True)` (or pass `confirm=`) from `mobilerun.sandbox`. Calling a Python remote mutation is explicit authorization; it does not prompt.

```sh
mobilerun sandbox deploy hello.py
mobilerun sandbox fire hello --input '{"name":"Ada"}'
mobilerun sandbox runs hello --billing no_commerce
```

`fire` returns an invocation ID without waiting. Use `--input-file FILE` instead of `--input` to load a JSON object from a file. Use `mobilerun sandbox list` to inspect functions and `mobilerun sandbox enable NAME` or `mobilerun sandbox disable NAME` to toggle owned flows. Disable schedules you no longer need. Both toggles accept multiple names and return a per-name `{name, status}` array with `--json`. See the [CLI index](cli.md#sandbox) for flags.

## Remote and Run handles

`hello.remote` is a typed `Remote`; `cloud["hello"]` is a lazy untyped handle returning plain JSON. Neither deploys implicitly. After authorization, `run = hello.remote.fire(name="Ada")` starts a potentially paid invocation and returns a `Run`; `hello.remote(name="Ada")` fires and waits. Pass keyword payload values or `input=` (mapping or Pydantic model), not both. Payload fields named `input` or `billing` belong inside the mapping.

`Run` exposes `invocation_id`, execution `id`, `status`, timestamps, `duration` and `snapshot`. `run.result(timeout=300)` waits and validates typed output when applicable; timeout does not cancel execution. Run failures raise; partial results may still return typed output with partial metadata in `snapshot`. Use `run.logs()` for logs and `remote.runs()` for recent executions. These APIs are synchronous; do not call them from a running event loop.

## Local store and ownership

`mobilerun sandbox path --json` reports the expanded absolute path without authenticating or creating it. The default is `<MOBILERUN_USER_CONFIG_DIR>/sandbox`; set `MOBILERUN_SANDBOX_DIRECTORY` to relocate it (empty uses the default).

Deployments write `receipt.json` and, for flows, `flow.yaml` under directories hashed by API origin/key fingerprint and declaration name. The receipt records verified IDs and partial progress; flow YAML and matching names do not establish ownership. Preserve the receipt and original source after a partial deploy. Changing origin or rotating the API key selects a different scope. Schedule replacement can miss a firing; do not assume exactly-once cutover.
