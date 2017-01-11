local base = _G
local string = require"string"
local table = require"table"
local sys = require"sys"
local ril = require"ril"
local net = require"net"
local pm = require"pm"
local aud = require"audio"

module("cc")

local ipairs,pairs = base.ipairs,base.pairs
local dispatch = sys.dispatch
local req = ril.request

--local
local ccready = false
-- 通话存在标志在以下状态时为true：
-- 主叫呼出中，被叫振铃中，通话中
local callexist = false

local incoming_num = nil -- 记录来电号码保证同一电话多次振铃只提示一次
local emergency_num = {"112", "911", "000", "08", "110", "119", "118", "999"}
local clcc = {}

function isemergencynum(num)
	for k,v in ipairs(emergency_num) do
		if v == num then
			return true
		end
	end
	return false
end

local function clearincomingflag()
	incoming_num = nil
end

local function discevt(reason)
	callexist = false -- 通话结束 清除通话状态标志
	if incoming_num then sys.timer_start(clearincomingflag,1000) end
	pm.sleep("cc")
	dispatch("CALL_DISCONNECTED",reason)
end

function anycallexist()
	return callexist
end

local function qrylist()
	clcc = {}
	req("AT+CLCC")
end

local function proclist()
	local k,v,isactive
	for k,v in pairs(clcc) do
		if v.sta == "0" then isactive = true break end
	end
	if isactive and #clcc > 1 then
		for k,v in pairs(clcc) do
			if v.sta ~= "0" then req("AT+CHLD=1"..v.id) end
		end
	end
end

function dial(number,delay)
	if number == "" or number == nil then
		return false
	end

	if ccready == false and not isemergencynum(number) then
		return false
	end

	pm.wake("cc")
	req(string.format("%s%s;","ATD",number),nil,nil,delay)
	callexist = true -- 主叫呼出

	return true
end

function hangup()
	aud.stop()
	req("AT+CHUP")
end

function accept()
	aud.stop()
	req("ATA")
	pm.wake("cc")
end

local function ccurc(data,prefix)
	if data == "CALL READY" then
		ccready = true
		dispatch("CALL_READY")
		req("AT+CCWA=1")
	elseif data == "CONNECT" then
		qrylist()
		dispatch("CALL_CONNECTED")
	elseif data == "NO CARRIER" or data == "BUSY" or data == "NO ANSWER" then
		qrylist()
		discevt(data)
	elseif prefix == "+CLIP" then
		qrylist()
		local number = string.match(data,"\"(%+*%d*)\"",string.len(prefix)+1)
		callexist = true -- 被叫振铃
		if incoming_num ~= number then
			incoming_num = number
			dispatch("CALL_INCOMING",number)
		end
	elseif prefix == "+CCWA" then
		qrylist()
	elseif prefix == "+CLCC" then
		local id,dir,sta = string.match(data,"%+CLCC:%s*(%d+),(%d),(%d)")
		if id then
			table.insert(clcc,{id=id,dir=dir,sta=sta})
			proclist()
		end
	end
end

local function ccrsp(cmd,success,response,intermediate)
	local prefix = string.match(cmd,"AT(%+*%u+)")
	if prefix == "D" then
		if not success then
			discevt("CALL_FAILED")
		end
	elseif prefix == "+CHUP" then
		discevt("LOCAL_HANG_UP")
	elseif prefix == "A" then
		incoming_num = nil
		dispatch("CALL_CONNECTED")
	end
	qrylist()
end

-- urc
ril.regurc("CALL READY",ccurc)
ril.regurc("CONNECT",ccurc)
ril.regurc("NO CARRIER",ccurc)
ril.regurc("NO ANSWER",ccurc)
ril.regurc("BUSY",ccurc)
ril.regurc("+CLIP",ccurc)
ril.regurc("+CLCC",ccurc)
ril.regurc("+CCWA",ccurc)
-- rsp
ril.regrsp("D",ccrsp)
ril.regrsp("A",ccrsp)
ril.regrsp("+CHUP",ccrsp)
ril.regrsp("+CHLD",ccrsp)

--cc config
req("ATX4") --开启拨号音,忙音检测
req("AT+CLIP=1")
