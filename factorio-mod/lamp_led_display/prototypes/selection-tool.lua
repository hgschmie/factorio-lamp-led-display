------------------------------------------------------------------------
-- selection tools
------------------------------------------------------------------------

local const = require('lib.constants')

data:extend {
  ---@type SelectionToolPrototype
  {
    -- PrototypeBase
    type = 'selection-tool',
    name = const.led_name,
    order = const.order,
    subgroup = 'tool',
    hidden = true,

    -- SelectionToolPrototype
    select = {
      border_color = { 0, 1, 0 },
      cursor_box_type = 'entity',
      mode = { 'any-entity', 'friend' },
      entity_type_filters = { 'lamp' },
    },
    alt_select = {
      border_color = { 0, 1, 0 },
      cursor_box_type = 'entity',
      mode = { 'any-entity', 'friend' },
      entity_type_filters = { 'lamp' },
    },

    --ItemPrototype
    stack_size = 1,
    icon = '__base__/graphics/icons/small-lamp.png',
    icon_size = 64,
    flags = { 'only-in-cursor', 'spawnable', 'not-stackable' },
  },
}
