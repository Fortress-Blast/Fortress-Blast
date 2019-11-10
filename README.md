![Fortress Blast](https://fortress-blast.github.io/images/logo.png)

**[Visit the wiki](https://github.com/Fortress-Blast/Fortress-Blast/wiki) for how to install Fortress Blast, as well as more in-depth information about the plugin.**

Fortress Blast is a Team Fortress 2 server mod created by Naleksuh and Jack5 that adds powerups from the Marble Blast series into TF2. It can be run on top of other gamemodes and server mods. Fortress Blast is mostly dependent on user-defined spawning locations, but comes packaged with support for many official and custom maps.

Powerups
--------

The lifeblood of Fortress Blast is its powerups, and *here are just a few examples:*

- **Blast** - An explosion is emitted from the user, killing low-health enemies and harming others nearby.
- **Frost Touch** - For 8 seconds, when the user touches an enemy, they turn into an ice statue for 3 seconds.
- **Mega Mann** - The user becomes 75% larger and is overhealed to 4 times their current health for 10 seconds.
- **Super Bounce** - The user is forced to uncontrollably bunny hop for 5 seconds.
- **Time Travel** - The user is invisible, has increased speed and cannot attack for 3 seconds.

Features
--------

Fortress Blast comes with several quality-of-life features, *such as:*

- A MOTD is available to players, with information on what powerups there are, what they do, and how they can be used.
- A server admin can allow players to drop Fortress Blast powerups on death with a ConVar.
- Bots can pick up powerups and randomly use them based on a user-defined range of time.
- By default, Mannpower powerups are replaced with Fortress Blast powerups.
- Debug mode can be turned on to test functions of the server mod without having to look at the console.

Contributors
------------

- [Naleksuh](https://www.youtube.com/channel/UC9g4LTIBTdBB0P0QNcOHnGQ) - Mod programming
- [Jack5](https://www.youtube.com/user/jack5vlogging) - Concept, design and graphics
- [ChargingTurnip](https://tf2maps.net/members/true-lemon.31187) - Custom powerup model

ConVars
-------

- `sm_fortressblast_action_use <string>` - Set the input to watch for using a powerup. `attack3` is default, but `reload` is recommended for PASS Time. Players are warned if they press `attack3` but it is not the set action.
- `sm_fortressblast_bot <0-1>` - Disable or enable bots using powerups within a random amount of time. On by default.
- `sm_fortressblast_bot_min <#>` - Minimum time for bots to use a powerup. Default 2.
- `sm_fortressblast_bot_max <#>` - Maximum time for bots to use a powerup. Default 15.
- `sm_fortressblast_debug <0-1>` - Disable or enable debug mode, which displays messages in chat and lets all players set powerups. Off by default.
- `sm_fortressblast_drop <0-2>` - How to handle dropping powerups on death. 0 = Never drop, 1 = Only drop on maps with no .json file (default), 2 = Always drop.
- `sm_fortressblast_drop_rate <0-100>` - Set the chance a player will drop a powerup on death out of 100. Default 10.
- `sm_fortressblast_drop_team <1-3>` - Set the teams that will drop powerups on death. 1 = Both (default), 2 = RED only, 3 = BLU only.
- `sm_fortressblast_mannpower <0-2>` - Set whether Mannpower powerups are replaced with Fortress Blast powerups. 0 = Don't replace, 1 = Replace only if there is no .json file, 2 = Always replace (default).
