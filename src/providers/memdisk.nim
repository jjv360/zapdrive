import std/asyncdispatch
import std/oids
import classes
import reactive
import ../nbd
import ./basedrive

## Last used ID
var LastID = 1

## A memory disk. This drive is lost once it is removed.
class ZDMemoryDisk of ZDDevice:
    
    ## Blocks
    var blocks : seq[tuple[offset : uint64, data : seq[uint8]]]



    ## Create a new memory disk.
    method createNew() : Future[ZDDevice] {.static, async.} =

        ## Ask user for size
        alert("Enter size in MB:", "New RAM disk", dlgQuestion)

        # Create it
        let drive = ZDMemoryDisk().init()
        drive.uuid = "ramdisk-" & $genOid()
        drive.info = NBDDeviceInfo.init()
        drive.info.name = drive.uuid
        drive.info.displayName = "RAM Disk #" & $LastID
        drive.info.displayDescription = "Temporary memory drive."
        drive.info.size = 1024*1024*4
        return drive