-- Actualiza las tecnologias infinitas que ya existian en partidas guardadas.
-- Factorio guarda el nivel y el progreso por fuerza, por eso hay que recargar
-- la tecnologia despues de cambiar su formula en data-final-fixes.lua.

local tecnologias_infinita_base = {
    ["energy-weapons-damage-7"] = true,
    ["physical-projectile-damage-7"] = true,
    ["refined-flammables-7"] = true,
    ["stronger-explosives-7"] = true,
    ["artillery-shell-range-1"] = true,
    ["artillery-shell-speed-1"] = true,
    ["worker-robots-speed-6"] = true,
    ["mining-productivity-4"] = true,
    ["follower-robot-count-5"] = true
}

local function es_tecnologia_infinita_base(tecnologia)
    return tecnologias_infinita_base[tecnologia.name] == true
end

local function actualizar_tecnologias_guardadas()
    for _, fuerza in pairs(game.forces) do
        for _, tecnologia in pairs(fuerza.technologies) do
            if es_tecnologia_infinita_base(tecnologia) then
                local progreso = tecnologia.saved_progress

                tecnologia.reload()
                tecnologia.saved_progress = progreso
            end
        end
    end
end

script.on_init(actualizar_tecnologias_guardadas)
script.on_configuration_changed(actualizar_tecnologias_guardadas)
