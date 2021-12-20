/*
 * Copyright (C) 2021  Mikusch
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

void Events_Initialize()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
	HookEvent("teamplay_round_win", Event_TeamplayRoundWin);
	HookEvent("arena_round_start", Event_ArenaRoundStart);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	// Prevent latespawning
	if (GameRules_GetRoundState() != RoundState_Preround)
	{
		ForcePlayerSuicide(client);
		return;
	}
	
	if (TF2_GetClientTeam(client) == TFTeam_Props)
	{
		AcceptEntityInput(client, "DisableShadow");
		
		// Some things, like setting conditions, only works with a delay
		CreateTimer(0.1, Timer_PropPostSpawn, GetClientSerial(client));
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
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
		// Fully regenerate the killing player
		if (GetEntityHealth(attacker) < GetPlayerMaxHealth(attacker))
			SetEntityHealth(attacker, GetPlayerMaxHealth(attacker));
		
		// Give them some health back
		AddEntityHealth(attacker, 50);
		TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 8.0);
		
		if (IsEntityClient(assister) && IsClientInGame(assister) && IsPlayerAlive(assister))
		{
			// Fully regenerate the assisting player as well
			if (GetEntityHealth(assister) < GetPlayerMaxHealth(assister))
				SetEntityHealth(assister, GetPlayerMaxHealth(assister));
			
			TF2_AddCondition(assister, TFCond_SpeedBuffAlly, 4.0);
		}
	}
	
	if (GameRules_GetRoundState() == RoundState_Stalemate)
	{
		// Count all living props
		int propCount = 0;
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) == TFTeam_Props)
				propCount++;
		}
		
		// The last prop has died, do the last man standing stuff
		if (TF2_GetClientTeam(victim) == TFTeam_Props && propCount == 2)
		{
			EmitSoundToAll("#" ... SOUND_LAST_PROP, _, SNDCHAN_STATIC, SNDLEVEL_NONE);
			
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client) && IsPlayerAlive(client))
				{
					if (TF2_GetClientTeam(client) == TFTeam_Props && client != victim)
					{
						if (ph_regenerate_last_prop.BoolValue)
						{
							PHPlayer(client).IsLastProp = true;
							TF2_RegeneratePlayer(client);
						}
					}
					else if (TF2_GetClientTeam(client) == TFTeam_Hunters)
					{
						TF2_AddCondition(client, TFCond_Jarated, 15.0);
					}
				}
			}
		}
	}
}

public void Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
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

public void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_InSetup = false;
	
	delete g_ControlPointBonusTimer;
	
	// Start a truce to avoid murder before the round even started
	GameRules_SetProp("m_bTruceActive", ph_setup_truce.BoolValue);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		PHPlayer(client).Reset();
	}
}

public void Event_TeamplayRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	delete g_ControlPointBonusTimer;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		// Reset this so no prop spawns with guns next round
		PHPlayer(client).IsLastProp = false;
	}
	
	// Always switch teams on round end
	SDKCall_SetSwitchTeams(true);
}

public void Event_ArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
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
	
	// Kick cheaters out of the game
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
			QueryClientConVar(client, "r_staticpropinfo", ConVarQuery_StaticPropInfo);
	}
}
