# Grok Bot — folder relocate

Status: protocol  
Read when: Grok Bot Job table → parked or named folder relocate  

For **Grok Bot** when the User names a folder move / relocate cluster. Do not fold this into a size sweep, extract, reuse-map brief, or doc facade PR.

## Mandate

Move an existing facade + helpers to a new location or rename them (placement and naming convention: refactor.md, Cluster folders; tool modes there). No behavior change.

Out of scope: inventing a new cluster to move, archives, art, features.

## Read set

1. `design/refactor.md` (Parked folder moves; recipe only)
2. The `design/code-map.md` **system rows** that name the cluster

Do not open the staged reuse brief. Do not read every caller first — run the mover, then open only paths the summary says changed.

## Pass

1. User names the source facade and destination folder. Stop and ask if either is missing.
2. Run `move_script_cluster.py` (modes, wrapper rule, what it rewrites: `refactor.md` Parked folder moves).
3. Update `design/code-map.md` rows in the same PR. Do the manual checks from `refactor.md` Cluster folders.
4. Prove: `BOT.md`.
