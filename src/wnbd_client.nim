import std/os
import stdx/osproc
import std/strutils
import std/strformat
import stdx/sequtils
import stdx/asyncdispatch
import stdx/httpclient
import std/asyncstreams
import std/math
import classes
import elvis

## MsiExec result codes
## 
let MsiExecResultCodes = @[
    (0, "ERROR_SUCCESS", "Action completed successfully."),
    (13, "ERROR_INVALID_DATA", "The data is invalid."),
    (87, "ERROR_INVALID_PARAMETER", "One of the parameters was invalid."),
    (120, "ERROR_CALL_NOT_IMPLEMENTED", "This function is not available for this platform. It is only available on Windows 2000 and Windows XP with Window Installer version 2.0."),
    (1259, "ERROR_APPHELP_BLOCK", "This error code only occurs when using Windows Installer version 2.0 and Windows XP or later. If Windows Installer determines a product may be incompatible with the current operating system, it displays a dialog informing the user and asking whether to try to install anyway. This error code is returned if the user chooses not to try the installation."),
    (1601, "ERROR_INSTALL_SERVICE_FAILURE", "The Windows Installer service could not be accessed. Contact your support personnel to verify that the Windows Installer service is properly registered."),
    (1602, "ERROR_INSTALL_USEREXIT", "User cancel installation."),
    (1603, "ERROR_INSTALL_FAILURE", "Fatal error during installation."),
    (1604, "ERROR_INSTALL_SUSPEND", "Installation suspended, incomplete."),
    (1605, "ERROR_UNKNOWN_PRODUCT", "This action is only valid for products that are currently installed."),
    (1606, "ERROR_UNKNOWN_FEATURE", "Feature ID not registered."),
    (1607, "ERROR_UNKNOWN_COMPONENT", "Component ID not registered."),
    (1608, "ERROR_UNKNOWN_PROPERTY", "Unknown property."),
    (1609, "ERROR_INVALID_HANDLE_STATE", "Handle is in an invalid state."),
    (1610, "ERROR_BAD_CONFIGURATION", "The configuration data for this product is corrupt. Contact your support personnel."),
    (1611, "ERROR_INDEX_ABSENT", "Component qualifier not present."),
    (1612, "ERROR_INSTALL_SOURCE_ABSENT", "The installation source for this product is not available. Verify that the source exists and that you can access it."),
    (1613, "ERROR_INSTALL_PACKAGE_VERSION", "This installation package cannot be installed by the Windows Installer service. You must install a Windows service pack that contains a newer version of the Windows Installer service."),
    (1614, "ERROR_PRODUCT_UNINSTALLED", "Product is uninstalled."),
    (1615, "ERROR_BAD_QUERY_SYNTAX", "SQL query syntax invalid or unsupported."),
    (1616, "ERROR_INVALID_FIELD", "Record field does not exist."),
    (1618, "ERROR_INSTALL_ALREADY_RUNNING", "Another installation is already in progress. Complete that installation before proceeding with this install."),
    (1619, "ERROR_INSTALL_PACKAGE_OPEN_FAILED", "This installation package could not be opened. Verify that the package exists and that you can access it, or contact the application vendor to verify that this is a valid Windows Installer package."),
    (1620, "ERROR_INSTALL_PACKAGE_INVALID", "This installation package could not be opened. Contact the application vendor to verify that this is a valid Windows Installer package."),
    (1621, "ERROR_INSTALL_UI_FAILURE", "There was an error starting the Windows Installer service user interface. Contact your support personnel."),
    (1622, "ERROR_INSTALL_LOG_FAILURE", "Error opening installation log file. Verify that the specified log file location exists and is writable."),
    (1623, "ERROR_INSTALL_LANGUAGE_UNSUPPORTED", "This language of this installation package is not supported by your system."),
    (1624, "ERROR_INSTALL_TRANSFORM_FAILURE", "Error applying transforms. Verify that the specified transform paths are valid."),
    (1625, "ERROR_INSTALL_PACKAGE_REJECTED", "This installation is forbidden by system policy. Contact your system administrator."),
    (1626, "ERROR_FUNCTION_NOT_CALLED", "Function could not be executed."),
    (1627, "ERROR_FUNCTION_FAILED", "Function failed during execution."),
    (1628, "ERROR_INVALID_TABLE", "Invalid or unknown table specified."),
    (1629, "ERROR_DATATYPE_MISMATCH", "Data supplied is of wrong type."),
    (1630, "ERROR_UNSUPPORTED_TYPE", "Data of this type is not supported."),
    (1631, "ERROR_CREATE_FAILED", "The Windows Installer service failed to start. Contact your support personnel."),
    (1632, "ERROR_INSTALL_TEMP_UNWRITABLE", "The temp folder is either full or inaccessible. Verify that the temp folder exists and that you can write to it."),
    (1633, "ERROR_INSTALL_PLATFORM_UNSUPPORTED", "This installation package is not supported on this platform. Contact your application vendor."),
    (1634, "ERROR_INSTALL_NOTUSED", "Component not used on this machine"),
    (1635, "ERROR_PATCH_PACKAGE_OPEN_FAILED", "This patch package could not be opened. Verify that the patch package exists and that you can access it, or contact the application vendor to verify that this is a valid Windows Installer patch package."),
    (1636, "ERROR_PATCH_PACKAGE_INVALID", "This patch package could not be opened. Contact the application vendor to verify that this is a valid Windows Installer patch package."),
    (1637, "ERROR_PATCH_PACKAGE_UNSUPPORTED", "This patch package cannot be processed by the Windows Installer service. You must install a Windows service pack that contains a newer version of the Windows Installer service."),
    (1638, "ERROR_PRODUCT_VERSION", "Another version of this product is already installed. Installation of this version cannot continue. To configure or remove the existing version of this product, use Add/Remove Programs on the Control Panel."),
    (1639, "ERROR_INVALID_COMMAND_LINE", "Invalid command line argument. Consult the Windows Installer SDK for detailed command line help."),
    (1640, "ERROR_INSTALL_REMOTE_DISALLOWED", "Installation from a Terminal Server client session not permitted for current user."),
    (1641, "ERROR_SUCCESS_REBOOT_INITIATED", "The installer has started a reboot. This error code not available on Windows Installer version 1.0."),
    (1642, "ERROR_PATCH_TARGET_NOT_FOUND", "The installer cannot install the upgrade patch because the program being upgraded may be missing or the upgrade patch updates a different version of the program. Verify that the program to be upgraded exists on your computer and that you have the correct upgrade patch. This error code is not available on Windows Installer version 1.0."),
    (1643, "ERROR_PATCH_PACKAGE_REJECTED", "The patch package is not permitted by system policy. This error code is available with Windows Installer versions 2.0 or later."),
    (1644, "ERROR_INSTALL_TRANSFORM_REJECTED", "One or more customizations are not permitted by system policy. This error code is available with Windows Installer versions 2.0 or later."),
    (3010, "ERROR_SUCCESS_REBOOT_REQUIRED", "A reboot is required to complete the install. This does not include installs where the ForceReboot action is run. This error code not available on Windows Installer version 1.0."),
]

