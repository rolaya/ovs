/* Misc. define values to string conversion helpers */
char* rtm_to_string(int code);
char* tca_to_string(uint16_t type);
char* netlink_to_string(int prototol);
char* ovs_vport_type_to_string(int type);

/* Socket related helpers */
void dbg_sock_dump_msghdr(const struct msghdr *msg);
void dbg_sock_dump_iovec(struct iovec *iovec);
ssize_t dbg_sock_send(int fd, const void *buf, size_t size, int flags, const char* caller);
ssize_t dbg_sock_sendmsg(int fd, const struct msghdr *msg, int flags, const char* caller);
ssize_t dbg_sock_recv(int fd, void *buf, size_t size, int flags, const char* caller);
ssize_t dbg_sock_recvmsg(int fd, struct msghdr *message, int flags, const char* caller);
ssize_t dbg_sock_recvfrom (int fd, void *__restrict buf, size_t size, int flags, __SOCKADDR_ARG addr, socklen_t *__restrict addr_len, const char* caller);
int dbg_sock_recvmmsg (int fd, struct mmsghdr *vmessages, unsigned int vlen, int flags, struct timespec *tmo, const char* caller);

/* Binary data conversion */
void Bin2Hex(char *dest, int sizeof_dest, const uint8_t *src, int len, uint32_t PrintFlags);
void LogBuffer(char *Message, const uint8_t* pData, int DataSize);

#ifdef DEBUG_SOCKET_IO

/* Misc. socket related macros (used for debugging purposes) */
#define SOCK_SEND(fd, buf, size, flags) dbg_sock_send(fd, buf, size, flags, __FUNCTION__)
#define SOCK_SENDMSG(fd, msg, flags) dbg_sock_sendmsg(fd, msg, flags, __FUNCTION__)

#define SOCK_RECV(fd, buf, size, flags) dbg_sock_recv(fd, buf, size, flags, __FUNCTION__)
#define SOCK_RECVMSG(fd, message, flags) dbg_sock_recvmsg(fd, message, flags, __FUNCTION__)
#define SOCK_RECVFROM(fd, buf, size, flags, addr, addr_len) dbg_sock_recvfrom(fd, buf, size, flags, addr, addr_len, __FUNCTION__)
#define SOCK_RECVMMSG(fd, vmessages, vlen, flags, tmo) dbg_sock_recvmmsg(fd, vmessages, vlen, flags, tmo, __FUNCTION__)

#else

/* Misc. socket related macros (used for debugging purposes) */
#define SOCK_SEND(fd, buf, size, flags) send(fd, buf, size, flags)
#define SOCK_SENDMSG(fd, msg, flags) sendmsg(fd, msg, flags)

#define SOCK_RECV(fd, buf, size, flags) recv(fd, buf, size, flags)
#define SOCK_RECVMSG(fd, message, flags) recvmsg(fd, message, flags)
#define SOCK_RECVFROM(fd, buf, size, flags, addr, addr_len) recvfrom(fd, buf, size, flags, addr, addr_len)
#define SOCK_RECVMMSG(fd, vmessages, vlen, flags, tmo) recvmmsg(fd, vmessages, vlen, flags, tmo)

#endif
