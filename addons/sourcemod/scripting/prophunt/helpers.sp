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

#pragma semicolon 1
#pragma newdecls required

#define FLOAT_EPSILON	0.0001

#define WEAPONDATA_SIZE	58	// sizeof(WeaponData_t)

static const TFClassType g_ValidPropClasses[] =
{
	TFClass_Scout,
};

static const TFClassType g_ValidHunterClasses[] =
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
		
		// near tracks distance to intersect (enter) the AABB
		// far tracks the distance to exit the AABB
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

int GetWeaponData(int weapon)
{
	int weaponMode = GetEntData(weapon, g_OffsetWeaponMode);
	int weaponInfo = GetEntData(weapon, g_OffsetWeaponInfo);
	return weaponInfo + (WEAPONDATA_SIZE * weaponMode);
}

int GetWeaponDamage(int weapon)
{
	// m_pWeaponInfo->GetWeaponData( m_iWeaponMode ).m_nDamage
	return LoadFromAddress(view_as<Address>(GetWeaponData(weapon) + g_OffsetWeaponDamage), NumberType_Int32);
}

int GetWeaponBulletsPerShot(int weapon)
{
	// m_pWeaponInfo->GetWeaponData( m_iWeaponMode ).m_nBulletsPerShot
	return LoadFromAddress(view_as<Address>(GetWeaponData(weapon) + g_OffsetWeaponBulletsPerShot), NumberType_Int32);
}

float GetWeaponTimeFireDelay(int weapon)
{
	// m_pWeaponInfo->GetWeaponData( m_iWeaponMode ).m_flTimeFireDelay
	return view_as<float>(LoadFromAddress(view_as<Address>(GetWeaponData(weapon) + g_OffsetWeaponTimeFireDelay), NumberType_Int32));
}

int GetPlayerSharedOuter(Address playerShared)
{
	Address outer = view_as<Address>(LoadFromAddress(playerShared + view_as<Address>(g_OffsetPlayerSharedOuter), NumberType_Int32));
	return SDKCall_GetBaseEntity(outer);
}

bool GetConfigByModel(const char[] model, PropConfig config)
{
	for (int i = 0; i < g_PropConfigs.Length; i++)
	{
		if (g_PropConfigs.GetArray(i, config) > 0)
		{
			// Try to fetch config by exact match first
			if (config.model[0] != EOS && strcmp(config.model, model) == 0)
				return true;
			
			// Then, try the regular expression
			if (config.regex && config.regex.Match(model) > 0)
				return true;
		}
	}
	
	return false;
}

bool IsPropBlacklisted(const char[] model)
{
	PropConfig config;
	return GetConfigByModel(model, config) && config.blacklist;
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
		buffer[start] = EOS;
}

bool IsEntityClient(int entity)
{
	return 0 < entity <= MaxClients;
}

int GetPlayerMaxHealth(int client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}

int GetEntityHealth(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_iHealth");
}

void AddEntityHealth(int entity, int amount)
{
	SetEntityHealth(entity, GetEntityHealth(entity) + amount);
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
	while (string[i] != EOS)
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
	
	// Split map prefix and first part of its name (e.g. pl_hightower)
	char[][] nameParts = new char[partsCount][PLATFORM_MAX_PATH];
	ExplodeString(mapName, "_", nameParts, partsCount, PLATFORM_MAX_PATH);
	
	// Start to stitch name parts together
	char tidyMapName[PLATFORM_MAX_PATH];
	char filePathBuffer[PLATFORM_MAX_PATH];
	strcopy(tidyMapName, sizeof(tidyMapName), nameParts[0]);
	
	// Build file path
	BuildPath(Path_SM, tidyMapName, sizeof(tidyMapName), MAP_CONFIG_FILEPATH, tidyMapName);
	
	for (int i = 1; i < partsCount; i++)
	{
		Format(tidyMapName, sizeof(tidyMapName), "%s_%s", tidyMapName, nameParts[i]);
		Format(filePathBuffer, sizeof(filePathBuffer), "%s.cfg", tidyMapName);
		
		// Find the most specific config
		if (FileExists(filePathBuffer))
			strcopy(filePath, length, filePathBuffer);
	}
	
	return FileExists(filePath);
}

void PrintKeyHintText(int client, const char[] format, any...)
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
		RemoveEntity(round_win);
	}
}

bool CanPlayerChangeProp(int client)
{
	return !TF2_IsPlayerInCondition(client, TFCond_OnFire)
		&& !TF2_IsPlayerInCondition(client, TFCond_Jarated)
		&& !TF2_IsPlayerInCondition(client, TFCond_Bleeding)
		&& !TF2_IsPlayerInCondition(client, TFCond_Milked)
		&& !TF2_IsPlayerInCondition(client, TFCond_Gas);
}

bool IsValidClass(TFTeam team, TFClassType class)
{
	if (team == TFTeam_Props)
	{
		for (int i = 0; i < sizeof(g_ValidPropClasses); i++)
		{
			if (g_ValidPropClasses[i] == class)
				return true;
		}
	}
	else if (team == TFTeam_Hunters)
	{
		for (int i = 0; i < sizeof(g_ValidHunterClasses); i++)
		{
			if (g_ValidHunterClasses[i] == class)
				return true;
		}
	}
	
	return false;
}

TFClassType GetRandomValidClass(TFTeam team)
{
	if (team == TFTeam_Props)
		return g_ValidPropClasses[GetRandomInt(0, sizeof(g_ValidPropClasses) - 1)];
	else if (team == TFTeam_Hunters)
		return g_ValidHunterClasses[GetRandomInt(0, sizeof(g_ValidHunterClasses) - 1)];
	else
		return TFClass_Unknown;
}

bool IsSeekingTime()
{
	return GameRules_GetRoundState() == RoundState_Stalemate && !g_InSetup;
}

bool ShouldPlayerDealSelfDamage(int client)
{
	return TF2_GetClientTeam(client) == TFTeam_Hunters && IsSeekingTime();
}

// FIXME: This does not hide weapons with strange stat clock attachments
void SetItemAlpha(int item, int alpha)
{
	// Hide the weapon
	SetEntityRenderMode(item, RENDER_TRANSCOLOR);
	SetEntityRenderColor(item, 255, 255, 255, alpha);
	
	// Hide extra wearables on the weapon
	if (HasEntProp(item, Prop_Send, "m_hExtraWearable"))
	{
		int extraWearable = GetEntPropEnt(item, Prop_Send, "m_hExtraWearable");
		if (extraWearable != -1)
		{
			SetEntityRenderMode(extraWearable, RENDER_TRANSCOLOR);
			SetEntityRenderColor(extraWearable, 255, 255, 255, alpha);
		}
	}
	
	// Hide extra wearables on the viewmodel
	if (HasEntProp(item, Prop_Send, "m_hExtraWearableViewModel"))
	{
		int extraWearable = GetEntPropEnt(item, Prop_Send, "m_hExtraWearableViewModel");
		if (extraWearable != -1)
		{
			SetEntityRenderMode(extraWearable, RENDER_TRANSCOLOR);
			SetEntityRenderColor(extraWearable, 255, 255, 255, alpha);
		}
	}
}
