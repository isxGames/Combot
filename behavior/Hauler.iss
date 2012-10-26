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

objectdef obj_Configuration_Hauler
{
	variable string SetName = "Hauler"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			UI:Update["obj_Configuration", " ${This.SetName} settings missing - initializing", "o"]
			This:Set_Default_Values[]
		}
		UI:Update["obj_Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	member:settingsetref CommonRef()
	{
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}]}
	}

	method Set_Default_Values()
	{
		BaseConfig.BaseRef:AddSet[${This.SetName}]

		This.CommonRef:AddSetting[DropoffContainer,""]
		This.CommonRef:AddSetting[PickupContainer,""]
		This.CommonRef:AddSetting[Dropoff,""]
		This.CommonRef:AddSetting[Pickup,""]
		
	}
	
	Setting(string, MiningSystem, SetMiningSystem)	
	Setting(string, PickupSubType, SetPickupSubType)
	Setting(string, Dropoff, SetDropoff)
	Setting(string, Pickup, SetPickup)
	Setting(string, DropoffType, SetDropoffType)
	Setting(string, PickupType, SetPickupType)
	Setting(string, DropoffContainer, SetDropoffContainer)
	Setting(string, PickupContainer, SetPickupContainer)
	Setting(string, DropoffSubType, SetDropoffSubType)
	Setting(int, Threshold, SetThreshold)	
	
}

