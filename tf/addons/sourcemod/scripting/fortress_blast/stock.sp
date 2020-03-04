/* InsertServerTag()
==================================================================================================== */

stock void InsertServerTag(const char[] sNewTag) {
	ConVar tags = FindConVar("sv_tags");
	if (tags == null) {
		return;
	}

	char sServerTags[256];
	tags.GetString(sServerTags, sizeof(sServerTags));

	// Tag already exists
	if (StrContains(sServerTags, sNewTag, false) != -1) {
		return;
	}

	// Insert server tag at end
	Format(sServerTags, sizeof(sServerTags), "%s,%s", sServerTags, sNewTag);
	tags.SetString(sServerTags);
}

/* IsValidClient()
==================================================================================================== */

stock bool IsValidClient(int iClient, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= iClient <= MaxClients) || !IsClientInGame(iClient) || (IsFakeClient(iClient) && !bAllowBots) || IsClientSourceTV(iClient) || IsClientReplay(iClient) || (!bAllowDead && !IsPlayerAlive(iClient)))
	{
		return false;
	}
	return true;
}

/* GetPlayerMaxHealth()
==================================================================================================== */

stock int GetPlayerMaxHealth(int iClient) {
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, iClient);
}

/* ColorizePlayer()
Roll the Dice function with new syntax
==================================================================================================== */

stock void ColorizePlayer(int iClient, int iColor[4]) {
	SetEntityColor(iClient, iColor);
	for (int i = 0; i < 3; i++) {
		int iWeapon = GetPlayerWeaponSlot(iClient, i);
		if (iWeapon > MaxClients && IsValidEntity(iWeapon)) {
			SetEntityColor(iWeapon, iColor);
		}
	}

	char sClassName[20];
	for (int i = MaxClients + 1; i < GetMaxEntities(); i++) {
		if (!IsValidEntity(i)) {
			continue;
		}

		GetEdictClassname(i, sClassName, sizeof(sClassName));
		if ((strncmp(sClassName, "tf_wearable", 11) == 0 || strncmp(sClassName, "tf_powerup", 10) == 0) && GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == iClient) {
			SetEntityColor(i, iColor);
		}
	}

	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hDisguiseWeapon");
	if (iWeapon > MaxClients && IsValidEntity(iWeapon)) {
		SetEntityColor(iWeapon, iColor);
	}

	TF2_RemoveCondition(iClient, TFCond_DemoBuff);
}

/* CreateRagdoll()
Roll the Dice function with new syntax
==================================================================================================== */

stock int CreateRagdoll(int iClient) {
	int iRagdoll = CreateEntityByName("tf_ragdoll");
	if (iRagdoll > MaxClients && IsValidEntity(iRagdoll)) {
		float fPosition[3];
		float fAngle[3];
		float fVelocity[3];
		GetClientAbsOrigin(iClient, fPosition);
		GetClientAbsAngles(iClient, fAngle);
		TeleportEntity(iRagdoll, fPosition, fAngle, fVelocity);
		SetEntProp(iRagdoll, Prop_Send, "m_iPlayerIndex", iClient);
		SetEntProp(iRagdoll, Prop_Send, "m_bIceRagdoll", 1);
		SetEntProp(iRagdoll, Prop_Send, "m_iTeam", GetClientTeam(iClient));
		SetEntProp(iRagdoll, Prop_Send, "m_iClass", view_as<int>(TF2_GetPlayerClass(iClient)));
		SetEntProp(iRagdoll, Prop_Send, "m_bOnGround", 1);

		// Fix oddly shaped statues
		SetEntPropFloat(iRagdoll, Prop_Send, "m_flHeadScale", GetEntPropFloat(iClient, Prop_Send, "m_flHeadScale"));
		SetEntPropFloat(iRagdoll, Prop_Send, "m_flTorsoScale", GetEntPropFloat(iClient, Prop_Send, "m_flTorsoScale"));
		SetEntPropFloat(iRagdoll, Prop_Send, "m_flHandScale", GetEntPropFloat(iClient, Prop_Send, "m_flHandScale"));

		SetEntityMoveType(iRagdoll, MOVETYPE_NONE);
		DispatchSpawn(iRagdoll);
		ActivateEntity(iRagdoll);

		return iRagdoll;
	}

	return -1;
}

/* IsEntityStuck()
Roll the Dice function with new syntax
==================================================================================================== */

public bool IsEntityStuck(int iEntity) {
	float fOrigin[3];
	float fMins[3];
	float fMaxs[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", fMaxs);

	TR_TraceHullFilter(fOrigin, fOrigin, fMins, fMaxs, MASK_SOLID, TraceFilterNotSelf, iEntity);
	return TR_DidHit();
}

/* SetThirdPerson()
Roll the Dice function with new syntax
==================================================================================================== */

public void SetThirdPerson(int iClient, bool bEnabled) {
	if (bEnabled) {
		SetVariantInt(1);
	} else {
		SetVariantInt(0);
	}
	AcceptEntityInput(iClient, "SetForcedTauntCam");
}

/* SetEntityColor()
Roll the Dice function with new syntax
==================================================================================================== */

stock void SetEntityColor(int iEntity, int iColor[4]) {
	SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iEntity, iColor[0], iColor[1], iColor[2], iColor[3]);
}

