---
name: mobilerun
description: >
  Load this skill whenever the user wants to control, automate, or interact with a phone
  or mobile device. This includes: tapping, swiping, typing, taking screenshots, reading
  the screen, managing apps, running AI agent tasks on a phone, or any form of phone/mobile
  automation. Also load when the user mentions Mobilerun, Droidrun, or phone control.
  Requires a Mobilerun API key (prefixed dr_sk_) and a connected device.
metadata: { "openclaw": { "emoji": "📱", "primaryEnv": "MOBILERUN_API_KEY", "requires": { "env": ["MOBILERUN_API_KEY"] } } }
---

# Mobilerun

Mobilerun turns your Android phone into a tool that AI can control. Instead of manually tapping through apps, you connect your phone and let an AI agent do it for you -- navigate apps, fill out forms, extract information, automate repetitive tasks, or anything else you'd normally do by hand. It works with your own personal device through a simple app called Droidrun Portal, and everything happens through a straightforward API: take screenshots to see the screen, read the UI tree to understand what's on it, then tap, swipe, and type to interact. No rooting, no emulators, just your real phone controlled remotely.

Base URL: `https://api.mobilerun.ai/v1`
Auth: `Authorization: Bearer <MOBILERUN_API_KEY>`

**Important:** The base domain (`https://api.mobilerun.ai/`) returns 404. You must always include `/v1` in the path. All API calls should be made via `curl`. Example:

```bash
curl -s https://api.mobilerun.ai/v1/devices \
  -H "Authorization: Bearer $MOBILERUN_API_KEY"
```

## Before You Start

The API key (`MOBILERUN_API_KEY`) is already available -- OpenClaw handles credential setup before this skill loads. Do NOT ask the user for an API key. Just use it.

1. **Check for devices:**
   ```bash
   curl -s https://api.mobilerun.ai/v1/devices \
     -H "Authorization: Bearer $MOBILERUN_API_KEY"
   ```
   - `200` with a device in `state: "ready"` = **good to go, skip all setup, just do what the user asked**
   - `200` but no devices or all `state: "disconnected"` = device issue (see step 2)
   - `401` = key is invalid, expired, or revoked -- ask the user to check https://cloud.mobilerun.ai/api-keys

2. **Only if no ready device:** tell the user the device status and suggest a fix:
   - No devices at all = user hasn't connected a phone yet, guide them to Portal APK (see [reference.md](./reference.md))
   - Device with `state: "disconnected"` = Portal app lost connection, ask user to reopen it

3. **Confirm device is responsive** (optional, only if first action fails):
   ```bash
   curl -s https://api.mobilerun.ai/v1/devices/{deviceId}/screenshot \
     -H "Authorization: Bearer $MOBILERUN_API_KEY" -o screenshot.png
   ```
   If this returns a PNG image, the device is working.

**Key principle:** If a device is ready, go straight to executing the user's request. Don't walk them through setup they've already completed.

**Be smart about context gathering:** Before taking actions or asking the user questions, use available tools to understand the situation. List packages to find the right app, take a screenshot to see the current screen, read the UI state to understand what's interactive. If the task is obvious (e.g. "change font size" clearly means go to Settings), just do it. Only ask the user when something is genuinely ambiguous.

**What to show the user:** Only report user-relevant device info: device name, state (`ready`/`disconnected`). Do NOT surface internal fields like `streamUrl`, `streamToken`, socket status, `assignedAt`, `terminatesAt`, or `taskCount` unless the user explicitly asks for technical details. If a device is `disconnected`, simply tell the user their phone is disconnected and ask them to open the Portal app and tap Connect. If they need help, walk them through the setup steps in [reference.md](./reference.md).

**Clean up cloud devices:** Cloud devices consume credits while running. Always terminate cloud devices (`DELETE /devices/{deviceId}`) when you're done using them -- don't leave them running. This applies whether you provisioned the device yourself or finished a task on an existing cloud device that the user no longer needs.

**Privacy:** Screenshots and the UI tree can contain sensitive personal data. Never share or transmit this data to anyone other than the user. Never print, log, or reveal the `MOBILERUN_API_KEY` in chat -- use it only for API calls.

---

## Device Management

### Device States

