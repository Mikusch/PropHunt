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

void Console_Initialize()
{
	RegAdminCmd("sm_getmodel", ConCmd_GetModel, ADMFLAG_CHEATS);
	RegAdminCmd("sm_setmodel", ConCmd_SetModel, ADMFLAG_CHEATS);
	RegAdminCmd("sm_reloadconfigs", ConCmd_ReloadConfigs, ADMFLAG_CONFIG);
}

void Console_Toggle(bool enable)
{
	if (enable)
	{
		AddMultiTargetFilter("@prop", MultiTargetFilter_FilterProps, "PH_Target_Props", true);
		AddMultiTargetFilter("@props", MultiTargetFilter_FilterProps, "PH_Target_Props", true);
		AddMultiTargetFilter("@hunters", MultiTargetFilter_FilterHunters, "PH_Target_Hunters", true);
		AddMultiTargetFilter("@hunter", MultiTargetFilter_FilterHunters, "PH_Target_Hunters", true);
		
		AddCommandListener(CommandListener_Build, "build");
	}
	else
	{
		RemoveMultiTargetFilter("@prop", MultiTargetFilter_FilterProps);
		RemoveMultiTargetFilter("@props", MultiTargetFilter_FilterProps);
		RemoveMultiTargetFilter("@hunters", MultiTargetFilter_FilterHunters);
		RemoveMultiTargetFilter("@hunter", MultiTargetFilter_FilterHunters);
		
		RemoveCommandListener(CommandListener_Build, "build");
	}
}

public bool MultiTargetFilter_FilterProps(const char[] pattern, ArrayList clients)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Props)
			clients.Push(client);
	}
	
	return clients.Length > 0;
}

public bool MultiTargetFilter_FilterHunters(const char[] pattern, ArrayList clients)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Hunters)
			clients.Push(client);
	}
	
	return clients.Length > 0;
}

public Action ConCmd_GetModel(int client, int args)
{
	if (!g_IsEnabled)
		return Plugin_Continue;
	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_getmodel <#userid|name>");
		return Plugin_Handled;
	}
	
	char target[MAX_TARGET_LENGTH];
	GetCmdArg(1, target, sizeof(target));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(target, client, target_list, MaxClients + 1, COMMAND_TARGET_NONE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	bool replied;
	
	for (int i = 0; i < target_count; i++)
	{
		char model[PLATFORM_MAX_PATH];
		if (GetEntPropString(target_list[i], Prop_Send, "m_iszCustomModel", model, sizeof(model)) > 0)
		{
			CReplyToCommand(client, "%s %t", PLUGIN_TAG, "PH_Command_GetModel_Success", target_list[i], model);
			replied = true;
		}
	}
	
	if (!replied)
	{
		CReplyToCommand(client, "%s %t", PLUGIN_TAG, "PH_Command_GetModel_NoModelSet");
	}
	
	return Plugin_Handled;
}

public Action ConCmd_SetModel(int client, int args)
{
	if (!g_IsEnabled)
		return Plugin_Continue;
	
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setmodel <#userid|name> <model>");
		return Plugin_Handled;
	}
	
	char target[MAX_TARGET_LENGTH], model[PLATFORM_MAX_PATH];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, model, sizeof(model));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(target, client, target_list, MaxClients + 1, COMMAND_TARGET_NONE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		if (model[0] != EOS)
			SetCustomModel(target_list[i], model, Prop_None, -1);
		else
			ClearCustomModel(target_list[i], true);
	}
	
	char modelTidyName[PLATFORM_MAX_PATH];
	GetModelTidyName(model, modelTidyName, sizeof(modelTidyName));
	
	if (tn_is_ml)
	{
		CShowActivity2(client, "{default}" ... PLUGIN_TAG ... " ", "%t", "PH_Command_SetModel_Success", modelTidyName, target_name);
	}
	else
	{
		CShowActivity2(client, "{default}" ... PLUGIN_TAG ... " ", "%t", "PH_Command_SetModel_Success", modelTidyName, "_s", target_name);
	}
	
	return Plugin_Handled;
}

public Action ConCmd_ReloadConfigs(int client, int args)
{
	if (!g_IsEnabled)
		return Plugin_Continue;
	
	ReadPropConfig();
	ReadMapConfig();
	
	CReplyToCommand(client, "%s %t", PLUGIN_TAG, "PH_Command_ReloadConfig_Success");
	
	return Plugin_Handled;
}

public Action CommandListener_Build(int client, const char[] command, int argc)
{
	if (argc < 1)
		return Plugin_Continue;
	
	if (TF2_GetPlayerClass(client) != TFClass_Engineer)
		return Plugin_Continue;
	
	char arg[8];
	GetCmdArg(1, arg, sizeof(arg));
	
	TFObjectType type = view_as<TFObjectType>(StringToInt(arg));
	
	// Prevent Engineers from building sentry guns
	if (type == TFObject_Sentry)
		return Plugin_Handled;
	
	return Plugin_Continue;
}
