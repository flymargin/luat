
local base = _G
local string = require"string"
local table = require"table"
local sys = require"sys"
local ril = require"ril"
local net = require"net"
local rtos = require"rtos"
local sim = require"sim"
module("link",package.seeall)

local print = base.print
local pairs = base.pairs
local tonumber = base.tonumber
local tostring = base.tostring
local req = ril.request

local MAXLINKS = 7 -- id 0-7
local IPSTART_INTVL = 10000 --IP环境建立失败时间隔10秒重连

local linklist = {}
local ipstatus = "IP INITIAL"
local cgatt
local apnname = "CMNET"
local username=''
local password=''
local connectnoretrestart = false
local connectnoretinterval
local apnflag,checkciicrtm=true

function setapn(a,b,c)
	apnname,username,password = a,b or '',c or ''
	apnflag=false
end

function getapn()
	return apnname
end

local function connectingtimerfunc(id)
	print("connectingtimerfunc",id,connectnoretrestart)
	if connectnoretrestart then
		sys.restart("link.connectingtimerfunc")
	end
end

local function stopconnectingtimer(id)
	print("stopconnectingtimer",id)
	sys.timer_stop(connectingtimerfunc,id)
end

local function startconnectingtimer(id)
	print("startconnectingtimer",id,connectnoretrestart,connectnoretinterval)
	if id and connectnoretrestart and connectnoretinterval and connectnoretinterval > 0 then
		sys.timer_start(connectingtimerfunc,connectnoretinterval,id)
	end
end

function setconnectnoretrestart(flag,interval)
	connectnoretrestart = flag
	connectnoretinterval = interval
end

local function setupIP()
	print("link.setupIP:",ipstatus,cgatt)
	if ipstatus ~= "IP INITIAL" then
		return
	end

	if cgatt ~= "1" then
		print("setupip: wait cgatt")
		return
	end

	req("AT+CSTT=\""..apnname..'\",\"'..username..'\",\"'..password.. "\"")
	req("AT+CIICR")
	req("AT+CIPSTATUS")
end

local function emptylink()
	for i = 0,MAXLINKS do
		if linklist[i] == nil then
			return i
		end
	end

	return nil
end

local function validaction(id,action)
	if linklist[id] == nil then
		print("link.validaction:id nil",id)
		return false
	end

	if action.."ING" == linklist[id].state then -- 同一个状态不重复执行
		print("link.validaction:",action,linklist[id].state)
		return false
	end

	local ing = string.match(linklist[id].state,"(ING)",-3)

	if ing then
		--有其他任务在处理时,不允许处理连接,断链或者关闭是可以的
		if action == "CONNECT" then
			print("link.validaction: action running",linklist[id].state,action)
			return false
		end
	end

	-- 无其他任务在执行,允许执行
	return true
end

function openid(id,notify,recv)
	if id > MAXLINKS or linklist[id] ~= nil then
		print("openid:error",id)
		return false
	end

	local link = {
		notify = notify,
		recv = recv,
		state = "INITIAL",
	}

	linklist[id] = link

	-- 关注连接urc
	ril.regurc(tostring(id),urc)

	-- 初始化IP环境
	if ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING" then
		setupIP()
	end

	return true
end

function open(notify,recv)
	local id = emptylink()

	if id == nil then
		return nil,"no empty link"
	end

	openid(id,notify,recv)

	return id
end

function close(id)
	if validaction(id,"CLOSE") == false then
		return false
	end

	linklist[id].state = "CLOSING"

	req("AT+CIPCLOSE="..id)

	return true
end

function asyncLocalEvent(msg,cbfunc,id,val)
	cbfunc(id,val)
end

sys.regapp(asyncLocalEvent,"LINK_ASYNC_LOCAL_EVENT")

