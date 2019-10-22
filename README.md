Fortress Blast
==============

Fortress Blast is a Team Fortress 2 server mod created by Naleksuh and Jack5 that adds powerups from the Marble Blast series into TF2. It can be run on top of any gamemodes or server mods. Fortress Blast is mostly dependent on user-defined spawning locations, but comes packaged with support for many official and custom maps.

Powerups
--------

The following powerups exist in the base version of this server mod:

- Super Bounce - The user is forced to uncontrollably bunny hop for 5 seconds. Air-strafing while this is active allows the user to build up speed. *(In development)*
- Shock Absorber - The user gets 75% damage resistance and full knockback immunity for 5 seconds.
- Super Speed - The user's speed is drastically increased, but gradually wears off over the course of 10 seconds.
- Super Jump - The user is launched into the air and will resist the initial fall damage. Using this powerup immediately after jumping results in a higher launch.
- Gyrocopter - The user has 25% gravity for 5 seconds.
- Time Travel - The user cannot attack, but their speed is doubled and they are immune to all damage for 5 seconds. This allows for uncontested passage through or escape from challenging situations. *(In development)*
- Blast - A large explosion is emitted from the user, hurting any enemies in its vicinity. *(In development)*
- Mega Mann - The user's size is increased by 75% and they have 4 times their regular health for 10 seconds. This powerup is known in the Marble Blast series as 'Mega Marble'. *(In development)*

Features
--------

Fortress Blast comes with a few quality-of-life features:

- A menu is available to in-game players with the command **!fortressblast**, which will provide them with information on what powerups there are, what they do, and tips on how they can be used. *(In development)*
- By default, Mannpower powerups are replaced with Fortress Blast powerups. This feature can be turned off with `fortressblast_mannpower`. *(In development)*
- Players can drop Fortress Blast powerups on death if `fortressblast_drop` is turned on. *(In development)*

Installation
------------

<installation guide required here>

Commands *(All in development)*
--------

- `fortressblast_bot 0|1` - Disable or enable bots using powerups within a random amount of time. Defaults to on.
- `fortressblast_bot_thinktime 0-#` - Set the amount of seconds after a bot collects a powerup before it considers using it. Defaults to 2.
- `fortressblast_bot_usetime 0-#` - Set the amount of seconds after a bot collects a powerup in which it must use it. Defaults to 15.
- `fortressblast_drop 0|1` - Disable or enable players dropping powerups on death. Defauts to off.
- `fortressblast_drop_rate 0-100` - Set the chance a player will drop a powerup on death out of 100. Defaults to 5.
- `fortressblast_drop_team 0|1|2|3` - Set the teams that will drop powerups on death. 0 = None, 1 = Both (default), 2 = RED, 3 = BLU.
- `fortressblast_mannpower 0|1` - Disable or enable automatic replacement of Mannpower powerups with Fortress Blast powerups. Defaults to on.
- `fortressblast_sound_pickup 0|1` - If set to off, picking up powerups will play the standard ammo pickup sound effect instead of the custom sound effects. Defaults to on.
` `fortressblast_sound_use 0|1` - If set to off, using powerups will play the standard spell casting sound effect instead of the custom sound effects. Defaults to on.
