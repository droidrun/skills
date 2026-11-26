# Proxy extensions

## Choose a proxy for a new cloud phone

**Paid cloud creation:** each example below creates a phone; rotating country capacity can add charges. Obtain approval first. Fixed and SOCKS5 reuse supplied capacity but the phone plan can still cost money. Select exactly one; this example accepts it as an argument, then creates a phone and closes its owned handle, including on connection failure.

```python
import sys

from mobilerun import CloudDevice
from mobilerun.core.proxy import CloudFixedProxy, CloudRotatingProxy, CloudSocks5Proxy


def proxy_choices(
    host: str, port: int, user: str, password: str
) -> list[CloudRotatingProxy | CloudFixedProxy | CloudSocks5Proxy]:
    return [
        CloudRotatingProxy(country="US", smart_ip=True),
        CloudFixedProxy("existing-connect-proxy-id"),
        CloudSocks5Proxy(host, port, user=user, password=password),
    ]


async def create_phone(
    proxy: CloudRotatingProxy | CloudFixedProxy | CloudSocks5Proxy,
) -> None:
    phone = CloudDevice(
        name="example", country="US", plan="minute", billing="paid", proxy=proxy
    )
    try:
        await phone.connect()
        print((await proxy.status()).connected)
    finally:
        original = sys.exception()
        try:
            await phone.close()
        except Exception as cleanup_error:
            if original is None:
                raise
            original.add_note(f"Phone cleanup failed: {cleanup_error}")
```

Provide SOCKS5 credentials through a secret manager or environment, never literals in source or logs. SOCKS5 provider charges are independent of Mobilerun billing. Fixed proxy means an existing purchased Connect ID; binding it does not buy capacity. Rotating country selection may provision paid capacity; the default new-phone proxy is rotating. Creation with `proxy=None` is invalid. Local HTTP proxies are not supported as cloud proxy inputs; there is no cloud HTTP proxy class in this package. The phone's `keep=True` retains it on close. Cleanup can fail; reconcile ownership and remote state.

## Local Android HTTP proxy

A compatible local Android device must support `http_proxy`. This mutates device settings. `LocalProxy(host, port)` does **not** support authentication; use an appropriate local unauthenticated endpoint, not credentials in the URL. Explicitly unbind before closing a borrowed device; replacement is exclusive.

```python
from mobilerun import AndroidDevice
from mobilerun.core.proxy import LocalProxy


async def local_proxy(serial: str, host: str, port: int) -> None:
    async with AndroidDevice(serial) as device:
        proxy = LocalProxy(host, port)
        await proxy.bind(device)
        try:
            print((await proxy.status()).connected)
        finally:
            await proxy.unbind()
```

## Existing phones, switching and actions

Existing cloud IDs reject creation-only `proxy=`. Connection reads and adopts the remote proxy; it does not purchase or switch one. A disconnected phone has no `phone.proxy`. An unidentified active proxy becomes `ExistingCloudProxy`; it cannot be reused as creation configuration. A supplied fixed ID or SOCKS5 binding changes the phone's network settings but does not itself buy Connect capacity. Country rotating binding can incur charges.

```python
from mobilerun import CloudDevice
from mobilerun.core.proxy import CloudFixedProxy


async def switch_existing(device_id: str, proxy_id: str) -> None:
    if not device_id.strip() or not proxy_id.strip():
        raise ValueError("Existing phone and proxy IDs required")
    async with CloudDevice(device_id=device_id.strip(), billing="no_commerce") as phone:
        replacement = CloudFixedProxy(proxy_id.strip())
        await replacement.bind(phone, force=True)
        status = await replacement.status()
        print(status.connected, status.protocol)
        await phone.actions.call("proxy.status", {})
```

`proxy.status()` returns `ProxyStatus` with `connected`, `name`, and `protocol`. `device.extensions` and `device.actions.list()` expose bound extensions and actions. A conflicting binding raises unless `force=True`; forced replacement does not close or release the replaced extension. Cloud proxy standalone unbind is rejected: switch instead. Local proxies support `await proxy.unbind()`. Closing a borrowed phone detaches local bookkeeping but does not disconnect its remote proxy. If switching fails, the implementation attempts rollback and reconciles remote status; an uncertain state can block actions.

`Device.set_proxy`, `clear_proxy`, and `proxy_status` are removed. Replace them with typed proxy extensions, `bind(..., force=True)` and `status()` or the `proxy.status` action. `DevicePool.bind_each` binds separate extensions per device.

