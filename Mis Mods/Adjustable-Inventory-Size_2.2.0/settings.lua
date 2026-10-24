data:extend({

	{
		type = "bool-setting",
		name = "ais-inventorysize-enabled",
		setting_type = "startup",
		default_value = false
	},

	{	
		type = "int-setting",
		name = "inventorysize",
		setting_type = "startup",
		default_value = 50,
		minimum_value = 50,
		maximum_value = 2000,
	}

})	