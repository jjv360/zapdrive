import std/asyncdispatch
import std/strformat
import stdx/strutils
import std/tables
import classes
import reactive
import ../nbd
import ./basedrive

## A memory disk. This drive is lost once it is removed.
class ZDMemoryDisk of ZDDevice:
    
    ## Memory files
    var files : Table[string, string]


    ## Called to check if a file exists
    method fileExists(path : string) : Future[bool] {.async.} =
        return this.files.hasKey(path)

    
    ## Called to read a file
    method readFile(path : string) : Future[string] {.async.} =
        return this.files[path]


    ## Called to write a file
    method writeFile(path : string, data : string) : Future[void] {.async.} =
        this.files[path] = data


    ## Called to delete a file
    method deleteFile(path : string) : Future[void] {.async.} =
        this.files.del(path)


    ## Fetch debug stats for this device
    method debugStats() : string =
        let superStats = super.debugStats()

        # Get memory usage
        var usage = 0
        for v in this.files.values: usage += v.len
        let memoryUsage = formatSize(usage)
        return fmt"{superStats} type=mem usage={memoryUsage}"


    ## Connect to the underlying storage, which for a mem disk does nothing
    method connectStorage() {.async.} =
        discard
