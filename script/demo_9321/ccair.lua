module(...,package.seeall)
require"cc"
local stat,num,linkshut = "IDLE",{}

local function addnum(id,val)
	print("ccapp addmun",id,val,stat)
	if val and string.len(val) > 0 and stat == "IDLE" then
		table.insert(num,val)
	end
end

local function dialnum()
	print("ccapp dialnum",#num)
	if #num > 0 then
		link.shut()
		linkshut = true
		if not cc.dial(table.remove(num,1),2000) then dialnum() end
		stat = "DIALING"
		sys.timer_start(cc.hangup,40000,"r1")
		return true
	end
end

local function connect()
	sys.timer_stop(cc.hangup,"r1")
	stat = "CONNECT"
	num = {}
	sys.dispatch("CCAPP_CONNECT")
	return true
end

local function disconnect()
	sys.timer_stop(cc.hangup,"r1")
	if linkshut then
		linkshut = nil
		link.reset()
	end
	if not dialnum() then
		stat = "IDLE"
		sys.dispatch("CCAPP_DISCONNECT")
	end
	return true
end

sys.regapp(connect,"CALL_CONNECTED")
sys.regapp(disconnect,"CALL_DISCONNECTED")
sys.regapp(addnum,"CCAPP_ADD_NUM")
sys.regapp(dialnum,"CCAPP_DIAL_NUM")

