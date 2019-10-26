Fortress Blast
==============

Fortress Blast is a Team Fortress 2 server mod created by Naleksuh and Jack5 that adds powerups from the Marble Blast series into TF2. It can be run on top of other gamemodes and server mods. Fortress Blast is mostly dependent on user-defined spawning locations, but comes packaged with support for many official and custom maps.


Powerups
--------

The following powerups exist in the base version of this server mod:

- Super Bounce - The user is forced to uncontrollably bunny hop for 5 seconds. Air-strafing while this is active allows the user to build up speed.
- Shock Absorber - The user gets 75% damage resistance and full knockback immunity for 5 seconds.
- Super Speed - The user's speed is drastically increased, but gradually wears off.
- Super Jump - The user is launched into the air and will resist the initial fall damage. Using this powerup immediately after jumping results in a higher launch.
- Gyrocopter - The user has 25% gravity for 5 seconds.
- Time Travel - The user is invisible, has increased speed and cannot attack for 5 seconds. This allows for uncontested passage through or escape from challenging situations.

Features
--------

Fortress Blast comes with a few quality-of-life features:

- A menu is available to in-game players which provides them with information on what powerups there are, what they do, and tips on how they can be used.
- A server admin can allow players to drop Fortress Blast powerups on death with a command.
- Bots can pick up powerups and randomly use them based on a user-defined range of time.
- By default, Mannpower powerups are replaced with Fortress Blast powerups.

Installation
------------

1) Install [Rest in Pawn](https://github.com/ErikMinekus/sm-ripext/releases/tag/1.0.6) and extract the .zip file into your server.
2) Install [More Colors](https://forums.alliedmods.net/showthread.php?t=185016) and extract the .inc file into your tf\addons\sourcemod\scripting
2) Download the Fortress Blast .zip file from [our releases page](https://github.com/Fortress-Blast/Fortress-Blast/releases) and extract the contents of the *tf* folder into your server's *tf* folder.
3) You can download more pre-made .json files from the [maps repository](https://github.com/Fortress-Blast/Fortress-Blast-Maps) or create your own.
4) It would greatly help this plugin thrive if you could add 'fortressblast' to the tag list of your server.

Commands
--------

- `sm_fortressblast` - Opens the Fortress Blast help menu.
- `sm_setpowerup` - Sets your powerup by ID number. (Only users with the Z flag can use this command)
## ConVars
- `sm_fortressblast_bot <0-1>` - Disable or enable bots using powerups within a random amount of time. Default 1.
- `sm_fortressblast_bot_min <#>` - Minimum time for bots to use a powerup. Default 2.
- `sm_fortressblast_bot_max <#>` - Minimum time for bots to use a powerup. Default 15.
- `sm_fortressblast_drop_rate <0-100>` - Set the chance a player will drop a powerup on death out of 100. Default 0 (5 recommended).
- `sm_fortressblast_drop_team <0-2>` - Set the teams that will drop powerups on death. 0 = Both (default), 1 = RED, 2 = BLU.
- `sm_fortressblast_mannpower <0-2>` - Set whether Mannpower powerups are replaced with Fortress Blast powerups. 0 = Don't replace, 1 = Replace only if there is no .json file (default), 2 = Always replace.

Known bugs (v0.1)
-----------------

- Dying sometimes does not remove powerups.
- Menus display all items with numbers despite them not being links.
- Not all Mannpower powerups end up being replaced.
- Players dropping powerups defaults to on.
- Players can use the grappling hook while Time Travel is active.
- Powerups dropped by players do not disappear after a certain amount of time.
- Shock Absorber sound plays twice on some clients.
- Using Super Bounce while Super Bounce is active does not extend the time it is active, and a similar case for other powerups.
- You can use powerups while dead or in spectator.
- Chat message happens during waiting for players
