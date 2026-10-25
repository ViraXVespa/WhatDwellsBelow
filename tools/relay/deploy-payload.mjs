// Writes .secrets/deploy.js: the code for the Cloudflare MCP `execute` tool that uploads this Worker.
// Usage: node tools/relay/deploy-payload.mjs [--with-secrets]   then call execute with code "$file:<repo>/.secrets/deploy.js"
// --with-secrets reads GITHUB_TOKEN from env WDB_ISSUES_TOKEN and .secrets/{gh_webhook_secret,relay_salt}; otherwise
// existing secrets are kept (keep_bindings). Delete .secrets/deploy.js after the call; it may hold secrets.
import { readFileSync, writeFileSync, readdirSync, chmodSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");
export const CONFIG = {
  script: "wdb-bug-relay",
  d1: { name: "DB", id: "ac9512aa-20c5-45b0-932e-692609241ba6" },
  kv: { name: "SHOTS", id: "579f8fada4f24440bfd6095407b648fa" },
  vars: { REPO: "ViraXVespa/WhatDwellsBelow", EMAIL_SEND: "off" },
  compatibility_date: "2025-09-01",
};

const modules = Object.fromEntries(readdirSync(join(here, "src")).filter((f) => f.endsWith(".js"))
  .map((f) => [f, readFileSync(join(here, "src", f), "utf8")]));
const bindings = [
  { type: "d1", name: CONFIG.d1.name, id: CONFIG.d1.id },
  { type: "kv_namespace", name: CONFIG.kv.name, namespace_id: CONFIG.kv.id },
  ...Object.entries(CONFIG.vars).map(([name, text]) => ({ type: "plain_text", name, text })),
];
const withSecrets = process.argv.includes("--with-secrets");
if (withSecrets) {
  const sec = (f) => readFileSync(join(root, ".secrets", f), "utf8").trim();
  bindings.push({ type: "secret_text", name: "GH_WEBHOOK_SECRET", text: sec("gh_webhook_secret") });
  bindings.push({ type: "secret_text", name: "RELAY_SALT", text: sec("relay_salt") });
  if (process.env.WDB_ISSUES_TOKEN) bindings.push({ type: "secret_text", name: "GITHUB_TOKEN", text: process.env.WDB_ISSUES_TOKEN });
}
const metadata = { main_module: "worker.js", compatibility_date: CONFIG.compatibility_date, bindings,
  keep_bindings: withSecrets ? [] : ["secret_text"] };

const code = `async () => {
  const modules = ${JSON.stringify(modules)};
  const metadata = ${JSON.stringify(metadata)};
  const b = "F" + Date.now();
  const parts = ["--" + b, 'Content-Disposition: form-data; name="metadata"', "Content-Type: application/json", "", JSON.stringify(metadata)];
  for (const [name, src] of Object.entries(modules))
    parts.push("--" + b, 'Content-Disposition: form-data; name="' + name + '"; filename="' + name + '"', "Content-Type: application/javascript+module", "", src);
  parts.push("--" + b + "--");
  const path = "/accounts/" + accountId + "/workers/scripts/${CONFIG.script}";
  const up = await cloudflare.request({ method: "PUT", path, body: parts.join("\\r\\n"), contentType: "multipart/form-data; boundary=" + b, rawBody: true });
  const sub = await cloudflare.request({ method: "POST", path: path + "/subdomain", body: { enabled: true, previews_enabled: false } });
  return { uploaded: up.success, modified_on: up.result && up.result.modified_on, workers_dev: sub.result,
    bindings: metadata.bindings.map((x) => x.type + ":" + x.name) };
}`;
const out = join(root, ".secrets", "deploy.js");
writeFileSync(out, code); chmodSync(out, 0o600);
console.log("wrote", out, withSecrets ? "(with secrets)" : "(keeps existing secrets)");
