#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ripext/json>
#include <morecolors>
#include <tf2>
#include <advanced_motd>

#define	MAX_EDICT_BITS 11
#define	MAX_EDICTS (1<<MAX_EDICT_BITS)
#define MAX_PARTICLES 10 // If a player needs more than this number, a random one is deleted, but too many might cause memory problems

int powerupid[MAX_EDICTS];
int powerup[MAXPLAYERS + 1] = 0;
int PlayerParticle[MAXPLAYERS + 1][MAX_PARTICLES + 1];
int SpeedRotationsLeft[MAXPLAYERS + 1] = 80;
int MegaMannRotation[MAXPLAYERS + 1] = 0;
bool PreviousAttack3[MAXPLAYERS + 1] = false;
bool VictoryTime = false;
bool MapHasJsonFile = false;
bool SuperBounce[MAXPLAYERS + 1] = false;
bool ShockAbsorber[MAXPLAYERS + 1] = false;
bool TimeTravel[MAXPLAYERS + 1] = true;
float OldSpeed[MAXPLAYERS + 1] = 0.0;
float SuperSpeed[MAXPLAYERS + 1] = 0.0;
float VerticalVelocity[MAXPLAYERS + 1];
float MegaMannCoords[MAXPLAYERS + 1][3];
Handle SuperBounceHandle[MAXPLAYERS + 1];
Handle ShockAbsorberHandle[MAXPLAYERS + 1];
Handle GyrocopterHandle[MAXPLAYERS + 1];
Handle TimeTravelHandle[MAXPLAYERS + 1];
Handle MegaMannHandle[MAXPLAYERS + 1];

/* Powerup IDs
1 - Super Bounce
2 - Shock Absorber
3 - Super Speed
4 - Super Jump
5 - Gyrocopter
6 - Time Travel
7 - Blast */

public OnPluginStart() {
	for (int client = 1; client <= MaxClients ; client++) {
		if (IsClientInGame(client)) {
			SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage); // In case the plugin is reloaded mid-round
		}
	}
	HookEvent("teamplay_round_start", teamplay_round_start);
	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("player_death", player_death);
	RegConsoleCmd("sm_setpowerup", SetPowerup);
	RegConsoleCmd("sm_fortressblast", FBMenu);
	CreateConVar("sm_fortressblast_action_use", "attack3", "Which action to watch for in order to use powerups.");
	CreateConVar("sm_fortressblast_bot", "1", "Disable or enable bots using powerups.");
	CreateConVar("sm_fortressblast_bot_min", "2", "Minimum time for bots to use a powerup.");
	CreateConVar("sm_fortressblast_bot_max", "15", "Maximum time for bots to use a powerup.");
	CreateConVar("sm_fortressblast_debug", "0", "Disable or enable command permission overrides and debug messages in chat.");
	CreateConVar("sm_fortressblast_drop", "1", "How to handle dropping powerups on death.");
	CreateConVar("sm_fortressblast_drop_rate", "5", "Chance out of 100 for a powerup to drop on death.");
	CreateConVar("sm_fortressblast_drop_teams", "1", "Set the teams that will drop powerups on death.");
	CreateConVar("sm_fortressblast_mannpower", "2", "How to handle replacing Mannpower powerups.");
	PrecacheModel("models/props_halloween/pumpkin_loot.mdl");
	LoadTranslations("common.phrases");
}

public OnMapStart() {
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
	PrecacheSound("fortressblast2/timetravel_use.mp3");
	PrecacheSound("fortressblast2/blast_pickup.mp3");
	PrecacheSound("fortressblast2/blast_use.mp3");
	PrecacheSound("fortressblast2/megamann_pickup.mp3");
	PrecacheSound("fortressblast2/megamann_use.mp3");
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
	AddFileToDownloadsTable("sound/fortressblast2/timetravel_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/blast_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/blast_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/megamann_pickup.mp3");
	AddFileToDownloadsTable("sound/fortressblast2/megamann_use.mp3");
	
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
	AdvMOTD_ShowMOTDPanel(client, "How are you reading this?", "http://fortress-blast.github.io/0.4", MOTDPANEL_TYPE_URL, true, true, true, INVALID_FUNCTION);
	CPrintToChat(client, "{orange}[Fortress Blast] {haunted}Opening Fortress Blast manual... If nothing happens, open your developer console and {yellow}try setting cl_disablehtmlmotd to 0{haunted}, then try again.");
}

