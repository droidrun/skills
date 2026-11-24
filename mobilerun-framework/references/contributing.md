# Contributing, tests and migration

Read the checkout's `AGENTS.md`, `CONTRIBUTING.md`, package README and `tests/unit/test_import_boundaries.py` before editing. Keep shared core independent of features and agent execution. Feature packages remain independent. Use role-named modules for logic and package `settings.py` for tunables. Update package READMEs when changing public APIs. Add unit tests with fakes; do not introduce unused speculative APIs.

```sh
python -m venv .venv
.venv/bin/pip install -e '.[dev]'
.venv/bin/pytest tests/unit
.venv/bin/pytest tests/unit/test_import_boundaries.py
.venv/bin/ruff check .
.venv/bin/black --check --diff --verbose .
.venv/bin/mypy mobilerun
```

Smoke tests are opt-in. Read `tests/unit/smoke/README.md` first. Ask for approval before paid smoke tests, cloud operations or LLM calls, and check ownership and cleanup first. Device-only tests may still change a real device. Never log secrets.

Use current `mobilerun` imports; there is no legacy import compatibility layer. Import agent code directly from the separate `mobilerun-agents` add-on. Placeholder expansion was removed: use bound credential providers for secret typing and retrieve codes explicitly.

## Where new code goes

| Code | Location |
| --- | --- |
| Shared errors, models, utilities, CLI helpers, config and logging | Corresponding top-level shared package |
| Feature CLI, errors, models and settings | Inside the feature package |
| Device errors | `mobilerun/errors/device.py` |
| Macro errors | `mobilerun/macro/errors.py` |
| Proxy commands | `mobilerun/cli/proxy/` |
| Skills commands | `mobilerun/skills/cli/` |

Features may import shared code, core and clients; core may import clients; clients never import core or the root package; shared code never imports features.

## Add a feature and CLI

1. Create a top-level `mobilerun/<feature>/` package with `__init__.py`, role-named modules and a README covering purpose, quick example, files and dependencies. Keep it independent of other feature packages and agents. Put tunables in its declarative `settings.py`.
2. Put Click commands in `<feature>/cli/`, with a group and focused command modules. Use existing shared prompt, device-selection and output helpers from `mobilerun/cli/base/`; feature CLI code may import this shared CLI layer.
3. Register the group in `pyproject.toml` under `[project.entry-points."mobilerun.cli"]`, e.g. `example = "mobilerun.example.cli.group:example"`; add its cheap root-help description to `mobilerun/addons/settings.py`. Follow `mobilerun/macro/cli/` and `mobilerun/skills/cli/`; do not eagerly import the feature into shared core.
4. Add unit tests with fakes, modeling `tests/unit/test_skills_bundle.py`, `tests/unit/test_skills_install_cli.py`, and `tests/unit/test_import_boundaries.py`. For device/cloud/CLI behavior add appropriate opt-in smoke coverage and follow the approval policy above. Run focused tests, import-boundary tests and relevant formatting/type checks. Never use real devices or cloud calls in unit tests.
5. Document public API changes in the package README and user-facing guides; exercise help and non-interactive/error paths. For new resource creation, define ownership, billing guards and cleanup before adding commands.


### Device-aware CLI skeleton

Example module `mobilerun/example/cli/group.py` (replace `example` with the actual feature). It uses the existing device selector and lifecycle; running `snapshot` prints the image byte count and may connect to a device.

```python
import click

from mobilerun.cli.base.run import coro
from mobilerun.cli.devices.base.options import DeviceTarget, device_command


@click.group()
def example() -> None:
    """Example feature commands."""


@example.command()
@device_command
@coro
async def snapshot(target: DeviceTarget) -> None:
    """Capture a screen and print its byte count."""
    async with target.open() as device:
        if device is None:
            raise click.UsageError("Device required")
        image = await device.screenshot()
        click.echo(len(image))
```

