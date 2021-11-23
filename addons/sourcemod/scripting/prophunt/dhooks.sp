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

static DynamicHook g_DHookSpawn;
static DynamicHook g_DHookModifyOrAppendCriteria;
static DynamicHook g_DHookFireProjectile;
static DynamicHook g_DHookSmack;

void DHooks_Initialize(GameData gamedata)
{
	DHooks_CreateDetour(gamedata, "CTFPlayer::GetMaxHealthForBuffing", _, DHookCallback_GetMaxHealthForBuffing_Post);
	DHooks_CreateDetour(gamedata, "CTFPlayer::CanPlayerMove", _, DHookCallback_CanPlayerMove_Post);
	DHooks_CreateDetour(gamedata, "CTFProjectile_GrapplingHook::HookTarget", DHookCallback_HookTarget_Pre, _);
	DHooks_CreateDetour(gamedata, "CTFPlayerShared::Heal", DHookCallback_Heal_Pre, _);
	
	g_DHookSpawn = CreateDynamicHook(gamedata, "CBaseEntity::Spawn");
	g_DHookModifyOrAppendCriteria = CreateDynamicHook(gamedata, "CBaseEntity::ModifyOrAppendCriteria");
	g_DHookFireProjectile = CreateDynamicHook(gamedata, "CTFWeaponBaseGun::FireProjectile");
	g_DHookSmack = CreateDynamicHook(gamedata, "CTFWeaponBaseMelee::Smack");
}

void DHooks_HookClient(int client)
{
	if (g_DHookSpawn)
		g_DHookSpawn.HookEntity(Hook_Pre, client, DHookCallback_Spawn_Pre);
	
	if (g_DHookModifyOrAppendCriteria)
		g_DHookModifyOrAppendCriteria.HookEntity(Hook_Post, client, DHookCallback_ModifyOrAppendCriteria_Post);
}

void DHooks_HookBaseGun(int weapon)
{
	if (g_DHookFireProjectile)
		g_DHookFireProjectile.HookEntity(Hook_Pre, weapon, DHookCallback_FireProjectile_Pre);
}

void DHooks_HookBaseMelee(int weapon)
{
	if (g_DHookSmack)
		g_DHookSmack.HookEntity(Hook_Pre, weapon, DHookCallback_Smack_Pre);
}

static void DHooks_CreateDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);
		
		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
	else
	{
		LogError("Failed to create detour: %s", name);
	}
}

static DynamicHook CreateDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create hook setup handle for %s", name);
	
	return hook;
}

public MRESReturn DHookCallback_GetMaxHealthForBuffing_Post(int player, DHookReturn ret)
{
	if (IsPlayerProp(player))
	{
		int health;
		float mins[3], maxs[3];
		
		// Determine health based on prop bounding box size
		switch (PHPlayer(player).PropType)
		{
			case Prop_Static:
			{
				if (StaticProp_GetOBBBounds(PHPlayer(player).PropIndex, mins, maxs))
					health = GetHealthForBbox(mins, maxs);
			}
			case Prop_Entity:
			{
				int entity = EntRefToEntIndex(PHPlayer(player).PropIndex);
				if (entity != -1)
				{
					GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
					GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);
					health = GetHealthForBbox(mins, maxs);
				}
				else
				{
					// Prop we disguised as is now invalid, don't update max health until we redisguise
					health = GetPlayerMaxHealth(player);
				}
			}
			default:
			{
				// Use class default health if we are not a prop
				return MRES_Ignored;
			}
		}
		
		ret.Value = health;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanPlayerMove_Post(int player, DHookReturn ret)
{
	// Allow movement during arena pre-round time
	if (GameRules_GetRoundState() == RoundState_Preround)
	{
		if (IsPlayerProp(player) || IsPlayerHunter(player) && !ph_hunter_setup_freeze.BoolValue)
		{
			ret.Value = true;
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_HookTarget_Pre(int projectile, DHookParam params)
{
	if (GameRules_GetRoundState() != RoundState_Stalemate)
		return MRES_Ignored;
	
	int owner = GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity");
	
	if (IsPlayerHunter(owner))
	{
		int launcher = GetEntPropEnt(projectile, Prop_Send, "m_hLauncher");
		float damage = SDKCall_GetProjectileDamage(launcher) * ph_hunter_damage_modifier_grapplinghook.FloatValue;
		int damageType = SDKCall_GetDamageType(projectile) | DMG_PREVENT_PHYSICS_FORCE;
		
		SDKHooks_TakeDamage(owner, projectile, owner, damage, damageType, launcher);
		
		// Don't allow hunters to hook onto props
		if (!params.IsNull(1))
		{
			int other = params.Get(1);
			if (IsEntityClient(other) && IsPlayerProp(other))
				return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_Heal_Pre(Address playerShared, DHookParam params)
{
	int player = GetPlayerSharedOuter(playerShared);
	
	// Reduce healing from all sources (except control point bonus)
	if (!TF2_IsPlayerInCondition(player, TFCond_HalloweenQuickHeal))
	{
		float amount = params.Get(2);
		
		params.Set(2, amount * ph_healing_modifier.FloatValue);
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}


public MRESReturn DHookCallback_Spawn_Pre(int player)
{
	// player_spawn event gets fired too early to manipulate player class properly
	if (IsPlayerProp(player))
	{
		// Check valid prop class
		if (!IsValidPropClass(TF2_GetPlayerClass(player)))
			TF2_SetPlayerClass(player, GetRandomPropClass(), _, false);
	}
	else if (IsPlayerHunter(player))
	{
		// Check valid hunter class
		if (!IsValidHunterClass(TF2_GetPlayerClass(player)))
			TF2_SetPlayerClass(player, GetRandomHunterClass(), _, false);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ModifyOrAppendCriteria_Post(int player, DHookParam params)
{
	if (IsPlayerHunter(player))
	{
		int criteriaSet = params.Get(1);
		
		if (SDKCall_FindCriterionIndex(criteriaSet, "crosshair_enemy") == -1)
			return MRES_Ignored;
		
		// Prevent Hunters from revealing props using voice lines
		SDKCall_RemoveCriteria(criteriaSet, "crosshair_on");
		SDKCall_RemoveCriteria(criteriaSet, "crosshair_enemy");
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_FireProjectile_Pre(int weapon, DHookReturn ret, DHookParam params)
{
	if (GameRules_GetRoundState() != RoundState_Stalemate)
		return MRES_Ignored;
	
	int player = params.Get(1);
	
	if (IsPlayerHunter(player))
	{
		float damage = SDKCall_GetProjectileDamage(weapon) * GetBulletsPerShot(weapon) * ph_hunter_damage_modifier_gun.FloatValue;
		int damageType = SDKCall_GetDamageType(weapon) | DMG_PREVENT_PHYSICS_FORCE;
		
		SDKHooks_TakeDamage(player, weapon, player, damage, damageType, weapon);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_Smack_Pre(int weapon)
{
	if (GameRules_GetRoundState() != RoundState_Stalemate)
		return MRES_Ignored;
	
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	
	if (IsPlayerHunter(owner))
	{
		int damageType = SDKCall_GetDamageType(weapon) | DMG_PREVENT_PHYSICS_FORCE;
		float damage = SDKCall_GetMeleeDamage(weapon, owner, damageType, 0) * ph_hunter_damage_modifier_melee.FloatValue;
		
		SDKHooks_TakeDamage(owner, weapon, owner, damage, damageType, weapon);
	}
	
	return MRES_Ignored;
}
