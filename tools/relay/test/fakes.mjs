// In-memory D1 (sql.js) and KV fakes with the subset of the API the Worker uses.
import initSqlJs from "sql.js";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const SCHEMA = readFileSync(fileURLToPath(new URL("../schema.sql", import.meta.url)), "utf8");
const SQL = await initSqlJs();

export function fakeD1() {
  const db = new SQL.Database();
  db.exec(SCHEMA);
  const conv = (sql) => sql.replace(/\?(\d+)/g, "?$1");
  const stmt = (sql, args) => ({
    first() {
      const s = db.prepare(conv(sql)); s.bind(args);
      const row = s.step() ? s.getAsObject() : null; s.free();
      return Promise.resolve(row);
    },
    all() {
      const s = db.prepare(conv(sql)); s.bind(args); const rows = [];
      while (s.step()) rows.push(s.getAsObject()); s.free();
      return Promise.resolve({ results: rows });
    },
    run() {
      const s = db.prepare(conv(sql)); s.bind(args);
      while (s.step()); s.free();
      return Promise.resolve({ meta: { changes: db.getRowsModified() } });
    },
  });
  return { _db: db, prepare: (sql) => ({ bind: (...a) => stmt(sql, a), ...stmt(sql, []) }),
    rows: (sql) => { const r = db.exec(sql); return r.length ? r[0].values : []; } };
}

export function fakeKV() {
  const m = new Map();
  return { _m: m,
    async put(k, v, o = {}) { m.set(k, { v, meta: o.metadata || null }); },
    async getWithMetadata(k) { const e = m.get(k); return e ? { value: e.v, metadata: e.meta } : { value: null, metadata: null }; } };
}
