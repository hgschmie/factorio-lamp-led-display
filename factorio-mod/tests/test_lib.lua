package.path = "../factorio_status_display/?.lua;" .. package.path
local lib = require("lib")

local function eq(actual, expected, message)
  if actual ~= expected then error((message or "values differ") .. ": got " .. tostring(actual) .. ", expected " .. tostring(expected)) end
end

local ok, value = lib.validate_channel(" smelter-1 ", {})
eq(ok, true); eq(value, "smelter-1")
eq(lib.validate_channel("Bad Name", {}), false)
eq(lib.validate_channel("used", {used={}}), false)

local statuses = {[1]="working", [2]="no-power"}
eq(lib.entity_status({valid=true,status=1}, statuses), "working")
eq(lib.entity_status({valid=false}, statuses), "missing")
eq(lib.entity_status({valid=true,status=99}, statuses), "unknown")

local list = lib.collect({b={entity={valid=false}},a={entity={valid=true,status=1}}}, statuses)
eq(list[1].id, "a"); eq(list[2].status, "missing")
local changes, values = lib.changed(list, {a="no-power",old="working"})
eq(#changes, 3); eq(values.a, "working")

local packet = lib.packet("save", 7, 123, "snapshot", list)
eq(packet.version, 1); eq(packet.sequence, 7); eq(packet.type, "snapshot")
print("factorio mod unit tests passed")

