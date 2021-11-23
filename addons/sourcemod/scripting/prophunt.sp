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

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <sdkhooks>
#include <regex>
#include <morecolors>
#include <dhooks>
#include <StaticProps>
#include <tf2attributes>
#include <tf2items>
#include <tf_econ_data>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"1.0.0"

#define PLUGIN_TAG	"[{orange}PropHunt{default}]"

#define DONT_BLEED	0

#define ITEM_DEFINDEX_GRAPPLINGHOOK			1152
#define ATTRIB_DEFINDEX_SEE_ENEMY_HEALTH	269

#define ZERO_VECTOR	view_as<float>( { 0.0, 0.0, 0.0 } )
#define DOWN_VECTOR	view_as<float>( { 90.0, 0.0, 0.0 } )

#define MAP_CONFIG_FILEPATH		"configs/prophunt/maps/%s"
#define PROP_CONFIG_FILEPATH	"configs/prophunt/props.cfg"

#define SOUND_LAST_PROP	"prophunt/oneandonly_hq.mp3"
#define LOCK_SOUND		"buttons/button3.wav"
#define UNLOCK_SOUND	"buttons/button24.wav"

const TFTeam TFTeam_Props = TFTeam_Red;
const TFTeam TFTeam_Hunters = TFTeam_Blue;

enum PHPropType
{
	Prop_None,		/**< Invalid or no prop */
	Prop_Static,	/**< Static prop, index corresponds to position in static prop array */
	Prop_Entity,	/**< Entity-based prop, index corresponds to entity reference */
}

// Globals
bool g_DisallowPropLocking;
Handle g_ControlPointBonusTimer;

// Offsets
int g_OffsetWeaponMode;
int g_OffsetWeaponInfo;
int g_OffsetPlayerSharedOuter;
int g_OffsetBulletsPerShot;

// ConVars
ConVar ph_prop_min_size;
ConVar ph_prop_max_size;
ConVar ph_prop_select_distance;
ConVar ph_prop_max_health;
ConVar ph_hunter_damage_modifier_gun;
ConVar ph_hunter_damage_modifier_melee;
ConVar ph_hunter_damage_modifier_grapplinghook;
ConVar ph_hunter_damage_flamethrower;
ConVar ph_hunter_setup_freeze;
ConVar ph_regenerate_last_prop;
ConVar ph_bonus_refresh_time;
ConVar ph_healing_modifier;
ConVar ph_open_doors_after_setup;
ConVar ph_setup_truce;
ConVar ph_setup_time;
ConVar ph_round_time;
ConVar ph_relay_name;

#include "prophunt/methodmaps.sp"
#include "prophunt/structs.sp"

#include "prophunt/console.sp"
#include "prophunt/convars.sp"
#include "prophunt/dhooks.sp"
#include "prophunt/events.sp"
#include "prophunt/helpers.sp"
#include "prophunt/sdkcalls.sp"
#include "prophunt/sdkhooks.sp"

public Plugin myinfo = 
{
	name = "PropHunt Neu", 
	author = "Mikusch", 
	description = "A modern PropHunt plugin for Team Fortress 2", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/Mikusch/PropHunt"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("prophunt.phrases");
	
	AddFileToDownloadsTable("sound/" ... SOUND_LAST_PROP);
	
	Console_Initialize();
	ConVars_Initialize();
	Events_Initialize();
	
	g_PropConfigs = new ArrayList(sizeof(PropConfig));
	
	// Read global prop config
	char file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof(file), "configs/prophunt/props.cfg");
	
	KeyValues kv = new KeyValues("Props");
	if (kv.ImportFromFile(file))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				PropConfig config;
				config.ReadFromKv(kv);
				g_PropConfigs.PushArray(config);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	delete kv;
	
	// Set up everything that needs gamedata
	GameData gamedata = new GameData("prophunt");
	if (gamedata)
	{
		DHooks_Initialize(gamedata);
		SDKCalls_Initialize(gamedata);
		
		g_OffsetWeaponMode = gamedata.GetOffset("CTFWeaponBase::m_iWeaponMode");
		g_OffsetWeaponInfo = gamedata.GetOffset("CTFWeaponBase::m_pWeaponInfo");
		g_OffsetPlayerSharedOuter = gamedata.GetOffset("CTFPlayerShared::m_pOuter");
		g_OffsetBulletsPerShot = gamedata.GetOffset("WeaponData_t::m_nBulletsPerShot");
		
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find prophunt gamedata");
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			OnClientPutInServer(client);
	}
}

