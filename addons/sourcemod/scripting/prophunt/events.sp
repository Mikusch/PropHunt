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
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	
	int client = GetClientOfUserId(userid);
	if (TF2_GetClientTeam(client) == TFTeam_Props)
	{
		SetEntProp(client, Prop_Send, "m_nDisguiseTeam", TFTeam_Hunters);
		
		CreateTimer(0.1, Timer_SetForcedTauntCam, userid);
	}
}

public void Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(client) == TFTeam_Props)
	{
		// Better than removing everything manually, this also removes wearables
		SDKCall_RemoveAllWeapons(client);
	}
}
