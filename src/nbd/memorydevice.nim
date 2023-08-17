import std/asyncdispatch
import stdx/strutils
import classes
import ./nbd_classes

##
## Test device which create a simple memory device with a given size
class NBDMemoryDevice of NBDDevice:

    ## The memory
    var memory : string

    ## Constructor
    method init(info : NBDDeviceInfo) =
        super.init(info)
        this.memory = newString(info.size, filledWith = 0)

    ## Read data from the device
    method read(offset : uint64, length : uint32) : Future[string] {.async.} =
        return this.memory[offset ..< offset + length]

    ## Write data to the device
    method write(offset : uint64, data : string) {.async.} =
        this.memory[offset ..< offset + data.len.uint64] = data

    ## Check for zeroes in the data
    method regionIsZero(offset : uint64, length : uint32) : Future[bool] {.async.} =

        # Check each byte, stop if a non-zero is found
        for i in offset ..< offset + length:
            if this.memory[i].int != 0:
                return false

        # No non-zero found
        return true
