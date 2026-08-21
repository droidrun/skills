---
name: mobilerun-assistant
description: >
  Talk to the Mobilerun virtual assistant (VA) over the chat API/SDK — send it a
  task, stream its reply, and handle the human-in-the-loop (HITL) cards it raises
  mid-turn (clarifying questions and approval prompts). Use when: (1) sending the
  Mobilerun assistant a natural-language task over chat, (2) reading its streamed
  reasoning/tool/text output, (3) answering or rejecting a question card it asks,
  (4) approving or rejecting a sensitive-action card (once/always/reject),
  (5) reconnecting to a dropped stream or recovering a pending card from history,
  (6) aborting an in-flight turn. Covers the Mobilerun chat REST endpoints under
  /assistant/chat and the @mobilerun/sdk (TypeScript) / mobilerun-sdk (Python)
  client (client.assistant.conversations.*). Requires a Mobilerun API key
  (prefixed dr_sk_). Do NOT use for direct phone tap/swipe control — use the
  mobilerun (device control) skill for that.
metadata: { "openclaw": { "emoji": "💬", "primaryEnv": "MOBILERUN_API_KEY", "requires": { "env": ["MOBILERUN_API_KEY"], "bins": ["curl", "jq"] } } }
---

# Talking to the mobilerun assistant

## Overview

The mobilerun assistant ("the VA") is a conversational agent that runs real
tasks — it can browse, use apps, and drive a device — inside a session you
create. You talk to it the same way you'd talk to a person over chat: send a
message, read the streamed reply, and sometimes the assistant needs a human
to make a call before it can continue (approve a risky action, or answer a
clarifying question). That's HITL, and it is the part of this API that is
easiest to get wrong — read the HITL section before you ship anything that
sends messages unattended.

A conversation lives in a **session** (a persistent chat thread with a
title). Each message you send starts a **turn**: the assistant streams back
its reasoning, tool calls, and text until the turn settles.

## Auth & endpoints

All requests use `Authorization: Bearer <api-key>` (your `dr_sk_...` key) and
the base URL `https://api.mobilerun.ai/v1`.

| Purpose | Method & path | SDK method |
|---|---|---|
| List sessions | `GET /assistant/chat/sessions` | `client.assistant.conversations.list()` |
| Create a session | `POST /assistant/chat/sessions` | `client.assistant.conversations.create()` |
| Rename / archive / pin | `PATCH /assistant/chat/sessions/{id}` | `client.assistant.conversations.update()` |
| Send a message | `POST /assistant/chat/message` | `client.assistant.conversations.send()` |
| Read history | `GET /assistant/chat/messages` | `client.assistant.conversations.history()` |
| Re-attach to a live turn | `GET /assistant/chat/stream` | `client.assistant.conversations.stream()` |
| Abort the in-flight turn | `POST /assistant/chat/abort` | `client.assistant.conversations.abort()` |
| Answer a question card | `POST /assistant/chat/question` | `client.assistant.conversations.answerQuestion()` |
| Dismiss a question card | `POST /assistant/chat/question/reject` | `client.assistant.conversations.rejectQuestion()` |
| Answer an approval card | `POST /assistant/chat/permission` | `client.assistant.conversations.answerPermission()` |

<!-- Field names below are copied verbatim from openapi.json. Where the spec
     was ambiguous this file says so inline rather than guessing. -->

## Hold a conversation

### 1. Create a session

```bash
curl -sX POST https://api.mobilerun.ai/v1/assistant/chat/sessions \
  -H "Authorization: Bearer $MOBILERUN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title": "Book a table for Friday"}'
```

Response: `{ "session": { "id": "<uuid>", "title": ..., "status": "active", ... } }`.
Only `title` is required (`description`, `agent` are optional). Pass an
`Idempotency-Key` header if you might retry the create call — a duplicate
submit within 24h returns the original session instead of creating a second
one.

### 2. Send a message and stream the reply

Always send with `Accept: text/event-stream`. A buffered JSON reply
(`Accept: application/json`) exists, but it hard-times-out at 110s and
returns only partial text — see Pitfalls. Streaming is the only mode that
works for turns that involve HITL, since the stream has to stay open while a
card is resolved.

