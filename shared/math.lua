TorqueWorksMath = {}

function TorqueWorksMath.clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function TorqueWorksMath.lerp(current, target, alpha)
    return current + (target - current) * TorqueWorksMath.clamp(alpha, 0.0, 1.0)
end

function TorqueWorksMath.interpolateCurve(points, rpm)
    if not points or #points == 0 then return 1.0 end

    rpm = TorqueWorksMath.clamp(rpm, 0.0, 1.0)
    if rpm <= points[1].rpm then return points[1].torque end

    for index = 2, #points do
        local right = points[index]
        if rpm <= right.rpm then
            local left = points[index - 1]
            local width = right.rpm - left.rpm
            if width <= 0.0 then return right.torque end
            local alpha = (rpm - left.rpm) / width
            return TorqueWorksMath.lerp(left.torque, right.torque, alpha)
        end
    end

    return points[#points].torque
end

