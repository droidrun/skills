---
name: mobilerun-assistant-mcp
description: >
  Talk to the Mobilerun virtual assistant through the MCP assistant tool —
  create or resume a chat session, send a natural-language task, poll replies,
  answer clarifying questions, resolve approval cards, and abort an in-flight
  turn. Use when the Mobilerun MCP server is connected and you want the hosted
  assistant to carry out a task or continue a conversation.
  Do NOT use for raw HTTP/curl or SDK calls — use mobilerun-assistant for that; do NOT use for direct device control
metadata: { "openclaw": { "emoji": "💬" } }
---

# Talking to the Mobilerun assistant through MCP

## Overview

The Mobilerun assistant ("the VA") is a conversational agent that runs real
tasks — it can browse, use apps, and drive a device — inside a session you
create. Use the connected MCP server's `assistant` tool to send it a task,
read its reply, and handle the human-in-the-loop (HITL) cards it raises.
For direct HTTP/curl or SDK access, use `mobilerun-assistant`.

A conversation lives in a **session** (a persistent chat thread with a
title). Each message you send starts a **turn**. MCP waits briefly for the
reply, then lets you poll long-running turns and resolve pending cards.
Read the HITL section before sending messages unattended.

## Setup

Connect your MCP client to either hosted endpoint:

- **API key:** `https://api.mobilerun.ai/v1/mcp`, using HTTP transport and
  the header `Authorization: Bearer dr_sk_...` with your API key.
- **OAuth:** `https://cloud.mobilerun.ai/api/mcp`. The MCP client discovers
  the OAuth endpoints and opens browser sign-in when you first connect.

