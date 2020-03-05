/* DoHudText()
The HUD function for the plugin
On April Fools most of the powerups have the word 'Super' inserted into them
==================================================================================================== */

public void DoHudText(int client) {
	if (PowerupID[client] != 0) {
		if (BlockPowerup(client)) {
			SetHudTextParams(0.825, 0.5, 0.25, 255, 0, 0, 0);
		} else {
			SetHudTextParams(0.825, 0.5, 0.25, 255, 255, 0, 255);
		}
		if (PowerupID[client] == -1) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nULTRA POWERUP!!");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSUPER POWERUP!!");
			}
		} else if (PowerupID[client] == 1) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Bounce");
		} else if (PowerupID[client] == 2) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nShock Absorber");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Absorber");
			}
		} else if (PowerupID[client] == 3) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Speed");
		} else if (PowerupID[client] == 4) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Jump");
		} else if (PowerupID[client] == 5) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nGyrocopter");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Gyrocopter");
			}
		} else if (PowerupID[client] == 6) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nTime Travel");
		} else if (PowerupID[client] == 7) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nBlast");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Blast");
			}
		} else if (PowerupID[client] == 8) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nMega Mann");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Mann");
			}
		} else if (PowerupID[client] == 9) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nFrost Touch");
		} else if (PowerupID[client] == 10) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nMystery");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Mystery");
			}
		} else if (PowerupID[client] == 11) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nTeleportation");
		} else if (PowerupID[client] == 12) {
			if (!AprilFools()) {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nMagnetism");
			} else {
				ShowSyncHudText(client, PowerupText, "Collected powerup:\nSuper Magnetism");
			}
		} else if (PowerupID[client] == 13) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nEffect Burst");
		} else if (PowerupID[client] == 14) {
			ShowSyncHudText(client, PowerupText, "Collected powerup:\nDizzy Bomb");
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
