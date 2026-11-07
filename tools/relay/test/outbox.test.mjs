import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fakeD1 } from "./fakes.mjs";
import { dispatchOutbox, retryAuthorizedOutbox } from "../src/outbox.js";
import worker from "../src/worker.js";

const subject="Approved subject", body="Approved immutable body with private unsubscribe fixture";
function fixture() {
  const env={DB:fakeD1(),EMAIL_SEND:"on",RESEND_API_KEY:"fixture-key",EMAIL_FROM:"changed@example.test"};
  env.DB._db.run("INSERT INTO reporters(reporter_code,email,opt_in,created) VALUES('R-fixture','private@example.test',1,0)");
  env.DB.prepare("INSERT INTO outbox(reporter_code,issue_number,kind,subject,body,created,sender) VALUES('R-fixture',78,'update',?1,?2,?3,'Sender <original@example.test>')").bind(subject,body,Math.floor(Date.now()/1000)).run();
  return env;
}
const row=env=>env.DB.rows("SELECT state,last_stage,last_error,last_http_status,provider_id,attempt_count FROM outbox")[0];
async function arm(env) { await env.DB.prepare("INSERT INTO outbox_retry(slot,outbox_id,armed) VALUES(1,1,1)").run(); }

test("singleton permit default-disabled; authorization consumed once; same row/key/payload; concurrent no duplicate",async()=>{
  const env=fixture(), calls=[];
  globalThis.fetch=async(url,init)=>{calls.push({url,init});await Promise.resolve();return new Response(JSON.stringify({id:"accepted-id"}));};
  await worker.scheduled({},env);
  assert.equal(calls.length,0);
  await arm(env);
  await Promise.all([retryAuthorizedOutbox(env),retryAuthorizedOutbox(env),dispatchOutbox(env,1)]);
  assert.equal(calls.length,1);
  assert.equal(calls[0].init.headers["Idempotency-Key"],"wdb-bug-relay/outbox/1");
  const payload=JSON.parse(calls[0].init.body);
  assert.equal(payload.subject,subject);assert.equal(payload.text,body);
  assert.equal(payload.from,"Sender <original@example.test>");assert.equal(payload.to,"private@example.test");
  assert.equal(env.DB.rows("SELECT COUNT(*) FROM outbox")[0][0],1);
  assert.deepEqual(row(env),["sent","accepted",null,200,"accepted-id",1]);
  assert.equal(env.DB.rows("SELECT armed FROM outbox_retry")[0][0],0);
  await worker.scheduled({},env);assert.equal(calls.length,1);
});

test("HTTP authentication/validation/quota/server failures persist only safe numeric status and fixed enum",async()=>{
  for(const status of [401,403,422,429,500]){
    const env=fixture();let calls=0;
    globalThis.fetch=async()=>{calls++;return new Response(JSON.stringify({message:"private@example.test fixture-key private unsubscribe fixture"}),{status});};
    await arm(env);await retryAuthorizedOutbox(env);
    assert.deepEqual(row(env),["queued","response","email_send_failed",status,null,1]);
    assert.ok(!JSON.stringify(row(env)).includes("private"));assert.ok(!JSON.stringify(row(env)).includes("fixture-key"));
    await retryAuthorizedOutbox(env);assert.equal(calls,1,"failed authorization cannot automatically retry");
  }
});

test("network, malformed acceptance and preflight failures recorded without exception text",async()=>{
  for(const mode of ["network","type-error","timeout","decode","missing-key"]){
    const env=fixture();
    globalThis.fetch=async()=>{if(mode==="network")throw new Error("private@example.test fixture-key");if(mode==="type-error")throw new TypeError("private@example.test fixture-key");if(mode==="timeout")throw new DOMException("private@example.test fixture-key","TimeoutError");return new Response("not-json");};
    if(mode==="missing-key")env.RESEND_API_KEY="";
    await arm(env);await retryAuthorizedOutbox(env);
    const r=row(env);assert.equal(r[0],"queued");assert.equal(r[1],(["network","type-error","timeout"].includes(mode))?"fetch":mode==="decode"?"decode":"preflight");
    assert.equal(r[3],mode==="decode"?200:null);if(mode==="timeout")assert.equal(r[2],"email_timeout");if(mode==="type-error")assert.equal(r[2],"email_fetch_type_error");assert.ok(!JSON.stringify(r).includes("private"));
  }
});

test("unsubscribe, sent, expired, missing row and interrupted claims never send and consume retry authorization",async()=>{
  for(const mode of ["unsubscribed","sent","expired","missing","sending"]){
    const env=fixture();let calls=0;globalThis.fetch=async()=>{calls++;throw new Error("unexpected");};
    if(mode==="unsubscribed")env.DB._db.run("UPDATE reporters SET unsub_at=1,opt_in=0");
    if(mode==="sent")env.DB._db.run("UPDATE outbox SET state='sent'");
    if(mode==="sending")env.DB._db.run("UPDATE outbox SET state='sending'");
    if(mode==="expired")env.DB._db.run("UPDATE outbox SET created=0");
    if(mode==="missing")env.DB._db.run("DELETE FROM outbox");
    await arm(env);await retryAuthorizedOutbox(env);
    assert.equal(calls,0);assert.equal(env.DB.rows("SELECT armed FROM outbox_retry")[0][0],0);
  }
});

test("additive migration preserves original queued body/subject/id with retry disabled",()=>{
  const env=fixture();env.DB._db.run("DROP TABLE outbox; DROP TABLE outbox_retry; CREATE TABLE outbox(id INTEGER PRIMARY KEY,reporter_code TEXT,issue_number INTEGER,kind TEXT,subject TEXT,body TEXT,created INTEGER,state TEXT DEFAULT 'queued',sent_at INTEGER)");
  env.DB.prepare("INSERT INTO outbox(id,subject,body) VALUES(1,?1,?2)").bind(subject,body).run();
  env.DB._db.exec(readFileSync(new URL("../migrations/0001-outbox-attempts.sql",import.meta.url),"utf8"));
  assert.deepEqual(env.DB.rows("SELECT id,subject,body,state,attempt_count FROM outbox"),[[1,subject,body,"queued",0]]);
  assert.equal(env.DB.rows("SELECT COUNT(*) FROM outbox_retry")[0][0],0);
});
