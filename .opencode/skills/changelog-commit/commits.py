#!/usr/bin/env python3
import subprocess
import os
import json

def get_commits():
    diff_ref = "origin/main" if subprocess.check_output(["git", "status", "--porcelain"], text=True).strip() else "HEAD"
    log_output = subprocess.check_output(["git", "log", f"{diff_ref}..HEAD", "--pretty=format:%s"], text=True)
    commits = [m for m in log_output.splitlines() if m]
    # Write to file
    out_path = os.path.join(os.path.dirname(__file__), 'commits.json')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(commits, f)
    return json.dumps(commits)

if __name__ == "__main__":
    print(get_commits())
