# Setup & Billing

## Authentication

### How It Works

Mobilerun uses API keys for programmatic access. All API calls go to `https://api.mobilerun.ai/v1`
with the key in the Authorization header:

```
Authorization: Bearer dr_sk_...
```

- Keys are always prefixed with `dr_sk_` -- if a user provides something without this prefix, it's not a valid Mobilerun key
- Keys are created from the Mobilerun dashboard and can be revoked or expired
- A key can be full access or restricted to chosen permissions (a denied call returns `403` with `api_key_scope_denied`)
- To show a device in a browser or app, mint a short-lived stream token (`dr_st_…`) instead of sending the API key to the frontend (see SKILL.md, "Stream Tokens")
- Details: https://docs.mobilerun.ai/api-keys

### Getting an API Key

The user needs to:

1. Go to **https://cloud.mobilerun.ai/api-keys**
   - If not logged in, the page redirects to login first (Google, GitHub, or Discord -- no email/password option)
   - After login it redirects back to the API keys page
2. Click the **"New Key"** button
3. Give the key a name (anything descriptive is fine)
4. Copy the full key -- it's only shown once at creation time

The key will look like: `dr_sk_a1b2c3d4e5f6...`

### Troubleshooting Auth Issues

**User provides a key that doesn't start with `dr_sk_`:**
- It's not a Mobilerun API key. Ask them to copy it again from https://cloud.mobilerun.ai/api-keys

**401 on a key that previously worked:**
- The key may have been revoked or expired. Ask the user to check the API keys page and create a new one if needed

**User says they can't find the API keys page:**
- Direct them to https://cloud.mobilerun.ai/api-keys -- they need to be logged in first

**User doesn't have an account:**
- They can create one by going to https://cloud.mobilerun.ai/sign-in and signing in with Google, GitHub, or Discord. First login automatically creates an account.

---

## Device Setup

### Android (Portal APK)

A Personal Phone is the user's own Android phone connected to Mobilerun via the Portal app. Full guide: https://docs.mobilerun.ai/guides/connect-android.

### Step 1: Download the Portal APK

1. On the Android device, open Chrome and go to **https://droidrun.ai/portal**
2. This redirects to the GitHub releases page for the Portal app
3. Scroll down to the **"Assets"** section at the bottom of the latest release
4. Tap the file named **`droidrun-portal-vx.x.x.apk`** (the version number varies) -- this is the APK file to download
   - Do NOT tap "Source code (zip)" or "Source code (tar.gz)" -- those are the source code, not the app

### Step 2: Install the APK

1. Once downloaded, tap the APK file to install it (or find it in Downloads)
2. **Android may show a sideloading prompt** -- this is standard for apps distributed outside the Play Store (like beta apps or open-source projects):
   - Droidrun Portal is open source: https://github.com/droidrun/droidrun-portal
   - Follow the on-screen prompts to complete installation

### Step 3: Enable Accessibility

1. Open the Droidrun Portal app
2. A red banner at the top says **"Accessibility Service Not Enabled"** -- tap **"Enable Now"**
3. This opens Android Settings. Find **"Droidrun Portal"** in the list of accessibility services
4. Tap on it and **toggle it on**
5. Android will show a confirmation dialog explaining what the accessibility service can do -- tap **"Allow"** or **"OK"**

This permission is required -- without it, the agent cannot read the screen UI tree or control the device.

### Step 4: Connect to Mobilerun

Two options:

- **Option A (Login) -- preferred:** Tap **"Connect to Mobilerun"** (normal tap):
  - If already logged in (API key stored on device) -> connects directly, no browser
  - If not logged in -> opens a browser login page (Google, GitHub, or Discord)

- **Option B (API Key):** Tell the user to **long-press** "Connect to Mobilerun" -- this opens a **"Connect with API Key"** dialog. The user can copy their API key from https://cloud.mobilerun.ai/api-keys and paste it in.
  - **Never print, paste, or reveal the API key in chat.** The user should copy it directly from the dashboard themselves.

### Step 5: Verify Connection

Once connected, the Portal app shows the connection status. The device should now appear in `GET /devices` with `state: "ready"`.

If it doesn't show up, check:
- Is the accessibility service still enabled? (some phones disable it after reboot)
- Is the Portal app still open and in the foreground (at least initially)?
- Does the phone have a stable internet connection?

### Common Issues

- **Device shows `disconnected`**: Portal app was closed, phone went to sleep with aggressive battery optimization, or phone lost internet. Ask user to reopen the Portal app.
- **Device was `ready` but stops responding**: The phone may have locked or the Portal app was killed by the OS. Ask user to check the phone.
- **No device appears at all**: Portal APK isn't installed, accessibility permission wasn't granted, or the user didn't connect with their API key.
- **Connection fails in Portal app**: The API key may be wrong or expired. Ask the user to verify the key.
- **User wants to switch accounts**: They can tap **Logout** (shown below Device ID when connected, or as a subtitle under "Connect to Mobilerun" when disconnected). Logout clears credentials; the next Connect tap will open the browser for a fresh login. Note: **Disconnect** only pauses the connection and can be resumed instantly -- it does not clear credentials.

