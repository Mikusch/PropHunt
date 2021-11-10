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

static Handle g_SDKCallRemoveAllWeapons;

void SDKCalls_Initialize(GameData gamedata)
{
	g_SDKCallRemoveAllWeapons = PrepSDKCall_RemoveAllWeapons(gamedata);
}

static Handle PrepSDKCall_RemoveAllWeapons(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFPlayer::RemoveAllWeapons");
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CTFPlayer::RemoveAllWeapons");
	
	return call;
}

void SDKCall_RemoveAllWeapons(int client)
{
	if (g_SDKCallRemoveAllWeapons)
		SDKCall(g_SDKCallRemoveAllWeapons, client);
}
