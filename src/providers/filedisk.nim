import std/asyncdispatch
import std/strformat
import std/strutils
import std/os
import std/asyncfile
import std/uri
import classes
import reactive
import ../nbd
import ./basedrive

## A file disk. This drive saves blocks to a folder on the user's device.
class ZDFileDisk of ZDDevice:

    ## Root path to the drive folder
    var folder = ""
    
    ## Called to check if a file exists
    method fileExists(path : string) : Future[bool] {.async.} =
        return fileExists(this.folder / path)

    
    ## Called to read a file
    method readFile(path : string) : Future[string] {.async.} =
    
        # Open file
        let fullpath = this.folder / path
        let file = openAsync(fullpath, fmRead)
        defer: file.close()

        # Return file content
        return await file.readAll()


    ## Called to write a file
    method writeFile(path : string, data : string) : Future[void] {.async.} =

        # Ensure folder exists
        let fullpath = this.folder / path
        discard existsOrCreateDir(fullpath.parentDir())
    
        # Open file
        let file = openAsync(fullpath, fmWrite)
        defer: file.close()

        # Write file content
        await file.write(data)


    ## Called to delete a file
    method deleteFile(path : string) : Future[void] {.async.} =
    
        # Remove existing block
        let fullpath = this.folder / path
        if fileExists(fullpath):
            removeFile(fullpath)


    ## Fetch debug stats for this device
    method debugStats() : string =
        let superStats = super.debugStats()
        return fmt"{superStats} type=file"


    ## Connect to the underlying storage
    method connectStorage() {.async.} =

        # Get path and strip leading slash
        var uri = parseUri(this.connectionURL)
        var path = uri.path
        if path.startsWith("/"):
            path = path[1 ..< ^0]
        
        # Ensure blocks folder exists
        this.folder = absolutePath(path)
        echo "[FileDisk] Connecting to path: " & this.folder
        discard existsOrCreateDir(this.folder)
