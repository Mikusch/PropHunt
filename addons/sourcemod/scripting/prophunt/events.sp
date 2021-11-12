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
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	
	// Prevent latespawning
	// TODO: Leave this out while still indev
	/*if (GameRules_GetRoundState() != RoundState_Preround)
	{
		ForcePlayerSuicide(client);
		return;
	}*/
	
	if (PHPlayer(client).IsProp())
	{
		SetEntProp(client, Prop_Send, "m_nDisguiseTeam", TFTeam_Hunters);
		
		CreateTimer(0.1, Timer_SetForcedTauntCam, userid);
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	
	if (victim != attacker && IsEntityClient(attacker) && IsClientInGame(attacker) && IsPlayerAlive(attacker))
	{
		// Fully regenerate the killing player
		SetEntityHealth(attacker, GetMaxHealth(attacker) + 25);
		TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 7.0);
		
		if (IsEntityClient(assister) && IsClientInGame(assister) && IsPlayerAlive(assister))
		{
			// Give the assister a little bonus
			SetEntityHealth(assister, GetMaxHealth(assister));
			TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 3.5);
		}
	}
}

public void Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (PHPlayer(client).IsProp())
	{
		// Better than removing everything manually, this also removes wearables
		SDKCall_RemoveAllWeapons(client);
	}
	else if (PHPlayer(client).IsHunter())
	{
		// Give Hunters a Grappling Hook to get around quicker
		Handle item = TF2Items_CreateItem(PRESERVE_ATTRIBUTES);
		
		char classname[256];
		TF2Econ_GetItemClassName(ITEM_DEFINDEX_GRAPPLINGHOOK, classname, sizeof(classname));
		
		TF2Items_SetClassname(item, classname);
		TF2Items_SetItemIndex(item, ITEM_DEFINDEX_GRAPPLINGHOOK);
		TF2Items_SetLevel(item, 1);
		
		int grapplingHook = TF2Items_GiveNamedItem(client, item);
		EquipPlayerWeapon(client, grapplingHook);
	}
}
