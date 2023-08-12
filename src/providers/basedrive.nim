import std/asyncdispatch
import classes
import reactive
import ../nbd


## Synchronized block device. Base class for all block devices.
class ZDDevice of NBDBlockDevice:

    ## Universally Unique ID
    var uuid = ""

    ## Provider name
    var provider = ""

    ## Get status text
    method status() : string =
        if this.connected:
            return "Connected"
        else:
            return "Disconnected"