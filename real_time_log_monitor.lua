local args = ngx.req.get_uri_args()
local logfile = args.filename
if logfile == nil then
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local wsserver = require "resty.websocket.server"
local ffi = require "ffi"
local C = ffi.C
local fs = require "fs"
local String = require "String"
local config = require "config"
local PLATFORM = ffi.os:upper()
-- linux: 2048
-- OSX: 4
local O_NONBLOCK = config.SYSTEM[PLATFORM].O_NONBLOCK or 2048
-- inotify_add_watch
local IN_MODIFY = config.SYSTEM[PLATFORM].IN_MODIFY or 0x00000002
local chunk_size = 4096
local buffer = ffi.new('char[?]', chunk_size)

local wb, err = wsserver.new{
    timeout = config.WEBSOCKET.TIMEOUT,
    max_payload_len = config.WEBSOCKET.MAX_PAYLOAD_LEN
}

if not wb then
    ngx.log(ngx.ERR, "init websocket failed: ", err)
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- global values
-- inotify init file descriptor
local fd
-- inotify watch descriptor
local wd
-- logfile file descriptor
local file
-- push thread
local push

local function pushlog(logfile)
    local err
    local filename = fs.pathJoin(config.LOGHOME, logfile..'.log')

    file = io.open(filename, "r")
    if not file then
        ngx.log(ngx.ERR, "NO SUCH FILE:", filename)
        return ngx.exit(ngx.HTTP_NOT_FOUND)
    end

    fd = C.inotify_init1(O_NONBLOCK)
    if fd == -1 then
        err = C.strerror(ffi.errno())
        ngx.log(ngx.ERR, 'init inotify failed: ', ffi.string(err))
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    wd = C.inotify_add_watch(fd, filename:cstring(), IN_MODIFY)
    if wd == -1 then
        err = C.strerror(ffi.errno())
        ngx.log(ngx.ERR, 'inotify add watch failed: ', ffi.string(err))
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local offset = file:seek("end")
    while true do
      -- when event occur for monitored file, get the offset and filesize of monitored file
      -- then to calculate that how many bytes have been appended to monitored file and read it
      -- send to websocket client
      ngx.sleep(config.IDENTIFYCHECKINTERVAL)
      local nread = C.read(fd, buffer,chunk_size);
      nread = tonumber(nread)
      -- rtn code must be 0 or -1 or > 0
      if nread < -1 then
          err = C.strerror(ffi.errno())
          ngx.log(ngx.ERR, "fetch inotify event error: ", ffi.string(err))
          return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
      end

      if nread > 0 then
          local text = file:read("*all")
          if #text > 0 then
              local bytes, err = wb:send_text(text)
          end
      end
    end
end

local function sweep()
    local ok, err, rtn
    ok, err = ngx.thread.kill(push)
    if err then
        ngx.log(ngx.ERR, "kill push thread failed: ", err)
    end

    local ftype = io.type(file)
    if ftype == "file" then
        file:close()
    end

    rtn = C.inotify_rm_watch(fd, wd)
    if rtn ~= 0 then
        err = C.strerror(ffi.errno())
        ngx.log(ngx.ERR, "inotidy rm watch error: ", ffi.string(err))
    else
        ngx.log(ngx.ERR, "inotidy rm watch success")
    end

    rtn = C.close(fd)
    if rtn ~= 0 then
        err = C.strerror(ffi.errno())
        ngx.log(ngx.ERR, "close monitor log file error: ", ffi.string(err))
    else
        ngx.log(ngx.ERR, "close monitor log file success")
    end
end

local function keepalive()
    while true do
        local data, typ, err = wb:recv_frame()
        if wb.fatal then
            sweep()
            ngx.log(ngx.ERR, "Bad Connection: Receive frame failed.")
            return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

      -- heartbeat
      -- chrome never send ping frame
      if not data then
          local bytes, err = wb:send_ping()
          if err then
              ngx.log(ngx.ERR, "SEND PING FAILED: ", err)
          end
          ngx.log(ngx.ERR, "Ping frame send")
      end

      if typ == "close" then
          sweep()
          ngx.log(ngx.ERR, "Connection Closed")
          break
      end

      if typ == "ping" then
          local bytes, err = wb:send_pong()
          if not bytes then
              ngx.log(ngx.ERR, "PONG frame send failed: ", err)
              return ngx.exit(501)
          end
      end

      if typ == "pong" then
          ngx.log(ngx.ERR, "PONG frame received")
      end
    end
end

local ok, err = ngx.on_abort(sweep)
if not ok then
    ngx.log(ngx.ERR, "failed to register the on_abort callback: ", err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end
ngx.log(ngx.ERR, "register the on_abort callback success")
-- create push task
push = ngx.thread.spawn(pushlog, logfile)
-- heartbeat
keepalive()