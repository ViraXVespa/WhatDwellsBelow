// Validate a player report and render the public issue. Nothing here may emit the player's email.
import { DOORS } from "./doors.js";

export const LIMITS = {
  body: 2_500_000,      // whole request, bytes
  shot: 1_500_000,      // decoded screenshot, bytes
  desc: 4000, descMin: 10, title: 80,
  state: 12_000,        // JSON chars after key filter
  log: 16_000,          // crash only
};
export const BUILDS = ["release", "debug", "dev"];
export const PLATFORMS = ["windows", "linux", "macos", "web", "android", "ios"];
// The only state keys that reach the issue: Vira's list (no other user data).
export const STATE_KEYS = ["version", "platform", "build", "scene", "floor", "seed", "pos", "loadout",
  "recent", "perf", "settings", "run", "uptime_s"];

const EMAIL_RE = /[A-Z0-9._%+-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)*\.[A-Z]{2,}/gi;
const INSTALL_RE = /^[A-Za-z0-9_-]{8,64}$/;

export class Bad extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}

export function normEmail(raw) {
  if (raw == null || raw === "") return null;
  const e = String(raw).trim().toLowerCase();
  if (e.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e)) throw new Bad(422, "bad_email", "email looks invalid");
  return e;
}

// Strip anything email-shaped (and the given email verbatim) from public text.
export function scrub(text, email) {
  let s = String(text);
  if (email) s = s.split(email).join("[email removed]").replace(new RegExp(escapeRe(email), "gi"), "[email removed]");
  return s.replace(EMAIL_RE, "[email removed]");
}
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// No pings, no stray fences out of player text.
export function defang(text) {
  return String(text).replace(/@(?=[A-Za-z0-9_-])/g, "@\u200b").replace(/`{3,}/g, "``\u200b`");
}

function depthOk(v, d = 0) {
  if (d > 5) return false;
  if (Array.isArray(v)) return v.length <= 200 && v.every((x) => depthOk(x, d + 1));
  if (v && typeof v === "object") return Object.keys(v).length <= 100 && Object.values(v).every((x) => depthOk(x, d + 1));
  return true;
}

export function category(raw) {
  if (raw == null || raw === "") return { door: "triage", job: null };
  const [door, job, extra] = String(raw).split(".");
  if (extra !== undefined || !Object.hasOwn(DOORS, door)) throw new Bad(422, "bad_category", "category must be a door or door.job from routes.yaml");
  if (job && !DOORS[door].includes(job)) throw new Bad(422, "bad_category", "unknown job for that door");
  return { door, job: job || null };
}

export function spamReason(desc) {
  const urls = (desc.match(/https?:\/\/|www\./gi) || []).length;
  if (urls > 2) return "too_many_links";
  const compact = desc.replace(/\s+/g, "");
  if (compact.length >= 40 && new Set(compact.toLowerCase()).size < 6) return "repetitive";
  if (/(.{2,12})\1{9,}/s.test(compact)) return "repetitive";
  if (/\b(viagra|casino|crypto ?airdrop|onlyfans|seo services|loan offer)\b/i.test(desc)) return "spam_words";
  return null;
}

const SHOT_MAGIC = [
  ["image/png", [0x89, 0x50, 0x4e, 0x47]],
  ["image/jpeg", [0xff, 0xd8, 0xff]],
  ["image/webp", [0x52, 0x49, 0x46, 0x46]],
];

export function decodeShot(b64) {
  if (b64 == null || b64 === "") return null;
  if (typeof b64 !== "string" || b64.length > Math.ceil(LIMITS.shot / 3) * 4 + 4) throw new Bad(413, "shot_too_big", `screenshot over ${LIMITS.shot} bytes`);
  let bin;
  try { bin = atob(b64.replace(/^data:image\/\w+;base64,/, "")); } catch { throw new Bad(422, "bad_shot", "screenshot is not base64"); }
  const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  if (bytes.length > LIMITS.shot) throw new Bad(413, "shot_too_big", `screenshot over ${LIMITS.shot} bytes`);
  const hitType = SHOT_MAGIC.find(([, m]) => m.every((b, i) => bytes[i] === b));
  if (!hitType) throw new Bad(422, "bad_shot", "screenshot must be png, jpeg or webp");
  return { bytes, type: hitType[0] };
}

// Returns a normalized report or throws Bad.
export function validate(p) {
  if (!p || typeof p !== "object" || Array.isArray(p)) throw new Bad(400, "bad_json", "body must be a JSON object");
  if (!INSTALL_RE.test(p.install_id || "")) throw new Bad(422, "bad_install_id", "install_id: 8-64 chars [A-Za-z0-9_-]");
  const email = normEmail(p.email);
  const desc = typeof p.description === "string" ? p.description.trim() : "";
  if (desc.length < LIMITS.descMin) throw new Bad(422, "desc_short", `description needs ${LIMITS.descMin}+ chars`);
  if (desc.length > LIMITS.desc) throw new Bad(413, "desc_long", `description over ${LIMITS.desc} chars`);
  const crash = p.crash === true;
  if (p.log != null && p.log !== "" && !crash) throw new Bad(422, "log_without_crash", "log lines are only accepted with crash: true");
  const log = crash && typeof p.log === "string" ? p.log.slice(-LIMITS.log) : "";
  if (!p.state || typeof p.state !== "object" || Array.isArray(p.state)) throw new Bad(422, "bad_state", "state object required");
  const state = {}, dropped = [];
  for (const [k, v] of Object.entries(p.state)) (STATE_KEYS.includes(k) ? (state[k] = v) : dropped.push(k));
  if (!state.version) throw new Bad(422, "bad_state", "state.version required");
  if (!depthOk(state)) throw new Bad(422, "bad_state", "state too deep or too wide");
  if (JSON.stringify(state).length > LIMITS.state) throw new Bad(413, "state_too_big", `state over ${LIMITS.state} chars`);
  const build = BUILDS.includes(state.build) ? state.build : "other";
  const platform = PLATFORMS.includes(state.platform) ? state.platform : "other";
  const cat = category(p.category);
  const title = typeof p.title === "string" ? p.title.trim().slice(0, LIMITS.title) : "";
  return { installId: p.install_id, email, optIn: !!(email && p.opt_in === true), desc, title, crash, log,
    state, dropped, build, platform, ...cat, dryRun: p.dry_run === true, shot: decodeShot(p.screenshot) };
}

export function labels(r) {
  const out = ["bug-report", `door:${r.door}`, `build:${r.build}`, `platform:${r.platform}`];
  if (r.job) out.splice(2, 0, `job:${r.door}.${r.job}`);
  if (r.crash) out.push("crash");
  return out;
}

export function issueTitle(r) {
  const base = r.title || r.desc.split("\n")[0];
  const t = defang(scrub(base, r.email)).slice(0, 70);
  return `[Report] ${t}${base.length > 70 && !r.title ? "…" : ""}`;
}

export function issueBody(r, code, shotUrl) {
  const v = r.state.version;
  const fence = (lang, s) => "````" + lang + "\n" + String(s).replace(/`{4,}/g, "```") + "\n````";
  const parts = [
    defang(scrub(r.desc, r.email)),
    "",
    `**Reporter:** \`${code}\` · **Category:** \`${r.door}${r.job ? "." + r.job : ""}\` · **Build:** ${r.build} · **Platform:** ${r.platform} · **Version:** \`${defang(scrub(String(v), r.email)).slice(0, 40)}\``,
  ];
  if (shotUrl) parts.push("", "### Screenshot", `![screenshot](${shotUrl})`);
  parts.push("", "<details><summary>Game state report</summary>", "", fence("json", scrub(JSON.stringify(r.state, null, 1), r.email)), "", "</details>");
  if (r.crash && r.log) parts.push("", "<details><summary>Crash log</summary>", "", fence("", scrub(r.log, r.email)), "", "</details>");
  parts.push("", "<sub>Filed in-game via wdb-bug-relay. Reporter contact details are private and never posted.</sub>");
  return parts.join("\n");
}
