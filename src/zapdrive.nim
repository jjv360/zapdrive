import std/strformat
# import reactive
import "../../nim-reactive/src/reactive"
import ./zapdrivenbdserver

reactiveStart do():

    # Load assets


    # Start server
    echo "Starting server..."
    ZapDriveNBDServer.shared.start(bindAddress = "0.0.0.0")  # TODO: Remove bind address
    echo fmt"Server is listening on {ZapDriveNBDServer.shared.port}"

    # Mount the app
    reactiveMount:

        # Tray icon
        TrayIcon(tooltip: "ZapDrive", icon: reactiveAsset("assets/ZapDrive Windows Tray.png"))

        # Main app window
        # Window:
        #     View(text: "Hello world!")