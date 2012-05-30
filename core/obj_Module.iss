objectdef obj_Module inherits obj_State
{
	variable index:module ModuleList
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
		ModuleList:GetIterator[ModuleIterator]
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
			return true;
		}
		else
		{
			return ${ModuleList[${Key}]}
		}
	}
	
	method Activate(int64 target = -1)
	{
		variable int Module = ${This.GetInactive}
		if ${target} == -1
		{
			ModuleList[${Module}]:Activate
			ModuleTarget:Set[${Module}, ${Me.ActiveTarget.ID}]
		}
		else
		{
			ModuleList[${Module}]:Activate[${target}]
			ModuleTarget:Set[${Module}, ${target}]
		}
		ModuleActive:Set[${Module}, TRUE]
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
				if (${ModuleIterator.Value} == ${actualTarget}) && (${ModuleActive[${ModuleIterator.Key}]} || ${ModuleList[${ModuleIterator.Key}].IsActive} )
				{
					ModuleList[${ModuleIterator.Key}]:Deactivate
					ModuleActive:Set[${ModuleIterator.Key}, FALSE]
					return
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
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
			return false
		}
		ModuleList:GetIterator[ModuleIterator]
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
		variable int ActiveCount = 0
		ModuleList:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if ${ModuleIterator.Value.IsActive} || ${ModuleActive[${ModuleIterator.Key}]}
				{
					ActiveCount:Inc
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
		return ${ActiveCount}
	}
	
	member:module GetIndex(int id)
	{
		return ${ModuleList[${id}]}
	}
	
	method GetIterator(iterator Iterator)
	{
		ModuleList:GetIterator[Iterator]
	}
	
	method Insert(int64 ID)
	{
		ModuleList:Insert[${ID}]
		ModuleActive:Insert[FALSE]
		ModuleTarget:Insert[-1]
	}
	
	method Clear()
	{
		ModuleList:Clear
		ModuleActive:Clear
		ModuleTarget:Clear
	}
}