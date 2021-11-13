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

static DynamicHook g_DHookFireProjectile;
static DynamicHook g_DHookSmack;
static DynamicHook g_DHookSpawn;

void DHooks_Initialize(GameData gamedata)
{
	DHooks_CreateDetour(gamedata, "CTFPlayer::GetMaxHealthForBuffing", _, DHook_GetMaxHealthForBuffing_Post);
	DHooks_CreateDetour(gamedata, "CTFProjectile_GrapplingHook::HookTarget", DHook_HookTarget_Pre, _);
	DHooks_CreateDetour(gamedata, "CTFPlayer::CanPlayerMove", _, DHook_CanPlayerMove_Post);
	
	g_DHookSpawn = CreateDynamicHook(gamedata, "CBaseEntity::Spawn");
	g_DHookFireProjectile = CreateDynamicHook(gamedata, "CTFWeaponBaseGun::FireProjectile");
	g_DHookSmack = CreateDynamicHook(gamedata, "CTFWeaponBaseMelee::Smack");
}

void DHooks_HookClient(int client)
{
	if (g_DHookSpawn)
		g_DHookSpawn.HookEntity(Hook_Pre, client, DHook_Spawn_Pre);
}

void DHooks_HookBaseGun(int weapon)
{
	if (g_DHookFireProjectile)
		g_DHookFireProjectile.HookEntity(Hook_Pre, weapon, DHook_FireProjectile_Pre);
}

void DHooks_HookBaseMelee(int weapon)
{
	if (g_DHookSmack)
		g_DHookSmack.HookEntity(Hook_Pre, weapon, DHook_Smack_Pre);
}

static void DHooks_CreateDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (!detour)
	{
		LogError("Failed to create detour: %s", name);
	}
	else
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);
		
		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
}

static DynamicHook CreateDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create hook setup handle for %s", name);
	
	return hook;
}

public MRESReturn DHook_GetMaxHealthForBuffing_Post(int player, DHookReturn ret)
{
	if (PHPlayer(player).IsProp())
	{
		int health;
		float mins[3], maxs[3];
		
		// Determine health based on prop bounding box size
		switch (PHPlayer(player).PropType)
		{
			case Prop_Static:
			{
				if (StaticProp_GetWorldSpaceBounds(PHPlayer(player).PropIndex, mins, maxs))
					health = RoundToCeil(GetVectorDistance(mins, maxs));
			}
			case Prop_Entity:
			{
				int entity = EntRefToEntIndex(PHPlayer(player).PropIndex);
				if (entity != -1)
				{
					GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
					GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);
					health = RoundToCeil(GetVectorDistance(mins, maxs));
				}
				else
				{
					// Prop we disguised as is now invalid, don't update max health until we redisguise
					health = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, player);
				}
			}
			default:
			{
				// Use class default health if we are not a prop
				return MRES_Ignored;
			}
		}
		
		// Refill health during setup time
		if (GameRules_GetRoundState() == RoundState_Preround || g_InSetup)
			SetEntityHealth(player, health);
		
		ret.Value = health;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_HookTarget_Pre(int projectile, DHookParam params)
{
	if (GameRules_GetRoundState() != RoundState_Stalemate || g_InSetup)
		return MRES_Ignored;
	
	int owner = GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity");
	
	if (PHPlayer(owner).IsHunter())
	{
		float damage = ph_hunter_damage_grapplinghook.FloatValue;
		int damageType = SDKCall_GetDamageType(projectile) | DMG_PREVENT_PHYSICS_FORCE;
		int launcher = GetEntPropEnt(projectile, Prop_Send, "m_hLauncher");
		
		SDKHooks_TakeDamage(owner, projectile, owner, damage, damageType, launcher);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_CanPlayerMove_Post(int player, DHookReturn ret)
{
	if (g_InSetup)
	{
		if (PHPlayer(player).IsHunter())
		{
			ret.Value = false;
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_Spawn_Pre(int player)
{
	// player_spawn event gets fired too early to manipulate player class properly
	if (PHPlayer(player).IsProp())
	{
		// Check valid prop class
		if (!IsValidPropClass(TF2_GetPlayerClass(player)))
		{
			TF2_SetPlayerClass(player, GetRandomPropClass(), _, false);
		}
	}
	else if (PHPlayer(player).IsHunter())
	{
		// Check valid hunter class
		if (!IsValidHunterClass(TF2_GetPlayerClass(player)))
		{
			TF2_SetPlayerClass(player, GetRandomHunterClass(), _, false);
		}
	}
}

public MRESReturn DHook_FireProjectile_Pre(int weapon, DHookReturn ret, DHookParam params)
{
	if (GameRules_GetRoundState() != RoundState_Stalemate || g_InSetup)
		return MRES_Ignored;
	
	int player = params.Get(1);
	
	if (PHPlayer(player).IsHunter())
	{
		float damage = SDKCall_GetProjectileDamage(weapon) * GetBulletsPerShot(weapon);
		if (!IsNaN(damage))
		{
			damage *= ph_hunter_damagemod_guns.FloatValue;
			int damageType = SDKCall_GetDamageType(weapon) | DMG_PREVENT_PHYSICS_FORCE;
			
			SDKHooks_TakeDamage(player, weapon, player, damage, damageType, weapon);
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_Smack_Pre(int weapon)
{
	if (GameRules_GetRoundState() != RoundState_Stalemate || g_InSetup)
		return MRES_Ignored;
	
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	
	if (PHPlayer(owner).IsHunter())
	{
		int damageType = SDKCall_GetDamageType(weapon) | DMG_PREVENT_PHYSICS_FORCE;
		float damage = SDKCall_GetMeleeDamage(weapon, owner, damageType, 0);
		if (!IsNaN(damage))
		{
			damage *= ph_hunter_damagemod_melee.FloatValue;
			
			SDKHooks_TakeDamage(owner, weapon, owner, damage, damageType, weapon);
		}
	}
	
	return MRES_Ignored;
}
