---
name: task-ops
description: Create or update complete, detailed Grok Build tasks under design/tasks/. Preserve every section and every line of relevant information from the user’s input. Never omit, summarize, or write “(omitted for brevity)”. Use docs.py task new/update, then task index. Do not invent door/job pairs. Callable from OpenCode or via direct Ollama API.
---

# task-ops

Create or update a complete task file under design/tasks/ that another session can execute without needing the original conversation.

## Rules
- Use `python tools/docs.py task new ID --owner ... --title ... --done-when "..." --resume "..."` (or `task update`).
- The `--resume` value becomes the `## Next Steps (User Only)` section automatically. Prefer a real slice-open line when the task is for Grok Build.
- Assign door and job only from routes.yaml or explicit content in the user’s input. If no exact pair exists, use the closest and tell the user.
- **Copy, do not summarize.** The body of the task must contain every section and every line the user supplied (Approach, Context, Skills lists, Constraints, Deliverables, First Actions, examples, notes, etc.) exactly as provided, preserving all markdown, code fences, and line breaks. 
- **Forbidden:** Do not write “(omitted for brevity)”, “see above”, “details omitted”, ellipsis-only bullets, or any other form of truncation. If the input is long, still include it in full.
- After creating or updating, run `python tools/docs.py task index` so the README index is current.
- Do not commit.
- Work on the trusted worktree when called after slice open.

## What a good task looks like
- Include any header fields present in the source (e.g., `area`, `door`, `job`) exactly as they appear, preserving their values.
- Body that is a faithful, complete copy of the user’s structured content
- A real `## Next Steps (User Only)` section containing the launch line

## Output
- Path of the task file
- Result of `docs.py task check` or `task show`
- Door/job assigned
- Confirmation that the body contains the full detailed sections from the input (no omissions)