function connect(id,protocol,address,port)
	if validaction(id,"CONNECT") == false or linklist[id].state == "CONNECTED" then
		return false
	end

	linklist[id].state = "CONNECTING"

	if cc and cc.anycallexist() then
		-- 如果打开了通话功能 并且当前正在通话中使用异步通知连接失败
		print("link.connect:failed cause call exist")
		sys.dispatch("LINK_ASYNC_LOCAL_EVENT",statusind,id,"CONNECT FAIL")
		return true
	end

	local connstr = string.format("AT+CIPSTART=%d,\"%s\",\"%s\",%s",id,protocol,address,port)

	if ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING" then
		-- ip环境未准备好先加入等待
		linklist[id].pending = connstr
	else
		req(connstr)
		startconnectingtimer(id)
	end

	return true
end

function disconnect(id)
	if validaction(id,"DISCONNECT") == false then
		return false
	end

	if linklist[id].pending then
		linklist[id].pending = nil
		if ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING" and linklist[id].state == "CONNECTING" then
			print("link.disconnect: ip not ready",ipstatus)
			linklist[id].state = "DISCONNECTING"
			sys.dispatch("LINK_ASYNC_LOCAL_EVENT",closecnf,id,"DISCONNECT","OK")
			return
		end
	end

	linklist[id].state = "DISCONNECTING"

	req("AT+CIPCLOSE="..id)

	return true
end

function send(id,data)
	if linklist[id] == nil or linklist[id].state ~= "CONNECTED" then
		print("link.send:error",id)
		return false
	end

	if cc and cc.anycallexist() then
		-- 如果打开了通话功能 并且当前正在通话中使用异步通知连接失败
		print("link.send:failed cause call exist")
		return false
	end

	req(string.format("AT+CIPSEND=%d,%d",id,string.len(data)),data)

	return true
end

function getstate(id)
	return linklist[id] and linklist[id].state or "NIL LINK"
end

local function recv(id,len,data)
	if linklist[id] == nil then
		print("link.recv:error",id)
		return
	end

	if linklist[id].recv then
		linklist[id].recv(id,data)
	else
		print("link.recv:nil recv",id)
	end
end

-- ipstatus查询返回的状态不提示
function linkstatus(data)
end

local function sendcnf(id,result)
	local str = string.match(result,"([%u ])")
	if str == "TCP ERROR" or str == "UDP ERROR" or str == "ERROR" then
		linklist[id].state = result
	end
	linklist[id].notify(id,"SEND",result)
end

function closecnf(id,result)
	if not id or not linklist[id] then
		print("link.closecnf:error",id)
		return
	end
	-- 不管任何的close结果,链接总是成功断开了,所以直接按照链接断开处理
	if linklist[id].state == "DISCONNECTING" then
		linklist[id].state = "CLOSED"
		linklist[id].notify(id,"DISCONNECT","OK")
		stopconnectingtimer(id)
	elseif linklist[id].state == "CLOSING" then
		-- 连接注销,清除维护的连接信息,清除urc关注
		local tlink = linklist[id]
		linklist[id] = nil
		ril.deregurc(tostring(id),urc)
		tlink.notify(id,"CLOSE","OK")
		stopconnectingtimer(id)
	else
		print("link.closecnf:error",linklist[id].state)
	end
end

-- 状态urc上报,有两种情况:cipstart返回或者链接状态变化
function statusind(id,state)
	if linklist[id] == nil then
		print("link.statusind:nil id",id)
		return
	end

	if state == "SEND FAIL" then -- 快发失败的提示会变成URC
		if linklist[id].state == "CONNECTED" then
			linklist[id].notify(id,"SEND",state)
		else
			print("statusind:send fail state",linklist[id].state)
		end
		return
	end

	local evt

	if linklist[id].state == "CONNECTING" or state == "CONNECT OK" then
		evt = "CONNECT"
	else
		evt = "STATE"
	end

	-- 除非连接成功,否则连接仍然还是在关闭状态
	if state == "CONNECT OK" then
		linklist[id].state = "CONNECTED"
	else
		linklist[id].state = "CLOSED"
	end

	linklist[id].notify(id,evt,state)
	stopconnectingtimer(id)
end

local function connpend()
	for k,v in pairs(linklist) do
		if v.pending then
			req(v.pending)
			local id = string.match(v.pending,"AT%+CIPSTART=(%d)")
			if id then
				startconnectingtimer(tonumber(id))
			end
			v.pending = nil
		end
	end
