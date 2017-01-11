local base = _G
local table = require"table"
local rtos = require"rtos"
local sys = require"sys"
local string = require"string"
local link = require"link"
local gps = require"gps"
module("agps")

local print = base.print
local tonumber = base.tonumber
local fly = base.fly
local sfind = string.find
local slen = string.len
local ssub = string.sub
local sbyte = string.byte
local sformat = string.format
local send = link.send
local dispatch = sys.dispatch

local lid,isfix
local ispt,itv,PROT,SVR,PORT,WRITE_INTERVAL = true,(2*3600),"UDP","zx1.clouddatasrv.com",8072,400
local mode,pwrcb = 0
local gpssupport,eph = true,""
local GET_TIMEOUT,ERROR_PACK_TIMEOUT,GET_RETRY_TIMES,PACKET_LEN,RETRY_TIMES = 10000,5000,3,1024,3
local state,total,last,checksum,packid,getretries,retries,reconnect = "IDLE",0,0,{},0,0,1,false

local function startupdatetimer()
	if gpssupport and ispt then
		sys.timer_start(connect,itv*1000)
	end
end

local function gpsstateind(id,data)
	if data == gps.GPS_LOCATION_SUC_EVT or data == gps.GPS_LOCATION_UNFILTER_SUC_EVT then
		sys.dispatch("AGPS_UPDATE_SUC")
		startupdatetimer()
		isfix = true
	elseif data == gps.GPS_LOCATION_FAIL_EVT or data == gps.GPS_CLOSE_EVT then
		isfix = false
	elseif data == gps.GPS_NO_CHIP_EVT then
		gpssupport = false
	end
	return true
end

local function writecmd()
	if eph and slen(eph) > 0 and not isfix then
		local h1,h2 = sfind(eph,"\181\98")
		if h1 and h2 then
			local id = ssub(eph,h2+1,h2+2)
			if id and slen(id) == 2 then
				local llow,lhigh = sbyte(eph,h2+3),sbyte(eph,h2+4)
				if lhigh and llow then
					local length = lhigh*256 + llow
					print("length",h2+6+length,slen(eph))
					if h2+6+length <= slen(eph) then
						gps.writegpscmd(false,ssub(eph,h1,h2+6+length),false)
						eph = ssub(eph,h2+7+length,-1)
						sys.timer_start(writecmd,WRITE_INTERVAL)
						return
					end
				end
			end
		end
	end
	gps.closegps("AGPS")
	eph = ""
	sys.dispatch("AGPS_UPDATE_SUC")
end

local function startwrite()
	if isfix or not gpssupport then
		eph = ""
		return
	end
	if eph and slen(eph) > 0 then
		gps.opengps("AGPS")
		sys.timer_start(writecmd,WRITE_INTERVAL)
	end
end

local function calsum(str)
	local sum,i = 0
	for i=1,slen(str) do
		sum = sum + sbyte(str,i)
	end
	return sum
end

local function errpack()
	print("errpack")
	upend(false)
end

function retry(para)
	if state ~= "UPDATE" and state ~= "CHECK" then
		return
	end

	if para == "STOP" then
		getretries = 0
		sys.timer_stop(errpack)
		sys.timer_stop(retry)
		return
	end

	if para == "ERROR_PACK" then
		sys.timer_start(errpack,ERROR_PACK_TIMEOUT)
		return
	end

	getretries = getretries + 1
	if getretries < GET_RETRY_TIMES then
		if state == "UPDATE" then
			-- 未达重试次数,继续尝试获取升级包
			reqget(packid)
		else
			reqcheck()
		end
	else
		-- 超过重试次数,升级失败
		upend(false)
	end
end

function reqget(idx)
	send(lid,sformat("Get%d",idx))
	sys.timer_start(retry,GET_TIMEOUT)
end

local function getpack(data)
	-- 判断包长度是否正确
	local len = slen(data)
	if (packid < total and len ~= PACKET_LEN) or (packid >= total and len ~= (last+2)) then
		print("getpack:len not match",packid,len,last)
		retry("ERROR_PACK")
		return
	end

	-- 判断包序号是否正确
	local id = sbyte(data,1)*256 + sbyte(data,2)%256
	if id ~= packid then
		print("getpack:packid not match",id,packid)
		retry("ERROR_PACK")
		return
	end

	--判断校验和是否正确
	local sum = calsum(ssub(data,3,-1))
	if checksum[id] ~= sum then
		print("getpack:checksum not match",checksum[id],sum)
		retry("ERROR_PACK")
		return
	end

	-- 停止重试
	retry("STOP")

	-- 保存星历包
	eph = eph .. ssub(data,3,-1)

	-- 获取下一包数据
	if packid == total then
		sum = calsum(eph)
		if checksum[total+1] ~= sum then
			print("getpack:total checksum not match",checksum[total+1],sum)
			upend(false)
		else
			upend(true)
		end
	else
		packid = packid + 1
		reqget(packid)
	end
