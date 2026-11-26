# Checkout and payment

**Paid purchases require authorization.** Number and mailbox creation and Connect proxy purchases can raise `PaymentRequired` when payment is needed; cloud task execution consumes credits rather than using this checkout flow. `PaymentRequired.checkout` is a `Checkout` containing `url`, `expires_at`, `resource`, and `resource_id`. Treat checkout URLs as sensitive; do not log or expose them to an unrelated user.

Default `checkout="error"` raises the resumable error without opening a browser. `await error.wait_until_paid(timeout=600)` resumes polling after the user pays; a resumed wait does not cancel on timeout. Number and mailbox instances also expose `wait_until_paid(timeout=...)`. `PurchaseInProgress` can surface when a number purchase is already pending; it is a distinct conflict, not permission to buy again.

Alternatively pass `on_checkout=callback`, which receives `Checkout` and may be synchronous or async. `checkout="print"` and `checkout="browser"` opt into presentation; neither can be combined with a callback. For an owned new purchase, callback/presentation mode attempts cancellation on timeout, cancellation, or callback failure; cleanup can itself fail. A `CloudPhoneNumber` that resumes a `PurchaseInProgress` is borrowed (`resumed_existing=True`): callback failure, timeout and `close()` do not cancel that existing purchase. Default `payment_timeout` is 600 seconds; checkout URL preparation separately defaults to 30 seconds. `wait_until_paid(timeout=...)` has its own 600-second default; number readiness, mailbox readiness and OTP waits are separate timeouts. Review the dashboard when status or cancellation is uncertain.

`PaymentRequired.resource`, `resource_id`, `payment_url` and `checkout_expires_at` alias the corresponding `checkout` fields. `status` and `request_id` are inherited cloud-error diagnostics and may be unset. `PurchaseInProgress.resource_id` identifies the conflicting number; `checkout` may be `None`. Without a callback or a usable checkout the conflict is raised; do not assume a second purchase occurred.

The high-level number/mailbox `wait_until_paid()` returns that resource handle; their `PaymentRequired.wait_until_paid()` resumes the handle too. Low-level `numbers.create` and `mailboxes.create` errors resume to SDK `NumberRetrieveResponse` and `MailboxRetrieveResponse`, respectively; `buy_proxy` resumes to `ProxyRetrieveResponse`.

This pattern rents a number and asks the caller to present the checkout URL securely, then waits for user payment. **Paid operation:** it can rent a number and requires explicit approval; no payment is completed by polling. Closing an owned handle releases it, including a pending purchase; pass `keep=True` only when intentionally retaining ownership and managing cleanup separately.

```python
import sys
from collections.abc import Awaitable, Callable

from mobilerun.core.phone_number import CloudPhoneNumber
from mobilerun.errors import PaymentRequired
from mobilerun.models.checkout import Checkout


async def rent_with_checkout(
    country: str, present: Callable[[Checkout], Awaitable[None]]
) -> None:
    number = CloudPhoneNumber(country=country, plan="rent", billing="paid")
    try:
        try:
            await number
        except PaymentRequired as error:
            await present(error.checkout)
            await error.wait_until_paid(timeout=600)
        await number.wait_ready()
    finally:
        original = sys.exception()
        try:
            await number.close()
        except Exception as cleanup_error:
            if original is None:
                raise
            original.add_note(f"Number cleanup failed: {cleanup_error}")
```

For Connect `buy_proxy`, `PaymentRequired.wait_until_paid()` returns the activated proxy response; closing a number or mailbox is not a proxy cancellation API. Callback-mode cancellation is handled by its purchase operation. To cancel an authorized pending or active Connect purchase, call `await mobilerun.clients.cloud.proxies.cancel_proxy(resource_id, billing=Billing.NO_COMMERCE)` after importing the module and `Billing` from `mobilerun.models.billing`. This is destructive and can disconnect phones. Track ownership; never cancel somebody else's resource.
