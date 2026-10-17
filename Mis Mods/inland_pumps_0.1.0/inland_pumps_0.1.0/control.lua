script.on_init(function()
    local activation_tech = calculate_activation_tech()
    
    global["unlocked"] = {}
    for _, force in pairs(game.forces) do
        if activation_tech == nil or force.technologies[activation_tech] == nil or force.technologies[activation_tech].researched then
            -- Allow everything from the beginning the tech is already unlocked
            -- or if there isn't one to use.
            global["unlocked"][force.name] = true
            replace_pumps(force)
        else
            global["unlocked"][force.name] = false
            global["activation_tech"] = activation_tech
        end
    end
    
    if game.active_mods["SeaBlock"] then
        script.on_event(defines.events.on_tick, function (event)
            -- Seablock's on_configuration_change overrides these changes,
            -- so I'll apply them through brute force instead.
            -- Consider an on_technology_effects_reset event instead
            for _, force in pairs(game.forces) do
                if global["unlocked"][force.name] then
                    replace_pumps(force)
                end
            end
            
            script.on_event(defines.events.on_tick, nil)
        end)
    end
end)

script.on_configuration_changed(function(data)
    -- Check for a changed activation tech
    local activation_tech = calculate_activation_tech()
    if global["activation_tech"] ~= activation_tech then
        for _, force in pairs(game.forces) do
            if global["unlocked"][force.name] then
                -- Lock it if they shouldn't have it unlocked
                if activation_tech ~= nil and not force.technologies[activation_tech].researched then
                    revert_pumps(force)
                    global["unlocked"][force.name] = false
                end
            else
                -- Unlock it if they shouldn't have it locked
                if activation_tech == nil or force.technologies[activation_tech].researched then
                    replace_pumps(force)
                    global["unlocked"][force.name] = true
                end
            end
        end
        global["activation_tech"] = activation_tech
    end

    if data.mod_changes["inland_pumps"] ~= nil then
        -- Version updates
        
        -- v0.0.2 and v0.0.3 fixes will both be applied by reverting all
        -- forces and then re-applying the change to the ones that have it
        -- unlocked.
        for _, force in pairs(game.forces) do
            reset(force)
        end
    end
end)

function calculate_activation_tech()
    local activation_tech = nil
    local settings_value = settings.startup["inland-pumps-unlock-tech"].value
    
    if settings_value ~= "" and game.technology_prototypes[settings_value] ~= nil then
        activation_tech = settings_value
    -- if no override, check for a supported installed mod
    elseif game.active_mods["Dectorio"] then
        activation_tech = "dect-earthworks"
    elseif game.active_mods["Noxys_Waterfill"] then
		if settings.startup["Noxys_Waterfill-require-research"].value then
			activation_tech = "waterfill"
		end
    elseif game.active_mods["Explosive Excavation"] then
        activation_tech = "blasting-charges"
    elseif game.active_mods["Waterfill_v17"] then
        activation_tech = "waterfill"
    elseif game.active_mods["artsDugWater"] then
        activation_tech = "art-dug-water"
    elseif game.active_mods["LandMover"] then
        activation_tech = "landfill"
    elseif game.active_mods["CanalBuilder"] then
        activation_tech = "waterfill-tech"
    elseif game.active_mods["Waterbomb"] then
        activation_tech = "explosives"
    elseif game.active_mods["JamozedsTweaks"] then
        activation_tech = "waterfill"
    end
    
    return activation_tech
end

-- Replaces all pumps and their recipes with their inland versions
function replace_pumps(force)
    function qualifies(str) return string.find(str, "-inland") == nil end
    function changed(str) return str .. "-inland" end
    make_changes(force, qualifies, changed)
end

-- Replaces all inland pumps and recipes with their original versions
function revert_pumps(force)
    function has_suffix(str)
        return (string.find(str, "-inland")) == string.len(str) - string.len("-inland") + 1
    end
    function remove_suffix(str)
        return (string.gsub(str, "-inland", ""))
    end
    
    make_changes(force, has_suffix, remove_suffix)
end

function replace_in_inventory(item, new_item, entity)
    local count = entity.get_item_count(item)
    if count > 0 then
        entity.remove_item({name=item, count=count})
        entity.insert({name=new_item, count=count})
    end
end

