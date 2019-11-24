#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ripext/json>
#include <morecolors>
#include <tf2>
#include <tf2_stocks>
#include <advanced_motd>

#define	MAX_EDICT_BITS 11
#define	MAX_EDICTS (1<<MAX_EDICT_BITS)
#define MAX_PARTICLES 10 // If a player needs more than this number, a random one is deleted, but too many might cause memory problems

int NumberOfPowerups = 11; // Do not define this
int PlayersAmount;
int giftgoal;
int Gifts[4] = 0;
int powerupid[MAX_EDICTS] = -1;
int powerup[MAXPLAYERS + 1] = 0;
int PlayerParticle[MAXPLAYERS + 1][MAX_PARTICLES + 1];
int SpeedRotationsLeft[MAXPLAYERS + 1] = 80;
bool PreviousAttack3[MAXPLAYERS + 1] = false;
bool VictoryTime = false;
bool MapHasJsonFile = false;
bool GiftHunt = false;
bool SuperBounce[MAXPLAYERS + 1] = false;
bool ShockAbsorber[MAXPLAYERS + 1] = false;
bool TimeTravel[MAXPLAYERS + 1] = false;
bool MegaMann[MAXPLAYERS + 1] = false;
bool MegaMannStuckComplete[MAXPLAYERS + 1] = true;
bool FrostTouch[MAXPLAYERS + 1] = false;
bool FrostTouchFrozen[MAXPLAYERS + 1] = true;
float OldSpeed[MAXPLAYERS + 1] = 0.0;
float SuperSpeed[MAXPLAYERS + 1] = 0.0;
float VerticalVelocity[MAXPLAYERS + 1];
float MegaMannCoords[MAXPLAYERS + 1][3];
Handle SuperBounceHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle ShockAbsorberHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle GyrocopterHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle TimeTravelHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle MegaMannPreHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle MegaMannHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle FrostTouchHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle FrostTouchUnfreezeHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle DestroyPowerupHandle[MAX_EDICTS + 1] = INVALID_HANDLE;
Handle TeleportationHandle[MAXPLAYERS + 1] = INVALID_HANDLE;

Handle texthand;
Handle gemtext;

ConVar sm_fortressblast_action_use;
ConVar sm_fortressblast_bot;
ConVar sm_fortressblast_bot_min;
ConVar sm_fortressblast_bot_max;
ConVar sm_fortressblast_debug;
ConVar sm_fortressblast_drop;
ConVar sm_fortressblast_drop_rate;
ConVar sm_fortressblast_drop_teams;
ConVar sm_fortressblast_gifthunt_goal;
ConVar sm_fortressblast_gifthunt_increment;
ConVar sm_fortressblast_gifthunt_players;
ConVar sm_fortressblast_gifthunt_rate;
ConVar sm_fortressblast_mannpower;
ConVar sm_fortressblast_powerups;
ConVar sm_fortressblast_spawnroom_kill;

/* Powerup IDs
0 - No powerup if on player, gift if on powerup entity
1 - Super Bounce
2 - Shock Absorber
3 - Super Speed
4 - Super Jump
5 - Gyrocopter
6 - Time Travel
7 - Blast
8 - Mega Mann
9 - Frost Touch
10 - Mystery
11 - Teleportation */

public OnPluginStart() {
	for (int client = 1; client <= MaxClients ; client++) {
		if (IsClientInGame(client)) {
			SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage); // In case the plugin is reloaded mid-round
			SDKHook(client, SDKHook_StartTouch, OnStartTouchFrozen);
		}
	}
	HookEvent("teamplay_round_start", teamplay_round_start);
	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("player_death", player_death);
	RegConsoleCmd("sm_fortressblast", FBMenu);
	RegConsoleCmd("sm_setpowerup", SetPowerup);
	RegAdminCmd("sm_spawnpowerup", SpawnPowerup, ADMFLAG_ROOT);
	LoadTranslations("common.phrases");
	sm_fortressblast_action_use = CreateConVar("sm_fortressblast_action_use", "attack3", "Which action to watch for in order to use powerups.");
	sm_fortressblast_bot = CreateConVar("sm_fortressblast_bot", "1", "Disables or enables bots using powerups.");
	sm_fortressblast_bot_min = CreateConVar("sm_fortressblast_bot_min", "2", "Minimum time for bots to use a powerup.");
	sm_fortressblast_bot_max = CreateConVar("sm_fortressblast_bot_max", "15", "Maximum time for bots to use a powerup.");
	sm_fortressblast_debug = CreateConVar("sm_fortressblast_debug", "0", "Disables or enables command permission overrides and debug messages in chat.");
	sm_fortressblast_drop = CreateConVar("sm_fortressblast_drop", "1", "How to handle dropping powerups on death.");
	sm_fortressblast_drop_rate = CreateConVar("sm_fortressblast_drop_rate", "10", "Chance out of 100 for a powerup to drop on death.");
	sm_fortressblast_drop_teams = CreateConVar("sm_fortressblast_drop_teams", "1", "Teams that will drop powerups on death.");
	sm_fortressblast_gifthunt_goal = CreateConVar("sm_fortressblast_gifthunt_goal", "125", "Base number of gifts required to unlock the objective in Gift Hunt.");
	sm_fortressblast_gifthunt_increment = CreateConVar("sm_fortressblast_gifthunt_increment", "25", "Amount to increase the gift goal per extra group of players.");
	sm_fortressblast_gifthunt_players = CreateConVar("sm_fortressblast_gifthunt_players", "4", "Number of players in a group, any more and the gift goal increases.");
	sm_fortressblast_gifthunt_rate = CreateConVar("sm_fortressblast_gifthunt_rate", "20", "Chance out of 100 for each gift to spawn once all gifts are collected.");
	sm_fortressblast_mannpower = CreateConVar("sm_fortressblast_mannpower", "2", "How to handle replacing Mannpower powerups.");
	sm_fortressblast_powerups = CreateConVar("sm_fortressblast_powerups", "-1", "Bitfield of which powerups to enable, a number within 1 and 1023.");
	sm_fortressblast_spawnroom_kill = CreateConVar("sm_fortressblast_spawnroom_kill", "1", "Disables or enables killing enemies inside spawnrooms due to Mega Mann exploit.");
	texthand = CreateHudSynchronizer();
	gemtext = CreateHudSynchronizer();
}

