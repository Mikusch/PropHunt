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

enum struct DetourData
{
	DynamicDetour detour;
	DHookCallback callbackPre;
	DHookCallback callbackPost;
}

static ArrayList g_DynamicDetours;
static ArrayList g_DynamicHookIds;

static DynamicHook g_DHookSpawn;
static DynamicHook g_DHookTakeHealth;
static DynamicHook g_DHookModifyOrAppendCriteria;
static DynamicHook g_DHookFireProjectile;
static DynamicHook g_DHookSmack;
static DynamicHook g_DHookHasKnockback;

static int g_OldGameType;

void DHooks_Initialize(GameData gamedata)
{
	g_DynamicDetours = new ArrayList(sizeof(DetourData));
	g_DynamicHookIds = new ArrayList();
	
	DHooks_CreateDynamicDetour(gamedata, "CTFPlayer::GetMaxHealthForBuffing", _, DHookCallback_GetMaxHealthForBuffing_Post);
	DHooks_CreateDynamicDetour(gamedata, "CTFPlayer::CanPlayerMove", _, DHookCallback_CanPlayerMove_Post);
	DHooks_CreateDynamicDetour(gamedata, "CTFProjectile_GrapplingHook::HookTarget", DHookCallback_HookTarget_Pre, DHookCallback_HookTarget_Post);
	DHooks_CreateDynamicDetour(gamedata, "CTFPlayerShared::Heal", DHookCallback_Heal_Pre, _);
	DHooks_CreateDynamicDetour(gamedata, "CTFPistol_ScoutPrimary::Push", _, DHookCallback_Push_Post);
	DHooks_CreateDynamicDetour(gamedata, "CTeamplayRoundBasedRules::SetInWaitingForPlayers", DHookCallback_SetInWaitingForPlayers_Pre, DHookCallback_SetInWaitingForPlayers_Post);
	
	g_DHookSpawn = DHooks_CreateDynamicHook(gamedata, "CBaseEntity::Spawn");
	g_DHookTakeHealth = DHooks_CreateDynamicHook(gamedata, "CBaseEntity::TakeHealth");
	g_DHookModifyOrAppendCriteria = DHooks_CreateDynamicHook(gamedata, "CBaseEntity::ModifyOrAppendCriteria");
	g_DHookFireProjectile = DHooks_CreateDynamicHook(gamedata, "CTFWeaponBaseGun::FireProjectile");
	g_DHookSmack = DHooks_CreateDynamicHook(gamedata, "CTFWeaponBaseMelee::Smack");
	g_DHookHasKnockback = DHooks_CreateDynamicHook(gamedata, "CTFScatterGun::HasKnockback");
}

void DHooks_Toggle(bool enable)
{
	for (int i = 0; i < g_DynamicDetours.Length; i++)
	{
		DetourData data;
		if (g_DynamicDetours.GetArray(i, data) > 0)
		{
			if (data.callbackPre != INVALID_FUNCTION)
			{
				if (enable)
					data.detour.Enable(Hook_Pre, data.callbackPre);
				else
					data.detour.Disable(Hook_Pre, data.callbackPre);
			}
			
			if (data.callbackPost != INVALID_FUNCTION)
			{
				if (enable)
					data.detour.Enable(Hook_Post, data.callbackPost);
				else
					data.detour.Disable(Hook_Post, data.callbackPost);
			}
		}
	}
	
	if (!enable)
	{
		for (int i = 0; i < g_DynamicHookIds.Length; i++)
		{
			int hookid = g_DynamicHookIds.Get(i);
			DynamicHook.RemoveHook(hookid);
		}
		
		g_DynamicHookIds.Clear();
	}
}

void DHooks_HookClient(int client)
{
	if (g_DHookSpawn)
		DHooks_HookEntity(g_DHookSpawn, Hook_Pre, client, DHookCallback_Spawn_Pre);
	
	if (g_DHookTakeHealth)
		DHooks_HookEntity(g_DHookTakeHealth, Hook_Pre, client, DHookCallback_TakeHealth_Pre);
	
	if (g_DHookModifyOrAppendCriteria)
		DHooks_HookEntity(g_DHookModifyOrAppendCriteria, Hook_Post, client, DHookCallback_ModifyOrAppendCriteria_Post);
}

