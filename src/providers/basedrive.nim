import stdx/sequtils
import stdx/osproc
import std/asyncdispatch
import std/strformat
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

    ## Get status text
    method status() : string =
        if this.connected:
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
        return fmt"id={this.uuid} unstable={this.currentUnstableBlocks} saving={this.currentSavingBlocks} loading={this.currentLoadingBlocks} ops={this.currentBlockOperations}"