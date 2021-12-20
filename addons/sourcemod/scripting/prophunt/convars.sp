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

#define MAX_COMMAND_LENGTH 1024

enum struct ConVarInfo
{
	char name[64];
	char value[MAX_COMMAND_LENGTH];
	char initialValue[MAX_COMMAND_LENGTH];
	bool enforce;
	bool enabled;
}

static StringMap g_GameConVars;

void ConVars_Initialize()
{
	CreateConVar("ph_version", PLUGIN_VERSION, "PropHunt Neu version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	ph_prop_min_size = CreateConVar("ph_prop_min_size", "40.0", "Minimum allowed size of props for them to be selectable.");
	ph_prop_max_size = CreateConVar("ph_prop_max_size", "400.0", "Maximum allowed size of props for them to be selectable.");
	ph_prop_select_distance = CreateConVar("ph_prop_select_distance", "128.0", "Minimum required distance to a prop for it to be selectable, in HU.");
	ph_prop_max_health = CreateConVar("ph_prop_max_health", "300", "Maximum health of props, regardless of prop size. Set to 0 to unrestrict health.");
	ph_hunter_damage_modifier_gun = CreateConVar("ph_hunter_damage_modifier_gun", "0.35", "Modifier of self-damage taken from guns.");
	ph_hunter_damage_modifier_melee = CreateConVar("ph_hunter_damage_modifier_melee", "0.15", "Modifier of self-damage taken from melees.");
	ph_hunter_damage_modifier_grapplinghook = CreateConVar("ph_hunter_damage_modifier_grapplinghook", "1.0", "Modifier of self-damage taken from the Grappling Hook.");
	ph_hunter_damage_modifier_flamethrower = CreateConVar("ph_hunter_damage_modifier_flamethrower", "0.15", "Modifier of self-damage taken from Flame Throwers.");
	ph_hunter_setup_freeze = CreateConVar("ph_hunter_setup_freeze", "1", "When set, prevent Hunter movement during setup.");
	ph_regenerate_last_prop = CreateConVar("ph_regenerate_last_prop", "1", "When set, regenerate the last prop so that they receive their weapons.");
	ph_bonus_refresh_time = CreateConVar("ph_bonus_refresh_time", "60.0", "Refresh interval of the control point bonus, in seconds.");
	ph_healing_modifier = CreateConVar("ph_healing_modifier", "0.2", "Modifier of the amount of healing received from continuous healing sources.");
	ph_open_doors_after_setup = CreateConVar("ph_open_doors_after_setup", "1", "When set, open all doors after setup time ends.");
	ph_setup_truce = CreateConVar("ph_setup_truce", "0", "When set, props can not be damaged during setup.");
	ph_setup_time = CreateConVar("ph_setup_time", "45", "Length of the setup time, in seconds.");
	ph_round_time = CreateConVar("ph_round_time", "225", "Length of the round time, in seconds.");
	ph_relay_name = CreateConVar("ph_relay_name", "hidingover", "Name of the relay to trigger when setup time ends.");
	
	g_GameConVars = new StringMap();
	
	// Track all ConVars not controlled by this plugin
	ConVars_Track("tf_arena_round_time", "0");
	ConVars_Track("tf_arena_override_cap_enable_time", "0");
	ConVars_Track("tf_arena_use_queue", "0");
	ConVars_Track("tf_arena_first_blood", "0");
	ConVars_Track("tf_weapon_criticals", "0");
	ConVars_Track("mp_show_voice_icons", "0");
	ConVars_Track("mp_forcecamera", "1");
	ConVars_Track("sv_gravity", "500");
}

void ConVars_Track(const char[] name, const char[] value, bool enforce = true)
{
	ConVar convar = FindConVar(name);
	if (convar)
	{
		// Store ConVar information
		ConVarInfo info;
		strcopy(info.name, sizeof(info.name), name);
		strcopy(info.value, sizeof(info.value), value);
		info.enforce = enforce;
		
		g_GameConVars.SetArray(name, info, sizeof(info));
	}
	else
	{
		LogError("The ConVar %s could not be found", name);
	}
}

void ConVars_ToggleAll(bool enable)
{
	StringMapSnapshot snapshot = g_GameConVars.Snapshot();
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

void ConVars_Enable(const char[] name)
{
	ConVarInfo info;
	if (g_GameConVars.GetArray(name, info, sizeof(info)) && !info.enabled)
	{
		ConVar convar = FindConVar(info.name);
		
		// Store the current value so we can later reset the ConVar to it
		convar.GetString(info.initialValue, sizeof(info.initialValue));
		info.enabled = true;
		g_GameConVars.SetArray(name, info, sizeof(info));
		
		// Update the current value
		convar.SetString(info.value);
		convar.AddChangeHook(OnConVarChanged);
	}
}

void ConVars_Disable(const char[] name)
{
	ConVarInfo info;
	if (g_GameConVars.GetArray(name, info, sizeof(info)) && info.enabled)
	{
		ConVar convar = FindConVar(info.name);
		
		info.enabled = false;
		g_GameConVars.SetArray(name, info, sizeof(info));
		
		// Restore the convar value
		convar.RemoveChangeHook(OnConVarChanged);
		convar.SetString(info.initialValue);
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char name[64];
	convar.GetName(name, sizeof(name));
	
	ConVarInfo info;
	if (g_GameConVars.GetArray(name, info, sizeof(info)))
	{
		if (!StrEqual(newValue, info.value))
		{
			strcopy(info.initialValue, sizeof(info.initialValue), newValue);
			g_GameConVars.SetArray(name, info, sizeof(info));
			
			// Restore our value if needed
			if (info.enforce)
				convar.SetString(info.value);
		}
	}
}
