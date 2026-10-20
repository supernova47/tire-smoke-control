-- Tire Smoke Control v0.2.3: adds configurable slow-rise control for native tire-smoke particles.
local M = {}
local CONFIG_PATH = "settings/tireSmokeControl.json"
local DEFAULT_SMOKE, MIN_SMOKE, MAX_SMOKE = 1.0, 0.1, 20.0
local DEFAULT_LIFETIME, MIN_LIFETIME, MAX_LIFETIME = 1.0, 0.1, 10.0
local DEFAULT_RISE, MIN_RISE, MAX_RISE = 0.25, 0.0, 2.0
local smokeMultiplier, lifetimeMultiplier, riseMultiplier = DEFAULT_SMOKE, DEFAULT_LIFETIME, DEFAULT_RISE
local pollElapsed, pollInterval = 0, 0.25
local currentPlayerVehicleId, currentPlayerVehicle = nil, nil
local lastCommandedVehicleId, lastCommandedSmoke = nil, nil
local smokeParticleTypes = {}
local lastParticleScriptKey = nil
local particleDataBaselines = {}

local function clamp(value, low, high)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
  return math.floor(math.max(low, math.min(high, value)) * 10 + 0.5) / 10
end
local function clampSmoke(value) return clamp(value, MIN_SMOKE, MAX_SMOKE) end
local function clampLifetime(value) return clamp(value, MIN_LIFETIME, MAX_LIFETIME) end
local function clampRise(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
  return math.floor(math.max(MIN_RISE, math.min(MAX_RISE, value)) * 100 + 0.5) / 100
end

local function publishState()
  if guihooks and type(guihooks.trigger) == "function" then
    pcall(function() guihooks.trigger("TireSmokeControlStateUpdate", {
      smokeMultiplier = smokeMultiplier,
      multiplier = smokeMultiplier,
      lifetimeMultiplier = lifetimeMultiplier,
      riseMultiplier = riseMultiplier,
      playerVehicleActive = currentPlayerVehicleId ~= nil,
      vehicleId = currentPlayerVehicleId,
      lifetimeTypesFound = #smokeParticleTypes > 0,
      riseTypesFound = #smokeParticleTypes > 0
    }) end)
  end
end

local function loadConfig()
  smokeMultiplier, lifetimeMultiplier, riseMultiplier = DEFAULT_SMOKE, DEFAULT_LIFETIME, DEFAULT_RISE
  if type(jsonReadFile) == "function" then
    local ok, config = pcall(jsonReadFile, CONFIG_PATH)
    if ok and type(config) == "table" then
      smokeMultiplier = clampSmoke(config.smokeMultiplier) or DEFAULT_SMOKE
      lifetimeMultiplier = clampLifetime(config.lifetimeMultiplier) or DEFAULT_LIFETIME
      riseMultiplier = clampRise(config.riseMultiplier) or DEFAULT_RISE
    end
  end
  log("I", "tireSmokeControl", "Loaded tire smoke settings: count x" .. tostring(smokeMultiplier) .. ", lifetime x" .. tostring(lifetimeMultiplier) .. ", upward drift x" .. tostring(riseMultiplier))
end

local function saveConfig()
  if type(jsonWriteFile) ~= "function" then
    log("W", "tireSmokeControl", "jsonWriteFile unavailable; settings active but not persisted")
    return false
  end
  local ok, result = pcall(jsonWriteFile, CONFIG_PATH, {
    smokeMultiplier = smokeMultiplier,
    lifetimeMultiplier = lifetimeMultiplier,
    riseMultiplier = riseMultiplier
  }, true)
  if not ok or result == false then
    log("W", "tireSmokeControl", "Could not save " .. CONFIG_PATH)
    return false
  end
  return true
end

local function buildVehicleCommand(value, shouldLoad)
  local val = string.format("%.1f", value)
  local command = shouldLoad and "extensions.load('tireSmokeControlVehicle'); " or ""
  command = command .. "if tireSmokeControlVehicle and tireSmokeControlVehicle.setSmokeMultiplier then " ..
    "tireSmokeControlVehicle.setSmokeMultiplier(" .. val .. "); " ..
    "if tireSmokeControlVehicle.reportParticleTypes then tireSmokeControlVehicle.reportParticleTypes(); end " ..
    "elseif extensions and extensions.tireSmokeControlVehicle and extensions.tireSmokeControlVehicle.setSmokeMultiplier then " ..
    "extensions.tireSmokeControlVehicle.setSmokeMultiplier(" .. val .. "); " ..
    "if extensions.tireSmokeControlVehicle.reportParticleTypes then extensions.tireSmokeControlVehicle.reportParticleTypes(); end end"
  return command
end

local function queueVehicleCommand(vehicle, value, shouldLoad)
  if not vehicle or type(vehicle.queueLuaCommand) ~= "function" then return false end
  local command = buildVehicleCommand(value, shouldLoad)
  local ok = pcall(function() vehicle:queueLuaCommand(command) end)
  if ok then
    lastCommandedVehicleId = currentPlayerVehicleId
    lastCommandedSmoke = value
  end
  return ok
end

-- Count is global for all currently spawned vehicles, including traffic. The native
-- ParticleData lifetime is shared as well; this avoids a custom per-vehicle particle system.
local function queueAllVehicleCommands(value)
  local command = buildVehicleCommand(value, true)
  if be and type(be.queueAllObjectLua) == "function" then
    local ok = pcall(function() be:queueAllObjectLua(command) end)
    if ok then
      lastCommandedVehicleId = currentPlayerVehicleId
      lastCommandedSmoke = value
      return true
    end
  end
  -- Fallback for versions without queueAllObjectLua: keep the active player's vehicle working.
  if currentPlayerVehicle then return queueVehicleCommand(currentPlayerVehicle, value, true) end
  return false
end

local function queueSpawnedVehicle(vehicleId)
  vehicleId = tonumber(vehicleId)
  if not vehicleId then return false end
  local vehicle = nil
  if be and type(be.getObjectByID) == "function" then
    local ok, result = pcall(function() return be:getObjectByID(vehicleId) end)
    if ok then vehicle = result end
  end
  if not vehicle and scenetree and type(scenetree.findObjectById) == "function" then
    local ok, result = pcall(function() return scenetree.findObjectById(vehicleId) end)
    if ok then vehicle = result end
  end
  if vehicle then return queueVehicleCommand(vehicle, smokeMultiplier, true) end
  return false
end

function M.onVehicleSpawned(vehicleId)
  -- BeamNG versions differ slightly in the shape of spawn hook arguments.
  if type(vehicleId) == "table" then
    vehicleId = vehicleId.vehicleId or vehicleId.vehId or vehicleId.id
  end
  queueSpawnedVehicle(vehicleId)
end

function M.onWorldReadyState(state)
  if tonumber(state) == 2 then queueAllVehicleCommands(smokeMultiplier) end
end

local function findDataBlock(name)
  if scenetree and type(scenetree.findObject) == "function" then
    local ok, object = pcall(scenetree.findObject, name)
    if ok and object then return object end
  end

  if Sim and type(Sim.getDataBlockSet) == "function" then
    local ok, dataBlockSet = pcall(Sim.getDataBlockSet)
    if ok and dataBlockSet and type(dataBlockSet.size) == "function" and type(dataBlockSet.at) == "function" then
      for index = 0, dataBlockSet:size() - 1 do
        local found, dataBlock = pcall(dataBlockSet.at, dataBlockSet, index)
        if found and dataBlock then
          local nameOk, objectName = pcall(dataBlock.getName, dataBlock)
          if nameOk and objectName == name then
            if type(Sim.upcast) == "function" then
              local upcastOk, object = pcall(Sim.upcast, dataBlock)
              if upcastOk and object then return object end
            end
            return dataBlock
          end
        end
      end
    end
  end
  return nil
end

local function readDataBlockNumber(object, fieldName)
  if not object or type(object.getField) ~= "function" then return nil end
  local ok, value = pcall(object.getField, object, fieldName, 0)
  if ok then return tonumber(value) end
  return nil
end

local function setDataBlockNumber(object, fieldName, value)
  if not object or type(object.setField) ~= "function" then return false end
  local ok = pcall(object.setField, object, fieldName, 0, tostring(value))
  return ok
end

local function getParticleDataObjects()
  local found, seen = {}, {}
  for _, particleType in ipairs(smokeParticleTypes) do
    local emitter = findDataBlock("BNGP_" .. tostring(particleType))
    if emitter and type(emitter.getField) == "function" then
      local ok, particleNames = pcall(emitter.getField, emitter, "particles", "")
      if ok and type(particleNames) == "string" then
        for particleName in particleNames:gmatch("[^%s]+") do
          if not seen[particleName] then
            local particle = findDataBlock(particleName)
            local classOk, className = false, nil
            if particle and type(particle.getClassName) == "function" then
              classOk, className = pcall(particle.getClassName, particle)
            end
            if particle and classOk and className == "ParticleData" then
              seen[particleName] = true
              found[#found + 1] = { name = particleName, object = particle }
            end
          end
        end
      end
    end
  end
  return found
end

-- Use BeamNG's Lua datablock API. It stays compatible with the 0.40.1 managed
-- particle datablocks and avoids relying on TorqueScript variable resolution.
local function applyParticleSettings()
  if #smokeParticleTypes == 0 then
    log("D", "tireSmokeControl", "Particle settings are waiting for smoke particle types from the active player vehicle")
    return false
  end

  local keyParts = {string.format("%.1f", lifetimeMultiplier), string.format("%.2f", riseMultiplier)}
  for _, id in ipairs(smokeParticleTypes) do keyParts[#keyParts + 1] = tostring(id) end
  local scriptKey = table.concat(keyParts, ":")
  if scriptKey == lastParticleScriptKey then return true end

  local appliedCount = 0
  for _, entry in ipairs(getParticleDataObjects()) do
    local particle, name = entry.object, entry.name
    local baseline = particleDataBaselines[name]
    if not baseline then
      baseline = {
        lifetimeMS = readDataBlockNumber(particle, "lifetimeMS"),
        gravityCoefficient = readDataBlockNumber(particle, "gravityCoefficient")
      }
      particleDataBaselines[name] = baseline
    end

    local changed = false
    if baseline.lifetimeMS and baseline.lifetimeMS > 0 then
      local lifetime = math.max(1, math.floor(baseline.lifetimeMS * lifetimeMultiplier + 0.5))
      changed = setDataBlockNumber(particle, "lifetimeMS", lifetime) or changed
    end
    if baseline.gravityCoefficient then
      local gravity = baseline.gravityCoefficient < 0 and baseline.gravityCoefficient * riseMultiplier or baseline.gravityCoefficient
      changed = setDataBlockNumber(particle, "gravityCoefficient", gravity) or changed
    end
    if changed then
      if type(particle.reload) == "function" then pcall(particle.reload, particle) end
      appliedCount = appliedCount + 1
    end
  end

  if appliedCount <= 0 then
    log("W", "tireSmokeControl", "No compatible tire-smoke ParticleData datablocks found through BeamNG's Lua datablock API.")
    return false
  end
  lastParticleScriptKey = scriptKey
  log("I", "tireSmokeControl", "Applied particle settings to " .. tostring(appliedCount) ..
      " ParticleData objects (lifetime x" .. tostring(lifetimeMultiplier) ..
      ", upward drift x" .. tostring(riseMultiplier) .. ")")
  return true
end

function M.setSmokeMultiplier(value)
  local cleaned = clampSmoke(value)
  if not cleaned then return smokeMultiplier end
  smokeMultiplier = cleaned
  saveConfig()
  queueAllVehicleCommands(smokeMultiplier)
  publishState()
  if type(ui_message) == "function" then
    pcall(function() ui_message("Smoke amount: x" .. string.format("%.1f", smokeMultiplier), 2, "info") end)
  end
  log("I", "tireSmokeControl", "Smoke count multiplier set to x" .. tostring(smokeMultiplier))
  return smokeMultiplier
end
function M.setMultiplier(value) return M.setSmokeMultiplier(value) end

function M.setLifetimeMultiplier(value)
  local cleaned = clampLifetime(value)
  if not cleaned then return lifetimeMultiplier end
  lifetimeMultiplier = cleaned
  saveConfig()
  lastParticleScriptKey = nil
  applyParticleSettings()
  publishState()
  if type(ui_message) == "function" then
    pcall(function() ui_message("Smoke lifetime: x" .. string.format("%.1f", lifetimeMultiplier), 2, "info") end)
  end
  log("I", "tireSmokeControl", "Particle lifetime multiplier set to x" .. tostring(lifetimeMultiplier))
  return lifetimeMultiplier
end

function M.setRiseMultiplier(value)
  local cleaned = clampRise(value)
  if cleaned == nil then return riseMultiplier end
  riseMultiplier = cleaned
  saveConfig()
  lastParticleScriptKey = nil
  applyParticleSettings()
  publishState()
  if type(ui_message) == "function" then
    local message = riseMultiplier == 0 and "Smoke upward movement from gravityCoefficient is disabled" or
      "Smoke rise: x" .. string.format("%.2f", riseMultiplier)
    pcall(function() ui_message(message, 2, "info") end)
  end
  log("I", "tireSmokeControl", "Smoke upward drift multiplier set to x" .. string.format("%.2f", riseMultiplier))
  return riseMultiplier
end

function M.sendStateToUI() publishState(); return smokeMultiplier end

function M.onSmokeParticleTypes(vehicleId, particleTypes)
  vehicleId = tonumber(vehicleId)
  if not vehicleId or type(particleTypes) ~= "table" then return end
  -- Particle lifetime is global, but the type list must come from a player vehicle.
  -- Traffic vehicle callbacks are ignored to avoid repeated global lifetime writes.
  if not currentPlayerVehicleId or vehicleId ~= tonumber(currentPlayerVehicleId) then return end
  local previous = smokeParticleTypes
  local merged, seen = {}, {}
  for _, id in ipairs(smokeParticleTypes) do
    id = tonumber(id)
    if id and not seen[id] then seen[id] = true; merged[#merged + 1] = id end
  end
  for _, id in ipairs(particleTypes) do
    id = tonumber(id)
    if id and id >= 0 and id == math.floor(id) and not seen[id] then seen[id] = true; merged[#merged + 1] = id end
  end
  table.sort(merged)
  local changed = #merged ~= #previous
  if not changed then
    for i, id in ipairs(merged) do
      if id ~= previous[i] then changed = true; break end
    end
  end
  smokeParticleTypes = merged
  if changed then
    lastParticleScriptKey = nil
    applyParticleSettings()
  end
  publishState()
end

function M.onVehicleExtensionReady(vehicleId)
  vehicleId = tonumber(vehicleId)
  if vehicleId and currentPlayerVehicleId and vehicleId == tonumber(currentPlayerVehicleId) and currentPlayerVehicle then
    queueVehicleCommand(currentPlayerVehicle, smokeMultiplier, false)
  end
end

local function updateActivePlayerVehicle()
  local vehicle = nil
  if be and type(be.getPlayerVehicle) == "function" then
    local ok, result = pcall(function() return be:getPlayerVehicle(0) end)
    if ok then vehicle = result end
  end
  local id = nil
  if vehicle and type(vehicle.getId) == "function" then
    local ok, result = pcall(function() return vehicle:getId() end)
    if ok then id = result end
  end
  if not id then
    local hadVehicle = currentPlayerVehicleId ~= nil
    currentPlayerVehicleId, currentPlayerVehicle = nil, nil
    lastCommandedVehicleId, lastCommandedSmoke = nil, nil
    if hadVehicle then publishState() end
    return
  end
  local changed = id ~= currentPlayerVehicleId
  currentPlayerVehicleId, currentPlayerVehicle = id, vehicle
  if changed or lastCommandedVehicleId ~= id or lastCommandedSmoke ~= smokeMultiplier then
    queueVehicleCommand(vehicle, smokeMultiplier, true)
    publishState()
  end
end

function M.onUpdate(dtReal, dtSim, dtRaw)
  pollElapsed = pollElapsed + (tonumber(dtReal) or 0)
  if pollElapsed < pollInterval then return end
  pollElapsed = 0
  updateActivePlayerVehicle()
end

function M.onExtensionLoaded()
  loadConfig()
  publishState()
  -- Apply to vehicles already present; onVehicleSpawned handles later traffic/player spawns.
  queueAllVehicleCommands(smokeMultiplier)
  -- If native particle types were discovered earlier in the same session, reapply settings.
  applyParticleSettings()
end
function M.onExtensionUnloaded()
  currentPlayerVehicleId, currentPlayerVehicle = nil, nil
end
return M
