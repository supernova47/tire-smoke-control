-- Tire Smoke Control: scale native tire particle count and report particle types to GE.
-- Count changes are applied to the active vehicle's particle rules. Lifetime is managed
-- in the global ParticleData datablocks by the GE extension because those definitions are shared.
local M = {}
local smokeMultiplier = 1.0
local cachedRules, rulesCached = {}, false
local reportedTypes = {}

local function materialName(materials, id)
  local material = materials and materials[tonumber(id)]
  if type(material) ~= "table" then return nil end
  return material.name or material[1]
end

local function isTargetRule(rule, materials)
  if type(rule) ~= "table" then return false end
  local first = materialName(materials, rule.materialID1)
  local second = materialName(materials, rule.materialID2)
  local rubberAsphalt = (first == "RUBBER" and second == "ASPHALT") or
                        (first == "ASPHALT" and second == "RUBBER")
  local hasSlipCondition = type(rule.slipVel) == "string" and rule.slipVel ~= ""
  local isNotCollisionRule = not (type(rule.perpendicularVel) == "string" and rule.perpendicularVel ~= "")
  return rubberAsphalt and hasSlipCondition and isNotCollisionRule
end

local function reportParticleTypes()
  if not (obj and type(obj.queueGameEngineLua) == "function" and type(obj.getId) == "function") then return end
  local ok, vehicleId = pcall(function() return obj:getId() end)
  if not ok or not vehicleId then return end
  local ids, seen = {}, {}
  for _, id in ipairs(reportedTypes) do ids[#ids + 1] = tostring(id) end
  if #ids > 0 then
    local list = "{" .. table.concat(ids, ",") .. "}"
    pcall(function() obj:queueGameEngineLua("extensions.tireSmokeControl.onSmokeParticleTypes(" .. tostring(vehicleId) .. "," .. list .. ")") end)
  end
end

local function cacheRules()
  if rulesCached then return #cachedRules > 0 end
  if type(particles) ~= "table" or type(particles.getMaterialsParticlesTable) ~= "function" then
    log("W", "tireSmokeControlVehicle", "particles.getMaterialsParticlesTable unavailable")
    return false
  end
  local ok, materials, materialsMap = pcall(function() return particles.getMaterialsParticlesTable() end)
  if not ok or type(materials) ~= "table" or type(materialsMap) ~= "table" then
    log("W", "tireSmokeControlVehicle", "Could not read native particle rules")
    return false
  end
  cachedRules = {}
  reportedTypes = {}
  local seenTypes = {}
  for _, rules in pairs(materialsMap) do
    if type(rules) == "table" then
      for _, rule in pairs(rules) do
        if isTargetRule(rule, materials) then
          if rule.__tscBaseCount == nil then rule.__tscBaseCount = tonumber(rule.count) or 1 end
          if rule.__tscBaseCompare == nil then rule.__tscBaseCompare = rule.compareFunc end
          cachedRules[#cachedRules + 1] = rule
          local particleType = tonumber(rule.particleType)
          if particleType and not seenTypes[particleType] then
            seenTypes[particleType] = true
            reportedTypes[#reportedTypes + 1] = math.floor(particleType)
          end
        end
      end
    end
  end
  table.sort(reportedTypes)
  rulesCached = true
  if #cachedRules == 0 then
    log("W", "tireSmokeControlVehicle", "No RUBBER/ASPHALT tire-smoke rules found; particle rules may differ in this game version")
  else
    log("I", "tireSmokeControlVehicle", "Captured " .. tostring(#cachedRules) .. " tire-smoke rules")
    reportParticleTypes()
  end
  return #cachedRules > 0
end

local function applySmokeMultiplier()
  if not cacheRules() then return false end
  for _, rule in ipairs(cachedRules) do
    local baseCount = tonumber(rule.__tscBaseCount) or 1
    local baseCompare = rule.__tscBaseCompare
    if type(baseCompare) == "function" then
      if smokeMultiplier < 1.0 then
        rule.compareFunc = function(data)
          if not baseCompare(data) then return false end
          return math.random() < smokeMultiplier
        end
      else
        -- At x1 and above, preserve the exact native comparison function. This avoids
        -- an unnecessary Lua wrapper on every particle event and keeps x1 identical to stock.
        rule.compareFunc = baseCompare
      end
    end
    if smokeMultiplier < 1.0 then
      rule.count = baseCount
    else
      rule.count = math.max(1, math.floor(baseCount * smokeMultiplier + 0.5))
    end
  end
  return true
end

function M.setSmokeMultiplier(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then return smokeMultiplier end
  smokeMultiplier = math.floor(math.max(0.1, math.min(20.0, value)) * 10 + 0.5) / 10
  applySmokeMultiplier()
  return smokeMultiplier
end
function M.reportParticleTypes() return reportParticleTypes() end
-- Backwards-compatible alias for the original v0.1.0 API.
function M.setMultiplier(value) return M.setSmokeMultiplier(value) end
function M.getSmokeMultiplier() return smokeMultiplier end
function M.getMultiplier() return smokeMultiplier end

function M.onExtensionLoaded()
  applySmokeMultiplier()
  reportParticleTypes()
  if obj and type(obj.queueGameEngineLua) == "function" and type(obj.getId) == "function" then
    local ok, vehicleId = pcall(function() return obj:getId() end)
    if ok and vehicleId then
      pcall(function() obj:queueGameEngineLua("extensions.tireSmokeControl.onVehicleExtensionReady(" .. tostring(vehicleId) .. ")") end)
    end
  end
end
function M.onDeserialized(data)
  if type(data) == "table" and data.smokeMultiplier then M.setSmokeMultiplier(data.smokeMultiplier)
  elseif type(data) == "table" and data.multiplier then M.setSmokeMultiplier(data.multiplier)
  else applySmokeMultiplier() end
end
function M.onSerialize() return { smokeMultiplier = smokeMultiplier, multiplier = smokeMultiplier } end
return M
