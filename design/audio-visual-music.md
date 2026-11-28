# Music and the SFX minimum set

Status: current plan  
Read when: Bitter loop point, attribution links, minimum cues  
Code: `scripts/audio/music.gd`, `scripts/audio/web_music.gd`, `scripts/audio/sfx.gd`

## Music

- The primary dungeon music track is the piece titled “Bitter”.
- Authoritative links MUST be referenced in the project for attribution and replacement:
  - YouTube: https://youtu.be/b3Cq_-ymFVU?si=YHZRCFmxf88BXmHW
  - Spotify: https://open.spotify.com/track/5ronKOeupSInit9Y21z80f?si=WB-zeKUGQO6V31dPEITdRA&utm_source=copy-link&context=spotify%3Atrack%3A5ronKOeupSInit9Y21z80f
- First playthrough starts at the beginning of the track, including the full intro.
- The loop point is the **1st beat of the 10th measure**. After that point is reached, subsequent loops MUST start there and MUST NOT replay anything before it.
- The equivalent timestamp of that beat MUST be measured from the supplied master and exposed in the secret debug menu as the loop offset. If the measured time and the score disagree, the score rule (1st beat of measure 10) wins until the User locks a timestamp.
- Volume and crossfade / fade behavior remain tunable.
- Hub music may be any warm, slightly hopeful, lightly comedic stand-in until final assets are created.
- Credit line “Bitter — ViraXVespa” MUST appear on the title screen and in the pause menu where appropriate.

Live default loop offset: `BITTER_LOOP_DEFAULT = 15.52`.

## SFX – minimum required set (Appendix E)

All volumes are controlled by the SFX slider. Additional short UI, weapon-specific, and ambient sounds may be added.

| SFX | Notes |
|-----|-------|
| Melee hit | |
| Player hurt | Separate male and female VO performances of equal scope |
| Special / Slam impact | |
| Dash | |
| Mining hit | |
| Woodcutting hit | |
| Breakable smash | |
| Item pickup | |
| UI click / confirm / cancel | |
| Level-up | |
| Adrenaline Rush start (warcry) | Separate male and female performances of equal scope |
| Adrenaline Rush loop (woosh / crackle) | |
| Critical hit | |
| Potion use | Instant heal; distinct from food |
| Food use | Heal-over-time start; distinct from potion |
| Deathrattle “hurk” | Separate male and female performances of equal scope |
| Comedic thud (“Dispel”) | |
| Consciousness-transfer (enter dungeon) | Short presentation beat |
| Wake-up (return to Placeholdia) | Short presentation beat |

## Cue wiring and missing SFX

Where cues come from, how Build wires one, and the silent-today event table: the audio_sfx gate (opened when wiring or generating a cue).
