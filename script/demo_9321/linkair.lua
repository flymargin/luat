module(...,package.seeall)

require"protoair"
require"sms"
require"dbg"
require"ccair"

local ssub,schar,smatch = string.sub,string.char,string.match
local SCK_IDX,KEEP_ALIVE_TIME = 1,300
local rests,shkcnt = "",0
local locshk,firstloc,firstgps = "SIL"
local chgalm,shkalm,accalm = true,true,true
local verno,mqttconnfailcnt,mqttconn = 1,0

local function print(...)
	_G.print("linkair",...)
end

local function getstatus()
	local t = {}

	t.shake = (shkcnt > 0) and 1 or 0
	shkcnt = 0
	t.charger = chg.getcharger() and 1 or 0
	t.acc = acc.getflag() and 1 or 0
	t.gps = gps.isopen() and 1 or 0
	t.sleep = pm.isleep() and 1 or 0
	t.volt = chg.getvolt()

	return t
end

local function getgps()
	local t = {}
	print("getgps:",gps.getgpslocation(),gps.getgpscog(),gps.getgpsspd())
	t.fix = gps.isfix()
	t.lng,t.lat = smatch(gps.getgpslocation(),"[EW]*,(%d+%.%d+),[NS]*,(%d+%.%d+)")
	t.lng,t.lat = t.lng or "",t.lat or ""
	t.cog = gps.getgpscog()
	t.spd = gps.getgpsspd()

	return t
end

local function getgpstat()
	local t = {}
	t.satenum = gps.getgpssatenum()
	return t
end

local function getfncpara()
	local n1 = (manage.GUARDFNC and 1 or 0) + (manage.HANDLEPWRFNC and 1 or 0)*2 + (manage.MOTORPWRFNC and 1 or 0)*4 + (manage.RMTPWRFNC and 1 or 0)*8
	n1 = n1 + (manage.BUZZERFNC and 1 or 0)*16
	local n2,n3,n4,n5,n6,n7,n8 = 0,0,0,0,0,0,0
	return pack.pack("bbbbbbbb",n1,n2,n3,n4,n5,n6,n7,n8)
end

local tget = {
	["VERSION"] = function() return _G.VERSION end,
	PROJECT = function() return 7 end,
	HEART = function() return nvm.get("heart") end,
	IMEI = misc.getimei,
	IMSI = sim.getimsi,
	ICCID = sim.geticcid,
	RSSI = net.getrssi,
	MNC = function() return tonumber(net.getmnc()) end,
	MCC = function() return tonumber(net.getmcc()) end,
	CELLID = function() return tonumber(net.getci(),16) end,
	LAC = function() return tonumber(net.getlac(),16) end,
	CELLINFO = net.getcellinfo,
	CELLINFOEXT = net.getcellinfoext,
	TA = net.getta,
	STATUS = getstatus,
	GPS = getgps,
	GPSTAT = getgpstat,
	FNCPARA = getfncpara,
}
local function getf(id)
	assert(tget[id] ~= nil,"getf nil id:" .. id)
	return tget[id]()
end

protoair.reget(getf)

local levt,lval,lerrevt,lerrval = "","","",""

local function datinactive()
	dbg.restart("AIRNODATA" .. ((levt ~= nil) and (",EVT=" .. levt) or "") .. ((lval ~= nil) and (",VAL=" .. lval) or "").. ((lerrevt ~= nil) and (",ERREVT=" .. lerrevt) or "") .. ((lerrval ~= nil) and (",ERRVAL=" .. lerrval) or ""))
	mqttconnfailcnt = 0
end

local function checkdatactive()
	sys.timer_start(datinactive,KEEP_ALIVE_TIME*1000*3+30000) --3±¶ÐÄÌø+°ë·ÖÖÓ
end

local function snd(data,para,pos,ins)
	return linkapp.scksnd(SCK_IDX,data,para,pos,ins)
end

