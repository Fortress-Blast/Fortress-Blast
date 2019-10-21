#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ripext/json>
#include <tf2>

#define	MAX_EDICT_BITS 11
#define	MAX_EDICTS (1 << MAX_EDICT_BITS)

int powerupid[MAX_EDICTS];
float StoredCoordinates[MAX_EDICTS][3];
bool NoFallDamage[MAXPLAYERS+1] = false;
bool VictoryTime = false;
int powerup[MAXPLAYERS+1] = 0;
bool ShockAbsorber[MAXPLAYERS + 1] = false;
float OldSpeed[MAXPLAYERS+1] = 0.0;
int SpeedRotationsLeft[MAXPLAYERS+1] = 100;

/* Powerup IDs
1 - Super Bounce
2 - Shock Absorber
3 - Super Speed
4 - Super Jump
5 - Gyrocopter
6 - Time Travel */

public OnPluginStart() {
	for (int client = 1; client <= MaxClients ; client++) {
		if (IsClientInGame(client)) {
			SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage); // In case the plugin is reloaded mid-round
		}
	}
	HookEvent("teamplay_round_start", teamplay_round_start);
	HookEvent("teamplay_round_win", teamplay_round_win);
	PrecacheModel("models/props_halloween/pumpkin_loot.mdl");
	RegConsoleCmd("sm_setpowerup", SetPowerup);
}

public Action SetPowerup(int client, int args) {
	char arg[3];
	GetCmdArg(1, arg, sizeof(arg));
	powerup[client] = StringToInt(arg);
}

public Action teamplay_round_start(Event event, const char[] name, bool dontBroadcast) {
	VictoryTime = false;
	for (int client = 1; client <= MaxClients; client++) {
		powerupid[client] = 0;
	}
	GetPowerupPlacements();
}

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast) {
	VictoryTime = true;
}

