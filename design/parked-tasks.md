# Parked tasks

Status: protocol
Read when: the User says resume parked, names a park id, or the first web message already names a parked job

Not a boot file. Not a topic index.


## Trigger (web Phase 1)

If the first User message names a row in the table below (id or trigger words), after the normal web review load only that Open file. Confirm: review done, this chat is that parked task. Do not wait for a separate go-to-Phase-2 message.

If that park file already has the mandate, Phase 2 is optional. When the User says go, implement, or Phase 7, proceed. Do not spend a turn asking which phase this is.

If no park is named, Phase 1 stays as it was: confirm ready for Phase 2 only.

This table is not Grok Bot intake. Web / chat does not open Bot Job files to continue a park.


## Table

id | trigger | open | path
--- | --- | --- | ---
attack_keyframes | resume parked, attack keyframes, coil stills | art-attack-keyframes.md (art_pipeline job) | web or isolated media
smoke_shots | resume parked, smoke shots, headless screenshots, _logs/shots | park-smoke-shots.md | web then Build / tools

Do not invent rows.
