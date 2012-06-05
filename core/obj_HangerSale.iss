objectdef obj_HangerSale inherits obj_State
{
	variable index:item HangerItems
	variable iterator HangerIterator
	variable collection:float MineralPrices
	variable collection:string MineralNames
	
	method Initialize()
	{
		This[parent]:Initialize
		;This:AssignStateQueueDisplay[obj_SalvageStateList@Salvager@ComBotTab@ComBot]
		PulseFrequency:Set[2000]
		UI:Update["obj_HangerSale", "Initialized", "g"]
	}
	
	method Start()
	{
		UI:Update["obj_HangerSale", "Started", "g"]
		if ${This.IsIdle}
		{
			MineralNames:Clear
			MineralNames:Set[34, "Tritanium"]
			MineralNames:Set[35, "Pyerite"]
			MineralNames:Set[36, "Mexallon"]
			MineralNames:Set[37, "Isogen"]
			MineralNames:Set[38, "Nocxium"]
			MineralNames:Set[39, "Zydrine"]
			MineralNames:Set[40, "Megacyte"]
			RefineData:Load
			This:QueueState["OpenHanger"]
;			This:QueueState["OpenMarket"]
			This:QueueState["GetMarket", 5000, "34"]
			This:QueueState["GetPrice", 5000, "34"]
			This:QueueState["GetMarket", 5000, "35"]
			This:QueueState["GetPrice", 5000, "35"]
			This:QueueState["GetMarket", 5000, "36"]
			This:QueueState["GetPrice", 5000, "36"]
			This:QueueState["GetMarket", 5000, "37"]
			This:QueueState["GetPrice", 5000, "37"]
			This:QueueState["GetMarket", 5000, "38"]
			This:QueueState["GetPrice", 5000, "38"]
			This:QueueState["GetMarket", 5000, "39"]
			This:QueueState["GetPrice", 5000, "39"]
			This:QueueState["GetMarket", 5000, "40"]
			This:QueueState["GetPrice", 5000, "40"]
			This:QueueState["CheckHanger"]
		}
	}
	
	member:bool OpenHanger()
	{
		if !${EVEWindow[ByName, "Item Hanger"](exists)}
		{
			UI:Update["obj_HangerSale", "Opening Item Hanger", "g"]
			EVE:Execute[OpenHangarFloor]
		}
		return TRUE
	}
	
	member:bool OpenMarket()
	{
		EVE:Execute[OpenMarket]
		return TRUE
	}
	
	member:bool GetMarket(int TypeID)
	{
		EVE:FetchMarketOrders[${TypeID}]
		return TRUE
	}
	
	member:bool GetPrice(int TypeID)
	{
		variable index:marketorder orders
		variable iterator orderIterator
		EVE:GetMarketOrders[orders, ${TypeID}, "buy"]
		orders:GetIterator[orderIterator]
		if ${orderIterator:First(exists)}
		{
			do
			{
				if ${orderIterator.Value.Jumps} <= ${orderIterator.Value.Range}
				{
					MineralPrices:Set[${TypeID}, ${orderIterator.Value.Price}]
					UI:Update["obj_HangerSale", "Best price for ${MineralNames[${TypeID}]} is ${orderIterator.Value.Price}", "g"]
					return TRUE
				}
			}
			while ${orderIterator:Next(exists)}
		}
		return TRUE
	}
	
	member:bool CheckHanger()
	{
		HangerItems:Clear
		Me:GetHangarItems[HangerItems]
		HangerItems:GetIterator[HangerIterator]
		if ${HangerIterator:First(exists)}
		{
			This:QueueState["GetMarket", 1000, ${HangerIterator.Value.TypeID}]
			This:QueueState["SellIfAboveValue", 5000]
			This:QueueState["CheckItem"]
		}
		return TRUE
	}
	
	member:bool CheckItem()
	{
		if ${HangerIterator:Next(exists)}
		{
			This:QueueState["GetMarket", 1000, ${HangerIterator.Value.TypeID}]
			This:QueueState["SellIfAboveValue", 5000]
			This:QueueState["CheckItem"]
		}
		return TRUE
	}
	
	member:bool SellIfAboveValue()
	{
		variable index:marketorder orders
		variable iterator orderIterator
		variable int remainingQuantity
		variable float itemValue
		
		EVE:GetMarketOrders[orders, ${HangerIterator.Value.TypeID}, "buy"]
		orders:GetIterator[orderIterator]
		
		itemValue:Set[${This.GetItemValue[${HangerIterator.Value.TypeID}, ${HangerIterator.Value.PortionSize}]}]
		remainingQuantity:Set[${HangerIterator.Value.Quantity}]
		
		UI:Update["obj_HangerSale", "Raw Value for ${HangerIterator.Value.Name} is ${itemValue}", "g"]
		
		if ${orderIterator:First(exists)}
		{
			do
			{
				if ${orderIterator.Value.Price} < ${itemValue}
				{
					UI:Update["obj_HangerSale", "None left above raw value", "g"]
					return TRUE
				}
				if ${orderIterator.Value.Jumps} <= ${orderIterator.Value.Range}
				{
					if ${orderIterator.Value.MinQuantityToBuy} <= ${remainingQuantity}
					{
						UI:Update["obj_HangerSale", "Better then Value - ${orderIterator.Value.Price}", "g"]
						if ${orderIterator.Value.QuantityRemaining} >= ${remainingQuantity}
						{
							This:InsertState["PlaceSellOrder", 5000, "${orderIterator.Value.Price}, ${remainingQuantity}"]
							UI:Update["obj_HangerSale", "None left above raw value", "g"]
							return TRUE
						}
						else
						{
							remainingQuantity:Dec[${orderIterator.Value.QuantityRemaining}]
							This:InsertState["PlaceSellOrder", 5000, "${orderIterator.Value.Price}, ${orderIterator.Value.QuantityRemaining}"]
						}
					}
				}
			}
			while ${orderIterator:Next(exists)}
		}
		UI:Update["obj_HangerSale", "None left above raw value", "g"]
		return TRUE
		
	}
	
	member:bool PlaceSellOrder(float Price, int Quantity)
	{
		UI:Update["obj_HangerSale", "Sale of ${Quantity} for ${Price}", "g"]
		HangerIterator.Value:PlaceSellOrder[${Price}, ${Quantity}, 1]
		return TRUE
	}
	
	member:float GetItemValue(int TypeID, int PortionSize)
	{
		variable float ItemValue=0
		
		ItemValue:Inc[${Math.Calc[${RefineData.Tritanium[${TypeID}]} * ${This.GetRefineLoss} * ${MineralPrices["34"]}]}]
		ItemValue:Inc[${Math.Calc[${RefineData.Pyerite[${TypeID}]} * ${This.GetRefineLoss} * ${MineralPrices["35"]}]}]
		ItemValue:Inc[${Math.Calc[${RefineData.Mexallon[${TypeID}]} * ${This.GetRefineLoss} * ${MineralPrices["36"]}]}]
		ItemValue:Inc[${Math.Calc[${RefineData.Isogen[${TypeID}]} * ${This.GetRefineLoss} * ${MineralPrices["37"]}]}]
		ItemValue:Inc[${Math.Calc[${RefineData.Nocxium[${TypeID}]} * ${This.GetRefineLoss} * ${MineralPrices["38"]}]}]
		ItemValue:Inc[${Math.Calc[${RefineData.Zydrine[${TypeID}]} * ${This.GetRefineLoss} * ${MineralPrices["39"]}]}]
		ItemValue:Inc[${Math.Calc[${RefineData.Megacyte[${TypeID}]} * ${This.GetRefineLoss} * ${MineralPrices["40"]}]}]
		echo ${ItemValue}
		return ${Math.Calc[${ItemValue} / ${PortionSize}]}
	}
	
	member:float GetRefineLoss()
	{
		return 0.83755
		
	}
	
}