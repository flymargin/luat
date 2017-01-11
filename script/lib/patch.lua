-- patch some function

local oldostime = os.time

function safeostime(t)
	return oldostime(t) or 0
end

os.time = safeostime

local oldosdate = os.date
function safeosdate(s,t)
    if s == "*t" then
        return oldosdate(s,t) or {year = 2012,
                month = 12,
                day = 11,
                hour = 10,
                min = 9,
                sec = 0}
    else
        return oldosdate(s,t)
    end
end

os.date = safeosdate

