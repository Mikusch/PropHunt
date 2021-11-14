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

#define DONT_BLEED	0

#define ITEM_DEFINDEX_GRAPPLINGHOOK			1152
#define ATTRIB_DEFINDEX_SEE_ENEMY_HEALTH	269

#define CONFIG_FILEPATH	"configs/prophunt/maps/%s"

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

// Globals
bool g_InSetup;
Handle g_ControlPointBonusTimer;

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
ConVar ph_hunter_damage_flamethrower;
ConVar ph_hunter_damage_grapplinghook;
ConVar ph_hunter_setup_freeze;
ConVar ph_bonus_refresh_time;
ConVar ph_open_doors_after_setup;
ConVar ph_setup_time;
ConVar ph_round_time;
ConVar ph_relay_name;

#include "prophunt/methodmaps.sp"
#include "prophunt/structs.sp"

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
	
	ConVars_Initialize();
	Events_Initialize();
	
	RegAdminCmd("ph_setprop", ConCmd_SetCustomModel, ADMFLAG_CHEATS);
	
	AddCommandListener(CommandListener_Build, "build");
	
	g_PropConfigs = new StringMap();
	
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
				g_PropConfigs.SetArray(config.model, config, sizeof(config));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	delete kv;
	
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

public void OnPluginEnd()
{
	ConVars_ToggleAll(false);
}

public void OnMapStart()
{
	PrecacheSound(LOCK_SOUND);
	PrecacheSound(UNLOCK_SOUND);
	
	ConVars_ToggleAll(true);
	
	g_CurrentMapConfig.hunter_setup_freeze = ph_hunter_setup_freeze.BoolValue;
	g_CurrentMapConfig.open_doors_after_setup = ph_open_doors_after_setup.BoolValue;
	g_CurrentMapConfig.setup_time = ph_setup_time.IntValue;
	g_CurrentMapConfig.round_time = ph_round_time.IntValue;
	ph_relay_name.GetString(g_CurrentMapConfig.relay_name, sizeof(g_CurrentMapConfig.relay_name));
	
	char filepath[PLATFORM_MAX_PATH];
	if (GetMapConfigFilepath(filepath, sizeof(filepath)))
	{
		KeyValues kv = new KeyValues("PropHunt");
		
		if (kv.ImportFromFile(filepath))
			g_CurrentMapConfig.ReadFromKv(kv);
		
		delete kv;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "tf_logic_arena") == 0)
	{
		// Prevent arena from trying to enable the control point
		DispatchKeyValue(entity, "CapEnableDelay", "0");
	}
	else if (strcmp(classname, "trigger_capture_area") == 0)
	{
		SDKHook(entity, SDKHook_StartTouch, OnTriggerCaptureAreaStartTouch);
	}
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if (GameRules_GetRoundState() != RoundState_Stalemate || g_InSetup)
		return Plugin_Continue;
	
	// Flame throwers are a special case, as always
	if (strcmp(weaponname, "tf_weapon_flamethrower") == 0)
	{
		SDKHooks_TakeDamage(client, weapon, client, ph_hunter_damage_flamethrower.FloatValue, DMG_PREVENT_PHYSICS_FORCE, weapon);
	}
	
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	PHPlayer(client).Reset();
	
	DHooks_HookClient(client);
	
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
		PrintHintText(client, "%t", "PropLock Engaged");
	}
	else
	{
		EmitSoundToClient(client, UNLOCK_SOUND, _, SNDCHAN_STATIC);
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int buttonsChanged = GetEntProp(client, Prop_Data, "m_afButtonPressed") | GetEntProp(client, Prop_Data, "m_afButtonReleased");
	
	// Prop-only functionality below this point
	if (!PHPlayer(client).IsProp() || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	// TODO: Only allow unlocking by moving after the player has fully released their movement keys
	static float latestUnlockTime[MAXPLAYERS + 1];
	
	// IN_ATTACK locks the player's prop view
	if (buttons & IN_ATTACK && buttonsChanged & IN_ATTACK)
	{
		bool locked = PHPlayer(client).PropLockEnabled = !PHPlayer(client).PropLockEnabled;
		TogglePropLock(client, locked);
		
		
		latestUnlockTime[client] = GetGameTime() + 1.0;
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
		if (!SearchForEntityProps(client) && !SearchForStaticProps(client))
			PrintToChat(client, "%t", "No Valid Prop");
	}
	
	// Prevent the player from auto-unlocking themselves with movement keys for one second
	if (PHPlayer(client).InForcedTauntCam && latestUnlockTime[client] > GetGameTime())
	{
		buttons &= ~IN_FORWARD;
		buttons &= ~IN_BACK;
		buttons &= ~IN_MOVELEFT;
		buttons &= ~IN_MOVERIGHT;
		
		return Plugin_Changed;
	}
	
	// Movement keys will undo a prop lock
	if (buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
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
	// Make sure that props stay naked
	if (PHPlayer(client).IsProp())
		return Plugin_Handled;
	
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
	
	// Nullify cheating attributes
	ArrayList attributes = TF2Econ_GetItemStaticAttributes(itemDefIndex);
	if (attributes)
	{
		int index = attributes.FindValue(ATTRIB_DEFINDEX_SEE_ENEMY_HEALTH);
		if (index != -1)
			TF2Attrib_SetByDefIndex(entity, ATTRIB_DEFINDEX_SEE_ENEMY_HEALTH, 0.0);
	}
	delete attributes;
	
	// Significantly reduce Medic's healing
	if (strcmp(classname, "tf_weapon_medigun") == 0)
	{
		TF2Attrib_SetByName(entity, "heal rate penalty", 0.1);
	}
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
		
		if (IsPropBlacklisted(model))
			return false;
		
		if (!g_CurrentMapConfig.IsWhitelisted(model) && g_CurrentMapConfig.IsBlacklisted(model))
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
		
		if (IsPropBlacklisted(name))
			return false;
		
		if (!g_CurrentMapConfig.IsWhitelisted(name) && g_CurrentMapConfig.IsBlacklisted(name))
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
	
	PropConfig config;
	if (g_PropConfigs.GetArray(model, config, sizeof(config)))
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
		AcceptEntityInput(client, "ClearCustomModelRotation");
		
		SetVariantVector3D(view_as<float>( { 0.0, 0.0, 0.0 } ));
		AcceptEntityInput(client, "SetCustomModelOffset");
	}
	
	SetEntProp(client, Prop_Data, "m_bloodColor", DONT_BLEED);
	
	PrintToChat(client, "%t", "Selected Prop", model);
	
	LogMessage("[PROP HUNT] %N chose prop \"%s\"", client, model);
}

void ClearCustomModel(int client)
{
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
	
	SetVariantVector3D(view_as<float>( { 0.0, 0.0, 0.0 } ));
	AcceptEntityInput(client, "SetCustomModelOffset");
	
	AcceptEntityInput(client, "ClearCustomModelRotation");
	
	SetVariantInt(1);
	AcceptEntityInput(client, "SetCustomModelRotates");
	
	SetVariantInt(1);
	AcceptEntityInput(client, "SetCustomModelVisibletoSelf");
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
		SetVariantInt(PHPlayer(client).InForcedTauntCam);
		AcceptEntityInput(client, "SetForcedTauntCam");
	}
	
	return Plugin_Continue;
}

