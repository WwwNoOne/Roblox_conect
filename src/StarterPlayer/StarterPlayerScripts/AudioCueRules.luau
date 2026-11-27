--!strict
-- Client presentation policy only: no gameplay state or remotes.
local Rules = {}
Rules.GeneratorRange = 42
Rules.SparkRange = 55
local chaseStates: { [string]: boolean } = { Chase=true, Windup=true, Lunge=true, Recover=true, Charge=true, FinalChase=true }
function Rules.CanUse(inRun: boolean, alive: boolean, hidden: boolean, safe: boolean): boolean
	return inRun and alive and not hidden and not safe
end
function Rules.CanHearChase(state: string, distance: number, target: string?, playerName: string, visible: boolean): boolean
	if not chaseStates[state] or distance > 95 then return false end
	if target ~= nil then return target == playerName end
	-- Base aggressors do not publish Target. Only use a nearby visible threat.
	return distance <= 55 and visible
end
function Rules.ShowGenerator(state: string, distance: number, canUse: boolean): boolean
	return canUse and state == 'Broken' and distance <= Rules.GeneratorRange
end
return table.freeze(Rules)
