local ffi = require "ffi"
local bit = require "bit"
local SYS = require "sys"
local config = require "config"
local String = require "String"
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local octal = function (s) return tonumber(s, 8) end
local cpath = function(path) return ffi.new('char['..#path+1 ..']', path) end

local _M = {};

local S_IFMT   = octal('0170000')
local S_IFSOCK = octal('0140000')
local S_IFLNK  = octal('0120000')
local S_IFREG  = octal('0100000')
local S_IFBLK  = octal('0060000')
local S_IFDIR  = octal('0040000')
local S_IFCHR  = octal('0020000')
local S_IFIFO  = octal('0010000')
local S_ISUID  = octal('0004000')
local S_ISGID  = octal('0002000')
local S_ISVTX  = octal('0001000')

local S_IRWXU = octal('00700')
local S_IRUSR = octal('00400')
local S_IWUSR = octal('00200')
local S_IXUSR = octal('00100')
local S_IRWXG = octal('00070')
local S_IRGRP = octal('00040')
local S_IWGRP = octal('00020')
local S_IXGRP = octal('00010')
local S_IRWXO = octal('00007')
local S_IROTH = octal('00004')
local S_IWOTH = octal('00002')
local S_IXOTH = octal('00001')

function S_ISREG(m)  return band(m, S_IFREG)  ~= 0 end
function S_ISDIR(m)  return band(m, S_IFDIR)  ~= 0 end
function S_ISCHR(m)  return band(m, S_IFCHR)  ~= 0 end
function S_ISBLK(m)  return band(m, S_IFBLK)  ~= 0 end
function S_ISFIFO(m) return band(m, S_IFFIFO) ~= 0 end
function S_ISLNK(m)  return band(m, S_IFLNK)  ~= 0 end
function S_ISSOCK(m) return band(m, S_IFSOCK) ~= 0 end


_M.is_dir = function(path)
    local stat = ffi.typeof("struct stat")
    local fstat = ffi.new(stat)
    local rtn = ffi.C.syscall(SYS.stat, path:cstring(), fstat)
    if rtn ~= 0 then
        local errno = ffi.errno()
        if tonumber(errno) == 2 then return false, nil end
        local err = ffi.C.strerror(errno)
        return nil, ffi.string(err)
    end

    return S_ISDIR(fstat.st_mode), nil
end

_M.is_exist = function (path)
    return ffi.C.access(cpath(path), 0) == 0
end

_M.basename = function(path)
    local bn = ffi.C.basename(cpath(path))
    return ffi.string(bn)
end

_M.dirname = function(path)
    local dn = ffi.C.dirname(cpath(path))
    return ffi.string(dn)
end

_M.create_dir_if_not_exist = function (path)
    local isDir, err = _M.is_dir(path)
    if err then return nil, err end
    if isDir then return true, nil end
    -- file mode default: 755
    local mode = octal(755)
    path = path:endswith('/') and path or path..'/'
    if ffi.C.ngx_create_full_path(path:cstring(), mode) == 0 then return true, nil end
    local err = ffi.C.strerror(ffi.errno())
    return nil, ffi.string(err)
end

_M.pathJoin = function(...)
    local tbl = {...}
    local path = ''
    for i, v in ipairs(tbl) do
        v = tostring(v)
        if v:startswith('/') then
            path = v
        elseif path == '' or path:endswith('/') then
            path = path..v
        else
            path = path..'/'..v
        end
    end
    return path
end

return _M