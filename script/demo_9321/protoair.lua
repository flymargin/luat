require"logger"
local lpack = require"pack"
module(...,package.seeall)

local slen,sbyte,ssub,sgsub,schar,srep,smatch,sgmatch = string.len,string.byte,string.sub,string.gsub,string.char,string.rep,string.match,string.gmatch

GPS,LBS1,LBS2,HEART,LBS3,GPSLBS,GPSLBS1,GPSLBSWIFIEXT,GPSLBSWIFI,RPTPARA,SETPARARSP,DEVEVENTRSP,GPSLBSWIFI1,INFO = 1,2,3,4,5,6,7,8,9,10,11,12,13,14
RPTFREQ,ALMFREQ,GUARDON,GUARDOFF,RELNUM,CALLVOL,CALLRINGVOL,CALLRINGMUTEON,CALLRINGMUTEOFF = 3,4,5,6,15,16,17,18,19
SILTIME,FIXTM,WHITENUM,FIXMOD,SMSFORBIDON,SMSFORBIDOFF,CALLRINGID,SOSIND,ENTERTAIN,ALARM = 20,21,22,23,24,25,26,27,28,29
SETPARA,SENDSMS,DIAL,QRYLOC,RESET,MONIT,POWEROFF,RESTORE,PROMPT,QRYPARA = 10,0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x50
VER = 0
FIXTIMEPOS,QRYPOS = 0,1

local PROTOVERSION = 0
local serial = 0
local imei -- 命令头包含IMEI,在第一次获取以后做缓存
local log = logger.new("PROTOAIR","BIN2")
local get

local function print(...)
	_G.print("protoair",...)
end

function bcd(d,n)
	local l = slen(d or "")
	local num
	local t = {}

	for i=1,l,2 do
		num = tonumber(ssub(d,i,i+1),16)

		if i == l then
			num = 0xf0+num
		else
			num = (num%0x10)*0x10 + num/0x10
		end

		table.insert(t,num)
	end

	local s = schar(_G.unpack(t))

	l = slen(s)

	if l < n then
		s = s .. srep("\255",n-l)
	elseif l > n then
		s = ssub(s,1,n)
	end

	return s
end

local function unbcd(d)
	local byte,v1,v2
	local t = {}

	for i=1,slen(d) do
		byte = sbyte(d,i)
		v1,v2 = bit.band(byte,0x0f),bit.band(bit.rshift(byte,4),0x0f)

		if v1 == 0x0f then break end
		table.insert(t,v1)

		if v2 == 0x0f then break end
		table.insert(t,v2)
	end

	return table.concat(t)
end

local function enlnla(v,s)
	if not v then return common.hexstobins("FFFFFFFFFF") end
	
	local v1,v2 = smatch(s,"(%d+)%.(%d+)")

	if slen(v1) < 3 then v1 = srep("0",3-slen(v1)) .. v1 end

	return bcd(v1..v2,5)
end

-- 基本状态信息封包处理
local function enstat()
	local stat = get("STATUS")
	local rssi = get("RSSI")
	local gpstat = get("GPSTAT")
	local satenum = gpstat.satenum

	-- 状态字节1
	local n1 = stat.shake + stat.charger*2 + stat.acc*4 + stat.gps*8 + stat.sleep*16
	-- 状态字节2
	rssi = rssi > 31 and 31 or rssi
	satenum = satenum > 7 and 7 or satenum
	local n2 = rssi + satenum*32

	return lpack.pack(">bbH",n1,n2,stat.volt)
end

