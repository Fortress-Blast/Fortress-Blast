/* Timer_MiscTimer()
Handles multiple plugin features including Gift Hunt, Super Speed and Dizzy Bomb
==================================================================================================== */

public Action Timer_MiscTimer(Handle timer, any data) {
	if (NumberOfActiveGifts() == 0 && !gb_GiftHuntSetup && (gi_CollectedGifts[2] < gi_GiftGoal || gi_CollectedGifts[3] < gi_GiftGoal)) {
		GetPowerupPlacements(true);
	}
	if (gf_GiftHuntIncrementTime < GetGameTime() && (gi_CollectedGifts[2] >= gi_GiftGoal || gi_CollectedGifts[3] >= gi_GiftGoal) && gc_sm_fortressblast_gifthunt_bonus.BoolValue) {
		if (gi_CollectedGifts[3] < gi_GiftGoal && gi_GiftBonus[3] < 5) {
			gi_GiftBonus[3]++;
			PrintCenterTextAll("Catchup bonus: gi_CollectedGifts are now worth x%d for BLU team.", gi_GiftBonus[3]);
		} else if (gi_CollectedGifts[2] < gi_GiftGoal && gi_GiftBonus[2] < 5) {
			gi_GiftBonus[2]++;
			PrintCenterTextAll("Catchup bonus: gi_CollectedGifts are now worth x%d for RED team.", gi_GiftBonus[2]);
		}

		DebugText("Incremenet time is %f , game time is %f", gf_GiftHuntIncrementTime, GetGameTime());
		gf_GiftHuntIncrementTime = GetGameTime() + 60.0;
	}
	for (int iClient = 1 ; iClient <= MaxClients ; iClient++ ) {
		if (!IsValidClient(iClient)) {
			continue;
		}

		if (gi_SpeedRotationsLeft[iClient] > 0) {
			if (IsPlayerAlive(iClient)) {
				if (GetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed") != gf_SuperSpeed[iClient]) { // If TF2 changed the speed
					gf_OldSpeed[iClient] = GetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed");
				}
				gf_SuperSpeed[iClient] = gf_OldSpeed[iClient] + (gi_SpeedRotationsLeft[iClient] * 2);
				SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed", gf_SuperSpeed[iClient]);
			}
		}

		gi_SpeedRotationsLeft[iClient]--;
		if (gi_DizzyProgress[iClient] <= (10 * gc_sm_fortressblast_dizzy_length.FloatValue) && gi_DizzyProgress[iClient] != -1) {
			float fAngles[3];
			GetClientAbsAngles(iClient, fAngles);
			if (!TF2_IsPlayerInCondition(iClient, TFCond_Taunting)) {
				float ang = Sine((PI * gc_sm_fortressblast_dizzy_states.FloatValue * gi_DizzyProgress[iClient]) / (10 * gc_sm_fortressblast_dizzy_length.FloatValue)) * ((10 * gc_sm_fortressblast_dizzy_length.FloatValue) - gi_DizzyProgress[iClient]);
				if (gb_NegativeDizzy[iClient]) {
					fAngles[2] = (ang * -1);
				} else {
					fAngles[2] = ang;
				}
				DebugText("Dizzy Bomb angle is %f at step %d", fAngles[2], gi_DizzyProgress[iClient]);
			} else {
				fAngles[2] = 0.0;
			}
			TeleportEntity(iClient, NULL_VECTOR, fAngles, NULL_VECTOR);
			gi_DizzyProgress[iClient] += 1;
		}
	}
}

/* Timer_DisplayIntro()
==================================================================================================== */

public Action Timer_DisplayIntro(Handle timer, int iClientSerial) {
	int iClient = GetClientFromSerial(iClientSerial);
	if (IsValidClient(iClient)) {
		return Plugin_Handled;
	}

	CPrintToChat(iClient, "%s {haunted}This server is running {yellow}Fortress Blast v%s!", MESSAGE_PREFIX, PLUGIN_VERSION);
	CPrintToChat(iClient, "{haunted}If you would like to know more or are unsure what a powerup does, type the command {yellow}!fbu {haunted}into chat.");

	return Plugin_Handled;
}

/* Timer_DeleteEdict()
==================================================================================================== */

public Action Timer_DeleteEdict(Handle timer, int iEntity) {
	if (IsValidEdict(iEntity)) {
		RemoveEdict(iEntity);
	}

	return Plugin_Stop;
}