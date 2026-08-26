------------------------------------------------------------------------
-- LED Management code
------------------------------------------------------------------------

local util = require('util')

local const = require('lib.constants')

local table = require('stdlib.utils.table')

---@class led.Channel
---@field channel integer
---@field brightness integer
---@field effect led.Effect
---@field lamp LuaEntity
---@field render LuaRenderObject[]

---@class led.Led
local Led = {
    MAX_CHANNELS = 64,
    DEFAULT_BRIGHTNESS = Framework.settings:startup_setting(const.settings_names.default_brightness),
    TARGET_PORT = Framework.settings:startup_setting(const.settings_names.udp_port),
}

------------------------------------------------------------------------
-- Manage channels
------------------------------------------------------------------------

---@param entity LuaEntity
---@return led.Channel?
function Led:findChannel(entity)
    local lamp_data = This:storage()
    return lamp_data.channel_assignments[entity.unit_number]
end

---@param channel_id integer
---@return led.Channel?
function Led:getChannel(channel_id)
    local lamp_data = This:storage()
    return lamp_data.channel_usage[channel_id]
end

---@param channel led.Channel
function Led:setChannel(channel)
    local lamp_data = This:storage()

    assert(channel.channel > 0)
    assert(channel.lamp and channel.lamp.valid)

    lamp_data.channel_usage[channel.channel] = channel
    lamp_data.channel_assignments[channel.lamp.unit_number] = channel

    lamp_data.last_change = game.tick
    self:markLamp(channel)
end

---@param channel led.Channel?
function Led:clearChannel(channel)
    if not channel then return end
    local lamp_data = This:storage()

    if channel.channel > 0 then
        lamp_data.channel_usage[channel.channel] = nil
    end

    if channel.lamp and channel.lamp.valid then
        lamp_data.channel_assignments[channel.lamp.unit_number] = nil
    end

    lamp_data.last_change = game.tick
    self:unmarkLamp(channel)
end

------------------------------------------------------------------------
-- Assign Lamps to channels, mark Lamps
------------------------------------------------------------------------

--- Finds a channel for an entity or creates a new channel.
---@param player LuaPlayer
---@param entity LuaEntity
function Led:selectLamp(player, entity)
    local channel = self:findChannel(entity) or {
        channel = 0,
        brightness = This.Led.DEFAULT_BRIGHTNESS,
        effect = const.effect.solid,
        lamp = entity,
        render = {},
    }

    self:markLamp(channel, true)

    player.clear_cursor()
    This.EditGui.openGui(player, channel)
end

---@param channel led.Channel
---@param channel_id integer
function Led:assignLamp(channel, channel_id)
    if channel_id < 1 then return end

    if channel.channel ~= channel_id then
        local old_channel = self:getChannel(channel_id)
        self:clearChannel(old_channel)

        if channel.channel > 0 then
            old_channel = self:getChannel(channel.channel)
            self:clearChannel(old_channel)
        end
    end

    channel.channel = channel_id
    self:setChannel(channel)
end

---@param channel led.Channel
---@param edit_mode boolean?
function Led:markLamp(channel, edit_mode)
    local color = channel.channel > 0 and { 0.1, 1, 0.2, 0.9 } or { 1, 1, 0.2, 0.9 }

    if #channel.render > 0 then self:unmarkLamp(channel) end

    channel.render[#channel.render + 1] = rendering.draw_circle {
        color = color,
        radius = 0.2,
        filled = true,
        target = { type = 'entity', entity = channel.lamp, offset = { 0.25, 0.25 } },
        surface = channel.lamp.surface,
        only_in_alt_mode = not edit_mode and channel.channel > 0,
    }

    channel.render[#channel.render + 1] = rendering.draw_text {
        color = { 0, 0, 0 },
        scale = 0.6,
        text = channel.channel > 0 and channel.channel or '',
        surface = channel.lamp.surface,
        target = { type = 'entity', entity = channel.lamp, offset = { 0.25, 0.25 } },
        alignment = 'center',
        vertical_alignment = 'middle',
        font = 'default-small-semibold',
        scale_with_zoom = false,
        only_in_alt_mode = not edit_mode and channel.channel > 0,
    }
end

---@param channel led.Channel
function Led:unmarkLamp(channel)
    for _, render in pairs(channel.render) do
        render.destroy()
    end
    channel.render = {}
end

------------------------------------------------------------------------
-- Create internal lamp state for UDP sending
------------------------------------------------------------------------

local OFF_STATES = table.array_to_dictionary({
    defines.entity_status.no_power,
    defines.entity_status.low_power,
    defines.entity_status.disabled_by_control_behavior,
    defines.entity_status.disabled_by_script,
    defines.entity_status.turned_off_during_daytime,
}, true)

