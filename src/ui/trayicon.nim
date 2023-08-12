import std/browsers
import reactive
import ../utils/iniparser
import ../providers/server
import ../providers/basedrive

# App version
const nimbleFile = staticRead("../../zapdrive.nimble")
const ini = parseINI(nimbleFile)
const appVersion = ini.get("version") 

## The ZapDrive tray icon
class ZDTrayIcon of Component:

    # On render
    method render() : Component = components:

        # Tray icon
        TrayIcon(tooltip: "ZapDrive", icon: reactiveAsset("../assets/ZapDrive Windows Tray.png")):
            Menu:

                # Title
                MenuItem(title: "ZapDrive v" & appVersion, disabled)
                MenuItem(separator)

                # Drives
                mapIt(ZapDriveServer.shared.devices):
                    MenuItem(title: it.info.displayName):
                        MenuItem(title: it.info.displayName, disabled)
                        MenuItem(title: it.status, disabled)
                        MenuItem(separator)
                        if not it.connected: 
                            MenuItem(title: "Connect", onPress: proc() = this.sendEventToProps("onConnectDrive", it.uuid))
                        # else: 
                        #     MenuItem(title: "Disconnect", onPress: proc() = this.sendEventToProps("onConnectDrive", it.uuid))
                        MenuItem(title: "Remove", onPress: proc() = this.sendEventToProps("onRemoveDrive", it.uuid))

                # No drive label
                if ZapDriveServer.shared.devices.len == 0:
                    MenuItem(title: "(no drives)", disabled)

                # Add drive menu
                MenuItem(title: "Open drive"):
                    MenuItem(title: "Temporary RAM Drive",  onPress: proc() = this.sendEventToProps("onAddDrive", "ram"))
                    MenuItem(title: "Dropbox",              onPress: proc() = this.sendEventToProps("onAddDrive", "dropbox"))
                    MenuItem(title: "FTP",                  onPress: proc() = this.sendEventToProps("onAddDrive", "ftp"))
                    MenuItem(title: "pCloud",               onPress: proc() = this.sendEventToProps("onAddDrive", "pcloud"))

                # Settings
                MenuItem(separator)
                MenuItem(title: "Options"):
                    MenuItem(title: "Start on login")
                    MenuItem(title: "Uninstall")

                # About and quit
                MenuItem(title: "About", onPress: proc() = openDefaultBrowser("https://github.com/jjv360/zapdrive"))
                MenuItem(title: "Quit", onPress: proc() = quit(0))