objectdef obj_Hauler inherits obj_State
{
	variable obj_Configuration_Hauler Config
	variable obj_HaulerUI LocalUI

	variable float OrcaCargo
	variable index:fleetmember FleetMembers
	variable int64 CurrentCan
	variable bool PopCan
	variable IPCQueue:obj_HaulLocation OnDemandHaulQueue = "HaulerOnDemandQueue"
	
	variable obj_TargetList IR_Cans
	variable obj_TargetList OOR_Cans

	method Initialize()
	{
		This[parent]:Initialize
		LavishScript:RegisterEvent[ComBot_Orca_Cargo]
		Event[ComBot_Orca_Cargo]:AttachAtom[This:OrcaCargoUpdate]
		PulseFrequency:Set[500]
		IR_Cans.MaxRange:Set[LOOT_RANGE]
		IR_Cans.ListOutOfRange:Set[FALSE]
		OOR_Cans.MaxRange:Set[WARP_RANGE]
		OOR_Cans.MinRange:Set[LOOT_RANGE]
		DynamicAddBehavior("Hauler", "Hauler")
	}

	method Shutdown()
	{
		Event[ComBot_Orca_Cargo]:DetachAtom[This:OrcaCargoUpdate]
	}	
	
	method Start()
	{
		UI:Update["obj_Hauler", "Started", "g"]
		Drones:RemainDocked
		Drones:Defensive
		This:AssignStateQueueDisplay[DebugStateList@Debug@ComBotTab@ComBot]
		if ${This.IsIdle}
		{
			This:QueueState["OpenCargoHold"]
			This:QueueState["CheckCargoHold"]
		}
	}
	
	method Stop()
	{
		This:DeactivateStateQueueDisplay
		This:Clear
	}
	
	
	
	member:bool OpenCargoHold()
	{
		if !${EVEWindow[ByName, "Inventory"](exists)}
		{
			UI:Update["obj_Hauler", "Opening inventory", "g"]
			MyShip:Open
			return FALSE
		}
		return TRUE
	}
	
	member:bool CheckCargoHold()
	{
		if ${MyShip.UsedCargoCapacity} / ${MyShip.CargoCapacity} >= ${Config.Threshold} * .01
		{
			UI:Update["obj_Hauler", "Unload trip required", "g"]
			Cargo:At[${Config.Dropoff},${Config.DropoffType},${Config.DropoffSubType}]:Unload
			This:QueueState["Traveling"]
			This:QueueState["OpenCargoHold"]
			This:QueueState["CheckCargoHold"]
			return TRUE
		}
		else
		{
			This:QueueState["CheckForWork"]
			This:QueueState["QueuePickup"]
			return TRUE
		}
	}

	member:bool CheckForWork()
	{
		if ${Config.PickupType.Equal[Orca]}
		{
			if ${OrcaCargo} > ${Config.Threshold} * .01 * ${MyShip.CargoCapacity}
			{
				return TRUE
			}
			else
			{
				Move:Bookmark[${Config.Dropoff}]
				This:InsertState["Traveling"]
				This:InsertState["Idle", 30000]
				This:InsertState["CheckForWork"]
				return TRUE
			}
		}
		return TRUE
	}
	
	member:bool QueuePickup()
	{
		if ${Config.PickupType.Equal[Jetcan]}
		{
			Move:Bookmark[${Config.Pickup}]
			This:QueueState["Traveling"]
			
			;	NEED JETCAN STATES HERE
		}
		else
		{
			variable string PickupType=${Config.PickupType}
			if ${PickupType.Equal[Orca]}
			{
				PickupType:Set[Container]
			}
			Cargo:At[${Config.Pickup},${PickupType},${Config.PickupSubType},${Config.PickupContainer}]:Load
			This:QueueState["Traveling"]
			This:QueueState["OpenCargoHold"]
			This:QueueState["CheckCargoHold"]
		}
		return TRUE
	}
	
	
	member:bool Traveling()
	{
		if ${Cargo.Processing} || ${Move.Traveling} || ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}
		return TRUE
	}

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	member:bool PopulateTargetList(int64 ID)
	{
		variable int64 CharID = ${Entity[${ID}].CharID}
		IR_Cans:ClearQueryString
		IR_Cans:AddQueryString[GroupID == GROUP_CARGOCONTAINER && OwnerID == ${CharID}]
		IR_Cans.DistanceTarget:Set[${ID}]
		OOR_Cans:ClearQueryString
		OOR_Cans:AddQueryString[GroupID == GROUP_CARGOCONTAINER && OwnerID == ${CharID}]
		OOR_Cans.DistanceTarget:Set[${ID}]

		IR_Cans.AutoLock:Set[FALSE]
		OOR_Cans.AutoLock:Set[FALSE]
		
		OOR_Cans:RequestUpdate
		IR_Cans:RequestUpdate
		
		return TRUE
	}
	
	member:bool CheckTargetList()
	{
		if ${IR_Cans.Updated} && ${OOR_Cans.Updated}
		{
			return TRUE
		}
		return FALSE
	}

	
	member:bool LootCans(int64 ID)
	{
		if !${Entity[${ID}](exists)}
		{
			return TRUE
		}
		
		variable iterator CanIter
		
		if ${MyShip.UsedCargoCapacity} > (${Config.Threshold} * .01 * ${MyShip.CargoCapacity})
		{
			return TRUE
		}
		
		echo ${IR_Cans.TargetList.Used} cans in range
		echo ${OOR_Cans.TargetList.Used} cans out of range
		
		OOR_Cans:RequestUpdate
		IR_Cans:RequestUpdate
		
		if !${Entity[${CurrentCan}](exists)}
		{
			CurrentCan:Set[-1]
		}
		
		if ${OOR_Cans.TargetList.Used} > 0 && ${CurrentCan.Equal[-1]}
		{
			CurrentCan:Set[${OOR_Cans.TargetList.Get[1].ID}]
			PopCan:Set[TRUE]
		}

		if ${IR_Cans.TargetList.Used} > 0 && ${CurrentCan.Equal[-1]}
		{
			CurrentCan:Set[${IR_Cans.TargetList.Get[1].ID}]
			PopCan:Set[TRUE]
			if ${IR_Cans.TargetList.Used} == 1
			{
				PopCan:Set[FALSE]
			}
		}
		
		if ${CurrentCan.Equal[-1]}
		{
			return TRUE
		}
		
		if ${Entity[${CurrentCan}].Distance} > ${MyShip.MaxTargetRange}
		{
			Move:Approach[${CurrentCan}, LOOT_RANGE]
			return FALSE
		}
		
		if !${Entity[${CurrentCan}].IsLockedTarget} && ${PopCan} && ${Ship.ModuleList_TractorBeams.Count} > 0 && ${Entity[${CurrentCan}].Distance} > LOOT_RANGE
		{
			if !${Entity[${CurrentCan}].BeingTargeted}
			{
				Entity[${CurrentCan}]:LockTarget
				return FALSE
			}
			return FALSE
		}
		
		if ${Entity[${CurrentCan}].Distance} > LOOT_RANGE
		{
			if ${Ship.ModuleList_TractorBeams.Count} > 0 && ${PopCan} && ${Entity[${CurrentCan}].Distance} <= ${Ship.ModuleList_TractorBeams.Range}
			{
				if !${Ship.ModuleList_TractorBeams.IsActiveOn[${CurrentCan}]}
				{
					Ship.ModuleList_TractorBeams:Activate[${CurrentCan}]
					return FALSE
				}
			}
			else
			{
				Move:Approach[${CurrentCan}, LOOT_RANGE]
				return FALSE
			}
		}
		else
		{
			if !${EVEWindow[ByName, Inventory].ChildWindowExists[${CurrentCan}]}
			{
				;UI:Update["obj_Hauler", "Opening - ${Entity[${CurrentCan}].Name}", "g"]
				Entity[${CurrentCan}]:OpenCargo
				return FALSE
			}
			if !${EVEWindow[ByItemID, ${CurrentCan}](exists)}
			{
				;UI:Update["obj_Hauler", "Activating - ${Entity[${CurrentCan}].Name}", "g"]
				EVEWindow[ByName, Inventory]:MakeChildActive[${CurrentCan}]
				return FALSE
			}
			UI:Update["obj_Hauler", "Looting - ${Entity[${CurrentCan}].Name}", "g"]
			Cargo:PopulateCargoList[CONTAINER, ${CurrentCan}]
			if ${EVEWindow[ByItemID, ${CurrentCan}].UsedCapacity} > ${Math.Calc[${MyShip.CargoCapacity} - ${MyShip.UsedCargoCapacity}]}
			{
				if ${PopCan}
				{
					Cargo:MoveCargoList[SHIP]
				}
				else
				{
					Cargo:DontPopCan
				}
				Ship.ModuleList_TractorBeams:Deactivate[${CurrentCan}]
				Entity[${CurrentCan}]:UnlockTarget
				return TRUE
			}
			else
			{
				if ${PopCan}
				{
					Cargo:MoveCargoList[SHIP]
				}
				else
				{
					Cargo:DontPopCan
					Entity[${CurrentCan}]:UnlockTarget
					if ${Config.JetCanMode.Equal["Service Corporate Bookmarks"]}
					{
						variable index:bookmark Bookmarks
						variable iterator BookmarkIterator
						EVE:GetBookmarks[Bookmarks]
						Bookmarks:GetIterator[BookmarkIterator]
						if ${BookmarkIterator:First(exists)}
						do
						{
							if ${BookmarkIterator.Value.Label.Left[5].Upper.Equal["Haul:"]} && ${BookmarkIterator.Value.CreatorID.Equal[${BookmarkCreator}]}
							{
								if ${BookmarkIterator.Value.JumpsTo} == 0
								{
									if ${BookmarkIterator.Value.Distance} < 500000
									{
										UI:Update["obj_Hauler", "Finished Salvaging ${BookmarkIterator.Value.Label} - Deleting", "g"]
										BookmarkIterator.Value:Remove
										return TRUE
									}
								}
							}
						}
						while ${BookmarkIterator:Next(exists)}
					}
					
					if ${Config.JetCanMode.Equal["Service On-Demand"]}
					{
						OnDemandHaulQueue:Dequeue
					}
					return TRUE
				}
			}
			return FALSE
		}
		return FALSE
	}

	member:bool DepopulateTargetList()
	{
		IR_Cans.AutoLock:Set[FALSE]
		OOR_Cans.AutoLock:Set[FALSE]
		CurrentCan:Set[-1]
		return TRUE
	}	
	
	
	member:bool Haul()
	{
		variable int64 Container

		This:Clear
		This:QueueState["OpenCargoHold", 10]

		if !${Client.InSpace}
		{
			This:QueueState["CheckCargoHold", 1000]
			This:QueueState["Pickup"]
			This:QueueState["OrcaWait"]
			This:QueueState["Undock"]
			This:QueueState["Haul"]
			return TRUE
		}
		else
		{
			This:QueueState["CheckCargoHold"]
			This:QueueState["GoToPickup"]
			This:QueueState["Traveling", 1000]
			This:QueueState["Haul"]
			if (${MyShip.UsedCargoCapacity} / ${MyShip.CargoCapacity}) >= ${Config.Threshold} * .01
			{
				echo Exiting before Haul - (${MyShip.UsedCargoCapacity} / ${MyShip.CargoCapacity}) >= ${Config.Threshold} * .01
				return TRUE
			}
		}

		if ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}

		echo Pickup Type
		switch ${Config.PickupType}
		{
			case Orca
				echo Orca
				if ${Entity[Name = "${Config.PickupContainerName}"](exists)}
				{
					Container:Set[${Entity[Name = "${Config.PickupContainerName}"].ID}]
					if ${Entity[${Container}].Distance} > LOOT_RANGE
					{
						Move:Approach[${Container}, LOOT_RANGE]
						return FALSE
					}
					else
					{
						if ${OrcaCargo}
						{
							if !${EVEWindow[ByName, Inventory].ChildWindowExists[${Container}]}
							{
								UI:Update["obj_Hauler", "Opening ${Config.PickupContainerName}", "g"]
								Entity[${Container}]:Open
								return FALSE
							}
							if !${EVEWindow[ByItemID, ${Container}](exists)} 
							{
								EVEWindow[ByName, Inventory]:MakeChildActive[${Container}]
								return FALSE
							}
							Cargo:PopulateCargoList[CONTAINERCORPORATEHANGAR, ${Container}]
							Cargo:MoveCargoList[SHIP]
							This:Clear
							This:QueueState["Idle", 1000]
							This:QueueState["CheckCargoHold"]
							This:QueueState["Haul"]
							return TRUE
						}
					}
				}
				else
				{
					echo Check for orca
					if ${Local[${Config.PickupContainerName}].ToFleetMember(exists)}
						{
							UI:Update["obj_Hauler", "Warping to ${Local[${Config.PickupContainerName}].ToFleetMember.ToPilot.Name}", "g"]
							Local[${Config.PickupContainerName}].ToFleetMember:WarpTo
							Client:Wait[5000]
							This:Clear
							This:QueueState["Traveling", 1000]
							This:QueueState["Haul"]
							return TRUE
						}
				}
				break

			case Container
				if ${Entity[Name = "${Config.PickupContainerName}"](exists)}
				{
					Container:Set[${Entity[Name = "${Config.PickupContainerName}"].ID}]
					if ${Entity[${Container}].Distance} > LOOT_RANGE
					{
						Move:Approach[${Container}, LOOT_RANGE]
						return FALSE
					}
					else
					{
						if !${EVEWindow[ByName, Inventory].ChildWindowExists[${Container}]}
						{
							UI:Update["obj_Hauler", "Opening ${Config.PickupContainerName}", "g"]
							Entity[${Container}]:Open
							return FALSE
						}
						if !${EVEWindow[ByItemID, ${Container}](exists)} 
						{
							EVEWindow[ByName, Inventory]:MakeChildActive[${Container}]
							return FALSE
						}
						Cargo:PopulateCargoList[CONTAINERCORPORATEHANGAR, ${Container}]
						Cargo:MoveCargoList[SHIP]
						This:Clear
						This:QueueState["Idle", 1000]
						This:QueueState["CheckCargoHold"]
						This:QueueState["Haul"]
						return TRUE
					}
				}
				else
				{
					Move:Bookmark[${Config.Pickup}]
					This:Clear
					This:QueueState["Traveling", 1000]
					This:QueueState["Haul"]
					return TRUE
				}
				break
			case Jetcan
				Switch ${Config.PickupSubType}
				{
					case Fleet Jetcan
						echo Fleet Jetcan
						if ${MyShip.UsedCargoCapacity} > (${Config.Threshold} * .01 * ${MyShip.CargoCapacity}) || ${EVE.Bookmark[${Config.Pickup}].SolarSystemID} != ${Me.SolarSystemID}
						{
							break
						}
						if !${FleetMembers.Used}
						{
							Me.Fleet:GetMembers[FleetMembers]
							FleetMembers:RemoveByQuery[${LavishScript.CreateQuery[ID == ${Me.CharID}]}]
							FleetMembers:Collapse
						}

						if ${FleetMembers.Get[1].ToEntity(exists)}
						{
							;UI:Update["obj_Miner", "Looting cans for ${FleetMembers.Get[1].ToPilot.Name}", "g"]
							This:Clear
							This:QueueState["PopulateTargetList", 2000, ${FleetMembers.Get[1].ToEntity.ID}]
							This:QueueState["CheckTargetList", 50]
							This:QueueState["LootCans", 1000, ${FleetMembers.Get[1].ToEntity.ID}]
							This:QueueState["DepopulateTargetList", 2000]
							This:QueueState["Haul"]
							FleetMembers:Remove[1]
							FleetMembers:Collapse
							return TRUE
						}
						else
						{
							echo Warping to ${FleetMembers.Get[1].ToPilot.Name} - ${FleetMembers.Get[1].ID}
							Move:Fleetmember[${FleetMembers.Get[1].ID}, TRUE]
							This:Clear
							This:QueueState["Traveling", 1000]
							This:QueueState["Haul"]
							return TRUE
						}
						break
					case Corporate Bookmark Jetcan
						variable string Target
						variable string BookmarkTime="24:00"
						variable bool BookmarkFound
						variable string BookmarkDate="9999.99.99"
						variable int64 BookmarkCreator
						variable index:bookmark Bookmarks
						variable iterator BookmarkIterator
						EVE:GetBookmarks[Bookmarks]
						Bookmarks:GetIterator[BookmarkIterator]
						if ${BookmarkIterator:First(exists)}
						do
						{	
							if ${BookmarkIterator.Value.Label.Left[5].Upper.Equal["Haul:"]} && ${BookmarkIterator.Value.JumpsTo} <= 0
							{
								if (${BookmarkIterator.Value.TimeCreated.Compare[${BookmarkTime}]} < 0 && ${BookmarkIterator.Value.DateCreated.Compare[${BookmarkDate}]} <= 0) || ${BookmarkIterator.Value.DateCreated.Compare[${BookmarkDate}]} < 0
								{
									echo Next bookmark set - ${BookmarkIterator.Value} - ${BookmarkIterator.Value.JumpsTo} Jumps
									Target:Set[${BookmarkIterator.Value.Label}]
									BookmarkTime:Set[${BookmarkIterator.Value.TimeCreated}]
									BookmarkDate:Set[${BookmarkIterator.Value.DateCreated}]
									BookmarkCreator:Set[${BookmarkIterator.Value.CreatorID}]
									BookmarkFound:Set[TRUE]
								}
							}
						}
						while ${BookmarkIterator:Next(exists)}
						
						if ${BookmarkIterator:First(exists)} && !${BookmarkFound}
						do
						{	
							if ${BookmarkIterator.Value.Label.Left[8].Upper.Equal[${Config.Salvager.Salvager_Prefix}]}
							{
								if (${BookmarkIterator.Value.TimeCreated.Compare[${BookmarkTime}]} < 0 && ${BookmarkIterator.Value.DateCreated.Compare[${BookmarkDate}]} <= 0) || ${BookmarkIterator.Value.DateCreated.Compare[${BookmarkDate}]} < 0
								{
									Target:Set[${BookmarkIterator.Value.Label}]
									BookmarkTime:Set[${BookmarkIterator.Value.TimeCreated}]
									BookmarkDate:Set[${BookmarkIterator.Value.DateCreated}]
									BookmarkCreator:Set[${BookmarkIterator.Value.CreatorID}]
									BookmarkFound:Set[TRUE]
								}
							}
						}
						while ${BookmarkIterator:Next(exists)}
						
						if ${BookmarkFound}
						{
							;UI:Update["obj_Miner", "Looting cans for ${FleetMembers.Get[1].ToPilot.Name}", "g"]
							This:Clear
							Move:Bookmark[${Target}, TRUE]
							This:QueueState["Traveling", 1000]
							This:QueueState["PopulateTargetList", 2000, ${BookmarkCreator}]
							This:QueueState["CheckTargetList", 50]
							This:QueueState["LootCans", 1000, ${BookmarkCreator}]
							This:QueueState["DepopulateTargetList", 2000]
							This:QueueState["Haul"]
							return TRUE
						}
						
						break
						
					case On-Demand Jetcan
						
						if ${Entity[${OnDemandHaulQueue.Peek.BeltID}](exists)}
						{
							
							Move:Object[${OnDemandHaulQueue.Peek.BeltID}]
							This:QueueState["Traveling", 1000]
							This:QueueState["PopulateTargetList", 2000, ${OnDemandHaulQueue.Peek.CharID}]
							This:QueueState["CheckTargetList", 50]
							This:QueueState["LootCans", 1000, ${OnDemandHaulQueue.Peek.CharID}]
							This:QueueState["DepopulateTargetList", 2000]
							This:QueueState["Haul"]
							return TRUE
						}
						
						break
				}
			
				break
				
			default
			
			Move:Bookmark[${Config.Pickup}]
			
		}
		
		if ${Config.DropoffType.Equal[Container]}
		{
			if ${Entity[Name = "${Config.DropoffContainerName}"](exists)}
			{
				Container:Set[${Entity[Name = "${Config.DropoffContainerName}"].ID}]
				if ${Entity[${Container}].Distance} > LOOT_RANGE
				{
					Move:Approach[${Container}, LOOT_RANGE]
					return FALSE
				}
				else
				{
					if (${MyShip.UsedCargoCapacity} / ${MyShip.CargoCapacity}) > 0.10
					{
						if !${EVEWindow[ByName, Inventory].ChildWindowExists[${Container}]}
						{
							UI:Update["obj_Hauler", "Opening ${Config.DropoffContainerName}", "g"]
							Entity[${Container}]:Open
							return FALSE
						}
						if !${EVEWindow[ByItemID, ${Container}](exists)}
						{
							EVEWindow[ByName, Inventory]:MakeChildActive[${Container}]
							return FALSE
						}
						;UI:Update["obj_Hauler", "Unloading to ${Config.DropoffContainerName}", "g"]
						Cargo:PopulateCargoList[SHIP]
						Cargo:MoveCargoList[SHIPCORPORATEHANGAR, "", ${Container}]
						This:QueueState["Idle", 1000]
						This:QueueState["Haul"]
						return TRUE
					}
				}
			}
		}
		
		if ${Ship.ModuleList_GangLinks.ActiveCount} < ${Ship.ModuleList_GangLinks.Count}
		{
			Ship.ModuleList_GangLinks:ActivateCount[${Math.Calc[${Ship.ModuleList_GangLinks.Count} - ${Ship.ModuleList_GangLinks.ActiveCount}]}]
		}
		
	
		return TRUE
	}
	
	method PopulateTargetList(int64 ID)
	{
		variable int64 CharID = ${Entity[${ID}].CharID}
		IR_Cans:ClearQueryString
		IR_Cans:AddQueryString["GroupID==GROUP_CARGOCONTAINER && OwnerID == ${CharID}"]
		IR_Cans.DistanceTarget:Set[${ID}]
		OOR_Cans:ClearQueryString
		OOR_Cans:AddQueryString["GroupID==GROUP_CARGOCONTAINER && OwnerID == ${CharID}"]
		OOR_Cans.DistanceTarget:Set[${ID}]
	}	

	method OrcaCargoUpdate(float value)
	{
		OrcaCargo:Set[${value}]
		UIElement[obj_HaulerOrcaCargo@Hauler@ComBotTab@ComBot]:SetText[Orca Cargo Hold: ${OrcaCargo.Round} m3]
	}
	
}	


