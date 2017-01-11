module(...,package.seeall)

local rstcnt = 0

local function clrrst()
	rstcnt = 0
end

local function ind(id,data)
	print("acc ind",data)

	if rstcnt == 0 then
		sys.timer_start(clrrst,10000)
	end
	rstcnt = rstcnt + 1
	if rstcnt >= 5 then dbg.restart("ACC") end

	sys.dispatch("DEV_ACC_IND",data)
end

function getflag()
	return pins.get(pins.ACC) or false
end

sys.regapp(ind,string.format("PIN_%s_IND",pins.ACC.name))
