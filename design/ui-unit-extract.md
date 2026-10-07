# Unit: Extraction gate

Status: queued unit  
Read when: send-all banking, banked lines  

- Shot: flow `dungeon-gate-shop`, state extract (`python tools/run_shot_flow.py --job ui.extract`). The flow calls `App.prog.stock_extract_shot` before the gate opens. A starter-only shot is not a test of this screen.
- Her ruling: one page, themed to the extract gate asset (stone, iron, lanterns, cyan mouth). The inventory gear board is the layout baseline, on that one page: worn slots and the bag, with resources and Send All added. Choosing a piece that can go asks to mail it. Artifacts, forged holds, and a white weapon or tool stay. The confirm stays a slip. Select and Leave stay in the footer.
- Surface sections and files: routes.yaml `unit_docs` and `unit_files` (the unit card prints them).
- Frame work follows the ui style doc.
