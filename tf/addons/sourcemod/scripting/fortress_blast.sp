#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ripext/json>
#include <morecolors>
#include <tf2>

#define	MAX_EDICT_BITS 11
#define	MAX_EDICTS (1 << MAX_EDICT_BITS)

int powerupid[MAX_EDICTS];
bool VictoryTime = false;
int powerup[MAXPLAYERS+1] = 0;
bool SuperBounce[MAXPLAYERS + 1] = false;
bool ShockAbsorber[MAXPLAYERS + 1] = false;
float OldSpeed[MAXPLAYERS+1] = 0.0;
float VerticalVelocity[MAXPLAYERS + 1];
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
	RegConsoleCmd("sm_setpowerup", SetPowerup);
	RegConsoleCmd("sm_fortressblast", FBMenu);
	CreateConVar("sm_fortressblast_bot", "1", "Disable or enable bots using powerups.");
	CreateConVar("sm_fortressblast_bot_min", "2", "Minimum time for bots to use a powerup.");
	CreateConVar("sm_fortressblast_bot_max", "15", "Maximum time for bots to use a powerup.");
	PrecacheModel("models/props_halloween/pumpkin_loot.mdl");
	LoadTranslations("common.phrases");
}

public OnMapStart() {
	PrecacheSound("fortressblast/superbounce_use.mp3");
	PrecacheSound("fortressblast/shockabsorber_use.mp3");
	PrecacheSound("fortressblast/superspeed_use.mp3");
	PrecacheSound("fortressblast/superjump_use.mp3");
	PrecacheSound("fortressblast/gyrocopter_use.mp3");
	PrecacheSound("fortressblast/timetravel_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast/superbounce_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast/shockabsorber_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast/superspeed_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast/superjump_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast/gyrocopter_use.mp3");
	AddFileToDownloadsTable("sound/fortressblast/timetravel_use.mp3");
}

public TF2_OnConditionAdded(int client, TFCond condition) {
	if (condition == TFCond_HalloweenKart) {
		powerup[client] = 0;
	}
}

public Action FBMenu(int client, int args) {
	DoMenu(client, 0);
}

public int MenuHandle(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char choice[32];
		menu.GetItem(param2, choice, sizeof(choice));
		if (StrEqual(choice, "info")) {
			DoMenu(param1, 1);
		} else if (StrEqual(choice, "listpowerups")) {
			DoMenu(param1, 2);
		} else if (StrEqual(choice, "credits")) {
			DoMenu(param1, 3);
		}
	}
	if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack) {
			DoMenu(param1, 0);
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}
}

public Action SetPowerup(int client, int args) {
	char arg[MAX_NAME_LENGTH + 1];
	char arg2[3]; // Need to have a check if there's only one argument, apply to command user
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	int player = FindTarget(client, arg);
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
}

public Action teamplay_round_start(Event event, const char[] name, bool dontBroadcast) {
	VictoryTime = false;
	for (int client = 1; client <= MaxClients; client++) {
		powerup[client] = 0;
		CreateTimer(3.0, PesterThisDude, client);
	}
	GetPowerupPlacements();
}

public Action PesterThisDude(Handle timer, int client) {
	CPrintToChat(client, "{haunted}This server is running {yellow}Fortress Blast! {haunted}If you would like to know more or are unsure what a powerup does, type the command {orange}!fortressblast {haunted}into chat.");
}

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast) {
	VictoryTime = true;
}

