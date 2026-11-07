-- wdb-bug-relay D1 schema. Emails live only in reporters.email; nothing public ever reads it.
CREATE TABLE IF NOT EXISTS reporters (
  reporter_code TEXT PRIMARY KEY,          -- public id, e.g. R-7f3a
  email TEXT,                              -- private; NULL for anonymous
  email_hash TEXT UNIQUE,                  -- salted sha256 for lookup
  install_hash TEXT,                       -- salted sha256 of the game's install id
  opt_in INTEGER NOT NULL DEFAULT 0,       -- 1 = email me updates/questions
  created INTEGER NOT NULL,
  unsub_at INTEGER
);
CREATE INDEX IF NOT EXISTS reporters_install ON reporters(install_hash);
CREATE TABLE IF NOT EXISTS reports (
  issue_number INTEGER PRIMARY KEY,
  reporter_code TEXT NOT NULL,
  created INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',
  door TEXT,
  desc_hash TEXT,
  install_hash TEXT,
  shot_key TEXT
);
CREATE INDEX IF NOT EXISTS reports_dupe ON reports(desc_hash, created);
CREATE TABLE IF NOT EXISTS rate (
  bucket TEXT PRIMARY KEY,                 -- kind:hash:window
  count INTEGER NOT NULL,
  expires INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS outbox (        -- private transactional outbox
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reporter_code TEXT NOT NULL,             -- email looked up at send time, never copied here
  issue_number INTEGER,
  kind TEXT NOT NULL,                      -- update | ask | closed | reopened
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  created INTEGER NOT NULL,
  state TEXT NOT NULL DEFAULT 'queued',    -- queued | sent | failed | dropped
  sent_at INTEGER,
  sender TEXT,                            -- fixed application sender, not reporter contact
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_attempt_at INTEGER,
  last_stage TEXT,
  last_error TEXT,                         -- fixed enum only, never provider/exception text
  last_http_status INTEGER,
  provider_id TEXT
);
CREATE TABLE IF NOT EXISTS hooks (         -- webhook delivery dedupe
  delivery_id TEXT PRIMARY KEY,
  created INTEGER NOT NULL
);

-- Operator-armed single authorization, consumed before attempting one existing row.
CREATE TABLE IF NOT EXISTS outbox_retry (
  slot INTEGER PRIMARY KEY CHECK (slot=1),
  outbox_id INTEGER NOT NULL,
  armed INTEGER NOT NULL DEFAULT 0,
  consumed_at INTEGER
);
