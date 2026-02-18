---
name: mobilerun
description: >
  Control real Android phones through the Mobilerun API. Supports tapping, swiping,
  typing, taking screenshots, reading the UI accessibility tree, and managing apps.
  Use when the user wants to automate or remotely control an Android device, interact
  with mobile apps, or run AI agent tasks on a phone. Requires a Mobilerun API key
  (prefixed dr_sk_) and a connected device (personal phone via Portal APK or cloud device).
---

# Mobilerun

Control real Android phones through an API -- tap, swipe, type, take screenshots, read the UI tree, manage apps, and more.

## What You Need

1. A **Mobilerun API key** (starts with `dr_sk_`) from the user
2. A **connected device** (user's personal phone via Portal APK, or a cloud device)

## Before You Start

Verify the setup is working:

1. **Test the API key:**
   ```
   GET https://api.mobilerun.ai/v1/devices
   Authorization: Bearer dr_sk_...
   ```
   - `200` = key is valid
   - `401` = key is bad, expired, or revoked -- ask the user to check https://cloud.mobilerun.ai/api-keys

2. **Check for a connected device:**
   Look for a device with `state: "ready"` in the response. If none:
   - No devices at all = user hasn't connected a phone yet
   - Device with `state: "disconnected"` = Portal app lost connection, ask user to reopen it

3. **Confirm device is responsive:**
   ```
   GET https://api.mobilerun.ai/v1/devices/{deviceId}/screenshot
   ```
   If this returns a PNG image, you're good to go.

If the user doesn't have an API key or account yet, see [setup.md](./setup.md) for how to guide them through it.

## Quick Reference

| Goal | Endpoint |
|------|----------|
| See the screen | `GET /devices/{id}/screenshot` |
| Read UI elements | `GET /devices/{id}/ui-state?filter=true` |
| Tap | `POST /devices/{id}/tap` -- `{x, y}` |
| Swipe | `POST /devices/{id}/swipe` -- `{startX, startY, endX, endY, duration}` |
| Type text | `POST /devices/{id}/keyboard` -- `{text, clear}` |
| Press key | `PUT /devices/{id}/keyboard` -- `{key}` (Android keycode) |
| Go back | `POST /devices/{id}/global` -- `{action: 1}` |
| Go home | `POST /devices/{id}/global` -- `{action: 2}` |
| Open app | `PUT /devices/{id}/apps/{packageName}` |
| List apps | `GET /devices/{id}/apps` |

All endpoints use base URL `https://api.mobilerun.ai/v1` with `Authorization: Bearer dr_sk_...`.

## Detailed Documentation

- **[setup.md](./setup.md)** -- Authentication, API key setup, device connectivity, troubleshooting
- **[phone-api.md](./phone-api.md)** -- Phone control API: screenshot, UI state, tap, swipe, type, app management
- **[subscription.md](./subscription.md)** -- Plans, pricing, credits, device types, and when to recommend upgrades

## Common Patterns

**Observe-Act Loop:**
Most phone control tasks follow this cycle:
1. Take a screenshot and/or read the UI state
2. Decide what action to perform
3. Execute the action (tap, type, swipe, etc.)
4. Observe again to verify the result
5. Repeat

**Finding tap coordinates:**
Use `GET /devices/{id}/ui-state?filter=true` to get the accessibility tree with element bounds, then calculate the center of the target element to get tap coordinates.

**Typing into a field:**
1. Check `phone_state.isEditable` -- if false, tap the input field first
2. Optionally clear existing text with `clear: true`
3. Send the text via `POST /devices/{id}/keyboard`

## Error Handling

| Error | Likely cause | What to do |
|-------|-------------|------------|
| `401` | Invalid or expired API key | Ask user to verify key at https://cloud.mobilerun.ai/api-keys |
| Empty device list | No device connected | Guide user to connect via Portal APK (see setup.md) |
| Device `disconnected` | Portal app closed or phone lost network | Ask user to check phone and reopen Portal |
| Billing/plan error on `POST /devices` | Free plan, cloud devices need subscription | Tell user to check plans at https://cloud.mobilerun.ai/billing |
| Action returns error on valid device | Device may be busy, locked, or unresponsive | Try taking a screenshot first to check state |
| `403` with "limit reached" | Plan limit hit (e.g. max concurrent devices) | User needs to terminate a device or upgrade (see [subscription.md](./subscription.md)) |
