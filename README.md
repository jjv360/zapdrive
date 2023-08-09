# ZapDrive

![](https://img.shields.io/badge/status-incomplete-lightgrey.svg)

This app creates a virtual disk drive on your computer, backed up and synchronized in the cloud.

## Building

- Make sure you have [Nim](https://nim-lang.org) installed
- `nimble run` - Run the app from source

## NBD testing

You can use the following tools to test the NBD server.

```bash
# Query the server's exports (Linux or WSL2)
nbdinfo --list nbd://<hostname>:<port>

# Mount the default exported device (Linux)
modprobe nbd
nbd-client <hostname> <port> /dev/nbd0

# Mount an exported device (Windows, requires WNBD and an admin PowerShell)
# WNBD driver: https://github.com/cloudbase/wnbd
wnbd-client map <deviceName> --hostname <host> --port <port>
Get-Disk

# Create partitions etc (Linux)
gparted /dev/nbd0
```