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

static DynamicHook g_CBaseEntity_Spawn;
static DynamicHook g_CBaseEntity_TakeHealth;
static DynamicHook g_CBaseEntity_ModifyOrAppendCriteria;
static DynamicHook g_CTFScatterGun_HasKnockback;
static DynamicHook g_CTFBaseRocket_Explode;
static DynamicHook g_CTFWeaponBaseGrenadeProj_Explode;

void DHooks_Init()
{
	PSM_AddDynamicDetourFromConf("CTFPlayer::GetMaxHealthForBuffing", _, CTFPlayer_GetMaxHealthForBuffing_Post);
	PSM_AddDynamicDetourFromConf("CTFProjectile_GrapplingHook::HookTarget", CTFProjectile_GrapplingHook_HookTarget_Pre, CTFProjectile_GrapplingHook_HookTarget_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayerShared::Heal", CTFPlayerShared_Heal_Pre, _);
	PSM_AddDynamicDetourFromConf("CTFPlayer::TeamFortress_CalculateMaxSpeed", _, CTFPlayer_TeamFortress_CalculateMaxSpeed_Post);
	
	g_CBaseEntity_Spawn = PSM_AddDynamicHookFromConf("CBaseEntity::Spawn");
	g_CBaseEntity_TakeHealth = PSM_AddDynamicHookFromConf("CBaseEntity::TakeHealth");
	g_CBaseEntity_ModifyOrAppendCriteria = PSM_AddDynamicHookFromConf("CBaseEntity::ModifyOrAppendCriteria");
	g_CTFScatterGun_HasKnockback = PSM_AddDynamicHookFromConf("CTFScatterGun::HasKnockback");
	g_CTFBaseRocket_Explode = PSM_AddDynamicHookFromConf("CTFBaseRocket::Explode");
	g_CTFWeaponBaseGrenadeProj_Explode = PSM_AddDynamicHookFromConf("CTFWeaponBaseGrenadeProj::Explode");
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (0 < entity <= MaxClients)
	{
		PSM_DHookEntity(g_CBaseEntity_Spawn, Hook_Pre, entity, CTFPlayer_Spawn_Pre);
		PSM_DHookEntity(g_CBaseEntity_TakeHealth, Hook_Pre, entity, CTFPlayer_TakeHealth_Pre);
		PSM_DHookEntity(g_CBaseEntity_ModifyOrAppendCriteria, Hook_Post, entity, CTFPlayer_ModifyOrAppendCriteria_Post);
	}
	else if (StrEqual(classname, "tf_weapon_scattergun"))
	{
		PSM_DHookEntity(g_CTFScatterGun_HasKnockback, Hook_Post, entity, CTFScatterGun_HasKnockback_Post);
	}
	else if (IsCTFBaseRocket(entity))
	{
		PSM_DHookEntity(g_CTFBaseRocket_Explode, Hook_Post, entity, CTFBaseRocket_Explode_Post);
	}
	else if (IsCTFWeaponBaseGrenadeProj(entity))
	{
		PSM_DHookEntity(g_CTFWeaponBaseGrenadeProj_Explode, Hook_Post, entity, CTFWeaponBaseGrenadeProj_Explode_Post);
	}
}

static MRESReturn CTFPlayer_GetMaxHealthForBuffing_Post(int player, DHookReturn ret)
{
	if (TF2_GetClientTeam(player) == TFTeam_Props)
	{
		int maxHealth;
		float mins[3], maxs[3];
		
		// Determine health based on prop bounding box size
		switch (PHPlayer(player).PropType)
		{
			case Prop_Static:
			{
				// Check if the config wants to override the health
				char model[PLATFORM_MAX_PATH];
				PropConfig config;
				if (StaticProp_GetModelName(PHPlayer(player).PropIndex, model, sizeof(model)) && GetConfigByModel(model, config) && config.health > 0)
					maxHealth = config.health;
				else if (StaticProp_GetOBBBounds(PHPlayer(player).PropIndex, mins, maxs))
					maxHealth = RoundToCeil(GetVectorDistance(mins, maxs));
			}
			case Prop_Entity:
			{
				int entity = EntRefToEntIndex(PHPlayer(player).PropIndex);
				if (entity != -1)
				{
					// Check if the config wants to override the health
					char model[PLATFORM_MAX_PATH];
					PropConfig config;
					if (GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model)) > 0 && GetConfigByModel(model, config) && config.health > 0)
					{
						maxHealth = config.health;
					}
					else
					{
						if (IsEntityClient(entity) && IsClientInGame(entity) && TF2_GetClientTeam(entity) == TFTeam_Hunters)
						{
							maxHealth = GetPlayerMaxHealth(entity);
						}
						else if (!IsEntityClient(entity) && HasEntProp(entity, Prop_Data, "m_iMaxHealth") && GetEntProp(entity, Prop_Data, "m_iMaxHealth") > 1)
						{
							maxHealth = GetEntProp(entity, Prop_Data, "m_iMaxHealth");
						}
						else
						{
							GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
							GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);
							maxHealth = RoundToCeil(GetVectorDistance(mins, maxs));
						}
					}
				}
				else
				{
					// Prop we disguised as is now invalid, don't update max health until we redisguise
					maxHealth = GetPlayerMaxHealth(player);
				}
			}
			default:
			{
				// Use class default health if we are not a prop
				return MRES_Ignored;
			}
		}
		
		// Clamp the health to avoid unkillable props
		if (ph_prop_max_health.IntValue > 0)
			maxHealth = Min(maxHealth, ph_prop_max_health.IntValue);
		
		// Keep the ratio of health to max health the same when the player switches props
		// e.g. switching from a 200/250 health prop to a 20/25 health prop
		int oldMaxHealth = PHPlayer(player).OldMaxHealth;
		if (oldMaxHealth != maxHealth)
		{
			float mult = oldMaxHealth != 0 ? float(GetEntProp(player, Prop_Data, "m_iHealth")) / float(oldMaxHealth) : 1.0;
			SetEntityHealth(player, RoundToNearest(maxHealth * mult));
		}
		
		PHPlayer(player).OldMaxHealth = maxHealth;
		
		ret.Value = maxHealth;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFProjectile_GrapplingHook_HookTarget_Pre(int projectile, DHookParam params)
{
	int owner = GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity");
	
	if (TF2_GetClientTeam(owner) == TFTeam_Hunters)
	{
		// Don't allow hunters to hook onto props
		if (!params.IsNull(1))
		{
			int other = params.Get(1);
			if (IsEntityClient(other) && TF2_GetClientTeam(other) == TFTeam_Props)
				return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFProjectile_GrapplingHook_HookTarget_Post(int projectile, DHookParam params)
{
	int owner = GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity");
	
	if (!ShouldPlayerDealSelfDamage(owner))
		return MRES_Ignored;
	
	int launcher = GetEntPropEnt(projectile, Prop_Send, "m_hLauncher");
	float damage = SDKCall_CTFWeaponBaseGun_GetProjectileDamage(launcher) * ph_hunter_damage_modifier_grapplinghook.FloatValue;
	int damageType = SDKCall_CBaseEntity_GetDamageType(projectile) | DMG_PREVENT_PHYSICS_FORCE;
	
	SDKHooks_TakeDamage(owner, projectile, owner, damage, damageType, launcher);
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayerShared_Heal_Pre(Address pShared, DHookParam params)
{
	int player = TF2Util_GetPlayerFromSharedAddress(pShared);
	
	// Reduce healing from continuous sources (except control point bonus)
	if (!TF2_IsPlayerInCondition(player, TFCond_HalloweenQuickHeal))
	{
		float amount = params.Get(2);
		
		params.Set(2, amount * ph_healing_modifier.FloatValue);
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayer_TeamFortress_CalculateMaxSpeed_Post(int client, DHookReturn ret)
{
	if (g_InSetup && ph_hunter_setup_freeze.BoolValue && TF2_GetClientTeam(client) == TFTeam_Hunters)
	{
		ret.Value = 1.0;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayer_Spawn_Pre(int player)
{
	// This needs to happen before the first call to CTFPlayer::GetMaxHealthForBuffing
	ClearCustomModel(player);
	PHPlayer(player).OldMaxHealth = 0;
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayer_TakeHealth_Pre(int entity, DHookReturn ret, DHookParam params)
{
	// Make sure we don't reduce healing induced by CTFPlayerShared::Heal since we already handle that above
	if (!g_InHealthKitTouch && !TF2_IsPlayerInCondition(entity, TFCond_Healing))
	{
		float health = params.Get(1);
		
		params.Set(1, health * ph_healing_modifier.FloatValue);
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFPlayer_ModifyOrAppendCriteria_Post(int player, DHookParam params)
{
	if (TF2_GetClientTeam(player) == TFTeam_Hunters)
	{
		int criteriaSet = params.Get(1);
		
		if (SDKCall_AI_CriteriaSet_FindCriterionIndex(criteriaSet, "crosshair_enemy") == -1)
			return MRES_Ignored;
		
		// Prevent Hunters from revealing props using voice lines
		SDKCall_AI_CriteriaSet_RemoveCriteria(criteriaSet, "crosshair_on");
		SDKCall_AI_CriteriaSet_RemoveCriteria(criteriaSet, "crosshair_enemy");
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFScatterGun_HasKnockback_Post(int scattergun, DHookReturn ret)
{
	// Disables the Force-A-Nature knockback during setup
	if (g_InSetup)
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFBaseRocket_Explode_Post(int rocket, DHookParam params)
{
	int other = params.Get(2);
	if (0 < other <= MaxClients)
		return MRES_Ignored;
	
	int owner = GetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity");
	if (owner == -1)
		return MRES_Ignored;
	
	if (!ShouldPlayerDealSelfDamage(owner))
		return MRES_Ignored;
	
	float damage = SDKCall_CBaseEntity_GetDamage(rocket) * ph_hunter_damage_modifier_projectile.FloatValue;
	int damageType = SDKCall_CBaseEntity_GetDamageType(rocket) | DMG_PREVENT_PHYSICS_FORCE;
	int launcher = GetEntPropEnt(rocket, Prop_Send, "m_hLauncher");
	
	SDKHooks_TakeDamage(owner, rocket, owner, damage, damageType, launcher);
	
	return MRES_Ignored;
}

static MRESReturn CTFWeaponBaseGrenadeProj_Explode_Post(int projectile, DHookParam params)
{
	int traceEnt = params.GetObjectVar(1, GetOffset("CGameTrace", "m_pEnt"), ObjectValueType_CBaseEntityPtr);
	if (0 < traceEnt <= MaxClients)
		return MRES_Ignored;
	
	int thrower = GetEntPropEnt(projectile, Prop_Send, "m_hThrower");
	if (thrower == -1)
		return MRES_Ignored;
	
	if (!ShouldPlayerDealSelfDamage(thrower))
		return MRES_Ignored;
	
	float damage = GetEntPropFloat(projectile, Prop_Send, "m_flDamage") * ph_hunter_damage_modifier_projectile.FloatValue;
	int damageType = params.Get(2) | DMG_PREVENT_PHYSICS_FORCE;
	int weapon = GetEntPropEnt(projectile, Prop_Send, "m_hLauncher");
	
	SDKHooks_TakeDamage(thrower, projectile, thrower, damage, damageType, weapon);
	
	return MRES_Ignored;
}