public Action OnSetupTimerFinished(const char[] output, int caller, int activator, float delay)
{
	g_InSetup = false;
	
	// Setup control point bonus
	g_ControlPointBonusTimer = CreateTimer(ph_bonus_refresh_time.FloatValue, Timer_RefreshControlPointBonus, _, TIMER_REPEAT);
	TriggerTimer(g_ControlPointBonusTimer);
	
	// Refresh speed of all clients to allow hunters to move
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
	}
	
	// Trigger named relays
	if (g_CurrentMapConfig.relay_name[0] != '\0')
	{
		int relay = MaxClients + 1;
		while ((relay = FindEntityByClassname(relay, "logic_relay")) != -1)
		{
			char name[64];
			GetEntPropString(relay, Prop_Data, "m_iName", name, sizeof(name));
			
			if (strcmp(name, g_CurrentMapConfig.relay_name) == 0)
				AcceptEntityInput(relay, "Trigger");
		}
	}
	
	// Open all doors in the map
	if (g_CurrentMapConfig.open_doors_after_setup)
	{
		int door = MaxClients + 1;
		while ((door = FindEntityByClassname(door, "func_door")) != -1)
		{
			AcceptEntityInput(door, "Open");
		}
	}
	
	return Plugin_Continue;
}

public Action OnRoundTimerFinished(const char[] output, int caller, int activator, float delay)
{
	SetWinningTeam(TFTeam_Props);
}

public Action OnTriggerCaptureAreaStartTouch(int trigger, int other)
{
	// Players touching the capture area receive a health bonus
	if (IsEntityClient(other) && !PHPlayer(other).HasReceivedBonus)
	{
		CastSelfHeal(other);
		EmitGameSoundToAll("Halloween.spell_overheal", other);
		PrintToChat(other, "%t", "Control Point Bonus Received");
		
		PHPlayer(other).HasReceivedBonus = true;
	}
	
	// Do not allow capturing
	return Plugin_Handled;
}

public Action CommandListener_Build(int client, const char[] command, int argc)
{
	if (TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		char arg[16];
		if (argc > 0 && GetCmdArg(1, arg, sizeof(arg)) > 0)
		{
			//Prevent Engineers from building sentry guns
			TFObjectType type = view_as<TFObjectType>(StringToInt(arg));
			if (type == TFObject_Sentry)
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action ConCmd_SetCustomModel(int client, int args)
{
	if (args < 1)
		return Plugin_Handled;
	
	char model[PLATFORM_MAX_PATH];
	GetCmdArg(1, model, sizeof(model));
	
	SetCustomModel(client, model);
	
	return Plugin_Handled;
}

public Action Timer_RefreshControlPointBonus(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		PHPlayer(client).HasReceivedBonus = false;
	}
	
	PrintToChatAll("Control Point Bonus Refreshed");
	
	return Plugin_Continue;
}