public Action SetPowerup(int client, int args) {
	if (!CheckCommandAccess(client, "", ADMFLAG_ROOT) && GetConVarFloat(FindConVar("sm_fortressblast_debug")) < 1) {
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
	}
	int player = FindTarget(client, arg, false, false);
	powerup[player] = StringToInt(arg2);
	PlayPowerupSound(player);
	// If player is a bot and bot support is enabled
	if (IsFakeClient(player) && GetConVarFloat(FindConVar("sm_fortressblast_bot")) >= 1) { // Replace with GetConVarBool
		// Get minimum and maximum times
		float convar1 = GetConVarFloat(FindConVar("sm_fortressblast_bot_min"));
		if (convar1 < 0) {
			convar1 == 0;
		}
		float convar2 = GetConVarFloat(FindConVar("sm_fortressblast_bot_max"));
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
	if (!GameRules_GetProp("m_bInWaitingForPlayers")) {
		for (int client = 1; client <= MaxClients; client++) {
			powerup[client] = 0;
			if (IsClientInGame(client)) {
				CreateTimer(3.0, PesterThisDude, client);
			}
		}
	}
	for (int entity = 1; entity <= MAX_EDICTS ; entity++) {
		if (IsValidEntity(entity)) {
			char classname[60];
			GetEntityClassname(entity, classname, sizeof(classname));
			if (FindEntityByClassname(0, "tf_logic_mannpower") != -1 && GetConVarInt(FindConVar("sm_fortressblast_mannpower")) != 0) {
				if ((!MapHasJsonFile || GetConVarInt(FindConVar("sm_fortressblast_mannpower")) == 2)) {
					if (StrEqual(classname, "item_powerup_rune") || StrEqual(classname, "item_powerup_crit") || StrEqual(classname, "item_powerup_uber") || StrEqual(classname, "info_powerup_spawn")) {
						if (StrEqual(classname, "info_powerup_spawn")) {
							float coords[3] = 69.420;
							GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
							coords[2] += 8;
							DebugText("Spawning a powerup at %f %f %f", coords[0], coords[1], coords[2]);
							SpawnPower(coords, true);
						}
						RemoveEntity(entity);
					}
				}
			}
			if (StrEqual(classname, "tf_halloween_pickup")) {
				DebugText("Removing duplicate halloween pickup entity %d", entity);
				RemoveEntity(entity);
			}
		}
	}
	GetPowerupPlacements();
}

public Action PesterThisDude(Handle timer, int client) {
	if (IsClientInGame(client)) { // Required because player might disconnect before this fires
		CPrintToChat(client, "{orange}[Fortress Blast] {haunted}This server is running {yellow}Fortress Blast v0.4! {haunted}If you would like to know more or are unsure what a powerup does, type the command {yellow}!fortressblast {haunted}into chat.");
	}
}

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast) {
	VictoryTime = true;
}

public Action player_death(Event event, const char[] name, bool dontBroadcast) {
	powerup[GetClientOfUserId(event.GetInt("userid"))] = 0;
	// Is dropping powerups enabled
	if (GetConVarFloat(FindConVar("sm_fortressblast_drop")) == 2 || (GetConVarFloat(FindConVar("sm_fortressblast_drop")) && !MapHasJsonFile)) { // Replace with GetConVarBool
		// Get chance a powerup will be dropped
		float convar = GetConVarFloat(FindConVar("sm_fortressblast_drop_rate"));
		int randomNumber = GetRandomInt(0, 99);
		if (convar > randomNumber && (GetConVarFloat(FindConVar("sm_fortressblast_drop_teams")) == GetClientTeam(GetClientOfUserId(event.GetInt("userid"))) || GetConVarFloat(FindConVar("sm_fortressblast_drop_teams")) == 1)) {
			float coords[3];
			GetEntPropVector(GetClientOfUserId(event.GetInt("userid")), Prop_Send, "m_vecOrigin", coords);
			SpawnPower(coords, false);
		}
	}
}

