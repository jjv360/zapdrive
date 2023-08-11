import std/asyncdispatch
import classes
import ./nbd


## NBDServer which connects to our server
singleton ZapDriveNBDServer of NBDServer:

    ## Open a block device
    method openDevice(deviceInfo : NBDDeviceInfo) : Future[NBDDevice] {.async.} =
        return NBDMemoryDevice.init(deviceInfo)

    ## Create fake list of devices
    method listDevices() : Future[seq[NBDDeviceInfo]] {.async.} =

        # Device 1
        var dev1 = NBDDeviceInfo.init()
        dev1.name = "dev1"
        dev1.displayName = "Device 1"
        dev1.displayDescription = "This is device 1"
        dev1.size = 1024*1024*1024*4
        dev1.isDefault = true

        # Device 2
        var dev2 = NBDDeviceInfo.init()
        dev2.name = "dev2"
        dev2.displayName = "Device 2"
        dev2.displayDescription = "This is device 2"
        dev2.size = 1024*1024*128

        # Return list of devices
        return @[dev1, dev2]


# Export NBD so that superclass functions are available
export nbd