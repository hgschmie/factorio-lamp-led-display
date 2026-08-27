------------------------------------------------------------------------
-- mod constant definitions.
--
-- can be loaded into scripts and data
------------------------------------------------------------------------

local table = require('stdlib.utils.table')

------------------------------------------------------------------------
-- globals
------------------------------------------------------------------------

---@class dico.Constants
local Constants = {
    prefix = 'hps__led-',
    log_prefix = 'LED',
    name = 'lamp_led_display',
    root = '__lamp_led_display__',
    order = 'z[lamp_led_display]',
}

Constants.gfx_location = Constants.root .. '/graphics/'

--------------------------------------------------------------------------------
-- Path and name helpers
--------------------------------------------------------------------------------

---@param value string
---@return string result
function Constants:with_prefix(value)
    return self.prefix .. value
end

---@param path string
---@return string result
function Constants:png(path)
    return self.gfx_location .. path .. '.png'
end

---@param id string
---@return string result
function Constants:locale(id)
    return Constants:with_prefix('gui.') .. id
end

--------------------------------------------------------------------------------
-- settings
--------------------------------------------------------------------------------

Constants.settings_keys = {
    'default_brightness',
    'udp_port',
}

Constants.settings_names = {}
Constants.settings = {}

for _, key in pairs(Constants.settings_keys) do
    Constants.settings_names[key] = key
    Constants.settings[key] = Constants:with_prefix(key)
end

------------------------------------------------------------------------
-- constants and names
------------------------------------------------------------------------
-- Base name
Constants.led_name = Constants:with_prefix(Constants.name)

Constants.hotkey_keys = {
    'toggle_display',
    'select_led',
}
Constants.hotkey_names = {}
Constants.hotkey = {}

for _, key in pairs(Constants.hotkey_keys) do
    Constants.hotkey[key] = key
    Constants.hotkey_names[key] = Constants:with_prefix(key)
end

---@enum led.Effect
Constants.effect = {
    solid = 1,
    blink = 2,
    pulse = 3,
}

Constants.effect_names = {}
for k, v in pairs(Constants.effect) do
    Constants.effect_names[v] = k
end

------------------------------------------------------------------------
return Constants