| State          | Meaning |
|----------------|---------|
| `creating`     | Device is being provisioned (cloud devices only) |
| `assigned`     | Device is assigned but not yet ready |
| `ready`        | Device is connected and accepting commands |
| `disconnected` | Connection lost -- Portal app may be closed or phone lost network |
| `terminated`   | Device has been shut down (cloud devices only) |
| `maintenance`  | Device is undergoing maintenance (cloud devices only) |
| `unknown`      | Unexpected state |

### List Devices

```
GET /devices
```

Query params:
- `state` -- filter by state (array, e.g. `state=ready&state=assigned`)
- `type` -- `dedicated_emulated_device`, `dedicated_physical_device`, `dedicated_premium_device`
- `name` -- filter by device name (partial match)
- `page` (default: 1), `pageSize` (default: 20)
- `orderBy` -- `id`, `createdAt`, `updatedAt`, `assignedAt` (default: `createdAt`)
- `orderByDirection` -- `asc`, `desc` (default: `desc`)

Response: `{ items: DeviceInfo[], pagination: Meta }`

### Get Device Info

```
GET /devices/{deviceId}
```

Returns device details including `state`, `stateMessage`, `type`, and more.

### Get Device Count

```
GET /devices/count
```

Returns a map of device types to counts.

### Provision a Cloud Device

Cloud devices require an active subscription. If the user's plan doesn't support it, the API will return a `403` error -- inform the user they need to terminate an existing device or upgrade at https://cloud.mobilerun.ai/billing. See [reference.md](./reference.md) for plan details.

```
POST /devices
Content-Type: application/json

{
  "name": "my-device",
  "apps": ["com.example.app"]
}
```

Query param:
- `deviceType` -- `dedicated_emulated_device`, `dedicated_physical_device`, `dedicated_premium_device`

After provisioning, wait for it to become ready:

```
GET /devices/{deviceId}/wait
```

This blocks until the device state transitions to `ready`.

**Cloud device workflow:**
1. `POST /devices?deviceType=dedicated_emulated_device` -- provision, returns device in `creating` state
2. `GET /devices/{deviceId}/wait` -- blocks until `ready`
3. Use the `deviceId` for phone control or tasks

**Temporary device for a task:**
When the user wants to run a task but has no ready device, provision a temporary cloud device, run the task on it, then clean up:
1. `POST /devices?deviceType=dedicated_emulated_device` with `{"name": "temp-task-device", "apps": [...]}` -- include any apps the task needs
2. `GET /devices/{deviceId}/wait` -- wait until ready
3. `POST /tasks` with the new `deviceId` -- run the task
4. Monitor via `GET /tasks/{taskId}/status` until the task finishes
5. `DELETE /devices/{deviceId}` -- terminate the device after the task completes (or fails)

Always terminate temporary devices after use -- they consume credits while running.

### Terminate a Cloud Device

```
DELETE /devices/{deviceId}
Content-Type: application/json

{}
```

> Personal devices cannot be terminated via the API. They disconnect when the Portal app is closed.

### Get Device Time

```
GET /devices/{deviceId}/time
```

Returns the current time on the device as a string.

---

## Screen Observation

### Take Screenshot

```
GET /devices/{deviceId}/screenshot
```

Query param: `hideOverlay` (default: `false`)

Returns a **PNG image** as binary data. Use this to see what's currently displayed on screen.

### Get UI State (Accessibility Tree)

```
GET /devices/{deviceId}/ui-state
```

Query param: `filter` (default: `false`) -- set to `true` to filter out non-interactive elements.

Returns an `AndroidState` object with three sections:

#### phone_state

```json
{
  "keyboardVisible": false,
  "packageName": "app.lawnchair",
  "currentApp": "Lawnchair",
  "isEditable": false,
  "focusedElement": {
    "className": "string",
    "resourceId": "string",
    "text": "string"
  }
}
```

- `currentApp` -- human-readable name of the foreground app
- `packageName` -- Android package name of the foreground app
- `keyboardVisible` -- whether the soft keyboard is showing
- `isEditable` -- whether the currently focused element accepts text input
- `focusedElement` -- details about the focused UI element (if any)

#### device_context

```json
{
  "screen_bounds": { "width": 720, "height": 1616 },
  "display_metrics": {
    "density": 1.75,
    "densityDpi": 280,
    "scaledDensity": 1.75,
    "widthPixels": 720,
    "heightPixels": 1616
  },
  "filtering_params": {
    "min_element_size": 5,
    "overlay_offset": 0
  }
}
```

