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
        drive.info.size = 1024 * 1024 * 512
        return drive
    

    ## Check if a block exists
    method blockExists(offset : uint64) : Future[bool] {.async.} =

        # Simulate network slowness
        # await sleepAsync(1000)

        # Check blocks
        for blk in this.blocks:
            if blk.offset == offset:
                return true

        # Not found
        return false


    ## Read a block from permanent storage
    method readBlock(offset : uint64) : Future[seq[uint8]] {.async.} =

        # Simulate network slowness
        await sleepAsync(4000)

        # Check blocks
        for blk in this.blocks:
            if blk.offset == offset:
                return blk.data

        # Not found, return blank zeros. Missing blocks are just "holes" of zeros.
        return newSeq[uint8](this.blockSize)


    ## Write a block to permanent storage
    method writeBlock(offset : uint64, data : seq[uint8]) : Future[void] {.async.} =

        # Simulate network slowness
        await sleepAsync(4000)
    
        # Remove existing block
        for i in 0 ..< this.blocks.len:
            if this.blocks[i].offset == offset:
                this.blocks.del(i)
                break

        # Add new data
        this.blocks.add(( offset, data ))


    ## Delete a block from permanent storage
    method deleteBlock(offset : uint64) : Future[void] {.async.} =

        # Simulate network slowness
        await sleepAsync(1000)
    
        # Remove existing block
        for i in 0 ..< this.blocks.len:
            if this.blocks[i].offset == offset:
                this.blocks.del(i)
                break