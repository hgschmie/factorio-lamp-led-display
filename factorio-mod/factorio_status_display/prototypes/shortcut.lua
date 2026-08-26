------------------------------------------------------------------------
-- shortcuts
------------------------------------------------------------------------

local const = require('lib.constants')

data:extend {
  ---@type ShortcutPrototype
  {
    -- PrototypeBase
    type = 'shortcut',
    name = const.hotkey_names.select_led,
    order = 'zb[' .. const.led_name .. ']',

    -- ShortcutPrototype
    action = 'spawn-item',
    icon = const:png('icon/led'),
    icon_size = 64,
    small_icon = const:png('icon/led'),
    small_icon_size = 64,
    item_to_spawn = const.led_name,
    technology_to_unlock = 'lamp',
    associated_control_input = const.hotkey_names.select_led,
  },
  ---@type ShortcutPrototype
  {
    -- PrototypeBase
    type = 'shortcut',
    name = const.hotkey_names.toggle_display,
    order = 'za[' .. const.led_name .. ']',

    -- ShortcutPrototype
    action = 'lua',
    toggleable = true,
    icon = const:png('icon/led-list'),
    icon_size = 64,
    small_icon = const:png('icon/led-list'),
    small_icon_size = 64,
    technology_to_unlock = 'lamp',
    associated_control_input = const.hotkey_names.toggle_display,
  },
}
