#!/usr/bin/env python3
import os, sys

# Path to the bullets file (directory containing this script)
SKILL_DIR = os.path.dirname(__file__)
BULLETS_FILE = os.path.join(SKILL_DIR, 'bullets.txt')

if len(sys.argv) < 2:
    sys.exit('Usage: add_bullet.py "bullet text"')

bullet = sys.argv[1].strip()
if not bullet:
    print('Empty bullet – not added.')
    sys.exit(0)

# Ensure directory exists
os.makedirs(SKILL_DIR, exist_ok=True)

# Avoid duplicates
existing = set()
if os.path.exists(BULLETS_FILE):
    with open(BULLETS_FILE, 'r', encoding='utf-8') as f:
        existing = {ln.strip() for ln in f.readlines() if ln.strip()}

if bullet in existing:
    print('Duplicate bullet – not added.')
else:
    with open(BULLETS_FILE, 'a', encoding='utf-8') as f:
        f.write(bullet + '\n')
    print(f'Bullet added to {BULLETS_FILE}')
