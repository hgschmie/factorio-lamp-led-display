local lib = require("lib")
local TOOL = "factorio-status-display-selector"
local FRAME = "factorio_status_display_frame"
local PROMPT = "factorio_status_display_prompt"
local PORT = 34198
local effects = {"solid", "blink", "pulse"}
local effect_items = {{"factorio-status-display.effect-solid"}, {"factorio-status-display.effect-blink"}, {"factorio-status-display.effect-pulse"}}

local supported = { ["assembling-machine"] = true, furnace = true, ["rocket-silo"] = true, lamp = true }
local CHANNEL_MODEL_VERSION = 2

local function root()
  storage.factorio_status_display = storage.factorio_status_display or {}
  local state = storage.factorio_status_display
  state.assignments = state.assignments or {}
  state.players = state.players or {}
  state.previous = state.previous or {}
  state.sequence = state.sequence or 0
  if state.channel_model_version ~= CHANNEL_MODEL_VERSION then
    local migrated = {}
    for key, assignment in pairs(state.assignments) do
      local channel = tonumber(key)
      if channel and channel == math.floor(channel) and channel >= 0 and channel <= 63 and not migrated[channel] then
        migrated[channel] = assignment
      else
        local mark = assignment and assignment.mark
        if mark and mark.valid then mark.destroy() end
      end
    end
    state.assignments = migrated
    state.previous = {}
    state.channel_model_version = CHANNEL_MODEL_VERSION
  end
  if not state.save_id then
    state.save_id = string.format("%08x-%08x", game.tick, math.random(0, 0x7fffffff))
  end
  return state
end

local function status_names()
  local names = {}
  for name, value in pairs(defines.entity_status) do names[value] = name:gsub("_", "-") end
  return names
end

local function find_assignment(entity)
  for channel, assignment in pairs(root().assignments) do
    if assignment.entity == entity then return channel, assignment end
  end
end

local function effect_index(assignment)
  for index, effect in ipairs(effects) do
    if assignment and assignment.effect == effect then return index end
  end
  return 1
end

local function color_byte(value)
  value = tonumber(value) or 0
  if value <= 1 then value = value * 255 end
  return math.max(0, math.min(255, math.floor(value + 0.5)))
end

local function lamp_channel(channel, assignment)
  local entity = assignment.entity
  if not entity or not entity.valid then return {id = channel, status = "missing"} end
  local behavior = entity.get_control_behavior()
  local off = behavior and behavior.disabled
  local status = entity.status
  off = off or status == defines.entity_status.no_power
    or status == defines.entity_status.low_power
    or status == defines.entity_status.disabled_by_control_behavior
    or status == defines.entity_status.disabled_by_script
    or status == defines.entity_status.turned_off_during_daytime
  local color = (behavior and behavior.color) or entity.color or {r = 1, g = 1, b = 1}
  return {
    id = channel,
    r = off and 0 or color_byte(color.r),
    g = off and 0 or color_byte(color.g),
    b = off and 0 or color_byte(color.b),
    brightness = assignment.brightness or 255,
    effect = assignment.effect or "solid"
  }
end

local function destroy_mark(assignment)
  local mark = assignment and assignment.mark
  if mark and mark.valid then mark.destroy() end
end

local function mark_entity(entity)
  return rendering.draw_circle{
    color = {0.1, 1, 0.2, 0.9}, radius = 0.7, width = 3, filled = false,
    target = entity, surface = entity.surface, only_in_alt_mode = true
  }
end

local function rebuild_marks()
  for _, assignment in pairs(root().assignments) do
    destroy_mark(assignment)
    if assignment.entity and assignment.entity.valid then assignment.mark = mark_entity(assignment.entity) end
  end
end

local function send(kind, channels)
  local state = root()
  state.sequence = state.sequence + 1
  local payload = lib.packet(state.save_id, state.sequence, game.tick, kind, channels)
  helpers.send_udp(PORT, helpers.table_to_json(payload))
end

local function poll(force_snapshot)
  local state = root()
  local channels = lib.collect(state.assignments, status_names(), lamp_channel)
  local changes, values = lib.changed(channels, state.previous)
  state.previous = values
  if force_snapshot then send("snapshot", channels)
  elseif #changes > 0 then send("update", changes) end
end

local function close_prompt(player)
  if player.gui.screen[PROMPT] then player.gui.screen[PROMPT].destroy() end
end

