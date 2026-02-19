# OpenClaw Skills

A monorepo of OpenClaw plugins and skills.

## Available Plugins

### [@mobilerun/openclaw-mobilerun](./mobilerun)

Control real Android phones through the Mobilerun API -- tap, swipe, type, take screenshots, read the UI tree, and manage apps.

**Install via npm (as OpenClaw plugin):**
```bash
openclaw plugins install @mobilerun/openclaw-mobilerun
```

**Or download the skill directly:**
[mobilerun.skill](https://github.com/droidrun/skills/releases/latest/download/mobilerun.skill)

#### Quick Start

1. Create an account at [cloud.mobilerun.ai](https://cloud.mobilerun.ai)
2. Get an API key from [cloud.mobilerun.ai/api-keys](https://cloud.mobilerun.ai/api-keys)
3. Give the API key to your agent

## Adding a New Skill

1. Create a new directory at the root (e.g. `my-skill/`)
2. Add a `SKILL.md` with YAML frontmatter (`name` and `description` required)
3. Add any reference files the skill needs

The packaging workflow will automatically detect any directory with a `SKILL.md` and build a `.skill` file for it.

## Releasing

The `.skill` zip files are built automatically on every push to `master` and attached to the `latest` GitHub Release.

## Repository Structure

```
├── README.md
├── .github/workflows/           # auto-packaging
├── mobilerun/
│   ├── SKILL.md
│   ├── api.md
│   ├── phone-api.md
│   ├── setup.md
│   └── subscription.md
```