public OnMapStart() {
	GiftHunt = false;
	Gifts[2] = 0;
	Gifts[3] = 0;
	PrecacheSound("fortressblast2/superbounce_pickup.mp3");
	PrecacheSound("fortressblast2/superbounce_use.mp3");
	PrecacheSound("fortressblast2/shockabsorber_pickup.mp3");
	PrecacheSound("fortressblast2/shockabsorber_use.mp3");
	PrecacheSound("fortressblast2/superspeed_pickup.mp3");
	PrecacheSound("fortressblast2/superspeed_use.mp3");
	PrecacheSound("fortressblast2/superjump_pickup.mp3");
	PrecacheSound("fortressblast2/superjump_use.mp3");
	PrecacheSound("fortressblast2/gyrocopter_pickup.mp3");
	PrecacheSound("fortressblast2/gyrocopter_use.mp3");
	PrecacheSound("fortressblast2/timetravel_pickup.mp3");
	PrecacheSound("fortressblast2/timetravel_use_3sec.mp3");
	PrecacheSound("fortressblast2/blast_pickup.mp3");
	PrecacheSound("fortressblast2/blast_use.mp3");
	PrecacheSound("fortressblast2/megamann_pickup.mp3");
	PrecacheSound("fortressblast2/megamann_use.mp3");
	PrecacheSound("fortressblast2/frosttouch_pickup.mp3");
	PrecacheSound("fortressblast2/frosttouch_use.mp3");
	PrecacheSound("fortressblast2/frosttouch_freeze.mp3");
	PrecacheSound("fortressblast2/frosttouch_unfreeze.mp3");
	PrecacheSound("fortressblast2/mystery_pickup.mp3");
	PrecacheSound("fortressblast2/teleportation_pickup.mp3");
	PrecacheSound("fortressblast2/teleportation_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/superbounce_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/superbounce_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/shockabsorber_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/shockabsorber_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/superspeed_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/superspeed_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/superjump_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/superjump_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/gyrocopter_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/gyrocopter_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/timetravel_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/timetravel_use_3sec.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/blast_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/blast_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/megamann_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/megamann_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/frosttouch_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/frosttouch_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/frosttouch_freeze.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/frosttouch_unfreeze.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/mystery_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/teleportation_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/teleportation_use.mp3");
	
	PrecacheSound("fortressblast2/gifthunt_gift_pickup.mp3");
	PrecacheSound("fortressblast2/gifthunt_goal_enemyteam.mp3");
	PrecacheSound("fortressblast2/gifthunt_goal_playerteam.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/gifthunt_gift_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/gifthunt_goal_enemyteam.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/gifthunt_goal_playerteam.mp3");
	AddFileToDownloadsTable("materials/sprites/fortressblast/gift_located_here.vmt");
	AddFileToDownloadsTable("materials/sprites/fortressblast/gift_located_here.vtf");
	
	AddFileToDownloadsTable("materials/models/fortressblast/pickups/fb_pickup/pickup_fb.vmt");
	AddFileToDownloadsTable("materials/models/fortressblast/pickups/fb_pickup/pickup_fb.vtf");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.mdl");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.dx80.vtx");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.dx90.vtx");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.phy");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.sw.vtx");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.vvd");
	
	char map[80];
	GetCurrentMap(map, sizeof(map));
	char path[PLATFORM_MAX_PATH + 1];
	Format(path, sizeof(path), "scripts/fortress_blast/powerup_spots/%s.json", map);
	MapHasJsonFile = FileExists(path); // So we dont overload read-writes
}

public TF2_OnConditionAdded(int client, TFCond condition) {
	if (condition == TFCond_HalloweenKart) {
		powerup[client] = 0;
	}
}

public Action FBMenu(int client, int args) {
	int bitfield = GetConVarInt(sm_fortressblast_powerups);
	if (bitfield < 1 && bitfield > ((Bitfieldify(NumberOfPowerups) * 2) - 1)) {
		bitfield = -1;
	}
	char url[200];
	char action[15];
	GetConVarString(sm_fortressblast_action_use, action, sizeof(action));
	Format(url, sizeof(url), "http://fortress-blast.github.io/2.1?powerups-enabled=%d&action=%s", bitfield, action);
	AdvMOTD_ShowMOTDPanel(client, "How are you reading this?", url, MOTDPANEL_TYPE_URL, true, true, true, INVALID_FUNCTION);
	CPrintToChat(client, "{orange}[Fortress Blast] {haunted}Opening Fortress Blast manual... If nothing happens, open your developer console and {yellow}try setting cl_disablehtmlmotd to 0{haunted}, then try again.");
}

public Action SetPowerup(int client, int args) {
	if (!CheckCommandAccess(client, "", ADMFLAG_ROOT) && GetConVarFloat(sm_fortressblast_debug) < 1) {
		CPrintToChat(client, "{orange}[Fortress Blast] {red}You do not have permission to use this command.");
		return;
	}
	char arg[MAX_NAME_LENGTH + 1];
	char arg2[3]; // Need to have a check if there's only one argument, apply to command user
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	// The approach of this is deliberate, to be as if they typed like normal
	if (StrEqual(arg, "@all")) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2)) {
				FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client2), StringToInt(arg2));
			}
		}
		return;
	} else if (StrEqual(arg, "@red")) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2) && GetClientTeam(client2) == 2) {
				FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client2), StringToInt(arg2));
			}
		}
		return;
	} else if (StrEqual(arg, "@blue")) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2) && GetClientTeam(client2) == 3) {
				FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client2), StringToInt(arg2));
			}
		}
		return;
	} else if (StrEqual(arg, "@bots")) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2) && IsFakeClient(client2)) {
				FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client2), StringToInt(arg2));
			}
		}
		return;
	} else if (StrEqual(arg, "@humans")) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2) && !IsFakeClient(client2)) {
				FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client2), StringToInt(arg2));
			}
		}
		return;
	}
	int player = FindTarget(client, arg, false, false);
	powerup[player] = StringToInt(arg2);
	PlayPowerupSound(player);
	// If player is a bot and bot support is enabled
	if (IsFakeClient(player) && GetConVarFloat(sm_fortressblast_bot) >= 1) { // Replace with GetConVarBool
		// Get minimum and maximum times
		float convar1 = GetConVarFloat(sm_fortressblast_bot_min);
		if (convar1 < 0) {
			convar1 == 0;
		}
		float convar2 = GetConVarFloat(sm_fortressblast_bot_max);
		if (convar2 < convar1) {
			convar2 == convar1;
		}
		// Get bot to use powerup within the random period
		CreateTimer(GetRandomFloat(convar1, convar2), BotUsePowerup, player);
	}
	DebugText("%N has force-set %N's powerup to ID %d", client, player, StringToInt(arg2));
}

public Action teamplay_round_start(Event event, const char[] name, bool dontBroadcast) {
	VictoryTime = false;
	EntFire("fb_warningmessage", "Kill");
	PlayersAmount = 0;
	if (!GameRules_GetProp("m_bInWaitingForPlayers")) {
		for (int client = 1; client <= MaxClients; client++) {
			powerup[client] = 0;
			if (IsClientInGame(client)) {
				PlayersAmount++;
				CreateTimer(3.0, PesterThisDude, client);
				// Remove powerup effects on round start
				SetEntityGravity(client, 1.0);
				SuperBounce[client] = false;
				ShockAbsorber[client] = false;
				TimeTravel[client] = false;
				SpeedRotationsLeft[client] = 0;
				SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 0.1);
			}
		}
	}
	CalculateGemAmountForPlayers();
	for (int entity = 1; entity <= MAX_EDICTS ; entity++) { // Remove leftover powerups
		if (IsValidEntity(entity)) {
			char classname[60];
			GetEntityClassname(entity, classname, sizeof(classname));
			if (StrEqual(classname, "tf_halloween_pickup")) {
				DebugText("Removing leftover powerup entity %d", entity);
				RemoveEntity(entity);
			}
		}
	}
	for (int entity = 1; entity <= MAX_EDICTS ; entity++) { // Add powerups and replace Mannpower
		if (IsValidEntity(entity)) {
			char classname[60];
			GetEntityClassname(entity, classname, sizeof(classname));
			if (FindEntityByClassname(0, "tf_logic_mannpower") != -1 && GetConVarInt(sm_fortressblast_mannpower) != 0) {
				if ((!MapHasJsonFile || GetConVarInt(sm_fortressblast_mannpower) == 2)) {
					if (StrEqual(classname, "item_powerup_rune") || StrEqual(classname, "item_powerup_crit") || StrEqual(classname, "item_powerup_uber") || StrEqual(classname, "info_powerup_spawn")) {
						if (StrEqual(classname, "info_powerup_spawn")) {
							float coords[3] = 69.420;
							GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
							DebugText("Found Mannpower spawn at %f, %f, %f", coords[0], coords[1], coords[2]);
							SpawnPower(coords, true);
						}
						DebugText("Removing entity name %s", classname);
						RemoveEntity(entity);
					}
				}
			}
		}
	}
	GetPowerupPlacements();
	Gifts[2] = 0;
	Gifts[3] = 0;
	int spawnrooms;
	while ((spawnrooms = FindEntityByClassname(spawnrooms, "func_respawnroom")) != -1) {
		SDKHook(spawnrooms, SDKHook_TouchPost, OnTouchRespawnRoom);
	}
}

