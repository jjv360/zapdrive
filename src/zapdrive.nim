import std/strformat
import std/asyncdispatch
import std/os
import stdx/osproc
import reactive
import ./providers/server
import ./providers/basedrive
import ./providers/memdisk
import ./ui/trayicon
import ./wnbd_client

## Main app
class MyApp of Component:

    ## WNBD client
    var wnbd : WNBDClient = WNBDClient.init()

    ## Driver download progress
    var driverIsDownloading = false
    var driverDownloadProgress = ""

    ## On mount
    method onMount() =

        # Start server
        echo "Starting server..."
        ZapDriveServer.shared.start()
        echo fmt"Server is listening on {ZapDriveServer.shared.port}"


    ## Called when the user clicks on the "Add drive" button
    method onAddDrive(e: ReactiveEvent) {.async.} =
    
        # Check drive type
        var drive : ZDDevice = nil
        if e.value == "ram": drive = await ZDMemoryDisk.createNew()
        else: 
            alert("Unknown drive type: " & e.value, "Error", dlgError)
            return

        # Drive created, add it
        echo fmt"Created: uuid={drive.uuid} name={drive.info.displayName}" 
        ZapDriveServer.shared.addDevice(drive)

        # Connect it immediately
        await this.onConnectDrive(ReactiveEvent.init("onConnectDrive", drive.uuid))

        # Update UI
        this.renderAgain()


    ## Called when the user wants to connect to a drive
    method onConnectDrive(e: ReactiveEvent) {.async.} =

        # Get drive
        var drive = ZapDriveServer.shared.getDevice(e.value)
        if drive == nil:
            alert("Unknown drive: " & e.value, "Error", dlgError)
            return

        # Stop if driver is downloading
        if this.driverIsDownloading:
            alert("Please wait for the driver to finish downloading", "Error", dlgError)
            return

        # Check if installed
        let versions = WNBDClient.installedVersion()
        if versions.client != "":

            # Driver found
            echo fmt"[WNBDClient] Found driver: client={versions.client} lib={versions.lib} driver={versions.driver}"

        else:

            # Need to install, confirm with user
            let accepted = confirm("The WNBD driver is needed to connect to this device. Do you want to install it now?", "Install driver", dlgQuestion)
            if not accepted:
                echo "User cancelled driver installation"
                return

            # Install it
            try:
                this.driverIsDownloading = true
                this.driverDownloadProgress = "Downloading..."
                this.renderAgain()
                await WNBDClient.installDriver(proc(progress : float, txt : string) =
                    echo txt
                    this.driverDownloadProgress = txt
                    this.renderAgain()
                )
            except:
                displayCurrentException("Failed to install driver")
                return
            finally:
                this.driverIsDownloading = false
                this.driverDownloadProgress = ""
                this.renderAgain()

        # Stop if driver is downloading
        if drive.wnbdClient != nil:
            return

        # Start connection
        try:
            echo fmt"Connecting: uuid={drive.uuid} name={drive.info.displayName}" 
            drive.wnbdClient = WNBDClient.init()
            drive.wnbdClient.port = ZapDriveServer.shared.port
            drive.wnbdClient.exportName = drive.uuid
            this.renderAgain()
            await drive.wnbdClient.connect()
        except:
            displayCurrentException("Failed to connect to drive")
        finally:
            echo fmt"Disconnected: uuid={drive.uuid} name={drive.info.displayName}" 
            drive.wnbdClient = nil
            this.renderAgain()



    ## Called when the user wants to remove a drive
    method onRemoveDrive(e: ReactiveEvent) {.async.} =

        echo "Remove " & e.value


    ## On render
    method render() : Component = components:

        # Tray icon
        ZDTrayIcon(
            driverStatus: this.driverDownloadProgress,
            onAddDrive: proc(e: ReactiveEvent) = 
                asyncCheck this.onAddDrive(e)
            ,
            onConnectDrive: proc(e: ReactiveEvent) = 
                asyncCheck this.onConnectDrive(e)
            ,
            onRemoveDrive: proc(e: ReactiveEvent) = 
                asyncCheck this.onRemoveDrive(e)
            ,
        )


# Start the app
reactiveStart do():
    reactiveMount:
        MyApp