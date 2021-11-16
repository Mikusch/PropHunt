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
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	
	// Prevent latespawning
	if (GameRules_GetRoundState() != RoundState_Preround)
	{
		ForcePlayerSuicide(client);
		return;
	}
	
	if (IsPlayerProp(client))
	{
		AcceptEntityInput(client, "DisableShadow");
		
		// Restore third-person setting to props
		CreateTimer(0.1, Timer_SetForcedTauntCam, userid);
	}
	
	ClearCustomModel(client);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	
	if (victim != attacker && IsEntityClient(attacker) && IsClientInGame(attacker) && IsPlayerAlive(attacker))
	{
		// Fully regenerate the killing player
		SetEntityHealth(attacker, GetPlayerMaxHealth(attacker) + 25);
		TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 7.0);
		
		if (IsEntityClient(assister) && IsClientInGame(assister) && IsPlayerAlive(assister))
		{
			// Give the assister a little bonus
			SetEntityHealth(assister, GetPlayerMaxHealth(assister));
			TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 3.5);
		}
	}
}

public void Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsPlayerProp(client))
	{
		// Fixes an exploit where you could keep your hunter weapons as a prop
		TF2_RemoveAllWeapons(client);
	}
}

public void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_InSetup = false;
	
	delete g_ControlPointBonusTimer;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		PHPlayer(client).Reset();
		
		// Afterburn is too strong
		if (IsClientInGame(client) && IsPlayerProp(client))
			TF2_AddCondition(client, TFCond_AfterburnImmune);
	}
}

public void Event_TeamplayRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	delete g_ControlPointBonusTimer;
	
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
			
			HookSingleEntityOutput(timer, "OnSetupFinished", OnSetupTimerFinished, true);
			HookSingleEntityOutput(timer, "OnFinished", OnRoundTimerFinished, true);
		}
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			// Kick cheaters out of the game
			QueryClientConVar(client, "r_staticpropinfo", ConVarQuery_StaticPropInfo);
			
			// Show prop controls
			if (IsPlayerProp(client))
				ShowKeyHintText(client, "%t", "Prop Controls");
		}
	}
}
