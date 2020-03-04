/* Definitions
==================================================================================================== */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ripext/json>
#include <morecolors>
#include <tf2>
#include <tf2_stocks>
#include <advanced_motd>

#pragma newdecls required

// Defines
#define	MAX_EDICT_BITS 11
#define	MAX_EDICTS (1<<MAX_EDICT_BITS)
#define MAX_PARTICLES 10 // If a player needs more than this number, a random one is deleted, but too many might cause memory problems
#define MESSAGE_PREFIX "{orange}[Fortress Blast]"
#define MESSAGE_PREFIX_NO_COLOR "[Fortress Blast]"
#define PLUGIN_VERSION "5.0 Beta"
#define MOTD_VERSION "5.0"

#define NUMBER_OF_POWERUPS 14 // do not use this definition to calculate - it is only for the variable below and for sizing arrays

#define PI 3.14159265359

public Plugin myinfo = {
	name = "Fortress Blast",
	author = "Benedevil, Jack5, Naleksuh & Rushy",
	description = "Adds powerups from Marble Blast into TF2! Can easily be combined with other plugins and game modes.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Fortress-Blast"
};

// Global Variables
int NumberOfPowerups = NUMBER_OF_POWERUPS; // DO NOT DEFINE THIS!
int PlayersAmount;
int GiftGoal;
int GiftsCollected[4] = 0;
int GiftMultiplier[4] = 1;
int PowerupID[MAX_EDICTS] = -2; // For powerups, gifts and player storage
int PlayerParticle[MAXPLAYERS + 1][MAX_PARTICLES + 1];
int SpeedRotationsLeft[MAXPLAYERS + 1] = 80;
int VictoryTeam = -1;
int DizzyProgress[MAXPLAYERS + 1] = -1;
int FrostTouchFrozen[MAXPLAYERS + 1] = 0;
int GlobalVerifier = 0;
bool PreviousAttack3[MAXPLAYERS + 1] = false;
bool MapHasJsonFile = false;
bool GiftHunt = false;
bool NegativeDizzy[MAXPLAYERS + 1] = false;
bool UltraPowerup[MAXPLAYERS + 1] = false;
bool MegaMannVerified[MAXPLAYERS + 1] = false;
bool UsingPowerup[NUMBER_OF_POWERUPS + 1][MAXPLAYERS+1];
bool GiftHuntAttackDefense = false;
bool GiftHuntNeutralFlag = false;
bool GiftHuntSetup = false;
float GiftHuntIncrementTime = 0.0;
float OldSpeed[MAXPLAYERS + 1] = 0.0;
float SuperSpeed[MAXPLAYERS + 1] = 0.0;
float VerticalVelocity[MAXPLAYERS + 1];
float ParticleZAdjust[MAXPLAYERS + 1][MAX_PARTICLES + 1];
Handle SuperBounceHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle ShockAbsorberHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle GyrocopterHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle TimeTravelHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle MegaMannHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle FrostTouchHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle FrostTouchUnfreezeHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle DestroyPowerupHandle[MAX_EDICTS + 1] = INVALID_HANDLE;
Handle TeleportationHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle MagnetismHandle[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle UltraPowerupHandle[MAXPLAYERS+1] = INVALID_HANDLE;

// HUDs
Handle PowerupText;
Handle GiftText;

// ConVars
ConVar sm_fortressblast_action;
ConVar sm_fortressblast_adminflag;
ConVar sm_fortressblast_blast_buildings;
ConVar sm_fortressblast_bot;
ConVar sm_fortressblast_bot_min;
ConVar sm_fortressblast_bot_max;
ConVar sm_fortressblast_debug;
ConVar sm_fortressblast_dizzy_states;
ConVar sm_fortressblast_dizzy_length;
ConVar sm_fortressblast_drop;
ConVar sm_fortressblast_drop_rate;
ConVar sm_fortressblast_drop_teams;
ConVar sm_fortressblast_event_fools;
ConVar sm_fortressblast_event_xmas;
ConVar sm_fortressblast_gifthunt;
ConVar sm_fortressblast_gifthunt_countbots;
ConVar sm_fortressblast_gifthunt_goal;
ConVar sm_fortressblast_gifthunt_increment;
ConVar sm_fortressblast_gifthunt_players;
ConVar sm_fortressblast_gifthunt_rate;
ConVar sm_fortressblast_gifthunt_bonus;
ConVar sm_fortressblast_intro;
ConVar sm_fortressblast_mannpower;
ConVar sm_fortressblast_powerups;
ConVar sm_fortressblast_powerups_roundstart;
ConVar sm_fortressblast_respawnroomkill;
ConVar sm_fortressblast_ultra_rate;

/* Powerup IDs
-1 - ULTRA POWERUP!!
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
11 - Teleportation
12 - Magnetism
13 - Effect Burst
14 - Dizzy Bomb */

/* OnPluginStart()
==================================================================================================== */

public void OnPluginStart() {
	// In case the plugin is reloaded mid-round
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
			SDKHook(client, SDKHook_StartTouch, OnStartTouchFrozen);
			DizzyProgress[client] = -1;
		}
	}

	// Hooks
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_setup_finished", Event_SetupFinished);
	HookEvent("teamplay_round_win", Event_RoundWin);
	HookEvent("player_death", Event_PlayerDeath);

	// Commands
	RegConsoleCmd("sm_fortressblast", Command_FortressBlast);
	RegConsoleCmd("sm_coordsjson", Command_CoordsJson);
	RegConsoleCmd("sm_setpowerup", Command_SetPowerup);
	RegConsoleCmd("sm_spawnpowerup", Command_SpawnPowerup);
	RegConsoleCmd("sm_respawnpowerups", Command_RespawnPowerups);

	// Translations
	LoadTranslations("common.phrases");

	// ConVars
	sm_fortressblast_action = CreateConVar("sm_fortressblast_action", "attack3", "Which action to watch for in order to use powerups.");
	sm_fortressblast_adminflag = CreateConVar("sm_fortressblast_adminflag", "z", "Which flag to use for admin-restricted commands outside of debug mode.");
	sm_fortressblast_blast_buildings = CreateConVar("sm_fortressblast_blast_buildings", "100", "Percentage of Blast player damage to inflict on enemy buildings.");
	sm_fortressblast_bot = CreateConVar("sm_fortressblast_bot", "1", "Disables or enables bots using powerups.");
	sm_fortressblast_bot_min = CreateConVar("sm_fortressblast_bot_min", "2", "Minimum time for bots to use a powerup.");
	sm_fortressblast_bot_max = CreateConVar("sm_fortressblast_bot_max", "15", "Maximum time for bots to use a powerup.");
	sm_fortressblast_debug = CreateConVar("sm_fortressblast_debug", "0", "Disables or enables command permission overrides and debug messages in chat.");
	sm_fortressblast_dizzy_states = CreateConVar("sm_fortressblast_dizzy_states", "5", "Number of rotational states Dizzy Bomb uses.");
	sm_fortressblast_dizzy_length = CreateConVar("sm_fortressblast_dizzy_length", "5", "Length of time Dizzy Bomb lasts.");
	sm_fortressblast_drop = CreateConVar("sm_fortressblast_drop", "1", "How to handle dropping powerups on death.");
	sm_fortressblast_drop_rate = CreateConVar("sm_fortressblast_drop_rate", "10", "Chance out of 100 for a powerup to drop on death.");
	sm_fortressblast_drop_teams = CreateConVar("sm_fortressblast_drop_teams", "1", "Teams that will drop powerups on death.");
	sm_fortressblast_event_fools = CreateConVar("sm_fortressblast_event_fools", "1", "How to handle the TF2 April Fools event.");
	sm_fortressblast_event_xmas = CreateConVar("sm_fortressblast_event_xmas", "1", "How to handle the TF2 Smissmas event.");
	sm_fortressblast_gifthunt = CreateConVar("sm_fortressblast_gifthunt", "0", "Disables or enables Gift Hunt on maps with Gift Hunt .json files.");
	sm_fortressblast_gifthunt_bonus = CreateConVar("sm_fortressblast_gifthunt_bonus", "1", "Whether or not to multiply players' gift collections once they fall behind.");
	sm_fortressblast_gifthunt_countbots = CreateConVar("sm_fortressblast_gifthunt_countbots", "0", "Disables or enables counting bots as players when increasing the goal.");
	sm_fortressblast_gifthunt_goal = CreateConVar("sm_fortressblast_gifthunt_goal", "125", "Base number of gifts required to unlock the objective in Gift Hunt.");
	sm_fortressblast_gifthunt_increment = CreateConVar("sm_fortressblast_gifthunt_increment", "25", "Amount to increase the gift goal per extra group of players.");
	sm_fortressblast_gifthunt_players = CreateConVar("sm_fortressblast_gifthunt_players", "4", "Number of players in a group, any more and the gift goal increases.");
	sm_fortressblast_gifthunt_rate = CreateConVar("sm_fortressblast_gifthunt_rate", "20", "Chance out of 100 for each gift to spawn once all gifts are collected.");
	sm_fortressblast_intro = CreateConVar("sm_fortressblast_intro", "1", "Disables or enables automatically display the plugin intro message.");
	sm_fortressblast_mannpower = CreateConVar("sm_fortressblast_mannpower", "2", "How to handle replacing Mannpower powerups.");
	sm_fortressblast_powerups = CreateConVar("sm_fortressblast_powerups", "-1", "Bitfield of which powerups to enable.");
	sm_fortressblast_powerups_roundstart = CreateConVar("sm_fortressblast_powerups_roundstart", "1", "Disables or enables automatically spawning powerups on round start.");
	sm_fortressblast_respawnroomkill = CreateConVar("sm_fortressblast_respawnroomkill", "1", "Disables or enables killing enemies inside spawnrooms due to Mega Mann exploit.");
	sm_fortressblast_ultra_rate = CreateConVar("sm_fortressblast_ultra_rate", "0.1", "Chance out of 100 for ULTRA POWERUP!! to spawn.");

	// HUDs
	PowerupText = CreateHudSynchronizer();
	GiftText = CreateHudSynchronizer();
}

/* OnConfigsExecuted() + InsertServerTag()
==================================================================================================== */

public void OnConfigsExecuted() {
	InsertServerTag("fortressblast");
}

public void InsertServerTag(const char[] insertThisTag) {
	ConVar tags = FindConVar("sv_tags");
	if (tags != null) {
		char serverTags[258];
		// Insert server tag at end
		tags.GetString(serverTags, sizeof(serverTags));
		if (StrContains(serverTags, insertThisTag, true) == -1) {
			Format(serverTags, sizeof(serverTags), "%s,%s", serverTags, insertThisTag);
			tags.SetString(serverTags);
			// If failed, insert server tag at start
			tags.GetString(serverTags, sizeof(serverTags));
			if (StrContains(serverTags, insertThisTag, true) == -1) {
				Format(serverTags, sizeof(serverTags), "%s,%s", insertThisTag, serverTags);
				tags.SetString(serverTags);
			}
		}
	}
}

/* OnMapStart()
==================================================================================================== */

