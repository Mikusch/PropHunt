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

void DHooks_Initialize(GameData gamedata)
{
	DHooks_CreateDetour(gamedata, "CTFPlayer::GetMaxHealthForBuffing", _, DHook_GetMaxHealthForBuffing_Post);
}

static void DHooks_CreateDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (!detour)
	{
		LogError("Failed to create detour: %s", name);
	}
	else
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);
		
		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
}

public MRESReturn DHook_GetMaxHealthForBuffing_Post(int player, DHookReturn ret)
{
	if (PHPlayer(player).IsProp())
	{
		int health;
		float mins[3], maxs[3];
		
		// Determine health based on prop bounding box size
		switch (PHPlayer(player).PropType)
		{
			case Prop_Static:
			{
				if (StaticProp_GetWorldSpaceBounds(PHPlayer(player).PropIndex, mins, maxs))
					health = RoundToCeil(GetVectorDistance(mins, maxs));
			}
			case Prop_Entity:
			{
				int entity = EntRefToEntIndex(PHPlayer(player).PropIndex);
				if (entity != -1)
				{
					GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
					GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);
					health = RoundToCeil(GetVectorDistance(mins, maxs));
				}
				else
				{
					// Prop we disguised as is now invalid, don't update max health until we redisguise
					health = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, player);
				}
			}
			default:
			{
				// Use class default health if we are not a prop
				return MRES_Ignored;
			}
		}
		
		// Refill health during setup time
		if (GameRules_GetRoundState() == RoundState_Preround)
			SetEntityHealth(player, health);
		
		ret.Value = health;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}
