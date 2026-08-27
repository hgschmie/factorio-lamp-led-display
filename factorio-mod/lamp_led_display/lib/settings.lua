------------------------------------------------------------------------
-- global startup settings
------------------------------------------------------------------------

local const = require('lib.constants')

---@type ff2.ModSettings
local Settings = {
   startup = {
        [const.settings_names.default_brightness] = {
            key = const.settings.default_brightness,
            value = 64,
        },
        [const.settings_names.udp_port] = {
            key = const.settings.udp_port,
            value = 34198,
        },
   },
}

return Settings
