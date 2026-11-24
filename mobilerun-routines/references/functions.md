# Serverless Functions

Use a function for saved Python logic; use a sandbox for temporary commands and
shared files. Functions consume function minutes. Obtain permission for that
usage before running; see [function usage](https://docs.mobilerun.ai/credits).
Python helpers need Python 3.11–3.13 and the optional
`mobilerun-functions` package; routine-only work needs neither.

## Write, inspect, and run locally

Use a private virtual environment. The scaffold command is `new`, not `init`.

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
python -m pip install mobilerun-functions==0.1.0
python -m mobilerun_functions new title.py
)
```

Replace `title.py` with this short example. It fetches one HTTPS URL and returns
its title. Change the approved hostname in both the input and upload manifest.
The manifest restricts hosted networking; do not use credentials or secrets in
source or input. Keep all code in one file and work inside the entry point:
inspection imports the file and runs top-level code.

```python
import html
import re
from urllib.request import urlopen
from pydantic import BaseModel
from mobilerun_functions import Context, script


class Input(BaseModel):
    url: str = "https://example.com"


class Output(BaseModel):
    title: str


@script
def main(input: Input, ctx: Context) -> Output:
    with urlopen(input.url, timeout=20) as response:
        page = response.read(262144).decode("utf-8")
    match = re.search(r"<title[^>]*>(.*?)</title>", page, re.I | re.S)
    if match is None:
        raise ValueError("Page has no title")
    ctx.log.info("title extracted")
    return Output(title=html.unescape(match.group(1)).strip())
```

Use exactly one bare `@script`, a Pydantic input model, and a supported typed
return. Inspection checks the contract; local execution checks code locally;
only a hosted run proves the cloud path.

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
python -m mobilerun_functions inspect title.py > inspection.json
printf '{"url":"https://example.com"}\n' > input.json
python -m mobilerun_functions run title.py --input-file input.json --result-file result.json
jq '{ok,outcome,result}' result.json
jq -n --rawfile source title.py \
  '{source:$source,manifest:{hosts:["example.com"],credentials:[],scopes:[]}}' > source-body.json
curl --fail-with-body -sS "$BASE/compute/functions/validations?waitS=25" -H @<(auth_header) \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $(uuidgen)" \
  --data-binary @source-body.json > source-validation.json
VALIDATION_ID=$(jq -er '.data.id' source-validation.json)
DEADLINE=$((SECONDS + 120))
until curl --fail-with-body -sS "$BASE/compute/functions/validations/$VALIDATION_ID?waitS=25" -H @<(auth_header) > source-validation.json \
  && jq -e '.data.status != "pending"' source-validation.json > /dev/null; do
  [ "$SECONDS" -lt "$DEADLINE" ] || { printf 'Source validation pending\n' >&2; exit 1; }
  sleep 3
done
jq '.data' source-validation.json
jq -e '.data.valid == true' source-validation.json
)
```

If validation is pending, poll with a bounded deadline. Inspect errors and
warnings before uploading. Rejected validation is not permission to skip it.

## Upload and wait for a ready version

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
jq '. + {name:"Page title"}' source-body.json > upload.json
UPLOAD_KEY=$(uuidgen)
curl --fail-with-body -sS "$BASE/compute/functions" -H @<(auth_header) \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $UPLOAD_KEY" \
  --data-binary @upload.json > function.json
FUNCTION_ID=$(jq -er '.data.id' function.json)
VERSION=$(jq -er '.data.latestVersion.version' function.json)
printf 'FUNCTION_ID=%q\nVERSION=%q\n' "$FUNCTION_ID" "$VERSION" >> mobilerun-state.sh
)
```

Poll the version until `ready` or `rejected`, with a bounded deadline:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
DEADLINE=$((SECONDS + 120))
until curl --fail-with-body -sS "$BASE/compute/functions/$FUNCTION_ID/versions/$VERSION" -H @<(auth_header) > version.json \
  && jq -e '.data.status == "ready" or .data.status == "rejected"' version.json > /dev/null; do
  [ "$SECONDS" -lt "$DEADLINE" ] || { printf 'Version inspection pending\n' >&2; exit 1; }
  sleep 3
done
jq '.data | {version,status,inspectError}' version.json
jq -e '.data.status == "ready"' version.json
)
```

On rejection, inspect `inspectError`, fix the source, then upload a new immutable
version. This updates an existing function without changing its stable ID:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
curl --fail-with-body -sS "$BASE/compute/functions/$FUNCTION_ID/versions" -H @<(auth_header) \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $(uuidgen)" \
  --data-binary @source-body.json > new-version.json