public void OnMapStart() {
	// Reset Gift Hunt progress
	GiftsCollected[2] = 0;
	GiftsCollected[3] = 0;

	// Powerup materials, models and sounds precaching and downloading
	AddFileToDownloadsTable("materials/models/fortressblast/pickups/fb_pickup/pickup_fb.vmt");
	AddFileToDownloadsTable("materials/models/fortressblast/pickups/fb_pickup/pickup_fb.vtf");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.mdl");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.dx80.vtx");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.dx90.vtx");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.phy");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.sw.vtx");
	AddFileToDownloadsTable("models/fortressblast/pickups/fb_pickup.vvd");
	PrecacheSound("fortressblast2/ultrapowerup_pickup.mp3");
	PrecacheSound("fortressblast2/ultrapowerup_use.mp3");
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
	PrecacheSound("fortressblast2/magnetism_pickup.mp3");
	PrecacheSound("fortressblast2/magnetism_use.mp3");
	PrecacheSound("fortressblast2/effectburst_pickup.mp3");
	PrecacheSound("fortressblast2/effectburst_use.mp3");
	PrecacheSound("fortressblast2/dizzybomb_pickup.mp3");
	PrecacheSound("fortressblast2/dizzybomb_use.mp3");
	PrecacheSound("fortressblast2/dizzybomb_dizzy.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/ultrapowerup_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/ultrapowerup_use.mp3");
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
	AddFileToDownloadsTable("sound/fortressblast2/magnetism_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/magnetism_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/effectburst_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/effectburst_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/dizzybomb_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/dizzybomb_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/dizzybomb_dizzy.mp3");

	// Powerup sound precaching for non-custom sounds
	PrecacheSound("items/spawn_item.wav");
	PrecacheSound("physics/flesh/flesh_impact_bullet2.wav");
	PrecacheSound("weapons/cleaver_hit_02.wav");
	PrecacheSound("weapons/jar_explode.wav");

	// Smissmas sound precaching for non-custom sounds
	PrecacheSound("misc/jingle_bells/jingle_bells_nm_01.wav");
	PrecacheSound("misc/jingle_bells/jingle_bells_nm_02.wav");

	// Gift Hunt materials and sounds precaching and downloading
	AddFileToDownloadsTable("materials/sprites/fortressblast/gift_located_here.vmt");
	AddFileToDownloadsTable("materials/sprites/fortressblast/gift_located_here.vtf");
	PrecacheSound("fortressblast2/gifthunt_gift_pickup.mp3");
	PrecacheSound("fortressblast2/gifthunt_goal_enemyteam.mp3");
	PrecacheSound("fortressblast2/gifthunt_goal_playerteam.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/gifthunt_gift_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/gifthunt_goal_enemyteam.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/gifthunt_goal_playerteam.mp3");

	CreateTimer(0.1, Timer_MiscTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE); // Timer to check gifts and calculate Super Speed and Dizzy Bomb progress
}

/* Commands
==================================================================================================== */

public bool AdminCommand(int client) {
	if (!CheckCommandAccess(client, "", AdminFlagInit()) && !sm_fortressblast_debug.BoolValue) {
		CPrintToChat(client, "%s {red}You do not have permission to use this command.", MESSAGE_PREFIX);
		return false;
	}
	return true;
}

public Action Command_FortressBlast(int client, int args) {
	char arg[30];
	GetCmdArg(1, arg, sizeof(arg));
	// Command '!fortressblast force' will print intro message to everyone if user is an admin
	if (StrEqual(arg, "force")) {
		if (AdminCommand(client)) {
			for (int client2 = 1; client2 <= MaxClients; client2++) {
				if (IsClientInGame(client2)) {
					CreateTimer(0.0, Timer_DisplayIntro, client2);
				}
			}
			return Plugin_Handled;
		} else {
			return Plugin_Handled;
		}
	}
	if (client == 0) {
		PrintToServer("%s Because this command uses the MOTD, it cannot be executed from the server console.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}
	int bitfield = sm_fortressblast_powerups.IntValue;
	if (bitfield < 1 && bitfield > ((Bitfieldify(NumberOfPowerups) * 2) - 1)) {
		bitfield = -1;
	}
	char url[200];
	char action[15];
	sm_fortressblast_action.GetString(action, sizeof(action));
	Format(url, sizeof(url), "https://fortress-blast.github.io/%s?powerups-enabled=%d&action=%s&gifthunt=%b&ultra=%f", MOTD_VERSION, bitfield, action, sm_fortressblast_gifthunt.BoolValue, sm_fortressblast_ultra_rate.FloatValue);
	AdvMOTD_ShowMOTDPanel(client, "", url, MOTDPANEL_TYPE_URL, true, true, true, INVALID_FUNCTION);
	CPrintToChat(client, "%s {haunted}Opening Fortress Blast manual... If nothing happened, open your developer console and {yellow}set cl_disablehtmlmotd to 0{haunted}, then try again.", MESSAGE_PREFIX);
	return Plugin_Handled;
}

public Action Command_CoordsJson(int client, int args) {
	if (client == 0) {
		PrintToServer("%s Because this command uses the crosshair, it cannot be executed from the server console.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}
	float points[3];
	GetCollisionPoint(client, points);
	CPrintToChat(client, "{haunted}\"#-x\": \"%d\", \"#-y\": \"%d\", \"#-z\": \"%d\",", RoundFloat(points[0]), RoundFloat(points[1]), RoundFloat(points[2]));
	return Plugin_Handled;
}

public Action Command_RespawnPowerups(int client, int args){
	if (!AdminCommand(client)) {
		return Plugin_Handled;
	}
	RemoveAllPowerups();
	GetSpawns(false);
	return Plugin_Handled;
}

public Action Command_SetPowerup(int client, int args) {
	if (!AdminCommand(client)) {
		return Plugin_Handled;
	}
	char arg[MAX_NAME_LENGTH + 1];
	char arg2[3]; // Need to have a check if there's only one argument, apply to command user
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	// the reason for using fake client commands here is intentional: other plugins that treat things like "all red players as an action"
	// is not the case here, it will be as though you set every player's powerup individually, while allowing @red as a way to save time
	if ((StrEqual(arg, "0") || StringToInt(arg) != 0) && StrEqual(arg2, "")) { // Name of target not included, act on client
		FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client), StringToInt(arg));
		return Plugin_Handled;
	}
	if (StrEqual(arg, "@all")) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2)) {
				FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client2), StringToInt(arg2));
			}
		}
		return Plugin_Handled;
	} else if (StrEqual(arg, "@red")) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2) && GetClientTeam(client2) == 2) {
				FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client2), StringToInt(arg2));
			}
		}
		return Plugin_Handled;
	} else if (StrEqual(arg, "@blue")) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2) && GetClientTeam(client2) == 3) {
				FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client2), StringToInt(arg2));
			}
		}
		return Plugin_Handled;
	} else if (StrEqual(arg, "@bots")) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2) && IsFakeClient(client2)) {
				FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client2), StringToInt(arg2));
			}
		}
		return Plugin_Handled;
	} else if (StrEqual(arg, "@humans")) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2) && !IsFakeClient(client2)) {
				FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client2), StringToInt(arg2));
			}
		}
		return Plugin_Handled;
	}
	int player = FindTarget(client, arg, false, false);
	PowerupID[player] = StringToInt(arg2);
	CollectedPowerup(player);
	DebugText("%N set %N's powerup to ID %d", client, player, StringToInt(arg2));
	return Plugin_Handled;
}

