/*
 * SourceMod Hosties Project
 * by: databomb & dataviruset
 *
 * This file is part of the SM Hosties project.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */
 
 // Double include protection
#if defined _foxserito_jail_warden_
	#endinput
#endif
#define _foxserito_jail_warden_

#include <sdktools_functions>
#include <sdktools_entinput>

public SharedPlugin:__jail_warden =
{
	name = "sm_jail_warden",
	file = "sm_jail_warden.smx",
	required = 1,
};

stock StripAllWeapons(client)
{
	new wepIdx;
	for (new i; i < 4; i++)
	{
		if ((wepIdx = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, wepIdx);
			AcceptEntityInput(wepIdx, "Kill");
		}
	}
}

stock InvisWeapons(client)
{
	new weapon;
	for (new slot = 0; slot <= 4; slot++)
	{
		weapon = GetPlayerWeaponSlot(client, slot);
		
		if(weapon > -1 )
		{
			SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
			SetEntityRenderColor(weapon, 255, 255, 255, 0);
		}
	}
}