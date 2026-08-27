------------------------------------------------------------------------
-- custom-input
------------------------------------------------------------------------

local const = require('lib.constants')

data:extend {
    ---@type CustomInputPrototype
    {
        type = 'custom-input',
        name = const.hotkey_names.toggle_display,
        key_sequence = 'CONTROL + SHIFT + D',
    },
    ---@type CustomInputPrototype
    {
        type = 'custom-input',
        name = const.hotkey_names.select_led,
        key_sequence = 'ALT + SHIFT + D',
        consuming = 'game-only',
        item_to_spawn = const.led_name,
        action = 'spawn-item',
    },
}
