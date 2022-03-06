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

// Map Config
enum struct MapConfig
{
	ArrayList prop_whitelist;
	ArrayList prop_blacklist;
	
	void ReadFromKv(KeyValues kv)
	{
		// Prop whitelist (overrides blacklist)
		if (kv.JumpToKey("prop_whitelist"))
		{
			this.prop_whitelist = new ArrayList(PLATFORM_MAX_PATH);
			
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char model[PLATFORM_MAX_PATH];
					kv.GetString(NULL_STRING, model, sizeof(model));
					this.prop_whitelist.PushString(model);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
		kv.GoBack();
		
		// Prop blacklist
		if (kv.JumpToKey("prop_blacklist"))
		{
			this.prop_blacklist = new ArrayList(PLATFORM_MAX_PATH);
			
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char model[PLATFORM_MAX_PATH];
					kv.GetString(NULL_STRING, model, sizeof(model));
					this.prop_blacklist.PushString(model);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	bool HasWhitelist()
	{
		return (this.prop_whitelist && this.prop_whitelist.Length > 0);
	}
	
	bool IsWhitelisted(const char[] model)
	{
		return this.HasWhitelist() && (this.prop_whitelist.FindString(model) != -1);
	}
	
	bool IsBlacklisted(const char[] model)
	{
		return this.HasWhitelist() || (this.prop_blacklist && this.prop_blacklist.Length > 0 && this.prop_blacklist.FindString(model) != -1);
	}
	
	void Clear()
	{
		delete this.prop_whitelist;
		delete this.prop_blacklist;
	}
}

MapConfig g_CurrentMapConfig;

// Global Prop Config
enum struct PropConfig
{
	char model[PLATFORM_MAX_PATH];
	Regex regex;
	bool blacklist;
	float offset[3];
	float rotation[3];
	int health;
	
	void ReadFromKv(KeyValues kv)
	{
		char section[256];
		if (!kv.GetSectionName(section, sizeof(section)))
			return;
		
		kv.GetString("model", this.model, PLATFORM_MAX_PATH);
		
		char pattern[256];
		kv.GetString("model_pattern", pattern, sizeof(pattern));
		if (pattern[0] != '\0')
		{
			RegexError errcode;
			char message[256];
			this.regex = new Regex(pattern, _, message, sizeof(message), errcode);
			
			if (!this.regex)
				LogError("%s: Failed to compile regular expression [errcode %d]: %s", section, errcode, message);
		}
		
		this.blacklist = view_as<bool>(kv.GetNum("blacklist"));
		kv.GetVector("offset", this.offset);
		kv.GetVector("rotation", this.rotation);
		this.health = kv.GetNum("health");
	}
}

ArrayList g_PropConfigs;