local function chgalmrpt()
	if nvm.get("guard") and not chg.getcharger() and chgalm then
		chgalm = false
		sys.dispatch("ALM_IND","CHG")
		heart()
		startalmtimer("CHG",true)
	end
end

local function shkalmrpt()
	print("shkalmrpt",nvm.get("guard"),shkalm)
	if nvm.get("guard") and shkalm then
		shkalm = false
		sys.dispatch("ALM_IND","SHK")
		heart()
		startalmtimer("SHK",true)
	end
end

local function accalmrpt()
	if nvm.get("guard") and acc.getflag() and accalm then
		accalm = false
		sys.dispatch("ALM_IND","ACC")
		heart()
		startalmtimer("ACC",true)
	end
end

function almtimerfnc(tag)
	print("almtimerfnc",tag)
	local val = nvm.get("guard")
	if tag == "CHG" then
		chgalm = val
		chgalmrpt()
	elseif tag == "SHK" then
		shkalm = val
	elseif tag == "ACC" then
		accalm = val
		accalmrpt()
	end
end

function startalmtimer(tag,val)
	print("startalmtimer",tag,val,nvm.get("guard"))
	if nvm.get("guard") then
		if val then
			sys.timer_start(almtimerfnc,nvm.get("almfreq")*60000+5000,tag)
		end
	end
end

local function stopalmtimer(tag)
	print("stopalmtimer",tag)
	sys.timer_stop(almtimerfnc,tag)
end

local function alminit()
	print("alminit",nvm.get("guard"))
	local val = nvm.get("guard")
	chgalm,shkalm,accalm = val,val,val
	stopalmtimer("CHG")
	stopalmtimer("SHK")
	stopalmtimer("ACC")
end

local function qrylocfnc()
	locrpt("QRYLOC")
end

local function preloc()
	print("preloc",locshk)
	if locshk == "SHK" then
		local mod = nvm.get("fixmod")
		if mod == "LBS" then
			loc()
		elseif mod == "GPS" then
			--gpsapp.open(gpsapp.TIMERORSUC,{cause="TIMERLOC",val=120,cb=loc})
			loc()
		end
	end
end

local function loctimerfnc()
	print("loctimerfnc",locshk)
	if locshk == "SIL" then	locshk = "TMOUT" end
	preloc()
end

function startloctimer()
	print("startloctimer")
	sys.timer_start(loctimerfnc,nvm.get("rptfreq")*1000)
end

local function entopic(t)
	return "/v"..verno.."/device/"..tget["IMEI"]().."/"..t
end

local function starthearttimer()
	sys.timer_start(heart,nvm.get("heart")*1000)
end

function locrpt(r,w)
	if not mqttconn then return end
	local id,mod,extyp = protoair.LBS3,r or nvm.get("fixmod")
	if mod == "LBS" then
		id = nvm.get("lbstyp")==1 and protoair.LBS1 or protoair.LBS3
	elseif mod == "GPS" then
		id = gps.isfix() and (nvm.get("gpslbsmix") and protoair.GPSLBS1 or protoair.GPS) or (nvm.get("lbstyp")==1 and protoair.LBS1 or (nvm.get("gpslbsmix") and protoair.GPSLBS1 or protoair.LBS3))
	elseif mod == "QRYLOC" then
		id = protoair.GPSLBSWIFIEXT
		extyp = protoair.QRYPOS
	end	
	print("locrpt",id,w)
	local p = {}
	p.lbs1 = tget["LAC"]().."@"..tget["CELLID"]()
	p.lbs2 = tget["CELLINFOEXT"]()
	p.gpsfix = getgps().fix
	p.gps = getgps().lng.."@"..getgps().lat
	return snd(mqtt.pack(mqtt.PUBLISH,{topic=entopic("devdata"),payload=protoair.pack(id,w,extyp)}),{typ="MQTTPUBLOC",val={typ=id,para=p}})
end