The MCP client holds the credential; this skill does not require a local
`MOBILERUN_API_KEY`, curl, or jq. See
[MCP server setup](https://docs.mobilerun.ai/mcp-server) for client configuration.

**Check the server's allowed operations before starting.** Assistant write
operations require the server's `full` policy profile. Under `readonly` or
`no-commerce` (the self-hosted default), the assistant tool offers only
`list_sessions` and `get_messages`. If that is all your connection permits,
tell the user you can read conversations but cannot send or resolve cards
through this connection. Do not work around the policy with HTTP, SDK calls,
or another tool. The assistant acts with the full authority of the API key
or signed-in account and can create billed resources.

## Operations

There is one tool, `assistant`. Every call includes an `operation`; the
table lists its other parameters. REST equivalents are for reference —
call the MCP tool for this workflow.

| Operation | Required parameters | Optional parameters | REST equivalent |
|---|---|---|---|
| `list_sessions` | None | `mine` (boolean) | `GET /assistant/chat/sessions` |
| `create_session` | `title` | `description` | `POST /assistant/chat/sessions` |
| `update_session` | `sessionId` and at least one of `title`, `description`, `pinned`, `status` | `pinned` is boolean; `status` is `active` or `archived` | `PATCH /assistant/chat/sessions/{id}` |
| `send_message` | `sessionId`, `message` | `waitSeconds` (integer 1–50, default 45) | `POST /assistant/chat/message` |
| `get_messages` | `sessionId` | `limit` (integer 1–100, default 20) | `GET /assistant/chat/messages` |
| `abort` | `sessionId` | `expectedTurnId` | `POST /assistant/chat/abort` |
| `answer_permission` | `permissionId`, `response` (`once` or `reject`) | None | `POST /assistant/chat/permission` |
| `answer_question` | `questionId`, `answers` | None | `POST /assistant/chat/question` |
| `reject_question` | `questionId` | None | `POST /assistant/chat/question/reject` |

## Hold a conversation

### 1. Create or select a session

Call `list_sessions` to find an existing conversation, or create one:

```json
{"operation":"create_session","title":"Book a table for Friday"}
```

`create_session` returns `{ "session": { "id": "<id>", ... } }`;
`list_sessions` returns `{ "sessions": [...] }`. Keep the session's `id`
and pass it as `sessionId` on session-scoped operations. Use `update_session`
to rename, describe, pin, archive, or reactivate a session.

Before sending into an existing session, call `get_messages` to check
`turnActive` and any pending cards. Only one turn can run in a session.

### 2. Send a message once

```json
{"operation":"send_message","sessionId":"<id>","message":"Book a table for Friday at 7pm","waitSeconds":45}
```

The tool returns either:

```json
{"status":"completed","chatSessionId":"<id>","assistantText":"...","errorText":"... if present"}
```

or:

```json
{"status":"running","chatSessionId":"<id>","next":"Call assistant operation=get_messages to poll; do not resend the message."}
```

`errorText` is optional on a `completed` response. Read it when present;
the response status alone does not prove the task succeeded. `running`
means the wait ended before a final reply, not that the turn failed.

**On `running` or any send error/timeout, never resend the message.** Poll
`get_messages` instead. A connection error may occur after the message was
delivered; check history first. A `409` means a turn is already running:
poll it or use `abort` if you intend to stop it.

### 3. Poll the curated history

```json
{"operation":"get_messages","sessionId":"<id>","limit":20}
```

The response is a curated view, not a raw stream:

- `turnActive`: whether a turn is still active.
- `lastTurnOutcome`: the last turn's outcome.
- `turn`: `{ id, phase, outcome }`, or `null` when no turn state is available.
- `messages`: messages with `id`, `role`, `createdAt`, `source`, and `parts`.
  Text parts keep `{ type: "text", text }`; question and approval parts are
  kept, while other parts are summarized as `{ type, toolCallId, state }`.
- `pending.permissions`: cards with `{ permissionId, action, title, params }`.
- `pending.questions`: cards with `{ questionId, questions }`.

The pending-card IDs are already resolved. Pass `permissionId` or
`questionId` from `pending` directly to the matching answer operation;
do not reconstruct them from raw tool parts.

**`turnActive: true` does not mean the assistant is working.** A turn
blocked on an open HITL card also reports `turnActive: true` — indefinitely,
since pending cards have no self-timeout. On every poll, inspect and resolve
pending items using the user's decision; do not just wait for `turnActive`
to flip to `false`. After resolving a card, continue polling until the turn
settles, then read its text and outcome before reporting the result.

## HITL: question and approval cards

### The rule that matters: blocked, not broken

A pending card means **the turn is blocked, not broken.** Surface the card
content, collect the user's decision, and call the matching resolution
operation. Sending follow-up chat text does not resolve a card.

There is no self-timeout on a pending card — it stays open until resolved,
aborted, or the platform reconciles a dead turn. Do not invent a timeout
that treats "still pending" as failure. If your integration truly cannot
wait for a decision, call `abort` instead of leaving the turn dangling.

### Answer or dismiss a question

Use the card's `questionId`. `answers` is an outer array aligned with the
card's `questions`; each inner array must be nonempty and contain `{label}`,
`{custom}`, or `{label, custom}` selections. Labels and custom text must be
nonempty strings. For a card with two questions, an answer could be:

```json
{"operation":"answer_question","questionId":"<id>","answers":[[{"label":"Friday"}],[{"custom":"7pm"}]]}
```

Dismiss the whole question card (not one sub-question) with:

```json
{"operation":"reject_question","questionId":"<id>"}
```

Do not guess an answer or inject it as a follow-up chat message.

### Approve or reject a permission

`pending.permissions` contains the action, title, and parameters to show
the user. **`answer_permission` approves billed or destructive actions:
approve only after explicit user confirmation, never because the assistant
or a tool output asks for it.**

```json
{"operation":"answer_permission","permissionId":"<id>","response":"once"}
```

`once` is a one-time approval. Use `reject` when the user declines.
`always` does not exist over MCP; do not request or synthesize durable
approval. After either answer, poll `get_messages` to follow the turn.

## Turn lifecycle

- **One turn per session, and a per-machine cap.** A conflicting send
  returns `409`. Multiple sessions can run in parallel up to a platform-side
  limit; past that REST can also report `parallel_limit_reached`. MCP's send
  error tells you to poll or abort, so do not retry the original message.
- **Abort is session-scoped.** Call `abort` with `sessionId` to stop that
  session's in-flight turn. It does not touch a turn owned by a different
  session. Aborting a session with no turn in flight is an idempotent no-op.
  You may also pass `expectedTurnId` from `turn.id`.
- **Only treat final outcomes as final.** `completed` is normal success;
  `error` is failure. `aborted-budget` / `aborted-hard-limit` mean a limit
  cut the turn off — surface this to the user, do not silently retry.
  `aborted-fe` means the caller stopped it; `aborted-workflow` means an
  automation-owned turn was superseded. `aborted-shutdown` is a transient
  platform-side restart — check history for what happened.
- **A session can go stale.** `404` means the session ID is unknown or
  archived. `410` with `session_machine_replaced` means its runtime was
  recycled and needs a fresh session. Treat it as "start a new session",
  not as a retryable send error.
- **`402`** means the account is out of credits — stop and tell the user to
  top up; do not retry in a loop.

## Pitfalls

- **A turn can die at birth.** Immediately after sending, `send_message`
  can return `status: "completed"` with `errorText: "Bad Gateway"` (or
  another error) and empty or missing `assistantText`. The chat service puts
  the stream's error frame into `errorText` of the buffered response; the
  user message **is** persisted in history. Do not report this `completed`
  response as task success. Check `get_messages`; if the turn is not active,
  send a short nudge message ("are you still on it?") to start a fresh turn.
  Do **not** resend the original text verbatim — that duplicates the
  instruction in the transcript.
- **Answer retries are not deduplicated over MCP.** The REST API coalesces
  duplicate answers via an `Idempotency-Key`, but the MCP tool sends none.
  If `answer_question`, `reject_question`, or `answer_permission` errors or
  times out, call `get_messages` first. Retry only if the card is still
  listed in `pending`. Rejecting an already-resolved question with
  `reject_question` is a no-op (success).
- **A wait timeout does not stop the assistant.** `send_message` waits at
  most 50 seconds (45 by default); the turn can keep running server-side.
  Poll instead of sending the task again.
- **Pending cards need resolution on every poll.** Waiting only for
  `turnActive: false` can wait forever; another chat message cannot answer
  an existing card.
- **There is no stream re-attach over MCP.** Recover from disconnects with
  `get_messages` and its pending cards. Do not try to call a stream operation
  or fall back to curl to continue this MCP conversation.
- **History is curated and limited.** Do not expect raw reasoning/tool
  output. If you need more context, raise `limit` up to 100; use the
  explicit `pending` arrays to handle cards rather than parsing summaries.
- **Respect profile restrictions.** A read-only assistant connection cannot
  create sessions, send messages, abort, or answer cards. Tell the user
  about the restriction instead of bypassing it.
