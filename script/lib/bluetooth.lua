local base = _G
local string = require "string"
local table = require "table"
local sys = require "sys"
local ril = require "ril"
local common = require "common"
module("bluetooth")

local print = base.print
local tonumber = base.tonumber
local hextobin=common.hexstobins
local dispatch = sys.dispatch
local req = ril.request

local ready = false
local search = false
local mac=''
local TAGET='RhBtTest'
TAGFLAG=false
function open()
	if ready then return true end
	req("AT+BTPOWERON=1")
end

function SearchBlutooth()
	-- if not ready then return true end
	-- if search then return true end
	req('AT+BTSCAN=20,50')
end

function close()
	req("AT+BTPOWERON=0")
	ready = false
	search = false
end
function readmac(flag)
	if mac~='' and mac~=nil then
		if flag == 'number' then
			print('readmac',mac)
			print('1',string.len(mac),string.sub(mac,16,17),tonumber(string.sub(mac,16,17),16),'2',string.sub(mac,1,2),tonumber(string.sub(mac,1,2),16),common.hexstobins(string.sub(mac,16,17)),string.len(common.hexstobins(string.sub(mac,16,17))))
		    return hextobin(string.sub(mac,1,2))..hextobin(string.sub(mac,4,5))..hextobin(string.sub(mac,7,8))..hextobin(string.sub(mac,10,11))..hextobin(string.sub(mac,13,14))..hextobin(string.sub(mac,16,17))
		else
			return
		end
	else
		return '\0\0\0\0\0\0'
	end
end

local function rsp(cmd,success,response,intermediate)
	print('bluetooth_rsp',cmd,success,response,intermediate)
	if success then
		if cmd == 'AT+BTMAC' then	
			mac=string.sub(intermediate,-17,-1)
		end
		if cmd == 'AT+BTPOWERON=1' then
			dispatch("BTPOWERON")
		end
		if cmd == 'AT+BTPOWERON=0' then
			dispatch("BTPOWEROFF")
		end
	end
end

local function urc(data,prefix)
	print('bluetooth_urc',data)
	if string.match(data,TAGET)~=nil and string.match(data,TAGET)~=''  then
		TAGFLAG=true
	end
end

ril.regurc("+BTSTATUS",urc)
ril.regurc("+BTDATA",urc)
ril.regurc("+BTSCAN",urc)

ril.regrsp("+BTPOWERON",rsp)
ril.regrsp("+BTNAME",rsp)
ril.regrsp("+BTPIN",rsp)
ril.regrsp("+BTSEND",rsp)
ril.regrsp("+BTMAC",rsp,2)

open()
req("AT+BTMAC")
-- SearchBlutooth()
close()