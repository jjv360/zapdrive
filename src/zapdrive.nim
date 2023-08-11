import std/strformat
import reactive
import ./zapdrivenbdserver

reactiveStart do():

    # Start server
    echo "Starting server..."
    ZapDriveNBDServer.shared.start(bindAddress = "0.0.0.0")  # TODO: Remove bind address
    echo fmt"Server is listening on {ZapDriveNBDServer.shared.port}"

    # Mount the app
    reactiveMount:

        # Tray icon
        TrayIcon(tooltip: "ZapDrive")

        # Main app window
        # Window:
        #     View(text: "Hello world!")