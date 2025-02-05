/**
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

static StringMap g_offsets;

void Offsets_Init(GameData gamedata)
{
	g_offsets = new StringMap();
	
	SetOffset(gamedata, "CTFWeaponBase", "m_iWeaponMode");
	SetOffset(gamedata, "CTFWeaponBase", "m_pWeaponInfo");
	
	SetOffset(gamedata, NULL_STRING, "sizeof(WeaponData_t)");
	SetOffset(gamedata, "WeaponData_t", "m_nDamage");
	SetOffset(gamedata, "WeaponData_t", "m_nBulletsPerShot");
	SetOffset(gamedata, "WeaponData_t", "m_flTimeFireDelay");
}

any GetOffset(const char[] cls, const char[] prop)
{
	int offset;
	
	if (IsNullString(cls))
	{
		if (!g_offsets.GetValue(prop, offset))
		{
			ThrowError("Offset '%s' not present in map", prop);
		}
	}
	else
	{
		char key[64];
		Format(key, sizeof(key), "%s::%s", cls, prop);
		
		if (!g_offsets.GetValue(key, offset))
		{
			ThrowError("Offset '%s' not present in map", key);
		}
	}
	
	return offset;
}

static void SetOffset(GameData gamedata, const char[] cls, const char[] prop)
{
	if (IsNullString(cls))
	{
		// Simple gamedata key lookup
		int offset = gamedata.GetOffset(prop);
		if (offset == -1)
		{
			ThrowError("Offset '%s' could not be found", prop);
		}
		
		g_offsets.SetValue(prop, offset);
	}
	else
	{
		char key[64], base_key[64], base_prop[64];
		Format(key, sizeof(key), "%s::%s", cls, prop);
		Format(base_key, sizeof(base_key), "%s_BaseOffset", cls);
		
		// Get the actual offset, calculated using a base offset if present
		if (gamedata.GetKeyValue(base_key, base_prop, sizeof(base_prop)))
		{
			int base_offset = FindSendPropInfo(cls, base_prop);
			if (base_offset == -1)
			{
				// If we found nothing, search on CBaseEntity instead
				base_offset = FindSendPropInfo("CBaseEntity", base_prop);
				if (base_offset == -1)
				{
					ThrowError("Base offset '%s::%s' could not be found", cls, base_prop);
				}
			}
			
			int offset = base_offset + gamedata.GetOffset(key);
			g_offsets.SetValue(key, offset);
		}
		else
		{
			int offset = gamedata.GetOffset(key);
			if (offset == -1)
			{
				ThrowError("Offset '%s' could not be found", key);
			}
			
			g_offsets.SetValue(key, offset);
		}
	}
}
