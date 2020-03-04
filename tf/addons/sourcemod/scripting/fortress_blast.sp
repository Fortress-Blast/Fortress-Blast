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

// Math
#define PI 3.14159265359

public Plugin myinfo = {
	name = "Fortress Blast",
	author = "Benedevil, Jack5, Naleksuh & Rushy",
	description = "Adds powerups from Marble Blast into TF2! Can easily be combined with other plugins and game modes.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Fortress-Blast"
};

// Global Variables
int gi_NumberOfPowerups = 14; // Do not define this, excludes the Ultra Powerup
int gi_PlayersAmount;
int gi_GiftGoal;
int gi_CollectedGifts[4] = 0;
int gi_GiftBonus[4] = 1;
int gi_PowerUpID[MAX_EDICTS] = -1;
int gi_CollectedPowerup[MAXPLAYERS + 1] = 0;
int gi_PlayerParticle[MAXPLAYERS + 1][MAX_PARTICLES + 1];
int gi_SpeedRotationsLeft[MAXPLAYERS + 1] = 80;
int gi_VictoryTeam = -1;
int gi_DizzyProgress[MAXPLAYERS + 1] = -1;
int gi_FrostTouchFrozen[MAXPLAYERS + 1] = 0;
int gi_GlobalVerifier = 0;
bool gb_PreviousAttack3[MAXPLAYERS + 1] = false;
bool gb_MapHasJsonFile = false;
bool GiftHunt = false;
bool SuperBounce[MAXPLAYERS + 1] = false;
bool ShockAbsorber[MAXPLAYERS + 1] = false;
bool TimeTravel[MAXPLAYERS + 1] = false;
bool MegaMann[MAXPLAYERS + 1] = false;
bool FrostTouch[MAXPLAYERS + 1] = false;
bool gb_NegativeDizzy[MAXPLAYERS + 1] = false;
bool Magnetism[MAXPLAYERS + 1] = false;
bool UltraPowerup[MAXPLAYERS + 1] = false;
bool gb_MegaMannVerified[MAXPLAYERS + 1] = false;
bool gb_GiftHuntAttackDefense = false;
bool gb_GiftHuntNeutralFlag = false;
bool gb_GiftHuntSetup = false;
float gf_GiftHuntIncrementTime = 0.0;
float gf_OldSpeed[MAXPLAYERS + 1] = 0.0;
float gf_SuperSpeed[MAXPLAYERS + 1] = 0.0;
float gf_VerticalVelocity[MAXPLAYERS + 1];
float gf_ParticleZAdjust[MAXPLAYERS + 1][MAX_PARTICLES + 1];
Handle gh_SuperBounce[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle gh_ShockAbsorber[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle gh_Gyrocopter[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle gh_TimeTravel[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle gh_MegaMann[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle gh_FrostTouch[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle gh_FrostTouchUnfreeze[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle gh_DestroyPowerup[MAX_EDICTS + 1] = INVALID_HANDLE;
Handle gh_Teleportation[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle gh_Magnetism[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle gh_UltraPowerup[MAXPLAYERS+1] = INVALID_HANDLE;

// HUDs
Handle ghud_PowerupText;
Handle ghud_GiftText;

// ConVars
ConVar gc_sm_fortressblast_action;
ConVar gc_sm_fortressblast_adminflag;
ConVar gc_sm_fortressblast_blast_buildings;
ConVar gc_sm_fortressblast_bot;
ConVar gc_sm_fortressblast_bot_min;
ConVar gc_sm_fortressblast_bot_max;
ConVar gc_sm_fortressblast_debug;
ConVar gc_sm_fortressblast_dizzy_states;
ConVar gc_sm_fortressblast_dizzy_length;
ConVar gc_sm_fortressblast_drop;
ConVar gc_sm_fortressblast_drop_rate;
ConVar gc_sm_fortressblast_drop_teams;
ConVar gc_sm_fortressblast_event_xmas;
ConVar gc_sm_fortressblast_gifthunt;
ConVar gc_sm_fortressblast_gifthunt_countbots;
ConVar gc_sm_fortressblast_gifthunt_goal;
ConVar gc_sm_fortressblast_gifthunt_increment;
ConVar gc_sm_fortressblast_gifthunt_players;
ConVar gc_sm_fortressblast_gifthunt_rate;
ConVar gc_sm_fortressblast_gifthunt_bonus;
ConVar gc_sm_fortressblast_intro;
ConVar gc_sm_fortressblast_mannpower;
ConVar gc_sm_fortressblast_powerups;
ConVar gc_sm_fortressblast_powerups_roundstart;
ConVar gc_sm_fortressblast_respawnroomkill;
ConVar gc_sm_fortressblast_ultra_rate;

// Included Files
#include "fortress_blast/stock.sp"
#include "fortress_blast/hud.sp"
#include "fortress_blast/timer.sp"
#include "fortress_blast/events.sp"
#include "fortress_blast/commands.sp"

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

	// Hooks
	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("teamplay_setup_finished", Event_OnSetupFinished);
	HookEvent("teamplay_round_win", Event_OnRoundWin);
	HookEvent("player_death", Event_OnPlayerDeath);

	// Commands
	RegConsoleCmd("sm_fortressblast", Command_FortressBlast);
	RegConsoleCmd("sm_coordsjson", Command_CoordsJson);
	RegConsoleCmd("sm_setpowerup", Command_SetPowerup);
	RegConsoleCmd("sm_spawnpowerup", Command_SpawnPowerup);
	RegConsoleCmd("sm_respawnpowerups", Command_RespawnPowerups);

	// Translations
	LoadTranslations("common.phrases");

	// ConVars
	gc_sm_fortressblast_action = CreateConVar("sm_fortressblast_action", "attack3", "Which action to watch for in order to use powerups.");
	gc_sm_fortressblast_adminflag = CreateConVar("sm_fortressblast_adminflag", "z", "Which flag to use for admin-restricted commands outside of debug mode.");
	gc_sm_fortressblast_blast_buildings = CreateConVar("sm_fortressblast_blast_buildings", "100", "Percentage of Blast player damage to inflict on enemy buildings.");
	gc_sm_fortressblast_bot = CreateConVar("sm_fortressblast_bot", "1", "Disables or enables bots using powerups.");
	gc_sm_fortressblast_bot_min = CreateConVar("sm_fortressblast_bot_min", "2", "Minimum time for bots to use a powerup.");
	gc_sm_fortressblast_bot_max = CreateConVar("sm_fortressblast_bot_max", "15", "Maximum time for bots to use a powerup.");
	gc_sm_fortressblast_debug = CreateConVar("sm_fortressblast_debug", "0", "Disables or enables command permission overrides and debug messages in chat.");
	gc_sm_fortressblast_dizzy_states = CreateConVar("sm_fortressblast_dizzy_states", "5", "Number of rotational states Dizzy Bomb uses.");
	gc_sm_fortressblast_dizzy_length = CreateConVar("sm_fortressblast_dizzy_length", "5", "Length of time Dizzy Bomb lasts.");
	gc_sm_fortressblast_drop = CreateConVar("sm_fortressblast_drop", "1", "How to handle dropping powerups on death.");
	gc_sm_fortressblast_drop_rate = CreateConVar("sm_fortressblast_drop_rate", "10", "Chance out of 100 for a powerup to drop on death.");
	gc_sm_fortressblast_drop_teams = CreateConVar("sm_fortressblast_drop_teams", "1", "Teams that will drop powerups on death.");
	gc_sm_fortressblast_event_xmas = CreateConVar("sm_fortressblast_event_xmas", "1", "How to handle the TF2 Smissmas event.");
	gc_sm_fortressblast_gifthunt = CreateConVar("sm_fortressblast_gifthunt", "0", "Disables or enables Gift Hunt on maps with Gift Hunt .json files.");
	gc_sm_fortressblast_gifthunt_bonus = CreateConVar("sm_fortressblast_gifthunt_bonus", "1", "Whether or not to multiply players' gift collections once they fall behind.");
	gc_sm_fortressblast_gifthunt_countbots = CreateConVar("sm_fortressblast_gifthunt_countbots", "0", "Disables or enables counting bots as players when increasing the goal.");
	gc_sm_fortressblast_gifthunt_goal = CreateConVar("sm_fortressblast_gifthunt_goal", "125", "Base number of gifts required to unlock the objective in Gift Hunt.");
	gc_sm_fortressblast_gifthunt_increment = CreateConVar("sm_fortressblast_gifthunt_increment", "25", "Amount to increase the gift goal per extra group of players.");
	gc_sm_fortressblast_gifthunt_players = CreateConVar("sm_fortressblast_gifthunt_players", "4", "Number of players in a group, any more and the gift goal increases.");
	gc_sm_fortressblast_gifthunt_rate = CreateConVar("sm_fortressblast_gifthunt_rate", "20", "Chance out of 100 for each gift to spawn once all gifts are collected.");
	gc_sm_fortressblast_intro = CreateConVar("sm_fortressblast_intro", "1", "Disables or enables automatically display the plugin intro message.");
	gc_sm_fortressblast_mannpower = CreateConVar("sm_fortressblast_mannpower", "2", "How to handle replacing Mannpower powerups.");
	gc_sm_fortressblast_powerups = CreateConVar("sm_fortressblast_powerups", "-1", "Bitfield of which powerups to enable.");
	gc_sm_fortressblast_powerups_roundstart = CreateConVar("sm_fortressblast_powerups_roundstart", "1", "Disables or enables automatically spawning powerups on round start.");
	gc_sm_fortressblast_respawnroomkill = CreateConVar("sm_fortressblast_respawnroomkill", "1", "Disables or enables killing enemies inside spawnrooms due to Mega Mann exploit.");
	gc_sm_fortressblast_ultra_rate = CreateConVar("sm_fortressblast_ultra_rate", "0.1", "Chance out of 100 for the Ultra Powerup to spawn.");

	// In case the plugin is reloaded mid-round
	for (int iClient = 1; iClient <= MaxClients; iClient++) {
		if (!IsValidClient(iClient)) {
			continue;
		}

		OnClientPutInServer(iClient);
	}

	// HUDs
	ghud_PowerupText = CreateHudSynchronizer();
	ghud_GiftText = CreateHudSynchronizer();
}

/* OnConfigsExecuted()
==================================================================================================== */

public void OnConfigsExecuted() {
	InsertServerTag("fortressblast");
}

public void OnGameFrame() {
	GiftHuntNeutralGoal();
}

/* OnMapStart()
==================================================================================================== */

public void OnMapStart() {
	// Reset Gift Hunt progress
	gi_CollectedGifts[2] = 0;
	gi_CollectedGifts[3] = 0;

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

public void CalculateGiftAmountForPlayers() {
	gi_GiftGoal = gc_sm_fortressblast_gifthunt_goal.IntValue;
	DebugText("Base gift goal is %d", gi_GiftGoal);
	int steps = RoundToFloor((gi_PlayersAmount - 1) / gc_sm_fortressblast_gifthunt_players.FloatValue);
	if (steps < 0) {
		steps = 0;
	}
	gi_GiftGoal += (gc_sm_fortressblast_gifthunt_increment.IntValue * steps);
	DebugText("Calculated gift goal is %d", gi_GiftGoal);
}

public void OnEntityDestroyed(int entity) {
	if (IsValidEntity(entity) && entity > 0) {
		ClearTimer(gh_DestroyPowerup[entity]); // This causes about half a second of lag when a new round starts. but not having it causes problems
		char classname[60];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "tf_halloween_pickup") && gi_PowerUpID[entity] == 0) { // This is just an optimizer, the same thing would happen without this but slower
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

public int NumberOfActiveGifts() {
	int totalgifts;
	int entity;
	while ((entity = FindEntityByClassname(entity, "tf_halloween_pickup")) != -1) {
		if (gi_PowerUpID[entity] == 0) {
			totalgifts++;
		}
	}
	return totalgifts;
}

public Action Timer_DestroyPowerupTime(Handle timer, int entity) {
	gh_DestroyPowerup[entity] = INVALID_HANDLE;
	RemoveEntity(entity);
}

public void OnClientPutInServer(int client) {
	gi_CollectedPowerup[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	SDKHook(client, SDKHook_StartTouch, OnStartTouchFrozen);
	CreateTimer(3.0, Timer_DisplayIntro, GetClientSerial(client));
	gi_DizzyProgress[client] = -1;
}

stock int SpawnPower(float location[3], bool respawn, int id = 0) {
	int entity = CreateEntityByName("tf_halloween_pickup");
	DispatchKeyValue(entity, "powerup_model", "models/fortressblast/pickups/fb_pickup.mdl");
	if (IsValidEdict(entity)) {
		if (id == 0) {
			if (gc_sm_fortressblast_ultra_rate.FloatValue > GetRandomFloat(0.0, 99.99)) {
				gi_PowerUpID[entity] = -1;
			} else {
				gi_PowerUpID[entity] = GetRandomInt(1, gi_NumberOfPowerups);
				while (!PowerupIsEnabled(gi_PowerUpID[entity])) {
					gi_PowerUpID[entity] = GetRandomInt(1, gi_NumberOfPowerups);
				}
			}
		} else {
			gi_PowerUpID[entity] = id;
		}
		// No colour setting required for Ultra Powerup, default is white
		if (gi_PowerUpID[entity] == 1) {
			SetEntityRenderColor(entity, 85, 102, 255, 255);
		} else if (gi_PowerUpID[entity] == 2) {
			SetEntityRenderColor(entity, 255, 0, 0, 255);
		} else if (gi_PowerUpID[entity] == 3) {
			SetEntityRenderColor(entity, 255, 119, 17, 255);
		} else if (gi_PowerUpID[entity] == 4) {
			SetEntityRenderColor(entity, 255, 85, 119, 255);
		} else if (gi_PowerUpID[entity] == 5) {
			SetEntityRenderColor(entity, 0, 204, 0, 255);
		} else if (gi_PowerUpID[entity] == 6) {
			SetEntityRenderColor(entity, 136, 255, 170, 255);
		} else if (gi_PowerUpID[entity] == 7) {
			SetEntityRenderColor(entity, 255, 255, 0, 255);
		} else if (gi_PowerUpID[entity] == 8) {
			SetEntityRenderColor(entity, 85, 85, 85, 255);
		} else if (gi_PowerUpID[entity] == 9) {
			SetEntityRenderColor(entity, 255, 187, 255, 255);
		} else if (gi_PowerUpID[entity] == 10) {
			SetEntityRenderColor(entity, 0, 0, 0, 255);
		} else if (gi_PowerUpID[entity] == 11) {
			SetEntityRenderColor(entity, 255, 153, 153, 255);
		} else if (gi_PowerUpID[entity] == 12) {
			SetEntityRenderColor(entity, 0, 68, 0, 255);
		} else if (gi_PowerUpID[entity] == 13) {
			SetEntityRenderColor(entity, 218, 182, 72, 255);
		} else if (gi_PowerUpID[entity] == 14) {
			SetEntityRenderColor(entity, 36, 255, 255, 255);
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

public int SpawnGift(float location[3]) {
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
		gi_PowerUpID[entity] = 0;
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

public Action OnStartTouchFrozen(int entity, int other) {
	// Test that using player and touched player are both valid targets
	if (entity > 0 && entity <= MaxClients && other > 0 && other <= MaxClients && IsClientInGame(entity) && IsClientInGame(other)) {
		if ((FrostTouch[entity] || UltraPowerup[entity]) && gi_FrostTouchFrozen[other] == 0) {
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
			ClearTimer(gh_FrostTouchUnfreeze[other]);
			gh_FrostTouchUnfreeze[other] = CreateTimer(3.0, Timer_FrostTouchUnfreeze, other);
			gi_FrostTouchFrozen[other] = ((UltraPowerup[entity]) ? 2 : 1);
			BlockAttacking(other, 3.0);
		}
	}
}

public Action Timer_FrostTouchUnfreeze(Handle timer, int client) {
	gh_FrostTouchUnfreeze[client] = INVALID_HANDLE;
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (IsPlayerAlive(client)) {
		EmitAmbientSound("fortressblast2/frosttouch_unfreeze.mp3", vel, client);
	}
	SetClientViewEntity(client, client);
	SetEntityMoveType(client, MOVETYPE_WALK);
	ColorizePlayer(client, {255, 255, 255, 255});
	SetThirdPerson(client, false);
	gi_FrostTouchFrozen[client] = 0;
}

public Action OnStartTouchRespawn(int entity, int other) {
	if (other > 0 && other <= MaxClients) {
		float coords[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
		Handle coordskv = CreateKeyValues("coordskv");
		KvSetFloat(coordskv, "0", coords[0]);
		KvSetFloat(coordskv, "1", coords[1]);
		KvSetFloat(coordskv, "2", coords[2]);
		KvSetNum(coordskv, "verifier", gi_GlobalVerifier);
		CreateTimer(10.0, Timer_SpawnPowerAfterDelay, coordskv);
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
	if (gi_PowerUpID[entity] == 0) {
		CollectedGift(other);
		return;
	}
	gi_CollectedPowerup[other] = gi_PowerUpID[entity];
	DebugText("%N has collected powerup ID %d", other, gi_CollectedPowerup[other]);
	CollectedPowerup(other);
}

public Action Timer_BotUsePowerup(Handle timer, int client) {
	if (IsClientInGame(client)) {
		DebugText("Forcing bot %N to use powerup ID %d", client, gi_CollectedPowerup[client]);
		UsePower(client);
	}
}

public Action Timer_SpawnPowerAfterDelay(Handle timer, any data) {
	float coords[3];
	Handle coordskv = data;
	coords[0] = KvGetFloat(coordskv, "0");
	coords[1] = KvGetFloat(coordskv, "1");
	coords[2] = KvGetFloat(coordskv, "2");
	int LocalVerifier = KvGetNum(coordskv, "verifier");
	// Only respawn powerup if it has an ID equal to the previously placed one
	if (LocalVerifier == gi_GlobalVerifier) {
		DebugText("Respawning powerup at %f, %f, %f", coords[0], coords[1], coords[2]);
		EmitAmbientSound("items/spawn_item.wav", coords);
		SpawnPower(coords, true);
	}
}

public void CollectedPowerup(int client) {
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (gi_CollectedPowerup[client] == -1) {
		EmitSoundToClient(client, "fortressblast2/ultrapowerup_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 1) {
		EmitSoundToClient(client, "fortressblast2/superbounce_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 2) {
		EmitSoundToClient(client, "fortressblast2/shockabsorber_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 3) {
		EmitSoundToClient(client, "fortressblast2/superspeed_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 4) {
		EmitSoundToClient(client, "fortressblast2/superjump_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 5) {
		EmitSoundToClient(client, "fortressblast2/gyrocopter_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 6) {
		EmitSoundToClient(client, "fortressblast2/timetravel_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 7) {
		EmitSoundToClient(client, "fortressblast2/blast_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 8) {
		EmitSoundToClient(client, "fortressblast2/megamann_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 9) {
		EmitSoundToClient(client, "fortressblast2/frosttouch_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 10) {
		EmitSoundToClient(client, "fortressblast2/mystery_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 11) {
		EmitSoundToClient(client, "fortressblast2/teleportation_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 12) {
		EmitSoundToClient(client, "fortressblast2/magnetism_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 13) {
		EmitSoundToClient(client, "fortressblast2/effectburst_pickup.mp3", client);
	} else if (gi_CollectedPowerup[client] == 14) {
		EmitSoundToClient(client, "fortressblast2/dizzybomb_pickup.mp3", client);
	}
	// If player is a bot and bot support is enabled
	if (IsFakeClient(client) && gc_sm_fortressblast_bot.BoolValue) {
		// Get minimum and maximum times
		float convar1 = gc_sm_fortressblast_bot_min.FloatValue;
		if (convar1 < 0) {
			convar1 == 0;
		}
		float convar2 = gc_sm_fortressblast_bot_max.FloatValue;
		if (convar2 < convar1) {
			convar2 == convar1;
		}
		// Get bot to use powerup within the random period
		CreateTimer(GetRandomFloat(convar1, convar2), Timer_BotUsePowerup, client);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float ang[3], int &weapon) {
	float coords[3] = 69.420;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
	if (TimeTravel[client]) {
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 520.0);
	}
	if (buttons & 33554432 && (!gb_PreviousAttack3[client]) && StringButtonInt() != 33554432) {
		char button[40];
		gc_sm_fortressblast_action.GetString(button, sizeof(button));
		CPrintToChat(client, "%s {red}Special attack is currently disabled on this server. You are required to {yellow}perform the '%s' action to use a powerup.", MESSAGE_PREFIX, button);
	} else if (buttons & StringButtonInt() && !BlockPowerup(client)) {
		UsePower(client);
	}
	float vel2[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel2);
	if (GetEntityFlags(client) & FL_ONGROUND) {
		if (gf_VerticalVelocity[client] != 0.0 && SuperBounce[client] && gf_VerticalVelocity[client] < -250.0) {
			vel2[2] = (gf_VerticalVelocity[client] * -1);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel2);
			DebugText("Setting %N's vertical velocity to %f", client, vel2[2]);
		}
	}
	DisplayHud(client);
	gf_VerticalVelocity[client] = vel2[2];

	for (int partid = MAX_PARTICLES; partid > 0 ; partid--) {
		if (gi_PlayerParticle[client][partid] == 0) {
			gi_PlayerParticle[client][partid] = -1; // Unsure of this line's purpose
		}
		if (IsValidEntity(gi_PlayerParticle[client][partid])) {
			float particlecoords[3];
			GetClientAbsOrigin(client, particlecoords);
			particlecoords[2] += gf_ParticleZAdjust[client][partid];
			TeleportEntity(gi_PlayerParticle[client][partid], particlecoords, NULL_VECTOR, NULL_VECTOR);
			if (!IsPlayerAlive(client)) {
				Handle partkv = CreateKeyValues("partkv");
				KvSetNum(partkv, "client", client);
				KvSetNum(partkv, "id", partid);
				CreateTimer(0.0, Timer_RemoveParticle, partkv);
			}
		}
	}
	gb_PreviousAttack3[client] = (buttons > 33554431);
	// Cover bases not covered by regular blocking
	if (TimeTravel[client] || gi_FrostTouchFrozen[client]) {
		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
	}
	if (IsValidEntity(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))) {
		if (GetEntProp(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), Prop_Send, "m_iItemDefinitionIndex") == 28 && !gb_MegaMannVerified[client] && MegaMann[client]) {
			buttons &= ~IN_ATTACK;
		}
	}
	if ((Magnetism[client] || UltraPowerup[client]) && IsPlayerAlive(client)) {
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
					if (GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") != GetPlayerWeaponSlot(client, 2)) {
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

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
	if (ShockAbsorber[victim] || gi_FrostTouchFrozen[victim] == 1 || UltraPowerup[victim]) {
		if (gi_FrostTouchFrozen[victim] == 1) {
			damage = damage * 0.1;
			DebugText("%N was in frozen state %d", victim, gi_FrostTouchFrozen[victim]);
		} else {
			damage = damage * 0.25;
		}
		damageForce[0] = 0.0;
		damageForce[1] = 0.0;
		damageForce[2] = 0.0;
	}
	if (SuperBounce[victim] && attacker == 0 && damage < 100.0) {
		return Plugin_Handled;
	}
	return Plugin_Changed;
}

public void UsePower(int client) {
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (gi_CollectedPowerup[client] == -1) {
		// Ultra Powerup - Multiple effects
		ClearTimer(gh_MegaMann[client]);
		UltraPowerup[client] = true;
		gh_UltraPowerup[client] = CreateTimer(10.0, Timer_RemoveUltraPowerup, client);
		// Super Bounce, Super Jump, Gyrocopter, Time Travel, Blast, Mystery, Teleportation, Effect Burst and Dizzy Bomb are not included
		// Shock Absorber already set
		gi_SpeedRotationsLeft[client] = 100; // Super Speed, for 10 seconds, slightly faster
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
		PowerupParticle(client, "medic_resist_bullet", 0.2, 0.0);
		for (int timepoint = 0 ; timepoint <= 50 ; timepoint++) {
			CreateTimer(timeport, MedicResistFire, client);
			CreateTimer((timeport + 0.1), MedicResistBullet, client);
			timeport = timeport + 0.2;
		}
	} else if (gi_CollectedPowerup[client] == 1) {
		// Super Bounce - Uncontrollable bunny hop and fall damage resistance for 5 seconds
		EmitAmbientSound("fortressblast2/superbounce_use.mp3", vel, client);
		gf_VerticalVelocity[client] = 0.0; // Cancel previously stored vertical velocity
		SuperBounce[client] = true;
		ClearTimer(gh_SuperBounce[client]);
		gh_SuperBounce[client] = CreateTimer(5.0, Timer_RemoveSuperBounce, client);
		PowerupParticle(client, "teleporter_blue_charged_level2", 5.0, 0.0);
	} else if (gi_CollectedPowerup[client] == 2) {
		// Shock Absorber - 75% damage and 100% knockback resistances for 5 seconds
		ShockAbsorber[client] = true;
		EmitAmbientSound("fortressblast2/shockabsorber_use.mp3", vel, client);
		ClearTimer(gh_ShockAbsorber[client]);
		gh_ShockAbsorber[client] = CreateTimer(5.0, Timer_RemoveShockAbsorb, client);
		PowerupParticle(client, "teleporter_red_charged_level2", 5.0, 0.0);
	} else if (gi_CollectedPowerup[client] == 3) {
		// Super Speed - Increased speed, gradually wears off over 10 seconds
		gf_OldSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
		gi_SpeedRotationsLeft[client] = 80;
		EmitAmbientSound("fortressblast2/superspeed_use.mp3", vel, client);
	} else if (gi_CollectedPowerup[client] == 4) {
		// Super Jump - Launch user into air
		if (MegaMann[client]) {
			vel[2] += 400.0;
		} else {
			vel[2] += 800.0;
		}
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
		EmitAmbientSound("fortressblast2/superjump_use.mp3", vel, client);
	} else if (gi_CollectedPowerup[client] == 5) {
		// Gyrocopter - 25% gravity for 5 seconds
		SetEntityGravity(client, 0.25);
		ClearTimer(gh_Gyrocopter[client]);
		gh_Gyrocopter[client] = CreateTimer(5.0, Timer_RestoreGravity, client);
		EmitAmbientSound("fortressblast2/gyrocopter_use.mp3", vel, client);
	} else if (gi_CollectedPowerup[client] == 6) {
		// Time Travel - Increased speed, invisibility and can't attack for 5 seconds
		TimeTravel[client] = true;
		SetThirdPerson(client, true);
		TF2_AddCondition(client, TFCond_StealthedUserBuffFade, 3.0);
		BlockAttacking(client, 3.0);
		ClearTimer(gh_TimeTravel[client]);
		gh_TimeTravel[client] = CreateTimer(3.0, Timer_RemoveTimeTravel, client);
		EmitAmbientSound("fortressblast2/timetravel_use_3sec.mp3", vel, client);
	} else if (gi_CollectedPowerup[client] == 7) {
		// Blast - Create explosion at user
		PowerupParticle(client, "rd_robot_explosion", 1.0, 0.0);
		EmitAmbientSound("fortressblast2/blast_use.mp3", vel, client);
		if (Smissmas()) {
			PowerupParticle(client, "xmas_ornament_glitter_alt", 2.0, 0.0);
			EmitAmbientSound("misc/jingle_bells/jingle_bells_nm_02.wav", vel, client);
		}
		TF2_RemoveCondition(client, TFCond_StealthedUserBuffFade);
		TF2_RemoveCondition(client, TFCond_Cloaked);
		TF2_RemovePlayerDisguise(client);
		ClearTimer(gh_TimeTravel[client]);
		gh_TimeTravel[client] = CreateTimer(0.0, Timer_RemoveTimeTravel, client); // Remove Time Travel instantly
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
	} else if (gi_CollectedPowerup[client] == 8) {
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
		ClearTimer(gh_MegaMann[client]);
		gh_MegaMann[client] = CreateTimer(10.0, Timer_RemoveMegaMann, client);
		float coords[3] = 69.420;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
		coords[2] += 16.0;
		TeleportEntity(client, coords, NULL_VECTOR, NULL_VECTOR);
		MegaMann[client] = true;
		gb_MegaMannVerified[client] = true;
	} else if (gi_CollectedPowerup[client] == 9) {
		// Frost Touch - Freeze touched players for 3 seconds within 8 seconds
		EmitAmbientSound("fortressblast2/frosttouch_use.mp3", vel, client);
		ClearTimer(gh_FrostTouch[client]);
		gh_FrostTouch[client] = CreateTimer(8.0, Timer_RemoveFrostTouch, client);
		FrostTouch[client] = true;
		PowerupParticle(client, "smoke_rocket_steam", 8.0, 32.0);
	} else if (gi_CollectedPowerup[client] == 10) {
		// Mystery - Random powerup
		int mysrand = 10;
		while (mysrand == 10 || !PowerupIsEnabled(mysrand)) {
			mysrand = GetRandomInt(1, gi_NumberOfPowerups);
		}
		gi_CollectedPowerup[client] = mysrand;
		UsePower(client);
	} else if (gi_CollectedPowerup[client] == 11) {
		// Teleportation - Teleport to random active Engineer exit teleport or spawn
		ClearTimer(gh_Teleportation[client]);
		gh_Teleportation[client] = CreateTimer(0.5, Timer_BeginTeleporter, client);
		EmitAmbientSound("fortressblast2/teleportation_use.mp3", vel, client);
		PowerupParticle(client, "teleported_flash", 0.5, 0.0); // Particle on using powerup
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
	} else if (gi_CollectedPowerup[client] == 12) {
		// Magnetism - Repel or attract enemies depending on weapon slot
		EmitAmbientSound("fortressblast2/magnetism_use.mp3", vel, client);
		Magnetism[client] = true;
		ClearTimer(gh_Magnetism[client]);
		gh_Magnetism[client] = CreateTimer(5.0, Timer_RemoveMagnetism, client);
		// Repeatedly produce Magnetism particle
		float timeport = 0.1;
		PowerupParticle(client, "ping_circle", 0.5, 0.0);
		for (int timepoint = 0 ; timepoint <= 50 ; timepoint++) {
			CreateTimer(timeport, RepeatPing, client);
			timeport = timeport + 0.1;
		}
	} else if (gi_CollectedPowerup[client] == 13) {
		// Effect Burst - Afflict enemies with one of four random status effects
		EmitAmbientSound("fortressblast2/effectburst_use.mp3", vel, client);
		PowerupParticle(client, "merasmus_dazed_explosion", 1.0, 0.0);
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
	} else if (gi_CollectedPowerup[client] == 14) {
		// Dizzy Bomb - Afflict enemies with dizziness of varying effectiveness
		EmitAmbientSound("fortressblast2/dizzybomb_use.mp3", vel, client);
		float pos1[3];
		GetClientAbsOrigin(client, pos1);
		for (int client2 = 1 ; client2 <= MaxClients ; client2++) {
			if (IsClientInGame(client2) && IsPlayerAlive(client2) && GetClientTeam(client2) != GetClientTeam(client)) {
				float pos2[3];
				GetClientAbsOrigin(client2, pos2);
				if (GetVectorDistance(pos1, pos2) < 512.0) {
					gi_DizzyProgress[client2] = 0;
					gb_NegativeDizzy[client2] = (GetRandomInt(0, 1) == 0); // Randomly decide which direction dizziness shoudl start in
					EmitSoundToClient(client2, "fortressblast2/dizzybomb_dizzy.mp3", client2);
					PowerupParticle(client2, "conc_stars", gc_sm_fortressblast_dizzy_length.FloatValue, 80.0);
				}
			}
		}
	}
	gi_CollectedPowerup[client] = 0;
}

public Action RepeatPing(Handle timer, int client) {
	if (IsClientInGame(client) && IsPlayerAlive(client) && Magnetism[client]) {
		PowerupParticle(client, "ping_circle", 0.5, 0.0);
	}
}

public Action MedicResistFire(Handle timer, int client) {
	if (IsClientInGame(client) && IsPlayerAlive(client) && UltraPowerup[client]) {
		PowerupParticle(client, "medic_resist_fire", 0.2, 0.0);
	}
}

public Action MedicResistBullet(Handle timer, int client) {
	if (IsClientInGame(client) && IsPlayerAlive(client) && UltraPowerup[client]) {
		PowerupParticle(client, "medic_resist_bullet", 0.2, 0.0);
	}
}

public Action Timer_RemoveMagnetism(Handle timer, int client) {
	gh_Magnetism[client] = INVALID_HANDLE;
	Magnetism[client] = false;
}

public Action Timer_RemoveUltraPowerup(Handle timer, int client) {
	gh_UltraPowerup[client] = INVALID_HANDLE;
	UltraPowerup[client] = false;
	if (GetClientHealth(client) > GetPlayerMaxHealth(client)) {
		SetEntityHealth(client, GetPlayerMaxHealth(client));
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
			float expectedDamage = gc_sm_fortressblast_blast_buildings.FloatValue / 100;
			if (expectedDamage < 0) {
				expectedDamage = 0.0;
			}
			SDKHooks_TakeDamage(entity, 0, client, ((150.0 - (GetVectorDistance(pos1, pos2) * 0.4)) * expectedDamage), 0, -1);
		}
	}
}

public Action Timer_BeginTeleporter(Handle timer, int client) {
	gh_Teleportation[client] = INVALID_HANDLE;
	if (!IsPlayerAlive(client)) {
		return; // Do not teleport dead player
	}
	if (MegaMann[client]) {
		ClearTimer(gh_MegaMann[client]);
		gh_MegaMann[client] = CreateTimer(0.0, Timer_RemoveMegaMann, client);
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
		PowerupParticle(client, "teleportedin_red", 1.0, 0.0);
	} else if (TF2_GetClientTeam(client) == TFTeam_Blue) {
		PowerupParticle(client, "teleportedin_blue", 1.0, 0.0);
	}
	TeleportXmasParticles(client);
}


public void TeleportXmasParticles(int client) {
	if (Smissmas()) {
		float vel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
		PowerupParticle(client, "xms_snowburst_child01", 5.0, 0.0);
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

public Action Timer_RemoveFrostTouch(Handle timer, int client) {
	gh_FrostTouch[client] = INVALID_HANDLE;
	FrostTouch[client] = false;
}

public Action Timer_RemoveMegaMann(Handle timer, int client) {
	gh_MegaMann[client] = INVALID_HANDLE;
	MegaMann[client] = false;
	if (IsClientInGame(client)) {
		SetVariantString("1 0");
		AcceptEntityInput(client, "SetModelScale");
		// Remove excess overheal, but leave injuries
		if (GetClientHealth(client) > GetPlayerMaxHealth(client)) {
			SetEntityHealth(client, GetPlayerMaxHealth(client));
		}
	}
}

public Action Timer_RemoveTimeTravel(Handle timer, int client) {
	gh_TimeTravel[client] = INVALID_HANDLE;
	TimeTravel[client] = false;
	SetThirdPerson(client, false);
	if (IsClientInGame(client)) {
		TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
	}
}

public Action Timer_RestoreGravity(Handle timer, int client) {
	gh_Gyrocopter[client] = INVALID_HANDLE;
	if (IsClientInGame(client)) {
		SetEntityGravity(client, 1.0);
	}
}

public Action Timer_RemoveSuperBounce(Handle timer, int client) {
	gh_SuperBounce[client] = INVALID_HANDLE;
	SuperBounce[client] = false;
}

public Action Timer_RemoveShockAbsorb(Handle timer, int client) {
	gh_ShockAbsorber[client] = INVALID_HANDLE;
	ShockAbsorber[client] = false;
}

public void GetPowerupPlacements(bool UsingGiftHunt) {
	if (!UsingGiftHunt && !gb_MapHasJsonFile) {
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
		gi_GlobalVerifier = GetRandomInt(1, 999999999); // Large integer used to avoid duplicate powerups where possible
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
			if (UsingGiftHunt && (GetRandomInt(0, 99) >= gc_sm_fortressblast_gifthunt_rate.IntValue)) {
				DebugText("Not spawning gift %d because it failed random", itemloop);
			} else {
				if (UsingGiftHunt) {
					coords[2] += 8.0;
					DebugText("Spawning gift %d at %f, %f, %f", itemloop, coords[0], coords[1], coords[2]);
					SpawnGift(coords);
				} else {
					DebugText("Spawning powerup %d at %f, %f, %f", itemloop, coords[0], coords[1], coords[2]);
					SpawnPower(coords, true);
				}
				if (flipx && flipy) {
					if (coords[0] != centerx || coords[1] != centery) {
						coords[0] = coords[0] - ((coords[0] - centerx) * 2);
						coords[1] = coords[1] - ((coords[1] - centery) * 2);
						DebugText("Flipping both axes, new entity created at %f, %f, %f", coords[0], coords[1], coords[2]);
						if (UsingGiftHunt) {
							SpawnGift(coords);
						} else {
							SpawnPower(coords, true);
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
							SpawnPower(coords, true);
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
							SpawnPower(coords, true);
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

stock void ClearTimer(Handle Timer) { // From SourceMod forums
    if (Timer != INVALID_HANDLE) {
        CloseHandle(Timer);
        Timer = INVALID_HANDLE;
    }
}

public void PowerupParticle(int client, char particlename[80], float time, float zadjust) {
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
		if (!IsValidEntity(gi_PlayerParticle[client][partid])) {
			freeid = partid;
		}
	}
	if (freeid == -5) {
		freeid = GetRandomInt(1, MAX_PARTICLES);
		RemoveEntity(gi_PlayerParticle[client][freeid]);
		PrintToServer("%s All of %N's particles were in use, freeing #%d", MESSAGE_PREFIX_NO_COLOR, client, freeid);
	}
	gi_PlayerParticle[client][freeid] = particle;
	gf_ParticleZAdjust[client][freeid] = zadjust;
	Handle partkv = CreateKeyValues("partkv");
	KvSetNum(partkv, "client", client);
	KvSetNum(partkv, "id", freeid);
	CreateTimer(time, Timer_RemoveParticle, partkv);
}

public Action Timer_RemoveParticle(Handle timer, any data) {
	Handle partkv = data;
	int client = KvGetNum(partkv, "client");
	int id = KvGetNum(partkv, "id");
	if (IsValidEntity(gi_PlayerParticle[client][id])) {
		RemoveEntity(gi_PlayerParticle[client][id]);
	}
	gi_PlayerParticle[client][id] = -1;
}

public void DebugText(const char[] text, any ...) {
	if (gc_sm_fortressblast_debug.BoolValue) {
		int len = strlen(text) + 255;
		char[] format = new char[len];
		VFormat(format, len, text, 2);
		CPrintToChatAll("{orange}[FBU Debug] {white}%s", format);
		PrintToServer("[FBU Debug] %s", format);
	}
}

public int AdminFlagInt() {
	char flag[40];
	gc_sm_fortressblast_adminflag.GetString(flag, sizeof(flag));
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

public void CollectedGift(int client) {
	int flag;
	DebugText("%N has collected a gift", client);
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	EmitAmbientSound("fortressblast2/gifthunt_gift_pickup.mp3", vel, client);
	int team = GetClientTeam(client);
	gi_CollectedGifts[team] = gi_CollectedGifts[team] + gi_GiftBonus[team];
	// A team has reached the gift goal
	if (gi_CollectedGifts[team] >= gi_GiftGoal && gi_CollectedGifts[team] < (gi_GiftGoal + gi_GiftBonus[team])) {
		gf_GiftHuntIncrementTime = GetGameTime() + 60.0;
		if (team == 2) {
			gi_GiftBonus[2] = 1;
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
			if (gb_GiftHuntAttackDefense) {
				EntFire("team_round_timer", "Resume");
			}
		} else if (team == 3) {
			gi_GiftBonus[3] = 1;
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

public void GiftHuntNeutralGoal() {
	// Neutral intelligence support for Gift Hunt
	if (gb_GiftHuntNeutralFlag) {
		int flag;
		while ((flag = FindEntityByClassname(flag, "item_teamflag")) != -1) {
			// Neither team has reached gift goal, intelligence is neutral and disabled
			if (gi_CollectedGifts[2] < gi_GiftGoal && gi_CollectedGifts[3] < gi_GiftGoal) {
				AcceptEntityInput(flag, "Disable");
				SetEntProp(flag, Prop_Send, "m_iTeamNum", 0);
			// Both teams have reached gift goal, intelligence is neutral and enabled
			} else if (gi_CollectedGifts[2] >= gi_GiftGoal && gi_CollectedGifts[3] >= gi_GiftGoal) {
				AcceptEntityInput(flag, "Enable");
				SetEntProp(flag, Prop_Send, "m_iTeamNum", 0);
			// RED team has reached gift goal, intelligence is BLU and enabled
			} else if (gi_CollectedGifts[3] >= gi_GiftGoal && gi_CollectedGifts[2] < gi_GiftGoal) {
				AcceptEntityInput(flag, "Enable");
				SetEntProp(flag, Prop_Send, "m_iTeamNum", 2);
			// BLU team has reached gift goal, intelligence is RED and enabled
			} else if (gi_CollectedGifts[2] >= gi_GiftGoal && gi_CollectedGifts[3] < gi_GiftGoal) {
				AcceptEntityInput(flag, "Enable");
				SetEntProp(flag, Prop_Send, "m_iTeamNum", 3);
			}
		}
	}
}

public bool PowerupIsEnabled(int id) {
	int max = (Bitfieldify(gi_NumberOfPowerups) * 2) - 1;
	int bitfield = gc_sm_fortressblast_powerups.IntValue;
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

public void RemoveAllPowerups() {
	int entity;
	while ((entity = FindEntityByClassname(entity, "tf_halloween_pickup")) != -1) {
		RemoveEntity(entity);
	}
}

public void OnTouchRespawnRoom(int entity, int other) {
	if (other < 1 || other > MaxClients) return;
	if (!IsClientInGame(other)) return;
	if (!IsPlayerAlive(other)) return;
	// Kill enemies inside spawnrooms
	if (GetEntProp(entity, Prop_Send, "m_iTeamNum") != GetClientTeam(other) && gc_sm_fortressblast_respawnroomkill.BoolValue && gi_VictoryTeam == -1) {
		FakeClientCommandEx(other, "kill");
		PrintToServer("%s %N was killed due to being inside an enemy team spawnroom.", MESSAGE_PREFIX_NO_COLOR, other);
		CPrintToChat(other, "%s {red}You were killed because you were inside the enemy spawn.", MESSAGE_PREFIX);
	}
}

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool& result) {
	if (MegaMann[client]) {
		result = false; // Prevent players with Mega Mann from taking teleporters
	}
	return Plugin_Changed;
}

public bool Smissmas() {
	int FeelsLikeTheVeryFirst = gc_sm_fortressblast_event_xmas.IntValue;
	if (FeelsLikeTheVeryFirst == 0) {
		return false;
	} else if (FeelsLikeTheVeryFirst == 1) {
		return TF2_IsHolidayActive(TFHoliday_Christmas);
	}
	return true;
}

public bool BlockPowerup(int client) {
	// Player is dead
	if (!IsPlayerAlive(client)) {
		return true;
	// Player is frozen
	} else if (gi_FrostTouchFrozen[client] != 0) {
		return true;
	// Player is in a kart or is taunting
	} else if (TF2_IsPlayerInCondition(client, TFCond_HalloweenKart) || TF2_IsPlayerInCondition(client, TFCond_Taunting)) {
		return true;
	// Player lost or is in a stalemate
	} else if ((gi_VictoryTeam != -1 && gi_VictoryTeam != GetClientTeam(client))) {
		return true;
	// Mega Mann pre-stuck checking
	} else if (gi_CollectedPowerup[client] == 8 && !MegaMann[client]) {
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
