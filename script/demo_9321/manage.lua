module(...,package.seeall)

GUARDFNC,HANDLEPWRFNC,MOTORPWRFNC,RMTPWRFNC,BUZZERFNC = true,false,false,false,false

local lastyp,lastlng,lastlat,lastmlac,lastmci,lastlbs2 = "","","","","",""

function setlastgps(lng,lat)
	lastyp,lastlng,lastlat = "GPS",lng,lat
end

function isgpsmove(lng,lat)
	if lastlng=="" or lastlat=="" or lastyp~="GPS" then return true end
	local dist = gps.diffofloc(lat,lng,lastlat,lastlng)
	print("isgpsmove",lat,lng,lastlat,lastlng,dist)
	return dist >= 15*15 or dist < 0
end

function setlastlbs1(lac,ci,flg)
	lastmlac,lastmci = lac,ci
	if flg then lastyp = "LBS1" end
end

function islbs1move(lac,ci)
	return lac ~= lastmlac or ci ~= lastmci
end

function setlastlbs2(v,flg)
	lastlbs2 = v
	if flg then lastyp = "LBS2" end
end

function islbs2move(v)
	if lastlbs2 == "" then return true end
	local oldcnt,newcnt,subcnt,chngcnt,laci = 0,0,0,0
	
	for laci in string.gmatch(lastlbs2,"(%d+%.%d+%.%d+%.%d+%.)%d+;") do
		oldcnt = oldcnt + 1
	end
	
	for laci in string.gmatch(v,"(%d+%.%d+%.%d+%.%d+%.)%d+;") do
		newcnt = newcnt + 1
		if not string.match(lastlbs2,laci) then chngcnt = chngcnt + 1 end
	end
	
	if oldcnt > newcnt then chngcnt = chngcnt + (oldcnt-newcnt) end
	local move = chngcnt*100/(newcnt>oldcnt and newcnt or oldcnt)
	print("islbs2move",lastlbs2,v,move)
	return move >= 50
end

function getlastyp()
	return lastyp
end

local cmcclastyp,cmcclastlng,cmcclastlat,cmcclastmlac,cmcclastmci = "","","","",""

function setcmcclastgps(lng,lat)
	print("setcmcclastgps",lng,lat)
	cmcclastlng,cmcclastlat = lng,lat
	if lng~="" and lat ~= "" then cmcclastyp = "GPS" end
end

function iscmccgpsmove(lng,lat)
	print("iscmccgpsmove",lng,lat,cmcclastlng,cmcclastlat,cmcclastyp)
	if cmcclastlng=="" or cmcclastlat=="" or cmcclastyp~="GPS" then return true end
	local dist = gps.diffofloc(lat,lng,cmcclastlat,cmcclastlng)
	print("iscmccgpsmove",lat,lng,cmcclastlat,cmcclastlng,dist)
	return dist >= 15*15 or dist < 0
end

function setcmcclastlbs1(lac,ci,flg)
	print("setcmcclastlbs1",lac,ci,flg)
	cmcclastmlac,cmcclastmci = lac,ci
	if flg then cmcclastyp = "LBS1" end
end

function iscmcclbs1move(lac,ci)
	print("iscmcclbs1move",lac,ci,cmcclastmlac,cmcclastmci)
	return lac ~= cmcclastmlac or ci ~= cmcclastmci
end

function getcmcclastyp()
	return cmcclastyp
end

function getcmcclastgps()
	return cmcclastlng,cmcclastlat
end

local gpsmod = 1+4+8

local function gpsstatind(evt)
	if evt == gps.GPS_LOCATION_SUC_EVT then
		sys.timer_start(gpsapp.close,5000,gpsapp.TIMER,{cause="POWERON"})
	end
	return true
end

local function init()
	if nvm.get("fixmod") == "LBS" then return end
	if bit.band(gpsmod,0x01) ~= 0 then
		if rtos.poweron_reason() == rtos.POWERON_KEY or rtos.poweron_reason() == rtos.POWERON_CHARGER then
			gpsapp.open(gpsapp.TIMER,{cause="POWERON",val=300})
		end
	end
end

local function shkind()
	if nvm.get("fixmod") == "LBS" then return true end
	if bit.band(gpsmod,0x02) ~= 0 then
		if nvm.get("rptfreq") <= 60 then
			gpsapp.open(gpsapp.TIMER,{cause="RPTFREQ",val=300})
		else
			gpsapp.close(gpsapp.TIMER,{cause="RPTFREQ"})
		end
	end
	if bit.band(gpsmod,0x08) ~= 0 then
		gpsapp.open(gpsapp.TIMER,{cause="RPTFREQ",val=300})
	end
	return true
end

local function accind(on)
	if nvm.get("fixmod") == "LBS" then return true end
	if bit.band(gpsmod,0x04) ~= 0 then
		if on then
			gpsapp.open(gpsapp.DEFAULT,{cause="ACC"})
		else
			gpsapp.close(gpsapp.DEFAULT,{cause="ACC"})
		end		
	end	
	return true
end

local function parachangeind(k,v,r)
	if k == "fixmod" then
		if v == "LBS" then
			gpsapp.close(gpsapp.TIMER,{cause="RPTFREQ"})
			gpsapp.close(gpsapp.TIMER,{cause="POWERON"})
			gpsapp.close(gpsapp.TIMER,{cause="ACC"})
		else
			accind(acc.getflag())
		end
	end	
	return true
end

local procer =
{
	DEV_SHK_IND = shkind,
	DEV_ACC_IND = accind,
	PARA_CHANGED_IND = parachangeind,
	[gps.GPS_STATE_IND] = gpsstatind,
}

sys.regapp(procer)
init()
accind(acc.getflag())
