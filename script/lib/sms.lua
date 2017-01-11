
local base = _G
local string = require "string"
local table = require "table"
local sys = require "sys"
local ril = require "ril"
local common = require "common"
local bit = require"bit"
module("sms")

local print = base.print
local tonumber = base.tonumber
local dispatch = sys.dispatch
local req = ril.request

local ready,isn,tlongsms = false,255,{}
local ssub,slen,sformat,smatch = string.sub,string.len,string.format,string.match

function send(num,data)
	local numlen,datalen,pducnt,pdu,pdulen,udhi = sformat("%02X",slen(num)),slen(data)/2,1,"","",""
	if not ready then return false end
	
	if datalen > 140 then
		pducnt = sformat("%d",(datalen+133)/134)
		pducnt = tonumber(pducnt)
		isn = isn==255 and 0 or isn+1
	end
	
	if ssub(num,1,1) == "+" then
		numlen = sformat("%02X",slen(num)-1)
	end
	
	for i=1, pducnt do
		if pducnt > 1 then
			local len_mul
			len_mul = (i==pducnt and sformat("%02X",datalen-(pducnt-1)*134+6) or "8C")
			udhi = "050003" .. sformat("%02X",isn) .. sformat("%02X",pducnt) .. sformat("%02X",i)
			print(datalen, udhi)
			pdu = "005110" .. numlen .. common.numtobcdnum(num) .. "000800" .. len_mul .. udhi .. ssub(data, (i-1)*134*2+1,i*134*2)
		else
			datalen = sformat("%02X",datalen)
			pdu = "001110" .. numlen .. common.numtobcdnum(num) .. "000800" .. datalen .. data
		end
		pdulen = slen(pdu)/2-1
		req(sformat("%s%s","AT+CMGS=",pdulen),pdu)
	end
	return true
end

function read(pos)
	if not ready or pos==ni or pos==0 then return false end
	
	req("AT+CMGR="..pos)
	return true
end

function delete(pos)
	if not ready or pos==ni or pos==0 then return false end
	req("AT+CMGD="..pos)
	return true
end

Charmap = {[0]=0x40,0xa3,0x24,0xa5,0xe8,0xE9,0xF9,0xEC,0xF2,0xC7,0x0A,0xD8,0xF8,0x0D,0xC5,0xE5
		  ,0x0394,0x5F,0x03A6,0x0393,0x039B,0x03A9,0x03A0,0x03A8,0x03A3,0x0398,0x039E,0x1B,0xC6,0xE5,0xDF,0xA9
		  ,0x20,0x21,0x22,0x23,0xA4,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,0x2F
		  ,0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F
		  ,0xA1,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F
		  ,0X50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,0xC4,0xD6,0xD1,0xDC,0xA7
		  ,0xBF,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x6F
		  ,0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0xE4,0xF6,0xF1,0xFC,0xE0}

Charmapctl = {[10]=0x0C,[20]=0x5E,[40]=0x7B,[41]=0x7D,[47]=0x5C,[60]=0x5B,[61]=0x7E
			 ,[62]=0x5D,[64]=0x7C,[101]=0xA4}

