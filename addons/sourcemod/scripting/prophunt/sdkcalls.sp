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

static Handle g_CTFSpellBook_CastSelfHeal;
static Handle g_AI_CriteriaSet_FindCriterionIndex;
static Handle g_AI_CriteriaSet_RemoveCriteria;
static Handle g_CTeamplayRules_SetSwitchTeams;
static Handle g_CBaseEntity_GetDamageType;
static Handle g_CBaseEntity_GetDamage;
static Handle g_CTFPlayer_InitClass;
static Handle g_CTFWeaponBaseGun_GetProjectileDamage;

void SDKCalls_Init(GameData gamedata)
{
	g_CTFSpellBook_CastSelfHeal = PrepSDKCall_CTFSpellBook_CastSelfHeal(gamedata);
	g_AI_CriteriaSet_FindCriterionIndex = PrepSDKCall_AI_CriteriaSet_FindCriterionIndex(gamedata);
	g_AI_CriteriaSet_RemoveCriteria = PrepSDKCall_AI_CriteriaSet_RemoveCriteria(gamedata);
	g_CTeamplayRules_SetSwitchTeams = PrepSDKCall_CTeamplayRules_SetSwitchTeams(gamedata);
	g_CBaseEntity_GetDamageType = PrepSDKCall_CBaseEntity_GetDamageType(gamedata);
	g_CBaseEntity_GetDamage = PrepSDKCall_CBaseEntity_GetDamage(gamedata);
	g_CTFPlayer_InitClass = PrepSDKCall_CTFPlayer_InitClass(gamedata);
	g_CTFWeaponBaseGun_GetProjectileDamage = PrepSDKCall_CTFWeaponBaseGun_GetProjectileDamage(gamedata);
}

static Handle PrepSDKCall_CTFSpellBook_CastSelfHeal(GameData gamedata)
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

static Handle PrepSDKCall_AI_CriteriaSet_FindCriterionIndex(GameData gamedata)
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

static Handle PrepSDKCall_AI_CriteriaSet_RemoveCriteria(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "AI_CriteriaSet::RemoveCriteria");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: AI_CriteriaSet::RemoveCriteria");
	
	return call;
}

static Handle PrepSDKCall_CTeamplayRules_SetSwitchTeams(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTeamplayRules::SetSwitchTeams");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTeamplayRules::SetSwitchTeams");
	
	return call;
}

static Handle PrepSDKCall_CBaseEntity_GetDamageType(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::GetDamageType");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CBaseEntity::GetDamageType");
	
	return call;
}

static Handle PrepSDKCall_CBaseEntity_GetDamage(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::GetDamage");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CBaseEntity::GetDamage");
	
	return call;
}

static Handle PrepSDKCall_CTFPlayer_InitClass(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFPlayer::InitClass");
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTFPlayer::InitClass");
	
	return call;
}

static Handle PrepSDKCall_CTFWeaponBaseGun_GetProjectileDamage(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFWeaponBaseGun::GetProjectileDamage");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTFWeaponBaseGun::GetProjectileDamage");
	
	return call;
}

bool SDKCall_CTFSpellBook_CastSelfHeal(int player)
{
	return g_CTFSpellBook_CastSelfHeal ? SDKCall(g_CTFSpellBook_CastSelfHeal, player) : false;
}

int SDKCall_AI_CriteriaSet_FindCriterionIndex(int criteriaSet, const char[] criteria)
{
	return g_AI_CriteriaSet_FindCriterionIndex ? SDKCall(g_AI_CriteriaSet_FindCriterionIndex, criteriaSet, criteria) : -1;
}

void SDKCall_AI_CriteriaSet_RemoveCriteria(int criteriaSet, const char[] criteria)
{
	if (g_AI_CriteriaSet_RemoveCriteria)
		SDKCall(g_AI_CriteriaSet_RemoveCriteria, criteriaSet, criteria);
}

void SDKCall_CTeamplayRules_SetSwitchTeams(bool shouldSwitch)
{
	if (g_CTeamplayRules_SetSwitchTeams)
		SDKCall(g_CTeamplayRules_SetSwitchTeams, shouldSwitch);
}

int SDKCall_CBaseEntity_GetDamageType(int entity)
{
	return g_CBaseEntity_GetDamageType ? SDKCall(g_CBaseEntity_GetDamageType, entity) : DMG_GENERIC;
}

float SDKCall_CBaseEntity_GetDamage(int entity)
{
	return g_CBaseEntity_GetDamage ? SDKCall(g_CBaseEntity_GetDamage, entity) : 0.0;
}

void SDKCall_CTFPlayer_InitClass(int player)
{
	if (g_CTFPlayer_InitClass)
		SDKCall(g_CTFPlayer_InitClass, player);
}

float SDKCall_CTFWeaponBaseGun_GetProjectileDamage(int weapon)
{
	return g_CTFWeaponBaseGun_GetProjectileDamage ? SDKCall(g_CTFWeaponBaseGun_GetProjectileDamage, weapon) : 0.0;
}
