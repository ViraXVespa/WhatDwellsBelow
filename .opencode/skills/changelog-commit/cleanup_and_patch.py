#!/usr/bin/env python3
import os, sys, subprocess

SKILL_DIR = os.path.dirname(__file__)
SUMMARY_FILE = os.path.join(SKILL_DIR, 'summary.txt')
BULLETS_FILE = os.path.join(SKILL_DIR, 'bullets.txt')
DIFF_FILE = os.path.join(SKILL_DIR, 'diff.json')
COMMITS_FILE = os.path.join(SKILL_DIR, 'commits.json')

# Read summary
summary = None
if os.path.exists(SUMMARY_FILE):
    with open(SUMMARY_FILE, 'r', encoding='utf-8') as f:
        summary = f.read().strip()

# Read bullets
bullets = []
if os.path.exists(BULLETS_FILE):
    with open(BULLETS_FILE, 'r', encoding='utf-8') as f:
        bullets = [ln.strip() for ln in f.readlines() if ln.strip()]

print('Bullets loaded:', bullets)
if not bullets:
    print('No bullets found – aborting patch.')
    sys.exit(1)

# Build patch command: one --bullet per bullet
cmd = ['python', 'tools/docs.py', 'patch', 'changelog']
if summary:
    cmd.extend(['--summary', summary])
for b in bullets:
    cmd.extend(['--bullet', b])

subprocess.check_call(cmd)
print('Changelog patched.')

# Clean up temp files
for f in [SUMMARY_FILE, BULLETS_FILE, DIFF_FILE, COMMITS_FILE]:
    if os.path.exists(f):
        os.remove(f)
        print(f'Removed {f}')
