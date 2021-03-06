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

objectdef obj_Configuration_Ratter
{
	variable string SetName = "Ratter"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			UI:Update["Configuration", " ${This.SetName} settings missing - initializing", "o"]
			This:Set_Default_Values[]
		}
		UI:Update["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	member:settingsetref CommonRef()
	{
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}]}
	}


	method Set_Default_Values()
	{
		BaseConfig.BaseRef:AddSet[${This.SetName}]

		This.CommonRef:AddSetting[Substring,"Anom:"]
		This.CommonRef:AddSetting[SalvagePrefix,"Salvage:"]
		This.CommonRef:AddSetting[RattingSystem,""]
		This.CommonRef:AddSetting[Dropoff,""]
		This.CommonRef:AddSetting[DropoffType,""]
		This.CommonRef:AddSetting[DropoffSubType,""]
		This.CommonRef:AddSetting[DropoffContainer,""]
		This.CommonRef:AddSetting[SpeedTankDistance,5000]
		This.CommonRef:AddSetting[Locks,4]
		This.CommonRef:AddSetting[TetherPilot,""]

	}

	Setting(bool, AssistOnly, SetAssistOnly)
	Setting(bool, WarpToAnom, SetWarpToAnom)
	Setting(bool, BeltRat, SetBeltRat)
	Setting(bool, Salvage, SetSalvage)
	Setting(bool, SpeedTank, SetSpeedTank)
	Setting(bool, SpeedTankKeepRange, SetSpeedTankKeepRange)
	Setting(bool, Tether, SetTether)
	Setting(bool, KeepRange, SetKeepRange)
	Setting(bool, Squat, SetSquat)
	Setting(bool, DroneControl, SetDroneControl)
	Setting(int, Warp, SetWarp)
	Setting(int, Locks, SetLocks)
	Setting(int, Threshold, SetThreshold)
	Setting(int, SpeedTankDistance, SetSpeedTankDistance)
	Setting(int, AmmoSupply, SetAmmoSupply)
	Setting(int, AmmoCap, SetAmmoCap)
	Setting(string, RattingSystem, SetRattingSystem)
	Setting(string, Substring, SetSubstring)
	Setting(string, Dropoff, SetDropoff)
	Setting(string, DropoffType, SetDropoffType)
	Setting(string, DropoffSubType, SetDropoffSubType)
	Setting(string, DropoffContainer, SetDropoffContainer)
	Setting(string, SalvagePrefix, SetSalvagePrefix)
	Setting(string, TetherPilot, SetTetherPilot)
	Setting(string, Ammo, SetAmmo)
}