function gsm7bitdecode(data,longsms)
	local ucsdata,lpcnt,tmpdata,resdata,nbyte,nleft,ucslen,olddat = "",slen(data)/2,0,0,0,0,0
  
	if longsms then
		tmpdata = tonumber("0x" .. ssub(data,1,2))   
		resdata = bit.rshift(tmpdata,1)
		if olddat==27 then
			if Charmapctl[resdata] then--特殊字符
				olddat,resdata = resdata,Charmapctl[resdata]
				ucsdata = ssub(ucsdata,1,-5)
			else
				olddat,resdata = resdata,Charmap[resdata]
			end
		else
			olddat,resdata = resdata,Charmap[resdata]
		end
		ucsdata = ucsdata .. sformat("%04X",resdata)
	else
		tmpdata = tonumber("0x" .. ssub(data,1,2))    
		resdata = bit.band(bit.bor(bit.lshift(tmpdata,nbyte),nleft),0x7f)
		if olddat==27 then
			if Charmapctl[resdata] then--特殊字符
				olddat,resdata = resdata,Charmapctl[resdata]
				ucsdata = ssub(ucsdata,1,-5)
			else
				olddat,resdata = resdata,Charmap[resdata]
			end
		else
			olddat,resdata = resdata,Charmap[resdata]
		end
		ucsdata = ucsdata .. sformat("%04X",resdata)
   
		nleft = bit.rshift(tmpdata, 7-nbyte)
		nbyte = nbyte+1
		ucslen = ucslen+1
	end
  
	for i=2, lpcnt do
		tmpdata = tonumber("0x" .. ssub(data,(i-1)*2+1,i*2))   
		if tmpdata == nil then break end 
		resdata = bit.band(bit.bor(bit.lshift(tmpdata,nbyte),nleft),0x7f)
		if olddat==27 then
			if Charmapctl[resdata] then--特殊字符
				olddat,resdata = resdata,Charmapctl[resdata]
				ucsdata = ssub(ucsdata,1,-5)
			else
				olddat,resdata = resdata,Charmap[resdata]
			end
		else
			olddat,resdata = resdata,Charmap[resdata]
		end
		ucsdata = ucsdata .. sformat("%04X",resdata)
   
		nleft = bit.rshift(tmpdata, 7-nbyte)
		nbyte = nbyte+1
		ucslen = ucslen+1
	
		if nbyte == 7 then
			if olddat==27 then
				if Charmapctl[nleft] then--特殊字符
					olddat,nleft = nleft,Charmapctl[nleft]
					ucsdata = ssub(ucsdata,1,-5)
				else
					olddat,nleft = nleft,Charmap[nleft]
				end
			else
				olddat,nleft = nleft,Charmap[nleft]
			end
			ucsdata = ucsdata .. sformat("%04X",nleft)
			nbyte,nleft = 0,0
			ucslen = ucslen+1
		end
	end
  
	return ucsdata,ucslen
end

function gsm8bitdecode(data)
	local ucsdata,lpcnt = "",slen(data)/2
   
	for i=1, lpcnt do
		ucsdata = ucsdata .. "00" .. ssub(data,(i-1)*2+1,i*2)
	end
   
	return ucsdata,lpcnt
end

local function rsp(cmd,success,response,intermediate)
	local prefix = smatch(cmd,"AT(%+%u+)")
	print("lib_sms rsp",prefix,cmd,success,response,intermediate)

	if prefix == "+CMGR" and success then
		local convnum,t,stat,alpha,len,pdu,data,longsms,total,isn,idx = "",""
		if intermediate then
			stat,alpha,len,pdu = smatch(intermediate,"+CMGR:%s*(%d),(.*),%s*(%d+)\r\n(%x+)")
			len = tonumber(len)--PDU数据长度，不包括短信息中心号码
		end
	
		if pdu and pdu ~= "" then
			local offset,addlen,addnum,flag,dcs,tz,txtlen,fo=5     
			pdu = ssub(pdu,(slen(pdu)/2-len)*2+1,-1)--PDU数据，不包括短信息中心号码
			fo = tonumber("0x" .. ssub(pdu,1,1))--PDU短信首字节的高4位,第6位为数据报头标志位
			if bit.band(fo, 0x4) ~= 0 then
				longsms = true
			end
			addlen = tonumber(sformat("%d","0x"..ssub(pdu,3,4)))--回复地址数字个数 
	  
			addlen = addlen%2 == 0 and addlen+2 or addlen+3 --加上号码类型2位（5，6）or 加上号码类型2位（5，6）和1位F
	  
			offset = offset+addlen
	  
			addnum = ssub(pdu,5,5+addlen-1)
			convnum = common.bcdnumtonum(addnum)
	  
			flag = tonumber(sformat("%d","0x"..ssub(pdu,offset,offset+1)))--协议标识 (TP-PID) 
			offset = offset+2
			dcs = tonumber(sformat("%d","0x"..ssub(pdu,offset,offset+1)))--用户信息编码方式 Dcs=8，表示短信存放的格式为UCS2编码
			offset = offset+2
			tz = ssub(pdu,offset,offset+13)--时区7个字节
			offset = offset+14
			txtlen = tonumber(sformat("%d","0x"..ssub(pdu,offset,offset+1)))--短信文本长度 
			offset = offset+2
			data = ssub(pdu,offset,offset+txtlen*2-1)--短信文本
			if longsms then
				isn,total,idx = tonumber("0x" .. ssub(data, 7,8)),tonumber("0x" .. ssub(data, 9,10)),tonumber("0x" .. ssub(data, 11,12))
				data = ssub(data, 13,-1)--去掉报头6个字节
			end
	  
			print("TP-PID : ",flag, "dcs: ", dcs, "tz: ",tz, "data: ",data,"txtlen",txtlen)
	  
			if dcs == 0x00 then--7bit encode
				local newlen
				data,newlen = gsm7bitdecode(data, longsms)
				if newlen > txtlen then
					data = ssub(data,1,txtlen*4)
				end
				print("7bit to ucs2 data: ",data,"txtlen",txtlen,"newlen",newlen)
			elseif dcs == 0x04 then
				data,txtlen = gsm8bitdecode(data)
				print("8bit to ucs2 data: ",data,"txtlen",txtlen)
			end
  
			for i=1, 7  do
				t = t .. ssub(tz, i*2,i*2) .. ssub(tz, i*2-1,i*2-1)
	  
				if i<=3 then
					t = i<3 and (t .. "/") or (t .. ",")
				elseif i <= 6 then
					t = i<6 and (t .. ":") or (t .. "+")
				end
			end
		end
	
		local pos = smatch(cmd,"AT%+CMGR=(%d+)")
		data = data or ""
		alpha = alpha or ""
		dispatch("SMS_READ_CNF",success,convnum,data,pos,t,alpha,total,idx,isn)
	elseif prefix == "+CMGD" then
		dispatch("SMS_DELETE_CNF",success)
	elseif prefix == "+CMGS" then
		dispatch("SMS_SEND_CNF",success)
	end
