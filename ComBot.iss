/*

ComBot  Copyright � 2012  Tehtsuo and Vendan

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

#if ${ISXEVE(exists)}
#else
	#error ComBot requires ISXEVE to be loaded before running
#endif

#include core/Defines.iss
#include core/obj_ComBot.iss
#include core/obj_Configuration.iss

#include core/obj_State.iss
#include core/obj_ComBotUI.iss
#include core/obj_Client.iss
#include core/obj_Move.iss
#include core/obj_Module.iss
#include core/obj_ModuleList.iss
#include core/obj_Ship.iss
#include core/obj_Cargo.iss
#include core/obj_Salvage.iss
#include core/obj_Targets.iss
#include core/obj_Miner.iss
#include core/obj_Agents.iss
#include core/obj_HangerSale.iss
#include core/obj_Combat.iss
#include core/obj_Bookmarks.iss
#include core/obj_AgentDialog.iss
#include core/obj_TargetList.iss
#include core/obj_Drones.iss
#include core/obj_Defense.iss


function atexit()
{

}

function main()
{
	echo "${Time} ComBot: Starting"

	declarevariable UI obj_ComBotUI script
	declarevariable ComBot obj_ComBot script
	declarevariable BaseConfig obj_Configuration_BaseConfig script
	declarevariable Config obj_Configuration script
	UI:Reload
	
	declarevariable Client obj_Client script
	declarevariable Move obj_Move script
	declarevariable InstaWarp obj_InstaWarp script
	declarevariable Ship obj_Ship script
	declarevariable Cargo obj_Cargo script
	declarevariable Salvager obj_Salvage script
	declarevariable Targets obj_Targets script
	declarevariable Miner obj_Miner script
	declarevariable Bookmarks obj_Bookmarks script
	declarevariable Agents obj_Agents script
	declarevariable HangerSale obj_HangerSale script
	declarevariable RefineData obj_Configuration_RefineData script
	declarevariable Combat obj_Combat script
	declarevariable AgentDialog obj_AgentDialog script
	declarevariable Drones obj_Drones script
	declarevariable Defense obj_Defense script

	UI:Update["ComBot", "Module initialization complete", "y"]
	
	
	
	if ${Config.Common.AutoStart}
	{
		ComBot.Paused:Set[FALSE]
		${Config.Common.ComBot_Mode}:Start
	}
	else
	{
		UI:Update["ComBot", "Paused", "r"]
	}
	

	while TRUE
	{
		wait 10
	}
}
