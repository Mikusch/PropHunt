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

void SDKHooks_HookClient(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, SDKHookCB_Client_OnTakeDamage);
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "prop_dynamic") == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_PropDynamic_SpawnPost);
	}
}

public Action SDKHookCB_Client_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	// Prevent props from drowning
	if (damagetype & DMG_DROWN && TF2_GetClientTeam(victim) == TFTeam_Props)
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void SDKHookCB_PropDynamic_SpawnPost(int prop)
{
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(prop, Prop_Data, "m_ModelName", model, sizeof(model));
	
	// Hook the control point prop
	if (strcmp(model, "models/props_gameplay/cap_point_base.mdl") == 0)
		SDKHook(prop, SDKHook_StartTouch, SDKHookCB_ControlPoint_StartTouch);
}

public Action SDKHookCB_ControlPoint_StartTouch(int prop, int other)
{
	// Players touching the capture area receive a health bonus
	if (IsEntityClient(other) && !PHPlayer(other).HasReceivedBonus)
	{
		if (SDKCall_CastSelfHeal(other))
		{
			EmitGameSoundToClient(other, "Announcer.MVM_Bonus");
			CPrintToChat(other, "%s %t", PLUGIN_TAG, "PH_Bonus_Received");
			
			PHPlayer(other).HasReceivedBonus = true;
		}
	}
	
	return Plugin_Continue;
}