public OnClientPutInServer(int client) {
	powerup[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	CreateTimer(3.0, PesterThisDude, client);
}

SpawnPower(float location[3], bool respawn) {
	int entity = CreateEntityByName("tf_halloween_pickup");
	DebugText("Spawning powerup entity %d at %f, %f, %f", entity, location[0], location[1], location[2]);
	if (IsValidEdict(entity)) {
		SetEntityModel(entity, "models/props_halloween/pumpkin_loot.mdl");
		powerupid[entity] = GetRandomInt(1, 8);
		if (powerupid[entity] == 1) {
			SetEntityRenderColor(entity, 100, 100, 255, 255);
		} else if (powerupid[entity] == 2) {
			SetEntityRenderColor(entity, 255, 100, 100, 255);
		} else if (powerupid[entity] == 3) {
			SetEntityRenderColor(entity, 255, 177, 100, 255);
		} else if (powerupid[entity] == 4) {
			SetEntityRenderColor(entity, 255, 100, 255, 255);
		} else if (powerupid[entity] == 5) {
			SetEntityRenderColor(entity, 255, 177, 255, 255);
		} else if (powerupid[entity] == 6) {
			SetEntityRenderColor(entity, 100, 255, 255, 255);
		} else if (powerupid[entity] == 7) {
			SetEntityRenderColor(entity, 50, 177, 177, 255);
		} else if (powerupid[entity] == 8) {
			SetEntityRenderColor(entity, 100, 50, 50, 255);
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
}

public Action OnStartTouchRespawn(entity, other) {
	if (other > 0 && other <= MaxClients) {
		if (!VictoryTime) {
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
	powerup[other] = powerupid[entity];
	DebugText("%N has collected powerup ID %d", other, powerup[other]);
	PlayPowerupSound(other);
	// If player is a bot and bot support is enabled
	if (IsFakeClient(other) && GetConVarFloat(FindConVar("sm_fortressblast_bot")) >= 1) { // Replace with GetConVarBool
		// Get minimum and maximum times
		float convar1 = GetConVarFloat(FindConVar("sm_fortressblast_bot_min"));
		if (convar1 < 0) {
			convar1 == 0;
		}
		float convar2 = GetConVarFloat(FindConVar("sm_fortressblast_bot_max"));
		if (convar2 < convar1) {
			convar2 == convar1;
		}
		// Get bot to use powerup within the random period
		CreateTimer(GetRandomFloat(convar1, convar2), BotUsePowerup, other);
	}
}

public Action BotUsePowerup(Handle timer, int client) {
	DebugText("Forcing bot %N to use powerup ID %d", client, powerup[client]);
	UsePower(client);
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
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float ang[3], int &weapon) {
	/* if (GetConVarFloat(FindConVar("sm_fortressblast_debug")) >= 1) {
		if (GetEntityFlags(client) & FL_ONGROUND) {
			PrintCenterText(client, "Ground");
		} else {
			PrintCenterText(client, "Air");
		}
	} */
	float coords[3] = 69.420;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
	if (TimeTravel[client]) {
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 520.0);
	}
	if (buttons & 33554432 && (!PreviousAttack3[client]) && StringButtonInt() != 33554432) {
		char button[40];
		GetConVarString(FindConVar("sm_fortressblast_action_use"), button, sizeof(button));
		CPrintToChat(client, "{orange}[Fortress Blast] {red}Special attack is currerntly disabled on this server. You are required to {yellow}perform the '%s' action to use a powerup.", button);
	}
	if (buttons & StringButtonInt() && IsPlayerAlive(client)) {
		UsePower(client);
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
	// Mega Mann stuck-checking loop
	if (MegaMannRotation[client] > 0) {
		if (MegaMannRotation[client] == 1) { // Store co-ordinates on powerup use
			MegaMannCoords[client][0] = coords[0];
			MegaMannCoords[client][1] = coords[1];
			MegaMannCoords[client][2] = coords[2];
		} else if (MegaMannRotation[client] == 102) {
			// Are co-ordinates the same since powerup use?
			if (MegaManCoords[client][0] == coords[0] && MegaManCoords[client][1] == coords[1] && MegaManCoords[client][2] == coords[2]) {
				// Force respawn the player
				TF2_RespawnPlayer(client);
				MegaMannRotation[client] = -5;
				CPrintToChat(client, "{orange}[Fortress Blast] {red}You were respawned since you may have been stuck. Be sure to {yellow}use Mega Mann in open areas {red}and {yellow}move once it is active.");
			}
		}
		MegaMannRotation[client]++;
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
		PowerupParticle(client, 1, 5.0);
	} else if (powerup[client] == 2) {
		// Shock Absorber - 75% damage and 100% knockback resistances for 5 seconds
		ShockAbsorber[client] = true;
		EmitAmbientSound("fortressblast2/shockabsorber_use.mp3", vel, client);
		ClearTimer(ShockAbsorberHandle[client]);
		PowerupParticle(client, 2, 5.0);
		ShockAbsorberHandle[client] = CreateTimer(5.0, RemoveShockAbsorb, client);
	} else if (powerup[client] == 3) {
		// Super Speed - Increased speed, gradually wears off over 10 seconds
		OldSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
		SpeedRotationsLeft[client] = 80;
		EmitAmbientSound("fortressblast2/superspeed_use.mp3", vel, client);
		CreateTimer(0.1, RecalcSpeed, client);
	} else if (powerup[client] == 4) {
		// Super Jump - Launch user into air
		vel[2] = 800.0;
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
		TF2_AddCondition(client, TFCond_StealthedUserBuffFade, 5.0);
		for (int weapon = 0; weapon <= 5 ; weapon++) {
			if (GetPlayerWeaponSlot(client, weapon) != -1) {
				SetEntPropFloat(GetPlayerWeaponSlot(client, weapon), Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 5.0);
				SetEntPropFloat(GetPlayerWeaponSlot(client, weapon), Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 5.0);
			}
		}
		// Cancel active grappling hook
		if (GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") == GetPlayerWeaponSlot(client, 5)) {
			SwitchPrimary(client);
		}
		ClearTimer(TimeTravelHandle[client]);
		TimeTravelHandle[client] = CreateTimer(5.0, RemoveTimeTravel, client);
		EmitAmbientSound("fortressblast2/timetravel_use.mp3", vel, client);
	} else if (powerup[client] == 7) {
		// Blast - Create explosion at user
		PowerupParticle(client, 7, 1.0);
		EmitAmbientSound("fortressblast2/blast_use.mp3", vel, client);
		float pos1[3];
		GetClientAbsOrigin(client, pos1);
		float pos2[3];
		for (int client2 = 1 ; client2 <= MaxClients ; client2++ ) {
			if (IsClientInGame(client2)) {
				GetClientAbsOrigin(client2, pos2);
				if (GetVectorDistance(pos1, pos2) <= 250.0 && GetClientTeam(client) != GetClientTeam(client2)) {
					SDKHooks_TakeDamage(client2, 0, client, (150.0 - (GetVectorDistance(pos1, pos2) * 0.4)), 0, 348);
				}
			}
		}
		TF2_RemovePlayerDisguise(client);
	} else if(powerup[client] == 8) {
		SetVariantString("1.75 0");
		AcceptEntityInput(client, "SetModelScale");
		SetEntityHealth(client, (GetClientHealth(client) * 4));
		ClearTimer(MegaMannHandle[client]);
		MegaMannRotation[client] = 1; // Activate Mega Mann stuck-checking loop
		MegaMannHandle[client] = CreateTimer(10.0, RemoveMegaMann, client);
	}
	powerup[client] = 0;
}

public Action RemoveMegaMann(Handle timer, int client) {
	MegaMannRotation[client] = 0;
	MegaMannHandle[client] = INVALID_HANDLE;
	SetVariantString("1 0");
	AcceptEntityInput(client, "SetModelScale");
	if (GetClientHealth(client) > TF2_GetPlayerMaxHealth(client)) {
		SetEntityHealth(client, TF2_GetPlayerMaxHealth(client));
	}
}

public Action RemoveTimeTravel(Handle timer, int client) {
	TimeTravelHandle[client] = INVALID_HANDLE;
	TimeTravel[client] = false;
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
		Handle text = CreateHudSynchronizer();
  		SetHudTextParams(0.9, 0.5, 0.25, 255, 255, 0, 255);
  		if (powerup[client] == 1) {
			ShowSyncHudText(client, text, "Collected powerup:\nSuper Bounce");
		} else if (powerup[client] == 2) {
			ShowSyncHudText(client, text, "Collected powerup:\nShock Absorber");
		} else if (powerup[client] == 3) {
			ShowSyncHudText(client, text, "Collected powerup:\nSuper Speed");
		} else if (powerup[client] == 4) {
			ShowSyncHudText(client, text, "Collected powerup:\nSuper Jump");
		} else if (powerup[client] == 5) {
			ShowSyncHudText(client, text, "Collected powerup:\nGyrocopter");
		} else if (powerup[client] == 6) {
			ShowSyncHudText(client, text, "Collected powerup:\nTime Travel");
		} else if (powerup[client] == 7) {
			ShowSyncHudText(client, text, "Collected powerup:\nBlast");
		} else if (powerup[client] == 8) {
			ShowSyncHudText(client, text, "Collected powerup:\nMega Mann");
		}		
		CloseHandle(text);
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

PowerupParticle(int client, int id, float time) {
	int particle = CreateEntityByName("info_particle_system");
	if (id == 1) {
		DispatchKeyValue(particle, "effect_name", "teleporter_blue_charged_level2");
	}
	if (id == 2) {
		DispatchKeyValue(particle, "effect_name", "teleporter_red_charged_level2");
	}
	if (id == 7) {
		DispatchKeyValue(particle, "effect_name", "rd_robot_explosion");
	}
	AcceptEntityInput(particle, "SetParent", client);
	AcceptEntityInput(particle, "Start");
	DispatchSpawn(particle);
	ActivateEntity(particle);
	float coords[3] = 69.420;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", coords);
	TeleportEntity(particle, coords, NULL_VECTOR, NULL_VECTOR);
	int freeid = -5;
	for (int partid = MAX_PARTICLES; partid > 0 ; partid--){
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
	if (GetConVarFloat(FindConVar("sm_fortressblast_debug")) >= 1) {
		int len = strlen(text) + 255;
		char[] format = new char[len];
		VFormat(format, len, text, 2);
		CPrintToChatAll("{orange}[Fortress Blast] {default}%s", format);
	}
}

int StringButtonInt() {
	char button[40];
	GetConVarString(FindConVar("sm_fortressblast_action_use"), button, sizeof(button));
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