CalculateGemAmountForPlayers() {
	giftgoal = GetConVarInt(sm_fortressblast_gifthunt_goal);
	DebugText("Base gift goal is %d", giftgoal);
	int steps = RoundToFloor((PlayersAmount - 1) / GetConVarFloat(sm_fortressblast_gifthunt_players));
	if (steps < 0) {
		steps = 0;
	}
	giftgoal += (GetConVarInt(sm_fortressblast_gifthunt_increment) * steps);
	DebugText("Calculated gift goal is %d", giftgoal);
}

public OnEntityDestroyed(int entity) {
	if (IsValidEntity(entity) && entity > 0) {
		ClearTimer(DestroyPowerupHandle[entity]); // This causes about half a second of lag when a new round starts. but not having it causes problems
		char classname[60];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(StrEqual(classname, "tf_halloween_pickup") && powerupid[entity] == 0){ // This is just an optimizer, the same thing would happen without this but slower
			char giftidsandstuff[20];
			Format(giftidsandstuff, sizeof(giftidsandstuff), "fb_giftid_%d", entity);
			int entity2 = 0;
			while ((entity2 = FindEntityByClassname(entity2, "env_sprite")) != -1) {
				char name2[50];
				GetEntPropString(entity2, Prop_Data, "m_iName", name2, sizeof(name2));
				if (StrEqual(name2, giftidsandstuff)) {
					RemoveEntity(entity2);
				}
			}
		}
	}
}

public OnGameFrame() {
	if (NumberOfActiveGifts() == 0) {
		RestockRandomBatch();
	}
}

RestockRandomBatch() {
	int entity = 0;
	while ((entity = FindEntityByClassname(entity, "info_target")) != -1) {
		char name2[50];
		GetEntPropString(entity, Prop_Data, "m_iName", name2, sizeof(name2));
		if (StrEqual(name2, "fb_giftspawn") && GetRandomInt(0, 99) < GetConVarInt(sm_fortressblast_gifthunt_rate)) {
			float coords[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
			coords[2] += 8.0;
			SpawnGift(coords);
		}
	}
}

int NumberOfActiveGifts() {
	int totalgifts;
	int entity;
	while ((entity = FindEntityByClassname(entity, "tf_halloween_pickup")) != -1) {
		if (powerupid[entity] == 0) {
			totalgifts++;
		}
	}
	return totalgifts;
}

public Action PesterThisDude(Handle timer, int client) {
	if (IsClientInGame(client)) { // Required because player might disconnect before this fires
		CPrintToChat(client, "{orange}[Fortress Blast] {haunted}This server is running {yellow}Fortress Blast v2.1! {haunted}If you would like to know more or are unsure what a powerup does, type the command {yellow}!fortressblast {haunted}into chat.");
	}
}

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast) {
	VictoryTime = true;
}

public Action player_death(Event event, const char[] name, bool dontBroadcast) {
	powerup[GetClientOfUserId(event.GetInt("userid"))] = 0;
	// Is dropping powerups enabled
	if (GetConVarFloat(sm_fortressblast_drop) == 2 || (GetConVarFloat(sm_fortressblast_drop) && !MapHasJsonFile)) { // Replace with GetConVarBool
		// Get chance a powerup will be dropped
		float convar = GetConVarFloat(sm_fortressblast_drop_rate);
		int randomNumber = GetRandomInt(0, 99);
		if (convar > randomNumber && (GetConVarInt(sm_fortressblast_drop_teams) == GetClientTeam(GetClientOfUserId(event.GetInt("userid"))) || GetConVarInt(sm_fortressblast_drop_teams) == 1)) {
			DebugText("Dropping powerup due to player death");
			float coords[3];
			GetEntPropVector(GetClientOfUserId(event.GetInt("userid")), Prop_Send, "m_vecOrigin", coords);
			int entity = SpawnPower(coords, false);
			ClearTimer(DestroyPowerupHandle[entity]);
			DestroyPowerupHandle[entity] = CreateTimer(15.0, DestroyPowerupTime, entity);
		}
	}
}

public Action DestroyPowerupTime(Handle timer, int entity){
	DestroyPowerupHandle[entity] = INVALID_HANDLE;
	RemoveEntity(entity);
}

