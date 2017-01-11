
-- load patch
require"patch"

local base = _G
local table = require"table"
local rtos = require"rtos"
local uart = require"uart"
local io = require"io"
local os = require"os"
module("sys")

local print = base.print
local unpack = base.unpack
local ipairs = base.ipairs
local type = base.type
local pairs = base.pairs
local assert = base.assert

-- 刷新处理
local refreshflag = false
function refresh()
	refreshflag = true
end

-- 定时器管理,自动分配定时器id
local MAXMS = 0x7fffffff/17 -- 最大定时值
local uniquetid = 0
local tpool = {}
local para = {}
local loop = {}
local lprfun,lpring
local LIB_ERR_FILE,liberr = "/lib_err.txt",""

local function timerfnc(tid)
	if tpool[tid] ~= nil then
		local cb = tpool[tid]

		if type(tpool[tid]) == "table" then
			local tval = tpool[tid]
			tval.times = tval.times+1
			if tval.times < tval.total then
				rtos.timer_start(tid,tval.step)
				return
			end
			cb = tval.cb
		end

		if not loop[tid] then tpool[tid] = nil end
		if para[tid] ~= nil then
			local pval = para[tid]
			if not loop[tid] then para[tid] = nil end
			cb(unpack(pval))
		else
			cb()
		end
		if loop[tid] then rtos.timer_start(tid,loop[tid]) end
	end
end

local function comp_table(t1,t2)
	if not t2 then return #t1 == 0 end
	if #t1 == #t2 then
		for i=1,#t1 do
			if unpack(t1,i,i) ~= unpack(t2,i,i) then
				return false
			end
		end
		return true
	end
	return false
end

function timer_start(fnc,ms,...)
	assert(fnc ~= nil,"timer_start:callback function == nil")
	if arg.n == 0 then
		timer_stop(fnc)
	else
		timer_stop(fnc,unpack(arg))
	end
	if ms > MAXMS then
		local count = ms/MAXMS + (ms%MAXMS == 0 and 0 or 1)
		local step = ms/count
		tval = {cb = fnc, step = step, total = count, times = 0}
		ms = step
	else
		tval = fnc
	end
	while true do
		uniquetid = uniquetid + 1
		if tpool[uniquetid] == nil then
			tpool[uniquetid] = tval
			break
		end
	end
	if rtos.timer_start(uniquetid,ms) ~= 1 then print("rtos.timer_start error") return end
	if arg.n ~= 0 then
		para[uniquetid] = arg
	end
	return uniquetid
end

function timer_loop_start(fnc,ms,...)
	local tid = timer_start(fnc,ms,unpack(arg))
	if tid then loop[tid] = ms end
	return tid
end

function timer_stop(val,...)
	if type(val) == "number" then
		tpool[val],para[val],loop[val] = nil
	else
		for k,v in pairs(tpool) do
			if type(v) == "table" and v.cb == val or v == val then
				if comp_table(arg,para[k])then
					rtos.timer_stop(k)
					tpool[k],para[k],loop[k] = nil
					break
				end
			end
		end
	end
end

function timer_stop_all(fnc)
	for k,v in pairs(tpool) do
		if type(v) == "table" and v.cb == fnc or v == fnc then
			rtos.timer_stop(k)
			tpool[k],para[k],loop[k] = nil
		end
	end
end

function timer_is_active(val,...)
	if type(val) == "number" then
		return tpool[val] ~= nil
	else
		for k,v in pairs(tpool) do
			if type(v) == "table" and v.cb == val or v == val then
				if comp_table(arg,para[k]) then
					return true
				end
			end
		end
		return false
	end
end

local function readtxt(f)
	local file,rt = io.open(f,"r")
	if not file then print("sys.readtxt no open",f) return "" end
	rt = file:read("*a")
	file:close()
	return rt
end

local function writetxt(f,v)
	local file = io.open(f,"w")
	if not file then print("sys.writetxt no open",f) return end	
	file:write(v)
	file:close()
end

local function appenderr(s)
	liberr = liberr..s
	writetxt(LIB_ERR_FILE,liberr)	
end

local function initerr()
	liberr = readtxt(LIB_ERR_FILE) or ""
	print("sys.initerr",liberr)
	liberr = ""
	os.remove(LIB_ERR_FILE)
end

function restart(r)
	assert(r and r ~= "","sys.restart cause null")
	appenderr("restart["..r.."];")
	rtos.restart()
end

