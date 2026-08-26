------------------------------------------------------------------------
-- runtime code
------------------------------------------------------------------------

This, Framework = require('lib.init')()

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')

local Matchers = require('framework.matchers')

local const = require('lib.constants')

---@param event EventData.on_player_selected_area|EventData.on_player_alt_selected_area
local function on_selected(event)
  local player = Player.get(event.player_index)
  if not player then return end

  local entity = event.entities and event.entities[1]
  if not (entity and entity.valid) then return end

  if #event.entities ~= 1 then
    player.create_local_flying_text {
      text = { const:locale('select-one') },
      position = player.position,
      create_at_cursor = true,
      color = { 1, 0, 0 },
    };

    return
  end

  This.Led:selectLamp(player, entity)
end

local function on_configuration_changed()
  This:init()

  This.Led:cleanupLamps()
end

local function on_tick()
  This.Led:tick()
end

local function register_events()
  ---@diagnostic disable-next-line: undefined-field
  local tool_matcher = Matchers:createEventMatcherFunction(const.led_name, function(event) return event.item end)

  Event.on_configuration_changed(on_configuration_changed)
  Event.register({ defines.events.on_player_selected_area, defines.events.on_player_alt_selected_area }, on_selected, tool_matcher)

  -- ticker code
  Event.on_nth_tick(1, on_tick)
end

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------

local function on_init()
  This:init()

  This.Led:reset()

  register_events()
end

local function on_load()
  register_events()

  This.Led:reset()
end

-- setup player management
Player.register_events(true)

Event.on_init(on_init)
Event.on_load(on_load)

------------------------------------------------------------------------

---@diagnostic disable-next-line: undefined-field
Framework.post_runtime_stage()
