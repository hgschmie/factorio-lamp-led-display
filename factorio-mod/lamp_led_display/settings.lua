--------------------------------------------------------------------------------
-- settings
--------------------------------------------------------------------------------
This, Framework = require('lib.init')()

local const = require('lib.constants')

local framework_settings = {
    {
        -- Debug mode (framework dependency)
        type = 'string-setting',
        name = Framework.PREFIX .. 'debug-mode',
        order = 'az',
        setting_type = 'startup',
        default_value = '0',
        allowed_values = { '0', '1', '2', '3' },
        -- Debugging is currently not in use
        hidden = true,
    },
    {
        type = 'int-setting',
        name = const.settings.default_brightness,
        setting_type = 'startup',
        default_value = 64,
        minimum_value = 16,
        maximum_value = 255,
        order = 'aa',
    },
    {
        type = 'int-setting',
        name = const.settings.udp_port,
        setting_type = 'startup',
        default_value = 34198,
        minimum_value = 1024,
        maximum_value = 65534,
        order = 'aa',
    },
}

data:extend(framework_settings)

---@diagnostic disable-next-line: undefined-field
Framework.post_settings_stage()
