#!/usr/bin/env python3
import sys, subprocess, json, os

def get_diff():
    status = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    diff_ref = "HEAD" if status.strip() else "origin/main"
    diff_output = subprocess.check_output(["git", "diff", "--name-status", f"{diff_ref}..HEAD"], text=True)
    lines = [ln.strip() for ln in diff_output.splitlines() if ln.strip()]
    return json.dumps([tuple(l.split("\t", 1)) for l in lines])

if __name__ == "__main__":
    print(get_diff())
