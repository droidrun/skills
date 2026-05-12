# Mobilerun Reference

Read this document when helping with setup, connection issues, billing, or webhooks.
For core API usage (tasks, device management), see [SKILL.md](./SKILL.md).

---

## Authentication

### How It Works

Mobilerun uses API keys for programmatic access. All API calls go to `https://api.mobilerun.ai/v1`
with the key in the Authorization header:

```
Authorization: Bearer dr_sk_...
```

- Keys are always prefixed with `dr_sk_` -- if a user provides something without this prefix, it's not a valid Mobilerun key
- Keys are created from the Mobilerun dashboard and can be revoked at any time
- Each key is tied to a single user account

### Getting an API Key

1. Go to **https://cloud.mobilerun.ai/api-keys** (sign in with Google, GitHub, or Discord if prompted)
2. Click **"New Key"**
3. Give the key a name
4. Copy the full key -- it's only shown once

### Troubleshooting Auth Issues

- **Key doesn't start with `dr_sk_`**: not a Mobilerun key. Copy it again from https://cloud.mobilerun.ai/api-keys
- **401 on a key that previously worked**: key may have been revoked. Create a new one.
- **User doesn't have an account**: go to https://cloud.mobilerun.ai/sign-in -- first login creates an account.

---

## Device Setup

### Android (Portal APK)

Connect a personal Android phone via the Mobilerun Portal app:

1. Download the latest APK from https://github.com/droidrun/mobilerun-portal/releases
2. Install the APK (approve sideloading if prompted — the app is open source)
3. Open the app, grant the permissions it requests (accessibility service, notifications, screen share, install auto-accept)
4. Tap **"Connect to Mobilerun"** and sign in with the same account used on the dashboard
5. Keep the app running — the phone stays online only while Portal is active

The device should appear at https://cloud.mobilerun.ai/devices as a Personal Phone.

**Common issues:**
- `disconnected`: Portal app was closed or phone lost internet — reopen the app
- Device not appearing: check accessibility service is enabled, Portal is open, phone has internet
- Connection fails: API key may be wrong or expired

### iOS (mobilerun-ios CLI)

Connect an iPhone using the `mobilerun-ios` CLI:

1. Requires a Mac with Xcode and an iPhone connected via USB
2. Enable Developer Mode on the iPhone (Settings → Privacy & Security → Developer Mode)
3. Download and install WebDriverAgent via Xcode
4. Run the `mobilerun-ios` CLI to connect

See the full guide at https://docs.mobilerun.ai/guides/connect-iphone

---

## Device Types & Pricing

No base plan is required — sign up for free and add devices as needed.

| Device | Hardware | Monthly Cost | Included Credits | Key Features |
|--------|----------|-------------|-----------------|-------------|
| **Personal Phone** | Your own device | $5/mo | 250/mo | BYO, persistent state |
| **Cloud Phone** | Virtual | $50/mo | 2,500/mo | Scalable, profiles, persistent |
| **Physical Phone** | Premium real device | $150/mo | 5,000/mo | eSIM, GPS, proxy, stealth |

### Credits

Credits are consumed when running tasks. 1 credit = $0.01 USD.

- **~0.5 credits per agent step** (varies by model, context length, vision/reasoning)
- Top up: $5 per 500 credits (one-time, no expiry)
- Monitor usage at https://cloud.mobilerun.ai/billing

### When to Recommend a Device Type

- **Personal Phone**: user wants to use their own hardware, quick testing
- **Cloud Phone**: scalable automation, multiple device identities via profiles
- **Physical Phone**: social media automation, apps that detect emulators, eSIM/GPS/proxy needed
- **User hits billing error**: they need a device subscription at https://cloud.mobilerun.ai/billing

---

## Webhooks

Subscribe to task lifecycle events to get notified when tasks change state.

### Subscribe

```
POST /hooks/subscribe
Content-Type: application/json

{
  "targetUrl": "https://your-server.com/webhook",
  "events": ["completed", "failed"],
  "service": "other"
}
```

Events: `created`, `running`, `completed`, `failed`, `cancelled`, `paused`
Services: `zapier`, `n8n`, `make`, `internal`, `other`

### List Hooks

```
GET /hooks
```

### Edit Hook

```
POST /hooks/{hook_id}/edit
Content-Type: application/json

{ "events": ["completed"], "state": "active" }
```

### Unsubscribe

```
POST /hooks/{hook_id}/unsubscribe
```
