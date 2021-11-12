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
#include <dhooks>
#include <sdkhooks>
#include <StaticProps>
#include <tf2items>
#include <tf2attributes>
#include <tf_econ_data>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"1.0.0"

#define DMG_MELEE	DMG_BLAST_SURFACE
#define DONT_BLEED	0

#define ITEM_DEFINDEX_GRAPPLINGHOOK			1152
#define ATTRIB_DEFINDEX_SEE_ENEMY_HEALTH	269

#define LOCK_SOUND		"buttons/button3.wav"
#define UNLOCK_SOUND	"buttons/button24.wav"

const TFTeam TFTeam_Hunters = TFTeam_Blue;
const TFTeam TFTeam_Props = TFTeam_Red;

enum PHPropType
{
	Prop_None,		/**< Invalid or no prop */
	Prop_Static,	/**< Static prop, index corresponds to position in static prop array */
	Prop_Entity,	/**< Entity-based prop, index corresponds to entity reference */
}

// Offsets
int g_OffsetWeaponMode;
int g_OffsetWeaponInfo;
int g_OffsetBulletsPerShot;

// ConVars
ConVar ph_prop_min_size;
ConVar ph_prop_max_size;
ConVar ph_prop_max_select_distance;
ConVar ph_hunter_damagemod_guns;
ConVar ph_hunter_damagemod_melee;
ConVar ph_hunter_damage_grapplinghook;

#include "prophunt/methodmaps.sp"

#include "prophunt/convars.sp"
#include "prophunt/dhooks.sp"
#include "prophunt/events.sp"
#include "prophunt/helpers.sp"
#include "prophunt/sdkcalls.sp"

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
	LoadTranslations("prophunt.phrases");
	
	PrecacheSound(LOCK_SOUND);
	PrecacheSound(UNLOCK_SOUND);
	
	ConVars_Initialize();
	Events_Initialize();
	
	GameData gamedata = new GameData("prophunt");
	if (gamedata)
	{
		DHooks_Initialize(gamedata);
		SDKCalls_Initialize(gamedata);
		
		g_OffsetWeaponMode = gamedata.GetOffset("CTFWeaponBase::m_iWeaponMode");
		g_OffsetWeaponInfo = gamedata.GetOffset("CTFWeaponBase::m_pWeaponInfo");
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

public void OnClientPutInServer(int client)
{
	QueryClientConVar(client, "r_staticpropinfo", ConVarQuery_StaticPropInfo);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int buttonsChanged = GetEntProp(client, Prop_Data, "m_afButtonPressed") | GetEntProp(client, Prop_Data, "m_afButtonReleased");
	
	// Prop-only functionality below this point
	if (!PHPlayer(client).IsProp())
		return Plugin_Continue;
	
	// IN_ATTACK locks the player's prop view
	if (buttons & IN_ATTACK && buttonsChanged & IN_ATTACK)
	{
		bool locked = PHPlayer(client).PropLockEnabled = !PHPlayer(client).PropLockEnabled;
		
		SetVariantInt(!locked);
		AcceptEntityInput(client, "SetCustomModelRotates");
		
		if (locked)
		{
			EmitSoundToClient(client, LOCK_SOUND, _, SNDCHAN_STATIC);
			PrintHintText(client, "%t", "PropLock Engaged");
		}
		else
		{
			EmitSoundToClient(client, UNLOCK_SOUND, _, SNDCHAN_STATIC);
		}
	}
	
	// IN_RELOAD allows the player to pick a prop
	if (buttons & IN_RELOAD && buttonsChanged & IN_RELOAD)
	{
		if (!SearchForEntityProps(client) && !SearchForStaticProps(client))
			PrintToChat(client, "%t", "No Valid Prop");
	}
	
	return Plugin_Continue;
}

public void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefIndex, int level, int quality, int entity)
{
	// CTFWeaponBaseGun
	if (IsWeaponBaseGun(entity))
		DHooks_HookBaseGun(entity);
	
	// CTFWeaponBaseMelee
	if (IsWeaponBaseMelee(entity))
		DHooks_HookBaseMelee(entity);
	
	// Nullify cheating attributes
	ArrayList attributes = TF2Econ_GetItemStaticAttributes(itemDefIndex);
	int index = attributes.FindValue(ATTRIB_DEFINDEX_SEE_ENEMY_HEALTH);
	if (index != -1)
		TF2Attrib_SetByDefIndex(entity, ATTRIB_DEFINDEX_SEE_ENEMY_HEALTH, 0.0);
	delete attributes;
}

bool SearchForEntityProps(int client)
{
	// For entities, we can simply go with whatever is under the player's crosshair
	int entity = GetClientAimTarget(client, false);
	if (entity == -1)
		return false;
	
	char classname[256];
	if (GetEntityClassname(entity, classname, sizeof(classname)) && HasEntProp(entity, Prop_Data, "m_ModelName"))
	{
		char model[PLATFORM_MAX_PATH];
		GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
		
		// Ignore brush entities
		if (model[0] == '*')
			return false;
		
		float mins[3], maxs[3];
		GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
		GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);
		
		if (!IsValidBboxSize(mins, maxs))
			return false;
		
		PHPlayer(client).PropType = Prop_Entity;
		PHPlayer(client).PropIndex = EntIndexToEntRef(entity);
		SetCustomModel(client, model);
		
		return true;
	}
	
	return false;
}

bool SearchForStaticProps(int client)
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
	distance = Clamp(distance, 0.0, ph_prop_max_select_distance.FloatValue);
	
	// Iterate all static props in the world
	int total = GetTotalNumberOfStaticProps();
	for (int i = 0; i < total; i++)
	{
		float mins[3], maxs[3];
		if (!StaticProp_GetWorldSpaceBounds(i, mins, maxs))
			continue;
		
		// Check whether the player is looking at this prop.
		// The engine completely ignores any non-solid props regardless of trace settings,
		// so we only use the engine trace to get the distance to the next wall and solve the intersection ourselves.
		if (!IntersectionLineAABBFast(mins, maxs, eyePosition, eyeAngleFwd, distance))
			continue;
		
		// Check the size of the prop
		if (!IsValidBboxSize(mins, maxs))
			continue;
		
		char name[PLATFORM_MAX_PATH];
		if (!StaticProp_GetModelName(i, name, sizeof(name)))
			continue;
		
		// Finally, set the player's prop
		PHPlayer(client).PropType = Prop_Static;
		PHPlayer(client).PropIndex = i;
		SetCustomModel(client, name);
		
		// Exit out after we find a valid prop
		return true;
	}
	
	// Exhausted all options...
	return false;
}

void SetCustomModel(int client, const char[] model)
{
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	
	PrintToChat(client, "%t", "Selected Prop", model);
	
	SetEntProp(client, Prop_Data, "m_bloodColor", DONT_BLEED);
}

public void ConVarQuery_StaticPropInfo(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (result == ConVarQuery_Okay)
	{
		int value = StringToInt(cvarValue);
		if (value == 0)
			return;
		
		KickClient(client, "%t", "r_staticpropinfo Enabled");
		return;
	}
	
	KickClient(client, "%t", "r_staticpropinfo Not Okay");
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
		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
		
		TF2_AddCondition(client, TFCond_AfterburnImmune);
	}
}
