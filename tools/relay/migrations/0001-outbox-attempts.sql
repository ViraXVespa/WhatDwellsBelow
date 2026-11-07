-- Additive migration for existing deployments. Apply once before new source.
ALTER TABLE outbox ADD COLUMN sender TEXT;
ALTER TABLE outbox ADD COLUMN attempt_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE outbox ADD COLUMN last_attempt_at INTEGER;
ALTER TABLE outbox ADD COLUMN last_stage TEXT;
ALTER TABLE outbox ADD COLUMN last_error TEXT;
ALTER TABLE outbox ADD COLUMN last_http_status INTEGER;
ALTER TABLE outbox ADD COLUMN provider_id TEXT;
-- Operator-armed single authorization, consumed before attempting one existing row.
CREATE TABLE IF NOT EXISTS outbox_retry (
  slot INTEGER PRIMARY KEY CHECK (slot=1),
  outbox_id INTEGER NOT NULL,
  armed INTEGER NOT NULL DEFAULT 0,
  consumed_at INTEGER
);
