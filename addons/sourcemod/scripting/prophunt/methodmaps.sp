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

methodmap PHPlayer < CBaseCombatCharacter
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
	
	public int GetEffectiveSkin()
	{
		return GetEntProp(this.entindex, Prop_Send, "m_bForcedSkin") ? GetEntProp(this.entindex, Prop_Send, "m_nForcedSkin") : GetEntProp(this.entindex, Prop_Send, "m_nSkin");
	}
	
	public int GetMaxHealth()
	{
		return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, this.entindex);
	}

	public void TogglePropLock(bool toggle)
	{
		if (this.PropLockEnabled == toggle)
			return;
		
		this.PropLockEnabled = toggle;
		
		if (toggle)
		{
			this.SetPropVector(Prop_Data, "m_vecAbsVelocity", ZERO_VECTOR);

			RunScriptCode(this.entindex, -1, -1, "self.DisableDraw()");
			RunScriptCode(this.entindex, -1, -1, "self.SetCollisionGroup(Constants.ECollisionGroup.COLLISION_GROUP_IN_VEHICLE)");
			TF2_AddCondition(this.entindex, TFCond_ImmuneToPushback);
			this.SetProp(Prop_Data, "m_takedamage", DAMAGE_NO); // All damage is passed on from CFakeProp

			CFakeProp prop = CFakeProp.CreateFromPlayer(this, LockedProp_OnTakeDamage);
			prop.SetPropFloat(Prop_Send, "m_fadeMaxDist", this.GetProp(Prop_Send, "m_nForceTauntCam") == 0 ? 1.0 : 0.0);
		}
		else
		{
			RunScriptCode(this.entindex, -1, -1, "self.EnableDraw()");
			RunScriptCode(this.entindex, -1, -1, "self.SetCollisionGroup(Constants.ECollisionGroup.COLLISION_GROUP_PLAYER)");
			TF2_RemoveCondition(this.entindex, TFCond_ImmuneToPushback);
			this.SetProp(Prop_Data, "m_takedamage", DAMAGE_YES);

			this.DestroyLockedProp();
		}

		SetVariantInt(!toggle);
		this.AcceptInput("SetCustomModelRotates");

		this.ToggleFlag(FL_NOTARGET);

		this.SetMoveType(toggle ? MOVETYPE_NONE : MOVETYPE_WALK);
		EmitSoundToClient(this.entindex, toggle ? LOCK_SOUND : UNLOCK_SOUND, _, SNDCHAN_STATIC);
	}

	public void DoTaunt()
	{
		if (GetGameTime() < this.NextTauntTime)
			return;
		
		char sound[PLATFORM_MAX_PATH];
		
		// Only props have taunt sounds by default, but subplugins can override this
		if (TF2_GetClientTeam(this.entindex) == TFTeam_Props)
			strcopy(sound, sizeof(sound), g_DefaultTauntSounds[GetRandomInt(0, sizeof(g_DefaultTauntSounds) - 1)]);
		
		Action result = Forwards_OnTaunt(this.entindex, sound, sizeof(sound));
		
		if (result >= Plugin_Handled)
			return;
		
		if (sound[0] == EOS)
			return;
		
		if (PrecacheScriptSound(sound))
			EmitGameSoundToAll(sound, this.entindex);
		else if (PrecacheSound(sound))
			EmitSoundToAll(sound, this.entindex, SNDCHAN_STATIC, 85, .pitch = GetRandomInt(90, 110));
		
		this.NextTauntTime = GetGameTime() + 2.0;
	}

	public CFakeProp GetLockedProp()
	{
		int prop = -1;
		while ((prop = FindEntityByClassname(prop, "ph_fake_prop")) != -1)
		{
			if (GetEntPropEnt(prop, Prop_Send, "m_hOwnerEntity") != this.entindex)
				continue;
			
			return CFakeProp(prop);
		}

		return CFakeProp(-1);
	}

	public void DestroyLockedProp()
	{
		CFakeProp prop = this.GetLockedProp();
		if (prop.IsValid())
			RemoveEntity(prop.index);
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
