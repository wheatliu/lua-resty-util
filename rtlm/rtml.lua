local wsserver = require "resty.websocket.server"
local lstat = require "posix.sys.stat"
local cjson = require "cjson"
local meta = ngx.shared.meta
local args = ngx.req.get_uri_args()
local logitem = args.item
if logitem == nil then
    ngx.log(ngx.ERR, "error arg of item")
    ngx.exit(413)
end

local fmeta = meta:get(logitem)
if fmeta == nil then
    ngx.log(ngx.ERR, "file init failed")
    ngx.exit(413)
end
local fmeta = cjson.decode(fmeta)

local wb, err = wsserver.new{
    timeout = 5000,
    max_payload_len = 65535,
}
if not wb then
    ngx.log(ngx.ERR, "Failed to new websocket: ", err)
    return ngx.exit(444)
end

local function send_logs()
    local fd = fmeta.fd
    local ifd = fmeta.ifd
    local filename = fmeta.filename
    local cfilename = ffi.new("char["..#filename+1 .."]", filename)
    local chunk_size = 4096
    local SEEK_END = 2
    local buffer = ffi.new('char[?]', chunk_size)
    local offset = ffi.C.lseek(fd, 0, SEEK_END)
    offset = tonumber(offset)

    while true do
    --  when event occur for monitored file, get the offset and filesize of monitored file
    --  then to calculate that how many bytes have been appended to monitored file and read it
    --  send to websocket client
        ngx.sleep(0.01)
        local nread = ffi.C.read(ifd, buffer,chunk_size);
        nread = tonumber(nread)
        if nread >0 then
            local rtn = lstat.stat(filename)
            if rtn ~= -1 then
                local cursor = rtn.st_size
                local nappend = cursor - offset
                if nappend > 0 then
                    local readbuffer = ffi.new('char[?]', nappend)
                    local nbytes, err = ffi.C.read(fd, readbuffer, nappend)
                    offset = cursor
                    if nbytes > 0 then
                        local text = ffi.string(readbuffer,nbytes)
                        local bytes, err = wb:send_text(text)
                    else
                        ngx.log(ngx.ERR, "send data failed")
                    end
                else
                    ngx.log(ngx.ERR, "no data append")
                end
            else
                ngx.log(ngx.ERR, "get file size failed")
            end
        elseif nread < -1 then
            ngx.log(ngx.ERR, "get event failed")
            break
    end
    end
end

local tsend = ngx.thread.spawn(send_logs)

while true do
    local data, typ, err = wb:recv_frame()
    if not data then
        ngx.log(ngx.ERR, "failed to receive a frame: ", err)
       -- return ngx.exit(444)
    end

    if typ == "close" then
        -- send a close frame back:
        local bytes, err = wb:send_close(1000, "enough, enough!")
        if not bytes then
            ngx.log(ngx.ERR, "failed to send the close frame: ", err)
            return
        end
        local code = err
        ngx.log(ngx.INFO, "closing with status code ", code, " and message ", data)
        return
    end

    if typ == "ping" then
        -- send a pong frame back:
        local bytes, err = wb:send_pong(data)
        if not bytes then
            ngx.log(ngx.ERR, "failed to send frame: ", err)
            -- return
        end
    elseif typ == "pong" then
        -- just discard the incoming pong frame
        ngx.log(ngx.ERR, "received a frame of type pong")
    else
        ngx.log(ngx.ERR, "received a frame of type ", typ, " and payload ", data)
    end
end