- `screen_bounds` -- the actual screen resolution in pixels. All tap/swipe coordinates use this coordinate space.
- `display_metrics` -- physical display properties (density, DPI)

#### a11y_tree (Accessibility Tree)

A recursive tree of UI elements. Each node has:

```json
{
  "className": "android.widget.TextView",
  "packageName": "app.lawnchair",
  "resourceId": "app.lawnchair:id/search_container",
  "text": "Search",
  "contentDescription": "",
  "boundsInScreen": { "left": 48, "top": 1420, "right": 671, "bottom": 1532 },
  "isClickable": true,
  "isLongClickable": false,
  "isEditable": false,
  "isScrollable": false,
  "isEnabled": true,
  "isVisibleToUser": true,
  "isCheckable": false,
  "isChecked": false,
  "isFocusable": false,
  "isFocused": false,
  "isSelected": false,
  "isPassword": false,
  "hint": "",
  "childCount": 0,
  "children": []
}
```

**Key node fields:**
- `text` -- the visible text on the element
- `contentDescription` -- accessibility label (useful when `text` is empty, e.g. icon buttons)
- `resourceId` -- Android resource ID (e.g. `com.app:id/button_ok`) -- useful for identifying elements
- `boundsInScreen` -- pixel coordinates as `{left, top, right, bottom}`. To tap an element, calculate its center: `x = (left + right) / 2`, `y = (top + bottom) / 2`
- `isClickable` -- whether the element responds to taps
- `isEditable` -- whether the element is a text input field
- `isScrollable` -- whether the element supports scrolling (swipe gestures)
- `children` -- nested child elements (the tree is recursive)

**Example: reading a home screen**
```
FrameLayout (0,0,720,1616)
  ScrollView (0,0,720,1616) [scrollable]
    FrameLayout (14,113,706,326)
      LinearLayout (42,128,706,310) [clickable]
        TextView (42,156,706,198) "Tap to set up"
  View (0,94,720,1574) "Home"
  TextView (14,1222,187,1422) "Phone" [clickable]
  TextView (187,1222,360,1422) "Contacts" [clickable]
  TextView (360,1222,533,1422) "Files" [clickable]
  TextView (533,1222,706,1422) "Chrome" [clickable]
  FrameLayout (48,1420,671,1532) "Search" [clickable]
```

To tap "Chrome": bounds are (533,1222,706,1422), so tap at x=(533+706)/2=619, y=(1222+1422)/2=1322.

Use `filter=true` for a cleaner tree focused on actionable elements (filters out non-interactive containers).

---

## Device Actions

All action endpoints take a `deviceId` path parameter.

### Tap

```
POST /devices/{deviceId}/tap
Content-Type: application/json

{ "x": 540, "y": 960 }
```

Taps at pixel coordinates. Use the `screen_bounds` from UI state and element bounds from the a11y tree to calculate where to tap.

### Swipe

```
POST /devices/{deviceId}/swipe
Content-Type: application/json

{
  "startX": 540,
  "startY": 1200,
  "endX": 540,
  "endY": 400,
  "duration": 300
}
```

`duration` is in milliseconds (minimum: 10). Common patterns:
- **Scroll down**: swipe from bottom to top (high startY -> low endY)
- **Scroll up**: swipe from top to bottom
- **Swipe left/right**: adjust X coordinates, keep Y similar

### Global Actions

```
POST /devices/{deviceId}/global
Content-Type: application/json

{ "action": 2 }
```

| Action code | Button  |
|-------------|---------|
| `1`         | BACK    |
| `2`         | HOME    |
| `3`         | RECENT  |

### Type Text

```
POST /devices/{deviceId}/keyboard
Content-Type: application/json

{ "text": "Hello world", "clear": false }
```

Types text into the currently focused input field.
- `clear: true` -- clears the field before typing
- Make sure an input field is focused first (check `phone_state.isEditable`)
- If the keyboard isn't visible, you may need to tap on an input field first

### Press Key

```
PUT /devices/{deviceId}/keyboard
Content-Type: application/json

{ "key": 66 }
```

Sends an Android keycode. Only text-input-related keycodes are supported.

| Keycode | Key |
|---------|-----|
| `4`   | BACK |
| `61`  | TAB |
| `66`  | ENTER |
| `67`  | DEL (backspace) |
| `112` | FORWARD_DEL (delete) |

For system navigation (home, back, recent), use `POST /devices/{id}/global` instead.

