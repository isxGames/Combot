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

objectdef obj_TargetList inherits obj_State
{
	variable index:entity TargetList
	variable index:entity TargetListBuffer
	variable index:entity TargetListBufferOOR
	variable index:string QueryStringList
	variable int MaxRange = 20000
	
	method Initialize()
	{
		This[parent]:Initialize
		PulseFrequency:Set[50]
		RandomDelta:Set[0]
		This:QueueState["UpdateList"]
	}

	method ClearQueryString()
	{
		QueryStringList:Clear
	}
	
	method AddQueryString(string QueryString)
	{
		QueryStringList:Insert["${QueryString.Escape}"]
	}
	
	method AddTargetingMe(bool NPC = TRUE)
	{
		if ${NPC}
		{
			This:AddQueryString["IsTargetingMe && IsNPC"]
		}
		else
		{
			This:AddQueryString["IsTargetingMe"]
		}
	}
	
	method AddAllNPCs()
	{
		variable string QueryString="CategoryID = CATEGORYID_ENTITY && IsNPC && !("
		
		;Exclude Groups here
		QueryString:Concat["GroupID = GROUP_CONCORDDRONE ||"]
		QueryString:Concat["GroupID = GROUP_CONVOYDRONE ||"]
		QueryString:Concat["GroupID = GROUP_CONVOY ||"]
		QueryString:Concat["GroupID = GROUP_LARGECOLLIDABLEOBJECT ||"]
		QueryString:Concat["GroupID = GROUP_LARGECOLLIDABLESHIP ||"]
		QueryString:Concat["GroupID = GROUP_SPAWNCONTAINER ||"]
		QueryString:Concat["GroupID = GROUP_LARGECOLLIDABLESTRUCTURE)"]
		
		This:AddQueryString["${QueryString.Escape}"]
	}
	
	member:bool UpdateList()
	{
		variable iterator QueryStringIterator
		QueryStringList:GetIterator[QueryStringIterator]

		if ${QueryStringIterator:First(exists)}
		{
			do
			{
				This:QueueState["GetQueryString", -1, "${QueryStringIterator.Value.Escape}"]
			}
			while ${QueryStringIterator:Next(exists)}
		}
		This:QueueState["PopulateList"]
		This:QueueState["UpdateList"]
		return TRUE
	}
	
	member:bool GetQueryString(string QueryString)
	{
		variable index:entity entity_index
		variable iterator entity_iterator
		if !${Client.InSpace}
		{
			return FALSE
		}
		EVE:QueryEntities[entity_index, "${QueryString.Escape}"]		
		entity_index:GetIterator[entity_iterator]
		if ${entity_iterator:First(exists)}
		{
			do
			{
				if ${entity_iterator.Value.Distance} <= ${MaxRange}
				{
					This.TargetListBuffer:Insert[${entity_iterator.Value.ID}]
				}
				else
				{
					This.TargetListBufferOOR:Insert[${entity_iterator.Value.ID}]
				}
			}
			while ${entity_iterator:Next(exists)}
		}
		return TRUE
	}
	
	member:bool PopulateList()
	{
		variable iterator entity_iterator
		This.TargetList:Clear
		This.TargetListBuffer:GetIterator[entity_iterator]

		if ${entity_iterator:First(exists)}
		{
			do
			{
				This.TargetList:Insert[${entity_iterator.Value.ID}]
			}
			while ${entity_iterator:Next(exists)}
		}
		
		This.TargetListBufferOOR:GetIterator[entity_iterator]

		if ${entity_iterator:First(exists)}
		{
			do
			{
				This.TargetList:Insert[${entity_iterator.Value.ID}]
			}
			while ${entity_iterator:Next(exists)}
		}
		This.TargetListBuffer:Clear
		This.TargetListBufferOOR:Clear
		return TRUE
	}
}