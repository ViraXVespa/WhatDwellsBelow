##### Intro
Describing the mobile interface should make most of the other questions pretty clear.

I'm picturing a home page that routes to several different  tooling entry points. Essentially a "What do you want to work on?" picker. The format and the layout should become logical as the rest of the system is built out.

The different character types idea may wind up being a class/subclass kind of thing for all of the different art subject types to route what tooling is involved in the workflows.

Here are the different art subjects I can think of (should not be considered all inclusive) and how I would expect the workflow interface to work for some of them.

##### General Concerns
While working with the pipeline, changing one area of an art subject may invalidate the work of other areas; invalidating their results until the art is regenerated. We'll need to make sure that the dependent chains get flagged for regeneration before exporting into the game (unless the User confirms a bypass).

Throughout this document, I will use the word 'player' to refer to someone playing the final game, the word 'character' to refer to in-game entities, and the word 'user' to refer to the person using these pipeline tools.

Since a lot of the usage scenarios aren't already set up in the game, we'll want to make sure that this system is designed in a manner that makes it easy to expand functionality and troubleshoot all of the different working parts. Due to the scope of tooling required, it may be necessary to make the system something that evolves and grows as more usage scenarios are encountered.

Since different systems interact with one another, the interface should be designed in a modular manner that makes it easy to navigate to different submodules while keeping info from the session/interface to open those submodules in tightly scoped manners when necessary.

We also need to make sure that things that are affected in one location update correctly in every other location. 

For example, if the user were looking at the items dropped by an enemy, they may randomly decide that they want to adjust the art of an item that enemy drops. Then the user should be able to to do something like right-click/hold-tap the item, select "edit item" and then be taken to the edit menu for that specific item without going through accessing the Item edit flow.

When implementing the Export system, the game code will have to be reconfigured to use the Exported resources from this tooling workflow as the single source of truth for art and configuration.

##### IMPORTANT CONSTRAINT
There should be an always-accessible Preview flow that provides live feedback to the user to view anything they've changed. They should be able to see before and after shots on demand, review anything waiting on approval, and run more demanding preview cases (for example: packing the resources and changes into a new worktree, then running the game and capturing video of the in-game results of the changed items) on demand. 

##### Subject Types
Character
NPC
Enemy
Sub-boss
Boss
Equipment
Item
Projectile
Decoration
Resource
UI
Biome
Building
VFX 

##### Flows
#### Character
### User Experience
Note: Flow for creating a new Character is used in the outline as it covers everything relevant in a clean, organized manner. 

1. User chooses the option to create a new Character type.
2. User selects between using a different Character as a template or creating a brand new Character.
    1. If using a different character as the template, the new character starts by copying the root Character and the player is taken to the section selection area after configuring the name.
    2. If a new Character is selected, it follows the rest of this flow instead of going to the section selector at step 4.
3. User is taken to the Base -> Details screen to (at minimum) enter a name for the new Character.
4. User is taken to the Body Shape subsection and continues through the flow until the mannequin has been confirmed and turned into an accepted 3D model.
5. User is walked through the Customization flow. 
    1. The user should allowed to skip as much as possible by making things optional by design.
    2. Everything required to generate animations wearing and using equipment should be configured during this flow.
    3. There should be default values for equipment using our current locked bibles as the reference. This should allow the user to generate everything they need to generate animations in equipment similar to our current characters while needing little to no input.
    4. Should be streamlined to get everything needed to generate animations set up with as little work as possible. 
6. User is walked through the Animation flow.
    1. Goes through setting up various animations.
    2. Requires 8-dir walk creation as minimum baseline.
    3. Optional creation of additional animations.
7. User is taken to the Export flow.

### Considerations/Random Thoughts
The creation flow should have default configurations to streamline the process. The user should be able to adjust any prompts. There should also be a way to hold two separate prompts: one that's details specific to that character and one that's a generic operational prompt for that step that's used whenever that step happens (maybe a skill). There should also be an option to override the operational prompt with a custom prompt for that step, but that step should also get flagged if the generic operational prompt changes (flagged as a warning, not as requiring regen). 

