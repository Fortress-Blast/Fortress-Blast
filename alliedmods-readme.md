[CENTER][SIZE="7"][B]Fortress Blast[/B][/SIZE][/CENTER]
Fortress Blast is a Team Fortress 2 server mod created by Naleksuh and Jack5 that adds powerups from the Marble Blast series into TF2. It can be run on top of other gamemodes and server mods. Fortress Blast is mostly dependent on user-defined spawning locations, but comes packaged with support for many official and custom maps.
[SIZE="5"][B]Powerups[/B][/SIZE]
The following powerups exist in the base version of this server mod:
[LIST]
[*] Super Bounce - The user is forced to uncontrollably bunny hop for 5 seconds. Air-strafing while this is active allows the user to build up speed.
[*] Shock Absorber - The user gets 75% damage resistance and full knockback immunity for 5 seconds.
[*] Super Speed - The user's speed is drastically increased, but gradually wears off.
[*] Super Jump - The user is launched into the air and will resist the initial fall damage. Using this powerup immediately after jumping results in a higher launch.
[*] Gyrocopter - The user has 25% gravity for 5 seconds.
[*] Time Travel - The user is invisible, has increased speed and cannot attack for 5 seconds. This allows for uncontested passage through or escape from challenging situations.
[/LIST]
[SIZE="5"][B]Features[/B][/SIZE]
Fortress Blast comes with a few quality-of-life features:
[LIST]
[*] A menu is available to players which provides them with information on what powerups there are, what they do, and tips on how they can be used.
[*] A server admin can allow players to drop Fortress Blast powerups on death with a ConVar.
[*] Bots can pick up powerups and randomly use them based on a user-defined range of time.
[*] By default, Mannpower powerups are replaced with Fortress Blast powerups.
[/LIST]

[SIZE="5"][B]Installation[/B][/SIZE]
[LIST=1]
[*]Install [URL="https://github.com/ErikMinekus/sm-ripext/releases/tag/1.0.6"]Rest in Pawn[/URL] and extract the .zip file into your server.
[*]Download the Fortress Blast .zip file from [URL="https://github.com/Fortress-Blast/Fortress-Blast/releases"]our releases page[/URL] and extract the contents of the tf folder into your server's tf folder.
[*]You can download extra pre-made .json files from [URL="https://github.com/Fortress-Blast/Fortress-Blast-Maps"]the maps repository[/URL] or create your own.
[*]It would greatly help this plugin thrive if you could add 'fortressblast' to the tag list of your server.
[/LIST]
[SIZE="5"][B]Commands[/B] (in chat, replace [I]sm_[/I] with [I]![/I])[/SIZE]
[LIST]
[*] [U]sm_fortressblast[/U] - Opens the Fortress Blast help menu.
[*] [U]sm_setpowerup <player> <0-6>[/U] - Sets your powerup by ID number. (Only users with the Z flag can use this command)
[/LIST]
[SIZE="5"][B]ConVars[/B][/SIZE]
[LIST]
[*] [U]sm_fortressblast_bot <0-1>[/U] - Disable or enable bots using powerups within a random amount of time. Default 1.
[*] [U]sm_fortressblast_bot_min <#>[/U] - Minimum time for bots to use a powerup. Default 2.
[*] [U]sm_fortressblast_bot_max <#>[/U] - Maximum time for bots to use a powerup. Default 15.
[*] [U]sm_fortressblast_drop <0-2>[/U] - 0 = Never drop, 1 = Only drop on maps with no .json file, 2 = Always drop (default)
[*] [U]sm_fortressblast_drop_rate <0-100>[/U] - Set the chance a player will drop a powerup on death out of 100. Default 5.
[*] [U]sm_fortressblast_drop_team <1-3>[/U] - Set the teams that will drop powerups on death. 1 = Both (default), 2 = RED, 3 = BLU.
[*] [U]sm_fortressblast_mannpower <0-2>[/U] - Set whether Mannpower powerups are replaced with Fortress Blast powerups. 0 = Don't replace, 1 = Replace only if there is no .json file, 2 = Always replace (default).
[/LIST]
[SIZE="5"][B]Known Bugs[/B][/SIZE]
[LIST]
[*] Dying sometimes does not remove powerups.
[*] Menus display all items with numbers despite them not being links.
[*] Powerups dropped by players do not disappear after a certain amount of time.
[*] Shock Absorber sound plays twice on some clients.
[/LIST]
