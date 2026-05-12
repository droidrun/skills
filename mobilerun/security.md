# Security & Privacy

## Data Handling

- **Screenshots and UI tree data** may contain personal information visible on the user's screen. This data is fetched on-demand and is not stored or cached beyond the API response.
- All API calls go to `https://api.mobilerun.ai/v1` over HTTPS.
- The skill does not collect analytics, telemetry, or usage data.

## Credentials

- The `MOBILERUN_API_KEY` (prefixed `dr_sk_`) is used solely for authenticating API requests.
- The key is never displayed, logged, or included in user-facing output.
- Keys can be created, rotated, or revoked at https://cloud.mobilerun.ai/api-keys.

## Device Permissions

The Mobilerun Portal app on Android requires the **Accessibility Service** permission. This allows the platform to read the UI element tree and control the device. The user grants this explicitly during setup and can revoke it at any time.

For iOS, the `mobilerun-ios` CLI uses WebDriverAgent via Xcode, requiring Developer Mode on the iPhone.

## Scope of Control

The skill can only interact with devices the user has connected to their Mobilerun account. All actions require a valid authenticated API key.
