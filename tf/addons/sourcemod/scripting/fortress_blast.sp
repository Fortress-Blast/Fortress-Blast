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
#define MAX_PARTICLES 25 // If a player needs more than this number, a random one is deleted, but too many might cause memory problems
#define MESSAGE_PREFIX "{orange}[Fortress Blast]"
#define MESSAGE_PREFIX_NO_COLOR "[Fortress Blast]"
#define PLUGIN_VERSION "5.0"
#define MOTD_VERSION "5.0"
#define NUMBER_OF_POWERUPS 17 // Do not use in calculations, only for sizing arrays

#define PI 3.14159265359

public Plugin myinfo = {
	name = "Fortress Blast",
	author = "Jack5 & Naleksuh",
	description = "Adds powerups from Marble Blast into TF2! Can easily be combined with other plugins and game modes.",
	version = PLUGIN_VERSION,
	url = "https://fortressblast.miraheze.org"
};

// Global Variables
int NumberOfPowerups = NUMBER_OF_POWERUPS; // Do not define, use this for calculations
int PlayersAmount;
int GiftGoal;
int GiftsCollected[4] = 0;
int GiftMultiplier[4] = 1;
int Powerup[MAX_EDICTS] = -2; // For powerups, gifts and player storage
int PlayerParticle[MAXPLAYERS + 1][MAX_PARTICLES + 1];
int SpeedRotationsLeft[MAXPLAYERS + 1] = 80;
int VictoryTeam = -1;
int DizzyProgress[MAXPLAYERS + 1] = -1;
int FrostTouchFrozen[MAXPLAYERS + 1] = 0;
int GlobalVerifier = 0;
int Building[MAXPLAYERS + 1] = 0;
int PreSentryHealth[MAXPLAYERS + 1] = 0;
bool LateLoad = false;
bool PreviousAttack3[MAXPLAYERS + 1] = false;
bool MapHasJsonFile = false;
bool GiftHunt = false;
bool NegativeDizzy[MAXPLAYERS + 1] = false;
bool UltraPowerup[MAXPLAYERS + 1] = false;
bool MegaMannVerified[MAXPLAYERS + 1] = false;
bool UsingPowerup[NUMBER_OF_POWERUPS + 1][MAXPLAYERS + 1];
bool GiftHuntAttackDefense = false;
bool GiftHuntNeutralFlag = false;
bool GiftHuntSetup = false;
float GiftHuntIncrementTime = 0.0;
float OldSpeed[MAXPLAYERS + 1] = 0.0;
float SuperSpeed[MAXPLAYERS + 1] = 0.0;
float VerticalVelocity[MAXPLAYERS + 1];
float ParticleZAdjust[MAXPLAYERS + 1][MAX_PARTICLES + 1];
float ExitSentryTime[MAXPLAYERS + 1];
Handle SuperBounceHandle[MAXPLAYERS + 1] = null;
Handle ShockAbsorberHandle[MAXPLAYERS + 1] = null;
Handle GyrocopterHandle[MAXPLAYERS + 1] = null;
Handle TimeTravelHandle[MAXPLAYERS + 1] = null;
Handle MegaMannHandle[MAXPLAYERS + 1] = null;
Handle FrostTouchHandle[MAXPLAYERS + 1] = null;
Handle FrostTouchUnfreezeHandle[MAXPLAYERS + 1] = null;
Handle DestroyPowerupHandle[MAX_EDICTS + 1] = null;
Handle TeleportationHandle[MAXPLAYERS + 1] = null;
Handle MagnetismHandle[MAXPLAYERS + 1] = null;
Handle UltraPowerupHandle[MAXPLAYERS+1] = null;
Handle GhostHandle[MAXPLAYERS+1] = null;

// HUDs
Handle PowerupText;
Handle GiftText;

// ConVars
ConVar sm_fortressblast_action_use;
ConVar sm_fortressblast_admin_flag;
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
ConVar sm_fortressblast_event_scream;
ConVar sm_fortressblast_event_fools;
ConVar sm_fortressblast_event_xmas;
ConVar sm_fortressblast_gifthunt;
ConVar sm_fortressblast_gifthunt_countbots;
ConVar sm_fortressblast_gifthunt_goal;
ConVar sm_fortressblast_gifthunt_increment;
ConVar sm_fortressblast_gifthunt_players;
ConVar sm_fortressblast_gifthunt_rate;
ConVar sm_fortressblast_gifthunt_multiply;
ConVar sm_fortressblast_intro;
ConVar sm_fortressblast_mannpower;
ConVar sm_fortressblast_powerups;
ConVar sm_fortressblast_powerups_roundstart;
ConVar sm_fortressblast_ultra_spawnchance;

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
14 - Dizzy Bomb
15 - Become Sentry
16 - Ghost
17 - Catapult */

/* OnPluginStart() + OnPluginEnd()
==================================================================================================== */

public void OnPluginStart() {

	// Hooks
	HookEvent("teamplay_round_start", teamplay_round_start);
	HookEvent("teamplay_setup_finished", teamplay_setup_finished);
	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("player_death", player_death);

	// Commands
	RegConsoleCmd("sm_fortressblast", sm_fortressblast);
	RegConsoleCmd("sm_coordsjson", sm_coordsjson);
	RegConsoleCmd("sm_respawnpowerups", sm_respawnpowerups);
	RegConsoleCmd("sm_setpowerup", sm_setpowerup);
	RegConsoleCmd("sm_spawnpowerup", sm_spawnpowerup);
	RegConsoleCmd("eureka_teleport", eureka_teleport);

	// Translations
	LoadTranslations("common.phrases");

	// ConVars
	sm_fortressblast_action_use = CreateConVar("sm_fortressblast_action_use", "attack3", "Which action to watch for in order to use powerups.");
	sm_fortressblast_admin_flag = CreateConVar("sm_fortressblast_admin_flag", "z", "Which flag to use for admin-restricted commands outside of debug mode.");
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
	sm_fortressblast_event_scream = CreateConVar("sm_fortressblast_event_scream", "1", "How to handle the TF2 Scream Fortress event.");
	sm_fortressblast_event_fools = CreateConVar("sm_fortressblast_event_fools", "1", "How to handle the TF2 April Fools event.");
	sm_fortressblast_event_xmas = CreateConVar("sm_fortressblast_event_xmas", "1", "How to handle the TF2 Smissmas event.");
	sm_fortressblast_gifthunt = CreateConVar("sm_fortressblast_gifthunt", "0", "Disables or enables Gift Hunt on maps with Gift Hunt .json files.");
	sm_fortressblast_gifthunt_countbots = CreateConVar("sm_fortressblast_gifthunt_countbots", "0", "Disables or enables counting bots as players when increasing the goal.");
	sm_fortressblast_gifthunt_goal = CreateConVar("sm_fortressblast_gifthunt_goal", "75", "Base number of gifts required to unlock the objective in Gift Hunt.");
	sm_fortressblast_gifthunt_increment = CreateConVar("sm_fortressblast_gifthunt_increment", "25", "Amount to increase the gift goal per extra group of players.");
	sm_fortressblast_gifthunt_multiply = CreateConVar("sm_fortressblast_gifthunt_multiply", "1", "Whether or not to multiply players' gift collections once they fall behind.");
	sm_fortressblast_gifthunt_players = CreateConVar("sm_fortressblast_gifthunt_players", "4", "Number of players in a group, any more and the gift goal increases.");
	sm_fortressblast_gifthunt_rate = CreateConVar("sm_fortressblast_gifthunt_rate", "20", "Chance out of 100 for each gift to spawn once all gifts are collected.");
	sm_fortressblast_intro = CreateConVar("sm_fortressblast_intro", "1", "Disables or enables automatically display the plugin intro message.");
	sm_fortressblast_mannpower = CreateConVar("sm_fortressblast_mannpower", "2", "How to handle replacing Mannpower powerups.");
	sm_fortressblast_powerups = CreateConVar("sm_fortressblast_powerups", "-1", "Bitfield of which powerups to enable.");
	sm_fortressblast_powerups_roundstart = CreateConVar("sm_fortressblast_powerups_roundstart", "1", "Disables or enables automatically spawning powerups on round start.");
	sm_fortressblast_ultra_spawnchance = CreateConVar("sm_fortressblast_ultra_spawnchance", "0.1", "Chance out of 100 for ULTRA POWERUP!! to spawn.");

	// HUDs
	PowerupText = CreateHudSynchronizer();
	GiftText = CreateHudSynchronizer();
	if (LateLoad) {
		GetSpawns(false);
	}
	// In case the plugin is reloaded mid-round
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			OnClientPutInServer(client);
		}
	}
}

