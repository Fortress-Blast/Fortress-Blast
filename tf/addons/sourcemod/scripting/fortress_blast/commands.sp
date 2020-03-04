/* Command_FortressBlast()
==================================================================================================== */

public Action Command_FortressBlast(int iClient, int iArgs) {
	if (!IsValidClient(iClient)) {
		return Plugin_Handled;
	}

	char sArgument[30];
	GetCmdArg(1, sArgument, sizeof(sArgument));

	// Command '!fbu force' will print intro message to everyone if user is an admin
	if (StrEqual(sArgument, "force")) {
		if (!AdminCommand(iClient)) {
			return Plugin_Handled;
		}

		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++) {
			if (IsValidClient(iPlayer)) {
				CreateTimer(0.1, Timer_DisplayIntro, GetClientSerial(iPlayer));
			}
		}

		return Plugin_Handled;
	}

	int iBitField = gc_sm_fortressblast_powerups.IntValue;
	if (iBitField < 1 && iBitField > ((Bitfieldify(gi_NumberOfPowerups) * 2) - 1)) {
		iBitField = -1;
	}

	char sURL[200];
	char sAction[15];
	gc_sm_fortressblast_action.GetString(sAction, sizeof(sAction));
	Format(sURL, sizeof(sURL), "https://fortress-blast.github.io/%s?powerups-enabled=%d&action=%s&gifthunt=%b&ultra=%f", MOTD_VERSION, iBitField, sAction, gc_sm_fortressblast_gifthunt.BoolValue, gc_sm_fortressblast_ultra_rate.FloatValue);
	AdvMOTD_ShowMOTDPanel(iClient, "", sURL, MOTDPANEL_TYPE_URL, true, true, true, INVALID_FUNCTION);
	CPrintToChat(iClient, "%s {haunted}Opening Fortress Blast manual... If nothing happened, open your developer console and {yellow}set cl_disablehtmlmotd to 0{haunted}, then try again.", MESSAGE_PREFIX);

	return Plugin_Handled;
}

/* Command_SetPowerup()
==================================================================================================== */

public Action Command_SetPowerup(int iClient, int iArgs) {
	if (!AdminCommand(iClient)) {
		return Plugin_Handled;
	}

	char sArgumentOne[MAX_NAME_LENGTH + 1];
	char sArgumentTwo[3]; // Need to have a check if there's only one argument, apply to command user
	GetCmdArg(1, sArgumentOne, sizeof(sArgumentOne));
	GetCmdArg(2, sArgumentTwo, sizeof(sArgumentTwo));

	// The approach of this is deliberate, to be as if they typed like normal
	if (StrEqual(sArgumentOne, "@all")) {
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++) {
			if (IsClientInGame(iPlayer)) {
				FakeClientCommand(iClient, "sm_setpowerup #%d %d", GetClientUserId(iPlayer), StringToInt(sArgumentTwo));
			}
		}
		return Plugin_Handled;
	} else if (StrEqual(sArgumentOne, "@red")) {
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++) {
			if (IsClientInGame(iPlayer) && GetClientTeam(iPlayer) == 2) {
				FakeClientCommand(iClient, "sm_setpowerup #%d %d", GetClientUserId(iPlayer), StringToInt(sArgumentTwo));
			}
		}
		return Plugin_Handled;
	} else if (StrEqual(sArgumentOne, "@blue")) {
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++) {
			if (IsClientInGame(iPlayer) && GetClientTeam(iPlayer) == 3) {
				FakeClientCommand(iClient, "sm_setpowerup #%d %d", GetClientUserId(iPlayer), StringToInt(sArgumentTwo));
			}
		}
		return Plugin_Handled;
	} else if (StrEqual(sArgumentOne, "@bots")) {
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++) {
			if (IsClientInGame(iPlayer) && IsFakeClient(iPlayer)) {
				FakeClientCommand(iClient, "sm_setpowerup #%d %d", GetClientUserId(iPlayer), StringToInt(sArgumentTwo));
			}
		}
		return Plugin_Handled;
	} else if (StrEqual(sArgumentOne, "@humans")) {
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++) {
			if (IsClientInGame(iPlayer) && !IsFakeClient(iPlayer)) {
				FakeClientCommand(iClient, "sm_setpowerup #%d %d", GetClientUserId(iPlayer), StringToInt(sArgumentTwo));
			}
		}
		return Plugin_Handled;
	}

	int iTarget = FindTarget(iClient, sArgumentOne, false, false);
	gi_CollectedPowerup[iTarget] = StringToInt(sArgumentTwo);
	CollectedPowerup(iTarget);
	DebugText("%N set %N's powerup to ID %d", iClient, iTarget, StringToInt(sArgumentTwo));

	return Plugin_Handled;
}

/* Command_CoordsJson()
==================================================================================================== */

public Action Command_CoordsJson(int iClient, int iArgs) {

	if (!IsValidClient(iClient)) {
		return Plugin_Handled;
	}

	float fPoints[3];
	GetCollisionPoint(iClient, fPoints);
	CPrintToChat(iClient, "{haunted}\"#-x\": \"%d\", \"#-y\": \"%d\", \"#-z\": \"%d\",", RoundFloat(fPoints[0]), RoundFloat(fPoints[1]), RoundFloat(fPoints[2]));

	return Plugin_Handled;
}

/* Command_SpawnPowerup()
==================================================================================================== */

public Action Command_SpawnPowerup(int iClient, int iArgs) {
	if (!IsValidClient(iClient)) {
		return Plugin_Handled;
	}

	if (!AdminCommand(iClient)) {
		return Plugin_Handled;
	}

	float fPoints[3];
	GetCollisionPoint(iClient, fPoints);
	char sArgumentOne[3];
	GetCmdArg(1, sArgumentOne, sizeof(sArgumentOne));
	SpawnPower(fPoints, false, StringToInt(sArgumentOne));

	return Plugin_Handled;
}

/* Command_RespawnPowerups()
==================================================================================================== */

public Action Command_RespawnPowerups(int iClient, int iArgs) {
	if (!AdminCommand(iClient)) {
		return Plugin_Handled;
	}

	RemoveAllPowerups();
	GetPowerupPlacements(false);

	return Plugin_Handled;
}