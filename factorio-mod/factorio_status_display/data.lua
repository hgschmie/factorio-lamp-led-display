data:extend({
  {
    type = "selection-tool",
    name = "factorio-status-display-selector",
    icon = "__base__/graphics/icons/programmable-speaker.png",
    icon_size = 64,
    flags = {"only-in-cursor", "spawnable"},
    subgroup = "tool",
    order = "z[factorio-status-display]",
    stack_size = 1,
    select = {
      border_color = {0, 1, 0},
      cursor_box_type = "entity",
      mode = {"any-entity"},
      entity_type_filters = {"assembling-machine", "furnace", "rocket-silo"}
    },
    alt_select = {
      border_color = {1, 0.5, 0},
      cursor_box_type = "entity",
      mode = {"any-entity"},
      entity_type_filters = {"assembling-machine", "furnace", "rocket-silo"}
    }
  },
  {
    type = "shortcut",
    name = "factorio-status-display-assign",
    action = "spawn-item",
    item_to_spawn = "factorio-status-display-selector",
    icon = "__base__/graphics/icons/programmable-speaker.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/programmable-speaker.png",
    small_icon_size = 64,
    associated_control_input = "factorio-status-display-toggle-list"
  },
  {
    type = "custom-input",
    name = "factorio-status-display-toggle-list",
    key_sequence = "CONTROL + SHIFT + D",
    consuming = "none"
  }
})
