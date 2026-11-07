// Writes tools/relay/.secrets/deploy.js (git-ignored by tools/relay/.gitignore): the code for the Cloudflare MCP `execute` tool that uploads this Worker.
// Usage: node tools/relay/deploy-payload.mjs [--with-secrets]   then call execute with code "$file:<repo>/tools/relay/.secrets/deploy.js"
// --with-secrets reads GITHUB_TOKEN from env WDB_ISSUES_TOKEN and tools/relay/.secrets/{gh_webhook_secret,relay_salt}; otherwise
// existing secrets are always kept (keep_bindings), also with named upserts. Delete tools/relay/.secrets/deploy.js after the call; it may hold secrets.
import { readFileSync, writeFileSync, readdirSync, chmodSync, mkdirSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
// Keep this JSON-compatible: both Wrangler and the connector payload use the same bindings.
const config = JSON.parse(readFileSync(join(here, "wrangler.jsonc"), "utf8"));
export const CONFIG = {
  script: config.name,
  d1: { name: config.d1_databases[0].binding, id: config.d1_databases[0].database_id },
  kv: { name: config.kv_namespaces[0].binding, id: config.kv_namespaces[0].id },
  vars: config.vars, compatibility_date: config.compatibility_date,
};

// Importing this pure builder never reads credentials or writes a deployment payload.
export function buildMetadata(secretBindings = []) {
  return { main_module: "worker.js", compatibility_date: CONFIG.compatibility_date,
    bindings: [
      { type: "d1", name: CONFIG.d1.name, database_id: CONFIG.d1.id },
      { type: "kv_namespace", name: CONFIG.kv.name, namespace_id: CONFIG.kv.id },
      ...Object.entries(CONFIG.vars).map(([name, text]) => ({ type: "plain_text", name, text })),
      ...secretBindings,
    ], keep_bindings: ["secret_text"] };
}

function main() {
const modules = Object.fromEntries(readdirSync(join(here, "src")).filter((f) => f.endsWith(".js"))
  .map((f) => [f, readFileSync(join(here, "src", f), "utf8")]));
const bindings = [];

const withSecrets = process.argv.includes("--with-secrets");
if (withSecrets) {
  const sec = (f) => readFileSync(join(here, ".secrets", f), "utf8").trim();
  bindings.push({ type: "secret_text", name: "GH_WEBHOOK_SECRET", text: sec("gh_webhook_secret") });
  bindings.push({ type: "secret_text", name: "RELAY_SALT", text: sec("relay_salt") });
  if (process.env.WDB_ISSUES_TOKEN) bindings.push({ type: "secret_text", name: "GITHUB_TOKEN", text: process.env.WDB_ISSUES_TOKEN });
}
const metadata = buildMetadata(bindings);

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
const out = join(here, ".secrets", "deploy.js");
mkdirSync(dirname(out), { recursive: true }); writeFileSync(out, code); chmodSync(out, 0o600);
console.log("wrote", out, withSecrets ? "(with secrets)" : "(keeps existing secrets)");

}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