public Action Command_SpawnPowerup(int client, int args) {
	if (!AdminCommand(client)) {
		return Plugin_Handled;
	}
	if (client == 0) {
		PrintToServer("%s Because this command uses the crosshair, it cannot be executed from the server console.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}
	float points[3];
	GetCollisionPoint(client, points);
	char arg1[3];
	GetCmdArg(1, arg1, sizeof(arg1));
	SpawnPowerup(points, false, StringToInt(arg1));
	return Plugin_Handled;
}

/* Command dependencies
==================================================================================================== */

stock void GetCollisionPoint(int client, float pos[3]) {
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

public bool TraceEntityFilterPlayer(int entity, int contentsMask) {
	return entity > MaxClients;
}

/* Powerups, Gifts and Respawn Room initialisation
==================================================================================================== */

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	char map[80];
	GetCurrentMap(map, sizeof(map));
	char path[PLATFORM_MAX_PATH + 1];
	// So we dont overload read-writes
	Format(path, sizeof(path), "scripts/fortress_blast/powerup_spawns/%s.json", map);
	MapHasJsonFile = FileExists(path);
	if (sm_fortressblast_gifthunt.BoolValue) {
		Format(path, sizeof(path), "scripts/fortress_blast/gift_spawns/%s.json", map);
		GiftHunt = FileExists(path);
		if (GiftHunt) {
			GiftMultiplier[2] = 1;
			GiftMultiplier[3] = 1;
			JSONObject handle = JSONObject.FromFile(path);
			if (handle.HasKey("mode")) { // For single-team objective maps like Attack/Defense and Payload
				char mode[30];
				handle.GetString("mode", mode, sizeof(mode));
				GiftHuntAttackDefense = StrEqual(mode, "attackdefense", true);
			}
			GiftHuntNeutralFlag = false;
			int flag;
			while ((flag = FindEntityByClassname(flag, "item_teamflag")) != -1) {
				if (GetEntProp(flag, Prop_Send, "m_iTeamNum") == 0) {
					GiftHuntNeutralFlag = true;
					AcceptEntityInput(flag, "Disable");
				}
			}
		}
	} else {
		GiftHunt = false;
	}
	if (GiftHuntAttackDefense) {
		GiftHuntSetup = true;
	}
	VictoryTeam = -1;
	// Gift Hunt map logic changes
	if (GiftHunt) {
		InsertServerTag("gifthunt");
		// Disable capturing control points
		EntFire("trigger_capture_area", "SetTeamCanCap", "2 0");
		EntFire("trigger_capture_area", "SetTeamCanCap", "3 0");
		// Disable collecting intelligences
		int flag;
		while ((flag = FindEntityByClassname(flag, "item_teamflag")) != -1) {
			DispatchKeyValue(flag, "VisibleWhenDisabled", "1");
			AcceptEntityInput(flag, "Disable");
		}
		// Disable Arena and King of the Hill control point cooldown
		if (FindEntityByClassname(1, "tf_logic_arena") != -1) {
			DispatchKeyValue(FindEntityByClassname(1, "tf_logic_arena"), "CapEnableDelay", "0");
		} else if (FindEntityByClassname(1, "tf_logic_koth") != -1) {
			DispatchKeyValue(FindEntityByClassname(1, "tf_logic_koth"), "timer_length", "0");
			DispatchKeyValue(FindEntityByClassname(1, "tf_logic_koth"), "unlock_point", "0");
		}
	}
	PlayersAmount = 0;
	if (!GameRules_GetProp("m_bInWaitingForPlayers")) {
		for (int client = 1; client <= MaxClients; client++) {
			PowerupID[client] = 0;
			if (IsClientInGame(client)) {
				// Only count bots if ConVar is true
				if (!IsFakeClient(client) || sm_fortressblast_gifthunt_countbots.BoolValue) {
					PlayersAmount++;
				}
				if (sm_fortressblast_intro.BoolValue) {
					CreateTimer(3.0, Timer_DisplayIntro, client);
				}
				// Remove powerup effects on round start
				SetEntityGravity(client, 1.0);
				UsingPowerup[1][client] = false;
				UsingPowerup[2][client] = false;
				UsingPowerup[6][client] = false;
				SpeedRotationsLeft[client] = 0;
				SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
			}
		}
	}
	CalculateGiftGoal();
	RemoveAllPowerups();
	for (int entity = 1; entity <= MAX_EDICTS; entity++) { // Add powerups and replace Mannpower
		if (IsValidEntity(entity)) {
			char classname[60];
			GetEntityClassname(entity, classname, sizeof(classname));
			if (FindEntityByClassname(0, "tf_logic_mannpower") != -1 && sm_fortressblast_mannpower.IntValue != 0) {
				if ((!MapHasJsonFile || sm_fortressblast_mannpower.IntValue == 2)) {
					if (StrEqual(classname, "item_powerup_rune") || StrEqual(classname, "item_powerup_crit") || StrEqual(classname, "item_powerup_uber") || StrEqual(classname, "info_powerup_spawn")) {
						if (StrEqual(classname, "info_powerup_spawn")) {
							float coords[3] = 69.420;
							GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
							DebugText("Found Mannpower spawn at %f, %f, %f", coords[0], coords[1], coords[2]);
							SpawnPowerup(coords, true);
						}
						DebugText("Removing entity name %s", classname);
						RemoveEntity(entity);
					}
				}
			}
		}
	}
	if (sm_fortressblast_powerups_roundstart.BoolValue) {
		GetSpawns(false);
	}
	GiftsCollected[2] = 0;
	GiftsCollected[3] = 0;
	int spawnrooms;
	while ((spawnrooms = FindEntityByClassname(spawnrooms, "func_respawnroom")) != -1) {
		SDKHook(spawnrooms, SDKHook_TouchPost, OnTouchRespawnRoom);
	}
}

public void GetSpawns(bool UsingGiftHunt) {
	if (!UsingGiftHunt && !MapHasJsonFile) {
		PrintToServer("%s No powerup locations .json file for this map! You can download pre-made files from the official maps repository:", MESSAGE_PREFIX_NO_COLOR);
		PrintToServer("https://github.com/Fortress-Blast/Fortress-Blast-Maps");
		return;
	} else if (UsingGiftHunt && !GiftHunt) {
		return;
	}
	// Get symmetry specifications from locations .json
	char map[80];
	GetCurrentMap(map, sizeof(map));
	char path[PLATFORM_MAX_PATH + 1];
	if (!UsingGiftHunt) {
		Format(path, sizeof(path), "scripts/fortress_blast/powerup_spawns/%s.json", map);
		GlobalVerifier = GetRandomInt(1, 999999999); // Large integer used to avoid duplicate powerups where possible
	} else {
		Format(path, sizeof(path), "scripts/fortress_blast/gift_spawns/%s.json", map);
	}
	JSONObject handle = JSONObject.FromFile(path);
	bool flipx = false;
	bool flipy = false;
	float centerx = 0.0;
	float centery = 0.0;
	char cent[80];
	if (handle.HasKey("flipx")) {
		flipx = handle.GetBool("flipx");
	}
	if (handle.HasKey("flipy")) {
		flipy = handle.GetBool("flipy");
	}
	if (flipx || flipy) {
		if (handle.HasKey("centerx")) {
			handle.GetString("centerx", cent, sizeof(cent));
			centerx = StringToFloat(cent);
		}
		if (handle.HasKey("centery")) {
			handle.GetString("centery", cent, sizeof(cent));
			centery = StringToFloat(cent);
		}
	}
	// Iterate through .json file to get coordinates
	int itemloop = 1;
	char stringamount[80];
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
			} else if (to == 1) {
				StrCat(query, sizeof(query), "y");
			} else if (to == 2) {
				StrCat(query, sizeof(query), "z");
			}
			if (handle.HasKey(query)) {
				handle.GetString(query, string, sizeof(string));
				coords[to] = StringToFloat(string);
			} else {
				spcontinue = false;
			}
		}
		if (coords[0] != 0.001) {
			if (UsingGiftHunt && (GetRandomInt(0, 99) >= sm_fortressblast_gifthunt_rate.IntValue)) {
				DebugText("Not spawning gift %d because it failed random", itemloop);
			} else {
				if (UsingGiftHunt) {
					coords[2] += 8.0;
					DebugText("Spawning gift %d at %f, %f, %f", itemloop, coords[0], coords[1], coords[2]);
					SpawnGift(coords);
				} else {
					DebugText("Spawning powerup %d at %f, %f, %f", itemloop, coords[0], coords[1], coords[2]);
					SpawnPowerup(coords, true);
				}
				if (flipx && flipy) {
					if (coords[0] != centerx || coords[1] != centery) {
						coords[0] = coords[0] - ((coords[0] - centerx) * 2);
						coords[1] = coords[1] - ((coords[1] - centery) * 2);
						DebugText("Flipping both axes, new entity created at %f, %f, %f", coords[0], coords[1], coords[2]);
						if (UsingGiftHunt) {
							SpawnGift(coords);
						} else {
							SpawnPowerup(coords, true);
						}
					} else {
						DebugText("Entity is at the center and will not be flipped");
   	 				}
				} else if (flipx) {
					if (coords[0] != centerx) {
						coords[0] = coords[0] - ((coords[0] - centerx) * 2);
						DebugText("Flipping X axis, new entity created at %f, %f, %f", coords[0], coords[1], coords[2]);
						if (UsingGiftHunt) {
							SpawnGift(coords);
						} else {
							SpawnPowerup(coords, true);
						}
					} else {
						DebugText("Entity is at the X axis center and will not be flipped");
    				}
				} else if (flipy) {
					if (coords[1] != centery) {
						coords[1] = coords[1] - ((coords[1] - centery) * 2);
						DebugText("Flipping Y axis, new entity created at %f, %f, %f", coords[0], coords[1], coords[2]);
						if (UsingGiftHunt) {
							SpawnGift(coords);
						} else {
							SpawnPowerup(coords, true);
						}
					} else {
						DebugText("Entity is at the Y axis center and will not be flipped");
					}
				}
			}
			itemloop++;
			IntToString(itemloop, stringamount, sizeof(stringamount));
		}
	}
	return;
}

public void RemoveAllPowerups() {
	int entity;
	while ((entity = FindEntityByClassname(entity, "tf_halloween_pickup")) != -1) {
		RemoveEntity(entity);
	}
}

public void CalculateGiftGoal() {
	GiftGoal = sm_fortressblast_gifthunt_goal.IntValue;
	DebugText("Base gift goal is %d", GiftGoal);
	int steps = RoundToFloor((PlayersAmount - 1) / sm_fortressblast_gifthunt_players.FloatValue);
	if (steps < 0) {
		steps = 0;
	}
	GiftGoal += (sm_fortressblast_gifthunt_increment.IntValue * steps);
	DebugText("Calculated gift goal is %d", GiftGoal);
}

public Action Event_SetupFinished(Event event, const char[] name, bool dontBroadcast) {
	if (GiftHuntAttackDefense) {
		GiftHuntSetup = false;
		EntFire("team_round_timer", "Pause");
	}
}

/* OnEntityDestroyed()
==================================================================================================== */

