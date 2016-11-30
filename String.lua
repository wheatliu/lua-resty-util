-- useful string method 
local ffi = require 'ffi'
local ngx_re = require "ngx.re"
local str = require "resty.string"
local string = string

string.split = ngx_re.split
string.cstring = function(str) return ffi.new('char['..#str+1 ..']', str) end
string.tohex = str.to_hex

string.startswith = function(raw, pre)
    if #raw < #pre then return false end
    return ffi.C.memcmp(pre:cstring(), raw:cstring(), #pre) == 0
end

string.endswith = function(raw, post)
    if #raw < #post then return false end
    return ffi.C.memcmp(post:cstring(), raw:cstring() + (#raw - #post), #post) == 0
end

return string