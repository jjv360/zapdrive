

## List of constants ... see https://github.com/NetworkBlockDevice/nbd/blob/master/nbd.h and https://github.com/NetworkBlockDevice/nbd/blob/master/doc/proto.md

# Handshake flags
const NBD_FLAG_FIXED_NEWSTYLE       * {.used.} : uint = (1 shl 0)
const NBD_FLAG_C_FIXED_NEWSTYLE     * {.used.} : uint = (1 shl 0)
const NBD_FLAG_C_NO_ZEROES          * {.used.} : uint = (1 shl 1)

# Option names
const NBD_OPT_EXPORT_NAME           * {.used.} : uint = 1
const NBD_OPT_ABORT                 * {.used.} : uint = 2
const NBD_OPT_LIST                  * {.used.} : uint = 3
const NBD_OPT_PEEK_EXPORT           * {.used.} : uint = 4
const NBD_OPT_STARTTLS              * {.used.} : uint = 5
const NBD_OPT_INFO                  * {.used.} : uint = 6
const NBD_OPT_GO                    * {.used.} : uint = 7
const NBD_OPT_STRUCTURED_REPLY      * {.used.} : uint = 8
const NBD_OPT_LIST_META_CONTEXT     * {.used.} : uint = 9
const NBD_OPT_SET_META_CONTEXT      * {.used.} : uint = 10
const NBD_OPT_EXTENDED_HEADERS      * {.used.} : uint = 11

# Option replies
const NBD_REP_ACK                   * {.used.} : uint = 1
const NBD_REP_SERVER                * {.used.} : uint = 2
const NBD_REP_INFO                  * {.used.} : uint = 3
const NBD_REP_META_CONTEXT          * {.used.} : uint = 4
const NBD_REP_ERR_UNSUP             * {.used.} : uint = (1 shl 31 + 1)
const NBD_REP_ERR_POLICY            * {.used.} : uint = (1 shl 31 + 2)
const NBD_REP_ERR_INVALID           * {.used.} : uint = (1 shl 31 + 3)
const NBD_REP_ERR_PLATFORM          * {.used.} : uint = (1 shl 31 + 4)
const NBD_REP_ERR_TLS_REQD          * {.used.} : uint = (1 shl 31 + 5)
const NBD_REP_ERR_UNKNOWN           * {.used.} : uint = (1 shl 31 + 6)
const NBD_REP_ERR_SHUTDOWN          * {.used.} : uint = (1 shl 31 + 7)
const NBD_REP_ERR_BLOCK_SIZE_REQD   * {.used.} : uint = (1 shl 31 + 8)
const NBD_REP_ERR_TOO_BIG           * {.used.} : uint = (1 shl 31 + 9)
const NBD_REP_ERR_EXT_HEADER_REQD   * {.used.} : uint = (1 shl 31 + 10)

# Info replies
const NBD_INFO_EXPORT               * {.used.} : uint = 0
const NBD_INFO_NAME                 * {.used.} : uint = 1
const NBD_INFO_DESCRIPTION          * {.used.} : uint = 2
const NBD_INFO_BLOCK_SIZE           * {.used.} : uint = 3

# Transmission flags
const NBD_REQUEST_MAGIC             * {.used.} : uint = 0x25609513u
const NBD_FLAG_HAS_FLAGS            * {.used.} : uint = (1 shl 0)
const NBD_FLAG_READ_ONLY            * {.used.} : uint = (1 shl 1)
const NBD_FLAG_SEND_FLUSH           * {.used.} : uint = (1 shl 2)
const NBD_FLAG_SEND_FUA             * {.used.} : uint = (1 shl 3)
const NBD_FLAG_ROTATIONAL           * {.used.} : uint = (1 shl 4)
const NBD_FLAG_SEND_TRIM            * {.used.} : uint = (1 shl 5)
const NBD_FLAG_SEND_WRITE_ZEROES    * {.used.} : uint = (1 shl 6)
const NBD_FLAG_SEND_DF              * {.used.} : uint = (1 shl 7)
const NBD_FLAG_CAN_MULTI_CONN       * {.used.} : uint = (1 shl 8)
const NBD_FLAG_SEND_RESIZE          * {.used.} : uint = (1 shl 9)
const NBD_FLAG_SEND_CACHE           * {.used.} : uint = (1 shl 10)
const NBD_FLAG_SEND_FAST_ZERO       * {.used.} : uint = (1 shl 11)
const NBD_FLAG_BLOCK_STATUS_PAYLOAD * {.used.} : uint = (1 shl 12)

# Transmission commands
const NBD_SIMPLE_REPLY_MAGIC        * {.used.} : uint32 = 0x67446698u32
const NBD_STRUCTURED_REPLY_MAGIC    * {.used.} : uint32 = 0x668e33efu32
const NBD_CMD_READ                  * {.used.} : uint16 = 0
const NBD_CMD_WRITE                 * {.used.} : uint16 = 1
const NBD_CMD_DISC                  * {.used.} : uint16 = 2
const NBD_CMD_FLUSH                 * {.used.} : uint16 = 3
const NBD_CMD_TRIM                  * {.used.} : uint16 = 4
const NBD_CMD_CACHE                 * {.used.} : uint16 = 5
const NBD_CMD_WRITE_ZEROES          * {.used.} : uint16 = 6
const NBD_CMD_BLOCK_STATUS          * {.used.} : uint16 = 7
const NBD_CMD_RESIZE                * {.used.} : uint16 = 8

# Transmission command flags
const NBD_CMD_FLAG_FUA              * {.used.} : uint16 = (1 shl 0)
const NBD_CMD_FLAG_NO_HOLE          * {.used.} : uint16 = (1 shl 1)
const NBD_CMD_FLAG_DF               * {.used.} : uint16 = (1 shl 2)
const NBD_CMD_FLAG_REQ_ONE          * {.used.} : uint16 = (1 shl 3)
const NBD_CMD_FLAG_FAST_ZERO        * {.used.} : uint16 = (1 shl 4)

# Transmission errors
const NBD_EPERM                     * {.used.} : uint32 = 1
const NBD_EIO                       * {.used.} : uint32 = 5
const NBD_ENOMEM                    * {.used.} : uint32 = 12
const NBD_EINVAL                    * {.used.} : uint32 = 22
const NBD_ENOSPC                    * {.used.} : uint32 = 28
const NBD_EOVERFLOW                 * {.used.} : uint32 = 75
const NBD_ENOTSUP                   * {.used.} : uint32 = 95
const NBD_SHUTDOWN                  * {.used.} : uint32 = 108

# Transmission structured reply flags
const NBD_REPLY_FLAG_DONE           * {.used.} : uint16 = (1 shl 0)

# Transmission reply types
const NBD_REPLY_TYPE_NONE           * {.used.} : uint16 = 0
const NBD_REPLY_TYPE_OFFSET_DATA    * {.used.} : uint16 = 1
const NBD_REPLY_TYPE_OFFSET_HOLE    * {.used.} : uint16 = 2
const NBD_REPLY_TYPE_BLOCK_STATUS   * {.used.} : uint16 = 5
const NBD_REPLY_TYPE_ERROR          * {.used.} : uint16 = (1 shl 15) + 1
const NBD_REPLY_TYPE_ERROR_OFFSET   * {.used.} : uint16 = (1 shl 15) + 2

# base:allocation flags
const NBD_STATE_HOLE                * {.used.} : uint32 = (1 shl 0)
const NBD_STATE_ZERO                * {.used.} : uint32 = (1 shl 1)

## Caused by the client requesting a soft disconnect.
type NBDDisconnect* = object of IOError