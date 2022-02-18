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

#define COMMAND_MAX_LENGTH	512

enum struct ConVarData
{
	char name[COMMAND_MAX_LENGTH];
	char value[COMMAND_MAX_LENGTH];
	char initialValue[COMMAND_MAX_LENGTH];
	bool enforce;
}

static StringMap g_ConVars;

void ConVars_Initialize()
{
	g_ConVars = new StringMap();
	
	CreateConVar("ph_version", PLUGIN_VERSION, "PropHunt Neu version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	ph_enable = CreateConVar("ph_enable", "1", "When set, the plugin will be enabled.");
	ph_enable.AddChangeHook(ConVarChanged_Enable);
	ph_prop_min_size = CreateConVar("ph_prop_min_size", "40.0", "Minimum allowed size of props for them to be selectable.");
	ph_prop_max_size = CreateConVar("ph_prop_max_size", "400.0", "Maximum allowed size of props for them to be selectable.");
	ph_prop_select_distance = CreateConVar("ph_prop_select_distance", "128.0", "Minimum required distance to a prop for it to be selectable, in HU.");
	ph_prop_max_health = CreateConVar("ph_prop_max_health", "300", "Maximum health of props, regardless of prop size. Set to 0 to unrestrict health.");
	ph_hunter_damage_modifier_gun = CreateConVar("ph_hunter_damage_modifier_gun", "0.35", "Modifier of self-damage taken from guns.");
	ph_hunter_damage_modifier_melee = CreateConVar("ph_hunter_damage_modifier_melee", "0.15", "Modifier of self-damage taken from melees.");
	ph_hunter_damage_modifier_grapplinghook = CreateConVar("ph_hunter_damage_modifier_grapplinghook", "1.0", "Modifier of self-damage taken from the Grappling Hook.");
	ph_hunter_damage_modifier_flamethrower = CreateConVar("ph_hunter_damage_modifier_flamethrower", "0.15", "Modifier of self-damage taken from Flame Throwers.");
	ph_hunter_damage_modifier_projectile = CreateConVar("ph_hunter_damage_modifier_projectile", "0.5", "Modifier of self-damage taken from miscellaneous projectiles.");
	ph_hunter_damage_modifier_scoutprimary_push = CreateConVar("ph_hunter_damage_modifier_scoutprimary_push", "5.0", "Modifier of self-damage taken from the Shortstop's shove ability.");
	ph_hunter_setup_freeze = CreateConVar("ph_hunter_setup_freeze", "1", "When set, prevent Hunter movement during setup.");
	ph_regenerate_last_prop = CreateConVar("ph_regenerate_last_prop", "1", "When set, regenerate the last prop so that they receive their weapons.");
	ph_chat_tip_interval = CreateConVar("ph_chat_tip_interval", "240.0", "Interval at which tips are printed in chat, in seconds. Set to 0 to disable chat tips.");
	ph_chat_tip_interval.AddChangeHook(ConVarChanged_ChatTipInterval);
	ph_bonus_refresh_interval = CreateConVar("ph_bonus_refresh_interval", "60.0", "Interval at which the control point bonus refreshes, in seconds.");
	ph_healing_modifier = CreateConVar("ph_healing_modifier", "0.25", "Modifier of the amount of healing received from continuous healing sources.");
	ph_open_doors_after_setup = CreateConVar("ph_open_doors_after_setup", "1", "When set, open all doors after setup time ends.");
	ph_setup_truce = CreateConVar("ph_setup_truce", "0", "When set, props can not be damaged during setup.");
	ph_setup_time = CreateConVar("ph_setup_time", "45", "Length of the setup time, in seconds.");
	ph_round_time = CreateConVar("ph_round_time", "225", "Length of the round time, in seconds.");
	ph_relay_name = CreateConVar("ph_relay_name", "hidingover", "Name of the relay to trigger when setup time ends.");
	
	ConVars_TrackConVar("tf_arena_round_time", "0");
	ConVars_TrackConVar("tf_arena_override_cap_enable_time", "0");
	ConVars_TrackConVar("tf_arena_use_queue", "0");
	ConVars_TrackConVar("tf_arena_first_blood", "0");
	ConVars_TrackConVar("tf_weapon_criticals", "0");
	ConVars_TrackConVar("mp_show_voice_icons", "0");
	ConVars_TrackConVar("mp_forcecamera", "1");
	ConVars_TrackConVar("sv_gravity", "500");
}

void ConVars_Toggle(bool enable)
{
	StringMapSnapshot snapshot = g_ConVars.Snapshot();
	for (int i = 0; i < snapshot.Length; i++)
	{
		int size = snapshot.KeyBufferSize(i);
		char[] key = new char[size];
		snapshot.GetKey(i, key, size);
		
		if (enable)
			ConVars_Enable(key);
		else
			ConVars_Disable(key);
	}
	delete snapshot;
}

static void ConVars_TrackConVar(const char[] name, const char[] value, bool enforce = true)
{
	ConVar convar = FindConVar(name);
	if (convar)
	{
		// Store ConVar information
		ConVarData info;
		strcopy(info.name, sizeof(info.name), name);
		strcopy(info.value, sizeof(info.value), value);
		info.enforce = enforce;
		
		g_ConVars.SetArray(name, info, sizeof(info));
	}
	else
	{
		LogError("Failed to find convar with name %s", name);
	}
}

static void ConVars_Enable(const char[] name)
{
	ConVarData data;
	if (g_ConVars.GetArray(name, data, sizeof(data)))
	{
		ConVar convar = FindConVar(data.name);
		
		// Store the current value so we can later reset the ConVar to it
		convar.GetString(data.initialValue, sizeof(data.initialValue));
		g_ConVars.SetArray(name, data, sizeof(data));
		
		// Update the current value
		convar.SetString(data.value);
		convar.AddChangeHook(OnConVarChanged);
	}
}

static void ConVars_Disable(const char[] name)
{
	ConVarData data;
	if (g_ConVars.GetArray(name, data, sizeof(data)))
	{
		ConVar convar = FindConVar(data.name);
		
		g_ConVars.SetArray(name, data, sizeof(data));
		
		// Restore the convar value
		convar.RemoveChangeHook(OnConVarChanged);
		convar.SetString(data.initialValue);
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char name[COMMAND_MAX_LENGTH];
	convar.GetName(name, sizeof(name));
	
	ConVarData data;
	if (g_ConVars.GetArray(name, data, sizeof(data)))
	{
		if (!StrEqual(newValue, data.value))
		{
			strcopy(data.initialValue, sizeof(data.initialValue), newValue);
			g_ConVars.SetArray(name, data, sizeof(data));
			
			// Restore our value if needed
			if (data.enforce)
				convar.SetString(data.value);
		}
	}
}

public void ConVarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_IsEnabled != convar.BoolValue)
		TogglePlugin(convar.BoolValue);
}

public void ConVarChanged_ChatTipInterval(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_IsEnabled)
		return;
	
	delete g_ChatTipTimer;
	
	if (convar.FloatValue > 0)
		g_ChatTipTimer = CreateTimer(convar.FloatValue, Timer_PrintChatTip, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}
