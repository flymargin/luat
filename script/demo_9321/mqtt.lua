module(...,package.seeall)
local lpack = require"pack"
require"mqttdup"

local slen,sbyte,ssub,sgsub,schar,srep,smatch,sgmatch = string.len,string.byte,string.sub,string.gsub,string.char,string.rep,string.match,string.gmatch
CONNECT,CONNACK,PUBLISH,PUBACK,PUBREC,PUBREL,PUBCOMP,SUBSCRIBE,SUBACK,UNSUBSCRIBE,UNSUBACK,PINGREQ,PINGRSP,DISCONNECT = 1,2,3,4,5,6,7,8,9,10,11,12,13,14

local PRONAME,PROVER,CLEANSESS = "MQIsdp",3,1

local seq = 1

local function print(...)
	_G.print("mqtt",...)
end

local function encutf8(s)
	if not s then return "" end
	return lpack.pack(">HA",slen(s),s)
end

local function enclen(s)
	if not s or slen(s) == 0 then return schar(0) end
	local ret,len,digit = "",slen(s)
	repeat
		digit = len % 128
		len = len / 128
		if len > 0 then
			digit = bit.bor(digit,0x80)
		end
		ret = ret..schar(digit)
	until (len <= 0)
	return ret
end

local function declen(s)
	local i,value,multiplier,digit = 1,0,1 
	repeat
		if i > slen(s) then return end
		digit = sbyte(s,i) 
		value = value + bit.band(digit,127)*multiplier
		multiplier = multiplier * 128
		i = i + 1
	until (bit.band(digit,128) == 0)
	return true,value,i-1
end

local function getseq()
	local s = seq
	seq = (seq+1)%0xFFFF
	if seq == 0 then seq = 1 end
	return lpack.pack(">H",s)
end

function iscomplete(s)
	local i,typ,flg,len,cnt
	for i=1,slen(s) do
		typ = bit.band(bit.rshift(sbyte(s,i),4),0x0f)
		--print("typ",typ)
		if typ >= CONNECT and typ <= DISCONNECT then
			flg,len,cnt = declen(ssub(s,i+1,-1))
			--print("f",flg,len,cnt,(slen(ssub(s,i+1,-1))-cnt))
			if flg and cnt <= 4 and len <= (slen(ssub(s,i+1,-1))-cnt) then
				return true,i,i+cnt+len,typ,len
			end
		end		
	end
end

function pack(typ,...)
	local para = {}
	local function connect(alive,id,user,pwd)
		return lpack.pack(">bAbbHAAA",CONNECT*16,encutf8(PRONAME),PROVER,(user and 1 or 0)*128+(pwd and 1 or 0)*64+CLEANSESS*2,alive,encutf8(id),encutf8(user),encutf8(pwd))
	end
	
	local function subscribe(p)
		para.dup,para.topic = true,p.topic
		para.seq = p.seq or getseq()
		print("subscribe",p.dup,para.dup,common.binstohexs(para.seq))
		
		local s = lpack.pack("bA",SUBSCRIBE*16+(p.dup and 1 or 0)*8+2,para.seq)
		for i=1,#p.topic do
			s = s..encutf8(p.topic[i]).."\1"
		end
		return s
	end
	
	local function publish(p)
		para.dup,para.topic,para.payload,para.qos,para.retain = true,p.topic,p.payload,p.qos,p.retain
		para.seq = p.seq or getseq()
		--print("publish",p.dup,para.dup,common.binstohexs(para.seq))
		
		return lpack.pack("bAAA",PUBLISH*16+(p.dup and 1 or 0)*8+(p.qos or 0)*2+(p.retain and 1 or 0)*1,encutf8(p.topic),((p.qos or 0)>0 and para.seq or ""),p.payload)
	end
	
	local function puback(seq)
		return schar(PUBACK*16)..seq
	end
	
	local function pingreq()
		return schar(PINGREQ*16)
	end
	
	local function disconnect()
		return schar(DISCONNECT*16)
	end

	local procer =
	{
		[CONNECT] = connect,
		[SUBSCRIBE] = subscribe,
		[PUBLISH] = publish,
		[PUBACK] = puback,
		[PINGREQ] = pingreq,
		[DISCONNECT] = disconnect,
	}

	local s = procer[typ](...)
	s = ssub(s,1,1)..enclen(ssub(s,2,-1))..ssub(s,2,-1)
	print("pack",typ,common.binstohexs(s))
	return s,para
end

function unpack(s)
	local packet = {}

	local function connack(d)
		print("connack",common.binstohexs(d))
		packet.suc = (sbyte(d,2)==0)
		return true
	end
	
	local function suback(d)
		print("suback",common.binstohexs(d))
		if slen(d) < 2 then return end
		packet.seq = ssub(d,1,2)
		return true
	end
	
	local function puback(d)
		print("puback",common.binstohexs(d))
		if slen(d) < 2 then return end
		packet.seq = ssub(d,1,2)
		return true
	end
	
	local function publish(d)
		print("publish",common.binstohexs(d))
		if slen(d) < 6 then return end
		local _,tplen = lpack.unpack(ssub(d,1,2),">H")
		if slen(d) < tplen + 5 then return end
		packet.topic = ssub(d,3,2+tplen)
		local pay = 3
		if packet.qos > 0 then
			packet.seq = ssub(d,tplen+3,tplen+4)
			pay = 5
		end
		packet.payload = ssub(d,tplen+pay,-1)
		return true
	end
	
	local function empty()
		return true
	end

	local procer =
	{
		[CONNACK] = connack,
		[SUBACK] = suback,
		[PUBACK] = puback,
		[PUBLISH] = publish,
		[PINGRSP] = empty,
	}
	local d1,d2,d3,typ,len = iscomplete(s)	
	if not procer[typ] then print("unpack unknwon typ",typ) return end
	packet.typ = typ
	packet.qos = bit.rshift(bit.band(sbyte(s,1),0x06),1)
	print("unpack",typ,packet.qos,common.binstohexs(s))
	return procer[typ](ssub(s,slen(s)-len+1,-1)) and packet or nil
end
