# Save — web export and cache

Status: current plan  
Read when: COOP COEP off, id.txt querybust, serviceworker rename

## Web export requirements

- MUST run in modern browsers.
- MUST NOT require special COOP/COEP headers or other non-standard server configuration to function on GitHub Pages or equivalent static hosting.
- Web preset is a PWA: enabled, display Standalone, orientation Landscape, `ensure_cross_origin_isolation_headers` off, `variant/thread_support` off.
- `html/custom_html_shell` is `res://tools/data/web_shell.html`. That shell is the web boot overlay: game wordmark, phased status, byte-backed progress for `index.wasm` / `index.pck`, and a small Godot credit. It is not the in-engine Title → Play loader (`scripts/ui/loader.gd`).
- `html/head_include` stashes `beforeinstallprompt` on `window.__wdbInstallPrompt` so a later tap can call `prompt()`, and installs a capturing Escape listener so Esc does not leave browser fullscreen (input).
- After changing `export_presets.cfg`, rebuild with `python tools/release.py export-web`. Exports land in untracked `_out/web/`; never commit them.

Rebuild live locally with `python tools/release.py export-web` into `_out/web/`. Combined live + archive preview: `python tools/release.py export-web -Archives` into `_pages/`. Both MUST run `tools/release.py mips` before Godot `--import`, then `tools/release.py postexport` on the live export directory after Godot writes `_out/web/index.html`. Pages live export (`.github/workflows/pages.yml`) MUST run the same mip script immediately before `--import`. That pass sets `mipmaps/generate=true` on 3D world texture imports (`assets/sprites/`, `assets/tiles/`, `assets/props/`, `assets/fx/`) in the **export workspace** so the PCK ships baked chains instead of generating them on the player’s machine. `assets/ui/` is left generate-off. Tracked `.import` files on `main` stay `mipmaps/generate=false`. Do not commit the workspace flip. The script is idempotent (`true` / `1` is left alone). Local `release.py export-web` restores the sidecars it dirtied once the export ends (ones already modified before it are left alone); a flip that still shows MUST NOT be committed. GitHub Actions deploys Pages from the user push (workspace-stamped `version.json`), then best-effort cached catalog pins via `tools/release.py archives`, and publishes `/changelog/` from `design/changelog/*.md`. Do not commit archive wasm/pck to `main`. Do not store changelog notes in the repo; Pages builds them in CI.

## Web cache

PWA service workers and GitHub Pages will otherwise keep players on an old `.pck`. After every live Web export:

- Write loose `build_id.txt` (`{label}-{short sha}`) next to `_out/web/index.html`.
- Query-bust `index.js`, icons, manifest, and the service-worker URL in `_out/web/index.html`. Do not rewrite Godot `fileSizes` keys (`index.pck` / `index.wasm`).
- Rename the generated service-worker cache to include that build id.
- Stamp `window.__wdbBuildId` into the generated HTML. The custom shell fetches `build_id.txt` with `cache: 'no-store'` before `Engine.startGame`. On mismatch it shows “New build found — clearing the old cache…”, unregisters service workers, drops Cache Storage, and reloads once per new remote id (`sessionStorage`). Download progress after that reload uses Godot `onProgress` plus `fileSizes`.

Players MUST receive a new build without an incognito window or a manual cache clear.
