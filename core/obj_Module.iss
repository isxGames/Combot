objectdef obj_Module inherits obj_State
{
	variable index:module ModList
	variable index:bool ModuleActive
	variable index:int ModuleTarget
	
	method Initialize()
	{
		This[parent]:Initialize
		This:QueueState["CheckActives", 100]
	}
	
	member:int GetInactive()
	{
		variable iterator ModuleIterator
		This.ModList:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if !${This.IsActive[ModuleIterator.Key]}
				{
					return ${ModuleIterator.Key}
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
		return -1
	}
	
	member:bool IsActive(int Key)
	{
		if ${ModuleActive[${Key}]}
		{
			return TRUE
		}
		else
		{
			return ${This.ModList[${Key}].IsActive}
		}
	}
	
	method Activate(int64 target = -1)
	{
		variable int Module = ${This.GetInactive}
		if ${target} == -1
		{
			This.ModList[${Module}]:Activate
			ModuleTarget:Set[${Module}, ${Me.ActiveTarget.ID}]
		}
		else
		{
			This.ModList[${Module}]:Activate
			ModuleTarget:Set[${Module}, ${target}]
		}
		ModuleActive:Set[${Module}, TRUE]
	}
	
	method ActivateCount(int moduleCount, int64 target = -1)
	{
		variable int varActivated = 0
		for (${varActivated}<${moduleCount} ; varActivated:Inc)
		{
			This:Activate[${target}]
		}
	}

	method ActivateAll(int64 target = -1)
	{
		This:Activate[${This.InactiveCount}, ${target}]
	}
	
	method Deactivate(int64 target = -1)
	{
		variable iterator ModuleIterator
		variable int actualTarget
		if ${target} == -1
		{
			actualTarget:Set[${Me.ActiveTarget.ID}]
		}
		else
		{
			actualTarget:Set[${target}]
		}
		ModuleActive:Set[${Module}, TRUE]
		ModuleTarget:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if (${ModuleIterator.Value} == ${actualTarget}) && (${ModuleActive[${ModuleIterator.Key}]} || ${This.ModList[${ModuleIterator.Key}].IsActive} )
				{
					This.ModList[${ModuleIterator.Key}]:Deactivate
					ModuleActive:Set[${ModuleIterator.Key}, FALSE]
					return
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
	}

	method DeactivateCount(int moduleCount, int64 target = -1)
	{
		variable int varDeactivated = 0
		for (${varDeactivated}<${moduleCount} ; varDeactivated:Inc)
		{
			This:Deactivate[${target}]
		}
	}

	method DeactivateAll(int64 target = -1)
	{
		This:Deactivate[${This.ActiveCount}, ${target}]
	}
	
	member:bool IsActiveOn(int64 target = -1)
	{
		variable iterator ModuleIterator
		variable int actualTarget
		if ${target} == -1
		{
			actualTarget:Set[${Me.ActiveTarget.ID}]
		}
		else
		{
			actualTarget:Set[${target}]
		}
		ModuleTarget:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if (${ModuleIterator.Value} == ${actualTarget}) && (${ModuleActive[${ModuleIterator.Key}]})
				{
					return TRUE
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
		return FALSE
	}
	
	member:bool CheckActives()
	{
		variable iterator ModuleIterator
		if !${Client.InSpace}
		{
			return FALSE
		}
		This.ModList:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if !${ModuleIterator.Value.IsActive}
				{
					ModuleActive:Set[${ModuleIterator.Key}, FALSE]
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
	}

	member:int ActiveCount()
	{
		variable int varActiveCount = 0
		variable iterator ModuleIterator
		This.ModList:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if ${ModuleIterator.Value.IsActive} || ${ModuleActive[${ModuleIterator.Key}]}
				{
					varActiveCount:Inc
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
		return ${varActiveCount}
	}

	member:int InctiveCount()
	{
		variable int varInctiveCount = 0
		variable iterator ModuleIterator
		This.ModList:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if !${ModuleIterator.Value.IsActive} && !${ModuleActive[${ModuleIterator.Key}]}
				{
					varInctiveCount:Inc
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
		return ${varInctiveCount}
	}

	member:int Count()
	{
		return ${This.ModList.Used}
	}
	
	member:double Range()
	{
		return ${This.ModList.Get[1].OptimalRange}
	}
	
	member:module GetIndex(int id)
	{
		return ${This.ModList[${id}]}
	}
	
	method GetIterator(iterator Iterator)
	{
		This.ModList:GetIterator[Iterator]
	}
	
	method Insert(int64 ID)
	{
		This.ModList:Insert[${ID}]
		ModuleActive:Insert[FALSE]
		ModuleTarget:Insert[-1]
	}
	
	method Clear()
	{
		This.ModList:Clear
		ModuleActive:Clear
		ModuleTarget:Clear
	}
}