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

// sizeof(WeaponData_t)
#define WEAPONDATA_SIZE	58

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

bool IsNaN(float value)
{
	return value != value;
}

// Thanks to ficool2 for helping me with scary vector math
bool IntersectionLineAABBFast(const float[3] mins, const float[3] maxs, const float[3] start, const float[3] dir, float far)
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

bool IsValidBboxSize(const float[3] mins, const float[3] maxs)
{
	return ph_prop_min_size.FloatValue < GetVectorDistance(mins, maxs) < ph_prop_max_size.FloatValue;
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

bool IsEntityClient(int entity)
{
	return 0 < entity < MaxClients;
}

int GetMaxHealth(int client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
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
	BuildPath(Path_SM, tidyMapName, sizeof(tidyMapName), CONFIG_FILEPATH, tidyMapName);
	
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

void ForceRoundWin(TFTeam team)
{
	int win = CreateEntityByName("game_round_win");
	
	DispatchKeyValue(win, "force_map_reset", "1");
	SetEntProp(win, Prop_Data, "m_iTeamNum", team);
	
	if (DispatchSpawn(win))
	{
		if (AcceptEntityInput(win, "RoundWin"))
			RemoveEntity(win);
	}
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
