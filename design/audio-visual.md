# Audio, visual, splash (door)

Status: current plan  
Read when: music, SFX, splash stills, presentation rules  
Code: `scripts/audio/` (music, web_music, sfx), `scripts/ui/splash.gd`, `scripts/ui/fs_gate.gd`, `scripts/world/sprite_filter.gd`, `tools/release.py mips` (code map row Audio visual; gdhealth group `audio_visual`)  

| Job | Open |
|-----|------|
| Bitter loop point, attribution links, minimum cues | `design/audio-visual-music.md` |
| nearest filter modes, mipmap bake, upright actors, lighting contrast, world art | `design/audio-visual-art.md` |
| credit graffiti, boot handover, Shamelessly line | `design/audio-visual-splash.md` |

Wiring or generating one SFX cue is its own gate (audio_sfx), not a job: it is opened by that action, from any job. Other code reaches audio through `App.sfx` and `App.music`, never a `scripts/audio/` file.

## Placeholder policy

The only assets considered final are:

- The designer’s profile picture
- Official Grok / xAI logos and related assets

Every other sprite, animation, tileset, prop, UI graphic, music track (except the identified “Bitter” reference), and sound effect is placeholder and MUST be replaced or massively updated before the demo is considered shippable.
