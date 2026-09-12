# Artifacts, extraction, vendor

Status: binding design
Read when: artifacts/collections, extraction mailing, vendor restock
See also: `design/inventory.md`, `design/inventory-bag.md`, `design/inventory-gear.md`, `design/inventory-live.md`, `design/gear-ui.md`, `design/hub.md`, `design/skills.md`, `design/doc-refactor.md`, `design/README.md`

## Artifacts and collections

- Artifacts are obtained from the Ghost Shop, boss chests, and (optionally) dead-end or trap-room chests.
- Artifacts cannot be extracted via Extraction Gates; they function as run-only items and are lost on death or “Dispel”.
- Artifacts with similar effects are grouped into collections (sets). The demo contains exactly eight distinct sets.
- Typical set size is 2–3 artifacts; one or two sets may contain 4–5 artifacts.
- Collecting multiple artifacts from the same set grants additional set bonuses. Bonuses begin at 2 pieces and may require higher thresholds depending on set size.
- Set bonuses are progressive and are invented by Grok Build at implementation time.
- Artifact set bonuses should feel like a natural addition to the items that make up the set. For example, if a set is made up of two items that increase health regeneration, the set bonus could provide an additional boost to health regen or a matching bonus to mana regen.
- For 2–3 piece sets, the bonus should be roughly equal in power to the bonus from an individual piece of the set.
- For larger sets, the bonuses should feel more powerful as more items in the collection are gathered.
- Active set bonuses are displayed beneath the normal artifact descriptions in the relevant UI.
- Set pieces count toward bonuses while carried or equipped in the current run.

## Extraction / mailing

- Performed exclusively through Extraction Gates.
- The interface MUST present a clear list of items that can be sent back to the surface.
- Once extracted, items and gold are safe.
- Three Extraction Gates per floor. Any gate can mail any extractable goods. Each gate is one-use after a visit that mailed something.
- Duplicate green/blue extracts follow **Salvage spare gear**. Whites follow the starter path.

## Vendor restock

If the player returns to Placeholdia with insufficient resources, a limited free restock of basic food and potions is granted.