public OnClientPutInServer(int client) {
	powerup[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}

SpawnPower(float location[3]) {
	int entity = CreateEntityByName("tf_halloween_pickup");
	if (IsValidEdict(entity)) {
		SetEntityModel(entity, "models/props_halloween/pumpkin_loot.mdl");
		powerupid[entity] = GetRandomInt(1, 6);
		if (powerupid[entity] == 1) {
			SetEntityRenderColor(entity, 100, 100, 255, 255);
		} else if (powerupid[entity] == 2) {
			SetEntityRenderColor(entity, 255, 100, 100, 255);
		} else if (powerupid[entity] == 3) {
			SetEntityRenderColor(entity, 255, 255, 100, 255);
		} else if (powerupid[entity] == 4) {
			SetEntityRenderColor(entity, 255, 218, 100, 255);
		} else if (powerupid[entity] == 5) {
			SetEntityRenderColor(entity, 100, 255, 255, 255);
		} else if (powerupid[entity] == 6) {
			SetEntityRenderColor(entity, 100, 255, 100, 255);
		}
		DispatchKeyValue(entity, "pickup_sound", "GetOutOfTheConsoleYouSnoop");
		DispatchKeyValue(entity, "pickup_particle", "GetOutOfTheConsoleYouSnoop");
		AcceptEntityInput(entity, "EnableCollision");
		DispatchSpawn(entity);
		ActivateEntity(entity);
		TeleportEntity(entity, location, NULL_VECTOR, NULL_VECTOR);
		SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
	}
}

public Action OnStartTouch(entity, other) {
	if (other > 0 && other <= MaxClients) {
		float coords[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
		StoredCoordinates[entity][0] = coords[0];
		StoredCoordinates[entity][1] = coords[1];
		StoredCoordinates[entity][2] = coords[2];
		if (!VictoryTime) {
			CreateTimer(10.0, SpawnPowerAfterDelay, entity);
		}
		RemoveEntity(entity);
		// PrintToChatAll("%N has collected a powerup", other);
		powerup[other] = powerupid[entity];
		// PrintToChat(other, "You have received the powerup with ID %d", powerupid[entity]);
		if (powerup[other] == 1) {
			ClientCommand(other, "playgamesound fortressblast/superbounce_pickup.wav");
		} else if (powerup[other] == 2) {
			ClientCommand(other, "playgamesound fortressblast/shockabsorber_pickup.wav");
		} else if(powerup[other] == 3) {
			ClientCommand(other, "playgamesound fortressblast/superspeed_pickup.wav");
		} else if(powerup[other] == 4) {
			ClientCommand(other, "playgamesound fortressblast/superjump_pickup.wav");
		} else if(powerup[other] == 5) {
			ClientCommand(other, "playgamesound fortressblast/gyrocopter_pickup.wav");
		} else if(powerup[other] == 6) {
			ClientCommand(other, "playgamesound fortressblast/timetravel_pickup.wav");
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public Action SpawnPowerAfterDelay(Handle timer, int entity) {
	// PrintToChatAll("A replacement duck has been spawned");
	float coords[3];
	coords[0] = StoredCoordinates[entity][0];
	coords[1] = StoredCoordinates[entity][1];
	coords[2] = StoredCoordinates[entity][2];
	SpawnPower(coords);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float ang[3], int &weapon) {
	if (buttons & IN_ATTACK3) {
		UsePower(client);
	}
	if (NoFallDamage[client] && GetEntityFlags(client) & FL_ONGROUND) {
		NoFallDamage[client] = false; // May be necessary to set this twice, in case their jump doesn't result in fall damage
	}
	DoHudText(client);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]){
	if(attacker == 0 && NoFallDamage[victim]){
		// PrintToChatAll("Fall damage negated");
		NoFallDamage[victim] = false;
		return Plugin_Handled;
	}
	if(ShockAbsorber[victim]){
		damage = damage * 0.25;
		damageForce[0] = 0.0;
		damageForce[1] = 0.0;
		damageForce[2] = 0.0;
	}
	return Plugin_Changed;
}

UsePower(client) {
	if (powerup[client] == 1) {
		// Super Bounce - Uncontrollable bunny hop for 5 seconds
	} else if (powerup[client] == 2) {
		// Shock Absorber - 75% damage and 100% knockback resistances for 5 seconds
		ShockAbsorber[client] = true;
		CreateTimer(5.0, RemoveShockAbsorb, client);
	} else if (powerup[client] == 3) {
		// Super Speed - Increased speed, gradually wears off over 10 seconds
		OldSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
		SpeedRotationsLeft[client] = 100;
		CreateTimer(0.1, RecalcSpeed, client);
	} else if (powerup[client] == 4) {
		// Super Jump - Launch into air and resist initial fall damage
		float vel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
		vel[2] = 800.0;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
		NoFallDamage[client] = true;
	} else if (powerup[client] == 5) {
		// Gyrocopter - 25% gravity for 5 seconds
		SetEntityGravity(client, 0.25);
		CreateTimer(5.0, RestoreGravity, client);
	} else if (powerup[client] == 6 ) {
		// Time Travel - Increased speed and Bonk Atomic Punch effect for 5 seconds
	}
	powerup[client] = 0;
}

public Action RestoreGravity(Handle timer, int client){
	SetEntityGravity(client, 1.0);
}

public Action RemoveShockAbsorb(Handle timer, int client){
	ShockAbsorber[client] = false;
}

public Action RecalcSpeed(Handle timer, int client){
	if(SpeedRotationsLeft[client] > 1){
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", OldSpeed[client] + (SpeedRotationsLeft[client] * 2));
		CreateTimer(0.1, RecalcSpeed, client);
	}
	else{
		TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
	}
	SpeedRotationsLeft[client]--;
}

DoHudText(client) {
	if (powerup[client] != 0){
		Handle text = CreateHudSynchronizer();
  		SetHudTextParams(0.8, 0.1, 0.25, 255, 255, 0, 255);
  		if(powerup[client] == 1){
			ShowSyncHudText(client, text, "Collected powerup\nSuper Bounce");
		}
		if(powerup[client] == 2){
			ShowSyncHudText(client, text, "Collected powerup\nShock Absorber");
		}
		if(powerup[client] == 3){
			ShowSyncHudText(client, text, "Collected powerup\nSuper Speed");
		}
		if(powerup[client] == 4){
			ShowSyncHudText(client, text, "Collected powerup\nSuper Jump");
		}
		if(powerup[client] == 5){
			ShowSyncHudText(client, text, "Collected powerup\nGyrocopter");
		}
		if(powerup[client] == 6){
			ShowSyncHudText(client, text, "Collected powerup\nTime Travel");
		}
		CloseHandle(text);
	}
}

GetPowerupPlacements() {
	char map[80];
	GetCurrentMap(map, sizeof(map));
	char path[PLATFORM_MAX_PATH + 1];
	StrCat(path, sizeof(path), "fortress_blast/powerup_spots/");
	StrCat(path, sizeof(path), map);
	StrCat(path, sizeof(path), ".json");
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
		// PrintToChatAll("Created powerup at %f, %f, %f", coords[0], coords[1], coords[2]);
		if(coords[0] != 0.001){
			SpawnPower(coords);
			if (flipx && flipy) {
				if (coords[0] != centerx || coords[1] != centery) {
					coords[0] = coords[0] - ((coords[0] - centerx) * 2);
					coords[1] = coords[1] - ((coords[1] - centery) * 2);
					// PrintToChatAll("Flipping both axes, new powerup created at %f %f %f", coords[0], coords[1], coords[2]);
					SpawnPower(coords);
				} else {
					// PrintToChatAll("Powerup is at the center and will not be flipped");
   	 			}
			} else if (flipx) {
				if (coords[0] != centerx) {
					coords[0] = coords[0] - ((coords[0] - centerx) * 2);
					// PrintToChatAll("Flipping X axis, new powerup created at %f, %f, %f", coords[0], coords[1], coords[2]);
					SpawnPower(coords);
				} else {
					// PrintToChatAll("Powerup is at the X axis center and will not be flipped");
    				}
			} else if (flipy) {
				if (coords[1] != centery) {
					coords[1] = coords[1] - ((coords[1] - centery) * 2);
					// PrintToChatAll("Flipping Y axis, new powerup created at %f, %f, %f", coords[0], coords[1], coords[2]);
					SpawnPower(coords);
				} else {
					// PrintToChatAll("Powerup is at the Y axis center and will not be flipped");
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
