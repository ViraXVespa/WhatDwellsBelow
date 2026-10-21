# Simulated Build run

Status: current procedure  
Read when: the Bot is asked to simulate a Grok Build task run on a week branch  

A dry walk of what a fresh Build session would do, to find defects before Vira launches one. Throwaway worktree off the week branch; delete it and its branch after.

1. Launch: `python tools/open_slice.py --dry-run --task ID`; the prompt's start command must match the task's `resume:` area and flags (`task.py check`).
2. Start: run that `start_build_slice.py` line, then `task.py show ID`; follow the card ORDER as far as runs without her (gate, flows, shots).
3. Mechanical: broken commands, dead paths, red checks, stale doc text. Fix these on the week branch, commit per cluster.
4. Intuitiveness: for each open task, walk every tool call its plan implies (kind, flags, defaults, output name and path) against that tool's `--help`, template and doc. Flag:
   - names that promise more or less than they do;
   - defaults that fight the task's intent;
   - surprising output names or paths;
   - a flag whose meaning differs between tools.
   A mechanical fix (wrong flag in a task, doc row) is made; a design change is listed, not made.
5. Console output: for every tool run above, read stdout and stderr. Flag any line that is not the result, a needed status, or an actionable error: debug prints, banners, progress spam, repeated or verbose lines, stderr or tracebacks on success, unexpected non-ASCII. `python tools/check_tool_cli.py --smoke-run` flags the mechanical cases (CONSOLE, NOISE, ASCII); fix clear noise, list the rest.
6. Report: fixes with hashes, then the intuitiveness flags as a short list for Vira, then judgment calls. Clean up the worktree.