public void OnEntityDestroyed(int entity) {
	if (IsValidEntity(entity) && entity > 0) {
		ClearTimer(DestroyPowerupHandle[entity]); // This causes about half a second of lag when a new round starts. but not having it causes problems
		char classname[60];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "tf_halloween_pickup") && PowerupID[entity] == 0) { // This is just an optimizer, the same thing would happen without this but slower
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

/* Timer_MiscTimer() + NumberOfActiveGifts()
Handles multiple plugin features including Gift Hunt, Super Speed and Dizzy Bomb
==================================================================================================== */

public Action Timer_MiscTimer(Handle timer, any data) {
	if (GiftHunt) {
		if (NumberOfActiveGifts() == 0 && !GiftHuntSetup && (GiftsCollected[2] < GiftGoal || GiftsCollected[3] < GiftGoal)) {
			GetSpawns(true);
		}
		if (GiftHuntIncrementTime < GetGameTime() && (GiftsCollected[2] >= GiftGoal || GiftsCollected[3] >= GiftGoal) && sm_fortressblast_gifthunt_bonus.BoolValue) {
			if (GiftsCollected[3] < GiftGoal && GiftMultiplier[3] < 5) {
				GiftMultiplier[3]++;
				PrintCenterTextAll("Catchup bonus: Gifts are now worth x%d for BLU team.", GiftMultiplier[3]);
			} else if (GiftsCollected[2] < GiftGoal && GiftMultiplier[2] < 5) {
				GiftMultiplier[2]++;
				PrintCenterTextAll("Catchup bonus: Gifts are now worth x%d for RED team.", GiftMultiplier[2]);
			}
			DebugText("Incremenet time is %f , game time is %f", GiftHuntIncrementTime, GetGameTime());
			GiftHuntIncrementTime = GetGameTime() + 60.0;
		}
	}
	for (int client = 1 ; client <= MaxClients ; client++ ) {
		if (IsClientInGame(client)) {
			if (SpeedRotationsLeft[client] > 0) {
				if (IsPlayerAlive(client)) {
					if (GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") != SuperSpeed[client]) { // If TF2 changed the speed
						OldSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
					}
					SuperSpeed[client] = OldSpeed[client] + (SpeedRotationsLeft[client] * 2);
					SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", SuperSpeed[client]);
				}
			}
			SpeedRotationsLeft[client]--;
			if (DizzyProgress[client] <= (10 * sm_fortressblast_dizzy_length.FloatValue) && DizzyProgress[client] != -1) {
				float angles[3];
				GetClientAbsAngles(client, angles);
				if (!TF2_IsPlayerInCondition(client, TFCond_Taunting)) {
					float ang = Sine((3.16159265 * sm_fortressblast_dizzy_states.FloatValue * DizzyProgress[client]) / (10 * sm_fortressblast_dizzy_length.FloatValue)) * ((10 * sm_fortressblast_dizzy_length.FloatValue) - DizzyProgress[client]);
					if (NegativeDizzy[client]) {
						angles[2] = (ang * -1);
					} else {
						angles[2] = ang;
					}
					DebugText("Dizzy Bomb angle is %f at step %d", angles[2], DizzyProgress[client]);
				} else {
					angles[2] = 0.0;
				}
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
				DizzyProgress[client] += 1;
			}
		}
	}
}

public int NumberOfActiveGifts() {
	int totalgifts;
	int entity;
	while ((entity = FindEntityByClassname(entity, "tf_halloween_pickup")) != -1) {
		if (PowerupID[entity] == 0) {
			totalgifts++;
		}
	}
	return totalgifts;
}

/* Timer_DisplayIntro()
==================================================================================================== */

public Action Timer_DisplayIntro(Handle timer, int client) {
	if (IsClientInGame(client)) { // Required because player might disconnect before this fires
		CPrintToChat(client, "%s {haunted}This server is running %s {yellow}v%s!", MESSAGE_PREFIX, NationalColors(), PLUGIN_VERSION);
		CPrintToChat(client, "{haunted}If you would like to know more or are unsure what a powerup does, type the command {yellow}!fortressblast {haunted}into chat.");
	}
}

stock char NationalColors(){
	char intro[500];
	// order these so that the last one is highest priority
	intro = "{yellow}Fortress Blast";
	if(Smissmas()){
		intro = "{salmon}F{limegreen}o{salmon}r{limegreen}t{salmon}r{limegreen}e{salmon}s{limegreen}s {salmon}B{limegreen}l{salmon}a{limegreen}s{salmon}t";
	}
	if(AprilFools()){
		intro = "{immortal}F{burlywood}o{crimson}r{lawngreen}t{lightgoldenrodyellow}r{fuchsia}e{mediumaquamarine}s{darkgoldenrod}s {sienna}B{mediumorchid}l{darkkhaki}a{thistle}s{fullred}t";
	}
	return intro;
}

/* Events
==================================================================================================== */

public Action Event_RoundWin(Event event, const char[] name, bool dontBroadcast) {
	VictoryTeam = event.GetInt("team");
	DebugText("Team #%d has won the round", event.GetInt("team"));
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	PowerupID[GetClientOfUserId(event.GetInt("userid"))] = 0;
	// Is dropping powerups enabled
	if (sm_fortressblast_drop.IntValue == 2 || (sm_fortressblast_drop.BoolValue && !MapHasJsonFile)) {
		// Get chance a powerup will be dropped
		float convar = sm_fortressblast_drop_rate.FloatValue;
		float randomNumber = GetRandomFloat(0.0, 99.99);
		if (convar > randomNumber && (sm_fortressblast_drop_teams.IntValue == GetClientTeam(GetClientOfUserId(event.GetInt("userid"))) || sm_fortressblast_drop_teams.IntValue == 1)) {
			DebugText("Dropping powerup due to player death");
			float coords[3];
			GetEntPropVector(GetClientOfUserId(event.GetInt("userid")), Prop_Send, "m_vecOrigin", coords);
			int entity = SpawnPowerup(coords, false);
			ClearTimer(DestroyPowerupHandle[entity]);
			DestroyPowerupHandle[entity] = CreateTimer(15.0, Timer_DestroyPowerupTime, entity);
		}
	}
}

public Action Timer_DestroyPowerupTime(Handle timer, int entity) {
	DestroyPowerupHandle[entity] = INVALID_HANDLE;
	RemoveEntity(entity);
}

public void OnClientPutInServer(int client) {
	PowerupID[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	SDKHook(client, SDKHook_StartTouch, OnStartTouchFrozen);
	CreateTimer(3.0, Timer_DisplayIntro, client);
	DizzyProgress[client] = -1;
}

/* SpawnPowerup() + SpawnGift()
==================================================================================================== */

stock int SpawnPowerup(float location[3], bool respawn, int id = 0) {
	int entity = CreateEntityByName("tf_halloween_pickup");
	DispatchKeyValue(entity, "powerup_model", "models/fortressblast/pickups/fb_pickup.mdl");
	if (IsValidEdict(entity)) {
		if (id == 0) {
			if (sm_fortressblast_ultra_rate.FloatValue > GetRandomFloat(0.0, 99.99)) {
				PowerupID[entity] = -1;
			} else {
				PowerupID[entity] = GetRandomInt(1, NumberOfPowerups);
				while (!PowerupIsEnabled(PowerupID[entity])) {
					PowerupID[entity] = GetRandomInt(1, NumberOfPowerups);
				}
			}
		} else {
			PowerupID[entity] = id;
		}
		// No colour setting required for Ultra Powerup, default is white
		if (PowerupID[entity] == 1) {
			SetEntityRenderColor(entity, 85, 102, 255, 255);
		} else if (PowerupID[entity] == 2) {
			SetEntityRenderColor(entity, 255, 0, 0, 255);
		} else if (PowerupID[entity] == 3) {
			SetEntityRenderColor(entity, 255, 119, 17, 255);
		} else if (PowerupID[entity] == 4) {
			SetEntityRenderColor(entity, 255, 85, 119, 255);
		} else if (PowerupID[entity] == 5) {
			SetEntityRenderColor(entity, 0, 204, 0, 255);
		} else if (PowerupID[entity] == 6) {
			SetEntityRenderColor(entity, 136, 255, 170, 255);
		} else if (PowerupID[entity] == 7) {
			SetEntityRenderColor(entity, 255, 255, 0, 255);
		} else if (PowerupID[entity] == 8) {
			SetEntityRenderColor(entity, 85, 85, 85, 255);
		} else if (PowerupID[entity] == 9) {
			SetEntityRenderColor(entity, 255, 187, 255, 255);
		} else if (PowerupID[entity] == 10) {
			SetEntityRenderColor(entity, 0, 0, 0, 255);
		} else if (PowerupID[entity] == 11) {
			SetEntityRenderColor(entity, 255, 153, 153, 255);
		} else if (PowerupID[entity] == 12) {
			SetEntityRenderColor(entity, 0, 68, 0, 255);
		} else if (PowerupID[entity] == 13) {
			SetEntityRenderColor(entity, 218, 182, 72, 255);
		} else if (PowerupID[entity] == 14) {
			SetEntityRenderColor(entity, 36, 255, 255, 255);
		}
		DispatchKeyValue(entity, "pickup_sound", " ");
		DispatchKeyValue(entity, "pickup_particle", " ");
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

public int SpawnGift(float location[3]) {
	GiftHunt = true;
	int entity = CreateEntityByName("tf_halloween_pickup");
	if (IsValidEntity(entity)) {
		DispatchKeyValue(entity, "powerup_model", "models/items/tf_gift.mdl");
		DispatchKeyValue(entity, "pickup_sound", " ");
		DispatchKeyValue(entity, "pickup_particle", " ");
		char giftidsandstuff[20];
		Format(giftidsandstuff, sizeof(giftidsandstuff), "fb_giftid_%d", entity);
		DispatchKeyValue(entity, "targetname", giftidsandstuff);
		AcceptEntityInput(entity, "EnableCollision");
		DispatchSpawn(entity);
		ActivateEntity(entity);
		TeleportEntity(entity, location, NULL_VECTOR, NULL_VECTOR);
		SDKHook(entity, SDKHook_StartTouch, OnStartTouchDontRespawn);
		PowerupID[entity] = 0;
		int entity2 = CreateEntityByName("env_sprite");
		if (IsValidEntity(entity2)) {
			DispatchKeyValue(entity2, "model", "sprites/fortressblast/gift_located_here.vmt");
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

/* Enabled Powerups
==================================================================================================== */

public bool PowerupIsEnabled(int id) {
	int max = (Bitfieldify(NumberOfPowerups) * 2) - 1;
	int bitfield = sm_fortressblast_powerups.IntValue;
	if (bitfield == -1) {
		return true; // All powerups enabled
	} else if (bitfield < 1 || bitfield > max) {
		PrintToServer("%s Your powerup whitelist ConVar is out of range. As a fallback, all powerups are allowed.", MESSAGE_PREFIX_NO_COLOR);
		return true;
	} else if (bitfield == 512) {
		PrintToServer("%s Your powerup whitelist ConVar is set to Mystery only. Mystery requires at least one other powerup to work and cannot be used on its own. As a fallback, all powerups are allowed.", MESSAGE_PREFIX_NO_COLOR);
		return true;
	} else if (bitfield & Bitfieldify(id)) {
		return true; // return bitfield & Bitfieldify(id) doesn't work
	}
	return false;
}

public int Bitfieldify(int bitter) {
	int num = 1;
	for (int id = 1; id <= bitter ; id++) {
		num = num * 2;
	}
	return (num / 2);
}

/* CollectedPowerup() + Timer_BotUsePowerup()
==================================================================================================== */

public void CollectedPowerup(int client) {
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (PowerupID[client] == -1) {
		EmitSoundToClient(client, "fortressblast2/ultrapowerup_pickup.mp3", client);
	} else if (PowerupID[client] == 1) {
		EmitSoundToClient(client, "fortressblast2/superbounce_pickup.mp3", client);
	} else if (PowerupID[client] == 2) {
		EmitSoundToClient(client, "fortressblast2/shockabsorber_pickup.mp3", client);
	} else if (PowerupID[client] == 3) {
		EmitSoundToClient(client, "fortressblast2/superspeed_pickup.mp3", client);
	} else if (PowerupID[client] == 4) {
		EmitSoundToClient(client, "fortressblast2/superjump_pickup.mp3", client);
	} else if (PowerupID[client] == 5) {
		EmitSoundToClient(client, "fortressblast2/gyrocopter_pickup.mp3", client);
	} else if (PowerupID[client] == 6) {
		EmitSoundToClient(client, "fortressblast2/timetravel_pickup.mp3", client);
	} else if (PowerupID[client] == 7) {
		EmitSoundToClient(client, "fortressblast2/blast_pickup.mp3", client);
	} else if (PowerupID[client] == 8) {
		EmitSoundToClient(client, "fortressblast2/megamann_pickup.mp3", client);
	} else if (PowerupID[client] == 9) {
		EmitSoundToClient(client, "fortressblast2/frosttouch_pickup.mp3", client);
	} else if (PowerupID[client] == 10) {
		EmitSoundToClient(client, "fortressblast2/mystery_pickup.mp3", client);
	} else if (PowerupID[client] == 11) {
		EmitSoundToClient(client, "fortressblast2/teleportation_pickup.mp3", client);
	} else if (PowerupID[client] == 12) {
		EmitSoundToClient(client, "fortressblast2/magnetism_pickup.mp3", client);
	} else if (PowerupID[client] == 13) {
		EmitSoundToClient(client, "fortressblast2/effectburst_pickup.mp3", client);
	} else if (PowerupID[client] == 14) {
		EmitSoundToClient(client, "fortressblast2/dizzybomb_pickup.mp3", client);
	}
	// If player is a bot and bot support is enabled
	if (IsFakeClient(client) && sm_fortressblast_bot.BoolValue && !BlockPowerup(client)) {
		// Get minimum and maximum times
		float convar1 = sm_fortressblast_bot_min.FloatValue;
		if (convar1 < 0) {
			convar1 == 0;
		}
		float convar2 = sm_fortressblast_bot_max.FloatValue;
		if (convar2 < convar1) {
			convar2 == convar1;
		}
		// Get bot to use powerup within the random period
		CreateTimer(GetRandomFloat(convar1, convar2), Timer_BotUsePowerup, client);
	}
}

public Action Timer_BotUsePowerup(Handle timer, int client) {
	if (IsClientInGame(client)) {
		DebugText("Forcing bot %N to use powerup ID %d", client, PowerupID[client]);
		UsePowerup(client);
	}
}

/* CollectedGift()
==================================================================================================== */

public void CollectedGift(int client) {
	int flag;
	DebugText("%N has collected a gift", client);
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	EmitAmbientSound("fortressblast2/gifthunt_gift_pickup.mp3", vel, client);
	int team = GetClientTeam(client);
	GiftsCollected[team] = GiftsCollected[team] + GiftMultiplier[team];
	// A team has reached the gift goal
	if (GiftsCollected[team] >= GiftGoal && GiftsCollected[team] < (GiftGoal + GiftMultiplier[team])) {
		GiftHuntIncrementTime = GetGameTime() + 60.0;
		if (team == 2) {
			GiftMultiplier[2] = 1;
			PrintCenterTextAll("RED team has collected the required number of gifts!");
			DebugText("RED team has collected the required number of gifts", client);
			flag = 0;
			EntFire("trigger_capture_area", "SetTeamCanCap", "2 1"); // Allow capturing control points
			// Allow collecting enemy intelligences
			while ((flag = FindEntityByClassname(flag, "item_teamflag")) != -1) {
				if (GetEntProp(flag, Prop_Send, "m_iTeamNum") == 3) {
					AcceptEntityInput(flag, "Enable");
				}
			}
			if (GiftHuntAttackDefense) {
				EntFire("team_round_timer", "Resume");
			}
		} else if (team == 3) {
			GiftMultiplier[3] = 1;
			PrintCenterTextAll("BLU team has collected the required number of gifts!");
			DebugText("BLU team has collected the required number of gifts", client);
			flag = 0;
			EntFire("trigger_capture_area", "SetTeamCanCap", "3 1"); // Allow capturing control points
			// Allow collecting enemy intelligences
			while ((flag = FindEntityByClassname(flag, "item_teamflag")) != -1) {
				if (GetEntProp(flag, Prop_Send, "m_iTeamNum") == 2) {
					AcceptEntityInput(flag, "Enable");
				}
			}
		}
		for (int client2 = 1 ; client2 <= MaxClients ; client2++) {
			if (IsClientInGame(client2)) {
				if (GetClientTeam(client2) == team) {
					EmitSoundToClient(client2, "fortressblast2/gifthunt_goal_playerteam.mp3", client2);
				} else {
					EmitSoundToClient(client2, "fortressblast2/gifthunt_goal_enemyteam.mp3", client2);
				}
			}
		}
	}
}

/* OnPlayerRunCmd() + BlockPowerup()
==================================================================================================== */

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float ang[3], int &weapon) {
	float coords[3] = 0.0; // Placeholder value
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
	if (UsingPowerup[6][client]) {
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 520.0);
	}
	if (buttons & 33554432 && (!PreviousAttack3[client]) && ActionInit() != 33554432) {
		char button[40];
		sm_fortressblast_action.GetString(button, sizeof(button));
		CPrintToChat(client, "%s {red}Special attack is currently disabled on this server. You are required to {yellow}perform the '%s' action to use a powerup.", MESSAGE_PREFIX, button);
	} else if (buttons & ActionInit() && !BlockPowerup(client)) {
		UsePowerup(client);
	}
	float vel2[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel2);
	if (GetEntityFlags(client) & FL_ONGROUND) {
		if (VerticalVelocity[client] != 0.0 && UsingPowerup[1][client] && VerticalVelocity[client] < -250.0) {
			vel2[2] = (VerticalVelocity[client] * -1);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel2);
			DebugText("Setting %N's vertical velocity to %f", client, vel2[2]);
		}
	}
	DoHudText(client);
	VerticalVelocity[client] = vel2[2];

	for (int partid = MAX_PARTICLES; partid > 0 ; partid--) {
		if (PlayerParticle[client][partid] == 0) {
			PlayerParticle[client][partid] = -1; // Unsure of this line's purpose
		}
		if (IsValidEntity(PlayerParticle[client][partid])) {
			float particlecoords[3];
			GetClientAbsOrigin(client, particlecoords);
			particlecoords[2] += ParticleZAdjust[client][partid];
			TeleportEntity(PlayerParticle[client][partid], particlecoords, NULL_VECTOR, NULL_VECTOR);
			if (!IsPlayerAlive(client)) {
				Handle partkv = CreateKeyValues("partkv");
				KvSetNum(partkv, "client", client);
				KvSetNum(partkv, "id", partid);
				CreateTimer(0.0, Timer_RemoveParticle, partkv);
			}
		}
	}
	PreviousAttack3[client] = (buttons > 33554431);
	// Cover bases not covered by regular blocking
	if (UsingPowerup[6][client] || FrostTouchFrozen[client]) {
		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
	}
	if (IsValidEntity(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))) {
		if (GetEntProp(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), Prop_Send, "m_iItemDefinitionIndex") == 28 && !MegaMannVerified[client] && UsingPowerup[8][client]) {
			buttons &= ~IN_ATTACK;
		}
	}
	if ((UsingPowerup[12][client] || UltraPowerup[client]) && IsPlayerAlive(client)) {
		float pos1[3];
		GetClientAbsOrigin(client, pos1);
		for (int client2 = 1 ; client2 <= MaxClients ; client2++ ) {
			if (IsClientInGame(client2) && TF2_GetClientTeam(client2) != TF2_GetClientTeam(client) && IsPlayerAlive(client2)) {
				float pos2[3];
				GetClientAbsOrigin(client2, pos2);
				float distanceScale = (1024 - GetVectorDistance(pos1, pos2)) / 1024;
				if (distanceScale > 0) {
					SetEntPropEnt(client2, Prop_Data, "m_hGroundEntity", -1);
					float direction[3];
					SubtractVectors(pos1, pos2, direction);
					NormalizeVector(direction, direction);
					float playerVel[3];
					GetEntPropVector(client2, Prop_Data, "m_vecVelocity", playerVel);
					NegateVector(direction);
					float multiplier = Pow(distanceScale * 4, 2.0);
					// Polarities are reversed during April Fools
					if ((GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") != GetPlayerWeaponSlot(client, 2) && !AprilFools()) || (GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") == GetPlayerWeaponSlot(client, 2) && AprilFools())) {
						multiplier = multiplier * -1.25;
					}
					direction[0] = direction[0] * multiplier;
					direction[1] = direction[1] * multiplier;
					SubtractVectors(playerVel, direction, direction);
					TeleportEntity(client2, NULL_VECTOR, NULL_VECTOR, direction);
				}
			}
		}
	}
}

public bool BlockPowerup(int client) {
	// Player is dead
	if (!IsPlayerAlive(client)) {
		return true;
	// Player is frozen
	} else if (FrostTouchFrozen[client] != 0) {
		return true;
	// Player is in a kart or is taunting
	} else if (TF2_IsPlayerInCondition(client, TFCond_HalloweenKart) || TF2_IsPlayerInCondition(client, TFCond_Taunting)) {
		return true;
	// Player lost or is in a stalemate
	} else if ((VictoryTeam != -1 && VictoryTeam != GetClientTeam(client))) {
		return true;
	// Mega Mann pre-stuck checking
	} else if (PowerupID[client] == 8 && !UsingPowerup[8][client]) {
		SetVariantString("1.75 0");
		AcceptEntityInput(client, "SetModelScale");
		float coords[3] = 69.420;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
		coords[2] += 16.0;
		TeleportEntity(client, coords, NULL_VECTOR, NULL_VECTOR);
		bool stuck = IsEntityStuck(client);
		coords[2] -= 16.0;
		TeleportEntity(client, coords, NULL_VECTOR, NULL_VECTOR);
		SetVariantString("1 0");
		AcceptEntityInput(client, "SetModelScale");
		if (stuck) {
			return true;
		}
	}
	return false;
}

/* UsePowerup()
==================================================================================================== */

public void UsePowerup(int client) {
	UsingPowerup[PowerupID[client]][client] = true; // double array :)
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (PowerupID[client] == -1) {
		// Ultra Powerup - Multiple effects
		ClearTimer(MegaMannHandle[client]);
		UltraPowerup[client] = true;
		UltraPowerupHandle[client] = CreateTimer(10.0, Timer_RemoveUltraPowerup, client);
		// Super Bounce, Super Jump, Gyrocopter, Time Travel, Blast, Mystery, Teleportation, Effect Burst and Dizzy Bomb are not included
		// Shock Absorber already set
		SpeedRotationsLeft[client] = 100; // Super Speed, for 10 seconds, slightly faster
		// Mega Mann, health only
		int healthMultiplier = 4;
		if (GetPlayerMaxHealth(client) >= 300) {
			// User is assumed to be a Heavy, reduce health gained to 3x
			healthMultiplier = 3;
		}
		SetEntityHealth(client, (GetClientHealth(client) * healthMultiplier)); // Multiply current health
		// Cap at expected multiplied maximum health
		if (GetClientHealth(client) > (GetPlayerMaxHealth(client) * healthMultiplier)) {
			SetEntityHealth(client, GetPlayerMaxHealth(client) * healthMultiplier);
		}
		// Frost Touch already set, no victim damage resistance
		// Magnetism already set
		TF2_AddCondition(client, TFCond_CritOnFlagCapture, 10.0); // Critical hits
		EmitAmbientSound("fortressblast2/ultrapowerup_use.mp3", vel, client);
		// Spam of Vaccinator particles
		float timeport = 0.1;
		ParticleOnPlayer(client, "medic_resist_bullet", 0.2, 0.0);
		for (int timepoint = 0 ; timepoint <= 50 ; timepoint++) {
			CreateTimer(timeport, UltraParticleRepeaterFire, client);
			CreateTimer((timeport + 0.1), UltraParticleRepeaterBullet, client);
			timeport = timeport + 0.2;
		}
	} else if (PowerupID[client] == 1) {
		// Super Bounce - Uncontrollable bunny hop and fall damage resistance for 5 seconds
		EmitAmbientSound("fortressblast2/superbounce_use.mp3", vel, client);
		VerticalVelocity[client] = 0.0; // Cancel previously stored vertical velocity
		ClearTimer(SuperBounceHandle[client]);
		SuperBounceHandle[client] = CreateTimer(5.0, Timer_RemoveSuperBounce, client);
		ParticleOnPlayer(client, "teleporter_blue_charged_level2", 5.0, 0.0);
		if (AprilFools()) {
			// Increase gravity during April Fools
			if (!UsingPowerup[5][client]) {
				SetEntityGravity(client, 3.0);
			} else {
				SetEntityGravity(client, 0.75); // Gyrocopter
			}
		}
	} else if (PowerupID[client] == 2) {
		// Shock Absorber - 75% damage and 100% knockback resistances for 5 seconds
		EmitAmbientSound("fortressblast2/shockabsorber_use.mp3", vel, client);
		ClearTimer(ShockAbsorberHandle[client]);
		ShockAbsorberHandle[client] = CreateTimer(5.0, Timer_RemoveShockAbsorb, client);
		ParticleOnPlayer(client, "teleporter_red_charged_level2", 5.0, 0.0);
	} else if (PowerupID[client] == 3) {
		// Super Speed - Increased speed, gradually wears off over 10 seconds
		OldSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
		SpeedRotationsLeft[client] = 80;
		EmitAmbientSound("fortressblast2/superspeed_use.mp3", vel, client);
	} else if (PowerupID[client] == 4) {
		// Super Jump - Launch user into air
		if (UsingPowerup[8][client]) {
			vel[2] += 600.0; // Slightly reduced height due to Mega Mann
		} else {
			vel[2] += 800.0;
		}
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
		EmitAmbientSound("fortressblast2/superjump_use.mp3", vel, client);
	} else if (PowerupID[client] == 5) {
		// Gyrocopter - 25% gravity for 5 seconds
		if (UsingPowerup[1][client] && AprilFools()) {
			SetEntityGravity(client, 0.75);
		} else {
			SetEntityGravity(client, 0.25);
		}
		ClearTimer(GyrocopterHandle[client]);
		GyrocopterHandle[client] = CreateTimer(5.0, Timer_RemoveGyrocopter, client);
		EmitAmbientSound("fortressblast2/gyrocopter_use.mp3", vel, client);
	} else if (PowerupID[client] == 6) {
		// Time Travel - Increased speed, invisibility and can't attack for 5 seconds
		SetThirdPerson(client, true);
		TF2_AddCondition(client, TFCond_StealthedUserBuffFade, 3.0);
		BlockAttacking(client, 3.0);
		ClearTimer(TimeTravelHandle[client]);
		TimeTravelHandle[client] = CreateTimer(3.0, Timer_RemoveTimeTravel, client);
		EmitAmbientSound("fortressblast2/timetravel_use_3sec.mp3", vel, client);
	} else if (PowerupID[client] == 7) {
		// Blast - Create explosion at user
		ParticleOnPlayer(client, "rd_robot_explosion", 1.0, 0.0);
		EmitAmbientSound("fortressblast2/blast_use.mp3", vel, client);
		if (Smissmas()) {
			ParticleOnPlayer(client, "xmas_ornament_glitter_alt", 2.0, 0.0);
			EmitAmbientSound("misc/jingle_bells/jingle_bells_nm_02.wav", vel, client);
		}
		TF2_RemoveCondition(client, TFCond_StealthedUserBuffFade);
		TF2_RemoveCondition(client, TFCond_Cloaked);
		TF2_RemovePlayerDisguise(client);
		ClearTimer(TimeTravelHandle[client]);
		TimeTravelHandle[client] = CreateTimer(0.0, Timer_RemoveTimeTravel, client); // Remove Time Travel instantly
		float pos1[3];
		GetClientAbsOrigin(client, pos1);
		for (int client2 = 1 ; client2 <= MaxClients ; client2++ ) {
			if (IsClientInGame(client2)) {
				float pos2[3];
				GetClientAbsOrigin(client2, pos2);
				if (GetVectorDistance(pos1, pos2) <= 250.0 && GetClientTeam(client) != GetClientTeam(client2)) {
					SDKHooks_TakeDamage(client2, 0, client, (150.0 - (GetVectorDistance(pos1, pos2) * 0.4)), 0, -1);
					EmitSoundToClient(client2, "physics/flesh/flesh_impact_bullet2.wav", client2);
				}
			}
		}
		BuildingDamage(client, "obj_sentrygun");
		BuildingDamage(client, "obj_dispenser");
		BuildingDamage(client, "obj_teleporter");
	} else if (PowerupID[client] == 8) {
		// Mega Mann - Giant and 4x health for 10 seconds
		EmitAmbientSound("fortressblast2/megamann_use.mp3", vel, client);
		SetVariantString("1.75 0");
		AcceptEntityInput(client, "SetModelScale");
		int healthMultiplier = 4;
		if (GetPlayerMaxHealth(client) >= 300) {
			// User is assumed to be a Heavy, reduce health gained to 3x
			healthMultiplier = 3;
		}
		SetEntityHealth(client, (GetClientHealth(client) * healthMultiplier)); // Multiply current health
		// Cap at expected multiplied maximum health
		if (GetClientHealth(client) > (GetPlayerMaxHealth(client) * healthMultiplier)) {
			SetEntityHealth(client, GetPlayerMaxHealth(client) * healthMultiplier);
		}
		ClearTimer(MegaMannHandle[client]);
		MegaMannHandle[client] = CreateTimer(10.0, Timer_RemoveMegaMann, client);
		float coords[3] = 69.420;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
		coords[2] += 16.0;
		TeleportEntity(client, coords, NULL_VECTOR, NULL_VECTOR);
		MegaMannVerified[client] = true;
	} else if (PowerupID[client] == 9) {
		// Frost Touch - Freeze touched players for 3 seconds within 8 seconds
		EmitAmbientSound("fortressblast2/frosttouch_use.mp3", vel, client);
		ClearTimer(FrostTouchHandle[client]);
		FrostTouchHandle[client] = CreateTimer(8.0, Timer_RemoveFrostTouch, client);
		ParticleOnPlayer(client, "smoke_rocket_steam", 8.0, 32.0);
	} else if (PowerupID[client] == 10) {
		// Mystery - Random powerup
		// Has a higher chance of picking Gyrocopter during April Fools
		if (GetRandomFloat(0.0, 99.99) < 75.0 && AprilFools() && PowerupIsEnabled(5)) {
			PowerupID[client] = 5;
		} else {
			int mysrand = 10;
			while (mysrand == 10 || !PowerupIsEnabled(mysrand)) {
				mysrand = GetRandomInt(1, NumberOfPowerups);
			}
			PowerupID[client] = mysrand;
		}
		UsePowerup(client);
	} else if (PowerupID[client] == 11) {
		// Teleportation - Teleport to random active Engineer exit teleport or spawn
		ClearTimer(TeleportationHandle[client]);
		TeleportationHandle[client] = CreateTimer(0.5, Timer_BeginTeleporter, client);
		EmitAmbientSound("fortressblast2/teleportation_use.mp3", vel, client);
		ParticleOnPlayer(client, "teleported_flash", 0.5, 0.0); // Particle on using powerup
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
	} else if (PowerupID[client] == 12) {
		// Magnetism - Repel or attract enemies depending on weapon slot
		EmitAmbientSound("fortressblast2/magnetism_use.mp3", vel, client);
		ClearTimer(MagnetismHandle[client]);
		MagnetismHandle[client] = CreateTimer(5.0, Timer_RemoveMagnetism, client);
		// Repeatedly produce Magnetism particle
		float timeport = 0.1;
		ParticleOnPlayer(client, "ping_circle", 0.5, 0.0);
		for (int timepoint = 0 ; timepoint <= 50 ; timepoint++) {
			CreateTimer(timeport, MagnetismParticleRepeater, client);
			timeport = timeport + 0.1;
		}
	} else if (PowerupID[client] == 13) {
		// Effect Burst - Afflict enemies with one of four random status effects
		EmitAmbientSound("fortressblast2/effectburst_use.mp3", vel, client);
		ParticleOnPlayer(client, "merasmus_dazed_explosion", 1.0, 0.0);
		float pos1[3];
		GetClientAbsOrigin(client, pos1);
		for (int client2 = 1 ; client2 <= MaxClients ; client2++) {
			if (IsClientInGame(client2) && GetClientTeam(client) != GetClientTeam(client2)) {
				float pos2[3];
				GetClientAbsOrigin(client2, pos2);
				if (GetVectorDistance(pos1, pos2) < 768.0) {
					int random = GetRandomInt(1, 4);
					if (random == 1) {
						TF2_MakeBleed(client2, client, 10.0);
						EmitSoundToClient(client2, "weapons/cleaver_hit_02.wav", client2);
					} else if (random == 2) {
						TF2_IgnitePlayer(client2, client, 10.0);
					} else if (random == 3) {
						TF2_AddCondition(client2, TFCond_Milked, 10.0);
						EmitSoundToClient(client2, "weapons/jar_explode.wav", client2);
					} else {
						TF2_AddCondition(client2, TFCond_Jarated, 10.0);
						EmitSoundToClient(client2, "weapons/jar_explode.wav", client2);
					}
				}
			}
		}
	} else if (PowerupID[client] == 14) {
		// Dizzy Bomb - Afflict enemies with dizziness of varying effectiveness
		EmitAmbientSound("fortressblast2/dizzybomb_use.mp3", vel, client);
		float pos1[3];
		GetClientAbsOrigin(client, pos1);
		for (int client2 = 1 ; client2 <= MaxClients ; client2++) {
			if (IsClientInGame(client2) && IsPlayerAlive(client2) && GetClientTeam(client2) != GetClientTeam(client)) {
				float pos2[3];
				GetClientAbsOrigin(client2, pos2);
				if (GetVectorDistance(pos1, pos2) < 512.0) {
					DizzyProgress[client2] = 0;
					NegativeDizzy[client2] = (GetRandomInt(0, 1) == 0); // Randomly decide which direction dizziness shoudl start in
					EmitSoundToClient(client2, "fortressblast2/dizzybomb_dizzy.mp3", client2);
					ParticleOnPlayer(client2, "conc_stars", sm_fortressblast_dizzy_length.FloatValue, 80.0);
				}
			}
		}
	}
	PowerupID[client] = 0;
}

/* Deleting and Respawning Powerups and Gifts
==================================================================================================== */

public Action OnStartTouchRespawn(int entity, int other) {
	if (other > 0 && other <= MaxClients) {
		float coords[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
		Handle coordskv = CreateKeyValues("coordskv");
		KvSetFloat(coordskv, "0", coords[0]);
		KvSetFloat(coordskv, "1", coords[1]);
		KvSetFloat(coordskv, "2", coords[2]);
		KvSetNum(coordskv, "verifier", GlobalVerifier);
		CreateTimer(10.0, Timer_RespawnPowerup, coordskv);
		DeletePowerup(entity, other);
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public Action OnStartTouchDontRespawn(int entity, int other) {
	DeletePowerup(entity, other);
}

public void DeletePowerup(int entity, int other) {
	RemoveEntity(entity);
	if (PowerupID[entity] == 0) {
		CollectedGift(other);
		return;
	}
	PowerupID[other] = PowerupID[entity];
	DebugText("%N has collected powerup ID %d", other, PowerupID[other]);
	CollectedPowerup(other);
}

public Action Timer_RespawnPowerup(Handle timer, any data) {
	float coords[3];
	Handle coordskv = data;
	coords[0] = KvGetFloat(coordskv, "0");
	coords[1] = KvGetFloat(coordskv, "1");
	coords[2] = KvGetFloat(coordskv, "2");
	int LocalVerifier = KvGetNum(coordskv, "verifier");
	// Only respawn powerup if it has an ID equal to the previously placed one
	if (LocalVerifier == GlobalVerifier) {
		DebugText("Respawning powerup at %f, %f, %f", coords[0], coords[1], coords[2]);
		EmitAmbientSound("items/spawn_item.wav", coords);
		SpawnPowerup(coords, true);
	}
}

/* OnTakeDamage()
==================================================================================================== */

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
	if (UsingPowerup[2][victim] || FrostTouchFrozen[victim] == 1 || UltraPowerup[victim]) {
		if (FrostTouchFrozen[victim] == 1) {
			damage = damage * 0.1;
			DebugText("%N was in frozen state %d", victim, FrostTouchFrozen[victim]);
		} else {
			damage = damage * 0.25;
		}
		damageForce[0] = 0.0;
		damageForce[1] = 0.0;
		damageForce[2] = 0.0;
	}
	if (UsingPowerup[1][victim] && attacker == 0 && damage < 100.0) {
		return Plugin_Handled;
	}
	return Plugin_Changed;
}

/* Particle Repeaters
==================================================================================================== */

public Action MagnetismParticleRepeater(Handle timer, int client) {
	if (IsClientInGame(client) && IsPlayerAlive(client) && UsingPowerup[12][client]) {
		ParticleOnPlayer(client, "ping_circle", 0.5, 0.0);
	}
}

public Action UltraParticleRepeaterFire(Handle timer, int client) {
	if (IsClientInGame(client) && IsPlayerAlive(client) && UltraPowerup[client]) {
		ParticleOnPlayer(client, "medic_resist_fire", 0.2, 0.0);
	}
}

public Action UltraParticleRepeaterBullet(Handle timer, int client) {
	if (IsClientInGame(client) && IsPlayerAlive(client) && UltraPowerup[client]) {
		ParticleOnPlayer(client, "medic_resist_bullet", 0.2, 0.0);
	}
}

public void BuildingDamage(int client, const char[] class) {
	float pos1[3];
	GetClientAbsOrigin(client, pos1);
	int entity = 0;
	while ((entity = FindEntityByClassname(entity, class)) != -1) {
		int bobthe = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
		float pos2[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos2);
		if (0 < bobthe <= MaxClients && IsClientInGame(bobthe) && GetClientTeam(bobthe) != GetClientTeam(client) && GetVectorDistance(pos1, pos2) <= 250.0) {
			DebugText("%s ID %d at %f, %f, %f damaged by Blast powerup", class, entity, pos2[0], pos2[1], pos2[2]);
			float expectedDamage = sm_fortressblast_blast_buildings.FloatValue / 100;
			if (expectedDamage < 0) {
				expectedDamage = 0.0;
			}
			SDKHooks_TakeDamage(entity, 0, client, ((150.0 - (GetVectorDistance(pos1, pos2) * 0.4)) * expectedDamage), 0, -1);
		}
	}
}

/* Frost Touch
==================================================================================================== */

public Action OnStartTouchFrozen(int entity, int other) {
	// Test that using player and touched player are both valid targets
	if (entity > 0 && entity <= MaxClients && other > 0 && other <= MaxClients && IsClientInGame(entity) && IsClientInGame(other)) {
		if ((UsingPowerup[9][entity] || UltraPowerup[entity]) && FrostTouchFrozen[other] == 0) {
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
			SetEntityMoveType(iRagDoll, MOVETYPE_NONE);
			ClearTimer(FrostTouchUnfreezeHandle[other]);
			FrostTouchUnfreezeHandle[other] = CreateTimer(3.0, Timer_FrostTouchUnfreeze, other);
			FrostTouchFrozen[other] = ((UltraPowerup[entity]) ? 2 : 1);
			BlockAttacking(other, 3.0);
		}
	}
}

public Action Timer_FrostTouchUnfreeze(Handle timer, int client) {
	FrostTouchUnfreezeHandle[client] = INVALID_HANDLE;
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (IsPlayerAlive(client)) {
		EmitAmbientSound("fortressblast2/frosttouch_unfreeze.mp3", vel, client);
	}
	SetClientViewEntity(client, client);
	SetEntityMoveType(client, MOVETYPE_WALK);
	ColorizePlayer(client, {255, 255, 255, 255});
	SetThirdPerson(client, false);
	FrostTouchFrozen[client] = 0;
}

stock void ColorizePlayer(int client, int iColor[4]) { // Roll the Dice function with new syntax
	SetEntityColor(client, iColor);
	for (int i = 0; i < 3; i++) {
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if (iWeapon > MaxClients && IsValidEntity(iWeapon)) {
			SetEntityColor(iWeapon, iColor);
		}
	}
	char strClass[20];
	for (int i = MaxClients + 1; i < GetMaxEntities(); i++) {
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

public int CreateRagdoll(int client) { // Roll the Dice function with new syntax
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
		SetEntProp(iRag, Prop_Send, "m_iClass", view_as<int>(TF2_GetPlayerClass(client)));
		SetEntProp(iRag, Prop_Send, "m_bOnGround", 1);

		// Fix oddly shaped statues
		SetEntPropFloat(iRag, Prop_Send, "m_flHeadScale", GetEntPropFloat(client, Prop_Send, "m_flHeadScale"));
		SetEntPropFloat(iRag, Prop_Send, "m_flTorsoScale", GetEntPropFloat(client, Prop_Send, "m_flTorsoScale"));
		SetEntPropFloat(iRag, Prop_Send, "m_flHandScale", GetEntPropFloat(client, Prop_Send, "m_flHandScale"));

		SetEntityMoveType(iRag, MOVETYPE_NONE);
		DispatchSpawn(iRag);
		ActivateEntity(iRag);
		return iRag;
	}
	return 0;
}

stock void SetEntityColor(int iEntity, int iColor[4]) { // Roll the Dice function with new syntax
	SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iEntity, iColor[0], iColor[1], iColor[2], iColor[3]);
}

/* SetThirdPerson()
Roll the Dice function with new syntax
==================================================================================================== */

public void SetThirdPerson(int client, bool bEnabled) {
	if (bEnabled) {
		SetVariantInt(1);
	} else {
		SetVariantInt(0);
	}
	AcceptEntityInput(client, "SetForcedTauntCam");
}

/* Mega Mann dependencies + OnTouchRespawnRoom()
==================================================================================================== */

stock int GetPlayerMaxHealth(int client) {
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool& result) {
	if (UsingPowerup[8][client]) {
		result = false; // Prevent players with Mega Mann from taking teleporters
	}
	return Plugin_Changed;
}

public bool IsEntityStuck(int iEntity) { // Roll the Dice function with new syntax
	float flOrigin[3];
	float flMins[3];
	float flMaxs[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flOrigin);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMins", flMins);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", flMaxs);

	TR_TraceHullFilter(flOrigin, flOrigin, flMins, flMaxs, MASK_SOLID, TraceFilterNotSelf, iEntity);
	return TR_DidHit();
}

public bool TraceFilterNotSelf(int entity, int contentsMask, any client) {
	if (entity == client) {
		return false;
	}
	return true;
}

public void OnTouchRespawnRoom(int entity, int other) {
	if (other < 1 || other > MaxClients) return;
	if (!IsClientInGame(other)) return;
	if (!IsPlayerAlive(other)) return;
	// Kill enemies inside spawnrooms
	if (GetEntProp(entity, Prop_Send, "m_iTeamNum") != GetClientTeam(other) && sm_fortressblast_respawnroomkill.BoolValue && VictoryTeam == -1) {
		FakeClientCommandEx(other, "kill");
		PrintToServer("%s %N was killed due to being inside an enemy team spawnroom.", MESSAGE_PREFIX_NO_COLOR, other);
		CPrintToChat(other, "%s {red}You were killed because you were inside the enemy spawn.", MESSAGE_PREFIX);
	}
}

/* Teleportation
==================================================================================================== */

public Action Timer_BeginTeleporter(Handle timer, int client) {
	TeleportationHandle[client] = INVALID_HANDLE;
	if (!IsPlayerAlive(client)) {
		return; // Do not teleport dead player
	}
	if (UsingPowerup[8][client]) {
		ClearTimer(MegaMannHandle[client]);
		MegaMannHandle[client] = CreateTimer(0.0, Timer_RemoveMegaMann, client);
	}
	FakeClientCommand(client, "dropitem"); // Force player to drop intelligence
	int teles = GetTeamTeleporters(TF2_GetClientTeam(client));
	if (teles == 0) {
		CPrintToChat(client, "%s {haunted}You were teleported to your spawn as there are no active Teleporter exits on your team.", MESSAGE_PREFIX);
		int preregenhealth = GetClientHealth(client);
		int index[4];
		int ammo[4];
		int clip[4];
		for (int i = 0; i <= 3; i++) {
			ammo[i] = GetEntProp(client, Prop_Data, "m_iAmmo", 4, i);
			int slot = GetPlayerWeaponSlot(client, i);
			if (IsValidEntity(slot)) {
				clip[i] = GetEntProp(slot, Prop_Data, "m_iClip1");
				index[i] = GetEntProp(slot, Prop_Send, "m_iItemDefinitionIndex");
			}
		}
		int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		DebugText("Active weapon ID is %d", active);
		char classname[30];
		GetEntityClassname(active, classname, sizeof(classname));
		TF2_RespawnPlayer(client);
		SetEntityHealth(client, preregenhealth);
		for (int i = 0; i <= 3; i++) {
			int slot = GetPlayerWeaponSlot(client, i);
			if (IsValidEntity(slot)) {
				if (GetEntProp(slot, Prop_Send, "m_iItemDefinitionIndex") == index[i]) {
					SetEntProp(slot, Prop_Data, "m_iClip1", clip[i]);
					SetEntProp(client, Prop_Data, "m_iAmmo", ammo[i], 4, i);
				}
			}
		}
		FakeClientCommand(client, "use %s", classname);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", active);
		TeleportXmasParticles(client);
		return;
	}
	int eli = GetRandomInt(1, teles);
	DebugText("Teleporter number %d has been selected", eli);
	int countby = 1;
	int entity;
	while ((entity = FindEntityByClassname(entity, "obj_teleporter")) != -1) {
		if (TF2_GetClientTeam(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")) == TF2_GetClientTeam(client) && TF2_GetObjectMode(entity) == TFObjectMode_Exit && TeleporterPassesNetprops(entity)) {
			if (countby == eli) {
				float coords[3] = 69.420;
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
				float angles[3] = 69.420;
				GetEntPropVector(entity, Prop_Data, "m_angRotation", angles);
				coords[2] += 24.00;
				TeleportEntity(client, coords, angles, NULL_VECTOR);
				break;
			}
			countby++;
		}
	}
	if (TF2_GetClientTeam(client) == TFTeam_Red) {
		ParticleOnPlayer(client, "teleportedin_red", 1.0, 0.0);
	} else if (TF2_GetClientTeam(client) == TFTeam_Blue) {
		ParticleOnPlayer(client, "teleportedin_blue", 1.0, 0.0);
	}
	TeleportXmasParticles(client);
}


public void TeleportXmasParticles(int client) {
	if (Smissmas()) {
		float vel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
		ParticleOnPlayer(client, "xms_snowburst_child01", 5.0, 0.0);
		EmitAmbientSound("misc/jingle_bells/jingle_bells_nm_01.wav", vel, client);
	}
}

public int GetTeamTeleporters(TFTeam team) {
	int entity;
	int amounter;
	while ((entity = FindEntityByClassname(entity, "obj_teleporter")) != -1) {
		if (TF2_GetClientTeam(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")) == team && TF2_GetObjectMode(entity) == TFObjectMode_Exit && TeleporterPassesNetprops(entity)) {
			amounter++;
		}
	}
	DebugText("Teleporting a player with %d active teleporters", amounter);
	return amounter;
}

public bool TeleporterPassesNetprops(int entity) {
	int state = GetEntProp(entity, Prop_Send, "m_iState");
	if (GetEntProp(entity, Prop_Send, "m_bHasSapper") > 0) {
		return false;
	} else if (GetEntProp(entity, Prop_Send, "m_bCarried") > 0) {
		return false;
	} else if (state == 2) {
		return true;
	} else if (state == 6) {
		return true;
	}
	return false;
}

/* Powerup Removal
==================================================================================================== */

public Action Timer_RemoveSuperBounce(Handle timer, int client) {
	SuperBounceHandle[client] = INVALID_HANDLE;
	UsingPowerup[1][client] = false;
	if (IsClientInGame(client)) {
		if (AprilFools() && UsingPowerup[5][client]) {
			SetEntityGravity(client, 0.25);
		} else {
			SetEntityGravity(client, 1.0);
		}
	}
}

public Action Timer_RemoveShockAbsorb(Handle timer, int client) {
	ShockAbsorberHandle[client] = INVALID_HANDLE;
	UsingPowerup[2][client] = false;
}

public Action Timer_RemoveGyrocopter(Handle timer, int client) {
	UsingPowerup[5][client] = false;
	GyrocopterHandle[client] = INVALID_HANDLE;
	if (IsClientInGame(client)) {
		if (UsingPowerup[1][client] && AprilFools()) {
			SetEntityGravity(client, 3.0);
		} else {
			SetEntityGravity(client, 1.0);
		}
	}
}

public Action Timer_RemoveTimeTravel(Handle timer, int client) {
	TimeTravelHandle[client] = INVALID_HANDLE;
	UsingPowerup[6][client] = false;
	SetThirdPerson(client, false);
	if (IsClientInGame(client)) {
		TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
	}
}

public Action Timer_RemoveFrostTouch(Handle timer, int client) {
	FrostTouchHandle[client] = INVALID_HANDLE;
	UsingPowerup[9][client] = false;
}

public Action Timer_RemoveMegaMann(Handle timer, int client) {
	MegaMannHandle[client] = INVALID_HANDLE;
	UsingPowerup[8][client] = false;
	if (IsClientInGame(client)) {
		SetVariantString("1 0");
		AcceptEntityInput(client, "SetModelScale");
		// Remove excess overheal, but leave injuries
		if (GetClientHealth(client) > GetPlayerMaxHealth(client)) {
			SetEntityHealth(client, GetPlayerMaxHealth(client));
		}
	}
}

public Action Timer_RemoveMagnetism(Handle timer, int client) {
	MagnetismHandle[client] = INVALID_HANDLE;
	UsingPowerup[12][client] = false;
}

public Action Timer_RemoveUltraPowerup(Handle timer, int client) {
	UltraPowerupHandle[client] = INVALID_HANDLE;
	UltraPowerup[client] = false;
	if (GetClientHealth(client) > GetPlayerMaxHealth(client)) {
		SetEntityHealth(client, GetPlayerMaxHealth(client));
	}
}

/* ClearTimer()
From SourceMod forums
==================================================================================================== */

stock void ClearTimer(Handle Timer) {
    if (Timer != INVALID_HANDLE) {
        CloseHandle(Timer);
        Timer = INVALID_HANDLE;
    }
}

/* DoHudText()
The HUD function for the plugin
On April Fools most of the powerups have the word 'Super' inserted into them
==================================================================================================== */

public void DoHudText(int client) {
	if (PowerupID[client] != 0) {
		if (BlockPowerup(client)) {
			SetHudTextParams(0.825, 0.5, 0.25, 255, 0, 0, 0);
		} else {
			SetHudTextParams(0.825, 0.5, 0.25, 255, 255, 0, 255);
		}
		if (PowerupID[client] == -1) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nULTRA POWERUP!!");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSUPER POWERUP!!");
			}
		} else if (PowerupID[client] == 1) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Bounce");
		} else if (PowerupID[client] == 2) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nShock Absorber");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Absorber");
			}
		} else if (PowerupID[client] == 3) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Speed");
		} else if (PowerupID[client] == 4) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Jump");
		} else if (PowerupID[client] == 5) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nGyrocopter");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Gyrocopter");
			}
		} else if (PowerupID[client] == 6) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nTime Travel");
		} else if (PowerupID[client] == 7) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nBlast");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Blast");
			}
		} else if (PowerupID[client] == 8) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nMega Mann");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Mann");
			}
		} else if (PowerupID[client] == 9) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nFrost Touch");
		} else if (PowerupID[client] == 10) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nMystery");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Mystery");
			}
		} else if (PowerupID[client] == 11) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nTeleportation");
		} else if (PowerupID[client] == 12) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nMagnetism");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Magnetism");
			}
		} else if (PowerupID[client] == 13) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nEffect Burst");
		} else if (PowerupID[client] == 14) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nDizzy Bomb");
		}
	}
	if (GiftHunt && VictoryTeam == -1) {
		SetHudTextParams(-1.0, 0.775, 0.25, 255, 255, 255, 255);
		if (GiftMultiplier[2] < 2 && GiftMultiplier[3] < 2) {
  			ShowSyncHudText(client, GiftText, "BLU: %d | Playing to %d gifts | RED: %d", GiftsCollected[3], GiftGoal, GiftsCollected[2]);
		} else if (GiftMultiplier[2] < 2 && GiftMultiplier[3] >= 2) {
  			ShowSyncHudText(client, GiftText, "BLU: %d (x%d)| Playing to %d gifts | RED: %d", GiftsCollected[3], GiftMultiplier[3], GiftGoal, GiftsCollected[2]);
		} else if (GiftMultiplier[2] >= 2 && GiftMultiplier[3] < 2) {
  			ShowSyncHudText(client, GiftText, "BLU: %d | Playing to %d gifts | RED: %d (x%d)", GiftsCollected[3], GiftGoal, GiftsCollected[2], GiftMultiplier[2]);
		}
	}
}

