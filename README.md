# Mobilerun Skills

A monorepo of Mobilerun agent skills and OpenClaw plugins.

## Available Skills

### [mobilerun-cloud](./mobilerun-cloud)

Control real Android and iOS phones through the Mobilerun API -- tap, swipe, type, take screenshots, read the UI tree, and manage apps.

**Install via the skills CLI:**
```bash
npx skills add droidrun/skills --skill mobilerun-cloud
```

**Install via npm (as OpenClaw plugin):**
```bash
openclaw plugins install @mobilerun/openclaw-mobilerun
```

**Or download the skill directly:**
[mobilerun-cloud.skill](https://github.com/droidrun/skills/releases/latest/download/mobilerun-cloud.skill)

#### Quick Start

1. Create an account at [cloud.mobilerun.ai](https://cloud.mobilerun.ai)
2. Get an API key from [cloud.mobilerun.ai/api-keys](https://cloud.mobilerun.ai/api-keys)
3. Give the API key to your agent

### [mobile-harness](./mobile-harness)

Portable Android and iOS device-control harness for agents using `mobilerun-core` — local ADB/Portal/Simulator control and Mobilerun cloud devices.

This directory is a mirror of [droidrun/mobile-harness](https://github.com/droidrun/mobile-harness), refreshed by the sync workflow. Contribute changes in the source repository.

**Install via the skills CLI:**
```bash
npx skills add droidrun/skills --skill mobile-harness
```

**Or download the skill directly:**
[mobile-harness.skill](https://github.com/droidrun/skills/releases/latest/download/mobile-harness.skill)

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
├── .github/workflows/           # auto-packaging + mobile-harness sync
├── mobilerun-cloud/
│   ├── SKILL.md
│   └── references/
├── mobile-harness/              # mirror of droidrun/mobile-harness
│   ├── SKILL.md
│   ├── AGENTS.md
│   └── ...
```
