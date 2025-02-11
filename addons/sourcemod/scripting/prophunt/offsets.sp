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
static StringMap g_typeSizes;

void Offsets_Init(GameData gamedata)
{
	g_offsets = new StringMap();
	g_typeSizes = new StringMap();
	
	SetOffset(gamedata, "CTFWeaponBase", "m_iWeaponMode");
	SetOffset(gamedata, "CTFWeaponBase", "m_pWeaponInfo");
	
	SetOffset(gamedata, "WeaponData_t", "m_nDamage");
	SetOffset(gamedata, "WeaponData_t", "m_flTimeFireDelay");
	
	SetOffset(gamedata, "CGameTrace", "m_pEnt");
	
	SetTypeSize(gamedata, "WeaponData_t");
}

any GetOffset(const char[] cls, const char[] prop)
{
	char key[64];
	Format(key, sizeof(key), "%s::%s", cls, prop);
	
	int offset;
	if (!g_offsets.GetValue(key, offset))
		ThrowError("Failed to find offset '%s'", key);
	
	return offset;
}

int GetTypeSize(const char[] key)
{
	int size;
	if (!g_typeSizes.GetValue(key, size))
		ThrowError("Failed to find size for type '%s'", key);
	
	return size;
}

static void SetOffset(GameData hGameConf, const char[] cls, const char[] prop)
{
	char key[64], base_key[64], base_prop[64];
	Format(key, sizeof(key), "%s::%s", cls, prop);
	Format(base_key, sizeof(base_key), "%s_BaseOffset", cls);
	
	// Get the actual offset, calculated using a base offset if present
	if (hGameConf.GetKeyValue(base_key, base_prop, sizeof(base_prop)))
	{
		int base_offset = FindSendPropInfo(cls, base_prop);
		if (base_offset == -1)
		{
			// If we found nothing, search on CBaseEntity instead
			base_offset = FindSendPropInfo("CBaseEntity", base_prop);
			if (base_offset == -1)
			{
				ThrowError("Failed to find base offset '%s::%s'", cls, base_prop);
			}
		}
		
		int offset = base_offset + hGameConf.GetOffset(key);
		g_offsets.SetValue(key, offset);
	}
	else
	{
		int offset = hGameConf.GetOffset(key);
		if (offset == -1)
		{
			ThrowError("Failed to find offset '%s'", key);
		}
		
		g_offsets.SetValue(key, offset);
	}
}

static void SetTypeSize(GameData hGameConf, const char[] name)
{
	char key[64];
	Format(key, sizeof(key), "sizeof(%s)", name);
	
	int size = hGameConf.GetOffset(key);
	if (size == -1)
		ThrowError("Failed to find size for type '%s", name);
	
	g_typeSizes.SetValue(name, size);
}
