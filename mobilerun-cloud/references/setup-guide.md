# Cloud Android & Cloud iOS Setup

Best practices for setting up Cloud Android and Cloud iOS devices. Full guide: https://docs.mobilerun.ai/guides/cloud-device-setup. Device types: https://docs.mobilerun.ai/device-types.

---

## Before Provisioning

1. **Create a Google account** — have credentials ready before the device is provisioned. The agent can handle Google sign-in if credentials are stored in Mobilerun.
2. **Configure a proxy** — use a managed Mobilerun Connect proxy or your own SOCKS5 proxy (Personal Phones use the phone's own network and don't need one). Pick or register it in the Proxies tab (https://docs.mobilerun.ai/proxies) or via `POST /proxies` for your own. Managed proxies can cost money, so never create one without the user's explicit OK.
3. **Match proxy country to locale** — a mismatch between proxy country and device locale is a common detection signal. Smart IP automatically aligns GPS, timezone, and language to the proxy country.

---

## After Provisioning

- **Install apps via Google Play Store** — do not sideload APKs from third-party sources (APKMirror, etc.). Third-party APKs can crash the device or be incompatible. Play Store apps are verified and auto-update.
- **Wait for Ready state** — provisioning takes a few minutes (`GET /devices/{deviceId}/wait`). Don't assume the device is broken if it doesn't appear immediately.

---

## eSIM

eSIM support depends on the device (for example dedicated Cloud iOS); check `GET /devices/{deviceId}/capabilities`. The user's eSIM must support activation or roaming in the country where the device is hosted (see https://docs.mobilerun.ai/device-types). Do not buy an eSIM or phone number unless the user asked for exactly that.
