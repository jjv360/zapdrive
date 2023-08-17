import std/asyncdispatch
import std/oids
import std/strformat
import std/strutils
import std/os
import std/asyncfile
import classes
import reactive
import ../nbd
import ./basedrive

## A file disk. This drive saves blocks to a folder on the user's device.
class ZDFileDisk of ZDDevice:

    ## Root path to the drive folder
    var folder = ""

    ## Create a new memory disk.
    method createNew(path : string) : Future[ZDDevice] {.static, async.} =

        # TODO: Read disk info from file

        # Create it
        let drive = ZDFileDisk().init()
        drive.folder = absolutePath(path)
        drive.uuid = "file-" & $genOid()
        drive.info = NBDDeviceInfo.init()
        drive.info.name = drive.uuid
        drive.info.displayName = "File Disk"
        drive.info.displayDescription = "Sparse file disk."
        drive.info.size = 1024 * 1024 * 1024 * 32
        return drive
    

    ## Check if a block exists
    method blockExists(offset : uint64) : Future[bool] {.async.} =

        # Check if block exists
        let path = this.folder / "blocks" / ($offset & ".blk")

        # Check if exists
        return fileExists(path)


    ## Read a block from permanent storage
    method readBlock(offset : uint64) : Future[string] {.async.} =

        # Open file
        let path = this.folder / "blocks" / ($offset & ".blk")
        let file = openAsync(path, fmRead)
        defer: file.close()

        # Return file content
        return await file.readAll()


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
        return fmt"type=mem usage={memoryUsage} {superStats}"