/* Particles
==================================================================================================== */

public void ParticleOnPlayer(int client, char particlename[80], float time, float zadjust) {
	int particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(particle, "effect_name", particlename);
	AcceptEntityInput(particle, "SetParent", client);
	AcceptEntityInput(particle, "Start");
	DispatchSpawn(particle);
	ActivateEntity(particle);
	float coords[3] = 69.420;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
	coords[2] += zadjust;
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
		PrintToServer("%s All of %N's particles were in use, freeing #%d", MESSAGE_PREFIX_NO_COLOR, client, freeid);
	}
	PlayerParticle[client][freeid] = particle;
	ParticleZAdjust[client][freeid] = zadjust;
	Handle partkv = CreateKeyValues("partkv");
	KvSetNum(partkv, "client", client);
	KvSetNum(partkv, "id", freeid);
	CreateTimer(time, Timer_RemoveParticle, partkv);
}

public Action Timer_RemoveParticle(Handle timer, any data) {
	Handle partkv = data;
	int client = KvGetNum(partkv, "client");
	int id = KvGetNum(partkv, "id");
	if (IsValidEntity(PlayerParticle[client][id])) {
		RemoveEntity(PlayerParticle[client][id]);
	}
	PlayerParticle[client][id] = -1;
}

/* DebugText()
==================================================================================================== */

