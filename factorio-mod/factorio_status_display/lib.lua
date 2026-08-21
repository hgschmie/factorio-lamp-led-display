local M = {}

function M.validate_channel(name, assignments, ignore_name)
  if type(name) ~= "string" then return false, "Channel name is required." end
  name = name:match("^%s*(.-)%s*$")
  if #name < 1 or #name > 64 then return false, "Use 1–64 characters." end
  if not name:match("^[a-z0-9][a-z0-9%-_%.]*$") then
    return false, "Use lowercase letters, digits, hyphen, underscore, or dot."
  end
  if name ~= ignore_name and assignments[name] then return false, "That channel already exists." end
  return true, name
end

function M.entity_status(entity, status_names)
  if not entity or not entity.valid then return "missing" end
  return status_names[entity.status] or "unknown"
end

function M.collect(assignments, status_names)
  local channels = {}
  for name, assignment in pairs(assignments) do
    channels[#channels + 1] = {id = name, status = M.entity_status(assignment.entity, status_names)}
  end
  table.sort(channels, function(a, b) return a.id < b.id end)
  return channels
end

function M.changed(current, previous)
  local result, next_values = {}, {}
  for _, channel in ipairs(current) do
    next_values[channel.id] = channel.status
    if previous[channel.id] ~= channel.status then result[#result + 1] = channel end
  end
  for id in pairs(previous) do
    if next_values[id] == nil then result[#result + 1] = {id = id, status = "missing"} end
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result, next_values
end

function M.packet(save_id, sequence, tick, kind, channels)
  return {version = 1, save_id = save_id, sequence = sequence, tick = tick, type = kind, channels = channels}
end

return M

