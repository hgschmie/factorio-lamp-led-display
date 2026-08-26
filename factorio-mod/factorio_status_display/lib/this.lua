----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

local const = require('lib.constants')

---@class led.Mod
---@field settings ff2.ModSettings
---@field Led led.Led
---@field Gui led.Gui
---@field EditGui led.EditGui
local This = {
    settings = require('lib.settings'),
}

function This.boot()
    This.Led = require('scripts.led')
    This.Gui = require('scripts.gui')
    This.EditGui = require('scripts.edit_gui')
end

--------------------------------------------------------------------------------
-- Framework intializer
--------------------------------------------------------------------------------

---@return FrameworkConfig config
function This.framework_init()
    return {
        -- prefix is the internal mod prefix
        prefix = const.prefix,
        -- prefix for log messages
        log_prefix = const.log_prefix,
        -- name is a human readable name
        name = const.name,
        -- The filesystem root.
        root = const.root,
    }
end

---@class led.Storage
---@field channel_assignments led.Channel[] -- key is the entity unit_number
---@field channel_usage led.Channel[]       -- key is the channel number
---@field last_change uint64?               -- last change for channel assignments, used for GUI
---@field state led.State[]                 -- Current lamp state as polled
---@field previous led.State[]?             -- Previous sent state
---@field game_id string                    -- Game id
---@field msg_sequence uint64               -- Message sequence

function This:init()
    storage.led_data = storage.led_data or {}

    local led_data = self:storage()
    led_data.channel_usage = led_data.channel_usage or {}
    led_data.channel_assignments = led_data.channel_assignments or {}
    led_data.state = led_data.state or {}
    led_data.game_id = led_data.game_id or string.format('%08x-%08x', math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
    led_data.msg_sequence = led_data.msg_sequence or 0
end

------------------------------------------------------------------------
-- Storage Management
------------------------------------------------------------------------

---@return led.Storage
function This:storage()
    return assert(storage.led_data)
end

return This