public OnClientPutInServer(int client) {
	powerup[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	SDKHook(client, SDKHook_StartTouch, OnStartTouchFrozen);
	CreateTimer(3.0, PesterThisDude, client);
}

int SpawnPower(float location[3], bool respawn, int id = 0) {
	// First check if there is a powerup already here, in the case that a duplicate has spawned
	int entity = CreateEntityByName("tf_halloween_pickup");
	DispatchKeyValue(entity, "powerup_model", "models/fortressblast/pickups/fb_pickup.mdl");
	DebugText("Spawning powerup entity %d at %f, %f, %f", entity, location[0], location[1], location[2]);
	if (IsValidEdict(entity)) {
		if (id == 0) {
			powerupid[entity] = GetRandomInt(1, NumberOfPowerups);
			while (!PowerupIsEnabled(powerupid[entity])) {
				powerupid[entity] = GetRandomInt(1, NumberOfPowerups);
			}
		} else {
			powerupid[entity] = id;
		}
		if (powerupid[entity] == 1) {
			SetEntityRenderColor(entity, 85, 102, 255, 255);
		} else if (powerupid[entity] == 2) {
			SetEntityRenderColor(entity, 255, 0, 0, 255);
		} else if (powerupid[entity] == 3) {
			SetEntityRenderColor(entity, 255, 119, 17, 255);
		} else if (powerupid[entity] == 4) {
			SetEntityRenderColor(entity, 255, 85, 119, 255);
		} else if (powerupid[entity] == 5) {
			SetEntityRenderColor(entity, 0, 204, 0, 255);
		} else if (powerupid[entity] == 6) {
			SetEntityRenderColor(entity, 136, 255, 170, 255);
		} else if (powerupid[entity] == 7) {
			SetEntityRenderColor(entity, 255, 255, 0, 255);
		} else if (powerupid[entity] == 8) {
			SetEntityRenderColor(entity, 85, 85, 85, 255);
		} else if (powerupid[entity] == 9) {
			SetEntityRenderColor(entity, 255, 187, 255, 255);
		} else if (powerupid[entity] == 10) {
			SetEntityRenderColor(entity, 0, 0, 0, 255);
		} else if (powerupid[entity] == 11) {
			SetEntityRenderColor(entity, 255, 153, 153, 255);
		}
		DispatchKeyValue(entity, "pickup_sound", "get_out_of_the_console_snoop");
		DispatchKeyValue(entity, "pickup_particle", "get_out_of_the_console_snoop");
		AcceptEntityInput(entity, "EnableCollision");
		DispatchSpawn(entity);
		ActivateEntity(entity);
		TeleportEntity(entity, location, NULL_VECTOR, NULL_VECTOR);
		if (respawn) {
			SDKHook(entity, SDKHook_StartTouch, OnStartTouchRespawn);
		} else {
			SDKHook(entity, SDKHook_StartTouch, OnStartTouchDontRespawn);
		}
	}
	return entity;
}

int SpawnGift(float location[3]) {
	GiftHunt = true;
	int entity = CreateEntityByName("tf_halloween_pickup");
	if (IsValidEntity(entity)) {
		DispatchKeyValue(entity, "powerup_model", "models/items/tf_gift.mdl");
		DispatchKeyValue(entity, "pickup_sound", "get_out_of_the_console_snoop");
		DispatchKeyValue(entity, "pickup_particle", "get_out_of_the_console_snoop");
		char giftidsandstuff[20];
		Format(giftidsandstuff, sizeof(giftidsandstuff), "fb_giftid_%d", entity);
		DispatchKeyValue(entity, "targetname", giftidsandstuff);
		AcceptEntityInput(entity, "EnableCollision");
		DispatchSpawn(entity);
		ActivateEntity(entity);
		TeleportEntity(entity, location, NULL_VECTOR, NULL_VECTOR);
		SDKHook(entity, SDKHook_StartTouch, OnStartTouchDontRespawn);
		powerupid[entity] = 0;
		int entity2 = CreateEntityByName("env_sprite");
		if(IsValidEntity(entity2)){
			DispatchKeyValue(entity2, "model", "sprites/fortressblast/gift_located_here.vmt");
			//SetEntityFlags(entity2, 1);
			DispatchKeyValue(entity2, "spawnflags", "1");
			DispatchSpawn(entity2);
			ActivateEntity(entity2);
			float coords[3] = 69.420;
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
			coords[2] += 32.0;
			TeleportEntity(entity2, coords, NULL_VECTOR, NULL_VECTOR);
			DispatchKeyValue(entity2, "targetname", giftidsandstuff);
		}
	}
}

public Action OnStartTouchFrozen(entity, other) {
	// Test that using player and touched player are both valid targets
	if (entity > 0 && entity <= MaxClients && other > 0 && other <= MaxClients && IsClientInGame(entity) && IsClientInGame(other)) {
		if (FrostTouch[entity] && !FrostTouchFrozen[other]) {
			float vel[3];
			GetEntPropVector(other, Prop_Data, "m_vecVelocity", vel);
			EmitAmbientSound("fortressblast2/frosttouch_freeze.mp3", vel, other);
			SetEntityMoveType(other, MOVETYPE_NONE);
			ColorizePlayer(other, {255, 255, 255, 0});
			
			int iRagDoll = CreateRagdoll(other);
			if (iRagDoll > MaxClients && IsValidEntity(iRagDoll)) {
				SetClientViewEntity(other, iRagDoll);
				SetThirdPerson(other, true);
			}
			ClearTimer(FrostTouchUnfreezeHandle[other]);
			FrostTouchUnfreezeHandle[other] = CreateTimer(3.0, FrostTouchUnfreeze, other);
			FrostTouchFrozen[other] = true;
			BlockAttacking(other, 3.0);
		}
	}
}

public Action FrostTouchUnfreeze(Handle timer, int client) {
	FrostTouchUnfreezeHandle[client] = INVALID_HANDLE;
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	EmitAmbientSound("fortressblast2/frosttouch_unfreeze.mp3", vel, client);
	SetClientViewEntity(client, client);
	SetEntityMoveType(client, MOVETYPE_WALK);
	ColorizePlayer(client, {255, 255, 255, 255});
	SetThirdPerson(client, false);
	FrostTouchFrozen[client] = false;
}

public Action OnStartTouchRespawn(entity, other) {
	if (other > 0 && other <= MaxClients) {
		if (!VictoryTime && !GameRules_GetProp("m_bInWaitingForPlayers")) {
			float coords[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
			Handle coordskv = CreateKeyValues("coordskv");
			KvSetFloat(coordskv, "0", coords[0]);
			KvSetFloat(coordskv, "1", coords[1]);
			KvSetFloat(coordskv, "2", coords[2]);
			CreateTimer(10.0, SpawnPowerAfterDelay, coordskv);
		}
		DeletePowerup(entity, other);
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public Action OnStartTouchDontRespawn(entity, other) {
	DeletePowerup(entity, other);
}

DeletePowerup(int entity, other) {
	RemoveEntity(entity);
	if (powerupid[entity] == 0) {
		CollectedGift(other);
		return;
	}
	powerup[other] = powerupid[entity];
	DebugText("%N has collected powerup ID %d", other, powerup[other]);
	PlayPowerupSound(other);
	// If player is a bot and bot support is enabled
	if (IsFakeClient(other) && GetConVarFloat(sm_fortressblast_bot) >= 1) { // Replace with GetConVarBool
		// Get minimum and maximum times
		float convar1 = GetConVarFloat(sm_fortressblast_bot_min);
		if (convar1 < 0) {
			convar1 == 0;
		}
		float convar2 = GetConVarFloat(sm_fortressblast_bot_max);
		if (convar2 < convar1) {
			convar2 == convar1;
		}
		// Get bot to use powerup within the random period
		CreateTimer(GetRandomFloat(convar1, convar2), BotUsePowerup, other);
	}
}

public Action BotUsePowerup(Handle timer, int client) {
	if (IsClientInGame(client)) {
		DebugText("Forcing bot %N to use powerup ID %d", client, powerup[client]);
		UsePower(client);
	}
}

public Action SpawnPowerAfterDelay(Handle timer, any data) {
	float coords[3];
	Handle coordskv = data;
	coords[0] = KvGetFloat(coordskv, "0");
	coords[1] = KvGetFloat(coordskv, "1");
	coords[2] = KvGetFloat(coordskv, "2");
	DebugText("Respawning powerup at %f, %f, %f", coords[0], coords[1], coords[2]);
	SpawnPower(coords, true);
}

PlayPowerupSound(int client) {
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (powerup[client] == 1) {
		EmitSoundToClient(client, "fortressblast2/superbounce_pickup.mp3", client);
	} else if (powerup[client] == 2) {
		EmitSoundToClient(client, "fortressblast2/shockabsorber_pickup.mp3", client);
	} else if (powerup[client] == 3) {
		EmitSoundToClient(client, "fortressblast2/superspeed_pickup.mp3", client);
	} else if (powerup[client] == 4) {
		EmitSoundToClient(client, "fortressblast2/superjump_pickup.mp3", client);
	} else if (powerup[client] == 5) {
		EmitSoundToClient(client, "fortressblast2/gyrocopter_pickup.mp3", client);
	} else if (powerup[client] == 6) {
		EmitSoundToClient(client, "fortressblast2/timetravel_pickup.mp3", client);
	} else if (powerup[client] == 7) {
		EmitSoundToClient(client, "fortressblast2/blast_pickup.mp3", client);
	} else if (powerup[client] == 8) {
		EmitSoundToClient(client, "fortressblast2/megamann_pickup.mp3", client);
	} else if (powerup[client] == 9) {
		EmitSoundToClient(client, "fortressblast2/frosttouch_pickup.mp3", client);
	} else if (powerup[client] == 10) {
		EmitSoundToClient(client, "fortressblast2/mystery_pickup.mp3", client);
	} else if (powerup[client] == 11) {
		EmitSoundToClient(client, "fortressblast2/teleportation_pickup.mp3", client);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float ang[3], int &weapon) {
	float coords[3] = 69.420;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
	if (TimeTravel[client]) {
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 520.0);
	}
	if (buttons & 33554432 && (!PreviousAttack3[client]) && StringButtonInt() != 33554432) {
		char button[40];
		GetConVarString(sm_fortressblast_action_use, button, sizeof(button));
		CPrintToChat(client, "{orange}[Fortress Blast] {red}Special attack is currerntly disabled on this server. You are required to {yellow}perform the '%s' action to use a powerup.", button);
	} else if (buttons & StringButtonInt() && IsPlayerAlive(client) && !FrostTouchFrozen[client]) {
		UsePower(client);
		// Only Super Speed should be blocked when carrying the PASS Time Jack
	}
	float vel2[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel2);
	if (GetEntityFlags(client) & FL_ONGROUND) {
		if (VerticalVelocity[client] != 0.0 && SuperBounce[client] && VerticalVelocity[client] < -250.0) {
			vel2[2] = (VerticalVelocity[client] * -1);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel2);
			DebugText("Setting %N's vertical velocity to %f", client, vel2[2]);
		}
	}
	DoHudText(client);
	VerticalVelocity[client] = vel2[2];
	
	for (int partid = MAX_PARTICLES; partid > 0 ; partid--) {
		if (PlayerParticle[client][partid] == 0) {
			PlayerParticle[client][partid] = -1;
		}
		if (IsValidEntity(PlayerParticle[client][partid])) {
			TeleportEntity(PlayerParticle[client][partid], coords, NULL_VECTOR, NULL_VECTOR);
		}
	}
	PreviousAttack3[client] = (buttons > 33554431);
	// Block placing sapping during Time Travel
	if (TimeTravel[client]) {
		buttons &= ~IN_ATTACK;
	}
	// Block placing buildings until Mega Mann stuck-check is complete
	if (IsValidEntity(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))) {
		if (GetEntProp(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), Prop_Send, "m_iItemDefinitionIndex") == 28 && !MegaMannStuckComplete[client] && MegaMann[client]) {
			buttons &= ~IN_ATTACK;
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
	if (ShockAbsorber[victim]) {
		damage = damage * 0.25;
		damageForce[0] = 0.0;
		damageForce[1] = 0.0;
		damageForce[2] = 0.0;
	}
	if (SuperBounce[victim] && attacker == 0 && damage < 100.0) {
		return Plugin_Handled;
	}
	return Plugin_Changed;
}

UsePower(client) {
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (powerup[client] == 1) {
		// Super Bounce - Uncontrollable bunny hop and fall damage resistance for 5 seconds
		EmitAmbientSound("fortressblast2/superbounce_use.mp3", vel, client);
		VerticalVelocity[client] = 0.0; // Cancel previously stored vertical velocity
		SuperBounce[client] = true;
		ClearTimer(SuperBounceHandle[client]);
		SuperBounceHandle[client] = CreateTimer(5.0, RemoveSuperBounce, client);
		PowerupParticle(client, "teleporter_blue_charged_level2", 5.0);
	} else if (powerup[client] == 2) {
		// Shock Absorber - 75% damage and 100% knockback resistances for 5 seconds
		ShockAbsorber[client] = true;
		EmitAmbientSound("fortressblast2/shockabsorber_use.mp3", vel, client);
		ClearTimer(ShockAbsorberHandle[client]);
		ShockAbsorberHandle[client] = CreateTimer(5.0, RemoveShockAbsorb, client);
		PowerupParticle(client, "teleporter_red_charged_level2", 5.0);
	} else if (powerup[client] == 3) {
		// Super Speed - Increased speed, gradually wears off over 10 seconds
		OldSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
		SpeedRotationsLeft[client] = 80;
		EmitAmbientSound("fortressblast2/superspeed_use.mp3", vel, client);
		CreateTimer(0.1, RecalcSpeed, client);
	} else if (powerup[client] == 4) {
		// Super Jump - Launch user into air
		if (MegaMann[client]) {
			vel[2] += 400.0;
		} else {
			vel[2] += 800.0;
		}
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
		EmitAmbientSound("fortressblast2/superjump_use.mp3", vel, client);
	} else if (powerup[client] == 5) {
		// Gyrocopter - 25% gravity for 5 seconds
		SetEntityGravity(client, 0.25);
		ClearTimer(GyrocopterHandle[client]);
		GyrocopterHandle[client] = CreateTimer(5.0, RestoreGravity, client);
		EmitAmbientSound("fortressblast2/gyrocopter_use.mp3", vel, client);
	} else if (powerup[client] == 6) {
		// Time Travel - Increased speed, invisibility and can't attack for 5 seconds
		TimeTravel[client] = true;
		SetThirdPerson(client, true);
		TF2_AddCondition(client, TFCond_StealthedUserBuffFade, 3.0);
		BlockAttacking(client, 3.0);
		ClearTimer(TimeTravelHandle[client]);
		TimeTravelHandle[client] = CreateTimer(3.0, RemoveTimeTravel, client);
		EmitAmbientSound("fortressblast2/timetravel_use_3sec.mp3", vel, client);
	} else if (powerup[client] == 7) {
		// Blast - Create explosion at user
		PowerupParticle(client, "rd_robot_explosion", 1.0);
		EmitAmbientSound("fortressblast2/blast_use.mp3", vel, client);
		float pos1[3];
		GetClientAbsOrigin(client, pos1);
		float pos2[3];
		for (int client2 = 1 ; client2 <= MaxClients ; client2++ ) {
			if (IsClientInGame(client2)) {
				GetClientAbsOrigin(client2, pos2);
				if (GetVectorDistance(pos1, pos2) <= 250.0 && GetClientTeam(client) != GetClientTeam(client2)) {
					SDKHooks_TakeDamage(client2, 0, client, (150.0 - (GetVectorDistance(pos1, pos2) * 0.4)), 0, -1);
				}
			}
		}
		TF2_RemoveCondition(client, TFCond_StealthedUserBuffFade);
		TF2_RemoveCondition(client, TFCond_Cloaked);
		TF2_RemovePlayerDisguise(client);
		TimeTravelHandle[client] = CreateTimer(0.0, RemoveTimeTravel, client); // Remove Time Travel instantly
	} else if (powerup[client] == 8) {
		// Mega Mann - Giant and 4x health for 10 seconds
		EmitAmbientSound("fortressblast2/megamann_use.mp3", vel, client);
		SetVariantString("1.75 0");
		AcceptEntityInput(client, "SetModelScale");
		SetEntityHealth(client, (GetClientHealth(client) * 4)); // 4x current health
		// Cap at 4x maximum health
		if (GetClientHealth(client) > (TF2_GetPlayerMaxHealth(client) * 4)) {
			SetEntityHealth(client, TF2_GetPlayerMaxHealth(client) * 4);
		}
		ClearTimer(MegaMannHandle[client]);
		ClearTimer(MegaMannPreHandle[client]);
		MegaMannPreHandle[client] = CreateTimer(1.0, MegaMannStuckCheck, client);
		MegaMannHandle[client] = CreateTimer(10.0, RemoveMegaMann, client);
		float coords[3] = 69.420;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
		coords[2] += 16.0;
		TeleportEntity(client, coords, NULL_VECTOR, NULL_VECTOR);
		MegaMannCoords[client][0] = coords[0];
		MegaMannCoords[client][1] = coords[1];
		MegaMannCoords[client][2] = coords[2];
		MegaMann[client] = true;
		MegaMannStuckComplete[client] = false;
	} else if (powerup[client] == 9) {
		// Frost Touch - Freeze touched players for 3 seconds within 8 seconds
		EmitAmbientSound("fortressblast2/frosttouch_use.mp3", vel, client);
		ClearTimer(FrostTouchHandle[client]);
		FrostTouchHandle[client] = CreateTimer(8.0, RemoveFrostTouch, client);
		FrostTouch[client] = true;
		PowerupParticle(client, "smoke_rocket_steam", 8.0);
	} else if (powerup[client] == 10) {
		// Mystery - Random powerup
		int mysrand = 10;
		while (mysrand == 10 || !PowerupIsEnabled(mysrand)) {
			mysrand = GetRandomInt(1, NumberOfPowerups);
		}
		powerup[client] = mysrand;
		UsePower(client);
	} else if (powerup[client] == 11) {
		// Teleportation - Teleport to random active Engineer exit teleport or spawn
		ClearTimer(TeleportationHandle[client]);
		TeleportationHandle[client] = CreateTimer(0.5, BeginTeleporter, client);
		EmitAmbientSound("fortressblast2/teleportation_use.mp3", vel, client);
		PowerupParticle(client, "teleported_flash", 0.5); // Particle on using powerup
		int clients[2];
		clients[0] = client;	
		int duration = 255;
		int holdtime = 255;
		int flags = 0x0002;
		int color[4] = {255, 255, 255, 255};
		UserMsg g_FadeUserMsgId = GetUserMessageId("Fade");
		Handle message = StartMessageEx(g_FadeUserMsgId, clients, 1);
		if (GetUserMessageType() == UM_Protobuf) {
			Protobuf pb = UserMessageToProtobuf(message);
			pb.SetInt("duration", duration);
			pb.SetInt("hold_time", holdtime);
			pb.SetInt("flags", flags);	
			pb.SetColor("clr", color);
		} else {
			BfWriteShort(message, duration);
			BfWriteShort(message, holdtime);	
			BfWriteShort(message, flags);
			BfWriteByte(message, color[0]);
			BfWriteByte(message, color[1]);
			BfWriteByte(message, color[2]);
			BfWriteByte(message, color[3]);
		}
		EndMessage();
	}
	powerup[client] = 0;
}

public Action BeginTeleporter(Handle timer, int client) {
	TeleportationHandle[client] = INVALID_HANDLE;
	PowerupParticle(client, "teleported_flash", 0.5); // Particle on teleporting away
	int entity;
	while ((entity = FindEntityByClassname(entity, "obj_teleporter")) != -1) {
		if (TF2_GetClientTeam(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")) == TF2_GetClientTeam(client)) {
			if (TF2_GetObjectMode(entity) == TFObjectMode_Exit) {
				float coords[3] = 69.420;
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
				coords[2] += 24.00;
				TeleportEntity(client, coords, NULL_VECTOR, NULL_VECTOR);
				break;
			}
		}
	}
	if (entity == -1) {
		CPrintToChat(client, "{orange}[Fortress Blast] {haunted}You were respawned as there are no active Teleporter exits on your team.");
		TF2_RespawnPlayer(client);
	} else if (TF2_GetClientTeam(client) == TFTeam_Red) {
		PowerupParticle(client, "teleportedin_red", 1.0);
	} else if (TF2_GetClientTeam(client) == TFTeam_Blue) {
		PowerupParticle(client, "teleportedin_blue", 1.0);
	}
}

public Action RemoveFrostTouch(Handle timer, int client) {
	FrostTouchHandle[client] = INVALID_HANDLE;
	FrostTouch[client] = false;
}

public Action MegaMannStuckCheck(Handle timer, int client) {
	MegaMannPreHandle[client] = INVALID_HANDLE;
	MegaMannStuckComplete[client] = true;
	MegaMann[client] = false;
	float coords[3] = 69.420;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
	if (MegaMannCoords[client][0] == coords[0] && MegaMannCoords[client][1] == coords[1] && MegaMannCoords[client][2] == coords[2]) {
		TF2_RespawnPlayer(client);
		CPrintToChat(client, "{orange}[Fortress Blast] {red}You were respawned as you might have been stuck. Be sure to {yellow}use Mega Mann in open areas {red}and {yellow}move once it is active.");
	}
}

public Action RemoveMegaMann(Handle timer, int client) {
	MegaMannHandle[client] = INVALID_HANDLE;
	MegaMann[client] = false;
	MegaMannStuckComplete[client] = true;
	if (IsClientInGame(client)) {
		SetVariantString("1 0");
		AcceptEntityInput(client, "SetModelScale");
		// Remove excess overheal, but leave injuries
		if (GetClientHealth(client) > TF2_GetPlayerMaxHealth(client)) {
			SetEntityHealth(client, TF2_GetPlayerMaxHealth(client));
		}
	}
}

public Action RemoveTimeTravel(Handle timer, int client) {
	TimeTravelHandle[client] = INVALID_HANDLE;
	TimeTravel[client] = false;
	SetThirdPerson(client, false);
	if (IsClientInGame(client)) {
		TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
	}
}

public Action RestoreGravity(Handle timer, int client) {
	GyrocopterHandle[client] = INVALID_HANDLE;
	if (IsClientInGame(client)) {
		SetEntityGravity(client, 1.0);
	}
}

public Action RemoveSuperBounce(Handle timer, int client) {
	SuperBounceHandle[client] = INVALID_HANDLE;
	SuperBounce[client] = false;
}

public Action RemoveShockAbsorb(Handle timer, int client) {
	ShockAbsorberHandle[client] = INVALID_HANDLE;
	ShockAbsorber[client] = false;
}

public Action RecalcSpeed(Handle timer, int client) {
	if (SpeedRotationsLeft[client] > 1) {
		if (IsPlayerAlive(client)) {
			if (GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") != SuperSpeed[client]) { // If TF2 changed the speed
				OldSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
			}
			SuperSpeed[client] = OldSpeed[client] + (SpeedRotationsLeft[client] * 2);
			SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", SuperSpeed[client]);
			CreateTimer(0.1, RecalcSpeed, client);
		}
	} else {
		TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
	}
	SpeedRotationsLeft[client]--;
}

DoHudText(client) {
	if (powerup[client] != 0) {
  		SetHudTextParams(0.9, 0.5, 0.25, 255, 255, 0, 255);
  		if (powerup[client] == 1) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nSuper Bounce");
		} else if (powerup[client] == 2) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nShock Absorber");
		} else if (powerup[client] == 3) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nSuper Speed");
		} else if (powerup[client] == 4) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nSuper Jump");
		} else if (powerup[client] == 5) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nGyrocopter");
		} else if (powerup[client] == 6) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nTime Travel");
		} else if (powerup[client] == 7) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nBlast");
		} else if (powerup[client] == 8) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nMega Mann");
		} else if (powerup[client] == 9) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nFrost Touch");
		} else if (powerup[client] == 10) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nMystery");
		} else if (powerup[client] == 11) {
			ShowSyncHudText(client, texthand, "Collected powerup:\nTeleportation");
		}
	}
	if (GiftHunt && !VictoryTime) {
  		SetHudTextParams(-1.0, 0.775, 0.25, 255, 255, 255, 255);
  		ShowSyncHudText(client, gemtext, "BLU: %d | Playing to %d gifts | RED: %d", Gifts[3], giftgoal, Gifts[2]);
	}
}

