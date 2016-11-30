local _M = {
    WEBSOCKET = {
        TIMEOUT = 5000,
        MAX_PAYLOAD_LEN = 65535
    },
    SYSTEM = {
        LINUX = {
            SEEK_END = 2,
            O_NONBLOCK = 2048,
            IN_MODIFY = 0x00000002
        }
    },
    LOGHOME = '/var/log',
    IDENTIFYCHECKINTERVAL = 0.5
}