end

local function upbegin(data)
	local d1,d2,p1,p2 = sfind(data,"AGPSUPDATE,(%d+),(%d+)")
	local i
	if d1 and d2 and p1 and p2 then
		p1,p2 = tonumber(p1),tonumber(p2)
		total,last = p1,p2
		local tmpdata = data
		for i=1,total+1 do
			if d2+2 > slen(tmpdata) then
				upend(false)
				return false
			end
			tmpdata = ssub(tmpdata,d2+2,-1)
			d1,d2,p1 = sfind(tmpdata,"(%d+)")
			if d1 == nil or d2 == nil or p1 == nil then
				upend(false)
				return false
			end
			checksum[i] = tonumber(p1)
		end

		getretries,state,packid,eph = 0,"UPDATE",1,""
		reqget(packid)
		return true
	end

	upend(false)
	return false
end

function reqcheck()
	state = "CHECK"
	send(lid,"AGPS")
	sys.timer_start(retry,GET_TIMEOUT)
end

function upend(succ)
	state = "IDLE"
	-- 停止充实定时器
	sys.timer_stop(retry)
	sys.timer_stop(errpack)
	-- 断开链接
	link.close(lid)
	getretries = 0
	if succ then
		reconnect = false
		retries = 0
		--写星历信息到GPS芯片
		print("eph rcv",slen(eph))
		startwrite()
		startupdatetimer()
		if mode==1 then dispatch("AGPS_EVT","END_IND",true) end
	else
		if retries >= RETRY_TIMES then
			reconnect = false
			retries = 0
			startupdatetimer()
			if mode==1 then dispatch("AGPS_EVT","END_IND",false) end
		else
			reconnect = true
			retries = retries + 1
		end
	end
end

local function rcv(id,data)
	base.collectgarbage()
	sys.timer_stop(retry)
	if isfix or not gpssupport then
		upend(true)
		return
	end
	if state == "CHECK" then
		if sfind(data,"AGPSUPDATE") == 1 then
			upbegin(data)
			return
		end
	elseif state == "UPDATE" then
		if data ~= "ERR" then
			getpack(data)
			return
		end
	end

	upend(false)
	return
end

local function nofity(id,evt,val)
	print("agps notify",lid,id,evt,val,reconnect)
	if id ~= lid then return end
	if isfix or not gpssupport then
		upend(true)
		return
	end
	if evt == "CONNECT" then
		if val == "CONNECT OK" then
			reqcheck()
		else
			upend(false)
		end
	elseif evt == "CLOSE" and reconnect then
		connect()
	elseif evt == "STATE" and val == "CLOSED" then
		upend(false)
	end
end

local function flycb()
	retries = RETRY_TIMES
	upend(false)
end

local function connectcb()
	lid = link.open(nofity,rcv)
	link.connect(lid,PROT,SVR,PORT)
end

function connect()
	if ispt then
		if mode==0 then
			connectcb()
		else
			dispatch("AGPS_EVT","BEGIN_IND",connectcb)
		end		
	end
end

function init(inv,md)
	itv = inv or itv
	mode = md or 0
	startupdatetimer()
end

function setspt(spt)
	if spt ~= nil and ispt ~= spt then
		ispt = spt
		if spt then
			startupdatetimer()
		end
	end
end

local function load(force)
	local pwrstat = pwrcb and pwrcb()
	if (rtos.poweron_reason() == rtos.POWERON_KEY or rtos.poweron_reason() == rtos.POWERON_CHARGER or pwrstat) and (gps.isagpspwronupd() or force) then
		connect()
	else
		startupdatetimer()
	end
end

function setpwrcb(cb)
	pwrcb = cb
	load(true)
end

sys.regapp(gpsstateind,gps.GPS_STATE_IND)
load()
if fly then fly.setcb(flycb) end
