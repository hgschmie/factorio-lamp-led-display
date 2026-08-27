package.path = './?.lua;../lamp_led_display/?.lua;' .. package.path

local support = require('test_support')
local eq, truthy, falsy = support.eq, support.truthy, support.falsy

package.preload.util = function()
    return { copy = support.deep_copy }
end

local sent_packets = {}

local function install_factorio_mocks()
    _G.storage = {}
    _G.game = { tick = 0 }
    _G.defines = {
        entity_status = {
            no_power = 1,
            low_power = 2,
            disabled_by_control_behavior = 3,
            disabled_by_script = 4,
            turned_off_during_daytime = 5,
        },
        events = {
            on_gui_closed = 10,
            on_gui_click = 11,
            on_gui_confirmed = 12,
            on_gui_value_changed = 13,
            on_gui_selection_state_changed = 14,
            on_lua_shortcut = 15,
        },
        controllers = { remote = 1 },
    }
    _G.rendering = support.rendering_mock()
    _G.helpers = {
        table_to_json = function(value) return value end,
        send_udp = function(port, payload)
            sent_packets[#sent_packets + 1] = { port = port, payload = payload }
        end,
    }
    _G.Framework = {
        settings = {
            startup_setting = function(_, name)
                if name == 'default_brightness' then return 64 end
                if name == 'udp_port' then return 34198 end
                error('unexpected setting ' .. tostring(name))
            end,
        },
        gui_manager = {
            registerGuiType = function() end,
            destroyGui = function() end,
        },
    }
end

local function reset_packets()
    for key in pairs(sent_packets) do sent_packets[key] = nil end
end

local function test_storage_initialization()
    package.loaded['lib.this'] = nil
    local this = require('lib.this')
    this:init()

    local data = this:storage()
    truthy(data.channel_usage, 'channel usage was not initialized')
    truthy(data.channel_assignments, 'channel assignments were not initialized')
    truthy(data.state, 'channel state was not initialized')
    truthy(data.game_id:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%x%x%x%x$'), 'game id has the wrong format')
    eq(data.msg_sequence, 0)

    local game_id = data.game_id
    data.msg_sequence = 17
    this:init()
    eq(this:storage().game_id, game_id, 'init replaced the persistent game id')
    eq(this:storage().msg_sequence, 17, 'init replaced the persistent sequence')
    return this
end

install_factorio_mocks()
local This = test_storage_initialization()
_G.This = This

package.loaded['scripts.led'] = nil
local Led = require('scripts.led')
This.Led = Led

local function reset_led_storage()
    storage.led_data = {
        channel_usage = {},
        channel_assignments = {},
        state = {},
        game_id = '12345678-90abcdef',
        msg_sequence = 0,
    }
    reset_packets()
    rendering = support.rendering_mock()
end

local function new_channel(lamp, channel, brightness, effect)
    return {
        channel = channel or 0,
        brightness = brightness or 64,
        effect = effect or 1,
        lamp = lamp,
        render = {},
    }
end

local function test_channel_management_and_markers()
    reset_led_storage()
    local first_lamp = support.lamp(101)
    local first = new_channel(first_lamp)

    Led:markLamp(first, true)
    eq(#first.render, 2)
    falsy(first.render[1].definition.only_in_alt_mode, 'edit marker should be visible outside Alt mode')

    Led:assignLamp(first, 1)
    eq(Led:getChannel(1), first)
    eq(Led:findChannel(first_lamp), first)
    truthy(first.render[1].definition.only_in_alt_mode, 'assigned marker should require Alt mode')

    local old_render = first.render[1]
    local second_lamp = support.lamp(102)
    local second = new_channel(second_lamp)
    Led:assignLamp(second, 1)
    eq(Led:getChannel(1), second, 'new lamp did not replace the channel owner')
    eq(Led:findChannel(first_lamp), nil, 'replaced lamp retained an assignment')
    truthy(old_render.destroyed, 'replaced lamp marker was not destroyed')

    Led:assignLamp(second, 64)
    eq(Led:getChannel(1), nil)
    eq(Led:getChannel(64), second)

    second_lamp.valid = false
    local second_render = second.render[1]
    Led:cleanupLamps()
    eq(Led:getChannel(64), nil, 'invalid lamp retained a channel')
    eq(storage.led_data.channel_assignments[102], nil, 'invalid lamp retained an entity assignment')
    truthy(second_render.destroyed, 'invalid lamp marker was not destroyed')
end

local function test_lamp_state_conversion()
    reset_led_storage()
    local lamp = support.lamp(201, { control_color = { r = 0.5, g = 2, b = 300 } })
    local channel = new_channel(lamp, 8, 127, 3)
    Led:setChannel(channel)
    Led:syncLampState()

    local state = storage.led_data.state[8]
    eq(state.id, 7)
    eq(state.r, 128)
    eq(state.g, 2)
    eq(state.b, 255)
    eq(state.brightness, 127)
    eq(state.effect, 'pulse')

    lamp.control.disabled = true
    Led:syncLampState()
    state = storage.led_data.state[8]
    eq(state.r, 0); eq(state.g, 0); eq(state.b, 0)

    lamp.control.disabled = false
    lamp.status = defines.entity_status.no_power
    Led:syncLampState()
    state = storage.led_data.state[8]
    eq(state.r, 0); eq(state.g, 0); eq(state.b, 0)
end

local function test_udp_snapshots_updates_and_reset()
    reset_led_storage()
    local high_lamp = support.lamp(301, { control_color = { r = 1, g = 0, b = 0 } })
    local low_lamp = support.lamp(302, { control_color = { r = 0, g = 1, b = 0 } })
    local high = new_channel(high_lamp, 64, 255, 2)
    local low = new_channel(low_lamp, 1, 32, 1)
    Led:setChannel(high)
    Led:setChannel(low)

    game.tick = 1
    Led:tick()
    eq(#sent_packets, 1)
    local frame = sent_packets[1]
    eq(frame.port, 34198)
    eq(frame.payload.version, 2)
    eq(frame.payload.save_id, '12345678-90abcdef')
    eq(frame.payload.sequence, 1)
    eq(frame.payload.tick, 1)
    eq(frame.payload.type, 'snapshot')
    eq(#frame.payload.channels, 2)
    eq(frame.payload.channels[1].id, 0, 'snapshot channels were not sorted')
    eq(frame.payload.channels[2].id, 63, 'channel 64 did not map to wire id 63')

    game.tick = 2
    Led:tick()
    eq(#sent_packets, 1, 'unchanged state produced an update')

    low_lamp.control.color = { r = 0, g = 0, b = 1 }
    game.tick = 3
    Led:tick()
    eq(#sent_packets, 2)
    frame = sent_packets[2].payload
    eq(frame.type, 'update')
    eq(frame.sequence, 2)
    eq(#frame.channels, 1)
    eq(frame.channels[1].id, 0)
    eq(frame.channels[1].b, 255)

    Led:reset()
    eq(#sent_packets, 3)
    frame = sent_packets[3].payload
    eq(frame.type, 'reset')
    eq(frame.sequence, 2, 'reset changed storage during the load-safe path')
    eq(#frame.channels, 2)

    Led:clearChannel(low)
    game.tick = 4
    Led:tick()
    eq(#sent_packets, 4)
    frame = sent_packets[4].payload
    eq(frame.type, 'update')
    eq(frame.sequence, 3)
    eq(#frame.channels, 1)
    eq(frame.channels[1].id, 0)
    eq(frame.channels[1].r, 0); eq(frame.channels[1].g, 0); eq(frame.channels[1].b, 0)
    eq(frame.channels[1].brightness, 0)
    eq(frame.channels[1].effect, 'solid')

    game.tick = 300
    Led:tick()
    eq(sent_packets[5].payload.type, 'snapshot')
    eq(sent_packets[5].payload.sequence, 4)
end

local function install_gui_module_mocks()
    _G.script = {}
    package.loaded['stdlib.event.event'] = nil
    package.preload['stdlib.event.event'] = function()
        return {
            on_init = function() end,
            on_load = function() end,
            on_event = function() end,
        }
    end
    package.loaded['stdlib.event.player'] = nil
    package.preload['stdlib.event.player'] = function()
        return {
            get = function() return nil end,
            pdata = function() return {} end,
        }
    end
end

local function test_edit_gui_callbacks()
    reset_led_storage()
    install_gui_module_mocks()
    package.loaded['scripts.edit_gui'] = nil
    local EditGui = require('scripts.edit_gui')

    local channel = new_channel(support.lamp(401))
    local gui = { context = { channel = channel } }
    EditGui.onConfirmChannel({ element = { text = '64' } }, gui)
    eq(channel.channel, 64)
    eq(Led:getChannel(64), channel)

    EditGui.onBrightnessSlider({ element = { slider_value = 300 } }, gui)
    eq(channel.brightness, 255)
    EditGui.onBrightnessSlider({ element = { slider_value = -10 } }, gui)
    eq(channel.brightness, 0)
    EditGui.onConfirmBrightness({ element = { text = '127' } }, gui)
    eq(channel.brightness, 127)
    EditGui.onConfirmBrightness({ element = { text = '' } }, gui)
    eq(channel.brightness, 64)

    EditGui.onEffectChanged({ element = { selected_index = 2 } }, gui)
    eq(channel.effect, 2)
end

local function test_assignment_list_callbacks()
    reset_led_storage()
    install_gui_module_mocks()
    package.loaded['scripts.gui'] = nil
    local Gui = require('scripts.gui')

    local channel = new_channel(support.lamp(501), 4, 64, 1)
    Led:setChannel(channel)
    local gui = { context = { refresh = false } }

    Gui.onBrightnessSlider({ element = { tags = { channel = 4 }, slider_value = 255 } }, gui)
    eq(channel.brightness, 255)
    truthy(gui.context.refresh)

    gui.context.refresh = false
    Gui.onEffectChanged({ element = { tags = { channel = 4 }, selected_index = 3 } }, gui)
    eq(channel.effect, 3)
    truthy(gui.context.refresh)

    gui.context.refresh = false
    Gui.onDeleteChannel({ element = { tags = { channel = 4 } } }, gui)
    eq(Led:getChannel(4), nil)
    truthy(gui.context.refresh)
end

test_channel_management_and_markers()
test_lamp_state_conversion()
test_udp_snapshots_updates_and_reset()
test_edit_gui_callbacks()
test_assignment_list_callbacks()

print('factorio mod unit tests passed')
