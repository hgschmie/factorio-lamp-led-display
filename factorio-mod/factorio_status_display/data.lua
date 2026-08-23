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
      entity_type_filters = {"assembling-machine", "furnace", "rocket-silo", "lamp"}
    },
    alt_select = {
      border_color = {1, 0.5, 0},
      cursor_box_type = "entity",
      mode = {"any-entity"},
      entity_type_filters = {"assembling-machine", "furnace", "rocket-silo", "lamp"}
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

-- Clone the base lamp so the game supplies the complete native lamp GUI,
-- circuit conditions, color mapping, separate RGB signals, and packed RGB mode.
local entity_name = "factorio-status-display-lamp"
local lamp = table.deepcopy(data.raw.lamp["small-lamp"])
lamp.name = entity_name
lamp.minable = lamp.minable or {}
lamp.minable.result = entity_name
lamp.next_upgrade = nil

local item = table.deepcopy(data.raw.item["small-lamp"])
item.name = entity_name
item.place_result = entity_name
item.order = (item.order or "") .. "[physical-display]"

local recipe = table.deepcopy(data.raw.recipe["small-lamp"])
recipe.name = entity_name
recipe.results = {{type = "item", name = entity_name, amount = 1}}

data:extend({lamp, item, recipe})

-- Unlock alongside the base lamp, without depending on a particular technology name.
if recipe.enabled == false then
  for _, technology in pairs(data.raw.technology) do
    for _, effect in pairs(technology.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe == "small-lamp" then
        table.insert(technology.effects, {type = "unlock-recipe", recipe = entity_name})
        break
      end
    end
  end
end