function loc(r,p)
	print("loc",gps.isfix(),r)
	startloctimer()
	if gps.isfix() then
		local t = getgps()
		if manage.isgpsmove(t.lng,t.lat) then
			return locrpt(nil,p)
		else
			locshk = "SIL"
		end
	else
		if nvm.get("lbstyp")==1 and manage.islbs1move(tostring(tget["LAC"]()),tostring(tget["CELLID"]())) then
			return locrpt(nil,p)
		elseif nvm.get("lbstyp")==2 and manage.islbs2move(tget["CELLINFOEXT"]()) then
			return locrpt(nil,p)
		else
			locshk = "SIL"
		end
	end
end

function heart()
	starthearttimer()
	if not mqttconn then return end
	snd(mqtt.pack(mqtt.PUBLISH,{topic=entopic("devdata"),payload=protoair.pack(protoair.HEART)}),{typ="MQTTPUBHEART"})
end

local function disconnect()
	snd(mqtt.pack(mqtt.DISCONNECT),"MQTTDISC")
end

local function pingreq()
	snd(mqtt.pack(mqtt.PINGREQ))
	if not sys.timer_is_active(disconnect) then
		sys.timer_start(disconnect,(KEEP_ALIVE_TIME+30)*1000)
	end
end

local function enrptpara(typ)
	local function enunsignshort(p)
		return pack.pack(">H",nvm.get(p))
	end	
	
	local proc =
	{
		rptfreq = {k=protoair.RPTFREQ,v=enunsignshort},
		almfreq = {k=protoair.ALMFREQ,v=enunsignshort},
		guard = {v=function() return schar(nvm.get("guard") and protoair.GUARDON or protoair.GUARDOFF) end},		
		fixmod = {v=function() return pack.pack("bb",protoair.FIXMOD,(nvm.get("fixmod")=="LBS") and 0 or ((nvm.get("fixmod")=="GPS") and 1 or 2)) end},		
	}
	if not proc[typ] then return "" end
	local ret = ""
	if proc[typ].k then ret = schar(proc[typ].k) end
	if proc[typ].v then ret = ret..proc[typ].v(typ) end
	return ret
end

local tpara,tparapend =
{
	"rptfreq","almfreq","guard","fixmod"
},{}