```bash
curl -N -sX POST https://api.mobilerun.ai/v1/assistant/chat/message \
  -H "Authorization: Bearer $MOBILERUN_API_KEY" \
  -H "Accept: text/event-stream" \
  -H "Content-Type: application/json" \
  -d '{"sessionId": "<uuid>", "message": "Book a table for Friday at 7pm"}'
```

The `sessionId` is required; `message` is the plain-text user turn; `agent`
is optional (selects a non-default assistant persona if your account has
more than one).

```typescript
import Mobilerun from "@mobilerun/sdk";

const client = new Mobilerun({ apiKey: process.env.MOBILERUN_API_KEY });

const stream = await client.assistant.conversations.send({
  sessionId,
  message: "Book a table for Friday at 7pm",
});

for await (const part of stream) {
  // handle part.type — see "Read the stream" below
}
```

```python
from mobilerun_sdk import Mobilerun

client = Mobilerun(api_key=os.environ["MOBILERUN_API_KEY"])

stream = client.assistant.conversations.send(
    session_id=session_id,
    message="Book a table for Friday at 7pm",
)

for part in stream:
    # handle part.type — see "Read the stream" below
    ...
```

### 3. Read the stream

The stream carries typed parts: assistant text deltas, tool-call parts (the
assistant using a capability), and — the ones you must handle — HITL parts
(next section). Treat any part type you don't recognize as informational and
skip it rather than failing the turn.

The turn ends with a settle signal. Only treat these as **final**:
- `completed` — normal success.
- `error` — the turn failed.
- `aborted-budget` / `aborted-hard-limit` — the turn was cut off by a limit;
  surface this to the user, don't silently retry.

Treat these as **not your problem to solve** — the platform will resume or
the caller intentionally stopped it:
- `aborted-fe` — the caller (you) called abort.
- `aborted-workflow` — an automation-owned turn was superseded.
- `aborted-shutdown` — a transient platform-side restart; safe to reconnect
  and check history for what happened.

### 4. Read history

```bash
curl -s "https://api.mobilerun.ai/v1/assistant/chat/messages?sessionId=<uuid>&limit=50" \
  -H "Authorization: Bearer $MOBILERUN_API_KEY"
```

Returns `{ messages: [...], turnActive: boolean, truncated?: boolean }`.
`turnActive` tells you whether a turn is currently running in this session —
check it before sending a new message (see Concurrency below). Each
message's `parts` array uses the same part shapes as the live stream, so a
client that reconnects late (or polls instead of streaming) can recover a
pending HITL card from history alone — it doesn't have to have seen it live.

## HITL: question and approval cards

Mid-turn, the assistant can pause and ask a human for input. This shows up
as a tool part on the stream (and, once emitted, in `GET
/assistant/chat/messages` history):

