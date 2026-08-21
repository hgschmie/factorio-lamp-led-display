local lib = require("lib")
local TOOL = "factorio-status-display-selector"
local FRAME = "factorio_status_display_frame"
local PROMPT = "factorio_status_display_prompt"
local PORT = 34198

local supported = { ["assembling-machine"] = true, furnace = true, ["rocket-silo"] = true }

local function root()
  storage.factorio_status_display = storage.factorio_status_display or {}
  local state = storage.factorio_status_display
  state.assignments = state.assignments or {}
  state.players = state.players or {}
  state.previous = state.previous or {}
  state.sequence = state.sequence or 0
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

local function destroy_mark(assignment)
  local mark = assignment and assignment.mark
  if mark and mark.valid then mark.destroy() end
end

local function mark_entity(entity)
  return rendering.draw_circle{
    color = {0.1, 1, 0.2, 0.9}, radius = 0.7, width = 3, filled = false,
    target = entity, surface = entity.surface, only_in_alt_mode = false
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
  local channels = lib.collect(state.assignments, status_names())
  local changes, values = lib.changed(channels, state.previous)
  state.previous = values
  if force_snapshot then send("snapshot", channels)
  elseif #changes > 0 then send("update", changes) end
end

local function close_prompt(player)
  if player.gui.screen[PROMPT] then player.gui.screen[PROMPT].destroy() end
end

local function show_prompt(player, entity, old_name)
  close_prompt(player)
  local frame = player.gui.screen.add{type="frame", name=PROMPT, direction="vertical", caption=old_name and {"factorio-status-display.rename-title"} or {"factorio-status-display.assign-title"}}
  frame.auto_center = true
  frame.add{type="label", caption={"factorio-status-display.channel-help"}}
  local text = frame.add{type="textfield", name="factorio_status_display_name", text=old_name or ""}
  text.style.width = 320
  local flow = frame.add{type="flow", direction="horizontal"}
  flow.add{type="button", name="factorio_status_display_save", caption={"gui.confirm"}, style="confirm_button"}
  flow.add{type="button", name="factorio_status_display_cancel", caption={"gui.cancel"}}
  local pstate = root().players[player.index] or {}
  pstate.pending_entity = entity
  pstate.rename_from = old_name
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
  local scroll = frame.add{type="scroll-pane"}; scroll.style.maximal_height = 500; scroll.style.minimal_width = 480
  local names = {}; for name in pairs(root().assignments) do names[#names+1]=name end; table.sort(names)
  if #names == 0 then scroll.add{type="label", caption={"factorio-status-display.none"}} end
  for _, name in ipairs(names) do
    local assignment = root().assignments[name]
    local row = scroll.add{type="flow", direction="horizontal"}
    local valid = assignment.entity and assignment.entity.valid
    row.add{type="label", caption=name .. (valid and "" or "  [missing]")}.style.horizontally_stretchable = true
    row.add{type="button", name="factorio_status_display_rename::"..name, caption={"factorio-status-display.rename"}}
    row.add{type="button", name="factorio_status_display_remove::"..name, caption={"factorio-status-display.remove"}}
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
  for name, assignment in pairs(root().assignments) do
    if assignment.entity == entity then show_prompt(player, entity, name); return end
  end
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

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element; if not element or not element.valid then return end
  local player = game.get_player(event.player_index)
  if element.name == "factorio_status_display_close" then close_list(player); return end
  if element.name == "factorio_status_display_cancel" then close_prompt(player); return end
  local action, name = element.name:match("^factorio_status_display_(rename)::(.+)$")
  if action then local a=root().assignments[name]; if a then show_prompt(player,a.entity,name) end; return end
  action, name = element.name:match("^factorio_status_display_(remove)::(.+)$")
  if action then local a=root().assignments[name]; destroy_mark(a); root().assignments[name]=nil; root().previous[name]=nil; send("update",{{id=name,status="missing"}}); show_list(player); return end
  if element.name ~= "factorio_status_display_save" then return end
  local prompt=player.gui.screen[PROMPT]; if not prompt then return end
  local entered=prompt.factorio_status_display_name.text
  local pstate=root().players[player.index] or {}
  local ok, result=lib.validate_channel(entered,root().assignments,pstate.rename_from)
  if not ok then player.create_local_flying_text{text=result,position=player.position}; return end
  local entity=pstate.pending_entity
  if not entity or not entity.valid then player.create_local_flying_text{text={"factorio-status-display.entity-gone"},position=player.position}; close_prompt(player); return end
  for existing, assignment in pairs(root().assignments) do
    if assignment.entity == entity and existing ~= pstate.rename_from then player.create_local_flying_text{text={"factorio-status-display.already-assigned"},position=player.position}; return end
  end
  if pstate.rename_from and pstate.rename_from ~= result then
    local old=root().assignments[pstate.rename_from]; destroy_mark(old); root().assignments[pstate.rename_from]=nil; root().previous[pstate.rename_from]=nil
    send("update",{{id=pstate.rename_from,status="missing"}})
  end
  local old=root().assignments[result]; destroy_mark(old)
  root().assignments[result]={entity=entity,mark=mark_entity(entity)}
  close_prompt(player); poll(false)
end)

