/**
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

static GlobalForward g_ForwardOnPlayerDisguised;
static GlobalForward g_hForwardOnTaunt;

void Forwards_Init()
{
	g_ForwardOnPlayerDisguised = new GlobalForward("PropHunt_OnPlayerDisguised", ET_Ignore, Param_Cell, Param_String);
	g_hForwardOnTaunt = new GlobalForward("PropHunt_OnPlayerTaunt", ET_Single, Param_Cell, Param_String, Param_Cell);
}

void Forward_OnPlayerDisguised(int client, const char[] model)
{
	Call_StartForward(g_ForwardOnPlayerDisguised);
	Call_PushCell(client);
	Call_PushString(model);
	Call_Finish();
}

Action Forwards_OnTaunt(int client, char[] sound, int maxlength)
{
	Action returnVal = Plugin_Continue;
	
	Call_StartForward(g_hForwardOnTaunt);
	Call_PushCell(client);
	Call_PushStringEx(sound, maxlength, SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(maxlength);
	Call_Finish(returnVal);
	
	return returnVal;
}