objectdef obj_Ratter inherits obj_State
{
	variable obj_Configuration_Ratter Config
	variable obj_RatterUI LocalUI

	variable obj_TargetList Rats
	variable index:entity Belts
	variable index:bookmark Bookmarks
	variable int64 CurrentTarget
	variable int64 FirstWreck=0
	variable int FinishedDelay
	variable int64 Orbiting

	method Initialize()
	{
		This[parent]:Initialize
		PulseFrequency:Set[1500]

		DynamicAddBehavior("Ratter", "Ratter")
	}

	method Shutdown()
	{
		This:DeactivateStateQueueDisplay
		This:Clear
	}

	method Start()
	{
		variable iterator classIterator
		variable iterator groupIterator
		variable string groups = ""
		variable string seperator = ""

		Rats:ClearQueryString


		PriorityTargets.Scramble:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		Rats:AddQueryString["Distance < 150000 && IsNPC && !IsMoribund && (${groups})"]

		seperator:Set[""]
		groups:Set[""]
		PriorityTargets.Neut:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		Rats:AddQueryString["Distance < 150000 && IsNPC && !IsMoribund && (${groups})"]

		seperator:Set[""]
		groups:Set[""]
		PriorityTargets.ECM:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		Rats:AddQueryString["Distance < 150000 && IsNPC && !IsMoribund && (${groups})"]



		NPCData.BaseRef:GetSetIterator[classIterator]
		if ${classIterator:First(exists)}
		{
			do
			{
				seperator:Set[""]
				groups:Set[""]
				classIterator.Value:GetSettingIterator[groupIterator]
				if ${groupIterator:First(exists)}
				{
					do
					{
						groups:Concat["${seperator}GroupID = ${groupIterator.Key}"]
						seperator:Set[" || "]
					}
					while ${groupIterator:Next(exists)}
				}
				Rats:AddQueryString["Distance < 150000 && IsNPC && !IsMoribund && (${groups})"]
			}
			while ${classIterator:Next(exists)}
		}

		Rats:AddTargetingMe
		Rats:SetIPCName[Rats]
		Rats.UseIPC:Set[TRUE]
		Rats.AutoLock:Set[FALSE]
		DroneControl.DroneTargets.AutoLock:Set[FALSE]


		UI:Update["obj_Ratter", "Started", "g"]
		This:AssignStateQueueDisplay[DebugStateList@Debug@ComBotTab@ComBot]
		if ${This.IsIdle}
		{
			if ${Config.AssistOnly}
			{
				This:QueueState["DropCloak", 50, TRUE]
				This:QueueState["Rat"]
			}
			else
			{
				This:QueueState["CheckCargoHold"]
			}
		}
	}

	method Stop()
	{
		This:DeactivateStateQueueDisplay
		This:Clear
		noop This.DropCloak[FALSE]
	}


	member:bool CheckCargoHold()
	{
		variable index:item Items
		variable iterator ItemIterator
		variable int AmmoCount=0
		variable string Reload=""

		if !${Client.Inventory}
		{
			return FALSE
		}

		MyShip:GetCargo[Items]
		Items:GetIterator[ItemIterator]

		if ${Config.Ammo.Length} > 0
		{
			if ${ItemIterator:First(exists)}
				do
				{
					if ${ItemIterator.Value.Name.Equal[${Config.Ammo}]}
					{
						AmmoCount:Inc[${ItemIterator.Value.Quantity}]
					}
				}
				while ${ItemIterator:Next(exists)}
			Reload:Set[":Load[Name =- \"${Config.Ammo}\", ${Config.AmmoCap}]"]
		}


		if 	${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} / ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} > ${Config.Threshold} * .01 ||\
			${AmmoCount} < ${Config.AmmoSupply}
		{
			UI:Update["Ratter", "Unload/Reload trip required", "g"]
			Cargo:At[${Config.Dropoff},${Config.DropoffType},${Config.DropoffSubType}, ${Config.DropoffContainer}]:Unload${Reload}
			This:QueueState["Traveling"]
			This:QueueState["CheckCargoHold"]
			return TRUE
		}

		This:QueueState["GoToRattingSystem"]
		This:QueueState["Traveling"]
		This:QueueState["Reload"]
		This:QueueState["ClearOldBookmarks"]
		This:QueueState["MoveToNewRatLocation"]
		This:QueueState["Traveling"]
		This:QueueState["VerifyRatLocation"]
		This:QueueState["InitialUpdate"]
		This:QueueState["Updated"]
		This:QueueState["Log", 10, "Ratting, g"]
		This:QueueState["DropCloak", 50, TRUE]
		This:QueueState["Rat"]
		This:QueueState["DropCloak", 50, FALSE]
		return TRUE
	}

	member:bool Log(string text, string color)
	{
		UI:Update["Ratter", "${text}", "${color}"]
		return TRUE
	}

	member:bool GoToRattingSystem()
	{
		if !${EVE.Bookmark[${Config.RattingSystem}](exists)}
		{
			UI:Update["Ratter", "No ratting system defined!  Check your settings", "r"]
		}
		if ${EVE.Bookmark[${Config.RattingSystem}].SolarSystemID} != ${Me.SolarSystemID}
		{
			Move:System[${EVE.Bookmark[${Config.RattingSystem}].SolarSystemID}]
		}
		return TRUE
	}


	member:bool Traveling()
	{
		if ${Move.Traveling} || ${Cargo.Processing} || ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}
		return TRUE
	}

	member:bool Reload()
	{
		EVE:Execute[CmdReloadAmmo]
		return TRUE
	}

	member:bool RemoveSavedSpot()
	{
		Move:RemoveSavedSpot
		return TRUE
	}

	member:bool ClearOldBookmarks(bool RefreshBookmarks=FALSE)
	{
		if !${RefreshBookmarks}
		{
			EVE:RefreshBookmarks
			This:InsertState["ClearOldBookmarks", 3000, TRUE]
			return TRUE
		}

		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator
		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[BookmarkIterator]

		if ${BookmarkIterator:First(exists)}
		do
		{
			if ${BookmarkIterator.Value.Label.Left[${Config.SalvagePrefix.Length}].Upper.Equal[${Config.SalvagePrefix}]} && \
				${BookmarkIterator.Value.CreatorID} == ${Me.CharID}
			{
				if ${BookmarkIterator.Value.Created.AsInt64} + 72000000000 < ${EVETime.AsInt64}
				{
					UI:Update["Ratter", "Removing old bookmark - ${BookmarkIterator.Value.Label}", "o", TRUE]
					BookmarkIterator.Value:Remove
					return FALSE
				}
			}
		}
		while ${BookmarkIterator:Next(exists)}

		return TRUE
	}

	member:bool MoveToNewRatLocation()
	{
		variable int Distance
		Distance:Set[${Math.Calc[${Config.Warp} * 1000]}]

		if ${Move.SavedSpotExists}
		{
			Move:GotoSavedSpot
			This:InsertState["RemoveSavedSpot"]
			This:InsertState["Traveling", 2000]
			This:InsertState["Reload"]
			return TRUE
		}

		if ${Config.Tether}
		{
			if !${Entity[Name =- "${Config.TetherPilot}"](exists)}
			{
				Move:Fleetmember[${Local["${Config.TetherPilot}"].ID}, TRUE, ${Distance}]
				return TRUE
			}
		}

		if ${Bookmarks.Used} == 0 && !${Config.WarpToAnom} && !${Config.Tether}
		{
			EVE:GetBookmarks[Bookmarks]
			Bookmarks:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID == ${Me.SolarSystemID}]}, FALSE]
			Bookmarks:RemoveByQuery[${LavishScript.CreateQuery[Label =- "${Config.Substring}"]}, FALSE]
			Bookmarks:Collapse
			if ${Bookmarks.Used} == 0
			{
				if ${Config.BeltRat}
				{
					if !${Client.InSpace}
					{
						Move:Undock
						return FALSE
					}

					if ${Belts.Used} == 0
					{
						EVE:QueryEntities[Belts, "GroupID = GROUP_ASTEROIDBELT"]
					}

					Move:Object[${Entity[${Belts[1].ID}]}, ${Distance}, TRUE]
					Belts:Remove[1]
					Belts:Collapse
					return TRUE
				}
				else
				{
					Move:Bookmark[${Config.Dropoff}, TRUE, 0, TRUE]
					This:Clear
					This:QueueState["Traveling"]
					This:QueueState["CheckCargoHold"]
					return TRUE
				}
			}
		}
		elseif !${Config.WarpToAnom} && !${Config.Tether}
		{
			UI:Update["Ratter", "Removing ${Bookmarks.Get[1].Label}", "g"]
			Bookmarks.Get[1]:Remove
			Bookmarks:Clear
			return FALSE
		}

		if ${Config.WarpToAnom}
		{
			if !${Client.InSpace}
			{
				Move:Undock

				This:InsertState["MoveToNewRatLocation"]
				This:InsertState["Reload"]
				This:InsertState["Idle", 20000]
				return TRUE
			}

			dotnet WarpToAnom WarpToAnom ${Distance}
			This:InsertState["Idle", 60000]
			return TRUE
		}
		elseif !${Config.Tether}
		{
			Move:Bookmark[${Bookmarks.Get[1].Label}, TRUE, ${Distance}, TRUE]
		}
		return TRUE

	}


	member:bool VerifyRatLocation()
	{
		DroneControl:Recall
		if ${Busy.IsBusy}
		{
			return FALSE
		}
		if ${Config.Tether}
		{
			if !${Entity[Name =- "${Config.TetherPilot}"](exists)}
			{
				UI:Update["Ratter", "Separated from Tether Pilot", "g"]
				This:InsertState["VerifyRatLocation"]
				This:InsertState["Traveling"]
				This:InsertState["MoveToNewRatLocation"]
				return TRUE
			}
		}
		if ${Entity[CategoryID == CATEGORYID_SHIP && IsPC && !IsFleetMember && OwnerID != ${Me.CharID}]}
		{
			UI:Update["Ratter", "This location is occupied, going to next", "g"]
			This:InsertState["VerifyRatLocation"]
			This:InsertState["Traveling"]
			This:InsertState["MoveToNewRatLocation"]
		}
		return TRUE
	}


	member:bool InitialUpdate()
	{
		UI:Update["Ratter", "Waiting for 60 seconds for rats", "g"]
		FinishedDelay:Set[${Math.Calc[${LavishScript.RunningTime} + (60000)]}]
		FirstWreck:Set[0]
		Rats:RequestUpdate
		return TRUE
	}

	member:bool Updated()
	{
		if ${Me.ToEntity.Mode} == 3
		{
			This:InsertState["Updated"]
			This:InsertState["InitialUpdate"]
			This:InsertState["VerifyRatLocation"]
			This:InsertState["Traveling"]
			This:InsertState["MoveToNewRatLocation"]
			This:InsertState["Traveling"]
			return TRUE
		}
		Rats:RequestUpdate
		if ${Rats.TargetList.Used} > 0
		{
			UI:Update["Ratter", "Found rats on grid", "g"]
			FinishedDelay:Set[${Math.Calc[${LavishScript.RunningTime} + (10000)]}]
			return TRUE
		}
		if ${Config.Tether} && !${Entity[Name =- "${Config.TetherPilot}"](exists)}
		{
			UI:Update["Ratter", "Tether pilot not on grid", "g"]
			FinishedDelay:Set[${Math.Calc[${LavishScript.RunningTime} + (10000)]}]
			return TRUE
		}
		if ${LavishScript.RunningTime} > ${FinishedDelay}
		{
			This:InsertState["Updated"]
			This:InsertState["InitialUpdate"]
			This:InsertState["VerifyRatLocation"]
			This:InsertState["Traveling"]
			This:InsertState["MoveToNewRatLocation"]
			This:InsertState["Traveling"]
			return TRUE
		}
	}

	member:bool DropCloak(bool arg)
	{
		AutoModule.DropCloak:Set[${arg}]
		return TRUE
	}

	member:bool Rat(bool RefreshBookmarks=FALSE)
	{
		if !${Client.InSpace}
		{
			if ${Config.AssistOnly}
			{
				This:QueueState["DropCloak", 50, TRUE]
				This:QueueState["Rat"]
			}
			else
			{
				This:QueueState["CheckCargoHold"]
			}
			return TRUE
		}

		if !${Client.Inventory}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == 3
		{
			FirstWreck:Set[0]
			return FALSE
		}
		if ${RefreshBookmarks}
		{
			EVE:RefreshBookmarks
			This:InsertState["Rat"]
			return TRUE
		}
		if (!${Busy.IsBusy} && !${Rats.TargetList.Used} && ${LavishScript.RunningTime} > ${FinishedDelay}) || (${Config.Tether} && !${Entity[Name =- "${Config.TetherPilot}"](exists)})
		{
			variable bool Bookmarked=FALSE
			variable index:bookmark Bookmarks
			variable iterator BookmarkIterator
			EVE:GetBookmarks[Bookmarks]
			Bookmarks:GetIterator[BookmarkIterator]
			if ${BookmarkIterator:First(exists)}
				do
				{
					if 	${BookmarkIterator.Value.JumpsTo} == 0 &&\
						${BookmarkIterator.Value.Distance} < WARP_RANGE &&\
						${BookmarkIterator.Value.Label.Find[${Config.SalvagePrefix}]}
					{
						Bookmarked:Set[TRUE]
					}
				}
				while ${BookmarkIterator:Next(exists)}

			if 	${Entity[GroupID==GROUP_WRECK && HaveLootRights](exists)} &&\
				${Config.Salvage} &&\
				!${Entity[CategoryID == CATEGORYID_SHIP && IsPC && !IsFleetMember && OwnerID != ${Me.CharID}]} &&\
				!${Bookmarked} &&\
				!${Entity[CategoryID = CATEGORYID_ENTITY && IsNPC && !IsMoribund && !(GroupID = GROUP_CONCORDDRONE || GroupID = GROUP_CONVOYDRONE || GroupID = GROUP_CONVOY || GroupID = GROUP_LARGECOLLIDABLEOBJECT || GroupID = GROUP_LARGECOLLIDABLESHIP || GroupID = GROUP_SPAWNCONTAINER || GroupID = CATEGORYID_ORE || GroupID = GROUP_LARGECOLLIDABLESTRUCTURE)]}
			{
				UI:Update["Ratter", "Bookmarking ${Entity[GroupID==GROUP_WRECK && HaveLootRights].Name}", "g"]
				Entity[GroupID==GROUP_WRECK && HaveLootRights]:CreateBookmark["${Config.SalvagePrefix} ${EVETime.Time.Left[-3].Replace[":",""]}","","Corporation Locations"]
				This:InsertState["Rat", 1500, TRUE]
				return TRUE
			}
			Rats.AutoLock:Set[FALSE]
			DroneControl.DroneTargets.AutoLock:Set[FALSE]


			if ${Config.AssistOnly}
			{
				FirstWreck:Set[0]
			}
			else
			{
				This:QueueState["CheckCargoHold"]
				return TRUE
			}
		}

		variable index:item Items
		variable iterator ItemIterator
		variable int AmmoCount=0

		MyShip:GetCargo[Items]
		Items:GetIterator[ItemIterator]

		if ${Config.Ammo.Length} > 0
		{
			if ${ItemIterator:First(exists)}
				do
				{
					if ${ItemIterator.Value.Name.Equal[${Config.Ammo}]}
					{
						AmmoCount:Inc[${ItemIterator.Value.Quantity}]
					}
				}
				while ${ItemIterator:Next(exists)}
		}

		if 	${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} / ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} > ${Config.Threshold} * .01 ||\
			${AmmoCount} < ${Config.AmmoSupply}
		{
			Move:SaveSpot
			This:QueueState["CheckCargoHold"]
			return TRUE
		}


		Rats.MinLockCount:Set[${Config.Locks}]
		Rats.AutoLock:Set[TRUE]
		DroneControl.DroneTargets.AutoLock:Set[TRUE]
		Rats:RequestUpdate

		variable string ModuleToUse

		if ${Config.DroneControl}
		{
			ModuleToUse:Set[DroneControl.DroneTargets]
		}
		else
		{
			ModuleToUse:Set[Rats]
		}


		if ${FirstWreck} == 0
		{
			if ${Entity[GroupID==GROUP_WRECK && HaveLootRights](exists)}
			{
				FirstWreck:Set[${Entity[GroupID==GROUP_WRECK && HaveLootRights].ID}]
				if ${Config.Salvage}
				{
					Entity[${FirstWreck}]:SetName[This salvage site belongs to ${Me.Name}]
				}
			}
		}

		if ${Config.Squat}
		{
			if ${FirstWreck}
			{
				if ${Config.SpeedTank}
				{
					if ${Me.ToEntity.Mode} != 4
					{
						UI:Update["Ratter", "SpeedTank: Orbiting \ao${Entity[${FirstWreck}].Name}", "g"]
						Entity[${FirstWreck}]:Orbit[${Math.Calc[${Config.SpeedTankDistance}*1000+1000].Int}]
					}
				}
				else
				{
					Move:Approach[${FirstWreck}, 2000]
				}
			}
		}
		elseif ${Config.SpeedTank}
		{
			if ${Entity[${CurrentTarget}](exists)}
			{
				if ${Config.SpeedTank}
				{
					if ${Config.SpeedTankKeepRange}
					{
						if ${Me.ToEntity.Mode} != 1
						{
							UI:Update["Ratter", "SpeedTank: Keeping \ao${Entity[${CurrentTarget}].Name} at range", "g"]
							Orbiting:Set[0]
							${ModuleToUse}.LockedAndLockingTargetList.Get[1]:KeepAtRange[${Math.Calc[${Config.SpeedTankDistance}*1000+1000].Int}]
						}
					}
					else
					{
						variable int64 CollisionDistance = 5000
						if ${Config.SpeedTankDistance} < 5000
						{
							CollisionDistance:Set[${Config.SpeedTankDistance}]
						}

						if ${Me.ToEntity.Mode} != 4
						{
							UI:Update["Ratter", "SpeedTank: Orbiting \ao${Entity[${CurrentTarget}].Name}", "g"]
							Orbiting:Set[0]
							${ModuleToUse}.LockedAndLockingTargetList.Get[1]:Orbit[${Math.Calc[${Config.SpeedTankDistance}*1000+1000].Int}]
						}
						elseif ${Entity[(GroupID==GROUP_LARGECOLLIDABLEOBJECT || GroupID==GROUP_LARGECOLLIDABLESHIP || GroupID==GROUP_LARGECOLLIDABLESTRUCTURE) && Distance < ${CollisionDistance}]} && \
								${Orbiting} != ${Entity[(GroupID==GROUP_LARGECOLLIDABLEOBJECT || GroupID==GROUP_LARGECOLLIDABLESHIP || GroupID==GROUP_LARGECOLLIDABLESTRUCTURE) && Distance < ${CollisionDistance}]}
						{
							UI:Update["Ratter", "SpeedTank: Orbiting \ao${Entity[(GroupID==GROUP_LARGECOLLIDABLEOBJECT || GroupID==GROUP_LARGECOLLIDABLESHIP || GroupID==GROUP_LARGECOLLIDABLESTRUCTURE) && Distance < ${CollisionDistance}].${CollisionDistance}}", "g"]
							Orbiting:Set[${Entity[(GroupID==GROUP_LARGECOLLIDABLEOBJECT || GroupID==GROUP_LARGECOLLIDABLESHIP || GroupID==GROUP_LARGECOLLIDABLESTRUCTURE) && Distance < ${CollisionDistance}]}]
							Entity[(GroupID==GROUP_LARGECOLLIDABLEOBJECT || GroupID==GROUP_LARGECOLLIDABLESHIP || GroupID==GROUP_LARGECOLLIDABLESTRUCTURE) && Distance < ${CollisionDistance}]:Orbit[${CollisionDistance}+5000]
						}
						elseif !${Entity[(GroupID==GROUP_LARGECOLLIDABLEOBJECT || GroupID==GROUP_LARGECOLLIDABLESHIP || GroupID==GROUP_LARGECOLLIDABLESTRUCTURE) && Distance < ${CollisionDistance} + 3000]} &&\
								${Me.ToEntity.Approaching.ID} != ${CurrentTarget}
						{
							UI:Update["Ratter", "SpeedTank: Orbiting \ao${Entity[${CurrentTarget}].Name}", "g"]
							Orbiting:Set[0]
							Entity[${CurrentTarget}]:Orbit[${Math.Calc[${Config.SpeedTankDistance}*1000+1000].Int}]
						}
					}
				}
			}
		}
		elseif ${Config.Tether} && ${Config.KeepRange}
		{
			if ${Entity[Name =- "${Config.TetherPilot}"](exists)}
			{
				if ${Me.ToEntity.Mode} != 1
				{
					Entity[Name =- "${Config.TetherPilot}"]:KeepAtRange
				}
			}
		}

		if !${Entity[${CurrentTarget}](exists)} || (!${Entity[${CurrentTarget}].IsLockedTarget} && !${Entity[${CurrentTarget}].BeingTargeted}) || ${Entity[${CurrentTarget}].Distance} > 150000
		{
			CurrentTarget:Set[-1]
		}
		else
		{
			FinishedDelay:Set[${Math.Calc[${LavishScript.RunningTime} + (10000)]}]
			if 	${Ship.ModuleList_Weapon.ActiveCount} < ${Ship.ModuleList_Weapon.Count}
			{
				Ship.ModuleList_Weapon:ActivateCount[${Ship.ModuleList_Weapon.InactiveCount}, ${CurrentTarget}]
				return FALSE
			}
			if 	${Ship.ModuleList_TargetPainter.ActiveCount} < ${Ship.ModuleList_TargetPainter.Count}
			{
				Ship.ModuleList_TargetPainter:ActivateCount[${Ship.ModuleList_TargetPainter.InactiveCount}, ${CurrentTarget}]
				return FALSE
			}
			if 	${Ship.ModuleList_StasisWeb.ActiveCount} < ${Ship.ModuleList_StasisWeb.Count} &&\
				${Entity[${CurrentTarget}].Distance} < ${Ship.ModuleList_StasisWeb.Range}
			{
				Ship.ModuleList_StasisWeb:ActivateCount[${Ship.ModuleList_StasisWeb.InactiveCount}, ${CurrentTarget}]
				return FALSE
			}
		}

		if ${${ModuleToUse}.LockedAndLockingTargetList.Used} && ${CurrentTarget.Equal[-1]}
		{
			if ${${ModuleToUse}.LockedAndLockingTargetList.Get[1](exists)}
			{
				CurrentTarget:Set[${${ModuleToUse}.LockedAndLockingTargetList.Get[1].ID}]
				UI:Update["Ratter", "Primary target: \ar${${ModuleToUse}.LockedAndLockingTargetList.Get[1].Name}", "g"]
			}
		}

		return FALSE
	}


}