jq '.data' new-version.json
VERSION=$(jq -er '.data.version' new-version.json)
printf 'VERSION=%q\n' "$VERSION" >> mobilerun-state.sh
)
```

Read its returned version number and wait for readiness as above. Do not assume
that an accepted upload is runnable or that latest equals latest ready.

## Direct hosted run and logs

Use the ready `VERSION`. Direct runs need no device unless the code needs one.

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
jq -n --argjson version "$VERSION" --slurpfile input input.json \
  '{version:$version,input:$input[0],timeoutS:60,waitS:30}' > function-run-body.json
RUN_KEY=$(uuidgen)
curl --fail-with-body -sS "$BASE/compute/functions/$FUNCTION_ID/runs" -H @<(auth_header) \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $RUN_KEY" \
  --data-binary @function-run-body.json > function-run.json
RUN_ID=$(jq -er '.data.id' function-run.json)
printf 'RUN_ID=%q\n' "$RUN_ID" >> mobilerun-state.sh
curl --fail-with-body -sS "$BASE/compute/runs/$RUN_ID?waitS=30" -H @<(auth_header) > function-result.json
jq '.data | {status,outcome,result,errorCode,errorText,stdout,stderr,truncated,logs}' function-result.json
)
```

HTTP 200/202 alone is not success. Poll until terminal and require a successful
outcome plus the expected result. Partial results need explicit user acceptance.
List summaries omit results; fetch the individual run for full output. When its
`logs` field is neither `none` nor `gone` (it may still be `pending`), poll
for a short-lived download link:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
curl --fail-with-body -sS "$BASE/compute/functions/$FUNCTION_ID/runs" -H @<(auth_header) | jq '.data'
LOG_DEADLINE=$((SECONDS + 60))
while :; do
  LOG_STATUS=$(curl -sS "$BASE/compute/runs/$RUN_ID/logs" -H @<(auth_header) \
    -o log-link.json -w '%{http_code}')
  [ "$LOG_STATUS" = 200 ] && break
  if [ "$LOG_STATUS" != 404 ] || ! jq -e '.. | strings | select(. == "logs_not_available")' log-link.json > /dev/null; then
    jq . log-link.json
    exit 1
  fi
  [ "$SECONDS" -lt "$LOG_DEADLINE" ] || { printf 'Logs still unavailable\n' >&2; exit 1; }
  sleep 1
done
LOG_URL=$(jq -er '.data.url' log-link.json)
curl --fail-with-body -sS "$LOG_URL" -o function.log
)
```

Do not forward API authorization to the log URL. A short window after completion
can return 404 `logs_not_available` for a few seconds after the run ends;
re-read the run's log state and poll within
a bounded deadline. Persistent unavailability or an expired retention period
needs reporting; do not relaunch side effects just to get logs. Keep log links
private and request a new one after expiry.

SDK **6.3.2** equivalents (with an authenticated `mobilerun` client and the
returned `RUN_ID`): wait for logs before requesting the link. See the
[function-run helpers](https://docs.mobilerun.ai/sdk/helpers#function-runs) for
wait options and errors; do not re-run work merely to obtain logs.

```typescript
const run = mobilerun.compute.runs.fromId(RUN_ID); await run.waitLogs(); const logs = await run.logs();
```

```python
run = mobilerun.compute.runs.from_id(RUN_ID); run.wait_logs(); logs = run.logs()
```

The direct-run examples above apply only to directly started function runs.
For routine steps, inspect the execution's step body for stdout, stderr and
errors; its function run ID cannot be read through these direct-run routes.

## Use as a routine step

Choose the function step from the live catalog and read its entire
`paramsSchema` and `outputSchema`. **Example — check the catalog:** the public
step name may be `functions.run`. Bind the stable function ID, a ready version,
and input in that entry's required shape. Pin the version for reproducibility.
Copy no service identifiers or internal API routes into a document.

Bind the uploaded ID, pinned ready version, and tested input using the live
catalog, then follow the golden path. No phone is needed for a device-free step.
See [using a function in a routine](https://docs.mobilerun.ai/routines/functions#use-it-in-a-routine).

On `429 concurrency_limit`, wait for the admitted run or sandbox to finish and
respect the returned retry delay. Retry the same logical request with its saved
idempotency key. Do not create extra environments to get around capacity.

## Cleanup

After deleting disposable routines that use the test function:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
curl --fail-with-body -sS -X DELETE "$BASE/compute/functions/$FUNCTION_ID" -H @<(auth_header)
)
```

Keep functions needed by the user's retained routine.
More depth: https://docs.mobilerun.ai/routines/functions.
