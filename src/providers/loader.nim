import std/json
import std/asyncdispatch
import std/uri
import std/oids
import ./basedrive
import ./memdisk
import ./filedisk

## Load a disk from the specified configuration info
proc loadFromURL*(_: typedesc[ZDDevice], url : string) : Future[ZDDevice] {.async.} =

    # Parse Uri
    let uri = parseUri(url)

    # Create device of the correct type
    var device : ZDDevice = nil
    if uri.scheme == "file": 
        
        # A disk backed up to a local file
        device = ZDFileDisk.init()

    # Stop if not found
    if device == nil:
        raise newException(IOError, "Unknown device type '" & deviceType & "'")

    # Connect to the backend storage
    device.connectionURL = url
    await device.connectStorage()

    # Allow it to load disk info
    await device.loadDiskInfo()

    # Done
    return device

## Create a new disk of the specified type
proc createNew*(_: typedesc[ZDDevice], deviceType : string) : Future[ZDDevice] {.async.} =

    # Check drive type
    var device : ZDDevice = nil
    if deviceType == "ram": 
        
        # A temporary RAM disk
        device = ZDMemoryDisk.init()
        device.connectionURL = "ram://" & $genOid()

    elif deviceType == "file": 
        
        # A disk backed up to a local file
        device = ZDFileDisk.init()
        device.connectionURL = "file:///" & ("C:/Users/jjv36/Desktop/FileDisk.vhd")

    else: 

        # Unknown disk type
        raise newException(IOError, "Unknown drive type: " & deviceType)

    # Connect to the backend storage
    await device.connectStorage()

    # Allow it to load disk info
    await device.loadDiskInfo()

    # Done
    return device