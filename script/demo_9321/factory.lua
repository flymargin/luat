module(...,package.seeall)

local ftrlt,fttimes,shkflag = 0,0
local smatch,slen = string.match,string.len
local waitrst

local function rsp(s)
	print("factory rsp",s)
	uart.write(3,s)
end

local function timeout()
	local s1
	fttimes = fttimes + 1
	print("factory timeout",fttimes)
	if fttimes > 20 then
	    s1 = "\r\n" .. "+FT9321:" .. "\r\n" .. ftrlt .. "\r\n" .. "OK" .. "\r\n"
		rsp(s1)
		return
	end
	checkft()
end

function checkft()
	print("factory checkft",net.getstate(),net.getrssi(),gps.getgpssn(),shkflag,acc.getflag(),chg.getcharger(),chg.getstate())
	local s1
	if net.getstate()=="REGISTERED" and net.getrssi() > 10 and (ftrlt % 2) == 0 then
		ftrlt = ftrlt + 1
	end
	if gps.getgpssn() > 30 then
		if (ftrlt % 4) < 2 then
			ftrlt = ftrlt + 2
		end
	end
	if shkflag then
		if (ftrlt % 8) < 4 then
			ftrlt = ftrlt + 4
		end
	end
	if acc.getflag() then
		if (ftrlt % 16) < 8 then
			ftrlt = ftrlt + 8
		end
	end
	if chg.getcharger() then
		if (ftrlt % 32) < 16 then
			ftrlt = ftrlt + 16
		end
	end
	if chg.getstate() then
		if ftrlt < 32 then
			ftrlt = ftrlt + 32
		end
	end

	if ftrlt < 63 then
		print("factory timeout",fttimes)
		sys.timer_start(timeout,1000)
	else
		gpsapp.close(gpsapp.DEFAULT,{cause="FAC"})
		s1 = "\r\n" .. "+FT9321:" .. "\r\n" .. ftrlt .. "\r\n" .. "OK" .. "\r\n"
		rsp(s1)
	end
end

local function cb(cmd,success,response,intermediate)
	if (smatch(cmd,"WIMEI=") or smatch(cmd,"WISN=") or smatch(cmd,"AMFAC=")) and success then
		rsp("\r\nOK\r\n")
	end
end

local function proc(s)
	s = string.upper(s)
	if smatch(s,"WIMEI=") then
		misc.set("WIMEI",smatch(s,"=\"(.+)\""),cb)
		waitrst = true
	elseif smatch(s,"CGSN") then
		if waitrst then
			rsp("\r\nAT+CGSN\r\nWAIT RST\r\nOK\r\n")
		else
			local imei = misc.getimei()
			if imei and slen(imei) > 0 then
				rsp("\r\nAT+CGSN\r\n" .. imei .. "\r\nOK\r\n")
			end
		end
	elseif smatch(s,"WISN=") then
		misc.set("WISN",smatch(s,"=\"(.+)\""),cb)
		waitrst = true
	elseif smatch(s,"WISN%?") then
		if waitrst then
			rsp("\r\nAT+WISN?\r\nWAIT RST\r\nOK\r\n")
		else
			local sn = misc.getsn()
			if sn and slen(sn) > 0 then
				rsp("\r\nAT+WISN?\r\n" .. sn .. "\r\nOK\r\n")
			end
		end
	elseif smatch(s,"VER") then
		rsp("\r\nAT+VER\r\n" .. _G.PROJECT .. "_" .. _G.VERSION .."\r\nOK\r\n")
	elseif smatch(s,"AMFAC=") then
		gpsapp.open(gpsapp.DEFAULT,{cause="FAC"})
		misc.set("AMFAC",smatch(s,"=(.+)"),cb)
	elseif smatch(s,"CFUN=") then
		--misc.set("CFUN",smatch(s,"=(.+)"))
		waitrst = true
		uart.close(3)
		rtos.restart()
	elseif smatch(s,"AT%+FT9321") then
		gpsapp.open(gpsapp.DEFAULT,{cause="FAC"})
		checkft()
	end
end

local function read()
	local t1
	local s1 = ""
	local rd = true
	while rd == true do
		t1 = uart.read(3,"*l",0)
		if string.len(t1) == 0 then
			rd = false
			continue
		end
		s1 = s1 .. t1
	end

	if s1 ~= "" then
		print("factory proc:",s1)
	end
	proc(s1)
end

local function ind(id,data)
	if id == "DEV_SHK_IND" then
		shkflag = true
	end
	return true
end

uart.setup(3,921600,8,uart.PAR_NONE,uart.STOP_1,2)
sys.reguart(3,read)
net.startquerytimer()
sys.regapp(ind,"DEV_SHK_IND")
