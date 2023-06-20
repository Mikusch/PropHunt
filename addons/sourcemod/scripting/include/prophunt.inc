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

#if defined _prophunt_included
 #endinput
#endif
#define _prophunt_included

/**
 * Called when a player has successfully disguised as a prop.
 *
 * @param client		The client index.
 * @param model			The model name.
 */
forward void PropHunt_OnPlayerDisguised(int client, const char[] model);

/**
 * Called when a player is taunting.
 *
 * @param client		The client index.
 * @param sound			The sound being played.
 * @param maxlength		Maximum length of the sound buffer.
 *
 * @return Plugin_Handled to block the taunt from playing, Plugin_Continue otherwise.
 */
forward Action PropHunt_OnPlayerTaunt(int client, char[] sound, int maxlength);

public SharedPlugin __pl_prophunt =
{
	name = "prophunt",
	file = "prophunt.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
