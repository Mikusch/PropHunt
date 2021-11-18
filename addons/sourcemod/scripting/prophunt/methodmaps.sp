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

static PHPropType g_PlayerPropType[MAXPLAYERS + 1];
static int g_PlayerPropIndex[MAXPLAYERS + 1];
static bool g_PlayerPropLockEnabled[MAXPLAYERS + 1];
static bool g_PlayerInForcedTauntCam[MAXPLAYERS + 1];
static bool g_PlayerHasReceivedBonus[MAXPLAYERS + 1];
static bool g_PlayerIsLastProp[MAXPLAYERS + 1];

methodmap PHPlayer
{
	public PHPlayer(int client)
	{
		return view_as<PHPlayer>(client);
	}
	
	property int Client
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
			return g_PlayerPropType[this.Client];
		}
		public set(PHPropType type)
		{
			g_PlayerPropType[this.Client] = type;
		}
	}
	
	property int PropIndex
	{
		public get()
		{
			return g_PlayerPropIndex[this.Client];
		}
		public set(int index)
		{
			g_PlayerPropIndex[this.Client] = index;
		}
	}
	
	property bool PropLockEnabled
	{
		public get()
		{
			return g_PlayerPropLockEnabled[this.Client];
		}
		public set(bool enabled)
		{
			g_PlayerPropLockEnabled[this.Client] = enabled;
		}
	}
	
	property bool InForcedTauntCam
	{
		public get()
		{
			return g_PlayerInForcedTauntCam[this.Client];
		}
		public set(bool inForcedTauntCam)
		{
			g_PlayerInForcedTauntCam[this.Client] = inForcedTauntCam;
		}
	}
	
	property bool HasReceivedBonus
	{
		public get()
		{
			return g_PlayerHasReceivedBonus[this.Client];
		}
		public set(bool hasReceivedBonus)
		{
			g_PlayerHasReceivedBonus[this.Client] = hasReceivedBonus;
		}
	}
	
	property bool IsLastProp
	{
		public get()
		{
			return g_PlayerIsLastProp[this.Client];
		}
		public set(bool isLastProp)
		{
			g_PlayerIsLastProp[this.Client] = isLastProp;
		}
	}
	
	public void Reset()
	{
		this.PropType = Prop_None;
		this.PropIndex = -1;
		this.PropLockEnabled = false;
		this.InForcedTauntCam = true;
		this.HasReceivedBonus = false;
		this.IsLastProp = false;
	}
}
