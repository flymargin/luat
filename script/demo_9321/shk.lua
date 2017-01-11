module(...,package.seeall)

local function ind(id,data)
	print("shk ind",data)
	sys.dispatch("DEV_SHK_IND")
end

sys.regapp(ind,string.format("PIN_%s_IND",pins.SHAKE.name))
