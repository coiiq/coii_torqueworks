TorqueWorksBrakes = {}
local wheelBoneCache = {}

local function wheelBones(vehicle, definitions)
    local model = GetEntityModel(vehicle)
    local cached = wheelBoneCache[model]
    if cached then return cached end
    cached = {}
    for index, definition in ipairs(definitions) do
        cached[index] = GetEntityBoneIndexByName(vehicle, definition.name)
    end
    wheelBoneCache[model] = cached
    return cached
end

local function heatColor(normalized)
    -- Warm orange through saturated red to pale white-hot highlights.
    if normalized < 0.65 then
        local blend = TorqueWorksMath.clamp(normalized / 0.65, 0.0, 1.0)
        return 255, math.floor(TorqueWorksMath.lerp(70, 18, blend)), 4
    end
    local blend = TorqueWorksMath.clamp((normalized - 0.65) / 0.35, 0.0, 1.0)
    return 255, math.floor(TorqueWorksMath.lerp(18, 150, blend)),
        math.floor(TorqueWorksMath.lerp(4, 95, blend))
end

function TorqueWorksBrakes.drawHeat(vehicle, heat)
    local config = Config.BrakeVisuals
    if not config.enabled or not DoesEntityExist(vehicle) then return end
    heat = TorqueWorksMath.clamp(tonumber(heat) or 0.0, 0.0, 1.0)
    if heat <= 0.001 then return end

    -- Fade smoothly through the former visibility threshold instead of
    -- abruptly removing the frame-drawn light when the brakes cool.
    local lowHeatFade = TorqueWorksMath.clamp(heat /
        math.max(0.01, config.visibleHeatThreshold), 0.0, 1.0)
    lowHeatFade = lowHeatFade * lowHeatFade
    local visible = TorqueWorksMath.clamp((heat - config.visibleHeatThreshold) /
        math.max(0.01, 1.0 - config.visibleHeatThreshold), 0.0, 1.0)
    local red, green, blue = heatColor(visible)
    local intensity = TorqueWorksMath.lerp(config.minimumIntensity,
        config.maximumIntensity, visible * visible) * lowHeatFade
    local range = config.lightRange * TorqueWorksMath.lerp(0.35, 1.0, lowHeatFade)

    local bones = wheelBones(vehicle, config.wheelBones)
    for index, definition in ipairs(config.wheelBones) do
        local bone = bones[index]
        if bone ~= -1 then
            local position = GetWorldPositionOfEntityBone(vehicle, bone)
            DrawLightWithRange(position.x, position.y, position.z,
                red, green, blue, range,
                intensity * (definition.front and 1.0 or config.rearIntensityMultiplier))
        end
    end
end

function TorqueWorksBrakes.temperature(heat)
    return math.floor(TorqueWorksMath.lerp(35.0,
        Config.BrakeVisuals.maximumTemperatureC,
        TorqueWorksMath.clamp(tonumber(heat) or 0.0, 0.0, 1.0)) + 0.5)
end
