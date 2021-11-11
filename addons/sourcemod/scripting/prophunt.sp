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
#include <StaticProps>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"1.0.0"

#define LOCK_SOUND		"buttons/button3.wav"
#define UNLOCK_SOUND	"buttons/button24.wav"

const TFTeam TFTeam_Hunters = TFTeam_Blue;
const TFTeam TFTeam_Props = TFTeam_Red;

enum PHPropType
{
	Prop_None, 
	Prop_Static, 
	Prop_Entity, 
}

// ConVars
ConVar ph_prop_min_size;
ConVar ph_prop_max_size;
ConVar fw_prop_max_select_distance;

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
	
	RegAdminCmd("ph_debug", ConCmd_DebugBox, ADMFLAG_GENERIC);
	
	ConVars_Initialize();
	Events_Initialize();
	
	GameData gamedata = new GameData("prophunt");
	if (gamedata)
	{
		DHooks_Initialize(gamedata);
		SDKCalls_Initialize(gamedata);
		
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find prophunt gamedata");
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int buttonsChanged = GetEntProp(client, Prop_Data, "m_afButtonPressed") | GetEntProp(client, Prop_Data, "m_afButtonReleased");
	
	if (TF2_GetClientTeam(client) == TFTeam_Props)
	{
		if (buttons & IN_ATTACK && buttonsChanged & IN_ATTACK)
		{
			bool locked = PHPlayer(client).PropLockEnabled = !PHPlayer(client).PropLockEnabled;
			
			SetVariantInt(!locked);
			AcceptEntityInput(client, "SetCustomModelRotates");
			
			if (locked)
			{
				EmitSoundToClient(client, LOCK_SOUND, _, SNDCHAN_STATIC);
				PrintToChat(client, "%t", "PropLock Engaged");
			}
			else
			{
				EmitSoundToClient(client, UNLOCK_SOUND, _, SNDCHAN_STATIC);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action ConCmd_DebugBox(int client, int args)
{
	// Search for prop_* entities first
	int entity = GetClientAimTarget(client, false);
	if (entity != -1)
	{
		char classname[256];
		if (GetEntityClassname(entity, classname, sizeof(classname)) && strncmp(classname, "prop_", 5) == 0)
		{
			float mins[3], maxs[3];
			GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
			GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);
			
			if (IsValidBboxSize(mins, maxs))
			{
				PHPlayer(client).PropType = Prop_Entity;
				PHPlayer(client).PropIndex = EntIndexToEntRef(entity);
				
				char model[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
				SetPropModel(client, model);
			}
		}
	}
	
	float eyePosition[3], eyeAngles[3], eyeAngleFwd[3];
	GetClientEyePosition(client, eyePosition);
	GetClientEyeAngles(client, eyeAngles);
	GetAngleVectors(eyeAngles, eyeAngleFwd, NULL_VECTOR, NULL_VECTOR);
	
	// Get the position of the cloest wall to us
	float endPosition[3];
	TR_TraceRayFilter(eyePosition, eyeAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilter_IgnoreEntity, client);
	TR_GetEndPosition(endPosition);
	
	float distance = GetVectorDistance(eyePosition, endPosition);
	distance = Clamp(distance, 0.0, fw_prop_max_select_distance.FloatValue);
	
	// Search for static props next
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
		SetPropModel(client, name);
		
		// Exit out after we find a valid prop
		break;
	}
}

public bool TraceEntityFilter_IgnoreEntity(int entity, int mask, any data)
{
	return entity != data;
}

void SetPropModel(int client, const char[] model)
{
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	
	PrintToChat(client, "Picked Model %s", model);
	
	SetEntProp(client, Prop_Data, "m_bloodColor", 0); // DONT_BLEED
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