GetPowerupPlacements() {
	if (!MapHasJsonFile) {
		PrintToServer("[Fortress Blast] No .json file for this map! You can download pre-made files from our GitHub map repository:");
		PrintToServer("https://github.com/Fortress-Blast/Fortress-Blast-Maps");
		return;
	}
	char map[80];
	GetCurrentMap(map, sizeof(map));
	char path[PLATFORM_MAX_PATH + 1];
	Format(path, sizeof(path), "scripts/fortress_blast/powerup_spots/%s.json", map);
	JSONObject handle = JSONObject.FromFile(path);
	int itemloop = 1;
	char stringamount[80];
	bool flipx = false;
	bool flipy = false;
	float centerx = 0.0;
	float centery = 0.0;
	char cent[80];
	if (HandleHasKey(handle, "flipx")) {
		flipx = handle.GetBool("flipx");
	}
	if (HandleHasKey(handle, "flipy")) {
		flipy = handle.GetBool("flipy");
	}
	if (flipx || flipy) {
		if (HandleHasKey(handle, "centerx")) {
			handle.GetString("centerx", cent, sizeof(cent));
			centerx = StringToFloat(cent);
		}
		if (HandleHasKey(handle, "centery")) {
			handle.GetString("centery", cent, sizeof(cent));
			centery = StringToFloat(cent);
		}
	}
	IntToString(itemloop, stringamount, sizeof(stringamount));
	bool spcontinue = true;
	while (spcontinue) {
		float coords[3] = 0.001;
		char query[80];
		for (int to = 0; to <= 2; to++) {
			char string[15];
			query = "";
			StrCat(query, sizeof(query), stringamount);
			StrCat(query, sizeof(query), "-");
			if (to == 0) {
				StrCat(query, sizeof(query), "x");
			}
			if (to == 1) {
				StrCat(query, sizeof(query), "y");
			}
			if (to == 2) {
				StrCat(query, sizeof(query), "z");
			}
			if (HandleHasKey(handle, query)) {
				handle.GetString(query, string, sizeof(string));
				coords[to] = StringToFloat(string);
			} else {
				spcontinue = false;
			}
		} 
		DebugText("Created powerup at %f, %f, %f", coords[0], coords[1], coords[2]);
		if (coords[0] != 0.001) {
			SpawnPower(coords, true);
			if (flipx && flipy) {
				if (coords[0] != centerx || coords[1] != centery) {
					coords[0] = coords[0] - ((coords[0] - centerx) * 2);
					coords[1] = coords[1] - ((coords[1] - centery) * 2);
					DebugText("Flipping both axes, new powerup created at %f %f %f", coords[0], coords[1], coords[2]);
					SpawnPower(coords, true);
				} else {
					DebugText("Powerup is at the center and will not be flipped");
   	 			}
			} else if (flipx) {
				if (coords[0] != centerx) {
					coords[0] = coords[0] - ((coords[0] - centerx) * 2);
					DebugText("Flipping X axis, new powerup created at %f, %f, %f", coords[0], coords[1], coords[2]);
					SpawnPower(coords, true);
				} else {
					DebugText("Powerup is at the X axis center and will not be flipped");
    			}
			} else if (flipy) {
				if (coords[1] != centery) {
					coords[1] = coords[1] - ((coords[1] - centery) * 2);
					DebugText("Flipping Y axis, new powerup created at %f, %f, %f", coords[0], coords[1], coords[2]);
					SpawnPower(coords, true);
				} else {
					DebugText("Powerup is at the Y axis center and will not be flipped");
				}
			}
			itemloop++;
			IntToString(itemloop, stringamount, sizeof(stringamount));
		}
	}
	return;
}