local function show_prompt(player, entity, old_channel)
  close_prompt(player)
  local frame = player.gui.screen.add{type="frame", name=PROMPT, direction="vertical", caption=old_channel ~= nil and {"factorio-status-display.rename-title"} or {"factorio-status-display.assign-title"}}
  frame.auto_center = true
  frame.add{type="label", caption={"factorio-status-display.channel-help"}}
  local text = frame.add{type="textfield", name="factorio_status_display_channel", text=old_channel ~= nil and tostring(old_channel) or "", numeric=true, allow_decimal=false, allow_negative=false}
  text.style.width = 120
  local assignment = old_channel ~= nil and root().assignments[old_channel]
  if entity and entity.valid and entity.type == "lamp" then
    local brightness = assignment and assignment.brightness or 255
    frame.add{type="label", caption={"factorio-status-display.lamp-brightness"}}
    local brightness_flow = frame.add{type="flow", name="factorio_status_display_prompt_brightness_flow", direction="horizontal"}
    local slider = brightness_flow.add{type="slider", name="factorio_status_display_prompt_brightness", minimum_value=0, maximum_value=255, value=brightness, value_step=1}
    slider.style.width = 260
    brightness_flow.add{type="label", name="factorio_status_display_prompt_brightness_value", caption=tostring(brightness)}
    frame.add{type="label", caption={"factorio-status-display.lamp-effect"}}
    frame.add{type="drop-down", name="factorio_status_display_prompt_effect", items=effect_items, selected_index=effect_index(assignment)}
  end
  local flow = frame.add{type="flow", direction="horizontal"}
  flow.add{type="button", name="factorio_status_display_save", caption={"gui.confirm"}, style="confirm_button"}
  flow.add{type="button", name="factorio_status_display_cancel", caption={"gui.cancel"}}
  local pstate = root().players[player.index] or {}
  pstate.pending_entity = entity
  pstate.rename_from = old_channel
  root().players[player.index] = pstate
  player.opened = frame
  text.focus()
end

local function close_list(player)
  if player.gui.screen[FRAME] then player.gui.screen[FRAME].destroy() end
end

