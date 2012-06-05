
objectdef obj_Move inherits obj_State
{

	variable bool Approaching=FALSE
	variable int64 ApproachingID
	variable int ApproachingDistance
	variable int TimeStartedApproaching = 0


	variable bool Traveling=FALSE
	
	variable int Distance


	method Initialize()
	{
		This[parent]:Initialize
		UI:Update["obj_Move", "Initialized", "g"]
	}



	
	
	method Warp(int64 ID, int Dist=0)
	{
		Entity[${ID}]:WarpTo[${Dist}]
		Client:Wait[5000]
	}
	
	method ActivateAutoPilot()
	{
		if !${Me.AutoPilotOn}
		{
			UI:Update["obj_Move", "Activating autopilot", "g"]
			EVE:Execute[CmdToggleAutopilot]
		}
	}

	method TravelToSystem(int64 DestinationSystemID)
	{
		if ${Me.ToEntity.Mode} == 3 || ${DestinationSystemID.Equal[${Me.SolarSystemID}]} || ${Me.AutoPilotOn}
		{
			return
		}

		variable index:int DestinationList
		EVE:GetWaypoints[DestinationList]
		
		if ${DestinationList[${DestinationList.Used}]} != ${DestinationSystemID}
		{
			UI:Update["obj_Move", "Setting destination to ${Universe[${DestinationSystemID}].Name}", "g"]
			Universe[${DestinationSystemID}]:SetDestination
			return
		}
		
		This:ActivateAutoPilot
	}

	method DockAtStation(int64 StationID)
	{
		if ${Entity[${StationID}](exists)}
		{
			UI:Update["obj_Move", "Docking: ${Entity[${StationID}].Name}", "g"]
			Entity[${StationID}]:Dock
			Client:Wait[10000]
		}
		else
		{
			UI:Update["obj_Move", "Station Requested does not exist.  StationID: ${StationID}", "r"]
		}
	}	
	
	method Undock()
	{
			EVE:Execute[CmdExitStation]
			Client:Wait[10000]
	}	
	
	
	
	
	
	
	method Bookmark(string DestinationBookmarkLabel, int Dist=0)
	{
		if ${This.Traveling}
		{
			return
		}
		
		if !${EVE.Bookmark[${DestinationBookmarkLabel}](exists)}
		{
			UI:Update["obj_Move", "Attempted to travel to a bookmark which does not exist", "r"]
			UI:Update["obj_Move", "Bookmark label: ${DestinationBookmarkLabel}", "r"]
			return
		}

		UI:Update["obj_Move", "Movement queued.  Destination: ${DestinationBookmarkLabel}", "g"]
		This.Traveling:Set[TRUE]
		This.Distance:Set[${Dist}]
		This:QueueState["BookmarkMove", 2000, ${DestinationBookmarkLabel}]
	}

	method System(string SystemID)
	{
		if ${This.Traveling}
		{
			return
		}
		
		if !${Universe[SystemID](exists)}
		{
			UI:Update["obj_Move", "Attempted to travel to a system which does not exist", "r"]
			UI:Update["obj_Move", "System ID: ${SystemID}", "r"]
			return
		}

		UI:Update["obj_Move", "Movement queued.  Destination: ${Universe[SystemID]}.Name", "g"]
		This.Traveling:Set[TRUE]
		This:QueueState["SystemMove", 2000, ${SystemID}]
	}
	
	
	method Agent(string AgentName)
	{
		if ${This.Traveling}
		{
			return
		}
		
		if !${Agent[${AgentName}](exists)}
		{
			UI:Update["obj_Move", "Attempted to travel to an agent which does not exist", "r"]
			UI:Update["obj_Move", "Agent name: ${AgentName}", "r"]
			return
		}

		UI:Update["obj_Move", "Movement queued.  Destination: ${AgentName}", "g"]
		This.Traveling:Set[TRUE]
		This:QueueState["AgentMove", 2000, ${Agent[AgentName].Index}]
	}	

	method Gate(int64 ID)
	{
		UI:Update["obj_Move", "Movement queued.  Destination: ${Entity[${ID}].Name}", "g"]
		This.Traveling:Set[TRUE]
		This:QueueState["GateMove", 2000, ${ID}]
	}

	member:bool GateMove(int64 ID)
	{
		echo GATEMOVE
		if !${This.CheckApproach}
		{
			return FALSE
		}

		if ${Entity[${ID}].Distance} == 0
		{
			UI:Update["obj_Move", "Too close!  Orbiting ${Entity[${ID}].Name}", "g"]
			This:Clear
			This:QueueState["Orbit", 10000, ${Entity[${ID}].ID}]
			This:QueueState["GateMove"]
			return TRUE
		}
		if ${Entity[${ID}].Distance} > 3000
		{
			This:Approach[${ID}, 3000]
			return FALSE
		}
		UI:Update["obj_Move", "Activating ${Entity[${ID}].Name}", "g"]
		Entity[${ID}]:Activate
		Client:Wait[5000]
		return TRUE
	}
	
	member:bool Orbit(int64 ID)
	{
		Entity[${ID}]:Orbit
		return TRUE
	}
	
	member:bool BookmarkMove(string Bookmark)
	{

		if ${Me.InStation}
		{
			if ${Me.StationID} == ${EVE.Bookmark[${Bookmark}].ItemID}
			{
				UI:Update["obj_Move", "Docked at ${Bookmark}", "g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
			else
			{
				UI:Update["obj_Move", "Undocking from ${Me.Station.Name}", "g"]
				This:Undock
				return FALSE
			}
		}

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}
		
		if  ${EVE.Bookmark[${Bookmark}].SolarSystemID} != ${Me.SolarSystemID}
		{
			This:TravelToSystem[${EVE.Bookmark[${Bookmark}].SolarSystemID}]
			return FALSE
		}
		
		if ${EVE.Bookmark[${Bookmark}].ItemID} == -1
		{
			if ${EVE.Bookmark[${Bookmark}].Distance} > WARP_RANGE
			{
				if ${Entity[GroupID == GROUP_WARPGATE](exists)}
				{
					UI:Update["obj_Move", "Gate found, activating", "g"]
					This:Gate[${Entity[GroupID == GROUP_WARPGATE].ID}]
					This:QueueState["BookmarkMove", 2000, ${Bookmark}]
					return TRUE
				}			
				
				UI:Update["obj_Move", "Warping to ${Bookmark}", "g"]
				EVE.Bookmark[${Bookmark}]:WarpTo[${This.Distance}]
				Client:Wait[5000]
				return FALSE
			}
			else
			{
				UI:Update["obj_Move", "Reached ${Bookmark}", "g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
		}
		else
		{
			if ${EVE.Bookmark[${Bookmark}].ToEntity(exists)}
			{
				if ${EVE.Bookmark[${Bookmark}].ToEntity.Distance} > WARP_RANGE
				{
					UI:Update["obj_Move", "Warping to ${Bookmark}", "g"]
					This:Warp[${EVE.Bookmark[${Bookmark}].ToEntity}, ${This.Distance}]
					return FALSE
				}
				else
				{
					UI:Update["obj_Move", "Reached ${Bookmark}, docking", "g"]
					This:DockAtStation[${EVE.Bookmark[${Bookmark}].ItemID}]
					return FALSE
				}
			}
			else
			{
				if ${EVE.Bookmark[${Bookmark}].Distance} > WARP_RANGE
				{
					UI:Update["obj_Move", "Warping to ${Bookmark}", "g"]
					EVE.Bookmark[${Bookmark}]:WarpTo[${This.Distance}]
					Client:Wait[5000]
					return FALSE
				}
				else
				{
					UI:Update["obj_Move", "Reached ${Bookmark}", "g"]
					This.Traveling:Set[FALSE]
					return TRUE
				}
			}
		}
	}
	

	member:bool AgentMove(int ID)
	{

		if ${Me.InStation}
		{
			if ${Me.StationID} == ${Agent[${ID}].StationID}
			{
				UI:Update["obj_Move", "Docked at ${Agent[${ID}].Station}", "g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
			else
			{
				UI:Update["obj_Move", "Undocking from ${Me.Station.Name}", "g"]
				This:Undock
				return FALSE
			}
		}

		if ${Me.ToEntity.Mode} == 3 || !${Client.InSpace}
		{
			return FALSE
		}
			
		if  ${Agent[${ID}].SolarSystem.ID} != ${Me.SolarSystemID}
		{
			This:TravelToSystem[${Agent[${ID}].SolarSystem.ID}]
			return FALSE
		}
		
		if ${Entity[${Agent[${ID}].StationID}](exists)}
		{
			if ${Entity[${Agent[${ID}].StationID}].Distance} > WARP_RANGE
			{
				UI:Update["obj_Move", "Warping to ${Agent[${ID}].Station}", "g"]
				This:Warp[${Agent[${ID}].StationID}]
				return FALSE
			}
			else
			{
				UI:Update["obj_Move", "Reached ${Agent[${ID}].Station}, docking", "g"]
				This:DockAtStation[${Agent[${ID}].StationID}]
				This.Traveling:Set[FALSE]
				return TRUE
			}
		}
	}

	member:bool SystemMove(int64 ID)
	{

		if ${Me.InStation}
		{
			if ${Me.SolarSystemID} == ${ID}
			{
				UI:Update["obj_Move", "Reached ${Universe[${ID}].Name", "g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
			else
			{
				UI:Update["obj_Move", "Undocking from ${Me.Station.Name}", "g"]
				This:Undock
				return FALSE
			}
		}

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}
		
		if  ${ID} != ${Me.SolarSystemID}
		{
			This:TravelToSystem[${ID}]
			return FALSE
		}
		This.Traveling:Set[FALSE]
		return TRUE
	}
	
	
	method Approach(int64 target, int distance=0)
	{
		echo APPROACH - ${target} == ${This.ApproachingID} && ${This.Approaching}
		;	If we're already approaching the target, ignore the request
		if ${target} == ${This.ApproachingID} && ${This.Approaching}
		{
			return
		}
		echo AFTER
		if !${Entity[${target}](exists)}
		{
			UI:Update["obj_Move", "Attempted to approach a target that does not exist", "r"]
			UI:Update["obj_Move", "Target ID: ${target}", "r"]
			return
		}
		echo EVEN AFTER
		if ${Entity[${target}].Distance} <= ${distance}
		{
			return
		}

		This.ApproachingID:Set[${target}]
		This.ApproachingDistance:Set[${distance}]
		This.TimeStartedApproaching:Set[-1]
		This.Approaching:Set[TRUE]
		This:QueueState["CheckApproach"]
	}
	
	
	member:bool CheckApproach()
	{
		;	Clear approach if we're in warp or the entity no longer exists
		if ${Me.ToEntity.Mode} == 3 || !${Entity[${This.ApproachingID}](exists)}
		{
			This.Approaching:Set[FALSE]
			return TRUE
		}			
		
		;	Find out if we need to warp to the target
		if ${Entity[${This.ApproachingID}].Distance} > WARP_RANGE 
		{
			UI:Update["obj_Move", "${Entity[${This.ApproachingID}].Name} is a long way away.  Warping to it", "g"]
			This:Warp[${This.ApproachingID}]
			return FALSE
		}
		
		;	Find out if we need to approach the target
		if ${Entity[${This.ApproachingID}].Distance} > ${This.ApproachingDistance} && ${This.TimeStartedApproaching} == -1
		{
			UI:Update["obj_Move", "Approaching to within ${ComBot.MetersToKM_Str[${This.ApproachingDistance}]} of ${Entity[${This.ApproachingID}].Name}", "g"]
			Entity[${This.ApproachingID}]:Approach[${distance}]
			This.TimeStartedApproaching:Set[${Time.Timestamp}]
			return FALSE
		}
		
		;	If we've been approaching for more than 1 minute, we need to give up
		if ${Math.Calc[${This.TimeStartedApproaching}-${Time.Timestamp}]} < -60
		{
			This.Approaching:Set[FALSE]
			return TRUE
		}
		
		;	If we're approaching a target, find out if we need to stop doing so 
		if ${Entity[${This.ApproachingID}].Distance} <= ${This.ApproachingDistance}
		{
			UI:Update["obj_Move", "Within ${ComBot.MetersToKM_Str[${This.ApproachingDistance}]} of ${Entity[${This.ApproachingID}].Name}", "g"]
			EVE:Execute[CmdStopShip]
			This.Approaching:Set[FALSE]
			return TRUE
		}
		
		if !${Ship.ModuleList_AB_MWD.ActiveCount} && ${MyShip.CapacitorPct} > 30
		{
			UI:Update["obj_Move", "Activating propulsion units", "g"]
			Ship.ModuleList_AB_MWD:Activate
			return FALSE
		}
		if ${Ship.ModuleList_AB_MWD.ActiveCount} && ${MyShip.CapacitorPct} <= 30
		{
			UI:Update["obj_Move", "Activating propulsion units", "g"]
			Ship.ModuleList_AB_MWD:Activate
			return FALSE
		}
		
		return FALSE
	}

}
	
	
	
objectdef obj_InstaWarp inherits obj_State
{
	variable bool InstaWarp_Cooldown=FALSE

	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		UI:Update["obj_InstaWarp", "Initialized", "g"]
		This:QueueState["InstaWarp_Check", 2000]
	}
	
	member:bool InstaWarp_Check()
	{
		if !${Client.InSpace}
		{
			return FALSE
		}
		
		echo ${Ship.ModuleList_AB_MWD.ActiveCount}
		if ${Me.ToEntity.Mode} == 3 && ${InstaWarp_Cooldown} && ${Ship.ModuleList_AB_MWD.ActiveCount}
		{
			echo DEACTIVATING AB/MWD
			Ship.ModuleList_AB_MWD:Deactivate
			return FALSE
		}
		
		if ${Me.ToEntity.Mode} == 3 && !${InstaWarp_Cooldown}
		{
			echo ACTIVATING AB/MWD
			Ship.ModuleList_AB_MWD:Activate
			InstaWarp_Cooldown:Set[TRUE]
			return FALSE
		}
		if ${Me.ToEntity.Mode} != 3
		{
			InstaWarp_Cooldown:Set[FALSE]
			return FALSE
		}
	}
}