bool HandleHasKey(JSONObject handle, char key[80]) {
	char acctest[10000];
	handle.ToString(acctest, sizeof(acctest));
	return (StrContains(acctest, key, true) != -1);
}

stock ClearTimer(Handle Timer) { // From SourceMod forums
    if (Timer != INVALID_HANDLE) {
        CloseHandle(Timer);
        Timer = INVALID_HANDLE;
    }
}

SwitchPrimary(int client) {
	int weapon = GetPlayerWeaponSlot(client, 0);
	if (IsValidEdict(weapon)) {
		char class[MAX_NAME_LENGTH * 2]; 
		GetEdictClassname(weapon, class, sizeof(class));
		FakeClientCommand(client, "use %s", class);
		SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", weapon);
	}
}

PowerupParticle(int client, char particlename[80], float time) {
	int particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(particle, "effect_name", particlename);
	AcceptEntityInput(particle, "SetParent", client);
	AcceptEntityInput(particle, "Start");
	DispatchSpawn(particle);
	ActivateEntity(particle);
	float coords[3] = 69.420;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
	TeleportEntity(particle, coords, NULL_VECTOR, NULL_VECTOR);
	int freeid = -5;
	for (int partid = MAX_PARTICLES; partid > 0 ; partid--) {
		if (!IsValidEntity(PlayerParticle[client][partid])) {
			freeid = partid;
		}
	}
	if (freeid == -5) {
		freeid = GetRandomInt(1, MAX_PARTICLES);
		RemoveEntity(PlayerParticle[client][freeid]);
		PrintToServer("[Fortress Blast] All of %N's particles were in use, freeing #%d", client, freeid);
	}
	PlayerParticle[client][freeid] = particle;
	Handle partkv = CreateKeyValues("partkv");
	KvSetNum(partkv, "client", client);
	KvSetNum(partkv, "id", freeid);
	CreateTimer(time, RemoveParticle, partkv);
}