/* BlockAttacking()
Roll the Dice function with new syntax
==================================================================================================== */

public void BlockAttacking(int iClient, float fTime) {
	for (int iWeapon = 0; iWeapon <= 5 ; iWeapon++) {
		if (GetPlayerWeaponSlot(iClient, iWeapon) != -1) {
			SetEntPropFloat(GetPlayerWeaponSlot(iClient, iWeapon), Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + fTime);
			SetEntPropFloat(GetPlayerWeaponSlot(iClient, iWeapon), Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + fTime);
		}
	}
}

/* AdminCommand()
==================================================================================================== */

public bool AdminCommand(int iClient) {
	if (!CheckCommandAccess(iClient, "", AdminFlagInt()) && !gc_sm_fortressblast_debug.BoolValue) {
		CPrintToChat(iClient, "%s {red}You do not have permission to use this command.", MESSAGE_PREFIX);
		return false;
	}

	return true;
}

/* TraceEntityFilterPlayer()
==================================================================================================== */

stock bool TraceEntityFilterPlayer(int iEntity, int iContentMask) {
	return iEntity > MaxClients;
}

/* TraceFilterNotSelf()
==================================================================================================== */

public bool TraceFilterNotSelf(int iEntity, int iContentMask, any iClient) {
	if (iEntity == iClient) {
		return false;
	}
	return true;
}

/* EntFire()
==================================================================================================== */

stock bool EntFire(char[] sTargetName, char[] sInput, char sParameter[] = "", float fDelay = 0.0) {
	char sBuffer[255];
	Format(sBuffer, sizeof(sBuffer), "OnUser1 %s:%s:%s:%f:1", sTargetName, sInput, sParameter, fDelay);

	int iEntity = CreateEntityByName("info_target");
	if (IsValidEdict(iEntity)) {
		DispatchSpawn(iEntity);
		ActivateEntity(iEntity);
		SetVariantString(sBuffer);
		AcceptEntityInput(iEntity, "AddOutput");
		AcceptEntityInput(iEntity, "FireUser1");
		CreateTimer(0.0, Timer_DeleteEdict, iEntity);

		return true;
	}

	return false;
}

/* GetCollisionPoint()
==================================================================================================== */

stock void GetCollisionPoint(int iClient, float fPosition[3]) {
	float fOrigin[3];
	float fAngles[3];

	GetClientEyePosition(iClient, fOrigin);
	GetClientEyeAngles(iClient, fAngles);

	Handle trace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);

	if (TR_DidHit(trace)) {
		TR_GetEndPosition(fPosition, trace);
		delete trace;
		return;
	}

	delete trace;
}

/* StringButtonInt()
==================================================================================================== */

stock int StringButtonInt() {
	char sButton[40];
	gc_sm_fortressblast_action.GetString(sButton, sizeof(sButton));
	if (StrEqual(sButton, "attack")) {
		return 1;
	} else if (StrEqual(sButton, "jump")) {
		return 2;
	} else if (StrEqual(sButton, "duck")) {
		return 4;
	} else if (StrEqual(sButton, "forward")) {
		return 8;
	} else if (StrEqual(sButton, "back")) {
		return 16;
	} else if (StrEqual(sButton, "use")) {
		return 32;
	} else if (StrEqual(sButton, "cancel")) {
		return 64;
	} else if (StrEqual(sButton, "left")) {
		return 128;
	} else if (StrEqual(sButton, "right")) {
		return 256;
	} else if (StrEqual(sButton, "moveleft")) {
		return 512;
	} else if (StrEqual(sButton, "moveright")) {
		return 1024;
	} else if (StrEqual(sButton, "attack2")) {
		return 2048;
	} else if (StrEqual(sButton, "run")) {
		return 4096;
	} else if (StrEqual(sButton, "reload")) {
		return 8192;
	} else if (StrEqual(sButton, "alt1")) {
		return 16384;
	} else if (StrEqual(sButton, "alt2")) {
		return 32768;
	} else if (StrEqual(sButton, "score")) {
		return 65536;
	} else if (StrEqual(sButton, "speed")) {
		return 131072;
	} else if (StrEqual(sButton, "walk")) {
		return 262144;
	} else if (StrEqual(sButton, "zoom")) {
		return 524288;
	} else if (StrEqual(sButton, "weapon1")) {
		return 1048576;
	} else if (StrEqual(sButton, "weapon2")) {
		return 2097152;
	} else if (StrEqual(sButton, "bullrush")) {
		return 4194304;
	} else if (StrEqual(sButton, "grenade1")) {
		return 8388608;
	} else if (StrEqual(sButton, "grenade2")) {
		return 16777216;
	}
	return 33554432; // Special attack
}