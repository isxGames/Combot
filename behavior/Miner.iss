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

objectdef obj_Miner inherits obj_State
{
	variable obj_TargetList Asteroids
	variable bool WarpToOrca=FALSE

	method Initialize()
	{
		This[parent]:Initialize
		LavishScript:RegisterEvent[ComBot_Orca_InBelt]
		Event[ComBot_Orca_InBelt]:AttachAtom[This:OrcaInBelt]
		PulseFrequency:Set[500]
		Asteroids.LockOutOfRange:Set[FALSE]
	}

	method Shutdown()
	{
		Event[ComBot_Orca_InBelt]:DetachAtom[This:OrcaInBelt]
	}	
	
	method Start()
	{
		This:PopulateTargetList

		UI:Update["obj_Miner", "Started", "g"]
		This:AssignStateQueueDisplay[DebugStateList@Debug@ComBotTab@ComBot]
		if ${This.IsIdle}
		{
			This:QueueState["Mine"]
		}
	}
	
	method Stop()
	{
		This:DeactivateStateQueueDisplay

		UI:Update["obj_Miner", "Stopped", "r"]
		This:Clear
	}
	
	method PopulateTargetList()
	{
		Asteroids:ClearQueryString
		
		variable iterator OreTypeIterator
		if ${Config.Miner.IceMining}
		{
			Config.Miner.IceTypesRef:GetSettingIterator[OreTypeIterator]
		}
		else
		{
			Config.Miner.OreTypesRef:GetSettingIterator[OreTypeIterator]
		}

		if ${OreTypeIterator:First(exists)}
		{		
			do
			{
				Asteroids:AddQueryString[CategoryID==CATEGORYID_ORE && Name =- "${OreTypeIterator.Key}"]
			}
			while ${OreTypeIterator:Next(exists)}
		}
		else
		{
			echo "WARNING: obj_Miner: Ore Type list is empty, please check config"
		}
	}
	
	member:bool OpenCargoHold()
	{
		if !${EVEWindow[ByName, "Inventory"](exists)}
		{
			UI:Update["obj_Miner", "Opening inventory", "g"]
			MyShip:OpenCargo[]
			return FALSE
		}
		return TRUE
	}
	
	member:bool CheckCargoHold()
	{
		Profiling:StartTrack["Miner_CheckCargohold"]
		switch ${Config.Miner.Dropoff_Type}
		{
			case Orca
				if !${Entity[Name = "${Config.Miner.Container_Name}"](exists)} && ${Local[${Config.Miner.Container_Name}].ToFleetMember(exists)} && ${This.WarpToOrca}
				{
					UI:Update["obj_Miner", "Warping to ${Local[${Config.Miner.Container_Name}].ToFleetMember.ToPilot.Name}", "g"]
					Local[${Config.Miner.Container_Name}].ToFleetMember:WarpTo
					Client:Wait[5000]
					This:Clear
					Asteroids.LockedTargetList:Clear
					This:QueueState["Traveling", 1000]
					This:QueueState["Mine"]
				}
				if !${This.WarpToOrca}
				{
					This:Clear
				}
				break
			case Container
				if (${MyShip.UsedCargoCapacity} / ${MyShip.CargoCapacity}) >= ${Config.Miner.Threshold} * .01
				{
					UI:Update["obj_Miner", "Unload trip required", "g"]
					if ${Config.Miner.OrcaMode}
					{
						relay all -event ComBot_Orca_InBelt FALSE
					}
					Bookmarks:StoreLocation
					This:Clear
					Asteroids.LockedTargetList:Clear
					Move:Bookmark[${Config.Miner.Dropoff}]
					This:QueueState["Traveling", 1000]
					This:QueueState["Mine"]
				}
				break
			case No Dropoff
				break
			case Jetcan
				break
			default
				if (${MyShip.UsedCargoCapacity} / ${MyShip.CargoCapacity}) >= ${Config.Miner.Threshold} * .01
				{
					UI:Update["obj_Miner", "Unload trip required", "g"]
					if ${Client.InSpace}
					{
						Bookmarks:StoreLocation
					}
					This:Clear
					Asteroids.LockedTargetList:Clear
					Move:Bookmark[${Config.Miner.Dropoff}]
					This:QueueState["Traveling", 1000]
					This:QueueState["PrepOffload", 1000]
					This:QueueState["Offload", 1000]
					This:QueueState["StackItemHangar", 1000]
					This:QueueState["GoToMiningSystem", 1000]
					This:QueueState["Traveling", 1000]
					This:QueueState["Mine"]
				}
				break
		}
		Profiling:EndTrack
		return TRUE;
	}

	member:bool Traveling()
	{
		if ${Move.Traveling} || ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}
		return TRUE
	}
	
	member:bool PrepOffload()
	{
		if ${Client.InSpace}
		{
			return TRUE
		}
		if !${EVEWindow[ByName, "Inventory"](exists)}
		{
			UI:Update["obj_Miner", "Opening inventory", "g"]
			MyShip:OpenCargo[]
			return FALSE
		}
		switch ${Config.Miner.Dropoff_Type}
		{
			case Personal Hangar
				break
			default
				if !${EVEWindow[ByName, Inventory].ChildWindowExists[Corporation Hangars]}
				{
					UI:Update["obj_Miner", "Delivery Location: Corporate Hangars child not found", "r"]
					UI:Update["obj_Miner", "Closing inventory to fix possible EVE bug", "y"]
					EVEWindow[ByName, Inventory]:Close
					return FALSE
				}
				EVEWindow[ByName, Inventory]:MakeChildActive[Corporation Hangars]
				break
		}
		return TRUE
	}
	member:bool Offload()
	{
		Profiling:StartTrack["Miner_Offload"]
		UI:Update["obj_Miner", "Unloading cargo", "g"]
		Cargo:PopulateCargoList[SHIP]
		switch ${Config.Miner.Dropoff_Type}
		{
			case Personal Hangar
				Cargo:MoveCargoList[HANGAR]
				break
			default
				Cargo:MoveCargoList[CORPORATEHANGAR, ${Config.Miner.Dropoff_Type}]
				break
		}
		Profiling:EndTrack
		return TRUE
	}
	
	member:bool StackItemHangar()
	{
		Profiling:StartTrack["Miner_StackItemHanger"]
		variable int64 Orca
		if !${EVEWindow[ByName, "Inventory"](exists)}
		{
			UI:Update["obj_Miner", "Making sure inventory is open", "g"]
			MyShip:Open
			Profiling:EndTrack
			return FALSE
		}

		;UI:Update["obj_Miner", "Stacking dropoff container", "g"]
		switch ${Config.Miner.Dropoff_Type}
		{
			case Personal Hangar
				EVE:StackItems[MyStationHangar, Hangar]
				break
			case Orca
				if ${Entity[Name = "${Config.Miner.Container_Name}"](exists)}
				{
					EVE:StackItems[${Entity[Name = "${Config.Miner.Container_Name}"].ID}, CorpHangars]
				}
				break
			case Container
				if ${Entity[Name = "${Config.Miner.Container_Name}"](exists)}
				{
					EVE:StackItems[${Entity[Name = "${Config.Miner.Container_Name}"].ID}, CorpHangars]
				}
				break
			default
				EVE:StackItems[MyStationCorporateHangar, StationCorporateHangar, "${Config.Miner.Dropoff_Type.Escape}"]
				break
		}
		Profiling:EndTrack
		return TRUE
	}
	
	member:bool GoToMiningSystem()
	{
		if !${EVE.Bookmark[${Config.Miner.MiningSystem}](exists)}
		{
			UI:Update["obj_Miner", "No mining system defined!  Check your settings", "r"]
		}
		if ${EVE.Bookmark[${Config.Miner.MiningSystem}].SolarSystemID} != ${Me.SolarSystemID}
		{
			Move:System[${EVE.Bookmark[${Config.Miner.MiningSystem}].SolarSystemID}]
		}
		return TRUE
	}
	
	member:bool RemoveStoredBookmark()
	{
		Bookmarks:RemoveStoredLocation
		return TRUE
	}

	member:bool MoveToBelt()
	{
		if ${Bookmarks.StoredLocationExists}
		{
			UI:Update["obj_Miner","Returning to last location (${Bookmarks.StoredLocation})", "g"]
			Move:Bookmark["${Bookmarks.StoredLocation}"]
			return TRUE
		}
	
		if ${Config.Miner.UseBookmarks}
		{
			variable index:bookmark BookmarkIndex
			variable int RandomBelt
			EVE:GetBookmarks[BookmarkIndex]

			while ${BookmarkIndex.Used} > 0
			{
				RandomBelt:Set[${Math.Rand[${BookmarkIndex.Used}]:Inc[1]}]

				if ${Config.Miner.IceMining}
				{
					prefix:Set[${Config.Miner.IceBeltPrefix}]
				}
				else
				{
					prefix:Set[${Config.Miner.BeltPrefix}]
				}

				Label:Set[${BookmarkIndex[${RandomBelt}].Label}]

				if (${BookmarkIndex[${RandomBelt}].SolarSystemID} != ${Me.SolarSystemID} || \
					${Label.Left[${prefix.Length}].NotEqual[${prefix}]})
				{
					BookmarkIndex:Remove[${RandomBelt}]
					BookmarkIndex:Collapse
					continue
				}

				Move:Bookmark[${BookmarkIndex[${RandomBelt}].Label}]

				return TRUE
			}	
		}
		else
		{
			if !${Client.InSpace}
			{
				Move:Undock
				return FALSE
			}
			variable int curBelt
			variable index:entity Belts
			variable string beltsubstring
			variable int TryCount
			if ${Config.Miner.IceMining}
			{
				beltsubstring:Set["ICE FIELD"]
			}
			else
			{
				beltsubstring:Set["ASTEROID BELT"]
			}

			EVE:QueryEntities[Belts, "GroupID = GROUP_ASTEROIDBELT"]
			Belts:GetIterator[BeltIterator]

			do
			{
				curBelt:Set[${Math.Rand[${Belts.Used}]:Inc[1]}]
				TryCount:Inc
				if ${TryCount} > ${Math.Calc[${Belts.Used} * 10]}
				{
					UI:Update["obj_Miner", "All belts empty!", "r"]

					return TRUE
				}
			}
			while ( !${Belts[${curBelt}].Name.Find[${beltsubstring}](exists)} || \
					${This.IsBeltEmpty[${Belts[${curBelt}].Name}]} )

			Move:Object[${Entity[${Belts[${curBelt}].ID}]}]
			return TRUE
		}
	}

	member:bool Undock()
	{
		Move:Undock
		return TRUE
	}
	
	member:bool Mine()
	{
		Profiling:StartTrack["Miner_Mine"]
		This:Clear
		This:QueueState["OpenCargoHold", 10]

		if !${Client.InSpace}
		{
			This:QueueState["CheckCargoHold", 1000]
			This:QueueState["Undock"]
			This:QueueState["Mine"]
			Profiling:EndTrack
			return TRUE
		}
		
		if ${Me.ToEntity.Mode} == 3
		{
			Profiling:EndTrack
			return FALSE
		}
		
		variable int MaxTarget = ${Math.Calc[${MyShip.MaxLockedTargets} - 2]}
		if ${Math.Calc[${Me.MaxLockedTargets} - 2]} < ${MaxTarget}
		{
			MaxTarget:Set[${Math.Calc[${Me.MaxLockedTargets} - 2]}]
		}
		if ${Ship.ModuleList_MiningLaser.Count} < ${MaxTarget}
		{
			MaxTarget:Set[${Ship.ModuleList_MiningLaser.Count}]
		}
		
		
		Asteroids.MinLockCount:Set[${MaxTarget}]
		Asteroids.MaxRange:Set[${Ship.ModuleList_MiningLaser.Range}]
		
		if ${Config.Miner.OrcaMode}
		{
			Asteroids.AutoLock:Set[FALSE]
			Asteroids.AutoRelock:Set[FALSE]
			Asteroids.AutoRelockPriority:Set[FALSE]
			if ${Config.Miner.Dropoff_Type.Equal[Container]} && ${EVEWindow[ByName, Inventory].ChildUsedCapacity[ShipCorpHangar]} > 0
			{
				Cargo:PopulateCargoList[SHIPCORPORATEHANGAR]
				Cargo:MoveCargoList[SHIP]
				This:QueueState["Idle", 1000]
				This:QueueState["Mine"]
				Profiling:EndTrack
				return TRUE
			}
			if ${Config.Miner.Dropoff_Type.Equal[Jetcan]} && ${EVEWindow[ByName, Inventory].ChildUsedCapacity[ShipCorpHangar]} > 0
			{
				Cargo:PopulateCargoList[SHIPCORPORATEHANGAR]
				Cargo:MoveCargoList[SHIP]
				This:QueueState["Idle", 1000]
				This:QueueState["Mine"]
				Profiling:EndTrack
				return TRUE
			}
		}
		
		if ${Config.Miner.Dropoff_Type.Equal[Orca]} || ${Config.Miner.Dropoff_Type.Equal[Container]}
		{
			variable int64 Orca
			if ${Entity[Name = "${Config.Miner.Container_Name}"](exists)}
			{
				Orca:Set[${Entity[Name = "${Config.Miner.Container_Name}"].ID}]
				Asteroids.DistanceTarget:Set[${Orca}]
				if ${Entity[${Orca}].Distance} > LOOT_RANGE
				{
					Move:Approach[${Orca}, LOOT_RANGE]
					Profiling:EndTrack
					return FALSE
				}
				else
				{
					if (${MyShip.UsedCargoCapacity} / ${MyShip.CargoCapacity}) > 0.10
					{
						if !${EVEWindow[ByName, Inventory].ChildWindowExists[${Orca}]}
						{
							UI:Update["obj_Miner", "Opening ${Config.Miner.Container_Name}", "g"]
							Entity[${Orca}]:Open
							Profiling:EndTrack
							return FALSE
						}
						if !${EVEWindow[ByItemID, ${Orca}](exists)}
						{
							EVEWindow[ByName, Inventory]:MakeChildActive[${Orca}]
							Profiling:EndTrack
							return FALSE
						}
						;UI:Update["obj_Miner", "Unloading to ${Config.Miner.Container_Name}", "g"]
						Cargo:PopulateCargoList[SHIP]
						Cargo:MoveCargoList[SHIPCORPORATEHANGAR, "", ${Orca}]
						This:QueueState["Idle", 1000]
						This:QueueState["StackItemHangar"]
						This:QueueState["Mine"]
						Profiling:EndTrack
						return TRUE
					}
				}
			}
			else
			{
				Asteroids.DistanceTarget:Set[${MyShip.ID}]
			}
		}
		
		if !${Config.Miner.Dropoff_Type.Equal[Orca]}
		{
			Asteroids.DistanceTarget:Set[${MyShip.ID}]
		}
		
		if !${Config.Miner.OrcaMode}
		{
			Asteroids.AutoLock:Set[TRUE]
			Asteroids.AutoRelock:Set[TRUE]
			Asteroids.AutoRelockPriority:Set[TRUE]
		}

		
		if ${Config.Miner.Dropoff_Type.Equal[Jetcan]}
		{
			Jetcan:Enable
		}
		else
		{
			Jetcan:Disable
		}

		if !${Entity[CategoryID==CATEGORYID_ORE]}
		{
			if ${Config.Miner.OrcaMode}
			{
				relay all -event ComBot_Orca_InBelt FALSE
			}
			Drones:Recall
			UI:Update["obj_Miner", "No asteroids found, moving to a new belt", "g"]
			This:QueueState["CheckCargoHold", 1000]
			This:QueueState["GoToMiningSystem", 1000]
			This:QueueState["Traveling", 1000]
			This:QueueState["MoveToBelt", 1000]
			This:QueueState["Traveling", 1000]
			This:QueueState["RemoveStoredBookmark", 1000]
			This:QueueState["Mine"]
			Profiling:EndTrack
			return TRUE
		}

		if ${Config.Miner.OrcaMode}
		{
			relay all -event ComBot_Orca_InBelt TRUE
			relay all -event ComBot_Orca_Cargo ${EVEWindow[ByName, Inventory].ChildUsedCapacity[ShipCorpHangar]}
			if ${Config.Miner.IceMining}
			{
				Move:Approach[${Entity[CategoryID==CATEGORYID_ORE]}, 10000]
			}
			else
			{
				Move:Approach[${Entity[CategoryID==CATEGORYID_ORE]}, 8000]
			}
		}
		else
		{
			if ${Entity[CategoryID==CATEGORYID_ORE].Distance} > ${Math.Calc[${Ship.ModuleList_MiningLaser.Range} * (2/3)]}
			{
				Move:Approach[${Entity[CategoryID==CATEGORYID_ORE]}, ${Math.Calc[${Ship.ModuleList_MiningLaser.Range} * (1/2)]}]
			}
		}
		
		Drones:RemainDocked
		Drones:Defensive
		
		if ${Ship.ModuleList_GangLinks.ActiveCount} < ${Ship.ModuleList_GangLinks.Count}
		{
			Ship.ModuleList_GangLinks:ActivateCount[${Math.Calc[${Ship.ModuleList_GangLinks.Count} - ${Ship.ModuleList_GangLinks.ActiveCount}]}]
		}
		
		if ${Ship.ModuleList_MiningLaser.ActiveCount} < ${Ship.ModuleList_MiningLaser.Count}
		{
			This:QueueState["ActivateLasers", 2000]
			This:QueueState["Mine"]
			Profiling:EndTrack
			return TRUE
		}
		
		if !${Config.Miner.Dropoff_Type.Equal[No Dropoff]}
		{
			This:QueueState["CheckCargoHold"]
			This:QueueState["Mine"]
			Profiling:EndTrack
			return TRUE
		}
		Profiling:EndTrack
		return FALSE
	}


	member:bool ActivateLasers()
	{
		Profiling:StartTrack["Miner_ActivateLasers"]
		if  ${Ship.ModuleList_MiningLaser.ActiveCount} == ${Ship.ModuleList_MiningLaser.Count}
		{
			Profiling:EndTrack
			return TRUE
		}
		Asteroids:RequestUpdate
		variable iterator Roid
		variable int64 FirstRoid = -1
		variable int RoidActiveCount
		variable int GoodCount = 0
		Asteroids.LockedTargetList:GetIterator[Roid]
		
		if ${Roid:First(exists)}
		{
			do
			{
				if ${Roid.Value.ID(exists)}
				{
					GoodCount:Inc
					if ${FirstRoid.Equal[-1]}
					{
						FirstRoid:Set[${Roid.Value.ID}]
						echo roid active count ${Ship.ModuleList_MiningLaser.ActiveCountOn[${FirstRoid}]}
						RoidActiveCount:Set[${Ship.ModuleList_MiningLaser.ActiveCountOn[${FirstRoid}]}]
					}
					if ${RoidActiveCount} > ${Ship.ModuleList_MiningLaser.ActiveCountOn[${Roid.Value.ID}]}
					{
						FirstRoid:Set[${Roid.Value.ID}]
						RoidActiveCount:Set[${Ship.ModuleList_MiningLaser.ActiveCountOn[${FirstRoid}]}]
					}
					if ${Roid.Value.Distance} > ${Ship.ModuleList_MiningLaser.Range}
					{
						Move:Approach[${Roid.Value.ID}, ${Ship.ModuleList_MiningLaser.Range}]
						Profiling:EndTrack
						return FALSE
					}
					if ${Config.Miner.IceMining}
					{
						UI:Update["obj_Miner", "Activating ${Ship.ModuleList_MiningLaser.InActiveCount} laser(s) on ${Roid.Value.Name} (${ComBot.MetersToKM_Str[${Roid.Value.Distance}]})", "y"]
						Ship.ModuleList_MiningLaser:ActivateCount[${Ship.ModuleList_MiningLaser.InActiveCount}, ${Roid.Value.ID}]
						Profiling:EndTrack
						return TRUE
					}
					else
					{
						if !${Ship.ModuleList_MiningLaser.IsActiveOn[${Roid.Value.ID}]}
						{
							UI:Update["obj_Miner", "Activating 1 laser on ${Roid.Value.Name} (${ComBot.MetersToKM_Str[${Roid.Value.Distance}]})", "y"]
							Ship.ModuleList_MiningLaser:Activate[${Roid.Value.ID}]
							Profiling:EndTrack
							return FALSE
						}
					}
				}
			}
			while ${Roid:Next(exists)}
		}
		
		if ${Asteroids.MinLockCount} <= ${GoodCount}
		{
			Ship.ModuleList_MiningLaser:Activate[${FirstRoid}]
		}
		
		Profiling:EndTrack
		return FALSE
	}
	
	member:bool ExpandContainer()
	{
		variable int64 Orca
		if ${Entity[Name = "${Config.Miner.Container_Name}"](exists)}
		{
			Orca:Set[${Entity[Name = "${Config.Miner.Container_Name}"].ID}]
			if ${EVEWindow[ByName, Inventory].ChildWindowExists[${Orca}]}
			{
				${EVEWindow[ByName, Inventory]:OpenChildAsNewWindow[${Orca}]
			}
		}
		return TRUE
	}
	
	method OrcaInBelt(bool value)
	{
		WarpToOrca:Set[${value}]
	}
	
}	