### Clear Input

```
DELETE /devices/{deviceId}/keyboard
```

Clears the currently focused input field.

---

## App Management

### List Installed Apps

```
GET /devices/{deviceId}/apps
```

Query param: `includeSystemApps` (default: `false`)

Returns an array of `AppInfo`:
```json
{
  "packageName": "com.example.app",
  "label": "Example App",
  "versionName": "1.2.3",
  "versionCode": 123,
  "isSystemApp": false
}
```

### List Package Names

```
GET /devices/{deviceId}/packages
```

Query param: `includeSystemPackages` (default: `false`)

Returns a string array of package names. Lighter than the full app list.

### Install App

```
POST /devices/{deviceId}/apps
Content-Type: application/json

{ "packageName": "com.example.app" }
```

Installs an app from the Mobilerun app library (not the Play Store directly).
Takes a couple of minutes and there's no status endpoint -- you'd have to poll `GET /devices/{id}/apps` to confirm.

**Prefer manually installing via Play Store instead.** Open the Play Store app on the device, search for the app, and tap install -- this is faster and more reliable. Only use this API endpoint if the user explicitly asks for it.

> On personal devices, this endpoint may fail because Android blocks app installations from unknown sources by default.

### Start App

```
PUT /devices/{deviceId}/apps/{packageName}
Content-Type: application/json

{}
```

Optional body: `{ "activity": "com.example.app.MainActivity" }` -- to launch a specific activity.
Usually omitting activity is fine; it launches the default/main activity.

### Stop App

```
PATCH /devices/{deviceId}/apps/{packageName}
Content-Type: application/json

{}
```

### Uninstall App

```
DELETE /devices/{deviceId}/apps/{packageName}
Content-Type: application/json

{}
```

---

## App Library (Upload & Manage APKs)

The app library stores APKs that can be pre-installed on cloud devices. Only one app per package name is allowed -- to update an app, delete the existing one first, then re-upload.

### List Apps in Library

```
GET /apps
```

Query params:
- `page` (default: 1), `pageSize` (default: 10)
- `source` -- `all`, `uploaded`, `store`, `queued` (default: `all`)
- `query` -- search by name
- `sortBy` -- `createdAt`, `name` (default: `createdAt`)
- `order` -- `asc`, `desc` (default: `desc`)

### Get App by ID

```
GET /apps/{id}
```

### Upload an APK

Uploading is a 3-step process:

**Step 1: Create signed upload URL**

```
POST /apps/create-signed-upload-url
Content-Type: application/json

{
  "displayName": "My App",
  "packageName": "com.example.myapp",
  "versionName": "1.0.0",
  "versionCode": 1,
  "targetSdk": 34,
  "sizeBytes": 5242880,
  "files": [
    { "fileName": "base.apk", "contentType": "application/vnd.android.package-archive" }
  ],
  "country": "US"
}
```

Required: `displayName`, `packageName`, `versionName`, `versionCode`, `targetSdk`, `sizeBytes`, `files`
Optional: `description`, `iconURL`, `developerName`, `categoryName`, `ratingScore`, `ratingCount`

Returns the app `id` and pre-signed R2 upload URLs for each file.

**Step 2: Upload the APK file(s)**

Upload each file directly to its pre-signed R2 URL using a PUT request.

**Step 3: Confirm the upload**

```
POST /apps/{id}/confirm-upload
```

Verifies the file exists in R2 and sets the app status to `available`.

If the upload failed, mark it:

```
POST /apps/{id}/mark-failed
```

### Delete an App

```
DELETE /apps/{id}
```

Removes the app from R2 storage and the database. Use this before re-uploading an app with the same package name.

### Re-uploading an App

Only one app per package name is allowed. To update:
1. Find the existing app: `GET /apps?query=com.example.myapp`
2. Delete it: `DELETE /apps/{id}`
3. Upload the new version using the 3-step upload flow above

---

## Tasks (AI Agent)

Instead of controlling a phone step-by-step, you can submit a natural language goal and let Mobilerun's AI agent execute it autonomously on the device with its own screen analysis, observe-act loop, and error recovery.

Tasks require a paid subscription with credits. If the user doesn't have an active plan, the API will return an error -- let them know they need a subscription at https://cloud.mobilerun.ai/billing. See [reference.md](./reference.md) for plan and credit details.

### Run a Task

