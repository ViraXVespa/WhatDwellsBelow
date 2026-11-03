# Local AI: two models, a playtester and a balance tuner (recommend-only, runs on Vira's PC)

id: local-ai-tuner
owner: bot
status: open
done-when: Phase 1 of both parts landed (each slice meets its measure) plus the one-command runner Vira launches herself.
resume: python tools/local-ai-tuner.py loop

## Intent
Tooling only, approved by Vira. There are TWO separate local models.
Dependency: the tuner is only as good as the playtester. It tunes against the playtester's runs, so part 1 comes first.
The playtester itself is split into a fast headless flow (skill emulation + balance data) and a separate CV flow (visual realism cross-check and cross-train). Both stay local; long runs happen only on Vira’s PC.

## 1. Playtester model
Makes the automated playtester play more like real players, and play better over time, by learning from playtest data and recordings.
Architecture (locked from brainstorm):
- Headless flow: drives the live game through the normal input path. Uses the existing decision-parameter surface (reaction delay, aim wobble, risk tolerance, skill priorities, etc.) plus a locally trained non-LLM policy. Focuses on emulating real player skill levels and generating telemetry for balance. Optimized for speed and reproducibility. Built on Godot RL Agents + Stable-Baselines3 (PyTorch) so observation/action bridging, sensors (including optional pixels), and training loops stay game-oriented.
- CV flow (separate system): consumes frames + matching journals/state. Checks for inhuman behaviors that telemetry alone misses (impossible reactions, unnatural pathing, UI blindness, etc.). Used to score/filter headless runs and to supply auxiliary training signal. Does not sit on the hot headless path.
- Shared memory for CV frames: fixed maximum region allocated up front (never resized). Header contains magic, version, width/height/stride, sequence counter, and data offset. Writer updates header then pixels; reader validates sequence and dimensions. Named file mapping on Windows with explicit security; both sides unmap cleanly. Avoids dynamic growth and BSOD-class failures.
- Language: Python primary for training, Optuna, CV scoring, orchestration, and the one-command runner. Optional later: export policy to ONNX/ncnn for lightweight in-engine inference (Godot Native RL or minimal GDExtension). Pure in-engine training is out of scope for Phase 1 (more glue than value).

Phase 1 slice: survey the existing playtester (the debug playtest job, `tools/perf.py`, journals, decision parameters). Stand up the Godot RL Agents bridge for one high-level decision (e.g. target or path choice). Train a first small policy on existing recorded runs (behavior cloning or simple RL). Add a minimal CV checker (OpenCV + optional small PyTorch scorer) that can flag obvious inhuman artifacts on a handful of dumped or mapped runs. Swap the learned decision in and compare.
Success: on held-out recordings, its choices match the real player’s more often than the scripted playtester’s do. Report both rates. CV checker produces a realism score + suspicious timestamps that can be read back as extra signal.

## 2. Balance tuner
Tunes the game-balance tunables (weapons, affixes, and so on). It may go beyond the slider ranges. It scores configs with playtester runs (headless flow only; CV-validated policies preferred once available).
It only recommends configs: a ranked report plus a tunables file to try. It never commits or applies balance changes.
Phase 1 slice: measure headless sim speed (sim seconds per wall second) on the box, then a minimal Optuna run (a few tunables, short headless runs) that outputs one recommended config.
Success: the recommended config beats the current config on the stated objective across repeat seeds, with the spread reported.

## Where it runs
Long runs happen on Vira's own dedicated PC. She launches them herself with one command (a runner script added in phase 1). Bot never runs anything on Vira's machines. Bot only builds, tests short slices on the box, and documents. A lean design doc covers the objective, the search space, the data captured, the runner, the headless/CV split, and the mmap layout for both parts.

## Operator requirements (Vira’s PC, once code lands)
- Godot 4.7.2 (editor or headless export).
- Python 3.11+ venv with: torch, stable-baselines3, godot-rl, optuna, opencv-python, numpy (plus any small IPC helper).
- Optional CUDA drivers for faster training.
- Standard Windows/Linux named shared-memory support (no extra install if mappings are fixed-size).
- Disk for telemetry JSONL, checkpoints, and optional frame dumps.
- One-command runner (e.g. `python tools/local-ai-tuner.py`) that starts headless playtests, optionally the CV checker, and writes the report + recommended tunables file.

## Hold
Vira said go on 2026-11-03. The set-and-forget command is `python tools/local-ai-tuner.py loop`. Each campaign process runs until the delve ends in death, then the loop trains. Export and import move the policy file between PCs. Status stays open until a live run on her PC reports the held-out rates and a recommended config that beats the current one across repeat seeds.