### Flow Detail Expansion
## Selection
User should be able to select between the available options (currently Male or Female) or create a new option.

After that selection, the UI should progress to a selector to choose which area of the selected Character they want to edit.

## Base
This section defines the base shape of the body for the equipment mannequin and 3D model. This area covers everything related to the base appearance of the selected Character.

# Details
Covers the naming and descriptive notes related to the Character. When creating a new Character, this is opened immediately and a name must be entered before progressing to any other area. 

# Body Shape
Covers the step in which the initial front and side views of the mannequin are generated, and the step in which the back/other side views are made.

# Model
Covers the step where the 3D model is made and edited.

# Portrait
Covers creating and framing the close up images of the Character (used in HUD). 

## Customization
This section covers setting up the traits that are applicable to the selected Character type. This includes customization and equipment slot handling.

# Character Traits
Covers all of the things that can be customized by the player in the character creation flow (not currently implemented in-game).

This includes eyes, hair, mouths, noses, body sliders, etc.

This should be setup in a manner that allows customization categories to be shared (and enabled/disabled for editing) for different Character types. For example, Male and Female may share hair options, but an entirely different set of head adornments would be required for a robot Character type.

We will probably need a schema for these customization options and we'll want to be able relative placement coordinates so things can be cleanly repositioned on different body shapes.

There should also be an option to add/remove/edit or regenerate the art for items in the individual option groups. That should allow the user to easily do something like create a new nose option or tweak a mouth shape.

There should be several different options for these customization options in the final game. Here are some examples:
- Bulk Slider: Adjusts character's overall body width proportions.
- Skin Tone Picker: Allows the player to pick from various colors for skin tone (or to choose a custom color).
- Hairstyle Selector: Allows the player to choose a hairstyle for their character.

There will need to be handling and schemas to accommodate all of these options.

This is the first example of something that will want the modular interface, as there should be separate views for viewing the customization groups somewhere, but this section would use a subview of that to only display the relevant items.

# Defaults
Covers setting the defaults for the Character appearance. Allows for a set default or for a set of preset configurations. This is essentially a streamlined version of the larger customization section that is focused on what the player first sees when selecting a Character type in the character customization menu.

# Equipment
Covers setting the positioning information for the equipment that gets placed on the mannequin and how the customization affects that placement (if it does affect that).

## Animation
This section covers everything related to animation.

# Direction
Covers adjusting prompting sent throughout the various steps. Should have a section for character wide details that are sent when describing the character to any model, a section for optional character specific prompts that are added at specific steps, and sections for adding negative prompt details when needed. This is mostly reserved to things that affect all of the animations for this character, rather than for things that affect a single animation.

# Picker
This is the entry point to a subflow that works in conjunction with the Specialization, Keyframes, and Generation sections. This section is where the user gets an overview of animation 'actions' and 'scenarios'. An 'action' is an animation grouping for shared behaviors (for example: walk, attack, dash, death), and a 'scenario' is a set of conditions that adjust the behavior of an action (for example: for the death action, if the user dies from an enemy, play the 'killed' animation, but if they used the dispel command, play the 'dispel' animation). These nomenclatures and data organization aren't set in stone; this is just a starting point so you understand the language I'm using. There may be better organizational structures and names for this, but I'm not really an animator, so I don't know that info.

This setup isn't described elsewhere, so I'll describe what I envision here. Unlike enemies, Characters have customization, which affects the animations and makes assembling them and keeping them organized a complex endeavor. Since an enemy has set equipment and appearance, they only need a few animations to accomplish every game situation. For a Character, however, animations vary depending on the equipment and customization options. A Character walking while carrying a two handed axe should look different from a Character walking while carrying a sword and shield. To accomplish the requisite diversity, we need a way to route the animations effectively. The idea I came up with was a system where variables can be configured and declared to allow the user to set up conditional usage scenarios. Essentially, it's a simple if/else framework to do things like "if (axe_equipped) use (these_sprites) else use (base_sprites)" in an intuitive way. The more I think about this the more I become confident there's an existing framework for this that I don't know about. I'll leave things at this level of detail and we can discuss this part later. Some more of this concept should become clear from the Enemy flow breakdown, anyway.

