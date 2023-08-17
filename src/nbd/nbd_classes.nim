import std/asyncdispatch
import std/asyncnet
import std/strformat
import stdx/strutils
import classes

##
## Represents information about a block device
class NBDDeviceInfo:

    ## Export name
    var name = ""

    ## Human-readable name
    var displayName = ""

    ## Human-readable description
    var displayDescription = ""

    ## Disk total size in bytes
    var size : uint64

    ## If hidden, this device will not appear in the device list but is still accessible by name
    var isHidden = false

    ## If true, this device is read-only
    var isReadOnly = false

    ## If true, this will be used as the default device if the client didn't specify which device to use.
    var isDefault = false



##
## Represents a block device
class NBDDevice:

    ## Device name
    var info : NBDDeviceInfo

    ## True if currently connected
    var connected = false

    ## Constructor
    method init(info : NBDDeviceInfo) =
        this.info = info

    ## Connect to the device. The default implementation does nothing.
    method connect() {.async.} =
        return

    ## Read data from the device
    method read(offset : uint64, length : uint32) : Future[string] {.async.} =
        raise newException(IOError, "Not implemented.")

    ## Write data to the device
    method write(offset : uint64, data : string) {.async.} =
        raise newException(IOError, "Not implemented.")

    ## Write zeroes to the device. Default implementation just calls write() with zeroes.
    method writeZeroes(offset : uint64, length : uint32) {.async.} =
        var zeroes = newString(length, filledWith = 0)
        await this.write(offset, zeroes)

    ## Check if the specified region is a "hole", meaning no data is allocated to that region. Writing data to holes could
    ## potentially cause "out of space" errors, so the client uses this to determine if that's possible for the specified
    ## region. The default implementation just returns false for everything, meaning the client will assume all regions
    ## are allocated already.
    method regionIsHole(offset : uint64, length : uint32) : Future[bool] {.async.} =
        return false

    ## Check if the specified region is filled with zeroes. True means all bytes in the region are zero, false means that
    ## the data within the region MAY have non-zero data. The default implementation just returns false for everything,
    method regionIsZero(offset : uint64, length : uint32) : Future[bool] {.async.} =
        return false

    ## Flush changes to permanent storage. Default implementation does nothing.
    method flush() {.async.} = 
        discard



## Last used connection ID
var lastConnectionId = 0

##
## Represents a single connection to the NBDServer.
class NBDConnection:

    ## The socket
    var socket : AsyncSocket

    ## Connection ID
    var connectionId : int

    ## Device this connection is currently connected to
    var device : NBDDevice = nil

    ## True if the connection is using structured replies
    var structuredReplies = false

    ## Meta contexts the client has set for this connection
    var metadataContexts : seq[string]

    ## Constructor
    method init() =
        this.connectionId = lastConnectionId
        lastConnectionId += 1

    ## Get remote IP address
    method remoteAddress() : string =
        return this.socket.getPeerAddr()[0]

    ## Log something from this connection
    method log(msg : string) =
        echo fmt"[{this.className} #{this.connectionId}] {msg}"


    ## Called when the connection is started
    method onConnectionStart() {.async.} = discard

    ## Called when the connection fails due to an error
    method onConnectionError(e : ref Exception) {.async.} = discard

    ## Called when the connection closes
    method onConnectionClose() {.async.} = discard

    ## Called when the connection starts accessing a device
    method onDeviceAccessStart(device : NBDDevice) {.async.} = discard