-- 初始化
function init(mode,lprfnc)
	assert(base.PROJECT and base.PROJECT ~= "" and base.VERSION and base.VERSION ~= "","Undefine PROJECT or VERSION")
	uart.setup(uart.ATC,0,0,uart.PAR_NONE,uart.STOP_1)
	print("poweron reason:",rtos.poweron_reason(),base.PROJECT,base.VERSION)
	-- 模式1:充电开机不启动gsm
	if mode == 1 then
		if rtos.poweron_reason() == rtos.POWERON_CHARGER then
			rtos.poweron(0)
		end
	end
	local f = io.open("/luaerrinfo.txt","r")
	if f then
		print(f:read("*a") or "")
		f:close()
	end
	lprfun = lprfnc
	initerr()
end

-- 启动gsm
function poweron()
	rtos.poweron(1)
end

--应用消息分发,消息通知
local apps = {}

-- 支持两种方式注册:
-- 1. app处理表
-- 2. 处理函数,id1,id2,...,idn
function regapp(...)
	local app = arg[1]

	if type(app) == "table" then
	elseif type(app) == "function" then
		app = {procer = arg[1],unpack(arg,2,arg.n)}
	else
		error("unknown app type "..type(app),2)
	end
	dispatch("SYS_ADD_APP",app)
	return app
end

function deregapp(id)
	dispatch("SYS_REMOVE_APP",id)
end

local function addapp(app)
	-- 插入尾部
	table.insert(apps,#apps+1,app)
end

local function removeapp(id)
	for k,v in ipairs(apps) do
		if type(id) == "function" then
			if v.procer == id then
				table.remove(apps,k)
				return
			end
		elseif v == id then
			table.remove(apps,k)
			return
		end
	end
end

local function callapp(msg)
	local id = msg[1]

	if id == "SYS_ADD_APP" then
		addapp(unpack(msg,2,#msg))
	elseif id == "SYS_REMOVE_APP" then
		removeapp(unpack(msg,2,#msg))
	else
		local app
		for i=#apps,1,-1 do
			app = apps[i]
			if app.procer then --函数注册方式的app,带id通知
				for _,v in ipairs(app) do
					if v == id then
						if app.procer(unpack(msg)) ~= true then
							return
						end
					end
				end
			elseif app[id] then -- 处理表方式的app,不带id通知
				if app[id](unpack(msg,2,#msg)) ~= true then
					return
				end
			end
		end
	end
end

--内部消息队列
local qmsg = {}

function dispatch(...)
	table.insert(qmsg,arg)
end

local function getmsg()
	if #qmsg == 0 then
		return nil
	end

	return table.remove(qmsg,1)
end

local refreshmsg = {"MMI_REFRESH_IND"}

local function runqmsg()
	local inmsg

	while true do
		inmsg = getmsg()
		if inmsg == nil then
			if refreshflag == true then
				refreshflag = false
				inmsg = refreshmsg
			else
				break
			end
		end

		callapp(inmsg)
	end
end

-- 消息处理
local handlers = {}
base.setmetatable(handlers,{__index = function() return function() end end,})

function regmsg(id,handler)
	handlers[id] = handler
end

local uartprocs = {}

function reguart(id,fnc)
	uartprocs[id] = fnc
end

function run()
	local msg,msgpara

	while true do
		runqmsg()

		msg,msgpara = rtos.receive(rtos.INF_TIMEOUT)

		if not lprfun and not lpring and type(msg) == "table" and msg.id == rtos.MSG_PMD and msg.level == 0 then
			lpring = true
			timer_start(rtos.poweroff,60000,"r1")
		end

		if type(msg) == "table" then
			if msg.id == rtos.MSG_TIMER then
				timerfnc(msg.timer_id)
			elseif msg.id == rtos.MSG_UART_RXDATA and msg.uart_id == uart.ATC then
				handlers.atc()
			else -- 通过消息id注册
				if msg.id == rtos.MSG_UART_RXDATA then
					if uartprocs[msg.uart_id] ~= nil then
						uartprocs[msg.uart_id]()
					else
						handlers[msg.id](msg)
					end
				else
					handlers[msg.id](msg)
				end
			end
		else
			if msg == rtos.MSG_TIMER then
				timerfnc(msgpara)
			elseif msg == rtos.MSG_UART_RXDATA then
				if msgpara == uart.ATC then
					handlers.atc()
				else
					if uartprocs[msgpara] ~= nil then
						uartprocs[msgpara]()
					else
						handlers[msg](msg,msgpara)
					end
				end
			end
		end
		--print("mem:",base.collectgarbage("count"))
	end
end
