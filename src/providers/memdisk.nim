import std/asyncdispatch
import std/oids
import std/strformat
import stdx/strutils
import classes
import reactive
import ../nbd
import ./basedrive

## Last used ID
var LastID = 1

## A memory disk. This drive is lost once it is removed.
class ZDMemoryDisk of ZDDevice:
    
    ## Blocks
    var blocks : seq[tuple[offset : uint64, data : string]]


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
        drive.info.size = 1024 * 1024 * 512
        return drive
    

    ## Check if a block exists
    method blockExists(offset : uint64) : Future[bool] {.async.} =

        # Check blocks
        for blk in this.blocks:
            if blk.offset == offset:
                return true

        # Not found
        return false


    ## Read a block from permanent storage
    method readBlock(offset : uint64) : Future[string] {.async.} =

        # Check blocks
        for blk in this.blocks:
            if blk.offset == offset:
                return blk.data

        # Not found, return blank zeros. Missing blocks are just "holes" of zeros.
        return newString(this.blockSize, filledWith = 0)


    ## Write a block to permanent storage
    method writeBlock(offset : uint64, data : string) : Future[void] {.async.} =
    
        # Remove existing block
        for i in 0 ..< this.blocks.len:
            if this.blocks[i].offset == offset:
                this.blocks.del(i)
                break

        # Add new data
        this.blocks.add(( offset, data ))


    ## Delete a block from permanent storage
    method deleteBlock(offset : uint64) : Future[void] {.async.} =
    
        # Remove existing block
        for i in 0 ..< this.blocks.len:
            if this.blocks[i].offset == offset:
                this.blocks.del(i)
                break


    ## Fetch debug stats for this device
    method debugStats() : string =
        let superStats = super.debugStats()
        let memoryUsage = formatSize(this.blocks.len * this.blockSize.int)
        return fmt"{superStats} type=mem usage={memoryUsage}"
