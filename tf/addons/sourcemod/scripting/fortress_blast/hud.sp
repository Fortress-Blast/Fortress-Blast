/* DisplayHud()
==================================================================================================== */

public void DisplayHud(int iClient) {
	if (gi_CollectedPowerup[iClient] != 0) {
		if (BlockPowerup(iClient)) {
			SetHudTextParams(0.825, 0.5, 0.25, 255, 0, 0, 0);
		} else {
			SetHudTextParams(0.825, 0.5, 0.25, 255, 255, 0, 255);
		}
		if (gi_CollectedPowerup[iClient] == -1) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nULTRA POWERUP!!");
		} else if (gi_CollectedPowerup[iClient] == 1) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nSuper Bounce");
		} else if (gi_CollectedPowerup[iClient] == 2) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nShock Absorber");
		} else if (gi_CollectedPowerup[iClient] == 3) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nSuper Speed");
		} else if (gi_CollectedPowerup[iClient] == 4) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nSuper Jump");
		} else if (gi_CollectedPowerup[iClient] == 5) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nGyrocopter");
		} else if (gi_CollectedPowerup[iClient] == 6) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nTime Travel");
		} else if (gi_CollectedPowerup[iClient] == 7) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nBlast");
		} else if (gi_CollectedPowerup[iClient] == 8) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nMega Mann");
		} else if (gi_CollectedPowerup[iClient] == 9) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nFrost Touch");
		} else if (gi_CollectedPowerup[iClient] == 10) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nMystery");
		} else if (gi_CollectedPowerup[iClient] == 11) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nTeleportation");
		} else if (gi_CollectedPowerup[iClient] == 12) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nMagnetism");
		} else if (gi_CollectedPowerup[iClient] == 13) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nEffect Burst");
		} else if (gi_CollectedPowerup[iClient] == 14) {
			ShowSyncHudText(iClient, ghud_PowerupText, "Collected powerup:\nDizzy Bomb");
		}
	}
	if (GiftHunt && gi_VictoryTeam == -1) {
		SetHudTextParams(-1.0, 0.775, 0.25, 255, 255, 255, 255);
		if (gi_GiftBonus[2] < 2 && gi_GiftBonus[3] < 2) {
  			ShowSyncHudText(iClient, ghud_GiftText, "BLU: %d | Playing to %d gifts | RED: %d", gi_CollectedGifts[3], gi_GiftGoal, gi_CollectedGifts[2]);
		} else if (gi_GiftBonus[2] < 2 && gi_GiftBonus[3] >= 2) {
  			ShowSyncHudText(iClient, ghud_GiftText, "BLU: %d (x%d)| Playing to %d gifts | RED: %d", gi_CollectedGifts[3], gi_GiftBonus[3], gi_GiftGoal, gi_CollectedGifts[2]);
		} else if (gi_GiftBonus[2] >= 2 && gi_GiftBonus[3] < 2) {
  			ShowSyncHudText(iClient, ghud_GiftText, "BLU: %d | Playing to %d gifts | RED: %d (x%d)", gi_CollectedGifts[3], gi_GiftGoal, gi_CollectedGifts[2], gi_GiftBonus[2]);
		}
	}
}
