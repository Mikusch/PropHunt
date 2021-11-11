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

void ConVars_Initialize()
{
	ph_prop_min_size = CreateConVar("ph_prop_min_size", "50.0", "Minimum size of props to be able to select them.");
	ph_prop_max_size = CreateConVar("ph_prop_max_size", "400.0", "Maximum size of props to be able to select them.");
	fw_prop_max_select_distance = CreateConVar("fw_prop_max_select_distance", "128.0", "Players must have at least this distance to the prop to be able to select it.");
}
