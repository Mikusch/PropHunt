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
	ph_prop_max_select_distance = CreateConVar("ph_prop_max_select_distance", "128.0", "Players must have at least this distance to the prop to be able to select it.");
	ph_hunter_damagemod_guns = CreateConVar("ph_hunter_damagemod_guns", "0.5", "Modifier of damage taken from gun-based weapons.");
	ph_hunter_damagemod_melee = CreateConVar("ph_hunter_damagemod_melee", "0.25", "Modifier of damage taken from melee-based weapons.");
	ph_hunter_damage_grapplinghook = CreateConVar("ph_hunter_damage_grapplinghook", "15.0", "Amount of damage taken when using the grappling hook.");
	
	// These may be overridden by map configs
	ph_hunter_setup_freeze = CreateConVar("ph_hunter_setup_freeze", "1", "If set to 1, Hunters cannot move during setup time.");
	ph_open_doors_after_setup = CreateConVar("ph_open_doors_after_setup", "1", "If set to 1, all doors in the map will open after setup time.");
	ph_setup_time = CreateConVar("ph_setup_time", "30", "Length of the hiding time for props.");
	ph_round_time = CreateConVar("ph_round_time", "175", "Length of the round time.");
	ph_relay_name = CreateConVar("ph_relay_name", "hidingover", "Name of the relay to fire after setup time.");
}