public void OnPluginEnd()
{
	ConVars_ToggleAll(false);
}

public void OnMapStart()
{
	PrecacheSound("#" ... SOUND_LAST_PROP);
	PrecacheSound(LOCK_SOUND);
	PrecacheSound(UNLOCK_SOUND);
	
	ConVars_ToggleAll(true);
	
	// Read map config
	char file[PLATFORM_MAX_PATH];
	if (GetMapConfigFilepath(file, sizeof(file)))
	{
		KeyValues kv = new KeyValues("PropHunt");
		if (kv.ImportFromFile(file))
		{
			g_CurrentMapConfig.ReadFromKv(kv);
		}
		delete kv;
	}
}

public void OnConfigsExecuted()
{
	FindConVar("tf_arena_preround_time").FloatValue = ph_setup_time.FloatValue;
}

public void OnMapEnd()
{
	g_CurrentMapConfig.Clear();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	SDKHooks_OnEntityCreated(entity, classname);
	
	if (strcmp(classname, "tf_logic_arena") == 0)
	{
		// Prevent arena from trying to enable the control point
		DispatchKeyValue(entity, "CapEnableDelay", "0");
	}
	else if (strcmp(classname, "trigger_capture_area") == 0)
	{
		RemoveEntity(entity);
	}
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if (GameRules_GetRoundState() != RoundState_Stalemate)
		return Plugin_Continue;
	
	// Flame throwers are a special case, as always
	if (strcmp(weaponname, "tf_weapon_flamethrower") == 0)
	{
		float damage = ph_hunter_damage_flamethrower.FloatValue;
		int damageType = SDKCall_GetDamageType(weapon) | DMG_PREVENT_PHYSICS_FORCE;
		
		SDKHooks_TakeDamage(client, weapon, client, damage, damageType, weapon);
	}
	
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	PHPlayer(client).Reset();
	
	DHooks_HookClient(client);
	SDKHooks_HookClient(client);
	
	// Fixes arena HUD messing up
	if (!IsFakeClient(client))
		FindConVar("tf_arena_round_time").ReplicateToClient(client, "1");
}

