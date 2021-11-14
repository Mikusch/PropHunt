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
	ph_prop_min_size = CreateConVar("ph_prop_min_size", "50.0", "Minimum size of props to be able to select them.");
	ph_prop_max_size = CreateConVar("ph_prop_max_size", "400.0", "Maximum size of props to be able to select them.");
	ph_prop_max_select_distance = CreateConVar("ph_prop_max_select_distance", "128.0", "Players must have at least this distance to the prop to be able to select it.");
	ph_hunter_damagemod_guns = CreateConVar("ph_hunter_damagemod_guns", "0.4", "Modifier of damage taken from gun-based weapons.");
	ph_hunter_damagemod_melee = CreateConVar("ph_hunter_damagemod_melee", "0.2", "Modifier of damage taken from melee-based weapons.");
	ph_hunter_damage_flamethrower = CreateConVar("ph_hunter_damage_flamethrower", "1.0", "Amount of damage taken when using the flame thrower.");
	ph_hunter_damage_grapplinghook = CreateConVar("ph_hunter_damage_grapplinghook", "10.0", "Amount of damage taken when using the grappling hook.");
	ph_bonus_refresh_time = CreateConVar("ph_bonus_refresh_time", "60.0", "Time in seconds for control point bonus to refresh.");
	
	// These may be overridden by map configs
	ph_hunter_setup_freeze = CreateConVar("ph_hunter_setup_freeze", "1", "If set to 1, Hunters cannot move during setup time.");
	ph_open_doors_after_setup = CreateConVar("ph_open_doors_after_setup", "1", "If set to 1, all doors in the map will open after setup time.");
	ph_setup_time = CreateConVar("ph_setup_time", "30", "Length of the hiding time for props.");
	ph_round_time = CreateConVar("ph_round_time", "180", "Length of the round time.");
	ph_relay_name = CreateConVar("ph_relay_name", "hidingover", "Name of the relay to fire after setup time.");
	
	g_GameConVars = new StringMap();
	
	//Track all ConVars not controlled by this plugin
	ConVars_Track("tf_arena_round_time", "0");
	ConVars_Track("tf_arena_override_cap_enable_time", "0");
	ConVars_Track("tf_arena_use_queue", "0");
	ConVars_Track("tf_arena_first_blood", "0");
	ConVars_Track("mp_show_voice_icons", "0");
	ConVars_Track("mp_forcecamera", "1");
	ConVars_Track("sv_gravity", "500");
}

void ConVars_Track(const char[] name, const char[] value, bool enforce = true)
{
	ConVar convar = FindConVar(name);
	if (convar)
	{
		//Store ConVar information
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
		
		//Store the current value so we can later reset the ConVar to it
		convar.GetString(info.initialValue, sizeof(info.initialValue));
		info.enabled = true;
		g_GameConVars.SetArray(name, info, sizeof(info));
		
		//Update the current value
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
		
		//Restore the convar value
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
			
			//Restore our value if needed
			if (info.enforce)
				convar.SetString(info.value);
		}
	}
}
