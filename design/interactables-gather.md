# Interactables — mining and wood nodes

Status: current plan
Read when: mining nodes, wood nodes, pickaxe rewards
Code: `scripts/world/gather/gather_node.gd`, `scripts/world/gather/rules.gd`

## Mining nodes

- Nodes have a small number of hits.
- Player approaches and interacts; gathering animation plays while stationary.
- At a steady interval the node takes one hit and a reward is rolled immediately.
- Reward chance and quality are influenced by Mining level, pickaxe quality, and node type.
- No progress bar is shown.
- Node is destroyed after its hit count is exhausted.

## Wood nodes

- Nodes have more hits than mining nodes.
- Player approaches and interacts; gathering animation plays while stationary.
- Hits come faster than mining, but each succeeds less often.
- Hit counts, intervals and reward chances: tunables-combat, Gathering.
- Reward chance and quality are influenced by Woodcutting level, hatchet quality, and node type.
- No progress bar is shown.
- Node is destroyed after its hit count is exhausted.