Anyway, this picker should allow the user to pick the animations they want to work on and function as a browser for the selected work area. When the selected area is changed, the content in the Specialization, Keyframes, and Generation sections should be scoped to the selected area.

The User should be able to add new animation areas or scenarios directly from this area. 

There should also be an easy way to scope to things that definitely need to be regenerated, to things that have other associated prompts that have been changed and may or may not affect the generated output, or to things that have been changed since the last export.

# Specialization
Covers any prompting that is added for the selected work area. 

# Keyframes
Covers creating the reference frames used for the animation creation. Should allow the user to generate reference videos and images for rigging up the 3D model animations, then allow the user to select frames to use as reference points during that step.

# Generation
Covers doing everything required to generate the 3D animations and write them to a sprite sheet.

## Export
Covers reviewing everything that's changed and exporting the changes to the game.

# Select
Lists every export area that's been edited since the last export. Allows the user to pick the areas to export so a full export isn't required each time.

# Review
Lists the specific things that changed in the selected area(s). This section functions as a gate to the Run section. If any assets have been flagged as missing, requiring regeneration, or have a 'potentially dirty' flag, they should be displayed with quick controls to resolve those flags. For the 'potentially dirty' flag, that info should be stored and displayed (+cleared) the next time a user attempts to regenerate the flagged asset. That way the user is informed that the source lrompts have changed since last generation.

# Run
Covers the execution and reporting of actual updates to the game.

#### Biome
### User Experience
Note: Flow for creating a new Biome is used in the outline as it covers everything relevant in a clean, organized manner. 

1. User chooses the option to create a new Biome type.
2. User selects between using a different Biome as a template or creating a brand new Biome.
    1. If using a different Biome as the template, the new Biome starts by copying the root Biome and the player is taken to the section selection area after configuring the name.
    2. If a new Biome is selected, it follows the rest of this flow instead of going to the section selector at step 4.
3. User is taken to the Design -> Details screen to (at minimum) enter a name for the new .
4. User is taken to the Design subsection and continues through the flow until the various art details are locked in.
5. User is walked through the Features flow. 
6. User is walked through the Art flow. 
7. User is walked through the Layout flow.
8. User is taken to the Export flow.

### Considerations/Random Thoughts
This should be able to handle configuring and editing various dungeon biome settings. This setting isn't currently very well covered in the actual game due to their only being one (Dungeon) biome at this time. There are lots of future things that have no representation in the current game that will have to be added for this workflow. For example, instead of having solid walls and black empty space, we may want empty boundaries and a paralax image of a city in the black space for a Sky City Biome and things like that.

### Flow Detail Expansion
## Selection
User should be able to select between the available options or create a new option.

After that selection, the UI should progress to a selector to choose which area of the selected Biome they want to edit.

## Design
This section defines the base properties of the biome.

# Details
Covers the naming and descriptive notes related to the Biome. When creating a new Biome, this is opened immediately and a name must be entered before progressing to any other area.

# Overview
Covers the descriptive prompting and generation of mockup images that fit the desired feel of the Biome. This is where the tone and makeup is defined and refined so the art creation has solid mockups to work with.

## Features
This will have some kind of flow to set up things like traps and puzzles that can spawn in the Biome. This should also handle things like setting up which floors appear with the Biome and which flavor props (such as the torches in the dungeon) spawn in the Biome. Also, which enemies can be spawned in the Biome. 

## Art
This section will cover generating all of the necessary assets for generating an immersive Biome experience.

## Layout
This section should cover adjusting all of the settings related to the procedural generation so different Biomes can have different feels.

## Export
Pretty much the same as the other flows. 

#### Enemy
### User Experience
Note: Flow for creating a new Enemy is used in the outline as it covers everything relevant in a clean, organized manner. 

