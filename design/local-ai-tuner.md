# Local AI tuner

Status: protocol
Read when: local_ai_playtester_or_balance_tuner

Two local models on the player PC. The playtester learns one high-level goal from decide rows. The balance tuner scores headless playtester runs and writes a recommendation. It does not write live defaults, the tunables table, or the save slot. Godot 4.7.2. Long runs stay on that PC. She launches them.

Behavior cloning is a small linear model in pure Python. Optuna, OpenCV, PyTorch, Stable-Baselines3, and Godot RL Agents are optional. `python tools/local-ai-tuner.py doctor` prints which of them import and prints `pip install -r tools/requirements-tuner.txt`. The command does not install them.

## Commands

`python tools/local-ai-tuner.py` and `python tools/local-ai-tuner.py run` train from recorded decide rows, score a held-out split, run the journal checker, and write a report. They do not launch Godot.

`python tools/local-ai-tuner.py doctor` checks the optional packages.

`python tools/local-ai-tuner.py run --live` does that offline pass, then measures headless sim seconds per wall second, then runs the short balance search. `--live` is what launches headless Godot.

`python tools/local-ai-tuner.py run --mode rl --live` starts the socket server, then headless Godot, and learns a linear policy on the bridge. `python tools/local-ai-tuner.py run --mode rl` does not launch Godot. It says the bridge starts with `--live`.

`python tools/local-ai-tuner.py --selftest` checks the offline pieces with a fake scorer. It does not need Godot or torch.

`python tools/local-ai-tuner.py train`, `python tools/local-ai-tuner.py eval`, and `python tools/local-ai-tuner.py cv` are the offline pieces on their own.

`python tools/local-ai-tuner.py speed --live --sec 8` measures one headless run.

`python tools/local-ai-tuner.py tune --live --trials 3 --seeds 1,2 --sec 8` is the short search.

`python tools/local-ai-tuner.py loop` is the command to leave running on a second PC. It starts headless Godot on the campaign slot, trains when that delve ends in death, and repeats until Ctrl+C. The campaign slot stays as it is.

The process keeps diving through extractions until the player dies in the dungeon. A full weapon clear, a stall, or an interrupt also ends that process, and the loop trains on the rows saved so far. `--rows` is an optional cap (default 0, no cap). A positive value still quits on the dive that crosses that decide-row count. The wait for one gather is `--wait` seconds (default 14400). Each gather uses the fast acting scale, capped at 6. The series saves the slot and quits on that death, after the dive's decide rows are in the spool. A gather that adds no decide rows is retried. Five of those in a row stop the loop. A Godot compile error stops the loop. Ctrl+C stops the loop and stops that Godot process. A dive still open when the wait ends is stopped, and that dive's journal stays out of the spool.

The new weights replace the policy file when their held-out rate is at least the current file's rate on the same split. The next gather loads that file. A missing file leaves the scripted ladder for that gather. Bot rows stay an imitation. The report does not invent a human match rate. `--dry-run` on this command still launches Godot and does not write the policy file.

`python tools/local-ai-tuner.py export --file PATH` writes a bundle from the tuner folder. `python tools/local-ai-tuner.py import --file PATH` writes that bundle into this PC's tuner folder. The next playtest that thinks reads it. A raw policy file with ver 1, six actions, a 6 by 7 weight matrix, and six biases imports the same way. The decision spool is a separate copy: the `playtest\db` folder beside the tuner folder.

`--dry-run` skips policy and report files. `--dir` selects the decision spool. `--out` selects the tuner folder. `--port` is the bridge port (default 11008). `--frames DIR` scores a folder of dumped frames when opencv imports. An empty `--frames` skips that pass. `--file` is the bundle path for export and import.

## Where files land

Decide rows are read from `user://playtest/db/decisions.jsonl` and from `user://playtest/runs/*.json`. On Windows that spool is `%APPDATA%\Godot\app_userdata\What Dwells Below\playtest\db`.

