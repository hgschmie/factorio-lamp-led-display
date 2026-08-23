package.path = "../factorio_status_display/?.lua;" .. package.path
local lib = require("lib")

local function eq(actual, expected, message)
  if actual ~= expected then error((message or "values differ") .. ": got " .. tostring(actual) .. ", expected " .. tostring(expected)) end
end

local ok, value = lib.validate_channel(" 0 ", {})
eq(ok, true); eq(value, 0)
eq(lib.validate_channel("63", {}), true)
eq(lib.validate_channel("64", {}), false)
eq(lib.validate_channel("1.5", {}), false)
eq(lib.validate_channel("name", {}), false)
eq(lib.validate_channel("5", {[5]={}}), false)

local statuses = {[1]="working", [2]="no-power"}
eq(lib.entity_status({valid=true,status=1}, statuses), "working")
eq(lib.entity_status({valid=false}, statuses), "missing")
eq(lib.entity_status({valid=true,status=99}, statuses), "unknown")

local list = lib.collect({[12]={entity={valid=false}},[2]={entity={valid=true,status=1}}}, statuses)
eq(list[1].id, 2); eq(list[2].status, "missing")
local changes, values = lib.changed(list, {[2]="no-power",[7]="working"})
eq(#changes, 3); eq(values[2], "status:working")

local direct = {id=63,r=1,g=2,b=3,brightness=127,effect="pulse"}
eq(lib.channel_signature(direct), "rgb:1:2:3:127:pulse")

local packet = lib.packet("save", 7, 123, "snapshot", list)
eq(packet.version, 2); eq(packet.sequence, 7); eq(packet.type, "snapshot")
print("factorio mod unit tests passed")