1. User chooses the option to create a new Enemy type.
2. User selects between using a different Enemy as a template or creating a brand new Enemy.
    1. If using a different Enemy as the template, the new Enemy starts by copying the root Enemy and the player is taken to the section selection area after configuring the name.
    2. If a new Enemy is selected, it follows the rest of this flow instead of going to the section selector at step 4.
3. User is taken to the Design -> Details screen to (at minimum) enter a name for the new Enemy.
4. User is taken to the Design subsection and continues through the flow until the front and side views have been confirmed and turned into an accepted 3D model.
5. User is walked through the Configuration flow. 
6. User is walked through the Animation flow.
    1. Goes through setting up various animations.
    2. Requires 8-dir walk creation as minimum baseline.
    3. Optional creation of additional animations.
7. User is walked through the Items flow.
8. User is walked through the Variants flow. 
9. User is taken to the Export flow.

### Considerations/Random Thoughts
This should be similar to the Character Flow, but with some flows simplified and new flows added. 

### Flow Detail Expansion
## Selection
User should be able to select between the available options or create a new option.

After that selection, the UI should progress to a selector to choose which area of the selected Enemy they want to edit.

## Design
This section defines the art design of the Enemy and 3D model. This area covers everything related to the base appearance of the selected Enemy.

# Details
Covers the naming and descriptive notes related to the Enemy. When creating a new Enemy, this is opened immediately and a name must be entered before progressing to any other area. 

# Description
Covers the step in which the initial front and side views of the Enemy are generated, and the step in which the back/other side views are made.

# Model
Covers the step where the 3D model is made and edited.

# Portrait
Covers creating and framing the close up images of the Enemy (used in the Enemy Log [not currently implemented in-game]). 

## Configuration
This section covers setting up the data related to the selected Enemy type.

# Behavior
Covers setting various behavior related things such as movement (walk, fly, float, etc.), temperament (aggressive, passive, fearful, etc.), combat (ranged, magic, melee, etc.), and anything else that may affect in-game behavior or art generation.

# Stats
Covers setting the base stats and scaling for the enemy.

## Animation
This section covers everything related to animation.

# Direction
Covers adjusting prompting sent throughout the various steps.

# Picker
Covers picking the animation to work on. Should be much simpler than the Character setup and have a limited set of options. Idle (Inactive), Idle (Attacking), Walk, Flee, Death, and Attack. Those animations should be able to have variants for different scenarios, and attacks should be configurable to use different animations for different attacks. 

# Specialization
Covers any prompting that is added for the selected work area.

# Keyframes
Covers creating the reference frames used for the animation creation. Should allow the user to generate reference videos and images for rigging up the 3D model animations, then allow the user to select frames to use as reference points during that step.

# Generation
Covers doing everything required to generate the 3D animations and write them to a sprite sheet.

## Items
Covers setting up item drops. I don't know what subsections go here, yet.

## Variants
Covers setting up variations of the Enemy.

# Alternates
Covers setting up variations of the base enemy that appear in different locations. This allows the user to configure pallette swapped variants that use different attacks and behaviors.

# Diversity
Allows the user to set up appearance variations that appear on the Enemy when it is spawned. This includes things like scoped, subtle pallette adjustments and size variation. This, like many other things I didn't mention, should be adjustable for different Alternates and Nameds if desired.

# Named
Covers setting up custom named variants of the Enemy for quests. They should be allowed to have custom art and attacks if desired. 

## Export
Covers reviewing everything that's changed and exporting the changes to the game.

# Select
Lists every export area that's been edited since the last export. Allows the user to pick the areas to export so a full export isn't required each time.

# Review
Lists the specific things that changed in the selected area(s). This section functions as a gate to the Run section. If any assets have been flagged as missing, requiring regeneration, or have a 'potentially dirty' flag, they should be displayed with quick controls to resolve those flags. For the 'potentially dirty' flag, that info should be stored and displayed (+cleared) the next time a user attempts to regenerate the flagged asset. That way the user is informed that the source lrompts have changed since last generation.

# Run
Covers the execution and reporting of actual updates to the game.  