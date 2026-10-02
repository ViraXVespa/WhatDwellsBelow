# Doc library: doc_patch, md_format_lib, code_map_lib

Status: binding  
Read when: editing docs, code-map rows or tool text by script; changing `doc_patch.py`, `md_format_lib.py` or `code_map_lib.py`  

Docs are edited by tools, not by hand-rolled scripts. Everything is idempotent: run twice, same bytes. Catalog and tool rules: `tools.md`.

## Principle

If a call does not work intuitively, it is designed wrong. Fix `doc_patch` (or the lib under it), add the missing subcommand, then use it. Do not work around it with a scratch, `sed`, `python -c` or a here-string. Add the fix to the same PR and say so in the rough-edges list (`tools.md`).

## doc_patch CLI

`python3 tools/doc_patch.py <cmd>` (`--dry-run` prints "would write" and changes nothing; `--eol keep|crlf|lf`, default keep):

| Cmd | Does |
|---|---|
| `replace FILE --old X --new Y` | Replace exactly one occurrence; fails on zero or many |
| `ensure-line FILE --line L [--after A]` | Add the line once |
| `set-read-when FILE "text"` | Rewrite the `Read when:` header line |
| `changelog --bullet B [--label L] [--summary S]` | Write `design/changelog/<label>.md` at the next free label |
| `next-label` | Print the next free changelog label |
| `write FILE [--b64 S] [--bom] [--append]` | Write UTF-8 from stdin or base64 (replaces `write_utf8_file.py`) |
| `apply plan.json` | Run a list of the above in one go |
| `check` | The docs checker (`run_checker`): load graph, markdown format, catalog |

## Library (import from a scratch only when the CLI cannot express it)

`replace_once`, `replace_once_any`, `replace_func`, `upsert_func` (new function), `replace_block`, `patch_file`, `ensure_line`, `set_read_when`, `drop_citations`, `drop_table_column`, `next_label`, `write_changelog`, `write_text`, `run_checker`, `dump_job` (runs a prove job, prints its summary body; never print `Summary ->` paths). `append_funcs` does not exist. `replace_func` fails when the name appears twice. A `.gd` body is tabs.

## md_format_lib

`read_text(path)` and `write_text(path, text, eol="keep", bom=None)` are the only way tools touch text: they keep each file's BOM and line endings (new files get CRLF), `detect_eol` reports them. Others: `leading_spaces_to_tabs` (`.gd`), `replace_once_text`, `splice_marker_block`, `rewrite_table_row`. Repo working tree is CRLF (`.gitattributes`); files outside the repo (skills under the agent dir) are LF: do not point `doc_patch` at them.

## code_map_lib

Row parser/writer for the code map: `parse_rows`, `find_system`, `add_path`, `remove_path`, `rename_path`, `file_is_mapped`. CLI is `code_map.py check|row|patch`, never edit a row by hand.

## Extend or fix

1. Reproduce with `--dry-run` on a copy of the text. 2. Fix in the lib function (shared by CLI and import), keep the signature. 3. Add a CLI subcommand if the need will repeat. 4. `check_tool_cli.py`, `check_tool_docs.py`, `check_load_graph.py`. 5. Update this file and the `doc_patch` row in `tools.md`.
