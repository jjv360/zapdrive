import std/asyncdispatch
import classes
import ../nbd
import ./basedrive


## NBDServer which connects to our server
singleton ZapDriveServer of NBDServer:

    ## List of devices
    var devices : seq[ZDDevice]

    ## Add a new drive
    method addDevice(device : ZDDevice) =
        this.devices.add(device)

    ## Get the device with the specified UUID
    method getDevice(uuid : string) : ZDDevice =
        for device in this.devices:
            if device.uuid == uuid:
                return device
        return nil

    ## Open a block device
    method openDevice(deviceInfo : NBDDeviceInfo) : Future[NBDDevice] {.async.} =

        # Find device
        for device in this.devices:
            if device.uuid == deviceInfo.name:

                # Connect to it, in case it isn't connected yet
                await device.connect()

                # Return device
                return device

        # Not found
        return nil
    

    ## Create fake list of devices
    method listDevices() : Future[seq[NBDDeviceInfo]] {.async.} =

        # Create list of devices
        var devices : seq[NBDDeviceInfo]
        for device in this.devices:
            devices.add(device.info)

        # Return list of devices
        return devices


# Export NBD so that superclass functions are available
export nbd