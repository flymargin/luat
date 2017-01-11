module(...,package.seeall)

local ONTIME,OFFTIME = 500,3500

-- 0:≥£√ 1:≥£¡¡ 2:…¡À∏
local ledgps,ledgsm = 0,0

local function gprsready(suc)
	ledgsm = suc and 1 or 2
end

local function netmsg(id,data)
	ledgsm = (data == "REGISTERED") and 2 or 0
	return true
end

local function gpstateind(evt)
	if evt == gps.GPS_LOCATION_SUC_EVT then
		ledgps = 1
	elseif evt == gps.GPS_OPEN_EVT or evt == gps.GPS_LOCATION_FAIL_EVT then
		ledgps = 2
	elseif evt == gps.GPS_CLOSE_EVT then
		ledgps = 0
	end
	return true
end

local procer = {
	NET_GPRS_READY = gprsready,
	[gps.GPS_STATE_IND] = gpstateind,
}
sys.regapp(procer)

local function set(pin,mode,val)
	if mode == 0 then
		pins.set(false,pin)
	elseif mode == 1 then
		pins.set(true,pin)
	elseif mode == 2 then
		pins.set(val,pin)
	end
end

local function blinkoff()
	set(pins.LED_GSM,ledgsm,false)
	set(pins.LED_GPS,ledgps,false)

	sys.timer_start(blinkon,OFFTIME)
end

function blinkon()
	set(pins.LED_GSM,ledgsm,true)
	set(pins.LED_GPS,ledgps,true)

	sys.timer_start(blinkoff,ONTIME)
end

sys.timer_start(blinkon,OFFTIME)
sys.regapp(netmsg,"NET_STATE_CHANGED")
