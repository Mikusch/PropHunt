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

void ConVars_Init()
{
	CreateConVar("ph_version", PLUGIN_VERSION, "PropHunt Neu version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	CreateConVar("ph_enabled", "1", "When set, the plugin will be enabled.");
	
	ph_prop_min_size = CreateConVar("ph_prop_min_size", "40.0", "Minimum allowed size of props for them to be selectable.");
	ph_prop_max_size = CreateConVar("ph_prop_max_size", "400.0", "Maximum allowed size of props for them to be selectable.");
	ph_prop_select_distance = CreateConVar("ph_prop_select_distance", "128.0", "Minimum required distance to a prop for it to be selectable, in HU.");
	ph_prop_max_health = CreateConVar("ph_prop_max_health", "300", "Maximum health of props, regardless of prop size. Set to 0 to unrestrict health.");
	ph_prop_afterburn_immune = CreateConVar("ph_prop_afterburn_immune", "1", "When set, props do not take afterburn damage.");
	ph_prop_proplock_enabled = CreateConVar("ph_prop_proplock_enabled", "1", "When set, props are allowed to freeze in place.");
	ph_hunter_damage_modifier_gun = CreateConVar("ph_hunter_damage_modifier_gun", "0.35", "Modifier of self-damage taken from guns.");
	ph_hunter_damage_modifier_melee = CreateConVar("ph_hunter_damage_modifier_melee", "0.15", "Modifier of self-damage taken from melees.");
	ph_hunter_damage_modifier_flamethrower = CreateConVar("ph_hunter_damage_modifier_flamethrower", "0.15", "Modifier of self-damage taken from Flame Throwers.");
	ph_hunter_damage_modifier_projectile = CreateConVar("ph_hunter_damage_modifier_projectile", "0.5", "Modifier of self-damage taken from miscellaneous projectiles.");
	ph_hunter_setup_freeze = CreateConVar("ph_hunter_setup_freeze", "1", "When set, prevent Hunter movement during setup.");
	ph_regenerate_last_prop = CreateConVar("ph_regenerate_last_prop", "1", "When set, regenerate the last prop so that they receive their weapons.");
	ph_chat_tip_interval = CreateConVar("ph_chat_tip_interval", "240.0", "Interval at which tips are printed in chat, in seconds. Set to 0 to disable chat tips.");
	ph_bonus_refresh_interval = CreateConVar("ph_bonus_refresh_interval", "60.0", "Interval at which the control point bonus refreshes, in seconds.");
	ph_healing_modifier = CreateConVar("ph_healing_modifier", "0.25", "Modifier of the amount of healing received from continuous healing sources.");
	ph_flamethrower_velocity = CreateConVar("ph_flamethrower_velocity", "300.0", "Velocity to add to the player while firing the Flame Thrower. Set to 0 to disable Flame Thrower flying.");
	ph_open_doors_after_setup = CreateConVar("ph_open_doors_after_setup", "1", "When set, open all doors after setup time ends.");
	ph_setup_truce = CreateConVar("ph_setup_truce", "0", "When set, props can not be damaged during setup.");
	ph_setup_time = CreateConVar("ph_setup_time", "45", "Length of the setup time, in seconds.");
	ph_round_time = CreateConVar("ph_round_time", "225", "Length of the round time, in seconds.");
	ph_relay_name = CreateConVar("ph_relay_name", "hidingover", "Name of the relay to trigger when setup time ends.");
	ph_gravity_modifier = CreateConVar("ph_gravity_modifier", "0.625", "Modifier to player gravity.");
	
	PSM_AddConVarChangeHook(ph_prop_afterburn_immune, ConVarChanged_PropAfterburnImmune);
	PSM_AddConVarChangeHook(ph_prop_proplock_enabled, ConVarChanged_PropPropLockEnabled);
	PSM_AddConVarChangeHook(ph_chat_tip_interval, ConVarChanged_ChatTipInterval);
	PSM_AddConVarChangeHook(ph_gravity_modifier, ConVarChanged_GravityModifier);
	
	PSM_AddEnforcedConVar("tf_arena_round_time", "0");
	PSM_AddEnforcedConVar("tf_arena_override_cap_enable_time", "0");
	PSM_AddEnforcedConVar("tf_arena_use_queue", "0");
	PSM_AddEnforcedConVar("tf_arena_first_blood", "0");
	PSM_AddEnforcedConVar("tf_weapon_criticals", "0");
	PSM_AddEnforcedConVar("mp_show_voice_icons", "0");
	PSM_AddEnforcedConVar("mp_forcecamera", "1");
}

static void ConVarChanged_PropAfterburnImmune(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (TF2_GetClientTeam(client) != TFTeam_Props)
			continue;
		
		if (convar.BoolValue)
			TF2_AddCondition(client, TFCond_AfterburnImmune);
		else
			TF2_RemoveCondition(client, TFCond_AfterburnImmune);
	}
}

static void ConVarChanged_PropPropLockEnabled(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!convar.BoolValue)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client))
				continue;
			
			if (!IsPlayerAlive(client))
				continue;
			
			if (PHPlayer(client).PropLockEnabled)
			{
				PHPlayer(client).PropLockEnabled = false;
				TogglePropLock(client, false);
			}
		}
	}
}

static void ConVarChanged_ChatTipInterval(ConVar convar, const char[] oldValue, const char[] newValue)
{
	delete g_ChatTipTimer;
	
	if (convar.FloatValue > 0)
		g_ChatTipTimer = CreateTimer(convar.FloatValue, Timer_PrintChatTip, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

static void ConVarChanged_GravityModifier(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		SetEntityGravity(client, convar.FloatValue);
	}
}
