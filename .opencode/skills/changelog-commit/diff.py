#!/usr/bin/env python3
import sys, subprocess, json, os

def get_diff():
    status = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    diff_ref = "origin/main"
    diff_output = subprocess.check_output(["git", "diff", "--name-status", f"{diff_ref}..HEAD"], text=True)
    lines = [ln.strip() for ln in diff_output.splitlines() if ln.strip()]
    diff = [tuple(l.split("\t", 1)) for l in lines]
    # Write to file
    out_path = os.path.join(os.path.dirname(__file__), 'diff.json')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(diff, f)
    return json.dumps(diff)

if __name__ == "__main__":
    print(get_diff())
