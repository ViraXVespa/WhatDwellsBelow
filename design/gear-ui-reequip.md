# Re-equip and Anvil submenus

Status: binding design  
Read when: re-equip lists, submenu chrome  


## Re-equip and Anvil submenus

**A** / confirm on a live slot opens a modal for that slot.

Shared chrome (inventory, loadout, and Anvil):

- The parent board’s control strip MUST NOT change while the submenu is open.
- The submenu MUST draw its own tooltip strip with the controls for that window.
- There is no **Back** button. B / Esc / the submenu strip’s cancel verb closes only the submenu. The parent menu stays open.
- Opening another slot replaces the open submenu.
- While a Forge job is running or the results screen is up, Back MUST NOT tear the panel down and leave a ghost over Floor Crystal / Pause. Work phase: stop the queue. Results: keep the old holds. Edit phase: close the submenu.

Inventory / loadout list:

- Chevron (`▸`) on the parent slot if a new non-starter option appeared since that list was last opened.
- Options are icon plates in a horizontal row, not text rows.
- Dungeon list: currently equipped item (if any) plus bag items for that slot. Tool bag rows MUST match the run’s tool type.
- Placeholdia / Loadout list: equipped, starters, unlocked starters, holds, then non-white bank items. No white duplicates. Bank / unforged kit pieces are marked **AT RISK** in the flyout and with a red border. Holds are marked **HOLD**.
- Left / Right stay on the option row. The host MUST NOT swallow Left / Right while that list is open.
- Selecting the equipped row unequips it when the slot allows. Weapon, tool, and starter pieces stay on the slot.

Anvil Analyze / Forge item law (who can appear, destroy-on-pick, locks, cost, holds cap, results pick-three): inventory.gear.

Anvil Analyze chrome:

- Picking a piece **is** the confirm. Do not close, reopen, and require a second select.
- Warning copy uses warning colorization: `WARNING: Analyzing an item permanently destroys the item in exchange for the ability to Forge new equipment with its equipment traits.`
- Strip verbs: analyze / close.

Anvil Forge chrome:

- The selected rarity is highlighted like a Pause tab, not disabled. After a batch the rarity MUST stay where the player left it (Blue stays Blue).
- Work phase: a progress bar for the current piece. Results phase: inventory icon cells and the same flyout / Y stats as the bag.
- Strip verbs: set / forge on the configurator; stop queue while forging; toggle / stats / keep old holds on results.