end

local function setIPStatus(status)
	print("ipstatus:",status)

	if ipstatus ~= status or status=="IP START" or status == "IP CONFIG" or status == "IP GPRSACT" or status == "PDP DEACT" then
		if status=="IP GPRSACT" and checkciicrtm then
			sys.timer_stop(sys.restart,"checkciicr")
		end
		ipstatus = status
		if ipstatus == "IP PROCESSING" then
		elseif ipstatus == "IP STATUS" then
			connpend()
		elseif ipstatus == "IP INITIAL" then -- 重新连接
			sys.timer_start(setupIP,IPSTART_INTVL)
		elseif ipstatus == "IP CONFIG" or ipstatus == "IP START" then
			sys.timer_start(req,2000,"AT+CIPSTATUS")
		elseif ipstatus == "IP GPRSACT" then
			req("AT+CIFSR")
			req("AT+CIPSTATUS")
		else -- 其他异常状态关闭至IP INITIAL
			req("AT+CIPSHUT")
			sys.timer_stop(req,"AT+CIPSTATUS")
		end
	end
end

local function shutcnf(result)
	if result == "SHUT OK" then
		setIPStatus("IP INITIAL")
		for i = 0,MAXLINKS do
			if linklist[i] then
				if linklist[i].state == "CONNECTING" and linklist[i].pending then
					-- 对于尚未进行过的连接请求 不提示close,IP环境建立后自动连接
				elseif linklist[i].state == "INITIAL" then -- 未连接的也不提示
				else
					linklist[i].state = "CLOSED"
					linklist[i].notify(i,"STATE","CLOSED")
				end
				stopconnectingtimer(i)
			end
		end
	else
		--req("AT+CIPSTATUS")
		sys.timer_start(req,10000,"AT+CIPSTATUS")
	end
	if checkciicrtm then
		sys.timer_stop(sys.restart,"checkciicr")
	end
end

local function reconnip(force)
	print("link.reconnip",force,ipstatus,cgatt)
	if force then
		setIPStatus("PDP DEACT")
	else
		if ipstatus == "IP START" or ipstatus == "IP CONFIG" or ipstatus == "IP GPRSACT" or ipstatus == "IP STATUS" or ipstatus == "IP PROCESSING" then
			setIPStatus("PDP DEACT")
		end
		cgatt = "0"
	end
end

local rcvd = {id = 0,len = 0,data = ""}

local function rcvdfilter(data)
	if rcvd.len == 0 then
		return data
	end

	local restlen = rcvd.len - string.len(rcvd.data)
	if  string.len(data) > restlen then -- at通道的内容比剩余未收到的数据多
		-- 截取网络发来的数据
		rcvd.data = rcvd.data .. string.sub(data,1,restlen)
		-- 剩下的数据仍按at进行后续处理
		data = string.sub(data,restlen+1,-1)
	else
		rcvd.data = rcvd.data .. data
		data = ""
	end

	if rcvd.len == string.len(rcvd.data) then
		--通知接收数据
		recv(rcvd.id,rcvd.len,rcvd.data)
		rcvd.id = 0
		rcvd.len = 0
		rcvd.data = ""
		return data
	else
		return data, rcvdfilter
	end
end

function urc(data,prefix)
	if prefix == "STATE" then
		setIPStatus(string.sub(data,8,-1))
	elseif prefix == "C" then
		linkstatus(data)
	elseif prefix == "+PDP" then
		--req("AT+CIPSTATUS")
		req("AT+CIPSHUT")
		sys.timer_stop(req,"AT+CIPSTATUS")
	elseif prefix == "+RECEIVE" then
		local lid,len = string.match(data,",(%d),(%d+)",string.len("+RECEIVE")+1)
		rcvd.id = tonumber(lid)
		rcvd.len = tonumber(len)
		return rcvdfilter
	else
		local lid,lstate = string.match(data,"(%d), *([%u :%d]+)")

		if lid then
			lid = tonumber(lid)
			statusind(lid,lstate)
		end
	end
