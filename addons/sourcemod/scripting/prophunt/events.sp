/*
 * Copyright (C) 2025  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma semicolon 1
#pragma newdecls required

void Events_Init()
{
	PSM_AddEventHook("player_spawn", OnGameEvent_player_spawn);
	PSM_AddEventHook("player_death", OnGameEvent_player_death);
	PSM_AddEventHook("player_hurt", OnGameEvent_player_hurt, EventHookMode_Pre);
	PSM_AddEventHook("post_inventory_application", OnGameEvent_post_inventory_application);
	PSM_AddEventHook("teamplay_round_start", OnGameEvent_teamplay_round_start);
	PSM_AddEventHook("teamplay_round_win", OnGameEvent_teamplay_round_win);
	PSM_AddEventHook("arena_round_start", OnGameEvent_arena_round_start);
}

static void OnGameEvent_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	TFTeam team = TF2_GetClientTeam(client);
	TFClassType class = TF2_GetPlayerClass(client);
	
	if (team == TFTeam_Props)
	{
		TF2_SetPlayerClass(client, TFClass_Scout, _, false);
		AcceptEntityInput(client, "DisableShadow");
		
		// Some things, like setting conditions, only works with a delay
		CreateTimer(0.1, Timer_PropPostSpawn, GetClientSerial(client));
	}
	
	if (team == TFTeam_Hunters && class == TFClass_Spy)
	{
		// Prevent Spy from using TargetID to find props
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_TARGET_ID);
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") & ~HIDEHUD_TARGET_ID);
	}
	
	SetEntityGravity(client, ph_gravity_modifier.FloatValue);
}

static void OnGameEvent_player_death(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	
	if (TF2_GetClientTeam(victim) == TFTeam_Props)
	{
		PHPlayer(victim).PropLockEnabled = false;
	}
	
	if (victim != attacker && IsEntityClient(attacker) && IsClientInGame(attacker) && IsPlayerAlive(attacker))
	{
		// Nerf health reward for props
		int healthToAdd;
		if (TF2_GetClientTeam(attacker) == TFTeam_Props)
			healthToAdd = Min(GetPlayerMaxHealth(victim) / 2, ph_prop_max_health.IntValue - GetEntityHealth(attacker));
		else
			healthToAdd = GetPlayerMaxHealth(victim);
		
		if (healthToAdd > 0)
		{
			// Give the attacker some health back
			AddEntityHealth(attacker, healthToAdd);
			
			// The assister gets a bit of health as well
			if (IsEntityClient(assister) && IsClientInGame(assister) && IsPlayerAlive(assister))
				AddEntityHealth(assister, healthToAdd / 2);
		}
	}
	
	CheckLastPropStanding(victim);
}

static Action OnGameEvent_player_hurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	if (TF2_GetClientTeam(victim) == TFTeam_Props && PHPlayer(victim).PropLockEnabled)
		return Plugin_Stop;
	
	return Plugin_Continue;
}

static void OnGameEvent_post_inventory_application(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(client) == TFTeam_Props && !PHPlayer(client).IsLastProp)
	{
		// Fixes an exploit where you could keep your hunter weapons as a prop
		TF2_RemoveAllWeapons(client);
	}
	else if (TF2_GetClientTeam(client) == TFTeam_Hunters)
	{
		// Quick and dirty way to restore alpha values from previous round
		for (int slot = 0; slot <= 5; slot++)
		{
			int weapon = GetPlayerWeaponSlot(client, slot);
			if (weapon != -1)
				SetItemAlpha(weapon, 255);
		}
		
		// Generate a Grappling Hook for the Hunters
		Handle item = TF2Items_CreateItem(PRESERVE_ATTRIBUTES);
		
		char classname[64];
		TF2Econ_GetItemClassName(ITEM_DEFINDEX_GRAPPLINGHOOK, classname, sizeof(classname));
		
		TF2Items_SetClassname(item, classname);
		TF2Items_SetItemIndex(item, ITEM_DEFINDEX_GRAPPLINGHOOK);
		TF2Items_SetLevel(item, 1);
		
		int grapplingHook = TF2Items_GiveNamedItem(client, item);
		
		delete item;
		
		SetEntProp(grapplingHook, Prop_Send, "m_bValidatedAttachedEntity", true);
		EquipPlayerWeapon(client, grapplingHook);
	}
}

static void OnGameEvent_teamplay_round_start(Event event, const char[] name, bool dontBroadcast)
{
	g_InSetup = false;
	g_IsLastPropStanding = false;
	
	delete g_ControlPointBonusTimer;
	
	// Start a truce to avoid murder before the round even started
	GameRules_SetProp("m_bTruceActive", ph_setup_truce.BoolValue);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		PHPlayer(client).Reset();
	}
}

static void OnGameEvent_teamplay_round_win(Event event, const char[] name, bool dontBroadcast)
{
	delete g_ControlPointBonusTimer;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		// Reset this so no prop spawns with guns next round
		PHPlayer(client).IsLastProp = false;
	}
	
	// Always switch teams on round end
	SDKCall_CTeamplayRules_SetSwitchTeams(true);
}

static void OnGameEvent_arena_round_start(Event event, const char[] name, bool dontBroadcast)
{
	g_InSetup = true;
	
	// Create the setup and round timer
	int timer = CreateEntityByName("team_round_timer");
	if (timer != -1)
	{
		DispatchKeyValue(timer, "show_in_hud", "1");
		SetEntProp(timer, Prop_Data, "m_nSetupTimeLength", ph_setup_time.IntValue);
		SetEntProp(timer, Prop_Data, "m_nTimerInitialLength", ph_round_time.IntValue);
		SetEntProp(timer, Prop_Data, "m_nTimerMaxLength", ph_round_time.IntValue);
		
		if (DispatchSpawn(timer))
		{
			AcceptEntityInput(timer, "Enable");
			
			HookSingleEntityOutput(timer, "OnSetupFinished", EntityOutput_OnSetupFinished, true);
			HookSingleEntityOutput(timer, "OnFinished", EntityOutput_OnFinished, true);
		}
	}
	
	if (ph_hunter_setup_freeze.BoolValue)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client))
				continue;
			
			if (TF2_GetClientTeam(client) != TFTeam_Hunters)
				continue;
			
			TF2Attrib_AddCustomPlayerAttribute(client, "no_attack", 1.0);
		}
	}
}

static void Timer_PropPostSpawn(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (client != 0)
	{
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", false);
		
		// Enable thirdperson
		SetVariantInt(PHPlayer(client).InForcedTauntCam);
		AcceptEntityInput(client, "SetForcedTauntCam");
		
		// Apply gameplay conditions
		TF2_AddCondition(client, TFCond_SpawnOutline);
		
		if (ph_prop_afterburn_immune.BoolValue)
			TF2_AddCondition(client, TFCond_AfterburnImmune);
	}
}

static Action Timer_RefreshControlPointBonus(Handle timer)
{
	if (timer != g_ControlPointBonusTimer)
		return Plugin_Stop;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		PHPlayer(client).HasReceivedBonus = false;
	}
	
	CPrintToChatAll("%s %t", PLUGIN_TAG, "PH_Bonus_Refreshed");
	
	return Plugin_Continue;
}

static Action EntityOutput_OnSetupFinished(const char[] output, int caller, int activator, float delay)
{
	g_InSetup = false;
	
	// Setup control point bonus
	g_ControlPointBonusTimer = CreateTimer(ph_bonus_refresh_interval.FloatValue, Timer_RefreshControlPointBonus, _, TIMER_REPEAT);
	TriggerTimer(g_ControlPointBonusTimer);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (TF2_GetClientTeam(client) != TFTeam_Hunters)
			continue;
		
		TF2Attrib_RemoveCustomPlayerAttribute(client, "no_attack");
	}
	
	// Trigger named relays
	char relayName[64];
	ph_relay_name.GetString(relayName, sizeof(relayName));
	
	if (relayName[0] != EOS)
	{
		int relay = -1;
		while ((relay = FindEntityByClassname(relay, "logic_relay")) != -1)
		{
			char name[64];
			GetEntPropString(relay, Prop_Data, "m_iName", name, sizeof(name));
			
			if (StrEqual(name, relayName))
				AcceptEntityInput(relay, "Trigger");
		}
	}
	
	// Open all doors in the map
	if (ph_open_doors_after_setup.BoolValue)
	{
		int door = -1;
		while ((door = FindEntityByClassname(door, "func_door")) != -1)
		{
			AcceptEntityInput(door, "Open");
		}
	}
	
	// End the truce
	GameRules_SetProp("m_bTruceActive", false);
	
	return Plugin_Continue;
}

static Action EntityOutput_OnFinished(const char[] output, int caller, int activator, float delay)
{
	SetWinningTeam(TFTeam_Props);
	
	return Plugin_Continue;
}
