# ZapDrive

![](https://img.shields.io/badge/status-incomplete-lightgrey.svg)

<div align="center">
    <img src="extra/ZapDrive.svg" />
    <br/>
    <br/>
    <b>ZapDrive</b>
    <br/>
    Virtual disk backed up in the cloud.
</div>

## How it works

ZapDrive allows you to create virtual disk drives, and sync them to cloud providers like Dropbox, etc. It does this by hosting a local [NBD](https://github.com/NetworkBlockDevice/nbd/blob/master/doc/proto.md) server, and using existing NBD client drivers (such as [WNBD](https://github.com/cloudbase/wnbd) on Windows) to connect to it.

The data for the virtual drive is exported as blocks, which are cached locally and synchronized to your selected cloud provider.

There is also a global server which tracks device access in order to ensure the device is not accessed by more than one machine at a time. If you connect to a drive, a request is sent to any other devices to flush and disconnect them first.

Due to the virtual drive being a standard block device, you're able to use the full power of any filesystem you like, including encryption, compression, symlinks, etc.

## Why this?

The biggest reason is for symlink support. Some tools (like `npm link` and `nx`) work by linking folders together, which often cause issues for cloud providers. 

The purpose of this tool is to provide a more robust way of syncing files. It's like carrying a flash drive with you, except the drive is in the cloud and you can't lose it somewhere.

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

# Mount an exported device (Windows, requires WNBD and an admin shell)
# WNBD driver: https://github.com/cloudbase/wnbd
wnbd-client map <deviceName> --hostname <host> --port <port>

# Create partitions etc (Linux)
gparted /dev/nbd0
```