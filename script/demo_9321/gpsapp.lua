module(...,package.seeall)
DEFAULT,TIMERORSUC,TIMER = 0,1,2
local tlist,flg = {}

local function delitem(mode,para)
	local i
	for i=1,#tlist do
		if tlist[i].flag and tlist[i].mode == mode and tlist[i].para.cause == para.cause then
			tlist[i].flag,tlist[i].delay = false
			break
		end
	end
end

local function additem(mode,para)
	delitem(mode,para)
	local item,i,fnd = {flag = true, mode = mode, para = para}
	if mode == TIMERORSUC or mode == TIMER then item.para.remain = para.val end
	for i=1,#tlist do
		if not tlist[i].flag then
			tlist[i] = item
			fnd = true
			break
		end
	end
	if not fnd then table.insert(tlist,item) end
end

local function isexisttimeritem()
	local i
	for i=1,#tlist do
		if tlist[i].flag and (tlist[i].mode == TIMERORSUC or tlist[i].mode == TIMER or tlist[i].para.delay) then return true end
	end
end

local function timerfunc()
	local i
	for i=1,#tlist do
		print("gpsapp.timerfunc@"..i,tlist[i].flag,tlist[i].mode,tlist[i].para.cause,tlist[i].para.val,tlist[i].para.remain,tlist[i].para.delay,tlist[i].para.cb)
		if tlist[i].flag then
			local rmn,dly,md,cb = tlist[i].para.remain,tlist[i].para.delay,tlist[i].mode,tlist[i].para.cb
			if rmn and rmn > 0 then
				tlist[i].para.remain = rmn - 1
			end
			if dly and dly > 0 then
				tlist[i].para.delay = dly - 1
			end
			
			rmn = tlist[i].para.remain
			if gps.isfix() and md == TIMER and rmn == 0 and not tlist[i].para.delay then
				tlist[i].para.delay = 10
			end
			
			dly = tlist[i].para.delay
			if gps.isfix() then
				if dly and dly == 0 then
					if cb then cb(tlist[i].para.cause) end
					if md == DEFAULT then
						tlist[i].para.delay = nil
					else
						close(md,tlist[i].para)
					end
				end
			else
				if rmn and rmn == 0 then
					if cb then cb(tlist[i].para.cause) end
					close(md,tlist[i].para)
				end
			end			
		end
	end
	if isexisttimeritem() then sys.timer_start(timerfunc,1000) end
end

local function gpsstatind(id,evt)
	if evt == gps.GPS_LOCATION_SUC_EVT then
		local i
		for i=1,#tlist do
			print("gpsapp.gpsstatind@"..i,tlist[i].flag,tlist[i].mode,tlist[i].para.cause,tlist[i].para.val,tlist[i].para.remain,tlist[i].para.delay,tlist[i].para.cb)
			if tlist[i].flag then
				if tlist[i].mode ~= TIMER then
					tlist[i].para.delay = 10
					if tlist[i].mode == DEFAULT then
						if isexisttimeritem() then sys.timer_start(timerfunc,1000) end
					end
				end				
			end			
		end
	elseif evt == gps.GPS_CLOSE_EVT then
		flg = nil
	end
	return true
end

function updfixmode()
end

function forceclose()
	local i
	for i=1,#tlist do
		if tlist[i].flag and tlist[i].para.cb then tlist[i].para.cb(tlist[i].para.cause) end
		close(tlist[i].mode,tlist[i].para)
	end
end

function close(mode,para)
	assert((para and _G.type(para) == "table" and para.cause),"gpsapp.close para invalid")
	print("gpsapp.ctl close",mode,para.cause,para.val,para.cb)
	delitem(mode,para)
	local valid,i
	for i=1,#tlist do
		if tlist[i].flag then
			valid = true
		end		
	end
	if not valid then gps.closegps("gpsapp") end
end

function open(mode,para)
	assert((para and _G.type(para) == "table" and para.cause),"gpsapp.open para invalid")
	print("gpsapp.ctl open",mode,para.cause,para.val,para.cb)
	if gps.isfix() then
		if mode ~= TIMER then
			if para.cb then para.cb(para.cause) end
			if mode == TIMERORSUC then return end			
		end
	end
	additem(mode,para)
	gps.opengps("gpsapp")
	updfixmode()	
	if isexisttimeritem() and not sys.timer_is_active(timerfunc) then
		sys.timer_start(timerfunc,1000)
	end
end

function isactive(mode,para)
	local i
	for i=1,#tlist do
		if tlist[i].flag and tlist[i].mode == mode and tlist[i].para.cause == para.cause then
			return true
		end
	end
end

gps.initgps(pins.GPS_EN.pin,pio.OUTPUT,true,1000,2,9600,8,uart.PAR_NONE,uart.STOP_1)
gps.setgpsfilter(1)
update.settimezone(update.BEIJING_TIME)
gps.setspdtyp(gps.GPS_KILOMETER_SPD)
sys.regapp(gpsstatind,gps.GPS_STATE_IND)