```
POST /tasks
Content-Type: application/json

{
  "task": "Open Chrome and search for weather",
  "deviceId": "uuid-of-device",
  "llmModel": "google/gemini-3.1-flash-lite-preview"
}
```

**Required fields:**
- `task` -- natural language description of what to do (min 1 char)
- `deviceId` -- UUID of the device to run on. Must be a device in `ready` state.

**Optional fields:**
- `llmModel` -- which model to use (default: `google/gemini-3.1-flash-lite-preview`, see `GET /models` for available models)
- `apps` -- list of app package names to pre-install
- `credentials` -- list of `{ packageName, credentialNames[] }` for app logins
- `maxSteps` -- max agent steps (default: 100)
- `reasoning` -- enable reasoning/thinking (default: true). **Always set to `false`** unless the user explicitly requests it.
- `vision` -- enable vision/screenshot analysis (default: false)
- `temperature` -- LLM temperature (default: 0.5)
- `executionTimeout` -- timeout in seconds (default: 1000)
- `outputSchema` -- JSON schema for structured output (nullable). Only use when the user explicitly asks for structured/formatted data. When set, the agent returns its result as a JSON object matching the schema in the task's `output` field.
- `vpnCountry` -- route through VPN in a specific country: `US`, `BR`, `FR`, `DE`, `IN`, `JP`, `KR`, `ZA`. Only use if the task specifically requires a certain region. VPN adds latency -- avoid unless needed.

Returns:
```json
{
  "id": "uuid",
  "streamUrl": "string"
}
```

### Writing Task Prompts

You don't see the phone screen -- the agent on the device does. Write prompts that describe **what to achieve**, not how to navigate the UI. The on-device agent will figure out the taps, swipes, and navigation itself.

**Don't assume the UI -- describe the goal:**
- Bad: `"Tap the three dots menu in the top right, then tap Settings, scroll down and tap the Dark Mode toggle"`
- Good: `"Open Settings in the Chrome app and enable Dark Mode"`
- You don't know what the screen looks like. The on-device agent can see it -- let it handle the navigation.

**Be specific about the important details:**
- Name the exact app (not "the browser" -- say "Chrome")
- Specify exact text to type or send
- Say what counts as success
- Name the person, contact, or item to find

**Examples by task type:**

Simple action:
```
"Open the Settings app, go to Display, and enable Dark Mode"
```

Multi-step with messaging:
```
"Open WhatsApp, find the conversation with John Smith, and send: Running 10 minutes late, sorry!"
```

Information extraction:
```
"Open Chrome, go to amazon.com, search for 'wireless headphones', and report back the name and price of the top 3 results"
```

Form filling:
```
"Open Chrome, go to docs.google.com/forms/d/abc123, and fill in the form with: Name = Sarah Connor, Email = sarah@example.com, Department = Engineering. Then submit the form."
```

App configuration:
```
"Open Spotify, go to Settings, turn off Autoplay, set Audio Quality to Very High, and disable Canvas"
```

Verification / checking:
```
"Open Gmail, check if there are any unread emails from support@stripe.com in the last 24 hours, and tell me the subject lines"
```

Multi-app workflow:
```
"Open Google Maps, search for 'Italian restaurants near me', find the highest rated one that's currently open, then open Chrome and search for that restaurant's menu"
```

**Break down complex goals -- tell the agent what you want, not the steps:**
- Bad: `"Order me an Uber to work"`
- Good: `"Open the Uber app, set the destination to 123 Main Street, select UberX, and stop before confirming the ride so I can review the price"`

**Include safety conditions when appropriate:**
- `"If the app asks for login, stop and tell me"`
- `"If the price is over $50, don't purchase -- just report the price"`

### Check Task Status

```
GET /tasks/{task_id}/status
```

Use this to monitor task progress:

```json
{
  "status": "running",
  "succeeded": null,
  "message": null,
  "output": null,
  "steps": 5,
  "lastResponse": { "event": "ManagerPlanEvent", "data": { ... } }
}
```

- **While running:** `lastResponse` contains the agent's latest thinking, plan, and actions. Check this to understand what the agent is doing and where it's up to.
- **When finished:** `status` is `completed` or `failed`, `message` has the final answer or failure reason, `succeeded` is `true`/`false`, `lastResponse` is `null`.
- **Statuses:** `created`, `running`, `paused`, `completed`, `failed`, `cancelled`

### Monitoring a Running Task

After creating a task, follow this pattern:

