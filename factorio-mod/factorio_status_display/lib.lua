local M = {}

function M.validate_channel(value, assignments, ignore_channel)
  if type(value) == "string" then value = value:match("^%s*(.-)%s*$") end
  local channel = tonumber(value)
  if not channel or channel ~= math.floor(channel) or channel < 0 or channel > 63 then
    return false, "Enter a channel number from 0 to 63."
  end
  if channel ~= ignore_channel and assignments[channel] then return false, "That channel is already assigned." end
  return true, channel
end

function M.entity_status(entity, status_names)
  if not entity or not entity.valid then return "missing" end
  return status_names[entity.status] or "unknown"
end

function M.collect(assignments, status_names, lamp_value)
  local channels = {}
  for channel, assignment in pairs(assignments) do
    if assignment.kind == "lamp" and lamp_value then
      channels[#channels + 1] = lamp_value(channel, assignment)
    else
      channels[#channels + 1] = {id = channel, status = M.entity_status(assignment.entity, status_names)}
    end
  end
  table.sort(channels, function(a, b) return a.id < b.id end)
  return channels
end

function M.changed(current, previous)
  local result, next_values = {}, {}
  for _, channel in ipairs(current) do
    local signature = M.channel_signature(channel)
    next_values[channel.id] = signature
    if previous[channel.id] ~= signature then result[#result + 1] = channel end
  end
  for id in pairs(previous) do
    if next_values[id] == nil then result[#result + 1] = {id = id, status = "missing"} end
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result, next_values
end

function M.channel_signature(channel)
  if channel.status then return "status:" .. channel.status end
  return table.concat({"rgb", channel.r or 0, channel.g or 0, channel.b or 0,
    channel.brightness or 255, channel.effect or "solid"}, ":")
end

function M.packet(save_id, sequence, tick, kind, channels)
  return {version = 2, save_id = save_id, sequence = sequence, tick = tick, type = kind, channels = channels}
end

return M
