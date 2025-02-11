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

static PHPropType g_aPlayerStatsPropType[MAXPLAYERS + 1];
static int g_aPlayerStatsPropIndex[MAXPLAYERS + 1];
static int g_aPlayerStatsOldMaxHealth[MAXPLAYERS + 1];
static bool g_aPlayerStatsPropLockEnabled[MAXPLAYERS + 1];
static bool g_aPlayerStatsInForcedTauntCam[MAXPLAYERS + 1];
static bool g_aPlayerStatsHasReceivedBonus[MAXPLAYERS + 1];
static bool g_aPlayerStatsIsLastProp[MAXPLAYERS + 1];
static float g_aPlayerStatsNextTauntTime[MAXPLAYERS + 1];

methodmap PHPlayer
{
	public PHPlayer(int client)
	{
		return view_as<PHPlayer>(client);
	}
	
	property int entindex
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property PHPropType PropType
	{
		public get()
		{
			return g_aPlayerStatsPropType[this.entindex];
		}
		public set(PHPropType type)
		{
			g_aPlayerStatsPropType[this.entindex] = type;
		}
	}
	
	property int PropIndex
	{
		public get()
		{
			return g_aPlayerStatsPropIndex[this.entindex];
		}
		public set(int index)
		{
			g_aPlayerStatsPropIndex[this.entindex] = index;
		}
	}
	
	property int OldMaxHealth
	{
		public get()
		{
			return g_aPlayerStatsOldMaxHealth[this.entindex];
		}
		public set(int health)
		{
			g_aPlayerStatsOldMaxHealth[this.entindex] = health;
		}
	}
	
	property bool PropLockEnabled
	{
		public get()
		{
			return g_aPlayerStatsPropLockEnabled[this.entindex];
		}
		public set(bool enabled)
		{
			g_aPlayerStatsPropLockEnabled[this.entindex] = enabled;
		}
	}
	
	property bool InForcedTauntCam
	{
		public get()
		{
			return g_aPlayerStatsInForcedTauntCam[this.entindex];
		}
		public set(bool inForcedTauntCam)
		{
			g_aPlayerStatsInForcedTauntCam[this.entindex] = inForcedTauntCam;
		}
	}
	
	property bool HasReceivedBonus
	{
		public get()
		{
			return g_aPlayerStatsHasReceivedBonus[this.entindex];
		}
		public set(bool hasReceivedBonus)
		{
			g_aPlayerStatsHasReceivedBonus[this.entindex] = hasReceivedBonus;
		}
	}
	
	property bool IsLastProp
	{
		public get()
		{
			return g_aPlayerStatsIsLastProp[this.entindex];
		}
		public set(bool isLastProp)
		{
			g_aPlayerStatsIsLastProp[this.entindex] = isLastProp;
		}
	}
	
	property float NextTauntTime
	{
		public get()
		{
			return g_aPlayerStatsNextTauntTime[this.entindex];
		}
		public set(float time)
		{
			g_aPlayerStatsNextTauntTime[this.entindex] = time;
		}
	}
	
	public void Reset()
	{
		this.PropType = Prop_None;
		this.PropIndex = -1;
		this.OldMaxHealth = 0;
		this.PropLockEnabled = false;
		this.InForcedTauntCam = true;
		this.HasReceivedBonus = false;
		this.IsLastProp = false;
		this.NextTauntTime = -1.0;
	}
};
