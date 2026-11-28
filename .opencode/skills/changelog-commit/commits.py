#!/usr/bin/env python3
import subprocess
import os
import json


def get_commits():
    # Determine base reference
    status = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    diff_ref = "origin/main" if status.strip() else "HEAD"
    # Get commits between diff_ref and HEAD
    # Use a record separator to split summary and body
    log_output = subprocess.check_output([
        "git", "log", f"{diff_ref}..HEAD", "--pretty=format:%s%x1e%b"
    ], text=True)
    # Split into entries
    entries = [e for e in log_output.split("\x1e") if e]
    commits = []
    for entry in entries:
        parts = entry.split("\n", 1)
        summary = parts[0].strip()
        description = parts[1].strip() if len(parts) > 1 else ""
        commits.append({"summary": summary, "description": description})
    # Write to file
    out_path = os.path.join(os.path.dirname(__file__), 'commits.json')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(commits, f, ensure_ascii=False, indent=2)
    return json.dumps(commits, ensure_ascii=False)

if __name__ == "__main__":
    print(get_commits())