1. **Immediately** tell the user the task is running (task ID, what it's doing).
2. **After 5 seconds** -- do the first status check. This catches quick tasks and confirms the agent started.
3. **After 30 seconds** -- check again if still running.
4. **Subsequent checks** -- use your judgement on the interval based on:
   - **Task complexity** -- a simple "open Chrome" task finishes fast; a multi-app workflow takes longer, so space out checks accordingly.
   - **Progress** -- if steps are increasing and `lastResponse` is changing, the agent is working well; you can wait longer between checks. If the step count and `lastResponse` haven't changed, the agent may be stuck; check sooner and consider warning the user.
   - **Time elapsed** -- the longer a task has been running successfully, the more you can trust it and wait between checks.

**At each check:**
- Report to the user what the agent is doing (from `lastResponse` -- its current plan, thinking, what step it's on).
- Optionally take a screenshot (`GET /devices/{id}/screenshot`) to show the user what's on screen.
- Optionally read the UI state (`GET /devices/{id}/ui-state`) for more context.
- Give the user a meaningful update, not just "still running" -- e.g. "The agent is on step 8, currently in the Settings app looking for display options."

**When the task finishes:**
- Report the result (`message`, `succeeded`, `output`).
- If the task failed unexpectedly, auto-submit feedback (see Feedback section).

**If the agent seems stuck:**
- Send a message via `POST /tasks/{id}/message` to nudge it in the right direction.
- Let the user know and ask if they want to steer it or cancel.

### Send Message to Task

```
POST /tasks/{task_id}/message
Content-Type: application/json

{ "message": "Actually, search for 'weather in London' instead" }
```

Send instructions to steer a running agent task. Use this to correct the agent, provide additional context, or change direction mid-task. The message is queued and delivered to the agent at the next step.

### Cancel Task

```
POST /tasks/{task_id}/cancel
```

### Get Task Details

```
GET /tasks/{task_id}
```

Returns the full task object including configuration, status, and trajectory.

### List Tasks

```
GET /tasks
```

Query params:
- `status` -- `created`, `running`, `paused`, `completed`, `failed`, `cancelled`
- `orderBy` -- `id`, `createdAt`, `finishedAt`, `status` (default: `createdAt`)
- `orderByDirection` -- `asc`, `desc` (default: `desc`)
- `query` -- search in task description (max 128 chars)
- `page` (default: 1), `pageSize` (default: 20, max: 100)

### Task Screenshots & UI States

```
GET /tasks/{task_id}/screenshots         -- list all screenshot URLs
GET /tasks/{task_id}/screenshots/{index}  -- get screenshot at index
GET /tasks/{task_id}/ui_states            -- list all UI state URLs
GET /tasks/{task_id}/ui_states/{index}    -- get UI state at index
```

### Get Task Trajectory

```
GET /tasks/{task_id}/trajectory
```

Returns the full history of events from the task execution.

### Available LLM Models

```
GET /models
```

Returns the list of models available for tasks. Default: `google/gemini-3.1-flash-lite-preview`.

### List Tasks for a Device

```
GET /devices/{deviceId}/tasks
```

Query params: `page`, `pageSize`, `orderBy`, `orderByDirection`

---

## Feedback

Submit feedback to help improve the Mobilerun platform. This is important for identifying bugs and improving agent performance.

**When to auto-submit feedback:**
- When a task fails unexpectedly
- When the agent behaves incorrectly or produces wrong results
- When API errors occur that seem like platform bugs
- Include the `taskId`, error details, and what happened

**When the user asks to submit feedback:**
- Ask for a few details (what happened, what they expected) but don't push hard
- If they don't want to elaborate, just submit with whatever details you have

```
POST /feedback
Content-Type: application/json

{
  "title": "Task failed unexpectedly",
  "feedback": "The agent got stuck on the login screen and timed out after 50 steps.",
  "rating": 2,
  "taskId": "uuid-of-related-task"
}
```

**Required fields:**
- `title` -- short summary (3-100 chars)
- `feedback` -- detailed description (10-4000 chars)
- `rating` -- 1 to 5

**Optional fields:**
- `taskId` -- UUID of a related task

| Status | Meaning |
|--------|---------|
| `201` | Feedback submitted |
| `400` | Validation error |
| `401` | Invalid or missing API key |
| `429` | Rate limited -- 15/day cap reached |

---

## Common Patterns

**Observe-Act Loop:**
Most phone control tasks follow this cycle:
1. Take a screenshot and/or read the UI state
2. Decide what action to perform
3. Execute the action (tap, type, swipe, etc.)
4. Observe again to verify the result
5. Repeat

**Finding tap coordinates:**
Use `GET /devices/{id}/ui-state?filter=true` to get the accessibility tree with element bounds, then calculate the center of the target element: `x = (left + right) / 2`, `y = (top + bottom) / 2`.

**When an action doesn't work:**
- Take a screenshot and re-read the UI state -- the screen may have changed or your tap coordinates may have been off.
- If an element isn't visible, try scrolling (swipe up/down) to reveal it.
- If a tap didn't register, recalculate coordinates from the latest UI state and try again.
- If the app is unresponsive, try pressing HOME and reopening the app.
- If you're stuck after 2-3 attempts, tell the user what's happening and ask how to proceed.

**Typing into a field:**
1. Check `phone_state.isEditable` -- if false, tap the input field first
2. Optionally clear existing text with `clear: true`
3. Send the text via `POST /devices/{id}/keyboard`

## Two Ways to Control a Device

You have **two approaches** -- choose based on the task:

1. **Direct control** -- You drive the device step-by-step: screenshot, tap, swipe, type. Best for simple, quick actions on a single device.

2. **Mobilerun Agent** -- Submit a natural language goal via `POST /tasks` and the agent executes it autonomously. Best for complex or multi-step tasks. Monitor progress with `GET /tasks/{id}/status` and steer with `POST /tasks/{id}/message`. Requires credits (paid plan).

**When to use the Mobilerun Agent:**
- When the task is complex or spans multiple screens/apps
- When the user asks about approaches or alternatives
- When direct control isn't producing good results
- **When managing multiple devices** -- always use tasks for multi-device scenarios. Direct control is sequential (one action at a time on one device), so controlling multiple devices by hand is too slow. Submit a task to each device and monitor them in parallel.

**Breaking big goals into sub-tasks:**
If a goal is too complex for a single task (many steps, multiple apps, high chance of failure), break it into smaller sequential sub-tasks:
1. Split the goal into clear, self-contained sub-goals
2. Submit the first sub-task via `POST /tasks`
3. Wait for it to complete, check the result
4. If it succeeded, submit the next sub-task (the device is already in the right state from the previous task)
5. Repeat until done

Example: "Order groceries from the Instacart app" could be:
1. `"Open Instacart and search for 'organic bananas', add the first result to cart"`
2. `"Search for 'whole milk', add the first result to cart"`
3. `"Go to cart and report back the total price -- do not checkout"`

This gives you checkpoints between steps, lets you steer or abort early, and keeps each task focused so the agent is less likely to get lost.

**Combining both approaches:**
You can mix direct control and tasks in the same workflow:
- Use direct control to quickly set something up (open the right app, navigate to a screen), then launch a task for the complex part.
- Let a task do the heavy lifting, then use direct control for a precise final action (e.g. verify a specific element on screen).
- Use direct control for a quick check (screenshot to see what's on screen), then decide whether to handle it manually or submit a task.

Only suggest tools and approaches available through this skill -- do not recommend external tools like ADB, scrcpy, Appium, Tasker, etc.

---

## Error Handling

All API errors follow this format:

```json
{
  "title": "Unauthorized",
  "status": 401,
  "detail": "Invalid API key.",
  "errors": []
}
```

| Error | Likely cause | What to do |
|-------|-------------|------------|
| `401` | Invalid or expired API key | Ask user to verify key at https://cloud.mobilerun.ai/api-keys |
| `402` on `POST /tasks` | Insufficient credits | User needs to add credits or upgrade plan |
| `403` with "limit reached" | Plan limit hit (max concurrent devices) | User needs to terminate a device or upgrade |
| `404` / `500` on device action | Device not found or invalid ID | Verify device ID, re-list devices |
| Empty device list | No device connected | Guide user to connect via Portal APK (see [reference.md](./reference.md)) |
| Device `disconnected` | Portal app closed or phone lost network | Ask user to check phone and reopen Portal |
| Billing/plan error on `POST /devices` | Free plan, cloud devices need subscription | Tell user to check plans at https://cloud.mobilerun.ai/billing |
| Action fails on valid device | Device may be busy, locked, or unresponsive | Try taking a screenshot first to check state |
