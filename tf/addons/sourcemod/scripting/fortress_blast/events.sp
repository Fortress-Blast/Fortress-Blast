/* Event_OnRoundStart()
==================================================================================================== */

public Action Event_OnRoundStart(Event event, const char[] name, bool bDontBroadcast) {
	char sMap[80];
	GetCurrentMap(sMap, sizeof(sMap));
	char sPath[PLATFORM_MAX_PATH + 1];
	// So we dont overload read-writes
	Format(sPath, sizeof(sPath), "scripts/fortress_blast/powerup_spawns/%s.json", sMap);
	gb_MapHasJsonFile = FileExists(sPath);
	if (gc_sm_fortressblast_gifthunt.BoolValue) {
		Format(sPath, sizeof(sPath), "scripts/fortress_blast/gift_spawns/%s.json", sMap);
		GiftHunt = FileExists(sPath);
		if (GiftHunt) {
			gi_GiftBonus[2] = 1;
			gi_GiftBonus[3] = 1;
			JSONObject handle = JSONObject.FromFile(sPath);
			if (handle.HasKey("mode")) { // For single-team objective maps like Attack/Defense and Payload
				char mode[30];
				handle.GetString("mode", mode, sizeof(mode));
				gb_GiftHuntAttackDefense = StrEqual(mode, "attackdefense", true);
			}
			gb_GiftHuntNeutralFlag = false;
			int flag;
			while ((flag = FindEntityByClassname(flag, "item_teamflag")) != -1) {
				if (GetEntProp(flag, Prop_Send, "m_iTeamNum") == 0) {
					gb_GiftHuntNeutralFlag = true;
					AcceptEntityInput(flag, "Disable");
				}
			}
		}
	} else {
		GiftHunt = false;
	}
	if (gb_GiftHuntAttackDefense) {
		gb_GiftHuntSetup = true;
	}
	gi_VictoryTeam = -1;
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
	gi_PlayersAmount = 0;
	if (!GameRules_GetProp("m_bInWaitingForPlayers")) {
		for (int client = 1; client <= MaxClients; client++) {
			gi_CollectedPowerup[client] = 0;
			if (IsClientInGame(client)) {
				// Only count bots if ConVar is true
				if (!IsFakeClient(client) || gc_sm_fortressblast_gifthunt_countbots.BoolValue) {
					gi_PlayersAmount++;
				}
				if (gc_sm_fortressblast_intro.BoolValue) {
					CreateTimer(3.0, Timer_DisplayIntro, GetClientSerial(client));
				}
				// Remove powerup effects on round start
				SetEntityGravity(client, 1.0);
				SuperBounce[client] = false;
				ShockAbsorber[client] = false;
				TimeTravel[client] = false;
				gi_SpeedRotationsLeft[client] = 0;
				SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
			}
		}
	}
	CalculateGiftAmountForPlayers();
	RemoveAllPowerups();
	for (int entity = 1; entity <= MAX_EDICTS ; entity++) { // Add powerups and replace Mannpower
		if (IsValidEntity(entity)) {
			char classname[60];
			GetEntityClassname(entity, classname, sizeof(classname));
			if (FindEntityByClassname(0, "tf_logic_mannpower") != -1 && gc_sm_fortressblast_mannpower.IntValue != 0) {
				if ((!gb_MapHasJsonFile || gc_sm_fortressblast_mannpower.IntValue == 2)) {
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
	if (gc_sm_fortressblast_powerups_roundstart.BoolValue) {
		GetPowerupPlacements(false);
	}
	gi_CollectedGifts[2] = 0;
	gi_CollectedGifts[3] = 0;
	int spawnrooms;
	while ((spawnrooms = FindEntityByClassname(spawnrooms, "func_respawnroom")) != -1) {
		SDKHook(spawnrooms, SDKHook_TouchPost, OnTouchRespawnRoom);
	}
}

/* Event_OnSetupFinished()
==================================================================================================== */

public Action Event_OnSetupFinished(Event event, const char[] name, bool bDontBroadcast) {
	if (gb_GiftHuntAttackDefense) {
		gb_GiftHuntSetup = false;
		EntFire("team_round_timer", "Pause");
	}
}

/* Event_OnRoundWin()
==================================================================================================== */

public Action Event_OnRoundWin(Event event, const char[] name, bool bDontBroadcast) {
	gi_VictoryTeam = event.GetInt("team");
	DebugText("Team #%d has won the round", event.GetInt("team"));
}

/* Event_OnPlayerDeath()
==================================================================================================== */

public Action Event_OnPlayerDeath(Event event, const char[] name, bool bDontBroadcast) {
	gi_CollectedPowerup[GetClientOfUserId(event.GetInt("userid"))] = 0;
	// Is dropping powerups enabled
	if (gc_sm_fortressblast_drop.IntValue == 2 || (gc_sm_fortressblast_drop.BoolValue && !gb_MapHasJsonFile)) {
		// Get chance a powerup will be dropped
		float convar = gc_sm_fortressblast_drop_rate.FloatValue;
		float randomNumber = GetRandomFloat(0.0, 99.99);
		if (convar > randomNumber && (gc_sm_fortressblast_drop_teams.IntValue == GetClientTeam(GetClientOfUserId(event.GetInt("userid"))) || gc_sm_fortressblast_drop_teams.IntValue == 1)) {
			DebugText("Dropping powerup due to player death");
			float coords[3];
			GetEntPropVector(GetClientOfUserId(event.GetInt("userid")), Prop_Send, "m_vecOrigin", coords);
			int entity = SpawnPower(coords, false);
			ClearTimer(gh_DestroyPowerup[entity]);
			gh_DestroyPowerup[entity] = CreateTimer(15.0, Timer_DestroyPowerupTime, entity);
		}
	}
}
