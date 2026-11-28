#!/usr/bin/env python3
import os, sys

SKILL_DIR = os.path.dirname(__file__)
SUMMARY_FILE = os.path.join(SKILL_DIR, 'summary.txt')

if len(sys.argv) < 2:
    sys.exit('Usage: write_summary.py "summary text"')

summary = sys.argv[1].strip()
if not summary:
    print('Empty summary – not written.')
    sys.exit(0)

with open(SUMMARY_FILE, 'w', encoding='utf-8') as f:
    f.write(summary)
print(f'Summary written to {SUMMARY_FILE}')