void DHooks_HookBaseGun(int weapon)
{
	if (g_DHookFireProjectile)
		DHooks_HookEntity(g_DHookFireProjectile, Hook_Post, weapon, DHookCallback_FireProjectile_Post);
}

void DHooks_HookBaseMelee(int weapon)
{
	if (g_DHookSmack)
		DHooks_HookEntity(g_DHookSmack, Hook_Post, weapon, DHookCallback_Smack_Post);
}

void DHooks_HookScatterGun(int scattergun)
{
	if (g_DHookHasKnockback)
		DHooks_HookEntity(g_DHookHasKnockback, Hook_Post, scattergun, DHookCallback_HasKnockback_Post);
}

static void DHooks_CreateDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		DetourData data;
		data.detour = detour;
		data.callbackPre = callbackPre;
		data.callbackPost = callbackPost;
		
		g_DynamicDetours.PushArray(data);
	}
	else
	{
		LogError("Failed to create detour setup handle for %s", name);
	}
}

static DynamicHook DHooks_CreateDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create hook setup handle for %s", name);
	
	return hook;
}

static void DHooks_HookEntity(DynamicHook hook, HookMode mode, int entity, DHookCallback callback)
{
	if (!hook)
		return;
	
	int hookid = hook.HookEntity(mode, entity, callback, DHookRemovalCB_OnHookRemoved);
	if (hookid != INVALID_HOOK_ID)
		g_DynamicHookIds.Push(hookid);
}

public void DHookRemovalCB_OnHookRemoved(int hookid)
{
	int index = g_DynamicHookIds.FindValue(hookid);
	if (index != -1)
		g_DynamicHookIds.Erase(index);
}

public MRESReturn DHookCallback_GetMaxHealthForBuffing_Post(int player, DHookReturn ret)
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
				if (StaticProp_GetOBBBounds(PHPlayer(player).PropIndex, mins, maxs))
					maxHealth = RoundToCeil(GetVectorDistance(mins, maxs));
			}
			case Prop_Entity:
			{
				int entity = EntRefToEntIndex(PHPlayer(player).PropIndex);
				if (entity != -1)
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

public MRESReturn DHookCallback_CanPlayerMove_Post(int player, DHookReturn ret)
{
	if (g_InSetup && ph_hunter_setup_freeze.BoolValue)
	{
		if (TF2_GetClientTeam(player) == TFTeam_Hunters)
		{
			ret.Value = false;
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_HookTarget_Pre(int projectile, DHookParam params)
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

public MRESReturn DHookCallback_HookTarget_Post(int projectile, DHookParam params)
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

public MRESReturn DHookCallback_Heal_Pre(Address playerShared, DHookParam params)
{
	int player = GetPlayerSharedOuter(playerShared);
	
	// Reduce healing from continuous sources (except control point bonus)
	if (!TF2_IsPlayerInCondition(player, TFCond_HalloweenQuickHeal))
	{
		float amount = params.Get(2);
		
		params.Set(2, amount * ph_healing_modifier.FloatValue);
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_Push_Post(int weapon)
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

public MRESReturn DHookCallback_SetInWaitingForPlayers_Pre(DHookParam params)
{
	// Re-enables waiting for player period
	g_OldGameType = GameRules_GetProp("m_nGameType");
	GameRules_SetProp("m_nGameType", 0);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_SetInWaitingForPlayers_Post(DHookParam params)
{
	GameRules_SetProp("m_nGameType", g_OldGameType);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_Spawn_Pre(int player)
{
	// This needs to happen before the first call to CTFPlayer::GetMaxHealthForBuffing
	ClearCustomModel(player);
	PHPlayer(player).OldMaxHealth = 0;
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_TakeHealth_Pre(int entity, DHookReturn ret, DHookParam params)
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

public MRESReturn DHookCallback_ModifyOrAppendCriteria_Post(int player, DHookParam params)
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

public MRESReturn DHookCallback_FireProjectile_Post(int weapon, DHookReturn ret, DHookParam params)
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

public MRESReturn DHookCallback_Smack_Post(int weapon)
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

public MRESReturn DHookCallback_HasKnockback_Post(int scattergun, DHookReturn ret)
{
	// Disables the Force-A-Nature knockback during setup
	if (g_InSetup)
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}