end

function shut()
	req("AT+CIPSHUT")
end
reset = shut

local function getresult(str)
	return str == "ERROR" and str or string.match(str,"%d, *([%u :%d]+)")
end

local function rsp(cmd,success,response,intermediate)
	local prefix = string.match(cmd,"AT(%+%u+)")
	local id = tonumber(string.match(cmd,"AT%+%u+=(%d)"))

	if prefix == "+CIPSEND" then
		if response == "+PDP: DEACT" then
			req("AT+CIPSTATUS")
			response = "ERROR"
		end
		if string.match(response,"DATA ACCEPT") then
			sendcnf(id,"SEND OK")
		else
			sendcnf(id,getresult(response))
		end
	elseif prefix == "+CIPCLOSE" then
		closecnf(id,getresult(response))
	elseif prefix == "+CIPSHUT" then
		shutcnf(response)
	elseif prefix == "+CIPSTART" then
		if response == "ERROR" then
			statusind(id,"ERROR")
		end
	elseif checkciicrtm and prefix == "+CIICR" then
		if success then
			if not sys.timer_is_active(sys.restart,"checkciicr") then
				sys.timer_start(sys.restart,checkciicrtm,"checkciicr")
			end
		end
	end
end

ril.regurc("STATE",urc)
ril.regurc("C",urc)
ril.regurc("+PDP",urc)
ril.regurc("+RECEIVE",urc)

ril.regrsp("+CIPSTART",rsp)
ril.regrsp("+CIPSEND",rsp)
ril.regrsp("+CIPCLOSE",rsp)
ril.regrsp("+CIPSHUT",rsp)

-- 在网络正常后初始化ip
local QUERYTIME = 2000
local querycgatt

local function cgattrsp(cmd,success,response,intermediate)
	if intermediate == "+CGATT: 1" then
		cgatt = "1"
		sys.dispatch("NET_GPRS_READY",true)

		-- 如果存在链接,那么在gprs附着上以后自动初始化ip环境
		if base.next(linklist) then
			if ipstatus == "IP INITIAL" then
				setupIP()
			else
				req("AT+CIPSTATUS")
			end
		end
	elseif intermediate == "+CGATT: 0" then
		if cgatt ~= "0" then
			cgatt = "0"
			sys.dispatch("NET_GPRS_READY",false)
		end
		sys.timer_start(querycgatt,QUERYTIME)
	end
end

querycgatt = function()
	req("AT+CGATT?",nil,cgattrsp)
end

-- 配置接口
local qsend = 0
function SetQuickSend(mode)
	qsend = mode
end

local inited = false
local function initial()
	if not inited then
		inited = true
		req("AT+CIICRMODE=2") -- ciicr异步
		req("AT+CIPMUX=1") -- 多链接
		req("AT+CIPHEAD=1")
		req("AT+CIPQSEND=" .. qsend)
	end
end

local function netmsg(id,data)
	if data == "REGISTERED" then
		initial() -- 进行初始化配置
		sys.timer_start(querycgatt,QUERYTIME)
	end

	return true
end

local apntable =
{
	["46000"] = "CMNET",
	["46002"] = "CMNET",
	["46004"] = "CMNET",
	["46007"] = "CMNET",
	["46001"] = "UNINET",
	["46006"] = "UNINET",
}

local function proc(id)
	if apnflag then
		if apn then
			local temp1,temp2,temp3=apn.get_default_apn(tonumber(sim.getmcc(),16),tonumber(sim.getmnc(),16))
			if temp1 == '' or temp1 == nil then temp1="CMNET" end
			setapn(temp1,temp2,temp3)
		else
			setapn(apntable[sim.getmcc()..sim.getmnc()] or "CMNET")
		end
	end
	return true
end

function checkciicr(tm)
	checkciicrtm = tm
	ril.regrsp("+CIICR",rsp)
end

sys.regapp(proc,"IMSI_READY")
sys.regapp(netmsg,"NET_STATE_CHANGED")

