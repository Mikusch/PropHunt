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

#define FLOAT_EPSILON	0.0001

#define WEAPONDATA_SIZE	58	// sizeof(WeaponData_t)

// Valid prop classes
static TFClassType g_ValidPropClasses[] = 
{
	TFClass_Scout,
};

// Valid hunter classes
static TFClassType g_ValidHunterClasses[] = 
{
	TFClass_Scout,
	TFClass_Sniper,
	TFClass_Soldier,
	TFClass_DemoMan,
	TFClass_Medic,
	TFClass_Heavy,
	TFClass_Pyro,
	TFClass_Engineer,
};

any Min(any a, any b)
{
	return (a <= b) ? a : b;
}

any Max(any a, any b)
{
	return (a >= b) ? a : b;
}

any Clamp(any val, any min, any max)
{
	return Min(Max(val, min), max);
}

// Thanks to ficool2 for helping me with scary vector math
bool IntersectionLineAABBFast(const float mins[3], const float maxs[3], const float start[3], const float dir[3], float far)
{
	// Test each cardinal plane (X, Y and Z) in turn
	float near = 0.0;
	
	if (!CloseEnough(dir[0], 0.0, FLOAT_EPSILON))
	{
		float recipDir = 1.0 / dir[0];
		float t1 = (mins[0] - start[0]) * recipDir;
		float t2 = (maxs[0] - start[0]) * recipDir;
		
		// tNear tracks distance to intersect (enter) the AABB
		// tFar tracks the distance to exit the AABB
		if (t1 < t2)
			near = Max(t1, near), far = Min(t2, far);
		else // Swap t1 and t2
			near = Max(t2, near), far = Min(t1, far);
		
		if (near > far)
			return false; // Box is missed since we "exit" before entering it
	}
	else if (start[0] < mins[0] || start[0] > maxs[0])
	{
		// The ray can't possibly enter the box, abort
		return false;
	}
	
	if (!CloseEnough(dir[0], 0.0, FLOAT_EPSILON))
	{
		float recipDir = 1.0 / dir[1];
		float t1 = (mins[1] - start[1]) * recipDir;
		float t2 = (maxs[1] - start[1]) * recipDir;
		
		if (t1 < t2)
			near = Max(t1, near), far = Min(t2, far);
		else // Swap t1 and t2.
			near = Max(t2, near), far = Min(t1, far);
		
		if (near > far)
			return false; // Box is missed since we "exit" before entering it
	}
	else if (start[1] < mins[1] || start[1] > maxs[1])
	{
		// The ray can't possibly enter the box, abort
		return false;
	}
	
	// Ray is parallel to plane in question
	if (!CloseEnough(dir[2], 0.0, FLOAT_EPSILON))
	{
		float recipDir = 1.0 / dir[2];
		float t1 = (mins[2] - start[2]) * recipDir;
		float t2 = (maxs[2] - start[2]) * recipDir;
		
		if (t1 < t2)
			near = Max(t1, near), far = Min(t2, far);
		else // Swap t1 and t2.
			near = Max(t2, near), far = Min(t1, far);
	}
	else if (start[2] < mins[2] || start[2] > maxs[2])
	{
		// The ray can't possibly enter the box, abort
		return false;
	}
	
	return near <= far;
}

bool CloseEnough(float a, float b, float epsilon)
{
	return FloatAbs(a - b) <= epsilon;
}

bool IsWeaponBaseGun(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseGunZoomOutIn");
}

bool IsWeaponBaseMelee(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseMeleeSmack");
}

int GetBulletsPerShot(int weapon)
{
	// m_pWeaponInfo->GetWeaponData( m_iWeaponMode ).m_nBulletsPerShot
	int weaponMode = GetEntData(weapon, g_OffsetWeaponMode);
	int weaponInfo = GetEntData(weapon, g_OffsetWeaponInfo);
	int weaponData = weaponInfo + (WEAPONDATA_SIZE * weaponMode);
	return LoadFromAddress(view_as<Address>(weaponData + g_OffsetBulletsPerShot), NumberType_Int8);
}

bool GetConfigByModel(const char[] model, PropConfig config)
{
	for (int i = 0; i < g_PropConfigs.Length; i++)
	{
		if (g_PropConfigs.GetArray(i, config) > 0)
		{
			// Try to fetch config by exact match first
			if (config.model[0] != '\0' && strcmp(config.model, model) == 0)
				return true;
			
			// Then, try the regular expression
			if (config.regex && config.regex.Match(model) > 0)
				return true;
		}
	}
	
	// No match found
	return false;
}

