PROJECT = "A9321_AIRMQTT_V1723_B3633"
VERSION = "1.0.5"
UPDMODE = 0
_G.collectgarbage("setpause",90)
function appendprj(suffix)
	PROJECT = PROJECT .. suffix
end
require"sys"
require"pins"
require"chg"
require"link"
require"update"
require"gps"
require"dbg"
require"nvm"
require"agps"
require"shk"
require"acc"
require"sleep"
require"light"
require"wdt"
require"gpsapp"
require"manage"
require"linkapp"
require"mqtt"
require"linkair"
require"factory"
require"test"


local apntable =
{
	["46000"] = "CMNET",
	["46002"] = "CMNET",
	["46004"] = "CMNET",
	["46007"] = "CMNET",
	["46001"] = "UNINET",
	["46006"] = "UNINET",
}

local function proc(id)
	link.setapn(apntable[sim.getmcc()..sim.getmnc()] or "CMNET")
	return true
end

sys.regapp(proc,"IMSI_READY")
sys.init(0,0)
sys.run()