local function encellinfo()
	local info,ret,t,lac,ci,rssi,k,v,m,n,cntrssi = get("CELLINFO"),"",{}
	print("encellinfo",info)
	for lac,ci,rssi in sgmatch(info,"(%d+)%.(%d+)%.(%d+);") do
		lac,ci,rssi = tonumber(lac),tonumber(ci),(tonumber(rssi) > 31) and 31 or tonumber(rssi)
		local handle = nil
		for k,v in pairs(t) do
			if v.lac == lac then
				if #v.rssici < 8 then
					table.insert(v.rssici,{rssi=rssi,ci=ci})
				end
				handle = true
				break
			end
		end
		if not handle then
			table.insert(t,{lac=lac,rssici={{rssi=rssi,ci=ci}}})
		end
	end
	for k,v in pairs(t) do
		ret = ret .. lpack.pack(">H",v.lac)
		for m,n in pairs(v.rssici) do
			cntrssi = bit.bor(bit.lshift(((m == 1) and (#v.rssici-1) or 0),5),n.rssi)
			ret = ret .. lpack.pack(">bH",cntrssi,n.ci)
		end
	end

	return schar(#t)..ret
end

local function encellinfoext()
	local info,ret,t,mcc,mnc,lac,ci,rssi,k,v,m,n,cntrssi = get("CELLINFOEXT"),"",{}
	print("encellinfoext",info)
	for mcc,mnc,lac,ci,rssi in sgmatch(info,"(%d+)%.(%d+)%.(%d+)%.(%d+)%.(%d+);") do
		mcc,mnc,lac,ci,rssi = tonumber(mcc),tonumber(mnc),tonumber(lac),tonumber(ci),(tonumber(rssi) > 31) and 31 or tonumber(rssi)
		local handle = nil
		for k,v in pairs(t) do
			if v.lac == lac and v.mcc == mcc and v.mnc == mnc then
				if #v.rssici < 8 then
					table.insert(v.rssici,{rssi=rssi,ci=ci})
				end
				handle = true
				break
			end
		end
		if not handle then
			table.insert(t,{mcc=mcc,mnc=mnc,lac=lac,rssici={{rssi=rssi,ci=ci}}})
		end
	end
	for k,v in pairs(t) do
		ret = ret .. lpack.pack(">HHb",v.lac,v.mcc,v.mnc)
		for m,n in pairs(v.rssici) do
			cntrssi = bit.bor(bit.lshift(((m == 1) and (#v.rssici-1) or 0),5),n.rssi)
			ret = ret .. lpack.pack(">bH",cntrssi,n.ci)
		end
	end

	return schar(#t)..ret
end

local function enwifi(p)
	local t,ret,i,mac,rssi = p or {},""
	for i=1,#t do
		mac,rssi = common.hexstobins(sgsub(t[i].mac,":","")),schar(255+tonumber(t[i].rssi))
		if mac and rssi then
			ret = ret..mac..rssi
		end
	end
	return schar(#t)..ret
end

function pack(id,...)
	if not imei then imei = bcd(get("IMEI"),8) end

	local head = schar(id)

	local function gps()
		local t = get("GPS")
		lng = enlnla(t.fix,t.lng)
		lat = enlnla(t.fix,t.lat)

		return lpack.pack(">AAHbA",lng,lat,t.cog,t.spd,enstat())
	end

	local function lbs1()
		local ci,lac = get("CELLID"),get("LAC")
		return lpack.pack(">HbIHA",get("MCC"),get("MNC"),ci,lac,enstat())
	end

	local function lbs3()
		return lpack.pack(">AbA",encellinfoext(),get("TA"),enstat())
	end
	
	local function lbs2()
		return lpack.pack(">HbAbA",get("MCC"),get("MNC"),encellinfo(),get("TA"),enstat())
	end
	
	local function gpslbs()
		local t = get("GPS")
		lng = enlnla(t.fix,t.lng)
		lat = enlnla(t.fix,t.lat)
		return lpack.pack(">AAHbHbAbA",lng,lat,t.cog,t.spd,get("MCC"),get("MNC"),encellinfo(),get("TA"),enstat())
	end
	
	local function gpslbs1()
		local t = get("GPS")
		lng = enlnla(t.fix,t.lng)
		lat = enlnla(t.fix,t.lat)
		return lpack.pack(">AAHbAbA",lng,lat,t.cog,t.spd,encellinfoext(),get("TA"),enstat())
	end
	
	local function gpslbswifi(p)
		local t = get("GPS")
		lng = enlnla(t.fix,t.lng)
		lat = enlnla(t.fix,t.lat)
		return lpack.pack(">AAHbHbAbAA",lng,lat,t.cog,t.spd,get("MCC"),get("MNC"),encellinfo(),get("TA"),enwifi(p),enstat())
	end
	
	local function gpslbswifi1(p)
		local t = get("GPS")
		lng = enlnla(t.fix,t.lng)
		lat = enlnla(t.fix,t.lat)
		return lpack.pack(">AAHbAbAA",lng,lat,t.cog,t.spd,encellinfoext(),get("TA"),enwifi(p),enstat())
	end
	
	local function gpslbswifiext(w,typ)
		local t = get("GPS")
		lng = enlnla(t.fix,t.lng)
		lat = enlnla(t.fix,t.lat)
		return lpack.pack(">bAAHbAbAA",typ,lng,lat,t.cog,t.spd,encellinfoext(),get("TA"),enwifi(w),enstat())
	end

	local function heart()
		return lpack.pack("A",enstat())
	end	
	
	local function rptpara(dat)
		return dat or ""
	end
	
	local function rsp(typ,result)
		return lpack.pack("bA",typ,result)
	end
	
	local function info()
		return lpack.pack(">bHHbHHbHA",0,2,get("PROJECT"),1,2,get("HEART"),2,2,bcd(sgsub(get("VERSION"),"%.",""),2))
	end
	
	local procer = {
		[GPS] = gps,
		[LBS1] = lbs1,
		[LBS2] = lbs2,
		[LBS3] = lbs3,
		[GPSLBS] = gpslbs,
		[GPSLBS1] = gpslbs1,
		[GPSLBSWIFIEXT] = gpslbswifiext,
		[GPSLBSWIFI] = gpslbswifi,
		[GPSLBSWIFI1] = gpslbswifi1,
		[HEART] = heart,
		[RPTPARA] = rptpara,
		[SETPARARSP] = rsp,
		[DEVEVENTRSP] = rsp,
		[INFO] = info,
	}	

	local s = head .. procer[id](...)
	print("pack",id,common.binstohexs(s))
	return s
end

function unpack(s)
	local packet = {}	
	
	local function setpara(d)
		if slen(d) > 0 then			
			
			local function unsignshort(m)
				if slen(m) ~= 2 then return end
				_,packet.val = lpack.unpack(m,">H")
				return true
			end
			
			local function empty(m)
				return m==""
			end
			
			local function numlist(m)
				if m == "" then return end
				packet.val = {}
				local i = 1
				while i < slen(m) do
					if i+1 > slen(m) then return end
					if i+1+sbyte(m,i+1) > slen(m) then return end
					packet.val[sbyte(m,i)] = (sbyte(m,i+1)==0 and "" or unbcd(ssub(m,i+2,i+1+sbyte(m,i+1))))					
					i = i+2+sbyte(m,i+1)
				end
				return true
			end
			
			local function unsignchar(m)
				if slen(m) ~= 1 then return end
				packet.val = sbyte(m)
				return true
			end
			
			local function listunsignchar(m)
				if m == "" then return end
				packet.val = {}
				local i = 1
				while i < slen(m) do
					if i+1 > slen(m) then return end					
					packet.val[sbyte(m,i)] = sbyte(m,i+1)
					i = i+2					
				end
				return true
			end
			
			local function timesect(m)
				if m == "" then return end
				packet.val = {}
				local i,tmp,j = 1
				while i < slen(m) do
					if i+5 > slen(m) then return end
					local flg = sbyte(m,i+1)
					tmp = ""
					for j=1,7 do
						tmp = tmp..(bit.band(flg,2^j)==0 and "0" or "1")
					end
					tmp = tmp.."!"..string.format("%02d%02d%02d%02d",sbyte(m,i+2),sbyte(m,i+3),sbyte(m,i+4),sbyte(m,i+5))
					packet.val[sbyte(m,i)] = tmp
					i = i+6					
				end
				return true
			end
			
			local function alarm(m)
				if m == "" then return end
				packet.val = {}
				local i,tmp,j = 1
				while i < slen(m) do
					if i+3 > slen(m) then return end
					local flg = sbyte(m,i+1)
					tmp = ""
					for j=0,7 do
						tmp = tmp..(bit.band(flg,2^j)==0 and "0" or "1")
					end
					tmp = tmp.."!"..string.format("%02d%02d",sbyte(m,i+2),sbyte(m,i+3))
					packet.val[sbyte(m,i)] = tmp
					i = i+4
				end
				return true
			end
			
			local proc =
			{
				[RPTFREQ] = unsignshort,
				[ALMFREQ] = unsignshort,
				[GUARDON] = empty,
				[GUARDOFF] = empty,
				[RELNUM] = numlist,
				[CALLVOL] = unsignchar,
				[CALLRINGVOL] = listunsignchar,
				[CALLRINGMUTEON] = empty,
				[CALLRINGMUTEOFF] = empty,
				[SILTIME] = timesect,
				[FIXTM] = timesect,
				[WHITENUM] = numlist,
				[FIXMOD] = unsignchar,
				[SMSFORBIDON] = empty,
				[SMSFORBIDOFF] = empty,
				[CALLRINGID] = listunsignchar,
				[ENTERTAIN] = timesect,
				[ALARM] = alarm,
			}
			packet.cmd = sbyte(d)
			if not proc[sbyte(d)] then print("protoair.unpack:unknwon setpara",sbyte(d)) return end			
			return proc[sbyte(d)](ssub(d,2,-1)) and packet or nil
		end
	end
	
	local function sendsms(d)
		if d == "" then return end

		local numcnt,i = sbyte(d)
		if numcnt*6+1 >= slen(d) then return end
		packet.num = {}
		for i=1,numcnt do
			local n = unbcd(ssub(d,2+(i-1)*6,7+(i-1)*6))
			if n and slen(n) > 0 then
				table.insert(packet.num,n)
			end
		end

		local t = {"7BIT","UCS2"}
		local typ = sbyte(d,numcnt*6+2)+1
		if not t[typ] then return end
		packet.coding = t[typ]
		packet.data = ssub(d,numcnt*6+3,-1)
		if not packet.data or slen(packet.data) <= 0 then return end

		return true
	end

	local function dial(d)
		if d == "" then return end

		local numcnt,i = sbyte(d)
		if numcnt*6 >= slen(d) then return end
		packet.num = {}
		for i=1,numcnt do
			local n = unbcd(ssub(d,2+(i-1)*6,7+(i-1)*6))
			if n and slen(n) > 0 then
				table.insert(packet.num,n)
			end
		end
		return true
	end
	
	local function empty(d)
		return d==""
	end
	
	local function prompt(d)
		if d == "" then return end
		packet.data = d
		return true
	end
	
	local function qrypara(d)
		if d == "" then return end
		packet.val = sbyte(d)
		return true
	end
	
	local procer = {
		[SETPARA] = setpara,
		[SENDSMS] = sendsms,
		[DIAL] = dial,
		[QRYLOC] = empty,
		[RESET] = empty,
		[MONIT] = dial,
		[POWEROFF] = empty,
		[RESTORE] = empty,
		[PROMPT] = prompt,
		[QRYPARA] = qrypara,
	}	
	local id = sbyte(s,1)
	if not procer[id] then print("protoair.unpack:unknwon id",id) return end
	packet.id = id
	print("unpack",id,common.binstohexs(s))
	return procer[id](ssub(s,2,-1)) and packet or nil
end

function reget(id)
	get = id
end
