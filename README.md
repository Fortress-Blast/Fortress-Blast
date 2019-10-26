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

<The following powerups are planned for addition after release:

- Blast - A large explosion is emitted from the user, hurting any enemies in its vicinity. *(In development)*
- Mega Mann - The user's size is increased by 75% and they have 4 times their regular health for 10 seconds. This powerup is known in the Marble Blast series as 'Mega Marble'. *(In development)*>

Features
--------

Fortress Blast comes with a few quality-of-life features:

- A menu is available to in-game players which provides them with information on what powerups there are, what they do, and tips on how they can be used.
- A server admin can allow players to drop Fortress Blast powerups on death with a command.
- Bots can pick up powerups and randomly use them based on a user-defined range of time.
- By default, Mannpower powerups are replaced with Fortress Blast powerups.

Commands
--------

- `!fortressblast` - Opens the Fortress Blast help menu.
- `sm_fortressblast_bot 0|1` - Disable or enable bots using powerups within a random amount of time. Default 1.
- `sm_fortressblast_bot_min #` - Minimum time for bots to use a powerup. Default 2.
- `sm_fortressblast_bot_max #` - Minimum time for bots to use a powerup. Default 15.
- `sm_fortressblast_drop 0|1` - Disable or enable players dropping powerups on death. Defaut 0.
- `sm_fortressblast_drop_rate 0-100` - Set the chance a player will drop a powerup on death out of 100. Default 5.
- `sm_fortressblast_drop_team 0|1|2` - Set the teams that will drop powerups on death. 0 = Both (default), 1 = RED, 2 = BLU.
- `sm_fortressblast_mannpower 0|1|2` - Set whether Mannpower powerups are replaced with Fortress Blast powerups. 0 = Don't replace, 1 = Replace only if there is no .json file, 2 = Always replace (default).
