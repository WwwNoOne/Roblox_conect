--!strict
-- Utilidades de hora del día compartidas por servidor y cliente.
local TimeOfDay = {}

-- 0 de día (7h-17h), 1 de noche (20h-4h), transiciones lineales de 3 h.
function TimeOfDay.Nightness(t: number): number
	if t >= 7 and t <= 17 then
		return 0
	elseif t >= 20 or t <= 4 then
		return 1
	elseif t > 17 then
		return (t - 17) / 3
	end
	return (7 - t) / 3
end

return TimeOfDay
