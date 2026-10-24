-- Factorio 2.x pumps draw the fluid defined by the tile at fluid_source_offset.
-- Ground tiles do not define a fluid in vanilla, so give them water.
for _, tile in pairs(data.raw.tile) do
    local layers = tile.collision_mask and tile.collision_mask.layers
    if layers and layers.ground_tile and tile.fluid == nil then
        tile.fluid = "water"
    end
end

local pump = data.raw["offshore-pump"]["offshore-pump"]

if pump == nil then
    error("Inland Pumps requires the base game's offshore pump prototypes.")
end

-- In 2.x these rules enforce the shore and intake-water requirements. Removing
-- them makes the original base-game pump placeable anywhere; its intake receives
-- water from the ground tile configured above.
pump.tile_buildability_rules = nil