## Install progress monitor
type WNBDInstallProgressCallback* = proc(progress : float, message : string)

##
## WNDBClient connection statuses
type WNBDClientStatus* = enum

    ## Not connected
    wnbdClientDisconnected

    ## Connecting
    wnbdClientConnecting

    ## Connected
    wnbdClientConnected

##
## This provides access to the WNBD Client on Windows.
## See: https://github.com/cloudbase/wnbd
class WNBDClient:

    ## Export name (device name) on the server to connect to
    var exportName = ""

    ## Server hostname
    var hostname = "127.0.0.1"

    ## Server port
    var port = 10809

    ## Connection status
    var status : WNBDClientStatus = wnbdClientDisconnected

    ## Find path to EXE
    method findWNBD() : string {.static.} =

        # Check if WNBD is installed# Check the user's $PATH
        var exe = findExe("wnbd-client.exe")
        if exe != "":
            return exe

        # Check the usual install locations
        var location = absolutePath(os.getEnv("ProgramFiles") / "Ceph" / "bin" / "wnbd-client.exe")
        if fileExists(location):
            return location

        # Not found
        return ""


    ## Check if WNBD is installed and get the version. If not installed, returns a blank string.
    method installedVersion() : tuple[client : string, lib : string, driver : string] {.static.} =

        # Stop if EXE not found
        let exe = WNBDClient.findWNBD()
        if exe == "":
            return ("", "", "")

        # Run app and get result
        var output = execProcess(@[exe, "-v"].quoteShellCommand)
        if output.len == 0:
            return ("", "", "")

        # Parse result lines
        var client = ""
        var lib = ""
        var driver = ""
        for line in output.splitLines():
            if line.startsWith("wnbd-client.exe:"):
                client = line["wnbd-client.exe:".len ..< ^0].strip
            elif line.startsWith("libwnbd.dll:"):
                lib = line["libwnbd.dll:".len ..< ^0].strip
            elif line.startsWith("wnbd.sys:"):
                driver = line["wnbd.sys:".len ..< ^0].strip

        # Done
        return (client, lib, driver)


    ## Check if installed
    method isInstalled() : bool {.static.} =
        let versions = WNBDClient.installedVersion()
        return versions.client != ""


    ## Install the WNBD driver
    method installDriver(callback : WNBDInstallProgressCallback) {.async, static.} =

        # Start installing... Get possible download URLs
        let urls = @[

            # The direct link from the Ceph website
            "https://cloudba.se/ceph-win-latest-quincy", 
            
            # Last known version, saved in case Ceph goes down
            "https://raw.githubusercontent.com/jjv360/zapdrive/master/extra/ceph_quincy_beta.msi"
            
        ]

        # Try each file
        var saveTo = getTempDir() / "ceph_quincy_beta.msi"
        var saved = false
        var lastError : ref Exception
        for url in urls:

            # Catch errors
            try:

                # Download the file at this URL
                echo "[WNBDClient] Driver downloading: " & url
                await newAsyncHttpClient().downloadFile(url, saveTo, proc (current : uint64, total : uint64) = 
                    let currentMb = (current.float / 1024 / 1024).round().int
                    let totalMb = (total.float / 1024 / 1024).round().int
                    let progressPercent = ((total > 0 ? current.float / total.float ! 0.0) * 100).round()
                    let progressTxt = fmt"Downloading {currentMb} MB of {totalMb} MB"
                    callback(progressPercent, progressTxt)
                )
                saved = true
                break

            except:

                # Error, move onto the next URL
                lastError = getCurrentException()
                continue

        # If failed to save, throw error
        if not saved:
            raise lastError

        # Start installation
        echo "[WNBDClient] Driver installing..."
        callback(100.0, "Installing...")
        var resultCode = execCmd(@["msiexec", "/i", saveTo, "/passive"].quoteShellCommand)
        if resultCode != 0:

            # Get error code
            var error = MsiExecResultCodes.findIt(it[0] == resultCode)
            if error[0] == 0:
                raise newException(OSError, "Failed to install the WNBD driver. Code " & $resultCode)
            else:
                raise newException(OSError, "Failed to install the WNBD driver. " & error[2])


    ## Connect the client to the server. This method doesn't return until the connection is closed.
    method connect() {.async.} =

        # Stop if already connected
        if this.status != wnbdClientDisconnected:
            return

        # Catch errors
        try:

            # Open process
            echo "Running: " & WNBDClient.findWNBD()
            # let promise = asyncThreadProc(proc() : string =
            await execElevatedAsync(
                WNBDClient.findWNBD(),
                "map",
                "--hostname=" & this.hostname,
                "--port=" & $this.port,
                "--instance-name=" & this.exportName
            )
            #     return ""
            # )
            # await promise
            # let process = startProcess(@[
            #     WNBDClient.findWNBD(),
            #     "map",
            #     "--hostname=" & this.hostname,
            #     "--port=" & $this.port,
            #     "--instance-name=" & this.exportName
            # ].quoteShellCommand, workingDir = "", args = @[], env = nil, { poParentStreams, poEvalCommand })

            # # Wrap pipe into AsyncFD
            # # let asyncFD = process.outputHandle.AsyncFD
            # # asyncFD
            # # register(asyncFD)

            # # # Read output line by line
            # # while process.running:

            # #     # Log it
            # #     let line = await asyncFD.readLine()
            # #     echo "[WNBDClient] " & line

            # # Wait for process to end
            # while process.peekExitCode == -1:
            #     await sleepAsync(10)

            # # Check exit code
            # if process.peekExitCode == 1:
            #     raise newException(OSError, "WNBD client exited with code 1. Maybe unable to run as administrator?")
            # elif process.peekExitCode != 0:
            #     raise newException(OSError, "WNBD client exited with code " & $process.peekExitCode)

        except:

            # Failed, pass on error
            raise getCurrentException()

        finally:

            # Reset state
            this.status = wnbdClientDisconnected