end

local function urc(data,prefix)
	if data == "SMS READY" then
		ready = true
		--req("AT+CSMP=17,167,0,8")--设置短信TEXT 模式参数
		req("AT+CMGF=0")
		req("AT+CSCS=\"UCS2\"")
		dispatch("SMS_READY")
	elseif prefix == "+CMTI" then
		local pos = smatch(data,"(%d+)",slen(prefix)+1)
		dispatch("SMS_NEW_MSG_IND",pos)
	end
end

function getsmsstate()
	return ready
end

local function mergelongsms()
	local data,num,t,alpha=""
	for i=1, #tlongsms do
		if tlongsms[i] and tlongsms[i].dat and tlongsms[i].dat~="" then
			data,num,t,alpha = data .. tlongsms[i].dat,tlongsms[i].num,tlongsms[i].t,tlongsms[i].nam 
		end
	end
	for i=1, #tlongsms do
		table.remove(tlongsms)
	end
	sys.dispatch("LONG_SMS_MERGR_CNF",true,num,data,t,alpha)
	print("mergelongsms", "num:",num, "data", data)
end

local function longsmsind(id,num, data,datetime,name,total,idx,isn)
	print("longsmsind", "total:",total, "idx:",idx,"data", data)
	if #tlongsms==0 then
		tlongsms[idx] = {dat=data,udhi=total .. isn,num=num,t=datetime,nam=name}
	else
		local oldudhi = ""
		for i=1,#tlongsms do
			if tlongsms[i] and tlongsms[i].udhi and tlongsms[i].udhi~="" then
				oldudhi = tlongsms[i].udhi
				break
			end
		end
		if oldudhi==total .. isn then
			tlongsms[idx] = {dat=data,udhi=total .. isn,num=num,t=datetime,nam=name}
		else
			sys.timer_stop(mergelongsms)
			mergelongsms()
			tlongsms[idx] = {dat=data,udhi=total .. isn,num=num,t=datetime,nam=name}
		end
	end
  
	if total==#tlongsms then
		sys.timer_stop(mergelongsms)
		mergelongsms()
	else
		sys.timer_start(mergelongsms,120000)
	end
end

sys.regapp(longsmsind,"LONG_SMS_MERGE")

ril.regurc("SMS READY",urc)
ril.regurc("+CMT",urc)
ril.regurc("+CMTI",urc)

ril.regrsp("+CMGR",rsp)
ril.regrsp("+CMGD",rsp)
ril.regrsp("+CMGS",rsp)

--默认上报新短信存储位置
--req("AT+CNMI=2,1")
--使用PDU模式发送
req("AT+CMGF=0")
req("AT+CSMP=17,167,0,8")
req("AT+CSCS=\"UCS2\"")
req("AT+CPMS=\"SM\"")
req('AT+CNMI=2,1')


