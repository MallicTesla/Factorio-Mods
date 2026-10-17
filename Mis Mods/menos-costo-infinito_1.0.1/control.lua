-- Actualiza las tecnologias infinitas que ya existian en partidas guardadas.
-- Factorio guarda el nivel y el progreso por fuerza, por eso hay que recargar
-- la tecnologia despues de cambiar su formula en data-final-fixes.lua.

local tecnologias_base = {
    ["energy-weapons-damage"] = true,
    ["physical-projectile-damage"] = true,
    ["refined-flammables"] = true,
    ["stronger-explosives"] = true,
    ["artillery-shell-range"] = true,
    ["artillery-shell-speed"] = true,
    ["worker-robots-speed"] = true,
    ["mining-productivity"] = true,
    ["follower-robot-count"] = true
}

local function es_tecnologia_infinita_base(tecnologia)
    local prefijo = tecnologia.name:match("^(.*)%-(%d+)$")

    return tecnologias_base[prefijo]
        and tecnologia.prototype.max_level == "infinite"
end

local function actualizar_tecnologias_guardadas()
    for _, fuerza in pairs(game.forces) do
        for _, tecnologia in pairs(fuerza.technologies) do
            if es_tecnologia_infinita_base(tecnologia) then
                local progreso = tecnologia.saved_progress

                tecnologia:reload()
                tecnologia.saved_progress = progreso
            end
        end
    end
end

script.on_init(actualizar_tecnologias_guardadas)
script.on_configuration_changed(actualizar_tecnologias_guardadas)
