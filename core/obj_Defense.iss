/*

ComBot  Copyright ? 2012  Tehtsuo and Vendan

This file is part of ComBot.

ComBot is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

ComBot is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with ComBot.  If not, see <http://www.gnu.org/licenses/>.

*/

objectdef obj_Defense inherits obj_State
{
	variable index:entity Locked
	variable index:entity Asteroids

	method Initialize()
	{
		UI:Update["obj_Defense", "Initialized", "g"]
		
		This[parent]:Initialize

		This:QueueState["Defend", 100]
	}
	
	member:bool Defend()
	{
		if !${Client.InSpace}
		{
			return FALSE
		}
		if ${Ship.ModuleList_Regen_Shield.InactiveCount} && ${MyShip.ShieldPct} < 95
		{
			Ship.ModuleList_Regen_Shield:ActivateCount[${Ship.ModuleList_Regen_Shield.InactiveCount}]
		}
		if ${Ship.ModuleList_Regen_Shield.ActiveCount} && ${MyShip.ShieldPct} > 95
		{
			Ship.ModuleList_Regen_Shield:DeactivateCount[${Ship.ModuleList_Regen_Shield.ActiveCount}]
		}
		return FALSE	
	}
		
}