public Action RemoveParticle(Handle timer, any data) {
	Handle partkv = data;
	int client = KvGetNum(partkv, "client");
	int id = KvGetNum(partkv, "id");
	if (IsValidEntity(PlayerParticle[client][id])) {
		RemoveEntity(PlayerParticle[client][id]);
	}
	PlayerParticle[client][id] = -1;
}

DebugText(const char[] text, any ...) {
	if (GetConVarFloat(sm_fortressblast_debug) >= 1) {
		int len = strlen(text) + 255;
		char[] format = new char[len];
		VFormat(format, len, text, 2);
		CPrintToChatAll("{orange}[FB Debug] {default}%s", format);
		PrintToServer("[FB Debug] %s", format);
	}
}

int StringButtonInt() {
	char button[40];
	GetConVarString(sm_fortressblast_action_use, button, sizeof(button));
	if (StrEqual(button, "attack")) {
		return 1;
	} else if (StrEqual(button, "jump")) {
		return 2;
	} else if (StrEqual(button, "duck")) {
		return 4;
	} else if (StrEqual(button, "forward")) {	
		return 8;
	} else if (StrEqual(button, "back")) {
		return 16;
	} else if (StrEqual(button, "use")) {
		return 32;
	} else if (StrEqual(button, "cancel")) {
		return 64;
	} else if (StrEqual(button, "left")) {
		return 128;
	} else if (StrEqual(button, "right")) {
		return 256;
	} else if (StrEqual(button, "moveleft")) {
		return 512;
	} else if (StrEqual(button, "moveright")) {
		return 1024;
	} else if (StrEqual(button, "attack2")) {
		return 2048;
	} else if (StrEqual(button, "run")) {
		return 4096;
	} else if (StrEqual(button, "reload")) {
		return 8192;
	} else if (StrEqual(button, "alt1")) {
		return 16384;
	} else if (StrEqual(button, "alt2")) {
		return 32768;
	} else if (StrEqual(button, "score")) {
		return 65536;
	} else if (StrEqual(button, "speed")) {
		return 131072;
	} else if (StrEqual(button, "walk")) {
		return 262144;
	} else if (StrEqual(button, "zoom")) {
		return 524288;
	} else if (StrEqual(button, "weapon1")) {
		return 1048576;
	} else if (StrEqual(button, "weapon2")) {
		return 2097152;
	} else if (StrEqual(button, "bullrush")) {
		return 4194304;
	} else if (StrEqual(button, "grenade1")) {
		return 8388608;
	} else if (StrEqual(button, "grenade2")) {
		return 16777216;
	} else { // Special attack
		return 33554432;
	}
}

stock int TF2_GetPlayerMaxHealth(int client) {
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}

