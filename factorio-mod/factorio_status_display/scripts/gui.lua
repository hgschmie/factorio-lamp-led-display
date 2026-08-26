------------------------------------------------------------------------
-- GUI
------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')
local table = require('stdlib.utils.table')

local const = require('lib.constants')

---@class led.PlayerStorage
---@field toggle boolean?


---@class led.Gui
---@field NAME string
---@field TABLE_COLUMNS framework.gui.element_definitions
local Gui = {
    NAME = const.name .. '-gui',
}

---@return framework.gui.element_definitions ui
local function get_table_columns()
    -- Entity position, channel, brightness, effect, button
    return {
        {
            type = 'empty-widget',
        },
        {
            type = 'label',
            style = 'bold_label',
            style_mods = {
                horizontal_align = 'center',
            },
            caption = { const:locale('channel-header') },
        },
        {
            type = 'label',
            style = 'bold_label',
            style_mods = {
                horizontal_align = 'center',
            },
            caption = { '', { const:locale('brightness-label') }, ' [img=info]' },
            tooltip = { const:locale('brightness-tooltip') },
        },
        {
            type = 'label',
            style = 'bold_label',
            style_mods = {
                horizontal_align = 'center',
            },
            caption = { '', { const:locale('effect-label') }, ' [img=info]' },
            tooltip = { const:locale('effect-tooltip') },
        },
        {
            type = 'empty-widget',
        },
    }
end

----------------------------------------------------------------------------------------------------
-- UI definition
----------------------------------------------------------------------------------------------------

--- Provides all the events used by the GUI and their mappings to functions. This must be outside the
--- GUI definition as it can not be serialized into storage.
---@return framework.gui_manager.event_definition
local function get_gui_event_definition()
    return {
        events = {
            onWindowClosed = Gui.onWindowClosed,
            onMapClicked = Gui.onMapClicked,
            onBrightnessSlider = Gui.onBrightnessSlider,
            onConfirmBrightness = Gui.onConfirmBrightness,
            onEffectChanged = Gui.onEffectChanged,
            onDeleteChannel = Gui.onDeleteChannel,
        },
        callback = Gui.guiUpdater,
    }
end

