# Routine documents

Read this when drafting, validating, exporting, or replacing a routine. Fetch
`GET /flows/document-schema` first. It includes the current anatomy, trigger
alternatives, step parameters and output schemas. Do not keep a local field
catalog. Build one trigger and ordered, uniquely identified steps; pass data
using the live template grammar. A stable step ID lets later steps reference
its output. Device-free eligibility comes from the selected catalog entries.

This short skeleton is an **example — check the live schema and catalog**.
Replace `STEP_USES` with a discovered `stepName` and fill `with` using that
entry's `paramsSchema`. Empty steps or missing required parameters cannot be
used as a working routine.

```json
{
  "version": 1,
  "name": "USER_APPROVED_NAME",
  "on": {"custom": {}},
  "steps": [{"id": "work", "uses": "STEP_USES", "with": {}}]
}
```

## JSON or YAML

Both represent the same document. JSON is convenient for `jq`; YAML is easier
for human review. Submit either a parsed JSON object (golden path), or parse YAML locally
and send its object inside the JSON envelope. The API does not accept a YAML
string. With an approved `routine.yaml`, Python, and the optional PyYAML parser
(use a private virtual environment):

```bash
python -m pip install PyYAML
python - <<'PYTHON'
import json
from pathlib import Path
import yaml

document = yaml.safe_load(Path("routine.yaml").read_text())
Path("yaml-body.json").write_text(json.dumps({"document": document}))
PYTHON
curl --fail-with-body -sS "$BASE/flows/document/validate" -H @<(auth_header) \
  -H 'Content-Type: application/json' --data-binary @yaml-body.json > yaml-validation.json
jq '.data' yaml-validation.json
jq -e '.data.valid == true' yaml-validation.json
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
curl --fail-with-body -sS "$BASE/flows/$FLOW_ID/document" -H @<(auth_header) > exported.json
jq '.data' exported.json > routine.json
```

Replacement is a full document operation. Omitted devices, description, and
trigger options clear those values. Omitting settings preserves stored settings;
present settings replaces them, with defaults for omitted inner fields. Export,
edit only the intended values, show the diff to the user, validate again, and
pause before replacement because it preserves enabled state.

```bash
curl --fail-with-body -sS -X PATCH "$BASE/flows/$FLOW_ID" -H @<(auth_header) \
  -H 'Content-Type: application/json' -d '{"enabled":false}' | jq '.data'
jq -n --slurpfile document routine.json '{document:$document[0]}' > document-body.json
curl --fail-with-body -sS "$BASE/flows/document/validate" -H @<(auth_header) \
  -H 'Content-Type: application/json' --data-binary @document-body.json > validation.json
jq -e '.data.valid == true' validation.json
curl --fail-with-body -sS -X PUT "$BASE/flows/$FLOW_ID/document" -H @<(auth_header) \
  -H 'Content-Type: application/json' --data-binary @document-body.json | jq '.data.flow'
```

Repeat Check → Test run → activation after any change. If the API reports a
shared trigger, an agent-managed routine, or unsupported stored behavior, stop
that replacement path. Preserve the routine and report the conflict; do not
silently clone it, detach it, or remove unsupported behavior.

More depth: https://docs.mobilerun.ai/agents/workflows.