public void DebugText(const char[] text, any ...) {
	if (sm_fortressblast_debug.BoolValue) {
		int len = strlen(text) + 255;
		char[] format = new char[len];
		VFormat(format, len, text, 2);
		CPrintToChatAll("{orange}[FB Debug] {white}%s", format);
		PrintToServer("[FB Debug] %s", format);
	}
}

/* ActionInit() + AdminFlagInit()
==================================================================================================== */

public int ActionInit() {
	char button[40];
	sm_fortressblast_action.GetString(button, sizeof(button));
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
	}
	return 33554432; // Special attack
}

public int AdminFlagInit() {
	char flag[40];
	sm_fortressblast_adminflag.GetString(flag, sizeof(flag));
	if (StrEqual(flag, "a")) {
		return ADMFLAG_RESERVATION;
	} else if (StrEqual(flag, "b")) {
		return ADMFLAG_GENERIC;
	} else if (StrEqual(flag, "c")) {
		return ADMFLAG_KICK;
	} else if (StrEqual(flag, "d")) {
		return ADMFLAG_BAN;
	} else if (StrEqual(flag, "e")) {
		return ADMFLAG_UNBAN;
	} else if (StrEqual(flag, "f")) {
		return ADMFLAG_SLAY;
	} else if (StrEqual(flag, "g")) {
		return ADMFLAG_CHANGEMAP;
	} else if (StrEqual(flag, "h")) {
		return ADMFLAG_CONVARS;
	} else if (StrEqual(flag, "i")) {
		return ADMFLAG_CONFIG;
	} else if (StrEqual(flag, "j")) {
		return ADMFLAG_CHAT;
	} else if (StrEqual(flag, "k")) {
		return ADMFLAG_VOTE;
	} else if (StrEqual(flag, "l")) {
		return ADMFLAG_PASSWORD;
	} else if (StrEqual(flag, "m")) {
		return ADMFLAG_RCON;
	} else if (StrEqual(flag, "n")) {
		return ADMFLAG_CHEATS;
	} else if (StrEqual(flag, "o")) {
		return ADMFLAG_CUSTOM1;
	} else if (StrEqual(flag, "p")) {
		return ADMFLAG_CUSTOM2;
	} else if (StrEqual(flag, "q")) {
		return ADMFLAG_CUSTOM3;
	} else if (StrEqual(flag, "r")) {
		return ADMFLAG_CUSTOM4;
	} else if (StrEqual(flag, "s")) {
		return ADMFLAG_CUSTOM5;
	} else if (StrEqual(flag, "t")) {
		return ADMFLAG_CUSTOM6;
	}
	return ADMFLAG_ROOT;
}