--- Returns the definition of the GUI. All events must be mapped onto constants from the gui_events array.
---@param gui framework.gui
---@return framework.gui.element_definitions ui
function Gui.getUi(gui)
    ---@type LuaPlayer
    local player = Player.get(gui.player_index)
    assert(player)

    local gui_events = gui.gui_events
    local max_height = ((player.display_resolution.height / player.display_scale) - 80) / 2

    return {
        type = 'frame',
        name = 'gui_root',
        direction = 'vertical',
        handler = { [defines.events.on_gui_closed] = gui_events.onWindowClosed },
        elem_mods = { auto_center = true },
        children = {
            { -- Title Bar
                type = 'flow',
                style = 'frame_header_flow',
                drag_target = 'gui_root',
                children = {
                    {
                        type = 'label',
                        style = 'frame_title',
                        caption = { const:locale('gui-title') },
                        drag_target = 'gui_root',
                        ignored_by_interaction = true,
                    },
                    {
                        type = 'empty-widget',
                        style = 'framework_titlebar_drag_handle',
                        ignored_by_interaction = true,
                    },
                    {
                        type = 'sprite-button',
                        style = 'frame_action_button',
                        sprite = 'utility/close',
                        hovered_sprite = 'utility/close_black',
                        clicked_sprite = 'utility/close_black',
                        mouse_button_filter = { 'left' },
                        handler = { [defines.events.on_gui_click] = gui_events.onWindowClosed },
                    },
                },
            }, -- Title Bar End
            {  -- Body
                type = 'frame',
                style = 'entity_frame',
                style_mods = {
                    natural_width = 400,
                    maximal_height = max_height,
                },
                children = {
                    {
                        type = 'flow',
                        style = 'two_module_spacing_vertical_flow',
                        direction = 'vertical',
                        children = {
                            type = 'frame',
                            style = 'entity_frame',
                            direction = 'vertical',
                            children = {

                                {
                                    type = 'scroll-pane',
                                    direction = 'vertical',
                                    visible = true,
                                    vertical_scroll_policy = 'auto',
                                    horizontal_scroll_policy = 'never',
                                    style_mods = {
                                        horizontally_stretchable = true,
                                        horizontally_squashable = true,
                                        vertically_stretchable = false,
                                    },
                                    children = {
                                        {
                                            type = 'table',
                                            style = 'led-table',
                                            name = 'led_table',
                                            column_count = #Gui.TABLE_COLUMNS,
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

----------------------------------------------------------------------------------------------------
-- UI Callbacks
----------------------------------------------------------------------------------------------------

--- close the UI (button or shortcut key)
---
---@param event EventData.on_gui_click|EventData.on_gui_closed
function Gui.onWindowClosed(event)
    local player = assert(Player.get(event.player_index))
    Gui.closeGui(player)
end

---@param event EventData.on_gui_click
function Gui.onMapClicked(event)
    local channel_id = tonumber(event.element.tags.channel)
    if not channel_id then return end

    local channel = This.Led:getChannel(channel_id)
    if not channel then return end

    local player = Player.get(event.player_index)
    if not player then return end

    -- open the map on the coordinates
    player.set_controller {
        type = defines.controllers.remote,
        position = channel.lamp.position,
        surface = channel.lamp.surface,
    }
    player.zoom = 3

    Gui.closeGui(player)
end

function Gui.onBrightnessSlider(event, gui)
    local context = assert(gui.context) --[[@as led.GuiContext ]]

    local channel_id = tonumber(event.element.tags.channel)
    if not channel_id then return end

    local channel = This.Led:getChannel(channel_id)
    if not channel then return end

    local value = event.element.slider_value
    value = math.min(255, math.max(value, 0))

    channel.brightness = value

    context.refresh = true
end

function Gui.onConfirmBrightness(event, gui)
    local context = assert(gui.context) --[[@as led.GuiContext ]]

    local channel_id = tonumber(event.element.tags.channel)
    if not channel_id then return end

    local channel = This.Led:getChannel(channel_id)
    if not channel then return end

    local value = tonumber(event.element.text) or This.Led.DEFAULT_BRIGHTNESS
    value = math.min(255, math.max(value, 0))

    channel.brightness = value

    context.refresh = true
end

function Gui.onEffectChanged(event, gui)
    local context = assert(gui.context) --[[@as led.GuiContext ]]

    local channel_id = tonumber(event.element.tags.channel)
    if not channel_id then return end

    local channel = This.Led:getChannel(channel_id)
    if not channel then return end

    channel.effect = event.element.selected_index --[[@as led.Effect]]

    context.refresh = true
end

---@param event EventData.on_gui_click
function Gui.onDeleteChannel(event, gui)
    local context = assert(gui.context) --[[@as led.GuiContext ]]

    local channel_id = tonumber(event.element.tags.channel)
    if not channel_id then return end

    local channel = This.Led:getChannel(channel_id)
    if not channel then return end

    This.Led:clearChannel(channel)

    context.refresh = true
end

----------------------------------------------------------------------------------------------------
-- Gui State Updater
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
local function update_gui(gui)
    local gui_events = gui.gui_events

    ---@type LuaGuiElement
    local led_table = assert(gui:findElement('led_table'))

    led_table.clear()

    gui:addChildElements(led_table, Gui.TABLE_COLUMNS)

    local led_data = This:storage()

    -- sorted list of keys
    local keys = table.keys(led_data.channel_usage, true)

    for _, key in pairs(keys) do
        local channel = led_data.channel_usage[key]

        local table_row = {
            {
                type = 'camera',
                position = channel.lamp.position,
                surface_index = channel.lamp.surface_index,
                zoom = 0.75,
                style_mods = {
                    width = 128,
                    height = 128,
                    padding = 4,
                },
                tags = {
                    channel = channel.channel,
                },
                handler = { [defines.events.on_gui_click] = gui_events.onMapClicked },
            },
            {
                type = 'label',
                style = 'label',
                caption = tostring(channel.channel),
                style_mods = {
                    horizontal_align = 'center',
                },
            },
            {
                type = 'flow',
                direction = 'horizontal',
                style_mods = {
                    vertical_align = 'center',
                },
                children = {
                    {
                        type = 'slider',
                        style = 'slider',
                        style_mods = {
                            maximal_width = 100, -- limit slider width to match look of the UI
                        },
                        minimum_value = 0,
                        maximum_value = 255,
                        value = channel.brightness,
                        tags = {
                            channel = channel.channel,
                        },

                        handler = { [defines.events.on_gui_value_changed] = gui_events.onBrightnessSlider },
                    },
                    {
                        type = 'textfield',
                        style = 'slider_value_textfield',
                        style_mods = {
                            maximal_width = 40, -- match the very_short_number_textfield
                        },
                        text = tostring(channel.brightness),
                        numeric = true,
                        allow_negative = false,
                        lose_focus_on_confirm = true,
                        clear_and_focus_on_right_click = false,
                        tags = {
                            channel = channel.channel,
                        },
                        handler = { [defines.events.on_gui_confirmed] = gui_events.onConfirmBrightness },
                    },
                },
            },
            {
                type = 'flow',
                direction = 'horizontal',
                style_mods = {
                    vertical_align = 'center',
                },
                children = {
                    {
                        type = 'drop-down',
                        tags = {
                            channel = channel.channel,
                        },
                        selected_index = channel.effect,
                        handler = { [defines.events.on_gui_selection_state_changed] = gui_events.onEffectChanged },
                        items = {
                            [const.effect.solid] = { const:locale('effect-dropdown-solid') },
                            [const.effect.blink] = { const:locale('effect-dropdown-blink') },
                            [const.effect.pulse] = { const:locale('effect-dropdown-pulse') },
                        },
                    },
                },
            },
            {
                type = 'sprite-button',
                style = 'tool_button_red',
                style_mods = {
                    top_margin = 1,
                },
                sprite = 'utility/trash',
                tooltip = { const:locale('button_clear') },
                mouse_button_filter = { 'left' },
                handler = { [defines.events.on_gui_click] = gui_events.onDeleteChannel },
                tags = {
                    channel = channel.channel,
                },
            },
        }

        gui:addChildElements(led_table, table_row)
    end
end

----------------------------------------------------------------------------------------------------
-- open gui handler
----------------------------------------------------------------------------------------------------

--- @param player LuaPlayer
function Gui.openGui(player)
    ---@type led.PlayerStorage
    local player_data = assert(Player.pdata(player.index))

    local lamp_data = This:storage()

    ---@class led.GuiContext
    ---@field refresh boolean
    ---@field last_change uint64?
    local gui_state = {
        refresh = false,
        last_change = lamp_data.last_change,
    }

    local gui = Framework.gui_manager:createGui {
        type = Gui.NAME,
        player_index = player.index,
        parent = player.gui.screen,
        ui_tree_provider = Gui.getUi,
        context = gui_state,
        retain_open_guis = true,
    }

    update_gui(gui)

    player_data.toggle = true
    player.set_shortcut_toggled(const.hotkey_names.toggle_display, player_data.toggle)
end

function Gui.closeGui(player)
    ---@type led.PlayerStorage
    local player_data = assert(Player.pdata(player.index))
    Framework.gui_manager:destroyGui(player.index, Gui.NAME)

    player_data.toggle = false
    player.set_shortcut_toggled(const.hotkey_names.toggle_display, player_data.toggle)
end

----------------------------------------------------------------------------------------------------
-- Event ticker
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@return boolean
function Gui.guiUpdater(gui)
    local context = assert(gui.context) --[[@as led.GuiContext]]

    local lamp_data = This:storage()

    -- lamp_data.last_change represets edits to the global state
    if context.refresh or (lamp_data.last_change and lamp_data.last_change ~= context.last_change) then
        update_gui(gui)

        context.refresh = false
        context.last_change = lamp_data.last_change
    end

    return true
end

----------------------------------------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------------------------------------

---@param player LuaPlayer
function Gui.toggleGui(player)
    ---@type led.PlayerStorage
    local player_data = assert(Player.pdata(player.index))
    player_data.toggle = player_data.toggle or false

    if player_data.toggle then
        Gui.closeGui(player)
    else
        Gui.openGui(player)
    end
end

---@param event EventData.CustomInputEvent
local function toggle_hotkey(event)
    local player = assert(Player.get(event.player_index))
    Gui.toggleGui(player)
end

---@param event EventData.on_lua_shortcut
local function toggle_shortcut(event)
    if event.prototype_name ~= const.hotkey_names.toggle_display then return end
    local player = assert(Player.get(event.player_index))
    Gui.toggleGui(player)
end

local function init_gui()
    Gui.TABLE_COLUMNS = get_table_columns()

    Framework.gui_manager:registerGuiType(Gui.NAME, get_gui_event_definition())
    Event.on_event(const.hotkey_names.toggle_display, toggle_hotkey)
    Event.on_event(defines.events.on_lua_shortcut, toggle_shortcut)
end

Event.on_init(init_gui)
Event.on_load(init_gui)

return Gui
