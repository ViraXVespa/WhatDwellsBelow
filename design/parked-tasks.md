# Parked tasks

Status: protocol
Read when: the User says resume parked, names a park id, or the first web message already names a parked job

Not a boot file. Not a topic index. See also is forbidden.


## Trigger (web Phase 1)

If the first User message names a row in the table below (id or trigger words), after the normal web review load only that Open file. Confirm: review done, this chat is that parked task. Do not wait for a separate go-to-Phase-2 message.

If that park file already has the mandate, Phase 2 is optional. When the User says go, implement, or Phase 7, proceed. Do not spend a turn asking which phase this is.

If no park is named, Phase 1 stays as it was: confirm ready for Phase 2 only.


## Pools (Bot intake, not web parks)

Reuse-map: one Brief of same-shape live extracts. Bot implements the whole Brief on the current open Bot PR.

Opt queue: standing ids for tools, boot, timing, preload. Not UI chrome cousins unless the item says so.

Size / relocate / docs stay Job-table rows. They are not a third queue file.


## Table

id | trigger | open | path
--- | --- | --- | ---
attack_keyframes | resume parked, attack keyframes, coil stills | art-attack-keyframes.md (art_pipeline job) | web or isolated media
reuse_brief | reuse-map, UI chrome brief | reuse-map.md when Brief is not empty | Grok Bot reuse job
opt_queue | named opt-NNN | grok-bot-opt.md via bot_opt --id | Grok Bot opt job
bot_setup | Refactorer profile, cloud clone, pool definitions | park-bot-setup.md | web then Bot profile

Do not invent rows.
