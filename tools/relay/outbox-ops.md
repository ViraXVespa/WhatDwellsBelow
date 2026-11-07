# Outbox diagnostics and one authorized retry

Apply `migrations/0001-outbox-attempts.sql` **once**, before deploying the new source. Additive only: existing report, subject and body remain untouched. Old rows have attempt_count0 (historical attempts unknown), not proof of no previous attempt. For the approved legacy row1 record its unchanged application sender; never regenerate body, signed unsubscribe link or reporter contact.

Dispatch atomically claims a queued row as sending, checks opt-in/unsubscribe, and stores only attempt timestamp/count, fixed stage/error enum, numeric HTTP status and accepted provider ID. No raw provider/exception message, credentials, contact, message body or signed URL goes in diagnostics or logs. `sent` means provider acceptance, not delivered. An interrupted sending claim stays held for operator reconciliation; no automatic reset.

## Default disabled

No Cron Trigger is configured (`triggers.crons=[]`), and outbox_retry is initially empty. There is no new HTTP endpoint. The scheduled handler consumes the **single** slot1 authorization before dispatching its selected existing row; it does not scan/drain queued mail. Consumed authorization cannot run again, even if sending fails. A retry outside24hours of row creation is refused because Resend idempotency expires. Same key with changed payload is unsafe; preserve original stored subject/body/sender and reporter identity.

## Explicit operator recovery (not automatic)

1. Obtain approval for the exact existing message and one attempt; read row status, comments, provider records and opt-in first. Already sent, unsubscribed, interrupted or expired rows do not send.
2. Arm the singleton permit for that id using sanctioned D1 administration: slot1, outbox_id selected, armed1. Do not create another report/comment or replay a webhook (delivery dedupe prevents replay dispatch).
3. Through sanctioned Cloudflare Cron administration only, temporarily schedule the Worker. One scheduled invocation consumes the permit and uses `wdb-bug-relay/outbox/<id>` with unchanged payload. Concurrent invocations cannot claim the same row twice.
4. Remove the temporary Cron Trigger after observing consumption. Read private stage/error/status/provider_id. A failure requires separate diagnosis/approval before another permit; never blindly rearm. Provider acceptance requires separate read-only delivery confirmation and does not prove inbox placement. Do not rely on a retry after the24hour window without reconciliation.

The production relay uses installed Worker secrets. Deployment must preserve them; never use file-reference strings as credential values, extract credentials, or add a public debug/send endpoint.

Workers supports `redirect:manual`, not `error`. The adapter rejects3xx without following; a real local Workerd regression constructs the production request with fake credentials and no outbound HTTP.
