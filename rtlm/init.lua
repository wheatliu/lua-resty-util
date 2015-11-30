ffi  = require "ffi"
local meta = ngx.shared.meta
local cjson = require "cjson"
ffi.cdef[[
        typedef signed char     int8_t;
        typedef unsigned char   uint8_t;
        typedef signed int  int16_t;
        typedef unsigned int    uint16_t;
        typedef signed long int     int32_t;
        typedef unsigned long int   uint32_t;
        typedef signed long long int    int64_t;
        typedef unsigned long long int  uint64_t;
        typedef unsigned long long int  uint64_t;
        typedef int mode_t;
        typedef long int __off64_t;
        typedef __off64_t off_t;
        typedef long int ssize_t;

        int open(const char * pathname, int flags);
        int close(int fd);
        off_t lseek(int fildes, off_t offset, int whence);
        ssize_t read(int fd, void * buf, size_t count);

        int inotify_init(void);
        int inotify_init1(int flags);
        int inotify_add_watch(int fd, const char *pathname, uint32_t mask);
        int inotify_rm_watch(int fd, int wd);
        int close(int fd);
]]

local SEEK_END = 2
local PLATFORM = ffi.os
local O_NONBLOCK
-- linux: 2048
-- OSX: 4
if PLATFORM == "Linux" then
    O_NONBLOCK = 2048
elseif PLATFORM == "OSX" then
    O_NONBLOCK = 4
end

local IN_MODIFY = 0x00000002
local chunk_size = 4096
local buffer = ffi.new('char[?]', chunk_size)
local logitems = {"kernel", "solr", "mail"}

for i=1, #logitems do
    local dict = {}
    local item = logitems[i]
    local filename = "/var/log/"..item..".log"
    local cfilename = ffi.new("char["..#filename+1 .."]", filename)
    local fd = ffi.C.open(cfilename, O_NONBLOCK)
    local errno = ffi.errno()
    local ifd = ffi.C.inotify_init1(O_NONBLOCK)
    local wd = ffi.C.inotify_add_watch(ifd, cfilename, IN_MODIFY)
    if (fd ~= -1) and (ifd ~= -1) and (wd ~= -1) then
        dict.filename = filename
        dict.fd = fd
        dict.ifd = ifd
        dict.wd = wd
        data = cjson.encode(dict)
        success, err, forcible = meta:set(item, data)
        if success then
            local gdata = meta:get(item)
                ngx.log(ngx.ERR, "dict is: ", gdata)
        else
            ngx.log(ngx.ERR, "err is: ", err)
        end
    else
        ngx.log(ngx.ERR, "Failed to open log file: ", filename)
        ngx.log(ngx.ERR, "Return errno is: ", errno)
    end
end