public OnClientPutInServer(int client) {
	powerup[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	CreateTimer(3.0, PesterThisDude, client);
}

SpawnPower(float location[3]) {
	int entity = CreateEntityByName("tf_halloween_pickup");
	// PrintToChatAll("Spawning powerup with ID %d at %f, %f, %f", entity, location[0], location[1], location[2]);
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
		if (!VictoryTime) {
			float coords[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", coords);
			Handle coordskv = CreateKeyValues("coordskv");
			KvSetFloat(coordskv, "0", coords[0]);
			KvSetFloat(coordskv, "1", coords[1]);
			KvSetFloat(coordskv, "2", coords[2]);
			CreateTimer(10.0, SpawnPowerAfterDelay, coordskv);
		}
		RemoveEntity(entity);
		// PrintToChatAll("%N has collected a powerup", other);
		powerup[other] = powerupid[entity];
		// PrintToChat(other, "You have received the powerup with ID %d", powerupid[entity]);
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
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public Action BotUsePowerup(Handle timer, int client){
	// PrintToChatAll("Making %N use powerup ID %d", client, powerup[client]);
	UsePower(client);
}

public Action SpawnPowerAfterDelay(Handle timer, any data) {
	// PrintToChatAll("A replacement duck has been spawned");
	float coords[3];
	Handle coordskv = data;
	coords[0] = KvGetFloat(coordskv, "0");
	coords[1] = KvGetFloat(coordskv, "1");
	coords[2] = KvGetFloat(coordskv, "2");
	SpawnPower(coords);
}

PlayPowerupSound(int client) {
	if (powerup[client] == 1) {
		ClientCommand(client, "playgamesound fortressblast/superbounce_pickup.wav");
	} else if (powerup[client] == 2) {
		ClientCommand(client, "playgamesound fortressblast/shockabsorber_pickup.wav");
	} else if (powerup[client] == 3) {
		ClientCommand(client, "playgamesound fortressblast/superspeed_pickup.wav");
	} else if (powerup[client] == 4) {
		ClientCommand(client, "playgamesound fortressblast/superjump_pickup.wav");
	} else if (powerup[client] == 5) {
		ClientCommand(client, "playgamesound fortressblast/gyrocopter_pickup.wav");
	} else if (powerup[client] == 6) {
		ClientCommand(client, "playgamesound fortressblast/timetravel_pickup.wav");
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float ang[3], int &weapon) {
	if (buttons & IN_ATTACK3) {
		UsePower(client);
	}
	float vel2[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel2);
	if (GetEntityFlags(client) & FL_ONGROUND) {
		if (VerticalVelocity[client] != 0.0 && SuperBounce[client]) {
			vel2[2] = (VerticalVelocity[client] * -1);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel2);
			// PrintToChat(client, "setting velocity to %f", vel2[2]);
		}
		// PrintCenterText(client, "Current Z velocity %f, stored %f, on the ground", vel2[2], VerticalVelocity[client]);
	} else {
		// PrintCenterText(client, "Current Z velocity %f, stored %f, in the air", vel2[2], VerticalVelocity[client]);
	}
	DoHudText(client);
	VerticalVelocity[client] = vel2[2];
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
	if (ShockAbsorber[victim]) {
		damage = damage * 0.25;
		damageForce[0] = 0.0;
		damageForce[1] = 0.0;
		damageForce[2] = 0.0;
	}
	return Plugin_Changed;
}

UsePower(client) {
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (powerup[client] == 1) {
		// Super Bounce - Uncontrollable bunny hop for 5 seconds
		// Needs way to block fall damage while bouncing (not when falling)
		EmitAmbientSound("fortressblast/superbounce_use.mp3", vel, client);
		VerticalVelocity[client] = 0.0; // Cancel previously stored vertical velocity
		SuperBounce[client] = true;
		CreateTimer(5.0, RemoveSuperBounce, client);
	} else if (powerup[client] == 2) {
		// Shock Absorber - 75% damage and 100% knockback resistances for 5 seconds
		ShockAbsorber[client] = true;
		EmitAmbientSound("fortressblast/shockabsorber_use.mp3", vel, client);
		CreateTimer(5.0, RemoveShockAbsorb, client);
	} else if (powerup[client] == 3) {
		// Super Speed - Increased speed, gradually wears off over 10 seconds
		OldSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
		SpeedRotationsLeft[client] = 100;
		EmitAmbientSound("fortressblast/superspeed_use.mp3", vel, client);
		CreateTimer(0.1, RecalcSpeed, client);
	} else if (powerup[client] == 4) {
		// Super Jump - Launch into air and resist initial fall damage
		vel[2] = 800.0;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
		EmitAmbientSound("fortressblast/superjump_use.mp3", vel, client);
	} else if (powerup[client] == 5) {
		// Gyrocopter - 25% gravity for 5 seconds
		SetEntityGravity(client, 0.25);
		CreateTimer(5.0, RestoreGravity, client);
		EmitAmbientSound("fortressblast/gyrocopter_use.mp3", vel, client);
	} else if (powerup[client] == 6 ) {
		// Time Travel - Increased speed and Bonk Atomic Punch effect for 5 seconds
		EmitAmbientSound("fortressblast/timetravel_use.mp3", vel, client);
	}
	powerup[client] = 0;
}

public Action RestoreGravity(Handle timer, int client) {
	SetEntityGravity(client, 1.0);
}

public Action RemoveSuperBounce(Handle timer, int client) {
	SuperBounce[client] = false;
}

public Action RemoveShockAbsorb(Handle timer, int client) {
	ShockAbsorber[client] = false;
}

public Action RecalcSpeed(Handle timer, int client) {
	if (SpeedRotationsLeft[client] > 1) {
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", OldSpeed[client] + (SpeedRotationsLeft[client] * 2));
		CreateTimer(0.1, RecalcSpeed, client);
	} else {
		TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
	}
	SpeedRotationsLeft[client]--;
}

DoHudText(client) {
	if (powerup[client] != 0) {
		Handle text = CreateHudSynchronizer();
  		SetHudTextParams(0.8, 0.1, 0.25, 255, 255, 0, 255);
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
		}
		CloseHandle(text);
	}
}

GetPowerupPlacements() {
	char map[80];
	GetCurrentMap(map, sizeof(map));
	char path[PLATFORM_MAX_PATH + 1];
	StrCat(path, sizeof(path), "scripts/fortress_blast/powerup_spots/");
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
		if (coords[0] != 0.001) {
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

DoMenu(int client, int menutype) {
	if (menutype == 0) {
		Menu menu = new Menu(MenuHandle);
		menu.SetTitle("Fortress Blast (v0.1)\n============\n");
		menu.AddItem("info", "Introduction");
		menu.AddItem("listpowerups", "Powerups");
		menu.AddItem("credits", "Credits");
		menu.Display(client, MENU_TIME_FOREVER);
	} else if (menutype == 1) {
		Menu menu = new Menu(MenuHandle);
		menu.SetTitle("Introduction\n");
		menu.AddItem("", "Fortress Blast adds collectable powerups to a map that give special abilities for a", ITEMDRAW_RAWLINE);
		menu.AddItem("", "short amount of time. If you have a powerup, you will be able to see what it is in", ITEMDRAW_RAWLINE);
		menu.AddItem("", "the top-right corner of your screen.", ITEMDRAW_RAWLINE);
		menu.AddItem("", "Press your 'Special attack' key to use a powerup. You can set this in TF2's Options.", ITEMDRAW_RAWLINE);
		menu.AddItem("", "Check out the Powerups submenu for information on each collectible.", ITEMDRAW_RAWLINE);
		menu.AddItem("", "", ITEMDRAW_IGNORE);
		SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXITBACK);
		menu.Display(client, MENU_TIME_FOREVER);
	} else if (menutype == 2) {
		Menu menu = new Menu(MenuHandle);
		// I want each pwoerup to be on a different page, could you work this out for me?
		menu.SetTitle("Powerups\n");
		// ------------
		// You need to make sure each page has 8 lines, both content and filler
		menu.AddItem("", "- Gyrocopter -", ITEMDRAW_RAWLINE);
		menu.AddItem("", "The Gyrocopter powerup lowers you gravity to 25%. This powerup can be used to clear", ITEMDRAW_RAWLINE);
		menu.AddItem("", "large gaps or reach new heights, if you are decent at parkour.", ITEMDRAW_RAWLINE);
		NewPage(menu, 5);
		menu.AddItem("", "- Shock Absorber -", ITEMDRAW_RAWLINE);
		menu.AddItem("", "Shock Absorber allows you to resist 75% of all damage and not take knockback. Use", ITEMDRAW_RAWLINE);
		menu.AddItem("", "this when trying take down a player with a high push force.", ITEMDRAW_RAWLINE);
		NewPage(menu, 5);
		menu.AddItem("", "- Super Bounce -", ITEMDRAW_RAWLINE);
		menu.AddItem("", "While this powerup is active, you are forced to uncontrollably bunny hop. This is", ITEMDRAW_RAWLINE);
		menu.AddItem("", "mainly used to clear gaps by bouncing but you can also trick players with your", ITEMDRAW_RAWLINE);
		menu.AddItem("", "unpredictable movement.", ITEMDRAW_RAWLINE);
		NewPage(menu, 4);
		menu.AddItem("", "- Super Jump -", ITEMDRAW_RAWLINE);
		menu.AddItem("", "Plain and simple, Super Jump launches you into the air. If you jump before using", ITEMDRAW_RAWLINE);
		menu.AddItem("", "this powerup, you will travel even higher, just watch out for fall damage.", ITEMDRAW_RAWLINE);
		NewPage(menu, 5);
		menu.AddItem("", "- Super Speed -", ITEMDRAW_RAWLINE);
		menu.AddItem("", "The Super Speed powerup drastically speeds up your movement, but wears off over", ITEMDRAW_RAWLINE);
		menu.AddItem("", "time. It's great for dodging focused fire.", ITEMDRAW_RAWLINE);
		NewPage(menu, 5);
		menu.AddItem("", "- Time Travel -", ITEMDRAW_RAWLINE);
		menu.AddItem("", "Using this powerup makes you invincible and fast, but prevents you from attacking.", ITEMDRAW_RAWLINE);
		menu.AddItem("", "Use this to your advantage in order to get past sentries or difficult opponents.", ITEMDRAW_RAWLINE);
		menu.AddItem("", "", ITEMDRAW_IGNORE);
		SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXITBACK);
		menu.Display(client, MENU_TIME_FOREVER);
	} else if (menutype == 3) {
		Menu menu = new Menu(MenuHandle);
		menu.SetTitle("Credits\n");
		menu.AddItem("", "Programmers - Naleksuh, Jack5", ITEMDRAW_RAWLINE);
		menu.AddItem("", "Sound effects - GarageGames", ITEMDRAW_RAWLINE);
		menu.AddItem("", "", ITEMDRAW_IGNORE);
		menu.AddItem("", "Plugin available at:", ITEMDRAW_RAWLINE);
		menu.AddItem("", "github.com/jack5github/Fortress_Blast", ITEMDRAW_RAWLINE);
		menu.AddItem("", "", ITEMDRAW_IGNORE);
		SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXITBACK);
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

NewPage (Menu menu, int lines) {
	for (int draw = 1; draw <= lines ; draw++) {
		menu.AddItem("", "", ITEMDRAW_NOTEXT);
	}
}
