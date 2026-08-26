------------------------------------------------------------------------
-- GUI
------------------------------------------------------------------------
assert(script)

local util = require('util')

local Event = require('stdlib.event.event')

local const = require('lib.constants')

---@class led.EditGui
---@field NAME string
local Gui = {
    NAME = const.name .. '-edit-gui',
}

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
            onConfirmChannel = Gui.onConfirmChannel,
            onBrightnessSlider = Gui.onBrightnessSlider,
            onConfirmBrightness = Gui.onConfirmBrightness,
            onEffectChanged = Gui.onEffectChanged,
        },
        callback = Gui.guiUpdater,
    }
end

--- Returns the definition of the GUI. All events must be mapped onto constants from the gui_events array.
---@param gui framework.gui
---@return framework.gui.element_definitions ui
function Gui.getUi(gui)
    local gui_events = gui.gui_events

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
                        caption = { const:locale('edit-gui-title') },
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
                        tooltip = { 'gui.close-instruction' },
                        handler = { [defines.events.on_gui_click] = gui_events.onWindowClosed },
                    },
                },
            }, -- Title Bar End
            {  -- Body
                type = 'frame',
                style = 'entity_frame',
                style_mods = {
                    natural_width = 400,
                    maximal_height = 200,
                },
                children = {
                    {
                        type = 'flow',
                        style = 'two_module_spacing_vertical_flow',
                        direction = 'vertical',
                        children = {
                            {
                                type = 'flow',
                                direction = 'horizontal',
                                style_mods = {
                                    vertical_align = 'center',
                                },
                                children = {
                                    {
                                        type = 'label',
                                        style = 'label',
                                        caption = { '', { const:locale('channel-label') }, ' [img=info]' },
                                        tooltip = { const:locale('channel-tooltip'), This.Led.MAX_CHANNELS },
                                    },
                                    {
                                        type = 'textfield',
                                        name = 'channel',
                                        style_mods = {
                                            maximal_width = 40,
                                        },
                                        numeric = true,
                                        allow_negative = false,
                                        lose_focus_on_confirm = true,
                                        clear_and_focus_on_right_click = true,
                                        handler = { [defines.events.on_gui_confirmed] = gui_events.onConfirmChannel },
                                    },
                                    {
                                        type = 'empty-widget',
                                        style_mods = { horizontally_stretchable = true },
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
                                        type = 'label',
                                        style = 'label',
                                        caption = { '', { const:locale('brightness-label') }, ' [img=info]' },
                                        tooltip = { const:locale('brightness-tooltip') },
                                    },
                                    {
                                        type = 'slider',
                                        name = 'brightness_slider',
                                        style = 'slider',
                                        style_mods = {
                                            maximal_width = 100, -- limit slider width to match look of the UI
                                        },
                                        minimum_value = 0,
                                        maximum_value = 255,

                                        handler = { [defines.events.on_gui_value_changed] = gui_events.onBrightnessSlider },
                                    },
                                    {
                                        type = 'textfield',
                                        name = 'brightness',
                                        style = 'slider_value_textfield',
                                        style_mods = {
                                            maximal_width = 40, -- match the very_short_number_textfield
                                        },
                                        numeric = true,
                                        allow_negative = false,
                                        lose_focus_on_confirm = true,
                                        clear_and_focus_on_right_click = false,
                                        handler = { [defines.events.on_gui_confirmed] = gui_events.onConfirmBrightness },
                                    },
                                    {
                                        type = 'empty-widget',
                                        style_mods = { horizontally_stretchable = true },
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
                                        type = 'label',
                                        style = 'label',
                                        caption = { '', { const:locale('effect-label') }, ' [img=info]' },
                                        tooltip = { const:locale('effect-tooltip') },
                                    },
                                    {
                                        type = 'drop-down',
                                        name = 'effect',
                                        handler = { [defines.events.on_gui_selection_state_changed] = gui_events.onEffectChanged },
                                        items = {
                                            [const.effect.solid] = { const:locale('effect-dropdown-solid') },
                                            [const.effect.blink] = { const:locale('effect-dropdown-blink') },
                                            [const.effect.pulse] = { const:locale('effect-dropdown-pulse') },
                                        },
                                    },
                                    {
                                        type = 'empty-widget',
                                        style_mods = { horizontally_stretchable = true },
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
---@param event EventData.on_gui_click|EventData.on_gui_closed
---@param gui framework.gui
function Gui.onWindowClosed(event, gui)
    local context = assert(gui.context) --[[@as led.EditGuiContext ]]
    if context.channel.channel == 0 then This.Led:clearChannel(context.channel) end

    Framework.gui_manager:destroyGui(event.player_index, Gui.NAME)
end

---@param event EventData.on_gui_confirmed
---@param gui framework.gui
function Gui.onConfirmChannel(event, gui)
    local context = assert(gui.context) --[[@as led.EditGuiContext ]]

    local element = event.element
    local channel_id = tonumber(element.text)

    if channel_id < 1 then return end

    This.Led:assignLamp(context.channel, channel_id)
end

---@param event EventData.on_gui_value_changed
---@param gui framework.gui
function Gui.onBrightnessSlider(event, gui)
    local context = assert(gui.context) --[[@as led.EditGuiContext ]]

    local value = event.element.slider_value
    value = math.min(255, math.max(value, 0))
    context.channel.brightness = value
end

---@param event EventData.on_gui_confirmed
---@param gui framework.gui
function Gui.onConfirmBrightness(event, gui)
    local context = assert(gui.context) --[[@as led.EditGuiContext ]]

    local value = tonumber(event.element.text) or This.Led.DEFAULT_BRIGHTNESS
    value = math.min(255, math.max(value, 0))
    context.channel.brightness = value
end

---@param event EventData.on_gui_selection_state_changed
---@param gui framework.gui
function Gui.onEffectChanged(event, gui)
    local context = assert(gui.context) --[[@as led.EditGuiContext ]]

    context.channel.effect = event.element.selected_index --[[@as led.Effect]]
end

----------------------------------------------------------------------------------------------------
-- Gui State Updater
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@param channel led.Channel
local function update_gui(gui, channel)
    local channel_elem = assert(gui:findElement('channel'))
    channel_elem.text = channel.channel > 0 and tostring(channel.channel) or ''

    local slider_elem = assert(gui:findElement('brightness_slider'))
    local brightness_elem = assert(gui:findElement('brightness'))

    local brightness = channel.brightness or This.Led.DEFAULT_BRIGHTNESS
    slider_elem.slider_value = brightness
    brightness_elem.text = tostring(brightness)

    local effect_elem = assert(gui:findElement('effect'))
    effect_elem.selected_index = channel.effect
end

----------------------------------------------------------------------------------------------------
-- open gui handler
----------------------------------------------------------------------------------------------------

---@param player LuaPlayer
---@param channel led.Channel
function Gui.openGui(player, channel)
    ---@class led.EditGuiContext
    ---@field channel led.Channel
    ---@field last_channel led.Channel?
    local gui_state = {
        channel = channel,
        last_channel = nil,
    }

    local gui = Framework.gui_manager:createGui {
        type = Gui.NAME,
        player_index = player.index,
        parent = player.gui.screen,
        ui_tree_provider = Gui.getUi,
        context = gui_state,
        retain_open_guis = true,
    }

    update_gui(gui, channel)

    local channel_elem = assert(gui:findElement('channel'))
    channel_elem.focus()

    player.opened = gui.root
end

----------------------------------------------------------------------------------------------------
-- Event ticker
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@return boolean
function Gui.guiUpdater(gui)
    local context = assert(gui.context) --[[@as led.EditGuiContext]]

    local refresh_config = not (context.last_channel)
        or context.last_channel.channel ~= context.channel.channel
        or context.last_channel.brightness ~= context.channel.brightness
        or context.last_channel.effect ~= context.channel.effect

    if refresh_config then
        update_gui(gui, context.channel)
        context.last_channel = util.copy(context.channel)
    end

    return true
end

----------------------------------------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------------------------------------

local function init_gui()
    Framework.gui_manager:registerGuiType(Gui.NAME, get_gui_event_definition())
end

Event.on_init(init_gui)
Event.on_load(init_gui)

return Gui