### iOS (mobilerun-ios CLI)

Connect an iPhone using the `mobilerun-ios` CLI:

1. Requires a Mac with Xcode and an iPhone connected via USB
2. Enable Developer Mode on the iPhone (Settings → Privacy & Security → Developer Mode)
3. Download and install WebDriverAgent via Xcode
4. Run the `mobilerun-ios` CLI to connect

See the full guide at https://docs.mobilerun.ai/guides/connect-iphone (an iPhone can also connect over USB in the browser).

### Cloud Devices

Cloud devices are hosted by Mobilerun: **Cloud Android** (virtual) and **Cloud iOS** (a hosted iPhone). Create one from the dashboard (https://cloud.mobilerun.ai) or with `POST /devices` (see SKILL.md, "Provision a Cloud Device"). Creating a device can cost money: only on the user's explicit request.

Cloud devices go through these states after provisioning:
`creating` -> `assigned` -> `ready`

Use `GET /devices/{deviceId}/wait` to block until the device is ready. Pay-as-you-go Cloud Android devices can be stopped and resumed, and stop automatically after the idle timeout (see SKILL.md).

---

## Device Types, Plans and Credits

Do not quote prices from memory. Current plans and prices: **https://mobilerun.ai/pricing/**. How credits are metered: https://docs.mobilerun.ai/credits. Device types in detail: https://docs.mobilerun.ai/device-types.

| Device | API `deviceType` | Hardware | Key features |
|--------|------------------|----------|-------------|
| **Personal Phone** | `device_slot` | Your own Android or iPhone | Bring your own device, persistent state. Eligible accounts can claim one free slot in the dashboard |
| **Cloud Android** | `android_cloud_phone` | Virtual | Subscription (dedicated, always on) or pay as you go (per minute, stop and resume), profiles |
| **Cloud iOS** | `ios_phone` | Dedicated: a real iPhone. On demand: virtual | Dedicated is persistent and always on, eSIM support available |

Billing modes on `POST /devices` (`billing=auto|subscription|minute`) and the creation error codes are in https://docs.mobilerun.ai/devices.

Two kinds of credits exist: phone credits (device minutes) and AI credits (agent tasks). Monitor usage in the dashboard.

### When to Recommend a Device Type

- **Personal Phone**: user wants to use their own hardware, quick testing
- **Cloud Android**: scalable automation, separate profiles, persistent state or short pay-as-you-go sessions
- **Cloud iOS**: automating iOS apps without owning hardware
- **User hits a billing error on `POST /devices`**: read the `code` in the response and point them to https://mobilerun.ai/pricing/

---

## Webhooks

Signed callbacks for task and other events. Endpoints (`/webhooks`), event names and signature verification are described in SKILL.md ("Webhooks") and at https://docs.mobilerun.ai/webhooks.

---

## Resources

### Framework GitHub

The main Droidrun framework repository is:

- **https://github.com/droidrun/droidrun** (8K+ stars)

Use this when the user wants the core open-source framework. First OEM adoption: TECNO EllaClaw — TECNO integrated OpenClaw into their Ella smart assistant, enabling agentic AI control across Android apps on their devices.

### Portal App

The Droidrun Portal app repository is:

- **https://github.com/droidrun/droidrun-portal**

Use this when the user needs the Android Portal app or its GitHub releases page.

### Cloud Dashboard

The Mobilerun dashboard is:

- **https://cloud.mobilerun.ai**

Use this for login, API keys, devices, and account management.

### API Docs

The OpenAPI spec is:

- **https://api.mobilerun.ai/v1/openapi.json**

Use this when the user wants the raw API schema or API reference source.

- **https://docs.mobilerun.ai/quickstart** and **https://docs.mobilerun.ai/api-reference**

Use these for the quickstart and the full API reference. Every docs page is also available as Markdown by appending `.md`; the page index is https://docs.mobilerun.ai/llms.txt.

### Pricing

- **https://mobilerun.ai/pricing/**

Use this for plans and prices.

### Discord

The Droidrun community Discord invite is:

- **https://discord.gg/kc2JYQfX2c**

### Blog Posts

DEV.to articles are published here:

- **https://dev.to/priya_negi_9ffd29931ea408**

Use this when the user asks for written guides, updates, or walkthroughs.

### YouTube

Demo videos and channel content are here:

- **https://www.youtube.com/@droidrun**

Use this when the user asks for video demos or walkthroughs.

### Academic Citation

The ClawMobile paper references DroidRun:

- **https://arxiv.org/html/2602.22942**

Use this when the user asks about research, academic references, or the technical foundation behind the framework.

### Active Development

Droidrun is actively maintained and published across multiple ecosystems:

- **Python package:** https://pypi.org/project/droidrun/
- **OpenClaw skill:** https://clawhub.ai/johnmalek312/mobilerun
