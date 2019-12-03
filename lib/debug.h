/* Misc. define values to string conversion helpers */
char* rtm_to_string(int code);
char* tca_to_string(uint16_t type);
char* netlink_to_string(int prototol);

/* Socket related helpers */
void dbg_sock_dump_msghdr(const struct msghdr *msg);
void dbg_sock_dump_iovec(struct iovec *iovec);
ssize_t dbg_sock_send(int fd, const void *buf, size_t size, int flags, const char* caller);
ssize_t dbg_sock_sendmsg(int fd, const struct msghdr *msg, int flags, const char* caller);

/* Binary data conversion */
void Bin2Hex(char *dest, int sizeof_dest, const uint8_t *src, int len, uint32_t PrintFlags);
void LogBuffer(char *Message, const uint8_t* pData, int DataSize);

/* Misc. socket related macros (used for debugging purposes) */
#define SOCK_SEND(fd, buf, size, flags) dbg_sock_send(fd, buf, size, flags, __FUNCTION__)
#define SOCK_SENDMSG(fd, msg, flags) dbg_sock_sendmsg(fd, msg, flags, __FUNCTION__)