objectdef obj_RatterUI inherits obj_State
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
		return ${Client.Inventory}
	}

	member:bool UpdateBookmarkLists()
	{
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator
		variable index:item Items
		variable iterator ItemIterator

		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[BookmarkIterator]
		MyShip:GetCargo[Items]
		Items:GetIterator[ItemIterator]

		UIElement[RattingSystemList@RatterFrame@Frame@ComBot_Ratter]:ClearItems
		if ${BookmarkIterator:First(exists)}
			do
			{
				if ${UIElement[RattingSystem@RatterFrame@Frame@ComBot_Ratter].Text.Length}
				{
					if ${BookmarkIterator.Value.Label.Left[${Ratter.Config.RattingSystem.Length}].Equal[${Ratter.Config.RattingSystem}]}
						UIElement[RattingSystemList@RatterFrame@Frame@ComBot_Ratter]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
				else
				{
					UIElement[RattingSystemList@RatterFrame@Frame@ComBot_Ratter]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
			}
			while ${BookmarkIterator:Next(exists)}

		UIElement[DropoffList@DropoffFrame@Frame@ComBot_Ratter]:ClearItems
		if ${BookmarkIterator:First(exists)}
			do
			{
				if ${UIElement[Dropoff@DropoffFrame@Frame@ComBot_Ratter].Text.Length}
				{
					if ${BookmarkIterator.Value.Label.Left[${Ratter.Config.Dropoff.Length}].Equal[${Ratter.Config.Dropoff}]}
						UIElement[DropoffList@DropoffFrame@Frame@ComBot_Ratter]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
				else
				{
					UIElement[DropoffList@DropoffFrame@Frame@ComBot_Ratter]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
			}
			while ${BookmarkIterator:Next(exists)}

		UIElement[AmmoList@AmmoFrame@Frame@ComBot_Ratter]:ClearItems
		if ${ItemIterator:First(exists)}
			do
			{
				if ${UIElement[Ammo@AmmoFrame@Frame@ComBot_Ratter].Text.Length}
				{
					if ${ItemIterator.Value.Name.Left[${Ratter.Config.Ammo.Length}].Equal[${Ratter.Config.Ammo}]}
						UIElement[AmmoList@AmmoFrame@Frame@ComBot_Ratter]:AddItem[${ItemIterator.Value.Name.Escape}]
				}
				else
				{
					UIElement[AmmoList@AmmoFrame@Frame@ComBot_Ratter]:AddItem[${ItemIterator.Value.Name.Escape}]
				}
			}
			while ${ItemIterator:Next(exists)}
		return FALSE
	}

}