local function show_list(player)
  close_list(player)
  local frame = player.gui.screen.add{type="frame", name=FRAME, direction="vertical", caption={"factorio-status-display.list-title"}}
  frame.auto_center = true
  local scroll = frame.add{type="scroll-pane"}; scroll.style.maximal_height = 500; scroll.style.minimal_width = 650
  local channels = {}; for channel in pairs(root().assignments) do channels[#channels+1]=channel end; table.sort(channels)
  if #channels == 0 then scroll.add{type="label", caption={"factorio-status-display.none"}} end
  for _, channel in ipairs(channels) do
    local suffix = tostring(channel)
    local assignment = root().assignments[channel]
    local entry = scroll.add{type="flow", direction="vertical"}
    local row = entry.add{type="flow", direction="horizontal"}
    local valid = assignment.entity and assignment.entity.valid
    row.add{type="label", caption={"factorio-status-display.channel-list-entry", channel, valid and "" or "  [missing]"}}.style.horizontally_stretchable = true
    row.add{type="button", name="factorio_status_display_rename::"..suffix, caption={"factorio-status-display.rename"}}
    row.add{type="button", name="factorio_status_display_remove::"..suffix, caption={"factorio-status-display.remove"}}
    if assignment.kind == "lamp" then
      local settings = entry.add{type="flow", direction="horizontal"}
      settings.add{type="label", caption={"factorio-status-display.lamp-brightness"}}
      local slider = settings.add{type="slider", name="factorio_status_display_list_brightness::"..suffix, minimum_value=0, maximum_value=255, value=assignment.brightness or 255, value_step=1}
      slider.style.width = 220
      settings.add{type="label", name="factorio_status_display_list_brightness_value::"..suffix, caption=tostring(assignment.brightness or 255)}
      settings.add{type="drop-down", name="factorio_status_display_list_effect::"..suffix, items=effect_items, selected_index=effect_index(assignment)}
      settings.add{type="button", name="factorio_status_display_list_apply::"..suffix, caption={"factorio-status-display.apply"}}
    end
  end
  frame.add{type="button", name="factorio_status_display_close", caption={"gui.close"}}
  player.opened = frame
end

local function on_selected(event)
  if event.item ~= TOOL then return end
  local player = game.get_player(event.player_index)
  local entity = event.entities and event.entities[1]
  if not entity or not entity.valid or not supported[entity.type] then player.create_local_flying_text{text={"factorio-status-display.select-one"}, position=player.position}; return end
  if #event.entities ~= 1 then player.create_local_flying_text{text={"factorio-status-display.select-one"}, position=player.position}; return end
  for channel, assignment in pairs(root().assignments) do if assignment.entity == entity then show_prompt(player, entity, channel); return end end
  show_prompt(player, entity, nil)
end

script.on_init(function() root(); rebuild_marks() end)
script.on_configuration_changed(function() root(); rebuild_marks() end)
script.on_event(defines.events.on_player_selected_area, on_selected)
script.on_event(defines.events.on_player_alt_selected_area, on_selected)
script.on_event("factorio-status-display-toggle-list", function(event) local p=game.get_player(event.player_index); if p.gui.screen[FRAME] then close_list(p) else show_list(p) end end)
script.on_nth_tick(30, function(event) poll(event.tick % 300 == 0) end)

script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.valid and (event.element.name == FRAME or event.element.name == PROMPT) then event.element.destroy() end
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
  local element = event.element
  if not element or not element.valid then return end
  if element.name == "factorio_status_display_prompt_brightness" then
    element.parent.factorio_status_display_prompt_brightness_value.caption = tostring(math.floor(element.slider_value + 0.5))
    return
  end
  local suffix = element.name:match("^factorio_status_display_list_brightness::(%d+)$")
  if suffix then
    local label = element.parent["factorio_status_display_list_brightness_value::"..suffix]
    if label then label.caption = tostring(math.floor(element.slider_value + 0.5)) end
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element; if not element or not element.valid then return end
  local player = game.get_player(event.player_index)
  if element.name == "factorio_status_display_close" then close_list(player); return end
  if element.name == "factorio_status_display_cancel" then close_prompt(player); return end
  local action, suffix = element.name:match("^factorio_status_display_(rename)::(%d+)$")
  local channel = suffix and tonumber(suffix)
  if action then local a=root().assignments[channel]; if a then show_prompt(player,a.entity,channel) end; return end
  action, suffix = element.name:match("^factorio_status_display_(remove)::(%d+)$")
  channel = suffix and tonumber(suffix)
  if action then local a=root().assignments[channel]; destroy_mark(a); root().assignments[channel]=nil; root().previous[channel]=nil; send("update",{{id=channel,status="missing"}}); show_list(player); return end
  suffix = element.name:match("^factorio_status_display_list_apply::(%d+)$")
  channel = suffix and tonumber(suffix)
  if channel then
    local assignment=root().assignments[channel]; local controls=element.parent
    if assignment and assignment.kind=="lamp" then
      assignment.brightness=math.floor(controls["factorio_status_display_list_brightness::"..suffix].slider_value+0.5)
      assignment.effect=effects[controls["factorio_status_display_list_effect::"..suffix].selected_index] or "solid"
      poll(false)
    end
    return
  end
  if element.name ~= "factorio_status_display_save" then return end
  local prompt=player.gui.screen[PROMPT]; if not prompt then return end
  local entered=prompt.factorio_status_display_channel.text
  local pstate=root().players[player.index] or {}
  local ok, result=lib.validate_channel(entered,root().assignments,pstate.rename_from)
  if not ok then player.create_local_flying_text{text=result,position=player.position}; return end
  local entity=pstate.pending_entity
  if not entity or not entity.valid then player.create_local_flying_text{text={"factorio-status-display.entity-gone"},position=player.position}; close_prompt(player); return end
  for existing_channel, assignment in pairs(root().assignments) do
    if assignment.entity == entity and existing_channel ~= pstate.rename_from then player.create_local_flying_text{text={"factorio-status-display.already-assigned"},position=player.position}; return end
  end
  if pstate.rename_from ~= nil and pstate.rename_from ~= result then
    local old=root().assignments[pstate.rename_from]; destroy_mark(old); root().assignments[pstate.rename_from]=nil; root().previous[pstate.rename_from]=nil
    send("update",{{id=pstate.rename_from,status="missing"}})
  end
  local old=root().assignments[result]; destroy_mark(old)
  local assignment={entity=entity,mark=mark_entity(entity)}
  if entity.type=="lamp" then
    local brightness_flow=prompt.factorio_status_display_prompt_brightness_flow
    assignment.kind="lamp"
    assignment.brightness=math.floor(brightness_flow.factorio_status_display_prompt_brightness.slider_value+0.5)
    assignment.effect=effects[prompt.factorio_status_display_prompt_effect.selected_index] or "solid"
  end
  root().assignments[result]=assignment
  close_prompt(player); poll(false)
end)