---@class led.State
---@field off boolean
---@field color Color
---@field brightness integer
---@field effect led.Effect
---@field tick uint64

---@param component (number|string)?
---@return integer color_component
local function normalize_color_component(component)
    component = tonumber(component) or 0
    if component <= 1 then component = component * 255 end
    return math.max(0, math.min(255, math.floor(component + 0.5)))
end


---@param color Color
---@return Color new_color
local function normalize_color(color)
    return {
        r = normalize_color_component(color.r),
        g = normalize_color_component(color.g),
        b = normalize_color_component(color.b),
    }
end

---@param channel led.Channel
---@return led.State?
local function create_lamp_state(channel)
    if not (channel.lamp and channel.lamp.valid) then return nil end

    local lamp_control = assert(channel.lamp.get_or_create_control_behavior()) --[[@as LuaLampControlBehavior]]

    local off = lamp_control.disabled or OFF_STATES[channel.lamp.status] or false
    local color = normalize_color(lamp_control.color or channel.lamp.color or { r = 1, g = 1, b = 1 })

    return {
        id = channel.channel - 1,
        r = off and 0 or color.r,
        g = off and 0 or color.g,
        b = off and 0 or color.b,
        brightness = channel.brightness,
        effect = const.effect_names[channel.effect],
    }
end

function Led:syncLampState()
    local lamp_data = This:storage()

    lamp_data.state = {}
    for channel_id, channel in pairs(lamp_data.channel_usage) do
        lamp_data.state[channel_id] = create_lamp_state(channel)
    end
end

------------------------------------------------------------------------
-- Resync state
------------------------------------------------------------------------

function Led:cleanupLamps()
    local lamp_data = This:storage()

    -- find all actual channel_assignments and the entities that use it
    local channel_assignments = {}
    for channel_id, channel in pairs(lamp_data.channel_usage) do
        if (channel.lamp and channel.lamp.valid) then
            channel_assignments[channel.lamp.unit_number] = channel
        else
            self:unmarkLamp(channel)
            lamp_data.channel_usage[channel_id] = nil
        end
    end

    for entity_id, channel in pairs(lamp_data.channel_assignments) do
        if not ((channel.lamp and channel.lamp.valid) and channel_assignments[entity_id]) then
            self:unmarkLamp(channel)
            lamp_data.channel_assignments[entity_id] = nil
        else
            self:markLamp(channel)
        end
    end

    for entity_id, channel in pairs(channel_assignments) do
        if not lamp_data.channel_assignments[entity_id] then
            self:setChannel(channel)
        end
    end
end

---@param type string
---@param payload led.State[]
local function send_udp(type, payload)
    local lamp_data = This:storage()

    -- reset is called out of on_load, do NOT write to storage
    if type ~= 'reset' then
        lamp_data.msg_sequence = lamp_data.msg_sequence + 1
    end

    local frame = {
        version = 2,
        save_id = lamp_data.game_id,
        sequence = lamp_data.msg_sequence,
        tick = game and game.tick or 0,
        type = type,
        channels = payload,
    }

    helpers.send_udp(Led.TARGET_PORT, helpers.table_to_json(frame))
end

---@param state led.State[]
local function create_channel_data(state)
    local channels = {}

    for _, s in pairs(state) do
        channels[#channels + 1] = s
    end

    table.sort(channels, function(a, b) return a.id < b.id end)

    return channels
end

function Led:reset()
    local lamp_data = This:storage()
    local channels = create_channel_data(lamp_data.state)
    send_udp('reset', channels)
end

function Led:tick()
    local lamp_data = This:storage()
    local snapshot = (game.tick % 300) == 0

    self:syncLampState()

    if snapshot or not lamp_data.previous then
        local channels = create_channel_data(lamp_data.state)
        lamp_data.previous = util.copy(lamp_data.state)
        send_udp('snapshot', channels)
    else
        local changes = {}
        for channel_id, state in pairs(lamp_data.state) do
            local old_state = lamp_data.previous[channel_id] or {}
            for k, v in pairs(state) do
                if v ~= old_state[k] then
                    changes[#changes + 1] = state
                    lamp_data.previous[channel_id] = state
                    break
                end
            end
        end

        for channel_id in pairs(lamp_data.previous) do
            if not lamp_data.state[channel_id] then
                changes[#changes + 1] = {
                    id = channel_id - 1,
                    r = 0,
                    g = 0,
                    b = 0,
                    brightness = 0,
                    effect = const.effect_names[1],
                }
                lamp_data.previous[channel_id] = nil
            end
        end

        if #changes > 0 then
            send_udp('update', changes)
        end
    end
end

return Led
