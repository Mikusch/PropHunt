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

#define MAX_EVENT_NAME_LENGTH	32

enum struct EventData
{
	char name[MAX_EVENT_NAME_LENGTH];
	EventHook callback;
	EventHookMode mode;
}

static ArrayList g_Events;

void Events_Initialize()
{
	g_Events = new ArrayList(sizeof(EventData));
	
	Events_AddEvent("player_spawn", EventHook_PlayerSpawn);
	Events_AddEvent("player_death", EventHook_PlayerDeath);
	Events_AddEvent("post_inventory_application", EventHook_PostInventoryApplication);
	Events_AddEvent("teamplay_round_start", EventHook_TeamplayRoundStart);
	Events_AddEvent("teamplay_round_win", EventHook_TeamplayRoundWin);
	Events_AddEvent("arena_round_start", EventHook_ArenaRoundStart);
}

void Events_Toggle(bool enable)
{
	for (int i = 0; i < g_Events.Length; i++)
	{
		EventData data;
		if (g_Events.GetArray(i, data) > 0)
		{
			if (enable)
				HookEvent(data.name, data.callback, data.mode);
			else
				UnhookEvent(data.name, data.callback, data.mode);
		}
	}
}

static void Events_AddEvent(const char[] name, EventHook callback, EventHookMode mode = EventHookMode_Post)
{
	Event event = CreateEvent(name, true);
	if (event)
	{
		event.Cancel();
		
		EventData data;
		strcopy(data.name, sizeof(data.name), name);
		data.callback = callback;
		data.mode = mode;
		
		g_Events.PushArray(data);
	}
	else
	{
		LogError("Failed to create event with name %s", name);
	}
}

public void EventHook_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	// Prevent latespawning
	if (GameRules_GetRoundState() != RoundState_Preround)
	{
		ForcePlayerSuicide(client);
		return;
	}
	
	TFTeam team = TF2_GetClientTeam(client);
	
	// Ensure the player is playing as a valid class for their team
	if (!IsValidClass(team, TF2_GetPlayerClass(client)))
	{
		TF2_SetPlayerClass(client, GetRandomValidClass(team), _, false);
		SDKCall_InitClass(client);
	}
	
	if (team == TFTeam_Props)
	{
		AcceptEntityInput(client, "DisableShadow");
		
		// Some things, like setting conditions, only works with a delay
		CreateTimer(0.1, Timer_PropPostSpawn, GetClientSerial(client));
	}
}

public void EventHook_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
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

public void EventHook_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
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

public void EventHook_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
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

public void EventHook_TeamplayRoundWin(Event event, const char[] name, bool dontBroadcast)
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

public void EventHook_ArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
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
}