public void OnPluginEnd() {
	RemoveAllPowerups();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max){
	if (late) {
		LateLoad = true;
	}
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
	PrecacheSound("fortressblast2/becomesentry_pickup.mp3");
	PrecacheSound("fortressblast2/ghost_pickup.mp3");
	PrecacheSound("fortressblast2/catapult_pickup.mp3");
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
	AddFileToDownloadsTable("sound/fortressblast2/becomesentry_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/ghost_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/catapult_pickup.mp3");

	// Powerup model and sound precaching for non-custom content
	PrecacheModel("models/props_halloween/ghost_no_hat.mdl");
	PrecacheModel("models/props_halloween/ghost_no_hat_red.mdl");
	PrecacheSound("items/spawn_item.wav");
	PrecacheSound("physics/flesh/flesh_impact_bullet2.wav");
	PrecacheSound("vo/halloween_boo1.mp3");
	PrecacheSound("vo/halloween_boo2.mp3");
	PrecacheSound("vo/halloween_boo3.mp3");
	PrecacheSound("vo/halloween_boo4.mp3");
	PrecacheSound("vo/halloween_boo5.mp3");
	PrecacheSound("vo/halloween_boo6.mp3");
	PrecacheSound("vo/halloween_boo7.mp3");
	PrecacheSound("vo/halloween_moan1.mp3");
	PrecacheSound("vo/halloween_moan2.mp3");
	PrecacheSound("vo/halloween_moan3.mp3");
	PrecacheSound("vo/halloween_moan4.mp3");
	PrecacheSound("weapons/cleaver_hit_02.wav");
	PrecacheSound("weapons/jar_explode.wav");

	// Scream Fortress sound precaching for non-custom sounds
	PrecacheSound("items/halloween/cat02.wav");
	PrecacheSound("items/halloween/cat03.wav");
	PrecacheSound("items/halloween/witch01.wav");
	PrecacheSound("items/halloween/witch02.wav");
	PrecacheSound("items/halloween/witch03.wav");
	PrecacheSound("misc/halloween/hwn_bomb_flash.wav");

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
	if (client != 0 && !(GetUserFlagBits(client) & AdminFlagInit()) && !(GetUserFlagBits(client) & ADMFLAG_ROOT) && !sm_fortressblast_debug.BoolValue) {
		CPrintToChat(client, "%s {red}You do not have permission to use this command.", MESSAGE_PREFIX);
		return false;
	}
	return true;
}

public Action sm_fortressblast(int client, int args) {
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
	sm_fortressblast_action_use.GetString(action, sizeof(action));
	Format(url, sizeof(url), "https://fortress-blast.github.io/%s?powerups-enabled=%d&action=%s&gifthunt=%b&ultra=%f&scream=%b", MOTD_VERSION, bitfield, action, sm_fortressblast_gifthunt.BoolValue, sm_fortressblast_ultra_spawnchance.FloatValue, ScreamFortress());
	AdvMOTD_ShowMOTDPanel(client, "", url, MOTDPANEL_TYPE_URL, true, true, true, INVALID_FUNCTION);
	QueryClientConVar(client, "cl_disablehtmlmotd", OnMOTDDisabledCheck); // Check if HTML MOTDs are disabled
	return Plugin_Handled;
}

// HTML MOTDs are disabled
public void OnMOTDDisabledCheck(QueryCookie cookie, int client, ConVarQueryResult result, const char[] name, const char[] value) {
	if (StringToInt(value) != 0) {
		CPrintToChat(client, "%s {haunted}The Fortress Blast manual failed to open because you have MOTDs disabled. Type {yellow}cl_disablehtmlmotd 0{haunted} into your developer console then try again.", MESSAGE_PREFIX);
	}
}