public void BlockAttacking(int client, float time) { // Roll the Dice function with new syntax
	for (int weapon = 0; weapon <= 5 ; weapon++) {
		if (GetPlayerWeaponSlot(client, weapon) != -1) {
			SetEntPropFloat(GetPlayerWeaponSlot(client, weapon), Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + time);
			SetEntPropFloat(GetPlayerWeaponSlot(client, weapon), Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + time);
		}
	}
}

/* OnGameFrame() + GiftHuntNeutralGoal()
Neutral intelligence support for Gift Hunt
==================================================================================================== */

public void OnGameFrame() {
	GiftHuntNeutralGoal();
}

public void GiftHuntNeutralGoal() {
	if (GiftHuntNeutralFlag) {
		int flag;
		while ((flag = FindEntityByClassname(flag, "item_teamflag")) != -1) {
			// Neither team has reached gift goal, intelligence is neutral and disabled
			if (GiftsCollected[2] < GiftGoal && GiftsCollected[3] < GiftGoal) {
				AcceptEntityInput(flag, "Disable");
				SetEntProp(flag, Prop_Send, "m_iTeamNum", 0);
			// Both teams have reached gift goal, intelligence is neutral and enabled
			} else if (GiftsCollected[2] >= GiftGoal && GiftsCollected[3] >= GiftGoal) {
				AcceptEntityInput(flag, "Enable");
				SetEntProp(flag, Prop_Send, "m_iTeamNum", 0);
			// RED team has reached gift goal, intelligence is BLU and enabled
			} else if (GiftsCollected[3] >= GiftGoal && GiftsCollected[2] < GiftGoal) {
				AcceptEntityInput(flag, "Enable");
				SetEntProp(flag, Prop_Send, "m_iTeamNum", 2);
			// BLU team has reached gift goal, intelligence is RED and enabled
			} else if (GiftsCollected[2] >= GiftGoal && GiftsCollected[3] < GiftGoal) {
				AcceptEntityInput(flag, "Enable");
				SetEntProp(flag, Prop_Send, "m_iTeamNum", 3);
			}
		}
	}
}

