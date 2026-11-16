Slice opened by `slice.py open`: start already ran for this session ({start}). A separate gather session has already refined the context packet; its card is in session-context.md. Do not run `slice.py start` again except a mid-session subcommand (--unit-done, --failed, --handoff). Do not re-gather what the packet already holds.

Your first read: the task file{task_line}.
Your second read: session-context.md (the packet: core bodies plus candidates with their conditions). Do not re-read what it holds. Open a candidate only when its condition holds (`wdb__lookup action=packet query=ID`). Change the index only with `{py} tools/slice.py adjust`, and write the four sections above the marker in session-plan.md as facts land so later post-compact turns receive the updated source context.
{warn}
