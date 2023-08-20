
# Package
version             = "0.1.0"
author              = "jjv360"
description         = "Cloud synced virtual drive."
license             = "MIT"
srcDir              = "src"
bin                 = @["zapdrive"]


# Reactive info
import reactive/pkg
reactive:
    bundleID        = "com.jjv360.zapdrive"
    displayName     = "ZapDrive"


# Dependencies
requires "nim >= 2.0.0"
requires "classes >= 0.3.17"
requires "stdx >= 0.1.0"
requires "elvis >= 0.5.0"
requires "reactive >= 0.3.0"