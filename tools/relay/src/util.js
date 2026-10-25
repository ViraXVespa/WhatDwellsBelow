// Small helpers: responses, hashing, HMAC, rate buckets.
const enc = new TextEncoder();

export const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400",
};

export function json(data, status = 200, extra = {}) {
  return new Response(JSON.stringify(data), {
    status, headers: { "Content-Type": "application/json", ...CORS, ...extra },
  });
}

export const err = (status, code, message, extra = {}) => json({ ok: false, error: code, message, ...extra }, status);

export const now = () => Math.floor(Date.now() / 1000);

export function hex(buf) {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function sha256(salt, value) {
  return hex(await crypto.subtle.digest("SHA-256", enc.encode(`${salt}\u0000${value}`)));
}

export async function hmacHex(secret, data) {
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", key, typeof data === "string" ? enc.encode(data) : data));
}

export function safeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

export function randomToken(bytes = 18) {
  const b = crypto.getRandomValues(new Uint8Array(bytes));
  return btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Fixed-window counter in D1. Returns the count after this hit.
export async function hit(db, kind, key, windowSec) {
  const t = now();
  const start = t - (t % windowSec);
  const row = await db.prepare(
    "INSERT INTO rate (bucket, count, expires) VALUES (?1, 1, ?2) " +
    "ON CONFLICT(bucket) DO UPDATE SET count = count + 1 RETURNING count"
  ).bind(`${kind}:${key}:${start}`, start + windowSec).first();
  return row ? row.count : 1;
}

export async function sweepRate(db) {
  await db.prepare("DELETE FROM rate WHERE expires < ?1").bind(now()).run();
}
