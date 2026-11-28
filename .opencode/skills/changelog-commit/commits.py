#!/usr/bin/env python3
import sys, subprocess, json

def get_commits():
    diff_ref = "HEAD" if subprocess.check_output(["git", "status", "--porcelain"], text=True).strip() else "origin/main"
    log_output = subprocess.check_output(["git", "log", f"{diff_ref}..HEAD", "--pretty=format:%s"], text=True)
    return json.dumps([m for m in log_output.splitlines() if m])

if __name__ == "__main__":
    print(get_commits())
