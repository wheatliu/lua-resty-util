-- init_by_lua_file fficdef.lua;
local ffi = require "ffi"

ffi.cdef[[

    typedef signed char int8_t;
    typedef unsigned char uint8_t;
    typedef signed int int16_t;
    typedef unsigned int uint16_t;
    typedef signed long int int32_t;
    typedef unsigned long int uint32_t;
    typedef signed long long int int64_t;
    typedef unsigned long long int uint64_t;
    typedef unsigned long long int uint64_t;
    typedef long int ssize_t;
    typedef unsigned char       u_char;
    typedef unsigned int        mode_t;
    typedef long int            intptr_t;
    typedef unsigned long int   uintptr_t;
    typedef int                 intptr_t;
    typedef unsigned int        uintptr_t;
    typedef int               ngx_err_t;
    typedef intptr_t          ngx_int_t;
    typedef uintptr_t         ngx_uint_t;
    typedef intptr_t          ngx_flag_t;

    typedef long long unsigned int dev_t;
    typedef long unsigned int ino_t;
    typedef unsigned int mode_t;
    typedef unsigned int nlink_t;
    typedef unsigned int uid_t;
    typedef unsigned int gid_t;
    typedef long int off_t;
    typedef long int blksize_t;
    typedef long int blkcnt_t;
    typedef long int _time_t;

    struct timespec {
        _time_t tv_sec;
        long    tv_nsec;
    };

    struct stat {
        unsigned long   st_dev;
        unsigned long   st_ino;
        unsigned long   st_nlink;
        unsigned int    st_mode;
        unsigned int    st_uid;
        unsigned int    st_gid;
        unsigned int    __pad0;
        unsigned long   st_rdev;
        long            st_size;
        long            st_blksize;
        long            st_blocks;
        unsigned long   st_atime;
        unsigned long   st_atime_nsec;
        unsigned long   st_mtime;
        unsigned long   st_mtime_nsec;
        unsigned long   st_ctime;
        unsigned long   st_ctime_nsec;
        long            __unused[3];
    };

    int open(const char * pathname, int flags);
    int close(int fd);
    off_t lseek(int fildes, off_t offset, int whence);
    ssize_t read(int fd, void * buf, size_t count);

    int inotify_init(void);
    int inotify_init1(int flags);
    int inotify_add_watch(int fd, const char *pathname, uint32_t mask);
    int inotify_rm_watch(int fd, int wd);
    int memcmp(const void *s1, const void *s2, size_t n);
    char *strerror(int errnum);
    char *dirname(char *path);
    char *basename(char *path);
    int access(const char *pathname, int mode);
    long syscall(int number, ...);
    ngx_err_t ngx_create_full_path(u_char *dir, ngx_uint_t access);
]]