The tuner folder is `user://playtest/tuner/` (the same AppData tree, `playtest\tuner`). It holds `policy.json`, `report.txt`, `loop-log.txt`, `recommended.json`, and `recommended-tunables.txt`. `loop-log.txt` grows by one block per gather.

## Playtester

Reflexes stay scripted: motion, a low-health potion, a foe already in range, a gather that is already busy, unstick, and an existing lock. The learned choice is the next goal after that lock returns. The goals are threat, hunt, gather, clerk, door, and wander. A journal goal `fight` is the label `threat`. A chosen goal with no valid target falls through. A door falls through when the player is not extracted or the stairs are locked, so the campaign depth step can still run.

`policy.json` is `ver` 1, six actions, a 6 by 7 weight matrix, and six biases. The score of an action is its bias plus the dot product with seven features: threat distance, gather distance, clerk distance, hp fraction, extracted, floor divided by 10, and cargo divided by 20. A distance that is missing, negative, or at least 99 becomes 1. The file changes every playtest job that thinks. A missing or invalid file leaves the scripted ladder in place. `--wdb-pt-nopolicy` forces that ladder. `--wdb-pt-rl` reads the bridge goal and wins over the file.

The report's scripted baseline is the distance ladder: a foe closer than 90, else a gather node within 9, else a clerk within 12 when cargo is held, else a door after extraction, else wander. It is not a replay of every playtest branch. By the time the learned choice runs, a live foe has already been handled, so a model trained on fight rows is choosing among the later goals.

Human labels need `--wdb-pt-human-log` while she plays. The flag is off unless it is passed, so phase smokes do not write those rows. When at least 8 human rows exist, training uses only those rows. Otherwise the report trains on bot rows when they exist, labels the rates as imitation, and says the human-versus-scripted comparison is waiting on human rows. With fewer than 8 human rows and no bot rows, it trains on the human rows it has and says the count is under 8. With no labeled rows it writes a report and does not write a policy. The report prints the counts it measured. It does not fill in a match rate.

Playtest confirmation is required before the automated player counts as matching a person.

## Journal checker and frames

The journal checker flags a decide row that reaches a threat within 0.05 s after a threat distance of at least 20 (`fast_reaction`), and a cell move of more than 8 within 0.3 s (`cell_jump`). The score is 1 minus the flag count divided by 10, and it does not go below 0. `--frames` adds a near-black frame and a mean absolute jump above 80 from the previous frame. Without opencv the report says frame scoring needs opencv.

The frame region is a named mapping, tag `wdb-tuner-frames` (selftest tag `wdb-tuner-selftest`). It is 230464 bytes and is never resized. The header is magic `WDBF`, version 1, width, height, stride, sequence, and data offset 64. The pixel cap is 320 by 180 by 4. The writer fills pixels, then writes the sequence last. The sequence is the 5th u32, at byte offset 20. Both sides unmap. The game process does not write that region. The Python writer fills pixels, then writes the sequence.

## Balance tuner

The search may pass the slider ends: `enemy_hp_mult` from 0.05 to 6, `axe_damage` from 0.5 to 120, `staff_damage` from 0.5 to 100. The current snapshot is 1.0, 16, and 9. The objective is the mean, across the repeat seeds, of the floor reached, plus 1 when the end condition is extraction, minus 0.25 for a death or a dispel. Higher is better. The report includes that mean and the spread (max minus min).

Speed and tune launch the non-campaign live smoke and pass `--wdb-pt-nopolicy`, so an existing policy does not change the score. The score is the scripted playtester. Each trial is a process-local file passed as `--wdb-pt-trial=FILE`. That file is not saved into the slot. When optuna imports, the same tune command uses it. When it does not, the search is a 3-point grid and the report says so. A recommendation that does not beat the current config is INFO. The two recommend files are the artifact. Nothing in this command applies them.
