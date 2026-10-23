-- Modifica unicamente las tecnologias infinitas del juego base.
-- Establece 1000 paquetes de ciencia para el primer nivel infinito y aplica
-- un multiplicador de 1.1 a cada nivel posterior.

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

for nombre, tecnologia in pairs(data.raw.technology) do
    local prefijo, primer_nivel = nombre:match("^(.*)%-(%d+)$")

    if tecnologias_base[prefijo]
        and tecnologia.max_level == "infinite"
        and tecnologia.unit
        and tecnologia.unit.count_formula then
        tecnologia.unit.count_formula = "1000 * (1.1 ^ (L - " .. primer_nivel .. "))"
    end
end
