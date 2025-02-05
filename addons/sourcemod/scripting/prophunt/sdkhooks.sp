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

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (0 < entity <= MaxClients)
	{
		PSM_SDKHook(entity, SDKHook_OnTakeDamage, CTFPlayer_OnTakeDamage);
	}
	else if (StrEqual(classname, "prop_dynamic"))
	{
		PSM_SDKHook(entity, SDKHook_SpawnPost, CDynamicProp_SpawnPost);
	}
	else if (strncmp(classname, "item_healthkit_", 15) == 0)
	{
		PSM_SDKHook(entity, SDKHook_Touch, CHealthKit_Touch);
		PSM_SDKHook(entity, SDKHook_TouchPost, CHealthKit_TouchPost);
	}
	else if (strncmp(classname, "tf_projectile_jar", 17) == 0 || StrEqual(classname, "tf_projectile_cleaver"))
	{
		PSM_SDKHook(entity, SDKHook_SpawnPost, CTFProjectile_Jar_SpawnPost);
	}
	else if (StrEqual(classname, "tf_projectile_stun_ball") || StrEqual(classname, "tf_projectile_ball_ornament"))
	{
		PSM_SDKHook(entity, SDKHook_SpawnPost, CTFStunBall_SpawnPost);
	}
	else if (StrEqual(classname, "tf_projectile_mechanicalarmorb"))
	{
		PSM_SDKHook(entity, SDKHook_SpawnPost, CTFProjectile_MechanicalArmOrb_SpawnPost);
	}
}

static Action CTFPlayer_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	// Prevent props from drowning
	if (damagetype & DMG_DROWN && TF2_GetClientTeam(victim) == TFTeam_Props)
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

static void CDynamicProp_SpawnPost(int prop)
{
	if (!g_IsMapRunning)
		return;
	
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(prop, Prop_Data, "m_ModelName", model, sizeof(model));
	
	// Hook the control point prop
	if (StrEqual(model, "models/props_gameplay/cap_point_base.mdl"))
	{
		SDKHook(prop, SDKHook_StartTouch, SDKHookCB_ControlPoint_StartTouch);
		
		// Create a taunt prop to outline the control point when the bonus is ready
		int glow = CreateEntityByName("tf_taunt_prop");
		if (glow != -1)
		{
			SetEntityModel(glow, model);
			
			float origin[3], angles[3];
			GetEntPropVector(prop, Prop_Data, "m_vecAbsOrigin", origin);
			GetEntPropVector(prop, Prop_Data, "m_angAbsRotation", angles);
			
			// Required for grappling hooks, otherwise players will grapple towards 0, 0, 0
			DispatchKeyValueVector(glow, "origin", origin);
			DispatchKeyValueVector(glow, "angles", angles);
			
			if (DispatchSpawn(glow))
			{
				SetEntPropEnt(glow, Prop_Data, "m_hEffectEntity", prop);
				SetEntProp(glow, Prop_Send, "m_bGlowEnabled", true);
				
				int effects = GetEntProp(glow, Prop_Send, "m_fEffects");
				SetEntProp(glow, Prop_Send, "m_fEffects", effects | EF_BONEMERGE | EF_NOSHADOW | EF_NORECEIVESHADOW);
				
				SetVariantString("!activator");
				AcceptEntityInput(glow, "SetParent", prop);
				
				SDKHook(glow, SDKHook_SetTransmit, SDKHookCB_TauntProp_SetTransmit);
			}
		}
	}
}

static Action CHealthKit_Touch(int healthkit, int other)
{
	g_InHealthKitTouch = true;
	
	return Plugin_Continue;
}

static void CHealthKit_TouchPost(int healthkit, int other)
{
	g_InHealthKitTouch = false;
}

static Action SDKHookCB_ControlPoint_StartTouch(int prop, int other)
{
	if (!IsSeekingTime())
		return Plugin_Continue;
	
	// Players touching the capture area receive a health bonus
	if (IsEntityClient(other) && !PHPlayer(other).HasReceivedBonus)
	{
		if (SDKCall_CastSelfHeal(other))
		{
			EmitGameSoundToClient(other, "Announcer.MVM_Bonus");
			CPrintToChat(other, "%s %t", PLUGIN_TAG, "PH_Bonus_Received");
			
			PHPlayer(other).HasReceivedBonus = true;
		}
	}
	
	return Plugin_Continue;
}

static Action SDKHookCB_TauntProp_SetTransmit(int entity, int client)
{
	if (!IsSeekingTime())
		return Plugin_Handled;
	
	// Give the control point an outline if the bonus is available
	if (PHPlayer(client).HasReceivedBonus)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

static void CTFProjectile_Jar_SpawnPost(int projectile)
{
	int owner = GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity");
	
	if (IsEntityClient(owner) && ShouldPlayerDealSelfDamage(owner))
	{
		int launcher = GetEntPropEnt(projectile, Prop_Send, "m_hLauncher");
		float damage = SDKCall_JarGetDamage(projectile) * ph_hunter_damage_modifier_projectile.FloatValue;
		int damageType = SDKCall_GetDamageType(projectile) | DMG_PREVENT_PHYSICS_FORCE;
		
		SDKHooks_TakeDamage(owner, projectile, owner, damage, damageType, launcher);
	}
}

static void CTFStunBall_SpawnPost(int projectile)
{
	int owner = GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity");
	
	if (IsEntityClient(owner) && ShouldPlayerDealSelfDamage(owner))
	{
		int launcher = GetEntPropEnt(projectile, Prop_Send, "m_hLauncher");
		float damage = FindConVar("sv_proj_stunball_damage").FloatValue * ph_hunter_damage_modifier_projectile.FloatValue;
		int damageType = SDKCall_GetDamageType(projectile) | DMG_PREVENT_PHYSICS_FORCE;
		
		SDKHooks_TakeDamage(owner, projectile, owner, damage, damageType, launcher);
	}
}

static void CTFProjectile_MechanicalArmOrb_SpawnPost(int projectile)
{
	int owner = GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity");
	
	if (IsEntityClient(owner) && ShouldPlayerDealSelfDamage(owner))
	{
		// The damage value for the mechanical arm orb is hardcoded
		int launcher = GetEntPropEnt(projectile, Prop_Send, "m_hLauncher");
		float damage = 15.0 * ph_hunter_damage_modifier_projectile.FloatValue;
		int damageType = SDKCall_GetDamageType(projectile) | DMG_PREVENT_PHYSICS_FORCE;
		
		SDKHooks_TakeDamage(owner, projectile, owner, damage, damageType, launcher);
	}
}
