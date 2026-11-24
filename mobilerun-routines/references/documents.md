# Routine documents

Read this when drafting, validating, exporting, or replacing a routine. Fetch
`GET /flows/document-schema` first. It includes the current anatomy, trigger
alternatives, step parameters and output schemas. Do not keep a local field
catalog. Build one trigger and ordered, uniquely identified steps; pass data
using the live template grammar. A stable step ID lets later steps reference
its output. Device-free eligibility comes from the selected catalog entries.

Start from the [live document templates](https://docs.mobilerun.ai/routines/documents#copy-a-template),
then refresh the schema and catalog before adapting one. Templates do not replace
live discovery or validation; never invent a step or its required parameters.

## JSON or YAML

Both represent the same document. The API accepts a document object, not a
YAML string. Keep `routine.json` as the single source for validation and
replacement. Export before editing using the block below; do not export again
on top of an edit. With Python and the optional PyYAML parser in a private
virtual environment, convert the saved JSON to YAML:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
python -m pip install PyYAML
python - <<'PYTHON'
import json
from pathlib import Path
import yaml

Path("routine.yaml").write_text(yaml.safe_dump(
    json.loads(Path("routine.json").read_text()), sort_keys=False))
PYTHON
)
```

Edit `routine.yaml`, then write it **back to `routine.json`** before running the
golden-path validation or the replace block:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
python - <<'PYTHON'
import json
from pathlib import Path
import yaml

Path("routine.json").write_text(json.dumps(
    yaml.safe_load(Path("routine.yaml").read_text())))
PYTHON
)
```

Quote the root `"on":` key in YAML: YAML 1.1 parsers such as PyYAML can
otherwise interpret `on` as a boolean. Use `safe_load`, never an unsafe loader.

Inspect `data.valid`, errors, warnings, JSON Pointer paths, and repair hints.
A 200 response can still mean an invalid document. Fix the indicated location;
do not discard unknown fields until you understand their purpose. Re-fetch the
schema for unsupported steps or parameters. Validation checks configuration,
not live business success or external side effects.

## Export and replace safely

Save the current canonical document before editing:

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID/document" -H @<(auth_header) > exported.json
jq '.data' exported.json > routine.json
)
```

Replacement is a full document operation, not a patch. Export first, preserve
all values you want to keep, show the diff, validate, and pause before replacing:
enabled state is preserved. Read the [replacement semantics](https://docs.mobilerun.ai/routines/documents#replace)
before omitting fields or settings.

```bash
(
set -euo pipefail
. ./mobilerun-env.sh
curl --fail-with-body -sS -X PATCH "$BASE/flows/$FLOW_ID" -H @<(auth_header) \
  -H 'Content-Type: application/json' -d '{"enabled":false}' | jq '.data'
jq -n --slurpfile document routine.json '{document:$document[0]}' > document-body.json
curl --fail-with-body -sS "$BASE/flows/document/validate" -H @<(auth_header) \
  -H 'Content-Type: application/json' --data-binary @document-body.json > validation.json
jq -e '.data.valid == true' validation.json
curl --fail-with-body -sS -X PUT "$BASE/flows/$FLOW_ID/document" -H @<(auth_header) \
  -H 'Content-Type: application/json' --data-binary @document-body.json | jq '.data.flow'
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID/document" -H @<(auth_header) > replaced-document.json
jq '.data.on' replaced-document.json
)
```

Confirm the edited trigger in that exported document and Check's `nextFireTime`.
Repeat Check → Test run after any change. For a blocked routine, guarded unblock
comes next, followed by a fresh Test run before activation (see runs and repair).
If the API reports a shared trigger, an agent-managed routine, or unsupported
stored behavior, stop that replacement path. Preserve the routine and report the conflict; do not
silently clone it, detach it, or remove unsupported behavior.

More depth: https://docs.mobilerun.ai/routines/documents.