-- Higher-order programming is fun
function make_changes(force, qualifies, changed)
    -- qualifies: function str -> bool for whether this name has a counterpart
    -- changed: function str -> str that changes this name into its counterpart
    -- Replace existing pumps with the inland versions
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered{type="offshore-pump", force=force}) do
            if qualifies(entity.name) and game.entity_prototypes[changed(entity.name)] ~= nil then
                local last_user = entity.last_user
                local new_entity = surface.create_entity{
                    name = changed(entity.name),
                    position = entity.position,
                    direction = entity.direction,
                    force = entity.force,
                    fast_replace = true,
                    spill = false,
                }
                if last_user ~= nil then
                    new_entity.last_user = last_user
                end
                entity.destroy()
            end
        end
    end
    
    -- Replace recipes for existing pumps
    for name, _ in pairs(force.recipes) do
        if qualifies(name) and force.recipes[changed(name)] ~= nil and force.recipes[name].enabled then
            force.recipes[changed(name)].enabled = true
            force.recipes[name].enabled = false
            
            -- And update assemblers
            for _, surface in pairs(game.surfaces) do
                for _, entity in pairs(surface.find_entities_filtered{type="assembling-machine", force=force}) do
                    local recipe = entity.get_recipe()
                    if recipe ~= nil and recipe.name == name then
                        entity.set_recipe(changed(name))
                    end
                end
            end
            
            
        end
    end
    
    -- Replace items
    for name, _ in pairs(game.item_prototypes) do
        if qualifies(name) and game.item_prototypes[changed(name)] ~= nil then
            for _, surface in pairs(game.surfaces) do
            
                -- Check train cars, chests, cars, player inventories, and logistics chests.
                local types = {"cargo-wagon", "container", "car", "character", "logistic-container"}
                for _, entity in pairs(surface.find_entities_filtered{type=types, force=force}) do
                    replace_in_inventory(name, changed(name), entity)
                end
            end
        
            -- Other places they might be (or be referenced):
            -- * Blueprints 
            --    Doesn't feel like it's safe to change those. If someone doesn't
            --    realize that it was changed, they might put something in their
            --    blueprint library that they don't realize contains modded entities.
            -- * Circuit conditions
            --    Those are hard enough to set up that I don't wanat people to need
            --    to fix them, and most networks won't be using them.
            -- * Construction/logistics bot inventories
            --    Small quantities, and better to not mess with those. Not likely to
            --    be heavily used, anyways.
            -- * Ghost entities
            --    I'll consider it. Might cause in-progress construction bots to break.
            -- * Inventory filters
            --    Another possibility.

        end
            
    end
end

-- Reverts all and then re-enables for forces that have it unlocked. Gets things back in sync
-- with the way they're supposed to be
function reset(force)
    force.reset_technology_effects()
    reset_internal(force)
end

-- To skip the technology effect reset when it's already being called because of one.
function reset_internal(force)
    revert_pumps(force)
    if global["unlocked"][force.name] then
        replace_pumps(force)
    end
end

script.on_event(defines.events.on_research_finished, function(event)
    local force = event.research.force
    
    if global["unlocked"][force.name] then
        -- Check for new pump recipes to override
        for _, effect in pairs(event.research.effects) do
            -- Replace the just-unlocked pump recipe with the inland version
            if effect.type == "unlock-recipe" and force.recipes[effect.recipe .. "-inland"] ~= nil then
                force.recipes[effect.recipe .. "-inland"].enabled = true
                force.recipes[effect.recipe].enabled = false
            end
        end
    elseif event.research.name == global["activation_tech"] then
        global["unlocked"][force.name] = true
        replace_pumps(force)
    end
end)

script.on_event(defines.events.on_technology_effects_reset, function(event) reset_internal(event.force) end)

-- Commands for bugfixing or mod removal
commands.add_command("inland-pumps-apply", {"inland-pumps.cmd-help-apply"}, 
    function(params)
        if game.players[params.player_index].admin then
            for _, force in pairs(game.forces) do
                global["unlocked"][force.name] = true
                replace_pumps(force)
            end
        end
    end
)

commands.add_command("inland-pumps-revert", {"inland-pumps.cmd-help-revert"},
    function(params)
        if game.players[params.player_index].admin then
            for _, force in pairs(game.forces) do
                global["unlocked"][force.name] = false
                revert_pumps(force)
            end
        end
    end
)

commands.add_command("inland-pumps-status", {"inland-pumps.cmd-help-status"},
    function(params)
        local player = game.players[params.player_index]
        if global["unlocked"][player.force.name] then
            player.print{"inland-pumps.status-unlocked"}
        else
            player.print{"inland-pumps.status-locked"}
        end
        if global["activation_tech"] ~= nil then
            player.print{"inland-pumps.status-tech", global["activation_tech"]}
        end
    end
)