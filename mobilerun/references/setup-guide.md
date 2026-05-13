# Cloud & Physical Phone Setup

Best practices for setting up Cloud Phones and Physical Phones. For full guides, see:
- Cloud Phone: https://docs.mobilerun.ai/guides/cloud-phone-setup
- Physical Phone: https://docs.mobilerun.ai/guides/physical-phone-setup

---

## Before Provisioning

1. **Create a Google account** — have credentials ready before the device is provisioned. The agent can handle Google sign-in if credentials are stored in Mobilerun.
2. **Configure a proxy** — Cloud and Physical Phones need a SOCKS5 proxy for internet access (Personal Phones use the phone's own network and don't need one). Register it in the Proxies tab or via `POST /proxies` before creating the device.
3. **Match proxy country to locale** — a mismatch between proxy country and device locale is a common detection signal. Smart IP (enabled by default on proxies) automatically aligns GPS, timezone, and language to the proxy country.

---

## After Provisioning

- **Install apps via Google Play Store** — do not sideload APKs from third-party sources (APKMirror, etc.). Third-party APKs can crash the device or be incompatible. Play Store apps are verified and auto-update.
- **Wait for Ready state** — provisioning takes a few minutes. Don't assume the device is broken if it doesn't appear immediately.

---

## eSIM (Physical Phones Only)

Physical Phones support eSIM for cellular connectivity. An eSIM gives the device a real phone number and mobile data connection.

**Important:** All Physical Phones are currently hosted in Germany. The user's eSIM must support activation or roaming in Germany to work on these devices.