- **Question card** — part type `tool-question`, `input: { questions: [...],
  questionID? }`. The assistant is asking a clarifying question (e.g. "Which
  of these two restaurants did you mean?").
- **Approval card** — part type `tool-hitl-approval`, `input: { action,
  title, params, permissionID, callID? }`. The assistant wants to perform a
  sensitive action (e.g. sending a payment, deleting something) and needs a
  human sign-off first.

Both use the same state machine on the part: `input-available` while the
card is open and unanswered, then `output-available` (resolved) or
`output-error` once a human responds.

### The rule that matters: blocked, not broken

When your client sees `input-available`, **the turn is blocked, not
broken.** Wait only until you can collect an explicit decision from your
user, then call the matching resolution method. Sending follow-up chat text
does not resolve a card.

Do:
- Surface the card content and collect the user's decision in your own UI.
- Keep the SSE stream open (or, if you're polling, keep polling
  `GET /assistant/chat/messages`) until you have that decision and have
  posted it. There is no self-timeout on a pending card — it stays open
  until resolved, aborted, or the platform reconciles a dead turn. Don't
  invent your own timeout that treats "still pending" as failure.
- If you reconnect after a drop, `GET /assistant/chat/stream` replays
  buffered events from the start of the active turn — a pending card comes
  back on reconnect. If there's no active turn, it 204s; fall back to
  history, which rehydrates any open card too.
- If your integration truly cannot wait (e.g. a fire-and-forget
  automation), call abort instead of leaving the turn dangling indefinitely.

Don't:
- Don't treat a lingering `input-available` card as an error and retry the
  send — that's a second turn while the first is still open and will 409
  (see Concurrency), and it does not answer the pending card.
- Don't guess an answer and try to inject it as a follow-up chat message.
- Don't synthesize or auto-approve an approval card. Obtain explicit user
  intent. `always` is durable approval — use it only when the user
  explicitly asks for lasting approval. `reject` is the safe choice when
  they decline. `once` is a one-time approval.

### Answer a question

Body: `{questionId, answers}`. Send the card's `questionID` as `questionId`.
`answers` is an outer array aligned with `input.questions`; each inner array
must be nonempty and contain `{label}`, `{custom}`, or `{label, custom}`
selections. Include `Idempotency-Key` on answer requests, especially
retries — the same key with the same answers coalesces duplicate submits.

```bash
curl -sX POST https://api.mobilerun.ai/v1/assistant/chat/question \
  -H "Authorization: Bearer $MOBILERUN_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: <unique-key>" \
  -d '{"questionId":"<id>","answers":[[{"label":"A"}]]}'
```

Dismiss the whole question card (not one sub-question) with `{questionId}`.
Already-resolved rejects return 200 (no-op).

```bash
curl -sX POST https://api.mobilerun.ai/v1/assistant/chat/question/reject \
  -H "Authorization: Bearer $MOBILERUN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"questionId":"<id>"}'
```

```typescript
await client.assistant.conversations.answerQuestion(
  { questionId, answers: [[{ label: "A" }]] },
  { headers: { "Idempotency-Key": key } },
);
await client.assistant.conversations.rejectQuestion({ questionId });
```

```python
client.assistant.conversations.answer_question(
    question_id=question_id,
    answers=[[{"label": "A"}]],
    extra_headers={"Idempotency-Key": key},
)
client.assistant.conversations.reject_question(question_id=question_id)
```

### Answer an approval

Body: `{permissionId, response}`. The stream field is `permissionID` — send
it as `permissionId`. `response` is exactly `once | always | reject`.

```bash
curl -sX POST https://api.mobilerun.ai/v1/assistant/chat/permission \
  -H "Authorization: Bearer $MOBILERUN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"permissionId":"<id>","response":"once"}'
```

```typescript
await client.assistant.conversations.answerPermission({
  permissionId, // stream field: permissionID
  response: "once",
});
```

```python
client.assistant.conversations.answer_permission(
    permission_id=permission_id,  # stream field: permissionID
    response="once",
)
```

## Turn lifecycle

- **One turn per session, and a per-machine cap.** Sending a message while a
  turn is already in flight for that session returns `409`. Multiple
  sessions can run in parallel up to a platform-side limit; past that you
  also get `409` with `code: "parallel_limit_reached"`. Check `turnActive`
  from `GET /assistant/chat/messages` (or the session list) before sending.
- **Abort is session-scoped.** `POST /assistant/chat/abort` with `{sessionId}`
  stops that session's in-flight turn (idempotent — aborting an already-idle
  session just returns `204`). It does not touch a turn owned by a different
  session.
- **A session can go stale.** `404` means the session id is unknown or
  archived. `410` with `code: "session_machine_replaced"` means the
  session's runtime was recycled and needs a fresh session (the response
  includes `recovery: "handoff"` — treat it as "start a new session", not as
  a retryable error).
- **`402`** means the account is out of credits — stop and tell the user to
  top up, don't retry in a loop.

## Pitfalls

- **Buffered (`Accept: application/json`) mode times out at 110s** and
  returns whatever partial `assistantText` it has as a `504`. Any turn that
  might run long, or might hit a HITL card, must use streaming
  (`Accept: text/event-stream`) instead.
- **Don't blindly retry a send on a network error.** You may have actually
  reached the server and started a turn; retrying can double-fire the
  message or collide with the 409 "already in flight" guard. On an
  ambiguous failure, check `turnActive` / history first, and prefer
  `GET /assistant/chat/stream` to re-attach to whatever is already running
  before sending anything new.
- **Prefer SSE end to end.** It's the only mode that supports both long
  turns and HITL without dropping the pending-card state.
- **Reconnecting after any disconnect** is: `GET /assistant/chat/stream` first
  (replays the active turn from the start; `204` if nothing is running),
  then `GET /assistant/chat/messages` to refetch full history and pick up
  anything — including an unresolved HITL card — you might have missed.