bool IsPropBlacklisted(const char[] model)
{
	PropConfig config;
	return GetConfigByModel(model, config) && config.blacklisted;
}

void GetModelTidyName(const char[] model, char[] buffer, int maxlength)
{
	// Always copy first
	strcopy(buffer, maxlength, model);
	
	// Remove models/ at the start
	if (StrContains(buffer, "models/") == 0)
		strcopy(buffer, maxlength, buffer[7]);
	
	// Remove .mdl at the end
	int start = StrContains(buffer, ".mdl");
	if (start != -1)
		buffer[start] = '\0';
}

bool IsEntityClient(int entity)
{
	return 0 < entity < MaxClients;
}

int GetPlayerMaxHealth(int client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}

int GetEntitySkin(int entity)
{
	if (HasEntProp(entity, Prop_Data, "m_nForcedSkin"))
	{
		int forcedSkin = GetEntProp(entity, Prop_Data, "m_nForcedSkin");
		if (forcedSkin == 0)
			return GetEntProp(entity, Prop_Data, "m_nSkin");
		else
			return GetEntProp(entity, Prop_Data, "m_nForcedSkin");
	}
	else
	{
		return GetEntProp(entity, Prop_Data, "m_nSkin");
	}
}

int CountCharInString(const char[] string, char letter)
{
	int i, count;
	while (string[i] != '\0')
	{
		if (string[i++] == letter)
			count++;
	}
	return count;
}

bool GetMapConfigFilepath(char[] filePath, int length)
{
	char mapName[PLATFORM_MAX_PATH];
	GetCurrentMap(mapName, sizeof(mapName));
	GetMapDisplayName(mapName, mapName, sizeof(mapName));
	
	int partsCount = CountCharInString(mapName, '_') + 1;
	
	//Split map prefix and first part of its name (e.g. pl_hightower)
	char[][] nameParts = new char[partsCount][PLATFORM_MAX_PATH];
	ExplodeString(mapName, "_", nameParts, partsCount, PLATFORM_MAX_PATH);
	
	//Start to stitch name parts together
	char tidyMapName[PLATFORM_MAX_PATH];
	char filePathBuffer[PLATFORM_MAX_PATH];
	strcopy(tidyMapName, sizeof(tidyMapName), nameParts[0]);
	
	//Build file path
	BuildPath(Path_SM, tidyMapName, sizeof(tidyMapName), MAP_CONFIG_FILEPATH, tidyMapName);
	
	for (int i = 1; i < partsCount; i++)
	{
		Format(tidyMapName, sizeof(tidyMapName), "%s_%s", tidyMapName, nameParts[i]);
		Format(filePathBuffer, sizeof(filePathBuffer), "%s.cfg", tidyMapName);
		
		//We are trying to find the most specific config
		if (FileExists(filePathBuffer))
			strcopy(filePath, length, filePathBuffer);
	}
	
	return FileExists(filePath);
}

void ShowKeyHintText(int client, const char[] format, any...)
{
	char buffer[256];
	SetGlobalTransTarget(client);
	VFormat(buffer, sizeof(buffer), format, 3);
	
	BfWrite bf = UserMessageToBfWrite(StartMessageOne("KeyHintText", client));
	bf.WriteByte(1);	//One message
	bf.WriteString(buffer);
	EndMessage();
}

void SetWinningTeam(TFTeam team)
{
	int round_win = CreateEntityByName("game_round_win");
	if (round_win != -1)
	{
		DispatchKeyValue(round_win, "force_map_reset", "1");
		SetEntProp(round_win, Prop_Data, "m_iTeamNum", team);
		
		AcceptEntityInput(round_win, "RoundWin");
	}
}

bool IsPlayerProp(int client)
{
	return TF2_GetClientTeam(client) == TFTeam_Props;
}

bool IsPlayerHunter(int client)
{
	return TF2_GetClientTeam(client) == TFTeam_Hunters;
}

bool IsValidPropClass(TFClassType class)
{
	for (int i = 0; i < sizeof(g_ValidPropClasses); i++)
	{
		if (g_ValidPropClasses[i] == class)
			return true;
	}
	return false;
}

TFClassType GetRandomPropClass()
{
	return g_ValidPropClasses[GetRandomInt(0, sizeof(g_ValidPropClasses) - 1)];
}

bool IsValidHunterClass(TFClassType class)
{
	for (int i = 0; i < sizeof(g_ValidHunterClasses); i++)
	{
		if (g_ValidHunterClasses[i] == class)
			return true;
	}
	return false;
}

TFClassType GetRandomHunterClass()
{
	return g_ValidHunterClasses[GetRandomInt(0, sizeof(g_ValidHunterClasses) - 1)];
}
