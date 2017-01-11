module(...,package.seeall)

ACC		= {name="ACC",		pin=pio.P0_6    ,dir=pio.INT,valid=0}
CHG_STATUS = {name="CHG_STATUS",pin=pio.P0_1,   dir=pio.INT,valid=0}
SHAKE	= {name="SHK",	pin=pio.P0_3    ,dir=pio.INT,valid=0}
GPS_EN 	= {pin=pio.P0_15,init=false}
CHARGER = {name="CHG",	pin=pio.P0_5    ,dir=pio.INT,valid=1}
LED_GPS = {pin=pio.P0_24,}
LED_GSM = {pin=pio.P0_25,}
WATCHDOG = {pin=pio.P0_14,init=false,valid=0}
RST_SCMWD = {pin=pio.P0_12,defval=true,valid=1}

local allpin = {ACC,CHG_STATUS,SHAKE,GPS_EN,CHARGER,LED_GPS,LED_GSM,RST_SCMWD}

function get(p)
	if p.get then return p.get(p) end
	return pio.pin.getval(p.pin) == p.valid
end

function set(bval,p)
	p.val = bval

	if not p.inited and (not p.ptype or p.ptype == "GPIO") then
		p.inited = true
		pio.pin.setdir(p.dir or pio.OUTPUT,p.pin)
	end

	if p.set then p.set(bval,p) return end

	if p.ptype and p.ptype ~= "GPIO" then print("unknwon pin type:",p.ptype) return end

	local valid = p.valid == 0 and 0 or 1 -- 默认高有效
	local notvalid = p.valid == 0 and 1 or 0
	local val = bval == true and valid or notvalid

	if p.pin then pio.pin.setval(val,p.pin) end
end

function setdir(dir,p)
	if p and not p.ptype or p.ptype == "GPIO" then
		if not p.inited then
			p.inited = true
		end
		if p.pin then
			pio.pin.close(p.pin)
			pio.pin.setdir(dir,p.pin)
			p.dir = dir
		end
	end
end

function init()
	for _,v in ipairs(allpin) do
		if v.init == false then
			-- 不做初始化
		elseif not v.ptype or v.ptype == "GPIO" then
			v.inited = true
			pio.pin.setdir(v.dir or pio.OUTPUT,v.pin)
			if not v.dir or v.dir == pio.OUTPUT then
				set(v.defval or false,v)
			elseif v.dir == pio.INTPUT or v.dir == pio.INT then
				v.val = pio.pin.getval(v.pin) == v.valid
			end
		elseif v.set then
			set(v.defval or false,v)
		end
	end
end

local function intmsg(msg)
	local status = 0

	if msg.int_id == cpu.INT_GPIO_POSEDGE then status = 1 end

	for _,v in ipairs(allpin) do
		if v.dir == pio.INT and msg.int_resnum == v.pin then
			v.val = v.valid == status
			sys.dispatch(string.format("PIN_%s_IND",v.name),v.val)
			return
		end
	end
end
sys.regmsg(rtos.MSG_INT,intmsg)
init()