local function rptpara(typ)
	print("rptpara",typ,tget["IMEI"](),#tparapend)
	if typ then
		if tget["IMEI"]() ~= "" then
			for k,v in pairs(tpara) do
				if typ == v then
					mqttdup.rmv("PUBRPTPARA"..v)
					local dat,para = mqtt.pack(mqtt.PUBLISH,{qos=1,topic=entopic("devpararpt"),payload=protoair.pack(protoair.RPTPARA,enrptpara(v))})
					para.usr = v
					if not snd(dat,{typ="MQTTPUBRPTPARA",val=para},nil,true) then
						mqttpubrptparacb(para)
					else
						return true
					end
				end
			end
		else
			local fnd
			for i=1,#tparapend do
				if tparapend[i] == typ then fnd = true break end
			end
			if not fnd then
				for k,v in pairs(tpara) do
					if v == typ then tparapend[#tparapend+1] = typ end
				end
			end
		end
	else
		for i=1,#tparapend do
			rptpara(tparapend[i])
		end
		tparapend = {}
	end
end

local function connect(cause)
	linkapp.sckconn(SCK_IDX,cause,nvm.get("prot"),nvm.get("addr1"),nvm.get("port"),ntfy,rcv)
end

local reconntimes = 0
local function reconn()
	if reconntimes < 3 then
		reconntimes = reconntimes+1
		connect(linkapp.NORMAL)
	else
		reconntimes = 0
		sys.timer_start(reconn,300000)
	end
end

local function connack(packet)
	print("connack",packet.suc)
	if packet.suc then
		if not sys.timer_is_active(heart) then starthearttimer() end
		mqttconn = true
		mqttdup.rmv("CONN")
		mqttdup.rmv("SUB")
		local dat,para = mqtt.pack(mqtt.SUBSCRIBE,{topic={entopic("devparareq/+"),entopic("deveventreq/+")}})
		--print("connack",para.dup,common.binstohexs(para.seq))
		if not snd(dat,{typ="MQTTSUB",val=para}) then mqttsubcb(para) end
	else
		mqttconnfailcnt = mqttconnfailcnt + 1
	end
end

local function suback(packet)
	print("suback",common.binstohexs(packet.seq))
	mqttdup.rmv("SUB",nil,packet.seq)
	
	snd(mqtt.pack(mqtt.PUBLISH,{topic=entopic("devdata"),payload=protoair.pack(protoair.INFO)}),{typ="MQTTPUBINFO"})
	
	if firstloc then
		preloc()
	else
		loc()
	end	
end

local function puback(packet)	
	local typ = mqttdup.getyp(packet.seq) or ""
	print("puback",common.binstohexs(packet.seq),typ)
	if typ == "PUBDEVEVENTRSP"..protoair.RESET then
		sys.timer_start(dbg.restart,1000,"AIRTCPSVR")
	end
	mqttdup.rmv(nil,nil,packet.seq)
end

local function fixmodpara(p)
	return nvm.set("fixmod",p.val==0 and "LBS" or (p.val==1 and "GPS" or "GPSWIFI"),"SVR")
end

local function setpara(packet)	
	local procer,result = {
		[protoair.RPTFREQ] = "rptfreq",
		[protoair.ALMFREQ] = "almfreq",		
		[protoair.GUARDON] = {k="guard",v=true},
		[protoair.GUARDOFF] = {k="guard",v=false},		
		[protoair.FIXMOD] = fixmodpara,		
	}
	if procer[packet.cmd] then
		local typ = type(procer[packet.cmd])
		if typ == "function" then
			result = procer[packet.cmd](packet)
		elseif typ == "table" then
			if type(procer[packet.cmd].k) == "function" then
				result = procer[packet.cmd].k(packet,procer[packet.cmd].v)
			else
				result = nvm.set(procer[packet.cmd].k,procer[packet.cmd].v,"SVR")
			end
		else
			result = nvm.set(procer[packet.cmd],packet.val,"SVR")
		end		
	end
	mqttdup.rmv("PUBSETPARARSP"..packet.cmd)
	local dat,para = mqtt.pack(mqtt.PUBLISH,{qos=1,topic=entopic("devpararsp/"..(smatch(packet.topic,"devparareq/(.+)") or "")),payload=protoair.pack(protoair.SETPARARSP,packet.cmd,schar(result and 1 or 0))})
	para.usr = packet.cmd
	if not snd(dat,{typ="MQTTPUBSETPARARSP",val=para}) then mqttpubsetpararspcb(para) end
end

local function sendsms(packet)
	if packet.coding == "UCS2" then
		local num,i = ""
		for i=1,#packet.num do
			print("sendsms",packet.num[i])
			if string.len(packet.num[i]) >= 5 and not string.match(num,packet.num[i]) then
				num = num..packet.num[i].."@"
			end
		end
		print("sendsms1",num)
		for i in string.gmatch(num,"(%d+)@") do
			sms.send(i,common.binstohexs(packet.data))
		end		
	end
end

local function dial(packet)
	while #packet.num > 0 do
		sys.dispatch("CCAPP_ADD_NUM",table.remove(packet.num,1))
	end
	sys.dispatch("CCAPP_DIAL_NUM")
end

local function deveventrsp(packet)
	mqttdup.rmv("PUBDEVEVENTRSP"..packet.id)
	local dat,para = mqtt.pack(mqtt.PUBLISH,{qos=1,topic=entopic("deveventrsp/"..(smatch(packet.topic,"deveventreq/(.+)") or "")),payload=protoair.pack(protoair.DEVEVENTRSP,packet.id,schar(1))})
	para.usr = packet.id
	if not snd(dat,{typ="MQTTPUBDEVEVENTRSP",val=para}) then mqttpubdeveventrspcb(para) end
end

local function qryloc(packet)
	deveventrsp(packet)
	if not gpsapp.isactive(gpsapp.TIMERORSUC,{cause="QRYLOC"}) then
		gpsapp.open(gpsapp.TIMERORSUC,{cause="QRYLOC",val=120,cb=qrylocfnc})
	end
end

local function restore(packet)
	sys.dispatch("SVR_RESTORE_IND")
	deveventrsp(packet)
end

local function devqrypararsp(packet,rsp)
	mqttdup.rmv("PUBDEVEVENTRSP"..packet.id..packet.val)
	local dat,para = mqtt.pack(mqtt.PUBLISH,{qos=1,topic=entopic("deveventrsp/"..smatch(packet.topic,"deveventreq/(.+)")),payload=protoair.pack(protoair.DEVEVENTRSP,packet.id,schar(packet.val)..rsp)})
	para.usr = packet.id..packet.val
	if not snd(dat,{typ="MQTTPUBDEVEVENTRSP",val=para}) then mqttpubdeveventrspcb(para) end
end

local function qrypara(packet)
	local procer,rsp = {
		[protoair.VER] = function() return _G.PROJECT.."_".._G.VERSION end,
	}
	if procer[packet.val] then
		rsp = procer[packet.val]()
	end
	if rsp then devqrypararsp(packet,rsp) end
end

local cmds = {
	[protoair.SETPARA] = setpara,
	[protoair.SENDSMS] = sendsms,
	[protoair.DIAL] = dial,
	[protoair.QRYLOC] = qryloc,
	[protoair.RESET] = deveventrsp,	
	[protoair.RESTORE] = restore,
	[protoair.QRYPARA] = qrypara,
}

local function publish(mqttpacket)	
	local packet = protoair.unpack(mqttpacket.payload)
	if mqttpacket.qos == 1 then snd(mqtt.pack(mqtt.PUBACK,mqttpacket.seq)) end
	if packet and packet.id and cmds[packet.id] then
		packet.seq = mqttpacket.seq
		packet.topic = mqttpacket.topic
		cmds[packet.id](packet)
	end
end

local function pingrsp()
	sys.timer_stop(disconnect)
end

local mqttcmds = {
	[mqtt.CONNACK] = connack,
	[mqtt.SUBACK] = suback,
	[mqtt.PUBACK] = puback,
	[mqtt.PUBLISH] = publish,
	[mqtt.PINGRSP] = pingrsp,
}

local function mqttconncb(v)
	--print("mqttconncb",common.binstohexs(v))
	mqttdup.ins("CONN",v)
end

function mqttsubcb(v)
	mqttdup.ins("SUB",mqtt.pack(mqtt.SUBSCRIBE,v),v.seq)
end

local function mqttdupcb(v)
	mqttdup.rsm(v)
end

local function mqttdiscb()
	linkapp.sckdisc(SCK_IDX)
end

local function mqttpublocb(v,r)
	startloctimer()
	locshk = "SIL"
	if r then		
		starthearttimer()	
		firstloc = true
		
		local function lbs1cb()
			manage.setlastlbs1(smatch(v.para.lbs1,"(%d+)@"),smatch(v.para.lbs1,"@(%d+)"),true)
		end
		
		local function lbs2cb()
			manage.setlastlbs2(v.para.lbs2,true)
		end
		
		local function gpscb()
			manage.setlastgps(smatch(v.para.gps,"([%.%d]+)@"),smatch(v.para.gps,"@([%.%d]+)"))
			manage.setlastlbs1(smatch(v.para.lbs1,"(%d+)@"),smatch(v.para.lbs1,"@(%d+)"))
			manage.setlastlbs2(v.para.lbs2)
		end
		
		local function gpslbscb()
			if v.para.gpsfix then manage.setlastgps(smatch(v.para.gps,"([%.%d]+)@"),smatch(v.para.gps,"@([%.%d]+)")) end
			manage.setlastlbs2(v.para.lbs2,not v.para.gpsfix)
		end
		
		local function gpslbswificb()
			if v.para.gpsfix then manage.setlastgps(smatch(v.para.gps,"([%.%d]+)@"),smatch(v.para.gps,"@([%.%d]+)")) end
			if v.para.wifi and #v.para.wifi > 0 then
				manage.setlastwifi(v.para.wifi)
				manage.setlastwifictl(v.para.wifi)
			end
			manage.setlastlbs2(v.para.lbs2,not (v.para.gpsfix or (v.para.wifi and #v.para.wifi > 0)))
		end
		
		local procer =
		{
			[protoair.LBS1] = lbs1cb,
			[protoair.LBS2] = lbs2cb,
			[protoair.LBS3] = lbs2cb,
			[protoair.GPS] = gpscb,
			[protoair.GPSLBS] = gpslbscb,
			[protoair.GPSLBS1] = gpslbscb,
			[protoair.GPSLBSWIFIEXT] = gpslbswificb,
		}
		if procer[v.typ] then procer[v.typ]() end
	end
end

local function mqttpubheartcb(v,r)
	if r then starthearttimer() end
end

function mqttpubrptparacb(v)
	print("mqttpubrptparacb",v.usr)
	mqttdup.ins("PUBRPTPARA"..v.usr,mqtt.pack(mqtt.PUBLISH,v),v.seq)
end

function mqttpubsetpararspcb(v)
	print("mqttpubsetpararspcb",v.usr)
	mqttdup.ins("PUBSETPARARSP"..v.usr,mqtt.pack(mqtt.PUBLISH,v),v.seq)
end

function mqttpubdeveventrspcb(v)
	print("mqttpubdeveventrspcb",v.usr)
	mqttdup.ins("PUBDEVEVENTRSP"..v.usr,mqtt.pack(mqtt.PUBLISH,v),v.seq)
end

local sndcbs =
{
	MQTTCONN = mqttconncb,
	MQTTSUB = mqttsubcb,
	MQTTDUP = mqttdupcb,
	MQTTDISC = mqttdiscb,
	MQTTPUBLOC = mqttpublocb,
	MQTTPUBHEART = mqttpubheartcb,
	MQTTPUBRPTPARA = mqttpubrptparacb,
	MQTTPUBSETPARARSP = mqttpubsetpararspcb,
	MQTTPUBDEVEVENTRSP = mqttpubdeveventrspcb,
}

local function enpwd(s)
	local tmp,ret,i = 0,""
	for i=1,string.len(s) do
		tmp = bit.bxor(tmp,string.byte(s,i))
		if i % 3 == 0 then
			ret = ret..schar(tmp)
			tmp = 0
		end
	end
	return common.binstohexs(ret)
end

function ntfy(idx,evt,result,item)
	print("ntfy",evt,result)
	if evt == "CONNECT" then
		if result then
			sys.timer_stop(reconn)
			reconntimes = 0
			rests = ""
			
			local dat = mqtt.pack(mqtt.CONNECT,KEEP_ALIVE_TIME,tget["IMEI"](),tget["IMEI"](),enpwd(tget["IMEI"]()))
			mqttdup.rmv("CONN")
			if not snd(dat,"MQTTCONN") then mqttconncb(dat) end						
		else
			sys.timer_start(reconn,5000)
		end
	elseif evt == "STATE" and result == "CLOSED" or evt == "DISCONNECT" then
		if mqttconnfailcnt <= 3 then sys.timer_start(reconn,5000) end
		sys.timer_stop(pingreq)
		mqttdup.rmvall()
		mqttconn = false
	elseif evt == "SEND" then
		if item.para then
			local typ = type(item.para) == "table" and item.para.typ or item.para
			local val = type(item.para) == "table" and item.para.val or item.data
			if sndcbs[typ] then sndcbs[typ](val,result)	end
		end
	end

	if smatch((type(result)=="string") and result or "","ERROR") then
		linkapp.sckdisc(SCK_IDX)
	end
end

function rcv(id,data)
	print("rcv",common.binstohexs(data))
	sys.timer_start(pingreq,KEEP_ALIVE_TIME*1000/2)	
	rests = rests..data

	local f,h,t = mqtt.iscomplete(rests)

	while f do
		data = ssub(rests,h,t)
		rests = ssub(rests,t+1,-1)
		local packet = mqtt.unpack(data)
		if packet and packet.typ and mqttcmds[packet.typ] then
			mqttcmds[packet.typ](packet)
			if packet.typ ~= mqtt.CONNACK and packet.typ ~= mqtt.SUBACK then
				checkdatactive()				
			end
		end
		f,h,t = mqtt.iscomplete(rests)
	end
end

local function mqttdupind(s)
	if not snd(s,"MQTTDUP") then mqttdupcb(s) end
end

local function shkind()
	print("shkind",locshk,shkalm,nvm.get("guard"))
	local oldflg = locshk	
	locshk = "SHK"
	if oldflg == "TMOUT" then
		preloc()
	end
	
	shkcnt = (shkalm or not nvm.get("guard")) and (shkcnt+1) or 0
	shkalmrpt()
	return true
end

local function chgind()
	chgalmrpt()
	if chg.getcharger() then
		chgalm = false
		stopalmtimer("CHG")
	elseif not sys.timer_is_active(almtimerfnc,"CHG") then
		startalmtimer("CHG",nvm.get("guard"))
	end
	return true
end

local function accind()
	nvm.set("guard",not acc.getflag(),"ACC")
	accalmrpt()
	if not acc.getflag() then
		accalm = false
		stopalmtimer("ACC")
	elseif not sys.timer_is_active(almtimerfnc,"ACC") then
		startalmtimer("ACC",nvm.get("guard"))
	end
	return true
end

local function cconnect()
	sys.timer_stop(datinactive)
end

local function ccdisc()
	checkdatactive()
	reconntimes = 0
	connect(linkapp.NORMAL)
end

local function gpstaind(evt)
	if evt == gps.GPS_LOCATION_SUC_EVT and manage.getlastyp() ~= "GPS" and not firstgps then
		if loc() then firstgps=true end
	end
	return true
end

local function parachangeloc()
	locshk = "SHK"
	preloc()
end

local function parachangeind(k,v,r)
	print("parachangeind",k,r)
	if r ~= "SVR" then
		rptpara(k)
	end
	local procer =
	{
		rptfreq = parachangeloc,
		almfreq = alminit,
		guard = alminit,
		fixmod = parachangeloc,
	}
	if procer[k] then procer[k]() end
	return true
end

local function tparachangeind(k,kk,v,r)
	if r ~= "SVR" then
		rptpara(k)
	end
	return true
end

local function imeirdy()
	rptpara()
end

local procer =
{
	MQTT_DUP_IND = mqttdupind,
	DEV_SHK_IND = shkind,
	DEV_CHG_IND = chgind,
	DEV_ACC_IND = accind,
	CCAPP_CONNECT = cconnect,
	CCAPP_DISCONNECT = ccdisc,
	[gps.GPS_STATE_IND] = gpstaind,
	PARA_CHANGED_IND = parachangeind,
	TPARA_CHANGED_IND = tparachangeind,
	IMEI_READY = imeirdy,
}

sys.regapp(procer)
checkdatactive()
net.startquerytimer()
connect(linkapp.NORMAL)
if rtos.poweron_reason() == rtos.POWERON_KEY or rtos.poweron_reason() == rtos.POWERON_CHARGER then
	accind()
end
