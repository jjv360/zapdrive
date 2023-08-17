import std/asyncdispatch
import std/strformat
import stdx/strutils
import elvis
import ./constants
import ./nbd_classes
import ./utils

## Send an option reply
proc sendOptionReply(connection : NBDConnection, option : uint, replyType : uint, data : seq[uint8] = newSeq[uint8](0)) {.async.} =
    var packet : seq[uint8]
    packet.add(0x3e889045565a9u.uint64)
    packet.add(option.uint32)
    packet.add(replyType.uint32)
    packet.add(data.len.uint32)
    packet.add(data)
    await connection.socket.send(packet)

## Get matching device info for a given export name
proc matchDevice(devices : seq[NBDDeviceInfo], name : string) : NBDDeviceInfo =

    # Check if name is empty
    if name == "":
        
        # Find the default device
        for device in devices:
            if device.isDefault:
                return device

        # Not found
        return nil

    else:

        # Find matching device
        for device in devices:
            if device.name == name:
                return device

        # Not found
        return nil


## This function handles the "option haggling" portion of the NBD protocol.
## Process the next option from the client. Returns `nil` while haggling, then returns the device info to connect to when the client wants to connect.
proc handleNextOption(connection : NBDConnection, devices : seq[NBDDeviceInfo]) : Future[NBDDeviceInfo] {.async.} =

    # Read next message header
    var header = await connection.socket.recvFixedLengthString(8)
    if header != "IHAVEOPT":
        raise newException(IOError, fmt"Invalid message header, expected IHAVEOPT but got something else instead.")

    # Read option name
    var option = await connection.socket.recvUint32()

    # Read option data size
    var dataSize = await connection.socket.recvUint32()

    # Check if data is too big
    if dataSize.int > 65536:

        # Return error to client
        connection.log(fmt"Warning: Option data size is too big: {dataSize.int}")
        await connection.sendOptionReply(option, NBD_REP_ERR_TOO_BIG)

        # Skip the data
        await connection.socket.skip(dataSize)
        return nil

    # Read option data
    var data = await connection.socket.recvFixedLengthData(dataSize.int)

    # Process option
    if option == NBD_OPT_EXPORT_NAME:

        # Get export name
        var exportName = data.toString()
        var exportDisplayName = exportName ?: "(default)"
        connection.log(fmt"Client wants to access the device: '{exportDisplayName}' (using the old NBD_OPT_EXPORT_NAME)")

        # Find device
        var deviceInfo = matchDevice(devices, exportName)
        if deviceInfo == nil:
            raise newException(IOError, fmt"Device '{exportDisplayName}' not found.")

        # Open device
        return deviceInfo

    elif option == NBD_OPT_ABORT:

        # Client wants to abort the connection, send an acknowledgement
        # Note: According to the docs, the server should safely handle the connection being closed immedialety after this,
        # so we catch errors here and ignore them.
        connection.log("Client wants to abort the connection.")
        try:
            await connection.sendOptionReply(option, NBD_REP_ACK)
        except: 
            discard

        # Now we can throw
        raise newException(NBDDisconnect, "Client aborted the connection.")

    elif option == NBD_OPT_LIST:

        # Client wants a list of our exports.
        connection.log("Client wants list of exported devices.")

        # Reply with each one
        for device in devices:

            # Skip if hidden
            if device.isHidden: 
                continue

            # Send device info packet
            var data : seq[uint8]
            data.add(device.name.len.uint32.toBytes())
            data.add(device.name.toBytes())
            await connection.sendOptionReply(option, NBD_REP_SERVER, data)

        # Done
        await connection.sendOptionReply(option, NBD_REP_ACK)

    elif option == NBD_OPT_STRUCTURED_REPLY:

        # Save that info
        connection.log("Client wants structured replies.")
        connection.structuredReplies = true

        # Done
        await connection.sendOptionReply(option, NBD_REP_ACK)

    elif option == NBD_OPT_STARTTLS:

        # We don't support this
        connection.log("Client wants to start TLS, but we don't support it.")
        await connection.sendOptionReply(option, NBD_REP_ERR_UNSUP)

    elif option == NBD_OPT_INFO or option == NBD_OPT_GO:

        # Get export name length
        var offset = 0
        var nameLen = data[offset ..< offset + 4].toUint32()
        offset += 4

        # Get export name
        var name = data[offset ..< offset + nameLen.int].toString()
        offset += nameLen.int

        # log it
        var displayName = name ?: "(default)"
        var accessType = option == NBD_OPT_INFO ? "get info for" ! "access"
        connection.log(fmt"Client wants to {accessType} the device: '{displayName}'")

        # Find device, or fail if not found
        var deviceInfo = matchDevice(devices, name)
        if deviceInfo == nil:
            connection.log(fmt"... but the device '{displayName}' doesn't exist")
            await connection.sendOptionReply(option, NBD_REP_ERR_UNKNOWN)
            return nil

        # TODO: Technically we only need to reply with the requests the client wants, but let's just send them all for now

        # Get transmission flags
        var flags = NBD_FLAG_HAS_FLAGS or NBD_FLAG_SEND_FLUSH or NBD_FLAG_SEND_FUA or NBD_FLAG_SEND_WRITE_ZEROES
        if deviceInfo.isReadOnly: flags = flags or NBD_FLAG_READ_ONLY

        # Send NBD_INFO_EXPORT (device size in bytes)
        var packet : seq[uint8]
        packet.add(NBD_INFO_EXPORT.uint16.toBytes())
        packet.add(deviceInfo.size.uint64.toBytes())
        packet.add(flags.uint16.toBytes())
        await connection.sendOptionReply(option, NBD_REP_INFO, packet)

        # Send NBD_INFO_NAME (device name)
        packet = @[]
        packet.add(NBD_INFO_NAME.uint16.toBytes())
        packet.add(deviceInfo.name.toBytes())
        await connection.sendOptionReply(option, NBD_REP_INFO, packet)

        # Send NBD_INFO_DESCRIPTION (device description)
        packet = @[]
        packet.add(NBD_INFO_DESCRIPTION.uint16.toBytes())
        packet.add(deviceInfo.displayDescription.toBytes())
        await connection.sendOptionReply(option, NBD_REP_INFO, packet)

        # Get preferred block sizes
        const minBlockSize          = 512u
        const preferredBlockSize    = 1024u * 8u
        const maxBlockSize          = 1024u * 1024u * 8u

        # Send NBD_INFO_BLOCK_SIZE (block size)
        packet = @[]
        packet.add(NBD_INFO_BLOCK_SIZE.uint16.toBytes())
        packet.add(minBlockSize.uint32.toBytes())
        packet.add(preferredBlockSize.uint32.toBytes())
        packet.add(maxBlockSize.uint32.toBytes())
        await connection.sendOptionReply(option, NBD_REP_INFO, packet)

        # Done
        await connection.sendOptionReply(option, NBD_REP_ACK)

        # If the client wants to start the connection, do so
        if option == NBD_OPT_GO:
            return deviceInfo

    elif option == NBD_OPT_LIST_META_CONTEXT:

        # Client wants to know what meta contexts we support... First check that they've enabled structured replies first
        connection.log("Client wants to know what metadata contexts we support")
        if not connection.structuredReplies:
            connection.log("...but they haven't enabled structured replies")
            await connection.sendOptionReply(option, NBD_REP_ERR_INVALID)
            return nil

        # Get export name length
        var offset = 0
        var nameLen = data[offset ..< offset + 4].toUint32()
        offset += 4

        # Get export name
        var name = data[offset ..< offset + nameLen.int].toString()
        offset += nameLen.int

        # Find device, or fail if not found
        var deviceInfo = matchDevice(devices, name)
        if deviceInfo == nil:
            connection.log(fmt"... but the device '{name}' doesn't exist.")
            await connection.sendOptionReply(option, NBD_REP_ERR_UNKNOWN)
            return nil

        # TODO: Technically we should filter by what the client asked for, but let's just return them all for now

        # List of meta contexts we support
        var contexts = @[
            "base:allocation"           # <-- Used for detecting if blocks have been allocated or not
        ]

        # Send each one
        for context in contexts:

            # Send context info packet
            var data : seq[uint8]
            data.add(context.len.uint32.toBytes())
            data.add(context.toBytes())
            await connection.sendOptionReply(option, NBD_REP_META_CONTEXT, data)

        # Done
        await connection.sendOptionReply(option, NBD_REP_ACK)

    elif option == NBD_OPT_SET_META_CONTEXT:

        # Client wants to set a meta context... First check that they've enabled structured replies first
        connection.log("Client wants to set meta contexts")
        if not connection.structuredReplies:
            connection.log("...but they haven't enabled structured replies.")
            await connection.sendOptionReply(option, NBD_REP_ERR_INVALID)
            return nil

        # Get export name length
        var offset = 0
        var nameLen = data[offset ..< offset + 4].toUint32()
        offset += 4

        # Get export name
        var name = data[offset ..< offset + nameLen.int].toString()
        offset += nameLen.int

        # Find device, or fail if not found
        var deviceInfo = matchDevice(devices, name)
        if deviceInfo == nil:
            connection.log(fmt"... but the device '{name}' doesn't exist.")
            await connection.sendOptionReply(option, NBD_REP_ERR_UNKNOWN)
            return nil

        # Get number of contexts
        let numContexts = data[offset ..< offset + 4].toUint32()
        offset += 4

        # Get each one
        for i in 0 ..< numContexts:

            # Get context name length
            let contextLen = data[offset ..< offset + 4].toUint32()
            offset += 4

            # Get context name
            let context = data[offset ..< offset + contextLen.int].toString()
            offset += contextLen.int

            # Check context
            if context == "base:allocation":

                # The client wants to use base:allocation
                connection.log(fmt"  Client is enabling metadata context: {context}")
                if not connection.metadataContexts.contains(context):
                    connection.metadataContexts.add(context)

                # Get context ID
                let contextID = connection.metadataContexts.find(context)

                # Send reply
                var data : seq[uint8]
                data.add(contextID.uint32.toBytes())        # <-- Unique context ID, we're using the offset into the connection.metadataContexts array
                data.add(context.toBytes())
                await connection.sendOptionReply(option, NBD_REP_META_CONTEXT, data)

            else:

                # Unknown context
                connection.log(fmt"  Ignoring unknown metadata context: {context}")

        # Done
        await connection.sendOptionReply(option, NBD_REP_ACK)

    else:

        # Unknown action!
        connection.log(fmt"Unknown option {option} requested by client, ignoring.")
        await connection.sendOptionReply(option, NBD_REP_ERR_UNSUP)

    # Done, but still in the option phase
    return nil


## Handle the optoin haggling part of the protocol.
proc handleOptionHaggling*(connection : NBDConnection, devices : seq[NBDDeviceInfo]) : Future[NBDDeviceInfo] {.async.} =

    # Run loop
    while true:

        # Handle next option
        var device = await handleNextOption(connection, devices)
        if device == nil:
            continue
        
        # Done, start the transmission phase with the selected device
        return device