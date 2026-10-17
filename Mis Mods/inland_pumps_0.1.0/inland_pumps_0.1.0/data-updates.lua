excluded_entities = {
	"stone-waterwell"
}

function remove_value(array, value)
	for index, arr_value in pairs(array) do
		if arr_value == value then
			table.remove(array, index)
			return
		end
	end
end

function contains_value(array, value)
	for index, arr_value in pairs(array) do
		if arr_value == value then
			return true
		end
	end
	return false
end

function any(array, predicate)
    for _, value in pairs(array) do
        if predicate(value) then
            return true
        end
    end
    return false
end

function get_recipe_data(recipe)
    if recipe.normal ~= nil and recipe.expensive ~= nil then
        return {recipe.normal, recipe.expensive}
    elseif recipe.normal ~= nil then
        return {recipe.normal}
    elseif recipe.expensive ~= nil then
        return {recipe.expensive}
    else
        return {recipe}
    end
end

function make_replacement_item(entity_key) do
    for item_key, item in pairs(data.raw["item"]) do
        if item.place_result == entity_key then
            local new_item = table.deepcopy(item)
            new_item.name = item.name .. "-inland"
            new_item.order = item.order .. "-a[inland]"
            if entity_key == "offshore-pump" then
                new_item.localised_name = { "entity-name.water-well-pump" }
            else
                new_item.localised_name = { "entity-name." .. entity_key }
            end
            new_item.place_result = entity_key .. "-inland"
            return new_item, item.name
        end
    end
    return nil
end end

-- Helper for getting the item key from either SimpleItemStack format
function get_item_key(item)
    if item.name ~= nil then
        return item.name
    end
    if item[1] ~= nil then
        return item[1]
    end
    return nil
end

-- Helper for replacing the item in either SimpleItemStack format
function replace_item(item, old_item_key, new_item_key)
    if item.name ~= nil then
        if item.name == old_item_key then
            item.name = new_item_key
        end
    end
    if item[1] ~= nil then
        if item[1] == old_item_key then
            item[1] = new_item_key
        end
    end
end

-- Helper for replacing items in ingredient and result lists, whether
-- or not it uses normal/expensive recipes and whether the results are
-- specified in .result or .results
function replace_recipe_item(recipe, old_item_key, new_item_key)
    -- ingredients
    -- log("Replacing recipe " .. old_item_key)
    -- log(serpent.block(recipe))
    -- normal/expensive recipes have the results and ingredients with the same
    -- structure but moved to recipe.normal and recipe.expensive
    if recipe.normal ~= nil then
        recipe.normal.enabled = nil
        replace_recipe_item(recipe.normal, old_item_key, new_item_key)
    end
    if recipe.expensive ~= nil then
        recipe.expensive.enabled = nil
        replace_recipe_item(recipe.expensive, old_item_key, new_item_key)
    end
    if recipe.ingredients ~= nil then
        for _, item in pairs(recipe.ingredients) do
            replace_item(item, old_item_key, new_item_key)
        end
    end
    
    -- results
    if recipe.result ~= nil then
        if recipe.result == old_item_key then
            recipe.result = new_item_key
        end
    end
    if recipe.results ~= nil then
        for _, item in pairs(recipe.results) do
            replace_item(item, old_item_key, new_item_key)
        end
    end
end

new_data = {}
for entity_key, entity in pairs(data.raw["offshore-pump"]) do
    log("processing " .. entity_key)
	if not contains_value(excluded_entities, entity_key) then
		-- Make a copy of the offshore pump entity that doesn't need to be on a shore
		local new_entity = table.deepcopy(entity)
		new_entity.name = entity_key .. "-inland"
		
		-- Make it placeable inland
		if contains_value(new_entity.collision_mask, "ground-tile") then
			-- Old-style pumps are placed offshore, so just removing the restriction
			-- that they be placed on water works.
			remove_value(new_entity.collision_mask, "ground-tile")
			table.insert(new_entity.adjacent_tile_collision_test, "ground-tile")
		else
			-- New-style pumps (vanilla pumps 0.18.10+) are placed onshore but restricted
			-- to be only placed near water, which is fixed by changing these values.
			remove_value(new_entity.adjacent_tile_collision_test, "water-tile")
			remove_value(new_entity.fluid_box_tile_collision_test, "ground-tile")
			remove_value(new_entity.adjacent_tile_collision_mask, "ground-tile")
		end
		
		-- Disable the position hints and auto-rotating, since they're no longer accurate
		remove_value(new_entity.flags, "filter-directions")
		new_entity.placeable_position_visualization = nil
		
		-- Make the replacement work right.
		if entity.fast_replaceable_group == nil then
			entity.fast_replaceable_group = entity.name
		end
		new_entity.fast_replaceable_group = entity.fast_replaceable_group
		
		-- Special handling to trigger the easter egg where vanilla offshore
		-- pumps change their name when surrounded by landfill.
		if entity_key == "offshore-pump" then
			new_entity.localised_name = { "entity-name.water-well-pump" }
		else
			new_entity.localised_name = { "entity-name." .. entity_key }
		end
		
		-- Make an inventory item and recipe for the new pump version
		local new_item, old_item_name
		new_item, old_item_name = make_replacement_item(entity_key)
		if new_item ~= nil then
			new_entity.minable.result = new_item.name
			table.insert(new_data, new_entity)
			table.insert(new_data, new_item)
			
			for recipe_key, recipe in pairs(data.raw["recipe"]) do
                log(serpent.block(recipe))
				local has_pump_output = any(get_recipe_data(recipe), function(r) 
					if r.result then
						return r.result == old_item_name
					end
					if r.results then
						return any(r.results, function(i) return get_item_key(i) == old_item_name end)
					end
				end)
				local has_pump_input = any(get_recipe_data(recipe), function (r)
					return any(r.ingredients, function (i) return get_item_key(i) == old_item_name end)
				end)
				if has_pump_output or has_pump_input then
					local new_recipe = table.deepcopy(recipe)
					new_recipe.name = recipe.name .. "-inland"
					
					replace_recipe_item(new_recipe, old_item_name, new_item.name)
                    if new_recipe.normal ~= nil then
                        new_recipe.normal.enabled = false
                        new_recipe.expensive.enabled = false
                    else
                        new_recipe.enabled = false
                    end
					table.insert(new_data, new_recipe)
				end
			end
		end
	end
end

data:extend(new_data)