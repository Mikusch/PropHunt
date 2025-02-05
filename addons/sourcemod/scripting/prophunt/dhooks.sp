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

static DynamicHook g_DHookSpawn;
static DynamicHook g_DHookTakeHealth;
static DynamicHook g_DHookModifyOrAppendCriteria;
static DynamicHook g_DHookFireProjectile;
static DynamicHook g_DHookSmack;
static DynamicHook g_DHookHasKnockback;

void DHooks_Init()
{
	PSM_AddDynamicDetourFromConf("CTFPlayer::GetMaxHealthForBuffing", _, CTFPlayer_GetMaxHealthForBuffing_Post);
	PSM_AddDynamicDetourFromConf("CTFProjectile_GrapplingHook::HookTarget", CTFProjectile_GrapplingHook_HookTarget_Pre, CTFProjectile_GrapplingHook_HookTarget_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayerShared::Heal", CTFPlayerShared_Heal_Pre, _);
	PSM_AddDynamicDetourFromConf("CTFPistol_ScoutPrimary::Push", _, CTFPistol_ScoutPrimary_Push_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::TeamFortress_CalculateMaxSpeed", _, CTFPlayer_TeamFortress_CalculateMaxSpeed_Post);
	
	g_DHookSpawn = PSM_AddDynamicHookFromConf("CBaseEntity::Spawn");
	g_DHookTakeHealth = PSM_AddDynamicHookFromConf("CBaseEntity::TakeHealth");
	g_DHookModifyOrAppendCriteria = PSM_AddDynamicHookFromConf("CBaseEntity::ModifyOrAppendCriteria");
	g_DHookFireProjectile = PSM_AddDynamicHookFromConf("CTFWeaponBaseGun::FireProjectile");
	g_DHookSmack = PSM_AddDynamicHookFromConf("CTFWeaponBaseMelee::Smack");
	g_DHookHasKnockback = PSM_AddDynamicHookFromConf("CTFScatterGun::HasKnockback");
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (0 < entity <= MaxClients)
	{
		PSM_DHookEntity(g_DHookSpawn, Hook_Pre, entity, CTFPlayer_Spawn_Pre);
		PSM_DHookEntity(g_DHookTakeHealth, Hook_Pre, entity, CTFPlayer_TakeHealth_Pre);
		PSM_DHookEntity(g_DHookModifyOrAppendCriteria, Hook_Post, entity, CTFPlayer_ModifyOrAppendCriteria_Post);
	}
	else if (HasEntProp(entity, Prop_Data, "CTFWeaponBaseGunZoomOutIn"))
	{
		PSM_DHookEntity(g_DHookFireProjectile, Hook_Post, entity, CTFWeaponBaseGun_FireProjectile_Post);
	}
	else if (HasEntProp(entity, Prop_Data, "CTFWeaponBaseMeleeSmack"))
	{
		PSM_DHookEntity(g_DHookSmack, Hook_Post, entity, CTFWeaponBaseMelee_Smack_Post);
	}
	else if (StrEqual(classname, "tf_weapon_scattergun"))
	{
		PSM_DHookEntity(g_DHookHasKnockback, Hook_Post, entity, CTFScatterGun_HasKnockback_Post);
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
	
	if (ShouldPlayerDealSelfDamage(owner))
	{
		int launcher = GetEntPropEnt(projectile, Prop_Send, "m_hLauncher");
		float damage = SDKCall_GetProjectileDamage(launcher) * ph_hunter_damage_modifier_grapplinghook.FloatValue;
		int damageType = SDKCall_GetDamageType(projectile) | DMG_PREVENT_PHYSICS_FORCE;
		
		SDKHooks_TakeDamage(owner, projectile, owner, damage, damageType, launcher);
	}
	
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

static MRESReturn CTFPistol_ScoutPrimary_Push_Post(int weapon)
{
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	
	if (ShouldPlayerDealSelfDamage(owner))
	{
		// The damage value for the push is hardcoded
		float damage = 1.0 * ph_hunter_damage_modifier_scoutprimary_push.FloatValue;
		int damageType = DMG_MELEE | DMG_NEVERGIB | DMG_CLUB | DMG_PREVENT_PHYSICS_FORCE;
		
		SDKHooks_TakeDamage(owner, weapon, owner, damage, damageType, weapon);
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
		
		if (SDKCall_FindCriterionIndex(criteriaSet, "crosshair_enemy") == -1)
			return MRES_Ignored;
		
		// Prevent Hunters from revealing props using voice lines
		SDKCall_RemoveCriteria(criteriaSet, "crosshair_on");
		SDKCall_RemoveCriteria(criteriaSet, "crosshair_enemy");
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFWeaponBaseGun_FireProjectile_Post(int weapon, DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	int projectile = ret.Value;
	
	if (ShouldPlayerDealSelfDamage(player))
	{
		float damage = SDKCall_GetProjectileDamage(weapon) * GetWeaponBulletsPerShot(weapon) * ph_hunter_damage_modifier_gun.FloatValue;
		int damageType = SDKCall_GetDamageType(weapon) | DMG_PREVENT_PHYSICS_FORCE;
		
		SDKHooks_TakeDamage(player, projectile != -1 ? projectile : weapon, player, damage, damageType, weapon);
	}
	
	return MRES_Ignored;
}

static MRESReturn CTFWeaponBaseMelee_Smack_Post(int weapon)
{
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	
	if (ShouldPlayerDealSelfDamage(owner))
	{
		int damageType = SDKCall_GetDamageType(weapon) | DMG_PREVENT_PHYSICS_FORCE;
		float damage = SDKCall_GetMeleeDamage(weapon, owner, damageType, 0) * ph_hunter_damage_modifier_melee.FloatValue;
		
		SDKHooks_TakeDamage(owner, weapon, owner, damage, damageType, weapon);
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
