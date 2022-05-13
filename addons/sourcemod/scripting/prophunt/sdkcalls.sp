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

static Handle g_SDKCallCastSelfHeal;
static Handle g_SDKCallFindCriterionIndex;
static Handle g_SDKCallRemoveCriteria;
static Handle g_SDKCallSetSwitchTeams;
static Handle g_SDKCallGetBaseEntity;
static Handle g_SDKCallGetDamageType;
static Handle g_SDKCallInitClass;
static Handle g_SDKCallGetProjectileDamage;
static Handle g_SDKCallGetMeleeDamage;
static Handle g_SDKCallJarGetDamage;

void SDKCalls_Initialize(GameData gamedata)
{
	g_SDKCallCastSelfHeal = PrepSDKCall_CastSelfHeal(gamedata);
	g_SDKCallFindCriterionIndex = PrepSDKCall_FindCriterionIndex(gamedata);
	g_SDKCallRemoveCriteria = PrepSDKCall_RemoveCriteria(gamedata);
	g_SDKCallSetSwitchTeams = PrepSDKCall_SetSwitchTeams(gamedata);
	g_SDKCallGetBaseEntity = PrepSDKCall_GetBaseEntity(gamedata);
	g_SDKCallGetDamageType = PrepSDKCall_GetDamageType(gamedata);
	g_SDKCallInitClass = PrepSDKCall_InitClass(gamedata);
	g_SDKCallGetProjectileDamage = PrepSDKCall_GetProjectileDamage(gamedata);
	g_SDKCallGetMeleeDamage = PrepSDKCall_GetMeleeDamage(gamedata);
	g_SDKCallJarGetDamage = PrepSDKCall_JarGetDamage(gamedata);
}

static Handle PrepSDKCall_CastSelfHeal(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFSpellBook::CastSelfHeal");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTFSpellBook::CastSelfHeal");
	
	return call;
}

static Handle PrepSDKCall_FindCriterionIndex(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "AI_CriteriaSet::FindCriterionIndex");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: AI_CriteriaSet::FindCriterionIndex");
	
	return call;
}

static Handle PrepSDKCall_RemoveCriteria(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "AI_CriteriaSet::RemoveCriteria");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: AI_CriteriaSet::RemoveCriteria");
	
	return call;
}

static Handle PrepSDKCall_SetSwitchTeams(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTeamplayRules::SetSwitchTeams");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTeamplayRules::SetSwitchTeams");
	
	return call;
}

static Handle PrepSDKCall_GetBaseEntity(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::GetBaseEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CBaseEntity::GetBaseEntity");
	
	return call;
}

static Handle PrepSDKCall_GetDamageType(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::GetDamageType");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CBaseEntity::GetDamageType");
	
	return call;
}

static Handle PrepSDKCall_InitClass(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFPlayer::InitClass");
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTFPlayer::InitClass");
	
	return call;
}

static Handle PrepSDKCall_GetProjectileDamage(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFWeaponBaseGun::GetProjectileDamage");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTFWeaponBaseGun::GetProjectileDamage");
	
	return call;
}

static Handle PrepSDKCall_GetMeleeDamage(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFWeaponBaseMelee::GetMeleeDamage");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTFWeaponBaseMelee::GetMeleeDamage");
	
	return call;
}

static Handle PrepSDKCall_JarGetDamage(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFProjectile_Jar::GetDamage");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTFProjectile_Jar::GetDamage");
	
	return call;
}

bool SDKCall_CastSelfHeal(int player)
{
	if (g_SDKCallCastSelfHeal)
		return SDKCall(g_SDKCallCastSelfHeal, player);
	else
		return false;
}

int SDKCall_FindCriterionIndex(int criteriaSet, const char[] criteria)
{
	if (g_SDKCallFindCriterionIndex)
		return SDKCall(g_SDKCallFindCriterionIndex, criteriaSet, criteria);
	else
		return -1;
}

void SDKCall_RemoveCriteria(int criteriaSet, const char[] criteria)
{
	if (g_SDKCallRemoveCriteria)
		SDKCall(g_SDKCallRemoveCriteria, criteriaSet, criteria);
}

void SDKCall_SetSwitchTeams(bool shouldSwitch)
{
	if (g_SDKCallSetSwitchTeams)
		SDKCall(g_SDKCallSetSwitchTeams, shouldSwitch);
}

int SDKCall_GetBaseEntity(Address address)
{
	if (g_SDKCallGetBaseEntity)
		return SDKCall(g_SDKCallGetBaseEntity, address);
	else
		return -1;
}

int SDKCall_GetDamageType(int entity)
{
	if (g_SDKCallGetDamageType)
		return SDKCall(g_SDKCallGetDamageType, entity);
	else
		return DMG_GENERIC;
}

void SDKCall_InitClass(int player)
{
	if (g_SDKCallInitClass)
		SDKCall(g_SDKCallInitClass, player);
}

float SDKCall_GetProjectileDamage(int weapon)
{
	if (g_SDKCallGetProjectileDamage)
		return SDKCall(g_SDKCallGetProjectileDamage, weapon);
	else
		return 0.0;
}

float SDKCall_GetMeleeDamage(int weapon, int target, int damageType, int customDamage)
{
	if (g_SDKCallGetMeleeDamage)
		return SDKCall(g_SDKCallGetMeleeDamage, weapon, target, damageType, customDamage);
	else
		return 0.0;
}

float SDKCall_JarGetDamage(int jar)
{
	if (g_SDKCallJarGetDamage)
		return SDKCall(g_SDKCallJarGetDamage, jar);
	else
		return 0.0;
}
