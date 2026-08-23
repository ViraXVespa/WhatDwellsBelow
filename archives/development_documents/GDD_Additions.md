The following is a list of additions and changes to the What Dwells Below game design philosophy that are not currently in the game code or documentation that should be added to the design documentation. Unless otherwise noted, the tuning of variables should be left up to Grok’s best judgment, but should be configured in a way that makes them easy to balance in the future.

Consider this info to be decided and final for the purposes of the GDD creation. You may ask for clarification, but should not ask for confirmation in regards to this info.

1. Create a debug menu that allows the player to dynamically adjust variables related to game balance. The purpose of this menu is to allow the developer to fine tune the game balancing to easily find the values that make the game feel right.  
   1. This menu should contain any and every variable pertaining to game balancing.  
   2. The interface should be categorized by source filename, then class.  
   3. Variables should be adjustable in real time for easy live tuning.   
   4. It may be easiest to create specialized handlers that are called on instantiation and use reflection to populate this menu as well as reflecting summary code blocks to retrieve user friendly info pertaining to the variable (like what it does, for example).  
      1. There should be handling for invalid variable configurations on creation if necessary. For example, if a divide by zero would occur if set to zero, zero is blocked from being used.   
      2. This can be handled using classes with implicit operators to convert to source variable type.   
2. Adjust the dungeon gameplay loop to fit a 5 floor format. Have each floor 1-4 have a small floor guardian boss that must be defeated to continue to the next floor. Floor 5 should have a gate master, which is a substantially more formidable foe.  
3. After floor 5, the same floor loop continues with the difficulty ramped up.  
4. Add rare random events in which the fastest enemy in a group of enemies may flee from the player and attempt to find and bring more enemies to fight the player after the group (collectively) has taken enough damage to trigger the event.  
5. Add events in which enemies appear around the player if they idle for too long outside of a safe area or go too long without uncovering a new area of the map.   
6. Add an “Adrenaline Rush” system that boosts the player’s movement speed and attack speed after killing a certain number of enemies in a certain amount of time. The goal of this system is to gently motivate the player to quickly move through the dungeon.  
7. Replace the current mining/resource gathering system with a new one that works in the following way (mining used as example, but system will be similar for other resources):  
   1. No progress bar is visible to the player.   
   2. Rocks have random ‘health’ between 3 and 5 hits.   
   3. Mining animation plays when the player starts mining to indicate their current activity.   
   4. While mining, rock health is reduced by 1 every 2.4 seconds.  
   5. When rock health is reduced, the player responsible for reducing the health rolls for their reward.  
   6. Reward roll is determined by mining level, rock type (in full game), and pickaxe (if it has modifiers).  
   7. Player can be rewarded with nothing (trivial XP reward), ore of the same level as the rock (normal XP reward for ore of that level), or ore that is 1 level less than the rock (full game only).  
8. Food and potions should have distinct behaviors. Food heals over a time window (heals X HP over Y seconds) whereas potions are immediate heals (heals Z HP now).  
   1. While in the healing time window of food:  
      1. UI element should be shown to play somewhere so they know their food is in effect.  
      2. Eating the same food does nothing (no stack consumed) until the first effect expires.  
      3. Eating a different food cancels the first effect, consumes a stack of the new food, and immediately starts the effect of the new food.  
9. Put the word “Dispel” in quotes in the pause menu and anywhere it's referenced. (This is a humorous nod to the fact that it's really just self-deathing.)   
10. If not already present, a critical hit system should be implemented.  
11. The dungeon music is actually titled ‘Bitter’, not 8-bit. We should include links to it in the game, too:  
    1. YouTube: [https://youtu.be/b3Cq\_-ymFVU?si=YHZRCFmxf88BXmHW](https://youtu.be/b3Cq_-ymFVU?si=YHZRCFmxf88BXmHW)  
    2. Spotify: [https://open.spotify.com/track/5ronKOeupSInit9Y21z80f?si=WB-zeKUGQO6V31dPEITdRA\&utm\_source=copy-link\&context=spotify%3Atrack%3A5ronKOeupSInit9Y21z80f](https://open.spotify.com/track/5ronKOeupSInit9Y21z80f?si=WB-zeKUGQO6V31dPEITdRA&utm_source=copy-link&context=spotify%3Atrack%3A5ronKOeupSInit9Y21z80f)