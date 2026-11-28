# Credit splash and title sequence

Status: current plan  
Read when: credit graffiti, boot handover, Shamelessly line  
Code: `scripts/ui/splash.gd`, `scripts/ui/fs_gate.gd`, `scripts/boot.gd`, `scripts/title.gd`

- Web export: `boot.tscn` → `fs_gate.tscn` (once per browser session when the gate still wants to show) → `splash.tscn` → title. Desktop and Xbox feature-tag builds skip the gate.
- Existing splash timing may be used as a baseline.
- The credit line MUST be modified so that the word “Proudly” is crossed out and the word “Shamelessly” is written above it in a graffiti style. The final readable phrase is “Shamelessly Vibecoded with Grok.” The graffiti treatment MUST look intentional and vandalized.

Live `splash.gd`: fade in 0.7 s, hold until t = 4.0 s, fade out 0.7 s. Skip with interact / pause / accept / click, then `App.go_title()`.

Live `fs_gate.gd`: title-card layout, platform copy, action + Continue. See ui.