objectdef obj_HaulerUI inherits obj_State
{


	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
	}
	
	method Start()
	{
		if ${This.IsIdle}
		{
			This:QueueState["OpenCargoHold"]
			This:QueueState["UpdateBookmarkLists", 5]
		}
	}
	
	method Stop()
	{
		This:Clear
	}

	member:bool OpenCargoHold()
	{
		if !${EVEWindow[ByName, "Inventory"](exists)}
		{
			UI:Update["obj_Hauler", "Opening inventory", "g"]
			MyShip:OpenCargo[]
			return FALSE
		}
		return TRUE
	}
	
	member:bool UpdateBookmarkLists()
	{
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator

		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[BookmarkIterator]
		
		UIElement[DropoffList@DropoffFrame@Hauler_Frame@ComBot_Hauler]:ClearItems
		if ${BookmarkIterator:First(exists)}
			do
			{	
				if ${UIElement[Dropoff@DropoffFrame@Hauler_Frame@ComBot_Hauler].Text.Length}
				{
					if ${BookmarkIterator.Value.Label.Left[${Hauler.Config.Dropoff.Length}].Equal[${Hauler.Config.Dropoff}]}
						UIElement[DropoffList@DropoffFrame@Hauler_Frame@ComBot_Hauler]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
				else
				{
					UIElement[DropoffList@DropoffFrame@Hauler_Frame@ComBot_Hauler]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
			}
			while ${BookmarkIterator:Next(exists)}
			
		UIElement[PickupList@PickupFrame@Hauler_Frame@ComBot_Hauler]:ClearItems
		if ${BookmarkIterator:First(exists)}
			do
			{	
				if ${UIElement[Pickup@PickupFrame@Hauler_Frame@ComBot_Hauler].Text.Length}
				{
					if ${BookmarkIterator.Value.Label.Left[${Hauler.Config.Pickup.Length}].Equal[${Hauler.Config.Pickup}]}
						UIElement[PickupList@PickupFrame@Hauler_Frame@ComBot_Hauler]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
				else
				{
					UIElement[PickupList@PickupFrame@Hauler_Frame@ComBot_Hauler]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
			}
			while ${BookmarkIterator:Next(exists)}
			
		return FALSE
	}

}