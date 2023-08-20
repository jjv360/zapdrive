import std/browsers
import reactive
import ../providers/server
import ../providers/basedrive

## A menu item for a specific drive
class ZDDriveMenu of Component:

    # Get drive
    method drive() : ZDDevice = this.props{"device"}.asObject(ZDDevice)

    # On render
    method render() : Component = components:

        # Menu item
        MenuItem(title: this.drive.info.displayName):

            # Drive details
            MenuItem(title: this.drive.info.displayName, disabled)
            MenuItem(title: this.drive.status, disabled)

            # Actions
            MenuItem(separator)
            if this.drive.connections.len == 0: MenuItem(title: "Connect", onPress: proc() = this.sendEventToProps("onConnectDrive", this.drive.uuid))
            if this.drive.connections.len >= 1: MenuItem(title: "Disconnect", onPress: proc() = this.sendEventToProps("onDisconnectDrive", this.drive.uuid))
            MenuItem(title: "Remove", onPress: proc() = this.sendEventToProps("onRemoveDrive", this.drive.uuid))


## The ZapDrive tray icon
class ZDTrayIcon of Component:

    # On render
    method render() : Component = components:

        # Tray icon
        TrayIcon(tooltip: "ZapDrive", icon: reactiveAsset("../assets/ZapDrive Windows Tray.png"), onActivate: proc() = this.renderAgain()):
            Menu:

                # Title
                MenuItem(title: ReactiveApp.name & " v" & ReactiveApp.version, disabled)
                MenuItem(separator)

                # Drives
                mapIt(ZapDriveServer.shared.devices):
                    ZDDriveMenu(device: it, onConnectDrive: this.props{"onConnectDrive"}, onRemoveDrive: this.props{"onRemoveDrive"})

                # No drive label
                if ZapDriveServer.shared.devices.len == 0:
                    MenuItem(title: "(no drives)", disabled)

                # Add drive menu
                MenuItem(title: "New drive"):
                    MenuItem(title: "Temporary RAM Drive",  onPress: proc() = this.sendEventToProps("onAddDrive", "ram"))
                    MenuItem(title: "Local File",           onPress: proc() = this.sendEventToProps("onAddDrive", "file"))

                # Driver status
                MenuItem(separator)
                if this.props{"driverStatus"}.string.len > 0:
                    MenuItem(title: "Driver: " & this.props{"driverStatus"}.string, disabled)

                # Settings
                MenuItem(title: "Options"):
                    MenuItem(title: "Start on login")
                    MenuItem(title: "Uninstall")

                # About and quit
                MenuItem(title: "About", onPress: proc() = openDefaultBrowser("https://github.com/jjv360/zapdrive"))
                MenuItem(title: "Quit", onPress: proc() = quit(0))