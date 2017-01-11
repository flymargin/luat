
local base = _G
local string = require"string"
local sys = require "sys"
local ril = require "ril"
require"sim"
module("net")

local dispatch = sys.dispatch
local req = ril.request
local smatch = string.match
local tonumber,tostring = base.tonumber,base.tostring

local state = "INIT"
local lac,ci,rssi = "","",0
local csqqrypriod,cengqrypriod = 60*1000
local cellinfo = {}

local function creg(data)
	local p1,s
	_,_,p1 = string.find(data,"%d,(%d)")
	if p1 == nil then
		_,_,p1 = string.find(data,"(%d)")
		if p1 == nil then
			return
		end
	end

	if p1 == "1" or p1 == "5" then
		s = "REGISTERED"
	else
		s = "UNREGISTER"
	end

	if s ~= state then
		if not cengqrypriod and s == "REGISTERED" then
			setcengqueryperiod(60000)
		else
			cengquery()
		end
		state = s
		dispatch("NET_STATE_CHANGED",s)
	end

	if state == "REGISTERED" then
		p2,p3 = string.match(data,"\"(%x+)\",\"(%x+)\"")
		if lac ~= p2 or ci ~= p3 then
			lac = p2
			ci = p3
			dispatch("NET_CELL_CHANGED")
		end
	end
end

local function resetcellinfo()
	local i
	cellinfo.cnt = 11
	for i=1,cellinfo.cnt do
		cellinfo[i] = {}
		cellinfo[i].mcc,cellinfo[i].mnc = nil
		cellinfo[i].lac = 0
		cellinfo[i].ci = 0
		cellinfo[i].rssi = 0
		cellinfo[i].ta = 0
	end
end

local function ceng(data)
	if string.find(data,"%+CENG:%d+,\".+\"") then
		local id,rssi,lac,ci,ta,mcc,mnc
		id = string.match(data,"%+CENG:(%d)")
		id = tonumber(id)
		if id == 0 then
			rssi,mcc,mnc,ci,lac,ta = string.match(data, "%+CENG:%d,\"%d+,(%d+),%d+,(%d+),(%d+),%d+,(%d+),%d+,%d+,(%d+),(%d+)\"")
		else
			rssi,mcc,mnc,ci,lac,ta = string.match(data, "%+CENG:%d,\"%d+,(%d+),(%d+),(%d+),%d+,(%d+),(%d+)\"")
		end
		if rssi and ci and lac and mcc and mnc then
			if id == 0 then
				resetcellinfo()
			end
			cellinfo[id+1].mcc = mcc
			cellinfo[id+1].mnc = mnc
			cellinfo[id+1].lac = tonumber(lac)
			cellinfo[id+1].ci = tonumber(ci)
			cellinfo[id+1].rssi = (tonumber(rssi) == 99) and 0 or tonumber(rssi)
			cellinfo[id+1].ta = tonumber(ta or "0")
			if id == 0 then
				dispatch("CELL_INFO_IND",cellinfo)
			end
		end
	end
end

local function neturc(data,prefix)
	if prefix == "+CREG" then
		req("AT+CSQ") -- 收到网络状态变化时,更新一下信号值
		creg(data)
	elseif prefix == "+CENG" then
		ceng(data)
	end
end

function getstate()
	return state
end

function getmcc()
	return cellinfo[1].mcc or sim.getmcc()
end

function getmnc()
	return cellinfo[1].mnc or sim.getmnc()
end

function getlac()
	return lac
end

function getci()
	return ci
end

function getrssi()
	return rssi
end

function getcell()
	local i,ret = 1,""
	for i=1,cellinfo.cnt do
		if cellinfo[i] and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
			ret = ret..cellinfo[i].ci.."."..cellinfo[i].rssi.."."
		end
	end
	return ret
end

function getcellinfo()
	local i,ret = 1,""
	for i=1,cellinfo.cnt do
		if cellinfo[i] and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
			ret = ret..cellinfo[i].lac.."."..cellinfo[i].ci.."."..cellinfo[i].rssi..";"
		end
	end
	return ret
end

function getcellinfoext()
	local i,ret = 1,""
	for i=1,cellinfo.cnt do
		if cellinfo[i] and cellinfo[i].mcc and cellinfo[i].mnc and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
			ret = ret..cellinfo[i].mcc.."."..cellinfo[i].mnc.."."..cellinfo[i].lac.."."..cellinfo[i].ci.."."..cellinfo[i].rssi..";"
		end
	end
	return ret
end

function getta()
	return cellinfo[1].ta
end

function startquerytimer() end

local function SimInd(id,para)
	if para ~= "RDY" then
		state = "UNREGISTER"
		dispatch("NET_STATE_CHANGED",state)
	end
	if para == "NIST" then
		sys.timer_stop(queryfun)
	end

	return true
end

function startcsqtimer()
	req("AT+CSQ")
	sys.timer_start(startcsqtimer,csqqrypriod)
end

function startcengtimer()
	req("AT+CENG?")
	req("AT+CREG?")
	sys.timer_start(startcengtimer,cengqrypriod)
end

local function rsp(cmd,success,response,intermediate)
	local prefix = string.match(cmd,"AT(%+%u+)")

	if intermediate ~= nil then
		if prefix == "+CSQ" then
			local s = smatch(intermediate,"+CSQ:%s*(%d+)")
			if s ~= nil then
				rssi = tonumber(s)
				rssi = rssi == 99 and 0 or rssi
				dispatch("GSM_SIGNAL_REPORT_IND",success,rssi)
			end
		elseif prefix == "+CENG" then
		end
	end
end

function setcsqqueryperiod(period)
	csqqrypriod = period
	startcsqtimer()
end

function setcengqueryperiod(period)
	if period ~= cengqrypriod then
		if period <= 0 then
			sys.timer_stop(startcengtimer)
		else
			cengqrypriod = period
			startcengtimer()
		end
	end
end

function cengquery()
	req("AT+CENG?")
	req("AT+CREG?")
end

function csqquery()
	req("AT+CSQ")
end

sys.regapp(SimInd,"SIM_IND")
ril.regurc("+CREG",neturc)
ril.regurc("+CENG",neturc)
ril.regrsp("+CSQ",rsp)
ril.regrsp("+CENG",rsp)
req("AT+CREG=2")
req("AT+CREG?")
req("AT+CENG=1,1")
sys.timer_start(startcsqtimer,8*1000) -- 8秒后查询第一次csq
resetcellinfo()