`phone.proxy` is dynamically adopted or replaced: retrieve it again after a switch, rather than caching an old handle. `await pool.bind_each(lambda device: CloudFixedProxy(proxy_id), force=True)` constructs one extension per device; it changes remote connections and assumes the proxy can be shared. The returned extension list follows device order. Use a per-device factory when IDs differ; never return one shared extension object. Cloud unbind restrictions still apply.

For extension authors, `Proxy` is the shared `Extension` base (exclusive role `proxy`); subclasses implement `_apply(target)` and `_parameters()`. `on_bind` applies and records status; `on_unbind` disconnects. `CloudProxy` adds cloud-device validation, unmanaged-proxy conflict checks, reconciliation, cloud-native status and restricted unbind. These are lifecycle hooks, not methods to invoke directly; use `bind`/`unbind`. See [extension authoring](architecture.md).

## Python Connect capacity management

The low-level module `mobilerun.clients.cloud.proxies` manages capacity separately from proxy extension bindings. Each call takes explicit keyword `billing`, plus optional `api_key` and `base_url`; it manages its own cloud client. `Billing.NO_COMMERCE` permits reads, cancellation and existing connections, but is not a safety guard against destructive changes. `Billing.PAID` is required for purchases and country-based Connect provisioning.

| Async call | Result and effect |
| --- | --- |
| `list_proxies(billing=..., **params)` | `ProxyListResponse`, one page; accepts SDK list parameters. |
| `get_proxy(id, billing=...)` | `ProxyRetrieveResponse`. |
| `buy_proxy(country, type="residential", billing=..., name=..., keep=False, checkout="error", on_checkout=None, payment_timeout=600)` | **Paid:** `ProxyBuyResponse`; type also accepts `dedicated_residential` or `mobile`. May raise resumable `PaymentRequired`. |
| `cancel_proxy(id, billing=...)` | **Destructive:** returns `None`, cancels capacity and can disconnect phones. |
| `connect_device(device_id, params, billing=...)` | Changes remote phone connection; country provisioning can cost money. `params` is SDK `ProxyConnectParams`. |
| `device_status(device_id, billing=...)` | `ProxyStatusResponse`, remote device connection, not capacity purchase status. |
| `disconnect_device(device_id, billing=...)` | Destructive connection change, returns `None`; cloud phone policy may reject disconnect. |

For an approved purchase, call `await proxies.buy_proxy("US", billing=Billing.PAID)`; retain its ID and handle checkout as described in [payments](payments.md). List or retrieve before reuse; call `await proxies.cancel_proxy(id, billing=Billing.NO_COMMERCE)` only when authorized to release that capacity. Binding `CloudFixedProxy(id)` does not transfer purchase ownership, and closing the phone does not cancel capacity. `keep` belongs to the purchase flow, not the phone extension. Don't log proxy credentials or checkout URLs.

These functions access cloud; purchase is **paid** and cancellation is **destructive**. The caller must present checkout securely and get separate authorization before release. The purchase function returns the ID without automatically canceling it.

```python
from collections.abc import Awaitable, Callable

from mobilerun.clients.cloud import proxies
from mobilerun.errors import PaymentRequired
from mobilerun.models.billing import Billing
from mobilerun.models.checkout import Checkout


async def purchase_proxy(present: Callable[[Checkout], Awaitable[None]]) -> str:
    try:
        purchased = await proxies.buy_proxy("US", billing=Billing.PAID)
        return purchased.id
    except PaymentRequired as error:
        await present(error.checkout)
        active = await error.wait_until_paid()
        return active.id


async def inspect_proxy(proxy_id: str) -> None:
    await proxies.list_proxies(billing=Billing.NO_COMMERCE)
    await proxies.get_proxy(proxy_id, billing=Billing.NO_COMMERCE)


async def release_proxy(proxy_id: str) -> None:
    await proxies.cancel_proxy(proxy_id, billing=Billing.NO_COMMERCE)
```

## CLI

`mobilerun proxy list --billing no_commerce` and `mobilerun proxy status PROXY_ID --billing no_commerce` inspect existing capacity. `mobilerun proxy bind PROXY_ID DEVICE_ID --force --billing no_commerce` changes a phone's connection without buying a proxy. **Paid:** `mobilerun proxy buy --country US --type dedicated_residential --billing paid` purchases capacity and may require checkout. `mobilerun proxy release PROXY_ID` is destructive and disconnects affected phones. Run each command with `--help` for flags and confirmations.
