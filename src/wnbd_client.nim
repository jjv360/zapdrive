import std/os
import std/osproc
import std/strutils
import std/asyncdispatch
import classes

## Install progress monitor
type WNBDInstallProgressCallback* = proc(progress : float, message : string)

##
## This provides access to the WNBD Client on Windows.
## See: https://github.com/cloudbase/wnbd
class WNBDClient:

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

        # Not found, start installing
        echo "[WNBDClient] Installing driver..."

