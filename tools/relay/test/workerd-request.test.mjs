// Real Workerd request construction with fake credentials and zero outbound fetches.
import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync,copyFileSync,writeFileSync,rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Miniflare,convertV4MiniflareOptions } from "miniflare";

test("production adapter constructs supported non-following request in Workerd, not just Node mocks",async()=>{
  const dir=mkdtempSync(join(tmpdir(),"relay-workerd-"));let mf;
  try{
    for(const name of ["email.js","report.js","doors.js","util.js"])
      copyFileSync(new URL("../src/"+name,import.meta.url),join(dir,name));
    writeFileSync(join(dir,"entry.js"),`import {sendEmail} from './email.js';
      export default {async fetch(){let constructed=0;
        const result=await sendEmail({EMAIL_SEND:'on',EMAIL_FROM:'sender@example.test',RESEND_API_KEY:'fixture'},
          'player@example.test','Subject','Body','wdb-bug-relay/outbox/1',async(url,init)=>{
            const request=new Request(url,init);constructed++;
            if(request.redirect!=='manual')throw new Error('redirect must not forward credentials');
            return Response.json({id:'fixture-accepted'});
          });return Response.json({result,constructed});}};`);
    mf=new Miniflare(convertV4MiniflareOptions({modules:["entry.js","email.js","report.js","doors.js","util.js"].map(name=>({type:"ESModule",path:join(dir,name)})),modulesRoot:dir,compatibilityDate:"2025-09-01"}));
    const result=await(await mf.dispatchFetch("https://local.test/")).json();
    assert.equal(result.constructed,1);assert.equal(result.result.sent,true);assert.equal(result.result.providerId,"fixture-accepted");
  }finally{if(mf)await mf.dispose();rmSync(dir,{recursive:true,force:true});}
});
