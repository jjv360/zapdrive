import stdx/sequtils
import stdx/osproc
import std/asyncdispatch
import std/strformat
import std/json
import std/oids
import classes
import reactive
import ../nbd
import ../wnbd_client


## Synchronized block device. Base class for all block devices.
class ZDDevice of NBDBlockDevice:

    ## Universally Unique ID
    var uuid = ""

    ## Provider name
    var provider = ""

    ## Client connection
    var wnbdClient : WNBDClient = nil

    ## True if the drive has been initialized (or at least requested to do so) at least once
    var hasInitializedDisk = false

    ## Connection URL
    var connectionURL = ""

    ## Get status text
    method status() : string =
        if this.connections.len > 0:
            return "Connected"
        else:
            return "Disconnected"

    ## Called when a connection is made to this device.
    method connect() {.async.} =
        await super.connect()

        # Start stats logging
        asyncCheck this.startStatsLogging()

        # Only do this once per disk
        if this.hasInitializedDisk: return
        this.hasInitializedDisk = true

        # Fetch the first 8KB of data from the device
        var data = await this.read(0, 8192)

        # Stop if non-zero data was returned
        if not data.allZero:
            return

        # Device is not initialized, initialize it by opening Disk Management. This automatically shows
        # some UI to initialize the disk if Windows sees an uninitialized disk.
        when defined(windows):
            asyncCheck execElevatedAsync("diskmgmt.msc")


    ## True if the stats loop is running
    var statLoopRunning = false
    
    ## Logs drive status constantly
    method startStatsLogging() {.async.} =

        # Stop if already active
        if this.statLoopRunning: return
        this.statLoopRunning = true

        # Log stats every second
        var state = ""
        while true:

            # Update state
            let newState = "[ZDDevice] Stats: " & this.debugStats()
            if newState != state:
                echo newState
                state = newState

            # Wait a bit
            await sleepAsync(250)


        # Done
        this.statLoopRunning = false


    ## Fetch debug stats for this device
    method debugStats() : string =
        let superStats = super.debugStats()
        return fmt"id={this.uuid} {superStats}"


    ## Called to check if a file exists
    method fileExists(path : string) : Future[bool] {.async.} =
        raiseAssert("fileExists() not implemented")

    
    ## Called to read a file
    method readFile(path : string) : Future[string] {.async.} =
        raiseAssert("readFile() not implemented")


    ## Called to write a file
    method writeFile(path : string, data : string) : Future[void] {.async.} =
        raiseAssert("writeFile() not implemented")


    ## Called to delete a file
    method deleteFile(path : string) : Future[void] {.async.} =
        raiseAssert("deleteFile() not implemented")
    

    ## Check if a block exists
    method blockExists(offset : uint64) : Future[bool] {.async.} =
        let path = "blocks/" & $offset & ".blk"
        return await this.fileExists(path)


    ## Read a block from permanent storage
    method readBlock(offset : uint64) : Future[string] {.async.} =
        let path = "blocks/" & $offset & ".blk"
        return await this.readFile(path)


    ## Write a block to permanent storage
    method writeBlock(offset : uint64, data : string) : Future[void] {.async.} =
        let path = "blocks/" & $offset & ".blk"
        await this.writeFile(path, data)


    ## Delete a block from permanent storage
    method deleteBlock(offset : uint64) : Future[void] {.async.} =
        let path = "blocks/" & $offset & ".blk"
        await this.deleteFile(path)


    ## Connect to the underlying storage
    method connectStorage() {.async.} =
        raiseAssert("connectStorage() not implemented")


    ## Load disk information
    method loadDiskInfo() {.async.} =

        # Check if disk properties exist
        let exists = await this.fileExists("disk.props")
        if not exists: 
            await this.createDiskInfo()

        # Read disk properties
        var diskProps = await this.readFile("disk.props")
        let diskInfo = diskProps.parseJson()

        # Store info
        this.uuid = diskInfo["uuid"].str
        this.blockSize = diskInfo["blockSize"].getInt().uint64
        if this.info == nil: this.info = NBDDeviceInfo.init()
        this.info.name = this.uuid
        this.info.displayName = diskInfo["name"].str
        this.info.displayDescription = diskInfo["description"].str
        this.info.size = diskInfo["size"].getInt().uint64


    ## Create disk information
    method createDiskInfo() {.async.} =

        # Generate UUID if none exists
        if this.uuid == "":
            this.uuid = $genOid()

        # Create info
        let info = %* {
            "uuid": this.uuid,
            "name": "ZapDrive Device",
            "description": "",
            "size": 1024 * 1024 * 1024 * 2,
            "blockSize": 1024 * 1024 * 8,
            "format": "raw"
        }

        # Save it
        await this.writeFile("disk.props", info.pretty(4))