stock ColorizePlayer(client, iColor[4]) { // Roll the Dice function with new syntax
	SetEntityColor(client, iColor);
	for (new i=0; i<3; i++) {
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if (iWeapon > MaxClients && IsValidEntity(iWeapon)) {
			SetEntityColor(iWeapon, iColor);
		}
	}
	char strClass[20];
	for (new i=MaxClients+1; i<GetMaxEntities(); i++) {
		if (IsValidEntity(i)) {
			GetEdictClassname(i, strClass, sizeof(strClass));
			if ((strncmp(strClass, "tf_wearable", 11) == 0 || strncmp(strClass, "tf_powerup", 10) == 0) && GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == client) {
				SetEntityColor(i, iColor);
			}
		}
	}
	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hDisguiseWeapon");
	if (iWeapon > MaxClients && IsValidEntity(iWeapon)) {
		SetEntityColor(iWeapon, iColor);
	}
	TF2_RemoveCondition(client, TFCond_DemoBuff);
}

CreateRagdoll(client) { // Roll the Dice function with new syntax
	int iRag = CreateEntityByName("tf_ragdoll");
	if (iRag > MaxClients && IsValidEntity(iRag)) {
		float flPos[3];
		float flAng[3];
		float flVel[3];
		GetClientAbsOrigin(client, flPos);
		GetClientAbsAngles(client, flAng);
		TeleportEntity(iRag, flPos, flAng, flVel);
		SetEntProp(iRag, Prop_Send, "m_iPlayerIndex", client);
		SetEntProp(iRag, Prop_Send, "m_bIceRagdoll", 1);
		SetEntProp(iRag, Prop_Send, "m_iTeam", GetClientTeam(client));
		SetEntProp(iRag, Prop_Send, "m_iClass", _:TF2_GetPlayerClass(client));
		SetEntProp(iRag, Prop_Send, "m_bOnGround", 1);
		SetEntityMoveType(iRag, MOVETYPE_NONE);
		DispatchSpawn(iRag);
		ActivateEntity(iRag);
		return iRag;
	}
	return 0;
}

SetThirdPerson(client, bool bEnabled) { // Roll the Dice function with new syntax
	if (bEnabled) {
		SetVariantInt(1);
	} else {
		SetVariantInt(0);
	}
	AcceptEntityInput(client, "SetForcedTauntCam");
}

stock SetEntityColor(iEntity, iColor[4]) { // Roll the Dice function with new syntax
	SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iEntity, iColor[0], iColor[1], iColor[2], iColor[3]);
}

BlockAttacking(int client, float time) { // Roll the Dice function with new syntax
	for (int weapon = 0; weapon <= 5 ; weapon++) {
		if (GetPlayerWeaponSlot(client, weapon) != -1) {
			SetEntPropFloat(GetPlayerWeaponSlot(client, weapon), Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + time);
			SetEntPropFloat(GetPlayerWeaponSlot(client, weapon), Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + time);
		}
	}
	// Cancel active grappling hook
	if (GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") == GetPlayerWeaponSlot(client, 5)) {
		SwitchPrimary(client);
	}
}

CollectedGift(int client) {
	DebugText("%N has collected a gift", client);
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	EmitAmbientSound("fortressblast2/gifthunt_gift_pickup.mp3", vel, client);
	Gifts[GetClientTeam(client)]++;
	if (Gifts[GetClientTeam(client)] == giftgoal) {
		if (GetClientTeam(client) == 2) {
			EntFire("fb_giftscollected_red", "Trigger");
			PrintCenterTextAll("RED team has collected the required number of gifts!");
			DebugText("RED team has collected the required number of gifts", client);
		} else if (GetClientTeam(client) == 3) {
			EntFire("fb_giftscollected_blu", "Trigger");
			PrintCenterTextAll("BLU team has collected the required number of gifts!");
			DebugText("BLU team has collected the required number of gifts", client);
		}
		for (int client2 = 1 ; client2 <= MaxClients ; client2++) {
			if(IsClientInGame(client2)){
				if (GetClientTeam(client2) == GetClientTeam(client)) {
					EmitSoundToClient(client2, "fortressblast2/gifthunt_goal_playerteam.mp3", client2);
				} else {
					EmitSoundToClient(client2, "fortressblast2/gifthunt_goal_enemyteam.mp3", client2);
				}
			}
		}
	}
}

// sm_entfire with updated syntax
EntFire(char[] strTargetname, char[] strInput, char strParameter[] = "", float flDelay = 0.0) {
	char strBuffer[255];
	Format(strBuffer, sizeof(strBuffer), "OnUser1 %s:%s:%s:%f:1", strTargetname, strInput, strParameter, flDelay);
	int entity = CreateEntityByName("info_target");
	if (IsValidEdict(entity)) {
		DispatchSpawn(entity);
		ActivateEntity(entity);
		SetVariantString(strBuffer);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
		CreateTimer(0.0, DeleteEdict, entity);
		return true;
	}
	return false;
}

public Action DeleteEdict(Handle timer, int entity) {
	if(IsValidEdict(entity)) RemoveEdict(entity);
	return Plugin_Stop;
}

bool PowerupIsEnabled(int id) {
	int max = (Bitfieldify(NumberOfPowerups) * 2) - 1;
	int bitfield = GetConVarInt(sm_fortressblast_powerups);
	if (bitfield == -1) {
		return true; // All powerups enabled
	} else if (bitfield < 1 || bitfield > max) {
		PrintToServer("[Fortress Blast] Your powerup whitelist ConVar is out of range. As a fallback, all powerups are allowed.");
		return true;
	} else if (bitfield == 512) {
		PrintToServer("[Fortress Blast] Your powerup whitelist ConVar is set to Mystery only. Mystery requires at least one other powerup to work and cannot be used on its own. As a fallback, all powerups are allowed.");
		return true;
	} // The below statement might need to merged with an else
	if (bitfield & Bitfieldify(id)) {
		return true; // return bitfield & Bitfieldify(id) doesn't work
	} else {
		return false;
	}
}

int Bitfieldify(int bitter) {
	int num = 1;
	for (int id = 1; id <= bitter ; id++) {
		num = num * 2;
	}
	return (num / 2);
}

public Action SpawnPowerup(int client, int args){
	if (client == 0) {
		PrintToServer("[Fortress Blast] Because this command uses the crosshair, it cannot be executed from the server console.");
		return Plugin_Handled;
	}
	float points[3];
	GetCollisionPoint(client, points);
	char arg1[3];
	GetCmdArg(1, arg1, sizeof(arg1));
	SpawnPower(points, false, StringToInt(arg1));
	return Plugin_Handled;
}

stock GetCollisionPoint(client, float pos[3])
{
	float vOrigin[3];
	float vAngles[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
	
	if (TR_DidHit(trace)) {
		TR_GetEndPosition(pos, trace);
		CloseHandle(trace);
		return;
	}
	CloseHandle(trace);
}

public bool TraceEntityFilterPlayer(entity, contentsMask) {
	return entity > MaxClients;
}  

public OnTouchRespawnRoom(entity, other) {
	if (other < 1 || other > MaxClients) return;
	if (!IsClientInGame(other)) return;
	if (!IsPlayerAlive(other)) return;
	// Kill enemies inside spawnrooms
	if (GetEntProp(entity, Prop_Send, "m_iTeamNum") != GetClientTeam(other) && (GetConVarInt(sm_fortressblast_spawnroom_kill) > 0) && !VictoryTime) {
		FakeClientCommandEx(other, "kill");
		PrintToServer("[Fortress Blast] %N was killed due to being inside an enemy team spawnroom.", other);
		CPrintToChat(other, "{orange}[Fortress Blast] {red}You were killed because you were inside the enemy spawn.");
	}
}