void TogglePropLock(int client, bool toggle)
{
	SetVariantInt(!toggle);
	AcceptEntityInput(client, "SetCustomModelRotates");
	
	if (toggle)
	{
		EmitSoundToClient(client, LOCK_SOUND, _, SNDCHAN_STATIC);
		SetEntityMoveType(client, MOVETYPE_NONE);
		PrintHintText(client, "%t", "PH_PropLock_Enabled");
	}
	else
	{
		EmitSoundToClient(client, UNLOCK_SOUND, _, SNDCHAN_STATIC);
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	// Prop-only functionality below this point
	if (!IsPlayerProp(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	int buttonsChanged = GetEntProp(client, Prop_Data, "m_afButtonPressed") | GetEntProp(client, Prop_Data, "m_afButtonReleased");
	
	// IN_ATTACK locks the player's prop view
	if (buttons & IN_ATTACK && buttonsChanged & IN_ATTACK)
	{
		if (GameRules_GetRoundState() != RoundState_Preround)
		{
			if (GetPlayerWeaponSlot(client, 0) == -1)
			{
				// Check if the player is currently above a trigger_hurt
				float origin[3];
				GetClientAbsOrigin(client, origin);
				TR_EnumerateEntities(origin, DOWN_VECTOR, PARTITION_TRIGGER_EDICTS, RayType_Infinite, TraceEntityEnumerator_EnumerateTriggers, client);
				
				// Don't allow them to lock to avoid props hovering above deadly areas
				if (!g_DisallowPropLocking)
				{
					bool locked = PHPlayer(client).PropLockEnabled = !PHPlayer(client).PropLockEnabled;
					TogglePropLock(client, locked);
				}
				else
				{
					PrintHintText(client, "%t", "PH_PropLock_Unavailable");
					g_DisallowPropLocking = false;
				}
			}
		}
	}
	
	// IN_ATTACK2 switches betweeen first-person and third-person view
	if (buttons & IN_ATTACK2 && buttonsChanged & IN_ATTACK2)
	{
		bool value = PHPlayer(client).InForcedTauntCam = !PHPlayer(client).InForcedTauntCam;
		
		SetVariantInt(value);
		AcceptEntityInput(client, "SetForcedTauntCam");
		
		SetVariantInt(value);
		AcceptEntityInput(client, "SetCustomModelVisibletoSelf");
	}
	
	// IN_RELOAD allows the player to pick a prop
	if (buttons & IN_RELOAD && buttonsChanged & IN_RELOAD)
	{
		if (CanPlayerPropChange(client))
		{
			char message[256];
			if (!SearchForProps(client, message, sizeof(message)))
				CPrintToChat(client, message);
		}
		else
		{
			CPrintToChat(client, "%s %t", PLUGIN_TAG, "PH_PropSelect_NotAllowed");
		}
	}
	
	// Pressing movement keys will undo a prop lock
	if ((buttons & IN_FORWARD && buttonsChanged & IN_FORWARD) ||
		(buttons & IN_BACK && buttonsChanged & IN_BACK) ||
		(buttons & IN_MOVELEFT && buttonsChanged & IN_MOVELEFT) ||
		(buttons & IN_MOVERIGHT && buttonsChanged & IN_MOVERIGHT) ||
		(buttons & IN_JUMP && buttonsChanged & IN_JUMP) ||
		(buttons & IN_DUCK && buttonsChanged & IN_DUCK))
	{
		if (PHPlayer(client).PropLockEnabled)
		{
			PHPlayer(client).PropLockEnabled = false;
			TogglePropLock(client, false);
		}
	}
	
	return Plugin_Continue;
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int itemDefIndex, Handle &item)
{
	if (IsPlayerProp(client))
	{
		// Make sure that all props except the last stay naked
		if (!PHPlayer(client).IsLastProp)
			return Plugin_Handled;
		
		// Remove all wearables too
		if (strncmp(classname, "tf_wearable", 11) == 0)
			return Plugin_Handled;
		
		// Lastly, remove power up canteens and spellbooks
		if (strcmp(classname, "tf_powerup_bottle") == 0 || strcmp(classname, "tf_weapon_spellbook") == 0)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefIndex, int level, int quality, int entity)
{
	// Is CTFWeaponBaseGun?
	if (IsWeaponBaseGun(entity))
		DHooks_HookBaseGun(entity);
	
	// Is CTFWeaponBaseMelee?
	if (IsWeaponBaseMelee(entity))
		DHooks_HookBaseMelee(entity);
	
	// Hide the last prop's items
	if (PHPlayer(client).IsLastProp)
		SetItemAlpha(entity, 0);
	
	// Nullify cheating attributes
	if (IsPlayerHunter(client))
	{
		ArrayList attributes = TF2Econ_GetItemStaticAttributes(itemDefIndex);
		if (attributes)
		{
			int index = attributes.FindValue(ATTRIB_DEFINDEX_SEE_ENEMY_HEALTH);
			if (index != -1)
				TF2Attrib_SetByDefIndex(entity, ATTRIB_DEFINDEX_SEE_ENEMY_HEALTH, 0.0);
		}
		delete attributes;
	}
}

bool SearchForProps(int client, char[] message, int maxlength)
{
	return SearchForEntityProps(client, message, maxlength) || SearchForStaticProps(client, message, maxlength);
}

bool SearchForEntityProps(int client, char[] message, int maxlength)
{
	// For entities, we can go with whatever is under the player's crosshair
	int entity = GetClientAimTarget(client, false);
	if (entity == -1)
		return false;
	
	float origin1[3], origin2[3];
	GetClientAbsOrigin(client, origin1);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin2);
	
	// Check whether the player is close enough
	if (GetVectorDistance(origin1, origin2) > ph_prop_select_distance.FloatValue)
		return false;
	
	if (!HasEntProp(entity, Prop_Data, "m_ModelName"))
		return false;
	
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
	
	if (!DoModelNameChecks(client, model, message, maxlength))
		return false;
	
	float mins[3], maxs[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);
	
	if (!DoModelSizeChecks(client, model, mins, maxs, message, maxlength))
		return false;
	
	// Set the player's prop
	PHPlayer(client).PropType = Prop_Entity;
	PHPlayer(client).PropIndex = EntIndexToEntRef(entity);
	SetCustomModel(client, model);
	
	// Copy skin of selected model
	SetEntProp(client, Prop_Send, "m_bForcedSkin", true);
	SetEntProp(client, Prop_Send, "m_nForcedSkin", GetEntitySkin(entity));
	
	// Refill health during setup time
	if (GameRules_GetRoundState() == RoundState_Preround)
		SetEntityHealth(client, GetHealthForBbox(mins, maxs));
	
	return true;
}

bool SearchForStaticProps(int client, char[] message, int maxlength)
{
	float eyePosition[3], eyeAngles[3], eyeAngleFwd[3];
	GetClientEyePosition(client, eyePosition);
	GetClientEyeAngles(client, eyeAngles);
	GetAngleVectors(eyeAngles, eyeAngleFwd, NULL_VECTOR, NULL_VECTOR);
	
	// Get the position of the cloest wall to us
	float endPosition[3];
	TR_TraceRayFilter(eyePosition, eyeAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilter_IgnoreEntity, client);
	TR_GetEndPosition(endPosition);
	
	float distance = GetVectorDistance(eyePosition, endPosition);
	distance = Clamp(distance, 0.0, ph_prop_select_distance.FloatValue);
	
	// Iterate all static props in the world
	int total = GetTotalNumberOfStaticProps();
	for (int i = 0; i < total; i++)
	{
		float aabbMins[3], aabbMaxs[3];
		if (!StaticProp_GetWorldSpaceBounds(i, aabbMins, aabbMaxs))
			continue;
		
		// The engine completely ignores any non-solid props regardless of trace settings, so we only
		// use the engine trace to get the distance to the next wall and solve the intersection ourselves.
		if (!IntersectionLineAABBFast(aabbMins, aabbMaxs, eyePosition, eyeAngleFwd, distance))
			continue;
		
		char name[PLATFORM_MAX_PATH];
		if (!StaticProp_GetModelName(i, name, sizeof(name)))
			continue;
		
		if (!DoModelNameChecks(client, name, message, maxlength))
			continue;
		
		float obbMins[3], obbMaxs[3];
		if (!StaticProp_GetOBBBounds(i, obbMins, obbMaxs))
			continue;
		
		if (!DoModelSizeChecks(client, name, obbMins, obbMaxs, message, maxlength))
			continue;
		
		// Set the player's prop
		PHPlayer(client).PropType = Prop_Static;
		PHPlayer(client).PropIndex = i;
		SetCustomModel(client, name);
		
		// Refill health during setup time
		if (GameRules_GetRoundState() == RoundState_Preround)
			SetEntityHealth(client, GetHealthForBbox(obbMins, obbMaxs));
		
		// Exit out after we find a valid prop
		return true;
	}
	
	// We have not found a prop at this point
	return false;
}

bool DoModelNameChecks(int client, const char[] model, char[] message, int maxlength)
{
	// Ignore brush entities
	if (model[0] == '*')
		return false;
	
	// Ignore the model if the player is already disguised as it
	char customModel[PLATFORM_MAX_PATH];
	if (GetEntPropString(client, Prop_Send, "m_iszCustomModel", customModel, sizeof(customModel)) > 0 && strcmp(customModel, model) == 0)
		return false;
	
	// Ignore the model if this is the player's actual playermodel
	if (GetEntProp(client, Prop_Data, "m_nModelIndex") == PrecacheModel(model))
		return false;
	
	// Is this prop blacklisted?
	if (IsPropBlacklisted(model) || (!g_CurrentMapConfig.IsWhitelisted(model) && g_CurrentMapConfig.IsBlacklisted(model)))
	{
		char modelTidyName[PLATFORM_MAX_PATH];
		GetModelTidyName(model, modelTidyName, sizeof(modelTidyName));
		
		Format(message, maxlength, "%s %T", PLUGIN_TAG, "PH_PropSelect_CannotDisguise", client, modelTidyName, "PH_PropSelect_Blacklisted", client);
		return false;
	}
	
	return true;
}

bool DoModelSizeChecks(int client, const char[] model, const float mins[3], const float maxs[3], char[] message, int maxlength)
{
	float size = GetVectorDistance(mins, maxs);
	
	char modelTidyName[PLATFORM_MAX_PATH];
	GetModelTidyName(model, modelTidyName, sizeof(modelTidyName));
	
	// Is the prop too small?
	if (size < ph_prop_min_size.FloatValue)
	{
		Format(message, maxlength, "%s %T", PLUGIN_TAG, "PH_PropSelect_CannotDisguise", client, modelTidyName, "PH_PropSelect_TooSmall", client);
		return false;
	}
	
	// Is the prop too big?
	if (size > ph_prop_max_size.FloatValue)
	{
		Format(message, maxlength, "%s %T", PLUGIN_TAG, "PH_PropSelect_CannotDisguise", client, modelTidyName, "PH_PropSelect_TooBig", client);
		return false;
	}
	
	return true;
}

void SetCustomModel(int client, const char[] model)
{
	// Reset everything first
	ClearCustomModel(client);
	
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	
	PropConfig config;
	if (GetConfigByModel(model, config))
	{
		SetVariantVector3D(config.offset);
		AcceptEntityInput(client, "SetCustomModelOffset");
		
		if (GetVectorLength(config.rotation, true) == 0.0)
		{
			AcceptEntityInput(client, "ClearCustomModelRotation");
		}
		else
		{
			SetVariantVector3D(config.rotation);
			AcceptEntityInput(client, "SetCustomModelRotation");
		}
	}
	else
	{
		SetVariantVector3D(ZERO_VECTOR);
		AcceptEntityInput(client, "SetCustomModelOffset");
		
		AcceptEntityInput(client, "ClearCustomModelRotation");
	}
	
	SetEntProp(client, Prop_Data, "m_bloodColor", DONT_BLEED);
	
	char modelTidyName[PLATFORM_MAX_PATH];
	GetModelTidyName(model, modelTidyName, sizeof(modelTidyName));
	
	CPrintToChat(client, "%s %t", PLUGIN_TAG, "PH_PropSelect_Success", modelTidyName);
}

void ClearCustomModel(int client)
{
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
	
	SetVariantVector3D(ZERO_VECTOR);
	AcceptEntityInput(client, "SetCustomModelOffset");
	
	AcceptEntityInput(client, "ClearCustomModelRotation");
	
	SetVariantInt(1);
	AcceptEntityInput(client, "SetCustomModelRotates");
	
	SetVariantInt(1);
	AcceptEntityInput(client, "SetCustomModelVisibletoSelf");
	
	SetEntProp(client, Prop_Send, "m_bForcedSkin", false);
	SetEntProp(client, Prop_Send, "m_nForcedSkin", 0);
	
	SetVariantString("ParticleEffectStop");
	AcceptEntityInput(client, "DispatchEffect");
}

public void ConVarQuery_StaticPropInfo(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (result == ConVarQuery_Okay)
	{
		int value = StringToInt(cvarValue);
		if (value == 0)
			return;
		
		KickClient(client, "%t", "PH_ConVarQuery_DisallowedValue", cvarName, cvarValue);
		return;
	}
	
	KickClient(client, "%t", "PH_ConVarQuery_QueryNotOkay", cvarName);
}

public Action EntityOutput_OnFinished(const char[] output, int caller, int activator, float delay)
{
	SetWinningTeam(TFTeam_Props);
	
	return Plugin_Continue;
}

public bool TraceEntityEnumerator_EnumerateTriggers(int entity, int client)
{
	char classname[16];
	if (GetEntityClassname(entity, classname, sizeof(classname)) && strcmp(classname, "trigger_hurt") == 0)
	{
		if (!GetEntProp(entity, Prop_Data, "m_bDisabled"))
		{
			Handle trace = TR_ClipCurrentRayToEntityEx(MASK_PLAYERSOLID, entity);
			bool didHit = TR_DidHit(trace);
			
			float endPos[3];
			TR_GetEndPosition(endPos, trace);
			
			delete trace;
			
			if (didHit)
			{
				float origin[3];
				GetClientAbsOrigin(client, origin);
				
				// If it hit, do a second trace to determine whether the player is directly above the trigger
				trace = TR_TraceRayFilterEx(origin, endPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceEntityFilter_IgnoreEntity, client);
				if (TR_DidHit(trace))
					didHit = false;
				delete trace;
			}
			
			g_DisallowPropLocking = didHit;
			return !didHit;
		}
	}
	
	return true;
}

public bool TraceEntityFilter_IgnoreEntity(int entity, int mask, any data)
{
	return entity != data;
}

public Action Timer_SetForcedTauntCam(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client != 0)
	{
		SetVariantInt(PHPlayer(client).InForcedTauntCam);
		AcceptEntityInput(client, "SetForcedTauntCam");
	}
	
	return Plugin_Continue;
}

public Action Timer_RefreshControlPointBonus(Handle timer)
{
	if (timer != g_ControlPointBonusTimer)
		return Plugin_Stop;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		PHPlayer(client).HasReceivedBonus = false;
	}
	
	CPrintToChatAll("%s %t", PLUGIN_TAG, "PH_Bonus_Refreshed");
	
	return Plugin_Continue;
}
