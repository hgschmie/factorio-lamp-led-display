local Support = {}

function Support.eq(actual, expected, message)
    if actual ~= expected then
        error((message or 'values differ') .. ': got ' .. tostring(actual) .. ', expected ' .. tostring(expected), 2)
    end
end

function Support.truthy(value, message)
    if not value then error(message or 'expected a truthy value', 2) end
end

function Support.falsy(value, message)
    if value then error(message or 'expected a falsy value', 2) end
end

function Support.deep_copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[Support.deep_copy(key, seen)] = Support.deep_copy(child, seen)
    end
    return result
end

function Support.rendering_mock()
    local objects = {}

    local function draw(kind, definition)
        local object = {
            kind = kind,
            definition = definition,
            destroyed = false,
        }
        function object.destroy()
            object.destroyed = true
        end
        objects[#objects + 1] = object
        return object
    end

    return {
        objects = objects,
        draw_circle = function(definition) return draw('circle', definition) end,
        draw_text = function(definition) return draw('text', definition) end,
    }
end

function Support.lamp(unit_number, options)
    options = options or {}
    local control = {
        disabled = options.disabled or false,
        color = options.control_color,
    }
    local lamp = {
        valid = options.valid ~= false,
        unit_number = unit_number,
        status = options.status or 0,
        color = options.color or { r = 1, g = 1, b = 1 },
        position = options.position or { x = unit_number, y = unit_number },
        surface = options.surface or {},
        surface_index = options.surface_index or 1,
    }
    function lamp.get_or_create_control_behavior()
        return control
    end
    lamp.control = control
    return lamp
end

return Support
