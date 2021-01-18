local mod = RegisterMod("npctest command", 1)

local checkedDataDefaults = {
	CheckType = {},
	Checked = 0,
	GoalChecked = 10000,
	Champion = 0,
	Morphed = 0,
	Colors = {},
	Morphs = {},
	Room = "s.treasure.14668",
	Stages = 0,
	UsedStages = false,
	Active = false
}
local checkedData = {}

local function percentify(amount, total, digits)
	return string.format("%." .. tostring(digits or 4) .. "f%%", (amount / math.max(total, 1)) * 100)
end

local function resetdefaults()
	for k, v in pairs(checkedDataDefaults) do
		if type(v) == "table" and #v == 0 then
			checkedData[k] = {}
		else
			checkedData[k] = v
		end
	end
end

local function logResult()
	local log = ""

	if checkedData.UsedStages then
		log = log .. "Stage " .. tostring(Game():GetLevel():GetStage()) .. "\n"
	end

	log = log .. "Room Enemy Readout (" .. tostring(checkedData.GoalChecked) .. ")\nNote that if an entity is specified by the npctest command, it will not be morphed due to how MC_PRE_ROOM_ENTITY_SPAWN, so you must use a different room command instead.\n\n"
	log = log .. "Percent Champion: " .. percentify(checkedData.Champion, checkedData.Checked) .. "\n"
	log = log .. "Percent Morphed: " .. percentify(checkedData.Morphed, checkedData.Checked) .. "\n"

	log = log .. "\nChampion Colors\n"

	for i = 0, 23 do
		log = log .. tostring(i) .. ": " .. percentify(checkedData.Colors[i] or 0, checkedData.Champion) .. " of Champions\n"
	end

	local hasMorph
	local morphs = ""
	for k, v in pairs(checkedData.Morphs) do
		for k2, v2 in pairs(v) do
			for k3, v3 in pairs(v2) do
				hasMorph = true
				morphs = morphs .. tostring(k) .. ": " .. percentify(v3, checkedData.Morphed) .. " of Morphs\n"
			end
		end
	end

	if hasMorph then
		log = log .. "\nMorphed Into:\n" .. morphs .. "\n"
	else
		log = log .. "\n"
	end

	local save = log
	if Isaac.HasModData(mod) then
		save = Isaac.LoadModData(mod) .. log
	end

	Isaac.SaveModData(mod, save)

	if checkedData.Stages > 0 then
		local newStages = checkedData.Stages - 1
		local checkType = checkedData.CheckType
		local checkRoom = checkedData.Room
		local checkGoal = checkedData.GoalChecked

		resetdefaults()

		checkedData.Stages = newStages
		checkedData.UsedStages = true
		checkedData.CheckType = checkType
		checkedData.Room = checkRoom
		checkedData.GoalChecked = checkGoal
		checkedData.Active = true

		Isaac.ExecuteCommand("stage " .. tostring(Game():GetLevel():GetStage() + 1))
	else
		resetdefaults()
	end
end

mod:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, function(_, typ, var, sub, ind, seed)
	if checkedData.Active then
		if (typ > 9 and typ < 999) and ((checkedData.CheckType[1] and checkedData.CheckType[1] ~= typ) or (checkedData.CheckType[2] and checkedData.CheckType[2] ~= var) or (checkedData.CheckType[3] and checkedData.CheckType[3]) ~= sub) then
			return {
				checkedData.CheckType[1] or EntityType.ENTITY_CHARGER,
				checkedData.CheckType[2] or 0,
				checkedData.CheckType[3] or 0,
				seed
			}
		end
	end
end)

mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
	if checkedData.Active then
		for _,entity in ipairs(Isaac.GetRoomEntities()) do
			local npc = entity:ToNPC()
			if npc and checkedData.Checked < checkedData.GoalChecked then
				checkedData.Checked = checkedData.Checked + 1
				if npc:IsChampion() then
					checkedData.Champion = checkedData.Champion + 1

					local color = npc:GetChampionColorIdx()
					checkedData.Colors[color] = (checkedData.Colors[color] or 0) + 1
				end

				if (checkedData.CheckType[1] and npc.Type ~= checkedData.CheckType[1]) or (checkedData.CheckType[2] and npc.Variant ~= checkedData.CheckType[2]) or (checkedData.CheckType[3] and npc.SubType ~= checkedData.CheckType[3]) then
					checkedData.Morphed = checkedData.Morphed + 1
					if not checkedData.Morphs[npc.Type] then
						checkedData.Morphs[npc.Type] = {}
					end

					if not checkedData.Morphs[npc.Type][npc.Variant] then
						checkedData.Morphs[npc.Type][npc.Variant] = {}
					end

					checkedData.Morphs[npc.Type][npc.Variant][npc.SubType] = (checkedData.Morphs[npc.Type][npc.Variant][npc.SubType] or 0) + 1
				end
			end
		end

		if checkedData.Checked < checkedData.GoalChecked then
			Isaac.ExecuteCommand("goto " .. checkedData.Room)
		else
			logResult()
		end
	end
end)

local function ssplit(str, delim)
	local tbl = {}
	for i in string.gmatch(str, "([^" .. (delim or "%s") .. "]+)") do
	   tbl[#tbl + 1] = i
	end

	return tbl
end

mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, function(_, cmd, params)
	if cmd == "npctest" then
		resetdefaults()

		local args = ssplit(params)

		if args[1] == "help" or args[1] == "h" then
			Isaac.ConsoleOutput("npctest usage\nnpctest [Entity] [EntityCount] [StageCount] [GoTo]\nTests a certain number of entities and outputs various champion / morphing data from them into the mod's save file.\nAll arguments are optional.\n- [Entity] is specified like in spawn, Type.Variant.SubType\n[StageCount] is the number of stages to run through, starting from the current stage\n- [GoTo] is the same parameter you would pass to goto\n")
		else
			if args[1] then -- ent
				local entdata = ssplit(args[1], ".")

				local typ, var, sub
				local set

				var, sub = tonumber(entdata[2]), tonumber(entdata[3])

				if entdata[1] and tonumber(entdata[1]) then
					typ = tonumber(entdata[1])
					checkedData.CheckType = {typ, var, sub}
				end
			end

			if args[2] and tonumber(args[2]) then -- count
				checkedData.GoalChecked = tonumber(args[2])
			end

			if args[3] and tonumber(args[3]) then -- stage count
				checkedData.Stages = tonumber(args[3])
				checkedData.UsedStages = true
			end

			if args[4] then -- goto command
				checkedData.Room = args[4]
			end

			checkedData.Active = true
		end
	end
end)

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
	if checkedData.Active then
		if checkedData.Checked < checkedData.GoalChecked then
			Isaac.ExecuteCommand("goto " .. checkedData.Room)
		else
			logResult()
		end
	end
end)

mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function()
	if checkedData.Active then
		return false
	end
end)
