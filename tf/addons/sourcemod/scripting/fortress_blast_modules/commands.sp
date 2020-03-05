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
	char arg2[3];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	// Fake client commands used intentionally, sets every player's powerup individually while allowing @ to save time
	if ((StrEqual(arg, "0") || StringToInt(arg) != 0) && StrEqual(arg2, "")) { // Name of target not included, act on client
		FakeClientCommand(client, "sm_setpowerup #%d %d", GetClientUserId(client), StringToInt(arg));
		return Plugin_Handled;
	} else if (StrEqual(arg, "@all")) {
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