public Action sm_coordsjson(int client, int args) {
	if (client == 0) {
		PrintToServer("%s Because this command uses the crosshair, it cannot be executed from the server console.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}
	float points[3];
	GetCollisionPoint(client, points);
	CPrintToChat(client, "{haunted}\"#-x\": \"%d\", \"#-y\": \"%d\", \"#-z\": \"%d\",", RoundFloat(points[0]), RoundFloat(points[1]), RoundFloat(points[2]));
	return Plugin_Handled;
}

public Action sm_respawnpowerups(int client, int args){
	if (!AdminCommand(client)) {
		return Plugin_Handled;
	}
	RemoveAllPowerups();
	GetSpawns(false);
	return Plugin_Handled;
}

public Action sm_setpowerup(int client, int args) {
	if (!AdminCommand(client)) {
		return Plugin_Handled;
	}
	char arg[MAX_NAME_LENGTH + 1];
	char arg2[3];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	int newpowerup = StringToInt(arg2);
	if (client == 0 && StrEqual(arg2, "")) {
		PrintToServer("%s You must specify a player and powerup number.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	} else if (StrEqual(arg, "") && StrEqual(arg2, "")) {
		CPrintToChat(client, "%s {red}You must specify a powerup number.", MESSAGE_PREFIX);
		return Plugin_Handled;
	}
	if ((StrEqual(arg, "0") || StringToInt(arg) != 0) && StrEqual(arg2, "")) { // Name of target not included, act on client
		CollectedPowerup(client, StringToInt(arg));
	} else if (StrContains(arg, "@") != -1) {
		for (int client2 = 1; client2 <= MaxClients; client2++) {
			if (IsClientInGame(client2) && ((GetClientTeam(client) == 2 && StrEqual(arg, "@red")) || (GetClientTeam(client) == 3 && StrEqual(arg, "@blue")) || (client2 == client && StrEqual(arg, "@me")) || StrEqual(arg, "@all"))) {
				CollectedPowerup(client2, newpowerup);
			}
		}
	} else {
		int player = FindTarget(client, arg, false, false);
		if (0 < player <= MaxClients && IsClientInGame(player)) {
			CollectedPowerup(player, newpowerup);
		}
	}
	return Plugin_Handled;
}

public Action sm_spawnpowerup(int client, int args) {
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

public Action eureka_teleport(int client, int args){
	if(UsingPowerup[8][client]){
		return Plugin_Handled;
	}
	return Plugin_Continue;
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
	}
	delete trace;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) {
	return entity > MaxClients;
}

/* Powerups, Gifts and Respawn Room initialisation
==================================================================================================== */

public Action teamplay_round_start(Event event, const char[] name, bool dontBroadcast) {
	VictoryTeam = -1;
	PlayersAmount = 0;
	if (!GameRules_GetProp("m_bInWaitingForPlayers")) {
		for (int client = 1; client <= MaxClients; client++) {
			Powerup[client] = 0;
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
	if (sm_fortressblast_powerups_roundstart.BoolValue) {
		GetSpawns(false);
	}
	// Replace Mannpower powerups
	if (FindEntityByClassname(0, "tf_logic_mannpower") != -1 && sm_fortressblast_mannpower.IntValue != 0) {
		for (int entity = 1; entity <= MAX_EDICTS; entity++) {
			if (IsValidEntity(entity)) {
				char classname[60];
				GetEntityClassname(entity, classname, sizeof(classname));
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
	GiftsCollected[2] = 0;
	GiftsCollected[3] = 0;
}

public void GetSpawns(bool UsingGiftHunt) {
	char map[80];
	GetCurrentMap(map, sizeof(map));
	char path[PLATFORM_MAX_PATH + 1];
	// So we dont overload read-writes
	Format(path, sizeof(path), "scripts/fortress_blast/powerup_spots/%s.json", map);
	MapHasJsonFile = FileExists(path);
	// Forcibly disable leftover Gift Hunt attributes
	GiftHunt = false;
	GiftHuntAttackDefense = false;
	GiftHuntNeutralFlag = false;
	// Check for Gift Hunt
	if (sm_fortressblast_gifthunt.BoolValue) {
		Format(path, sizeof(path), "scripts/fortress_blast/gift_spots/%s.json", map);
		GiftHunt = FileExists(path);
		if (GiftHunt) {
			InsertServerTag("gifthunt");
			GiftMultiplier[2] = 1;
			GiftMultiplier[3] = 1;
			// For single-team objective maps like Attack/Defense and Payload
			JSONObject handle = JSONObject.FromFile(path);
			if (handle.HasKey("mode")) {
				char mode[30];
				handle.GetString("mode", mode, sizeof(mode));
				GiftHuntAttackDefense = StrEqual(mode, "attackdefense", true);
				if (GiftHuntAttackDefense) {
					GiftHuntSetup = true;
				}
			}
			// Disable capturing control points
			EntFire("trigger_capture_area", "SetTeamCanCap", "2 0");
			EntFire("trigger_capture_area", "SetTeamCanCap", "3 0");
			// Disable collecting intelligences
			int flag;
			while ((flag = FindEntityByClassname(flag, "item_teamflag")) != -1) {
				DispatchKeyValue(flag, "VisibleWhenDisabled", "1");
				AcceptEntityInput(flag, "Disable");
				// Neutral intelligence support
				if (GetEntProp(flag, Prop_Send, "m_iTeamNum") == 0) {
					GiftHuntNeutralFlag = true;
				}
			}
			// Disable Arena and King of the Hill control point cooldown
			if (FindEntityByClassname(1, "tf_logic_arena") != -1) {
				DispatchKeyValue(FindEntityByClassname(1, "tf_logic_arena"), "CapEnableDelay", "0");
			} else if (FindEntityByClassname(1, "tf_logic_koth") != -1) {
				DispatchKeyValue(FindEntityByClassname(1, "tf_logic_koth"), "timer_length", "0");
				DispatchKeyValue(FindEntityByClassname(1, "tf_logic_koth"), "unlock_point", "0");
			}
		}
	}
	if (!UsingGiftHunt && !MapHasJsonFile) {
		PrintToServer("%s No powerup locations .json file for this map! You can download pre-made files from the official maps repository:", MESSAGE_PREFIX_NO_COLOR);
		PrintToServer("https://github.com/Fortress-Blast/Fortress-Blast-Maps");
		return;
	} else if (UsingGiftHunt && !GiftHunt) {
		return;
	}
	if (!UsingGiftHunt) {
		Format(path, sizeof(path), "scripts/fortress_blast/powerup_spots/%s.json", map);
		GlobalVerifier = GetGameTickCount(); // Large integer used to avoid duplicate powerups where possible
	} else {
		Format(path, sizeof(path), "scripts/fortress_blast/gift_spots/%s.json", map);
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
			if (UsingGiftHunt && (GetSMRandomInt(0, 99) >= sm_fortressblast_gifthunt_rate.IntValue)) {
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
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "tf_halloween_pickup")) != -1) {
		if (0 < entity <= MAX_EDICTS && IsValidEntity(entity)) {
			RemoveEntity(entity);
		}
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

public Action teamplay_setup_finished(Event event, const char[] name, bool dontBroadcast) {
	if (GiftHuntAttackDefense) {
		GiftHuntSetup = false;
		EntFire("team_round_timer", "Pause");
	}
}

/* OnEntityDestroyed()
==================================================================================================== */

public void OnEntityDestroyed(int entity) {
	if (IsValidEntity(entity) && entity > 0) {
		DebugText("Destroying handle for ID %d", entity);
		delete DestroyPowerupHandle[entity];
		char classname[60];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "tf_halloween_pickup") && Powerup[entity] == 0) { // This is just an optimizer, the same thing would happen without this but slower
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
		// Return control to player after sentry from Become Sentry is destroyed
		if (StrEqual(classname, "obj_sentrygun")) {
			for (int client = 1; client <= MaxClients; client++) {
				if (IsClientInGame(client)) {
					if (Building[client] == entity) {
						Building[client] = -1;
						SetClientViewEntity(client, client);
						SetThirdPerson(client, false);
						ColorizePlayer(client, {255, 255, 255, 255});
						SetEntityMoveType(client, MOVETYPE_WALK);
						SetVariantString("1 0");
						AcceptEntityInput(client, "SetModelScale");
						SetEntityHealth(client, PreSentryHealth[client]);
					}
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
		if (GiftHuntIncrementTime < GetGameTime() && (GiftsCollected[2] >= GiftGoal || GiftsCollected[3] >= GiftGoal) && sm_fortressblast_gifthunt_multiply.BoolValue) {
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
					if (SuperSpeed[client] > 520.0 && OldSpeed[client] < 520.0) {
						SuperSpeed[client] = 520.0; // Capping manually, TF2 caps it itself but footsteps sound weird without this
					}
					SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", SuperSpeed[client]);
				}
				SpeedRotationsLeft[client]--;
				if (SpeedRotationsLeft[client] == 0) {
					RemoveSpeedBonus(client);
				}
			}
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
		if (Powerup[entity] == 0) {
			totalgifts++;
		}
	}
	return totalgifts;
}

/* Introductory Message
==================================================================================================== */

public Action Timer_DisplayIntro(Handle timer, int client) {
	if (IsClientInGame(client)) { // Required because player might disconnect before this fires
		CPrintToChat(client, "%s {haunted}This server is running %s {yellow}v%s!", MESSAGE_PREFIX, FancyPluginName(), PLUGIN_VERSION);
		CPrintToChat(client, "{haunted}If you would like to know more or are unsure what a powerup does, type the command {yellow}!fortressblast {haunted}into chat.");
	}
}

stock char FancyPluginName() {
	char intro[500];
	if (ScreamFortress()) {
		intro = "{chocolate}Fo{darkgoldenrod}rt{darkorange}re{orange}ss {cornflowerblue}B{royalblue}l{slateblue}a{darkslateblue}s{darkslategray}t";
	} else if (Smissmas()) {
		intro = "{salmon}F{limegreen}o{salmon}r{limegreen}t{salmon}r{limegreen}e{salmon}s{limegreen}s {salmon}B{limegreen}l{salmon}a{limegreen}s{salmon}t";
	} else if (AprilFools()) {
		intro = "{red}F{orange}o{yellow}r{green}t{cyan}r{blue}e{pink}s{blue}s {cyan}B{green}l{yellow}a{orange}s{red}t";
	} else {
		intro = "{yellow}Fortress Blast";
	}
	return intro;
}

/* Events
==================================================================================================== */

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast) {
	VictoryTeam = event.GetInt("team");
	DebugText("Team #%d has won the round", event.GetInt("team"));
}

public Action player_death(Event event, const char[] name, bool dontBroadcast) {
	Powerup[GetClientOfUserId(event.GetInt("userid"))] = 0;
	// Is dropping powerups enabled
	if (sm_fortressblast_drop.IntValue == 2 || (sm_fortressblast_drop.BoolValue && !MapHasJsonFile)) {
		// Get chance a powerup will be dropped
		float convar = sm_fortressblast_drop_rate.FloatValue;
		float randomNumber = GetSMRandomFloat(0.0, 99.99);
		if (convar > randomNumber && (sm_fortressblast_drop_teams.IntValue == GetClientTeam(GetClientOfUserId(event.GetInt("userid"))) || sm_fortressblast_drop_teams.IntValue == 1)) {
			DebugText("Dropping powerup due to player death");
			float coords[3];
			GetEntPropVector(GetClientOfUserId(event.GetInt("userid")), Prop_Send, "m_vecOrigin", coords);
			int entity = SpawnPowerup(coords, false);
			delete DestroyPowerupHandle[entity];
			DestroyPowerupHandle[entity] = CreateTimer(15.0, Timer_DestroyPowerupTime, entity);
			DebugText("Destroyed old timer and made new one for %d", entity);
		}
	}
	// Kill sentry tied to player due to Become Sentry
	if (IsValidEntity(Building[GetClientOfUserId(event.GetInt("userid"))])) {
		SetVariantInt(864);
		AcceptEntityInput(Building[GetClientOfUserId(event.GetInt("userid"))], "RemoveHealth");
		Building[GetClientOfUserId(event.GetInt("userid"))] = -1;
	}
}

public void OnClientDisconnect(int client) {
	// Kill sentry tied to player due to Become Sentry
	if (IsValidEntity(Building[client])) {
		SetVariantInt(864);
		AcceptEntityInput(Building[client], "RemoveHealth");
		Building[client] = -1;
	}
}

public Action Timer_DestroyPowerupTime(Handle timer, int entity) {
	DestroyPowerupHandle[entity] = null;
	RemoveEntity(entity);
	DebugText("Just deleted expired powerup ID %d", entity);
}

public void OnClientPutInServer(int client) {
	Powerup[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	SDKHook(client, SDKHook_StartTouch, OnStartTouchFrozen);
	if (sm_fortressblast_intro.BoolValue) {
		CreateTimer(3.0, Timer_DisplayIntro, client);
	}
	DizzyProgress[client] = -1;
	Building[client] = -1;
}

/* SpawnPowerup() + SpawnGift()
==================================================================================================== */

stock int SpawnPowerup(float location[3], bool respawn, int id = 0) {
	int entity = CreateEntityByName("tf_halloween_pickup");
	DispatchKeyValue(entity, "powerup_model", "models/fortressblast/pickups/fb_pickup.mdl");
	if (IsValidEdict(entity)) {
		if (id == 0) {
			if (sm_fortressblast_ultra_spawnchance.FloatValue > GetSMRandomFloat(0.0, 99.99)) {
				Powerup[entity] = -1;
			} else {
				Powerup[entity] = GetSMRandomInt(1, NumberOfPowerups);
				while (!PowerupIsEnabled(Powerup[entity]) || (Powerup[entity] == 16 && !ScreamFortress())) {
					Powerup[entity] = GetSMRandomInt(1, NumberOfPowerups);
				}
			}
		} else {
			Powerup[entity] = id;
		}
		// Set colors
		if (Powerup[entity] == 1) {
			SetEntityRenderColor(entity, 85, 102, 255, 255);
		} else if (Powerup[entity] == 2) {
			SetEntityRenderColor(entity, 255, 0, 0, 255);
		} else if (Powerup[entity] == 3) {
			SetEntityRenderColor(entity, 255, 119, 17, 255);
		} else if (Powerup[entity] == 4) {
			SetEntityRenderColor(entity, 255, 85, 119, 255);
		} else if (Powerup[entity] == 5) {
			SetEntityRenderColor(entity, 0, 204, 0, 255);
		} else if (Powerup[entity] == 6) {
			SetEntityRenderColor(entity, 136, 255, 170, 255);
		} else if (Powerup[entity] == 7) {
			SetEntityRenderColor(entity, 255, 255, 0, 255);
		} else if (Powerup[entity] == 8) {
			SetEntityRenderColor(entity, 85, 85, 85, 255);
		} else if (Powerup[entity] == 9) {
			SetEntityRenderColor(entity, 255, 187, 255, 255);
		} else if (Powerup[entity] == 10) {
			SetEntityRenderColor(entity, 0, 0, 0, 255);
		} else if (Powerup[entity] == 11) {
			SetEntityRenderColor(entity, 255, 153, 153, 255);
		} else if (Powerup[entity] == 12) {
			SetEntityRenderColor(entity, 0, 68, 0, 255);
		} else if (Powerup[entity] == 13) {
			SetEntityRenderColor(entity, 218, 182, 72, 255);
		} else if (Powerup[entity] == 14) {
			SetEntityRenderColor(entity, 36, 255, 255, 255);
		} else if (Powerup[entity] == 15) {
			SetEntityRenderColor(entity, 255, 0, 255, 255);
		} else if (Powerup[entity] == 16) {
			SetEntityRenderColor(entity, 109, 72, 182, 255);
		} else if (Powerup[entity] == 17) {
			SetEntityRenderColor(entity, 255, 102, 85, 255);
		} else if (Powerup[entity] == -1) {
			Handle kv = CreateKeyValues("");
			KvSetNum(kv, "powerup", entity);
			KvSetNum(kv, "rainbowid", 0);
			CreateTimer(0.0, UpdateUltraPowerupColor, kv);
		}
		// End colors
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

public Action UpdateUltraPowerupColor(Handle timer, Handle kv) {
	int powerup = KvGetNum(kv, "powerup");
	int rainbowid = KvGetNum(kv, "rainbowid");
	if (!IsValidEntity(powerup) || Powerup[powerup] != -1) {
		return;
	}
	if (rainbowid > 7) {
		rainbowid = 0;
	}
	if (rainbowid == 0) {
		SetEntityRenderColor(powerup, 255, 0, 0, 255); // Red
	}
	if (rainbowid == 1) {
		SetEntityRenderColor(powerup, 255, 128, 0, 255); // Orange
	}
	if (rainbowid == 2) {
		SetEntityRenderColor(powerup, 255, 255, 0, 255); // Yellow
	}
	if (rainbowid == 3) {
		SetEntityRenderColor(powerup, 0, 255, 145, 255); // Green
	}
	if (rainbowid == 4) {
		SetEntityRenderColor(powerup, 36, 255, 255, 255); // Cyan
	}
	if (rainbowid == 5) {
		SetEntityRenderColor(powerup, 85, 102, 255, 255); // Blue
	}
	if (rainbowid == 6) {
		SetEntityRenderColor(powerup, 109, 0, 255, 255); // Purple
	}
	if (rainbowid == 7) {
		SetEntityRenderColor(powerup, 255, 0, 218, 255); // Magenta
	}
	Handle kv2 = CreateKeyValues("");
	KvSetNum(kv2, "powerup", powerup);
	KvSetNum(kv2, "rainbowid", rainbowid + 1);
	CreateTimer(0.5, UpdateUltraPowerupColor, kv2);
	CloseHandle(kv);
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
		Powerup[entity] = 0;
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

public void CollectedPowerup(int client, int newpowerup) {
	Powerup[client] = newpowerup;
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (Powerup[client] == -1) {
		EmitSoundToClient(client, "fortressblast2/ultrapowerup_pickup.mp3", client);
	} else if (Powerup[client] == 1) {
		EmitSoundToClient(client, "fortressblast2/superbounce_pickup.mp3", client);
	} else if (Powerup[client] == 2) {
		EmitSoundToClient(client, "fortressblast2/shockabsorber_pickup.mp3", client);
	} else if (Powerup[client] == 3) {
		EmitSoundToClient(client, "fortressblast2/superspeed_pickup.mp3", client);
	} else if (Powerup[client] == 4) {
		EmitSoundToClient(client, "fortressblast2/superjump_pickup.mp3", client);
	} else if (Powerup[client] == 5) {
		EmitSoundToClient(client, "fortressblast2/gyrocopter_pickup.mp3", client);
	} else if (Powerup[client] == 6) {
		EmitSoundToClient(client, "fortressblast2/timetravel_pickup.mp3", client);
	} else if (Powerup[client] == 7) {
		EmitSoundToClient(client, "fortressblast2/blast_pickup.mp3", client);
	} else if (Powerup[client] == 8) {
		EmitSoundToClient(client, "fortressblast2/megamann_pickup.mp3", client);
	} else if (Powerup[client] == 9) {
		EmitSoundToClient(client, "fortressblast2/frosttouch_pickup.mp3", client);
	} else if (Powerup[client] == 10) {
		EmitSoundToClient(client, "fortressblast2/mystery_pickup.mp3", client);
	} else if (Powerup[client] == 11) {
		EmitSoundToClient(client, "fortressblast2/teleportation_pickup.mp3", client);
	} else if (Powerup[client] == 12) {
		EmitSoundToClient(client, "fortressblast2/magnetism_pickup.mp3", client);
	} else if (Powerup[client] == 13) {
		EmitSoundToClient(client, "fortressblast2/effectburst_pickup.mp3", client);
	} else if (Powerup[client] == 14) {
		EmitSoundToClient(client, "fortressblast2/dizzybomb_pickup.mp3", client);
	} else if (Powerup[client] == 15) {
		EmitSoundToClient(client, "fortressblast2/becomesentry_pickup.mp3", client);
	} else if (Powerup[client] == 16) {
		EmitSoundToClient(client, "fortressblast2/ghost_pickup.mp3", client);
	} else if (Powerup[client] == 17) {
		EmitSoundToClient(client, "fortressblast2/catapult_pickup.mp3", client);
	}
	// If player is a bot and bot support is enabled
	if (IsFakeClient(client) && sm_fortressblast_bot.BoolValue && !BlockPowerup(client, 0)) {
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
		CreateTimer(GetSMRandomFloat(convar1, convar2), Timer_BotUsePowerup, client);
	}
}

public Action Timer_BotUsePowerup(Handle timer, int client) {
	if (IsClientInGame(client) && !BlockPowerup(client, 0)) {
		// May need to look into getting a bot to try again a couple of times if powerup is blocked
		DebugText("Forcing bot %N to use powerup ID %d", client, Powerup[client]);
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
		sm_fortressblast_action_use.GetString(button, sizeof(button));
		CPrintToChat(client, "%s {red}Special attack is currently disabled on this server. You are required to {yellow}perform the '%s' action to use a powerup.", MESSAGE_PREFIX, button);
	} else if (buttons & ActionInit() && !BlockPowerup(client, 0)) {
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
	if (IsValidEntity(Building[client])) {
		BlockAttacking(client, 0.5);
		SetEntityHealth(client, GetEntProp(Building[client], Prop_Send, "m_iHealth"));
		buttons &= ~IN_DUCK;
		// User wants to leave sentry, kill the sentry
		if (!GetEntProp(Building[client], Prop_Send, "m_bHasSapper") && (buttons & IN_ATTACK || buttons & IN_JUMP) && GetGameTime() > ExitSentryTime[client]) {
			SetVariantInt(864);
			AcceptEntityInput(Building[client], "RemoveHealth");
		}
	}
	if (UsingPowerup[16][client]) {
		float coords1[3];
		GetClientAbsOrigin(client, coords1);
		for (int client2 = 1 ; client2 <= MaxClients ; client2++) {
			if (IsClientInGame(client2) && GetClientTeam(client2) > 1 && GetClientTeam(client2) != GetClientTeam(client)) {
				float coords2[3];
				GetClientAbsOrigin(client2, coords2);
				if (GetVectorDistance(coords1, coords2) <= 200.0) {
					if (!TF2_IsPlayerInCondition(client2, TFCond_Dazed)) {
						int boorandom = GetSMRandomInt(1, 7);
						if (boorandom == 1) {
							EmitAmbientSound("vo/halloween_boo1.mp3", vel, client);
						} else if (boorandom == 2) {
							EmitAmbientSound("vo/halloween_boo2.mp3", vel, client);
						} else if (boorandom == 3) {
							EmitAmbientSound("vo/halloween_boo3.mp3", vel, client);
						} else if (boorandom == 4) {
							EmitAmbientSound("vo/halloween_boo4.mp3", vel, client);
						} else if (boorandom == 5) {
							EmitAmbientSound("vo/halloween_boo5.mp3", vel, client);
						} else if (boorandom == 6) {
							EmitAmbientSound("vo/halloween_boo6.mp3", vel, client);
						} else if (boorandom == 7) {
							EmitAmbientSound("vo/halloween_boo7.mp3", vel, client);
						}
					}
					TF2_StunPlayer(client2, 2.0, _, TF_STUNFLAGS_GHOSTSCARE, 0);
				}
			}
		}
	}
}

public bool BlockPowerup(int client, int testpowerup) {
	if (testpowerup == 0) {
		testpowerup = Powerup[client];
	}
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
	// Player is a building
	} else if (IsValidEntity(Building[client])) {
		return true;
	// Mega Mann pre-stuck checking
	} else if (testpowerup == 8 && !UsingPowerup[8][client]) {
		if(TF2_IsPlayerInCondition(client, TFCond_Teleporting)){
			return true;// don't allow using mega mann while about to teleport
		}
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
	// Become Sentry buildable area checking
	} else if (((testpowerup == 15) && !(GetEntityFlags(client) & FL_ONGROUND)) || (GetEntityFlags(client) & FL_INWATER)) {
		return true;
	// Mystery other powerup checking
	} else if (testpowerup == 10) {
		bool allblocked = true;
		for (int i = 1 ; i <= NumberOfPowerups ; i++) {
			if (i != 10 && PowerupIsEnabled(i) && !BlockPowerup(client, i)) {
				allblocked = false;
			}
		}
		if (allblocked) {
			return true;
		}
	} else if (testpowerup == 16) {
		if(!ScreamFortress()){// these can't even spawn without scream fortress, this is just here for mystery
			return true;
		}
	}
	return false;
}

/* UsePowerup()
==================================================================================================== */

public void UsePowerup(int client) {
	if (Powerup[client] > 0) {
		UsingPowerup[Powerup[client]][client] = true; // Double array, client is using powerup
	}
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (Powerup[client] == -1) {
		// Ultra Powerup - Multiple effects
		delete UltraPowerupHandle[client];
		UltraPowerup[client] = true;
		UltraPowerupHandle[client] = CreateTimer(10.0, Timer_RemoveUltraPowerup, client);
		// Super Bounce, Super Jump, Gyrocopter, Time Travel, Blast, Mystery, Teleportation, Effect Burst and Dizzy Bomb are not included
		// Shock Absorber already set
		SpeedRotationsLeft[client] += 100; // Super Speed, for 10 seconds, slightly faster
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
	} else if (Powerup[client] == 1) {
		// Super Bounce - Uncontrollable bunny hop and fall damage resistance for 5 seconds
		EmitAmbientSound("fortressblast2/superbounce_use.mp3", vel, client);
		VerticalVelocity[client] = 0.0; // Cancel previously stored vertical velocity
		delete SuperBounceHandle[client];
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
	} else if (Powerup[client] == 2) {
		// Shock Absorber - 75% damage and 100% knockback resistances for 5 seconds
		EmitAmbientSound("fortressblast2/shockabsorber_use.mp3", vel, client);
		delete ShockAbsorberHandle[client];
		ShockAbsorberHandle[client] = CreateTimer(5.0, Timer_RemoveShockAbsorb, client);
		ParticleOnPlayer(client, "teleporter_red_charged_level2", 5.0, 0.0);
	} else if (Powerup[client] == 3) {
		// Super Speed - Increased speed, gradually wears off over 10 seconds
		SpeedRotationsLeft[client] += 80;
		EmitAmbientSound("fortressblast2/superspeed_use.mp3", vel, client);
	} else if (Powerup[client] == 4) {
		// Super Jump - Launch user into air
		if (ScreamFortress()) {
			EmitAmbientSound("items/halloween/witch01.wav", vel, client);
			if (TF2_GetClientTeam(client) == TFTeam_Red) {
				ParticleOnPlayer(client, "spell_batball_impact_red", 1.0, 0.0);
			} else if (TF2_GetClientTeam(client) == TFTeam_Blue) {
				ParticleOnPlayer(client, "spell_batball_impact_blue", 1.0, 0.0);
			}
		}
		if (UsingPowerup[8][client]) {
			vel[2] += 600.0; // Slightly reduced velocity due to Mega Mann
		} else {
			vel[2] += 800.0;
		}
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
		EmitAmbientSound("fortressblast2/superjump_use.mp3", vel, client);
	} else if (Powerup[client] == 5) {
		// Gyrocopter - 25% gravity for 5 seconds
		if (ScreamFortress()) {
			if (GetSMRandomInt(1, 2) == 1) {
				EmitAmbientSound("items/halloween/witch02.wav", vel, client);
			} else {
				EmitAmbientSound("items/halloween/witch03.wav", vel, client);
			}
			// Particle only lasts for 3 seconds, need to play twice to fill out 5 seconds
			if (TF2_GetClientTeam(client) == TFTeam_Red) {
				ParticleOnPlayer(client, "spell_batball_red", 5.0, 0.0);
			} else if (TF2_GetClientTeam(client) == TFTeam_Blue) {
				ParticleOnPlayer(client, "spell_batball_blue", 5.0, 0.0);
			}
		}
		if (UsingPowerup[1][client] && AprilFools()) {
			SetEntityGravity(client, 0.75);
		} else {
			SetEntityGravity(client, 0.25);
		}
		delete GyrocopterHandle[client];
		GyrocopterHandle[client] = CreateTimer(5.0, Timer_RemoveGyrocopter, client);
		EmitAmbientSound("fortressblast2/gyrocopter_use.mp3", vel, client);
	} else if (Powerup[client] == 6) {
		// Time Travel - Increased speed, invisibility and can't attack for 5 seconds
		SetThirdPerson(client, true);
		TF2_AddCondition(client, TFCond_StealthedUserBuffFade, 3.0);
		BlockAttacking(client, 3.0);
		delete TimeTravelHandle[client];
		TimeTravelHandle[client] = CreateTimer(3.0, Timer_RemoveTimeTravel, client);
		EmitAmbientSound("fortressblast2/timetravel_use_3sec.mp3", vel, client);
	} else if (Powerup[client] == 7) {
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
		delete TimeTravelHandle[client];
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
	} else if (Powerup[client] == 8) {
		// Mega Mann - Giant and 4x health for 10 seconds
		EmitAmbientSound("fortressblast2/megamann_use.mp3", vel, client);
		int healthMultiplier = (TF2_GetPlayerClass(client) == TFClass_Heavy ? 3 : 4);
		SetEntityHealth(client, (GetClientHealth(client) * healthMultiplier)); // Multiply current health
		// Cap at expected multiplied maximum health
		if (GetClientHealth(client) > (GetPlayerMaxHealth(client) * healthMultiplier)) {
			SetEntityHealth(client, GetPlayerMaxHealth(client) * healthMultiplier);
		}
		delete MegaMannHandle[client];
		MegaMannHandle[client] = CreateTimer(10.0, Timer_RemoveMegaMann, client);
		// Push player up to avoid getting stuck in floor if not using Mega Mann
		if (!UsingPowerup[8][client]) {
			float coords[3] = 69.420;
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
			coords[2] += 16.0;
			TeleportEntity(client, coords, NULL_VECTOR, NULL_VECTOR);
		}
		SetVariantString("1.75 0");
		AcceptEntityInput(client, "SetModelScale");
		MegaMannVerified[client] = true;
	} else if (Powerup[client] == 9) {
		// Frost Touch - Freeze touched players for 3 seconds within 8 seconds
		EmitAmbientSound("fortressblast2/frosttouch_use.mp3", vel, client);
		delete FrostTouchHandle[client];
		FrostTouchHandle[client] = CreateTimer(8.0, Timer_RemoveFrostTouch, client);
		ParticleOnPlayer(client, "smoke_rocket_steam", 8.0, 32.0);
	} else if (Powerup[client] == 10) {
		// Mystery - Random powerup
		// Has a higher chance of picking Gyrocopter during April Fools
		if (GetSMRandomFloat(0.0, 99.99) < 75.0 && AprilFools() && PowerupIsEnabled(5)) {
			Powerup[client] = 5;
		} else {
			int mysrand = 10;
			while (mysrand == 10 || !PowerupIsEnabled(mysrand) || (BlockPowerup(client, mysrand) && !BlockPowerup(client, 10))) {
				mysrand = GetSMRandomInt(1, NumberOfPowerups);
			}
			Powerup[client] = mysrand;
		}
		UsePowerup(client);
	} else if (Powerup[client] == 11) {
		// Teleportation - Teleport to random active Engineer exit teleport or spawn
		delete TeleportationHandle[client];
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
	} else if (Powerup[client] == 12) {
		// Magnetism - Repel or attract enemies depending on weapon slot
		EmitAmbientSound("fortressblast2/magnetism_use.mp3", vel, client);
		delete MagnetismHandle[client];
		MagnetismHandle[client] = CreateTimer(5.0, Timer_RemoveMagnetism, client);
		// Repeatedly produce Magnetism particle
		float timeport = 0.1;
		ParticleOnPlayer(client, "ping_circle", 0.5, 0.0);
		for (int timepoint = 0 ; timepoint <= 50 ; timepoint++) {
			CreateTimer(timeport, MagnetismParticleRepeater, client);
			timeport = timeport + 0.1;
		}
	} else if (Powerup[client] == 13) {
		// Effect Burst - Afflict enemies with one of four random status effects
		EmitAmbientSound("fortressblast2/effectburst_use.mp3", vel, client);
		ParticleOnPlayer(client, "merasmus_dazed_explosion", 1.0, 0.0);
		float pos1[3];
		GetClientAbsOrigin(client, pos1);
		for (int client2 = 1 ; client2 <= MaxClients ; client2++) {
			if (IsClientInGame(client2) && GetClientTeam(client) != GetClientTeam(client2) && !IsValidEntity(Building[client2])) {
				float pos2[3];
				GetClientAbsOrigin(client2, pos2);
				if (GetVectorDistance(pos1, pos2) < 768.0) {
					int random = GetSMRandomInt(1, 4);
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
	} else if (Powerup[client] == 14) {
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
					NegativeDizzy[client2] = (GetSMRandomInt(0, 1) == 0); // Randomly decide which direction dizziness shoudl start in
					EmitSoundToClient(client2, "fortressblast2/dizzybomb_dizzy.mp3", client2);
					ParticleOnPlayer(client2, "conc_stars", sm_fortressblast_dizzy_length.FloatValue, 80.0);
				}
			}
		}
	} else if (Powerup[client] == 15) {
		MakeUserBuilding(client, "obj_sentrygun");
		ExitSentryTime[client] = GetGameTime() + 1.0;
	} else if (Powerup[client] == 16) {
		// Ghost - Turn user into ghost that scares nearby enemies
		int moanRandom = GetSMRandomInt(1, 4);
		if (moanRandom == 1) {
			EmitAmbientSound("vo/halloween_moan1.mp3", vel, client);
		} else if (moanRandom == 2) {
			EmitAmbientSound("vo/halloween_moan2.mp3", vel, client);
		} else if (moanRandom == 3) {
			EmitAmbientSound("vo/halloween_moan3.mp3", vel, client);
		} else {
			EmitAmbientSound("vo/halloween_moan4.mp3", vel, client);
		}
		delete GhostHandle[client];
		GhostHandle[client] = CreateTimer(5.0, Timer_RemoveGhost, GetClientUserId(client));
		TF2_AddCondition(client, TFCond_HalloweenGhostMode, 5.0);
	} else if (Powerup[client] == 17) {
		// Catapult - Launch user forward
		if (!AprilFools()) {
			// Need regular sound for Catapult
		} else {
			if (GetSMRandomInt(1, 2) == 1) {
				EmitAmbientSound("items/halloween/cat02.wav", vel, client);
			} else {
				EmitAmbientSound("items/halloween/cat03.wav", vel, client);
			}
		}
		float ang[3];
		GetClientEyeAngles(client, ang);
		ang[0] = -17.5;
		float vec[3] = {0.0, 0.0, 0.0};
		if (UsingPowerup[8][client]) {
			vec[0] = 600.0; // Slightly reduced velocity due to Mega Mann
		} else {
			vec[0] = 800.0;
		}
		float vel2[3];
		RotateVector(vec, ang, vel2);
		vel[0] += vel2[0];
		vel[1] += vel2[1];
		vel[2] += vel2[2];
		// Must lift player off ground in order to launch properly
		if (vel[2] < 270.0) {
			vel[2] = 270.0;
		}
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
	}
	Powerup[client] = 0;
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
	if (Powerup[entity] == 0) {
		CollectedGift(other);
		return;
	}
	if (0 < other <= MaxClients && IsClientInGame(other)) {
		CollectedPowerup(other, Powerup[entity]);
	}
}

public Action Timer_RespawnPowerup(Handle timer, Handle coordskv) {
	float coords[3];
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

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	if (damagecustom != TF_CUSTOM_TELEFRAG && damagecustom != TF_CUSTOM_BACKSTAB && (UsingPowerup[2][victim] || FrostTouchFrozen[victim] == 1 || UltraPowerup[victim])) {
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
	if ((UsingPowerup[1][victim] && attacker == 0 && damagecustom != TF_CUSTOM_TRIGGER_HURT) || IsValidEntity(Building[victim])) {
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
			delete FrostTouchUnfreezeHandle[other];
			FrostTouchUnfreezeHandle[other] = CreateTimer(3.0, Timer_FrostTouchUnfreeze, other);
			FrostTouchFrozen[other] = ((UltraPowerup[entity]) ? 2 : 1);
			BlockAttacking(other, 3.0);
		}
	}
}

public Action Timer_FrostTouchUnfreeze(Handle timer, int client) {
	FrostTouchUnfreezeHandle[client] = null;
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


/* Teleportation
==================================================================================================== */

public Action Timer_BeginTeleporter(Handle timer, int client) {
	TeleportationHandle[client] = null;
	if (!IsPlayerAlive(client)) {
		return; // Do not teleport dead player
	}
	if (UsingPowerup[8][client]) {
		delete MegaMannHandle[client];
		MegaMannHandle[client] = CreateTimer(0.0, Timer_RemoveMegaMann, client);
	}
	FakeClientCommand(client, "dropitem"); // Force player to drop intelligence
	int teles = GetTeamTeleporters(TF2_GetClientTeam(client));
	if (teles == 0) {
		TF2_RespawnPlayer(client);
		TeleportXmasParticles(client);
		return;
	}
	int eli = GetSMRandomInt(1, teles);
	DebugText("Teleporter number %d has been selected", eli);
	int countby = 1;
	int entity;
	while ((entity = FindEntityByClassname(entity, "obj_teleporter")) != -1) {
		if (TF2_GetClientTeam(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")) == TF2_GetClientTeam(client) && TF2_GetObjectMode(entity) == TFObjectMode_Exit && BuildingPassesNetprops(entity)) {
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
		if (TF2_GetClientTeam(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")) == team && TF2_GetObjectMode(entity) == TFObjectMode_Exit && BuildingPassesNetprops(entity)) {
			amounter++;
		}
	}
	DebugText("Teleporting a player with %d active teleporters", amounter);
	return amounter;
}

public bool BuildingPassesNetprops(int entity) {
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

/* MakeUserBuilding()
==================================================================================================== */

public void MakeUserBuilding(int client, const char[] buildingname) { // Become Sentry
	PreSentryHealth[client] = GetClientHealth(client);
	Building[client] = CreateEntityByName(buildingname);
	DispatchKeyValue(Building[client], "defaultupgrade", "1");
	SetVariantInt(GetClientTeam(client));
	AcceptEntityInput(Building[client], "SetTeam");
	SetVariantInt((GetClientTeam(client) * -1) + 4);
	AcceptEntityInput(Building[client], "Skin");
	SetVariantInt(1);
	AcceptEntityInput(Building[client], "SetSolidToPlayer");
	float coords[3];
	GetClientAbsOrigin(client, coords);
	float angles[3];
	GetClientAbsAngles(client, angles);
	TeleportEntity(Building[client], coords, angles, NULL_VECTOR);
	DispatchSpawn(Building[client]);
	ActivateEntity(Building[client]);
	AcceptEntityInput(Building[client], "SetBuilder", client); // Do not use variant here, SetBuilder always sets to the caller
	SetVariantString("0.2");
	AcceptEntityInput(client, "SetModelScale");
	SetEntityMoveType(client, MOVETYPE_NONE);
	SetClientViewEntity(client, Building[client]);
	SetThirdPerson(client, true);
	ColorizePlayer(client, {0, 0, 0, 0});
	TeleportEntity(client, coords, NULL_VECTOR, NULL_VECTOR);
	BlockAttacking(client, 0.5);
}

/* RotateVector()
Vector rotation from smlib
==================================================================================================== */

void RotateVector(float points[3], float angles[3], float result[3]) {
	float rad[3];
	rad[0] = DegToRad(angles[2]);
	rad[1] = DegToRad(angles[0]);
	rad[2] = DegToRad(angles[1]);
	float cosAlpha = Cosine(rad[0]);
	float sinAlpha = Sine(rad[0]);
	float cosBeta = Cosine(rad[1]);
	float sinBeta = Sine(rad[1]);
	float cosGamma = Cosine(rad[2]);
	float sinGamma = Sine(rad[2]);
	float x = points[0];
	float y = points[1];
	float z = points[2];
	float newX, newY, newZ;
	newY = cosAlpha*y - sinAlpha*z;
	newZ = cosAlpha*z + sinAlpha*y;
	y = newY;
	z = newZ;
	newX = cosBeta*x + sinBeta*z;
	newZ = cosBeta*z - sinBeta*x;
	x = newX;
	z = newZ;
	newX = cosGamma*x - sinGamma*y;
	newY = cosGamma*y + sinGamma*x;
	x = newX;
	y = newY;
	result[0] = x;
	result[1] = y;
	result[2] = z;
}

/* Powerup Removal
==================================================================================================== */

public Action Timer_RemoveSuperBounce(Handle timer, int client) {
	SuperBounceHandle[client] = null;
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
	ShockAbsorberHandle[client] = null;
	UsingPowerup[2][client] = false;
}

public Action Timer_RemoveGyrocopter(Handle timer, int client) {
	UsingPowerup[5][client] = false;
	GyrocopterHandle[client] = null;
	if (IsClientInGame(client)) {
		if (UsingPowerup[1][client] && AprilFools()) {
			SetEntityGravity(client, 3.0);
		} else {
			SetEntityGravity(client, 1.0);
		}
	}
}

public Action Timer_RemoveTimeTravel(Handle timer, int client) {
	TimeTravelHandle[client] = null;
	UsingPowerup[6][client] = false;
	SetThirdPerson(client, false);
	if (IsClientInGame(client)) {
		RemoveSpeedBonus(client);
		float vel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
		if (ScreamFortress()) {
			EmitAmbientSound("misc/halloween/hwn_bomb_flash.wav", vel, client);
		}
	}
}

public Action Timer_RemoveFrostTouch(Handle timer, int client) {
	FrostTouchHandle[client] = null;
	UsingPowerup[9][client] = false;
}

public Action Timer_RemoveMegaMann(Handle timer, int client) {
	MegaMannHandle[client] = null;
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
	MagnetismHandle[client] = null;
	UsingPowerup[12][client] = false;
}

public Action Timer_RemoveUltraPowerup(Handle timer, int client) {
	UltraPowerupHandle[client] = null;
	UltraPowerup[client] = false;
	if (GetClientHealth(client) > GetPlayerMaxHealth(client)) {
		SetEntityHealth(client, GetPlayerMaxHealth(client));
	}
}


public Action Timer_RemoveGhost(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	if(client < 1){
		return;
	}
	GhostHandle[client] = null;
	UsingPowerup[16][client] = false;
}

/* DoHudText()
The HUD function for the plugin
On April Fools most of the powerups have the word 'Super' inserted into them
==================================================================================================== */

public void DoHudText(int client) {
	if (Powerup[client] != 0) {
		if (BlockPowerup(client, 0)) {
			SetHudTextParams(0.825, 0.5, 0.25, 255, 0, 0, 0);
		} else {
			SetHudTextParams(0.825, 0.5, 0.25, 255, 255, 0, 255);
		}
		if (Powerup[client] == -1) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nULTRA POWERUP!!");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSUPER POWERUP!!");
			}
		} else if (Powerup[client] == 1) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Bounce");
		} else if (Powerup[client] == 2) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nShock Absorber");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Absorber");
			}
		} else if (Powerup[client] == 3) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Speed");
		} else if (Powerup[client] == 4) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Jump");
		} else if (Powerup[client] == 5) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nGyrocopter");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Gyrocopter");
			}
		} else if (Powerup[client] == 6) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nTime Travel");
		} else if (Powerup[client] == 7) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nBlast");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Blast");
			}
		} else if (Powerup[client] == 8) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nMega Mann");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Mann");
			}
		} else if (Powerup[client] == 9) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nFrost Touch");
		} else if (Powerup[client] == 10) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nMystery");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Mystery");
			}
		} else if (Powerup[client] == 11) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nTeleportation");
		} else if (Powerup[client] == 12) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nMagnetism");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Magnetism");
			}
		} else if (Powerup[client] == 13) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nEffect Burst");
		} else if (Powerup[client] == 14) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nDizzy Bomb");
		} else if (Powerup[client] == 15) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nBecome Sentry");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Sentry");
			}
		} else if (Powerup[client] == 16) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nGhost");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Ghost");
			}
		} else if (Powerup[client] == 17) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nCatapult");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Catapult");
			}
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
		freeid = GetSMRandomInt(1, MAX_PARTICLES);
		RemoveEntity(PlayerParticle[client][freeid]);
		DebugText("All of %N's particles were in use, freeing #%d", client, freeid);
	}
	PlayerParticle[client][freeid] = particle;
	ParticleZAdjust[client][freeid] = zadjust;
	Handle partkv = CreateKeyValues("partkv");
	KvSetNum(partkv, "client", client);
	KvSetNum(partkv, "id", freeid);
	CreateTimer(time, Timer_RemoveParticle, partkv);
}

public Action Timer_RemoveParticle(Handle timer, Handle partkv) {
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
		CPrintToChatAll("{orange}[FB Debug] {default}%s", format);
		PrintToServer("[FB Debug] %s", format);
	}
}

/* ActionInit() + AdminFlagInit()
==================================================================================================== */

public int ActionInit() {
	char button[40];
	sm_fortressblast_action_use.GetString(button, sizeof(button));
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
	sm_fortressblast_admin_flag.GetString(flag, sizeof(flag));
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

/* Updated syntax stocks
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

stock int GetSMRandomInt(int min, int max) {
	int random = GetURandomInt();
	if (random == 0) {
		random++;
	}
	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock float GetSMRandomFloat(float min, float max) {
	return (GetURandomFloat() * (max  - min)) + min;
}

stock void RemoveSpeedBonus(int client) {
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);
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

public bool ScreamFortress() {
	int convar = sm_fortressblast_event_scream.IntValue;
	if (convar == 0) {
		return false;
	} else if (convar == 1) {
		return TF2_IsHolidayActive(TFHoliday_Halloween);
	}
	return true;
}

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
