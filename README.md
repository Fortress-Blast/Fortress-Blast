![Fortress Blast](https://fortress-blast.github.io/images/logo.png)

Fortress Blast is a Team Fortress 2 server mod created by Naleksuh and Jack5 that adds powerups from the Marble Blast series into TF2. It can be run on top of other gamemodes and server mods. Fortress Blast is mostly dependent on user-defined spawning locations, but comes packaged with support for many official and custom maps.

Powerups
--------

The following powerups exist in the base version of this server mod:

- Super Bounce - The user is forced to uncontrollably bunny hop for 5 seconds. Air-strafing while this is active allows the user to build up speed.
- Shock Absorber - The user gets 75% damage resistance and full knockback immunity for 5 seconds.
- Super Speed - The user's speed is drastically increased, but gradually wears off.
- Super Jump - The user is launched into the air and will resist the initial fall damage. Using this powerup immediately after jumping results in a higher launch.
- Gyrocopter - The user has 25% gravity for 5 seconds.
- Time Travel - The user is invisible, has increased speed and cannot attack for 3 seconds. This allows for uncontested passage through or escape from challenging situations.
- Blast - An explosion is emitted from the user, killing low-health enemies and harming others nearby. Most effective when paired with other sources of damage.
- Mega Mann - The user becomes 75% larger and is overhealed to 4 times their current health for 10 seconds. Overheal is capped at 4 times the user's maximmum health.

Features
--------

Fortress Blast comes with a few quality-of-life features:

- A MOTD is available to players which provides them with information on what powerups there are, what they do, and tips on how they can be used.
- A server admin can allow players to drop Fortress Blast powerups on death with a ConVar.
- Bots can pick up powerups and randomly use them based on a user-defined range of time.
- By default, Mannpower powerups are replaced with Fortress Blast powerups.
- Debug mode can be turned on to test functions of the server mod without having to look at the console.

Installation
------------

1) Install [Rest in Pawn](https://github.com/ErikMinekus/sm-ripext/releases/tag/1.0.6) and extract the .zip file into your server.
2) Download the Fortress Blast .zip file from [the releases page](https://github.com/Fortress-Blast/Fortress-Blast/releases) and extract the contents of the *tf* folder into your server's *tf* folder.
3) You can download extra pre-made .json files from the [maps repository](https://github.com/Fortress-Blast/Fortress-Blast-Maps) or create your own.
4) It would greatly help this plugin thrive if you could add 'fortressblast' to the tags list of your server.

Commands (in chat, replace *sm_* with *!*)
--------

- `sm_fortressblast` - Opens the Fortress Blast MOTD manual.
- `sm_setpowerup <player> <#>` - Sets a player's powerup by ID number. Also works with the tags @all, @red, @blue and @me. Only users with the Z flag can use this command.

ConVars
-------

- `sm_fortressblast_action_use <string>` - Set the input to watch for using a powerup. `attack3` is default, but `reload` is recommended for PASS Time. Players are warned if they press `attack3` but it is not the set action.
- `sm_fortressblast_bot <0-1>` - Disable or enable bots using powerups within a random amount of time. On by default.
<!-- - `sm_fortressblast_bot_collect <0-1>` - Disable or enable bots collecting powerups, a setting useful for Mann vs. Machine. On by default. -->
- `sm_fortressblast_bot_min <#>` - Minimum time for bots to use a powerup. Default 2.
- `sm_fortressblast_bot_max <#>` - Maximum time for bots to use a powerup. Default 15.
- `sm_fortressblast_debug <0-1>` - Disable or enable debug mode, which displays messages in chat and lets all players set powerups. Off by default.
- `sm_fortressblast_drop <0-2>` - How to handle dropping powerups on death. 0 = Never drop, 1 = Only drop on maps with no .json file (default), 2 = Always drop.
- `sm_fortressblast_drop_rate <0-100>` - Set the chance a player will drop a powerup on death out of 100. Default 10.
- `sm_fortressblast_drop_team <1-3>` - Set the teams that will drop powerups on death. 1 = Both (default), 2 = RED only, 3 = BLU only.
- `sm_fortressblast_mannpower <0-2>` - Set whether Mannpower powerups are replaced with Fortress Blast powerups. 0 = Don't replace, 1 = Replace only if there is no .json file, 2 = Always replace (default).

Known bugs (v0.4.1)
-----------------

- It is possible to break the PASS Time jack with the Mega Mann powerup somehow. Involves throwing it.
- Model precaching is in the wrong place according to Rushy, should be moved to OnMapStart.
- Super Speed should be denied when holding PASS Time jack, as it does not work.
