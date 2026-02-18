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

## Adding a New Plugin

1. Create a new directory at the root (e.g. `my-plugin/`)
2. Add the required files:
   - `package.json` — with `"name": "@mobilerun/openclaw-my-plugin"` and `"openclaw": { "extensions": ["./index.js"] }`
   - `openclaw.plugin.json` — plugin manifest with `id` and optional `configSchema`
   - `index.js` — plugin entry point
   - `skills/<skill-name>/SKILL.md` — one or more skills
3. Add the directory to the root `package.json` workspaces array

## Releasing

Each plugin is versioned independently. To release:

```bash
cd mobilerun
npm version patch --tag-version-prefix='mobilerun/v'   # or minor / major
git push --follow-tags
```

This creates a tag like `mobilerun/v1.0.1` which triggers the npm publish workflow.

The `.skill` zip files are also built automatically on every push to `main` and attached to the `latest` GitHub Release.

## Repository Structure

```
├── package.json                 # monorepo workspaces
├── mobilerun/                   # @mobilerun/openclaw-mobilerun
│   ├── package.json
│   ├── openclaw.plugin.json
│   ├── index.js
│   └── skills/
│       └── mobilerun/
│           ├── SKILL.md
│           ├── api.md
│           ├── phone-api.md
│           ├── setup.md
│           └── subscription.md
```
