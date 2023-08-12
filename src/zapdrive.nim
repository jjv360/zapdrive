import std/strformat
import std/asyncdispatch
import std/os
import reactive
import ./providers/server
import ./providers/basedrive
import ./providers/memdisk
import ./ui/trayicon

## Main app
class MyApp of Component:

    # On mount
    method onMount() =

        # Start server
        echo "Starting server..."
        ZapDriveServer.shared.start(bindAddress = "0.0.0.0")  # TODO: Remove bind address
        echo fmt"Server is listening on {ZapDriveServer.shared.port}"


    # Called when the user clicks on the "Add drive" button
    method onAddDrive(e: ReactiveEvent) {.async.} =
    
        # Check drive type
        var drive : ZDDevice = nil
        if e.value == "ram": drive = await ZDMemoryDisk.createNew()
        else: 
            alert("Unknown drive type: " & e.value, "Error", dlgError)
            return

        # Drive created, add it
        ZapDriveServer.shared.addDevice(drive)

        # Update UI
        this.renderAgain()


    # Called when the user wants to connect to a drive
    method onConnectDrive(e: ReactiveEvent) {.async.} =

        # Get drive
        var drive = ZapDriveServer.shared.getDevice(e.value)
        if drive == nil:
            alert("Unknown drive: " & e.value, "Error", dlgError)
            return

        # Start connection
        echo fmt"Connecting: uuid={drive.uuid} name={drive.info.displayName}" 
        let result = execShellCmd(fmt"""wnbd-client map --hostname=localhost --port={ZapDriveServer.shared.port} --instance-name="{drive.uuid}" """)
        if result != 0:
            alert(fmt"Failed to connect to drive: Code {result}", "Error", dlgError)


    # Called when the user wants to remove a drive
    method onRemoveDrive(e: ReactiveEvent) {.async.} =

        echo "Remove " & e.value


    # On render
    method render() : Component = components:

        # Tray icon
        ZDTrayIcon(
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