/* EntFire()
sm_entfire with updated syntax
==================================================================================================== */

stock bool EntFire(char[] strTargetname, char[] strInput, char strParameter[] = "", float flDelay = 0.0) {
	char strBuffer[255];
	Format(strBuffer, sizeof(strBuffer), "OnUser1 %s:%s:%s:%f:1", strTargetname, strInput, strParameter, flDelay);
	int entity = CreateEntityByName("info_target");
	if (IsValidEdict(entity)) {
		DispatchSpawn(entity);
		ActivateEntity(entity);
		SetVariantString(strBuffer);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
		CreateTimer(0.0, Timer_DeleteEdict, entity);
		return true;
	}
	return false;
}

public Action Timer_DeleteEdict(Handle timer, int entity) {
	if (IsValidEdict(entity)) {
		RemoveEdict(entity);
	}
	return Plugin_Stop;
}

/* Events/Holidays
==================================================================================================== */

/* Possible holidays
- TFHoliday_Birthday;
- TFHoliday_Halloween;
- TFHoliday_Christmas;
- TFHoliday_EndOfTheLine;
- TFHoliday_CommunityUpdate;
- TFHoliday_ValentinesDay;
- TFHoliday_MeetThePyro;
- TFHoliday_FullMoon;
- TFHoliday_HalloweenOrFullMoon;
- TFHoliday_HalloweenOrFullMoonOrValentines;
- TFHoliday_AprilFools; */

public bool Smissmas() {
	int convar = sm_fortressblast_event_xmas.IntValue;
	if (convar == 0) {
		return false;
	} else if (convar == 1) {
		return TF2_IsHolidayActive(TFHoliday_Christmas);
	}
	return true;
}

public bool AprilFools() {
	int convar = sm_fortressblast_event_fools.IntValue;
	if (convar == 0) {
		return false;
	} else if (convar == 1) {
		return TF2_IsHolidayActive(TFHoliday_AprilFools);
	}
	return true;
}
