module(...,package.seeall)

local typ = 1 --0:充电芯片控制 1:IO口控制
local inf = {}

local function proc(msg)
	if msg then
		if typ == 0 then
			inf.chg = msg.charger
			inf.state = msg.state
		end
		inf.lev = msg.level
		inf.vol = msg.voltage
		if inf.lev == 0 and not inf.chg then
			if not inf.poweroffing then
				inf.poweroffing = true
				sys.timer_start(rtos.poweroff,30000,"chg")
			end
		elseif inf.poweroffing then
			sys.timer_stop(rtos.poweroff,"chg")
			inf.poweroffing = false
		end
		print("chg proc",typ,inf.chg,inf.lev,inf.vol)
		sys.dispatch("DEV_VOLT_IND",inf.vol)
	end
end

local function init()
	inf.vol = 0
	inf.lev = 0
	inf.chg = (typ == 1) and pins.get(pins.CHARGER) or false
	inf.state = (typ == 1) and pins.get(pins.CHG_STATUS) or false
	inf.poweroffing = false
end

local function ind(id,data)
	print("chg ind",id,data)
	if id == string.format("PIN_%s_IND",pins.CHARGER.name) then
		inf.chg = data
		sys.dispatch("DEV_CHG_IND")
	elseif id == string.format("PIN_%s_IND",pins.CHG_STATUS.name) then
		inf.state = data
	end
end

function getcharger()
	return inf.chg
end

function getvolt()
	return inf.vol
end

function getlev()
	return inf.lev
end

function getstate()
	return (typ == 1) and pins.get(pins.CHG_STATUS) or (inf.state == 1)
end

sys.regmsg(rtos.MSG_PMD,proc)
sys.regapp(ind,string.format("PIN_%s_IND",pins.CHARGER.name),string.format("PIN_%s_IND",pins.CHG_STATUS.name))
init()
