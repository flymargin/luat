
local string = require"string"
local ril = require"ril"
local sys = require"sys"
local base = _G
local os = require"os"
module(...)

local tonumber = base.tonumber
local tostring = base.tostring
local req = ril.request
local imsi
local iccid

function geticcid()
	return iccid
end

function getimsi()
	return imsi
end

function getmcc()
	return (imsi ~= nil and imsi ~= "") and string.sub(imsi,1,3) or ""
end

function getmnc()
	return (imsi ~= nil and imsi ~= "") and string.sub(imsi,4,5) or ""
end

local function rsp(cmd,success,response,intermediate)
	if cmd == "AT+CCID" then
		iccid = intermediate
	elseif cmd == "AT+CIMI" then
		imsi = intermediate
		sys.dispatch("IMSI_READY")
	end
end

local function urc(data,prefix)
	if prefix == "+CPIN" then
		if data == "+CPIN: READY" then
			req("AT+CCID")
			req("AT+CIMI")
			sys.dispatch("SIM_IND","RDY")
		elseif data == "+CPIN: NOT INSERTED" then
			sys.dispatch("SIM_IND","NIST")
		else
			if data == "+CPIN: SIM PIN" then
				sys.dispatch("SIM_IND_SIM_PIN")	
			end
			sys.dispatch("SIM_IND","NORDY")
		end
	end
end

ril.regrsp("+CCID",rsp)
ril.regrsp("+CIMI",rsp)
ril.regurc("+CPIN",urc)