Add `example = "mobilerun.example.cli.group:example"` under `[project.entry-points."mobilerun.cli"]` in `pyproject.toml` and reinstall editable metadata before testing. Add package `__init__.py` files, a README, feature logic and tests. For CLI tests invoke the Click command with `CliRunner` and patch `DeviceTarget.open` to return an async context manager yielding a `MemoryDevice` fake; exercise selector arguments and errors. Do not patch `AndroidDevice`, which bypasses the selector. See `tests/unit/test_cli_async_prompts_regression.py` for the `DeviceTarget.open` test pattern.


After adding that module, a root-dispatch test can use the real registry and a fake selector target. The context manager must close its fake even if the action raises. This example belongs in `tests/unit/test_example_cli.py`:

```python
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import pytest
from click.testing import CliRunner

from mobilerun.cli.app import cli
from mobilerun.cli.devices.base.options import DeviceTarget
from mobilerun.core.devices.base import Device
from tests.support.devices import MemoryDevice


class FakeDevice(MemoryDevice):
    def __init__(self, fail: bool) -> None:
        super().__init__()
        self.fail = fail
        self.closed = False

    async def screenshot(self, hide_overlay: bool = True) -> bytes:
        if self.fail:
            raise RuntimeError("screenshot failed")
        return b"fake-png"

    async def close(self) -> None:
        self.closed = True


@pytest.mark.parametrize("fail", [False, True])
def test_snapshot_root_dispatch(monkeypatch: pytest.MonkeyPatch, fail: bool) -> None:
    fake = FakeDevice(fail)
    selected: list[str | None] = []

    @asynccontextmanager
    async def open_fake(target: DeviceTarget) -> AsyncIterator[Device | None]:
        selected.append(target.identifier)
        try:
            yield fake
        finally:
            await fake.close()

    monkeypatch.setattr(DeviceTarget, "open", open_fake)
    result = CliRunner().invoke(cli, ["example", "snapshot", "--device", "fake-id"])
    assert selected == ["fake-id"]
    assert fake.closed
    if fail:
        assert result.exit_code != 0
    else:
        assert result.exit_code == 0, result.output
        assert result.output.strip() == str(len(b"fake-png"))
```

## Legacy imports

### Selector and menu contracts

`device_command(optional=False, base_url_name="base_url", cloud_only=False, allow_auto_setup=False)` injects one `DeviceTarget`: `identifier`, `kind`, `config: MobileConfig`, `tcp`, `base_url`, and `allow_auto_setup`. `target.open()` is an async context manager yielding a connected device, or `None` for an optional missing target; it closes the connection on exit. The decorator rejects incompatible type/transport options. `cloud_only` enforces a cloud ID; `allow_auto_setup` enables Portal setup only when config permits it. Keep setup off for read-only commands. See [CLI selection](cli.md#device-selection-and-replay).

`mobilerun.cli.base.menu.MenuGroup` uses `PromptingCommand` as `command_class` and its own type as `group_class`. `parse_args` presents visible commands plus Back/Exit only on an interactive terminal with no arguments; non-interactive execution follows Click parsing. `menu_choices(ctx)` returns visible choices; `get_epilog(ctx)` and `format_epilog(ctx, formatter)` supply the help/menu epilog. `resolve_command` prepares commands and suggests close matches for typos. `main` handles menu-back navigation and renders errors; interruption exits 130 in standalone mode. Test both interactive and non-interactive paths without real devices.

| Earlier import | Current import |
| --- | --- |
| `from droidrun import AndroidDevice` | `from mobilerun import AndroidDevice` |
| `from droidrun.tools.ui.state import UIState` | `from mobilerun.core.state import UIState` |
| `from droidrun.macro.replay import MacroPlayer` | `from mobilerun.macro import MacroPlayer` |
| `from droidrun import DroidAgent` | `from mobilerun.agents import MobileAgent` (separate `mobilerun-agents` install) |

Old `droidrun` and deprecated `mobilerun` import paths are unavailable. Update imports to the current paths above.
