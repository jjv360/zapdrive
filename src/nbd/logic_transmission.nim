import std/asyncdispatch
import std/asyncnet
import std/strformat
import ./constants
import ./nbd_classes
import ./utils


## Maximum amount of bytes that can be sent in a single chunk (16MB)
const NBDServerMaxChunkSize = 1024u * 1024u * 16u


## Send a command reply in the simple format
proc sendTransmissionSimpleReply(connection : NBDConnection, cookie : uint64, errorCode : uint32, data : string = "") {.async.} =
    var packet : string
    packet.add(NBD_SIMPLE_REPLY_MAGIC)
    packet.add(errorCode)
    packet.add(cookie)
    packet.add(data)
    if connection.socket.isClosed: return
    await connection.socket.send(packet)


## Send a command reply chunk in the structured format
proc sendTransmissionStructuredReplyChunk(connection : NBDConnection, cookie : uint64, errorCode : uint32, flags : uint16, replyType : uint16, data : string = "") {.async.} =
    var packet : string
    packet.add(NBD_STRUCTURED_REPLY_MAGIC)
    packet.add(flags)
    packet.add(replyType)
    packet.add(cookie)
    packet.add(data.len.uint32)
    packet.add(data)
    if connection.socket.isClosed: return
    await connection.socket.send(packet)


## Send a simple non-chunked reply in whatever format the client requested
proc sendTransmissionReply(connection : NBDConnection, cookie : uint64, errorCode : uint32 = 0, replyType : uint16 = NBD_REPLY_TYPE_NONE, data : string = "") {.async.} =

    # Check connection type
    if connection.structuredReplies:

        # Send a single completed chunk
        await sendTransmissionStructuredReplyChunk(connection, cookie, errorCode, NBD_REPLY_FLAG_DONE, replyType, data)

    else:

        # Send a simple reply
        await sendTransmissionSimpleReply(connection, cookie, errorCode, data)


##
## Handles an async read request
proc handleReadCommandImpl(connection : NBDConnection, commandFlags : uint16, commandType : uint16, cookie : uint64, requestOffset: uint64, requestLength : uint32, requestData : string) {.async.} =

    # Check if can chunk reads
    let canChunkReads = connection.structuredReplies and (commandFlags and NBD_CMD_FLAG_DF) == 0
    if (not canChunkReads or requestLength <= NBDServerMaxChunkSize):

        # Client wants to read data without chunking, or the requested length is small enough to only need one chunk. 
        # Ensure the requested size isn't too big
        # connection.log(fmt"Client requested a read of {requestLength} bytes from offset {requestOffset} in a single chunk.")
        if requestLength > NBDServerMaxChunkSize:
            connection.log(fmt"Client requested a read of {requestLength} bytes, which is too big.")
            await connection.sendTransmissionReply(cookie, NBD_EOVERFLOW)
            return

        # First check if data is all zero
        # NOTE: Spec calls this "NBD_REPLY_TYPE_OFFSET_HOLE" but says it represents zeroes, not a "hole" specifically...
        var isZero = false
        try:
            isZero = await connection.device.regionIsZero(requestOffset, requestLength)
        except:
            connection.log(fmt"Failed to check if region is zero, we'll assume it isn't. Offset: {requestOffset}, length: {requestLength}. Error: {getCurrentExceptionMsg()}")

        # If all zeroes, send that if supported
        if isZero and connection.structuredReplies:
            var packet : string
            packet.add(requestOffset.uint64)
            packet.add(requestLength.uint32)
            await connection.sendTransmissionReply(cookie, errorCode = 0, replyType = NBD_REPLY_TYPE_OFFSET_HOLE, packet)
            return
        
        # Read data
        var data : string
        try:
            data = await connection.device.read(requestOffset, requestLength)
            if data.len.uint32 != requestLength: raise newException(IOError, "Returned data was not the correct length. Got length " & $data.len)
        except:
            connection.log(fmt"Failed to read data from the device. Offset: {requestOffset}, length: {requestLength}. Error: {getCurrentExceptionMsg()}")
            await connection.sendTransmissionReply(cookie, NBD_EIO)
            return
        
        # Send everything in one go
        if connection.structuredReplies:

            # Send a structured reply
            var packet : string
            packet.add(requestOffset.uint64)
            packet.add(data)
            await connection.sendTransmissionStructuredReplyChunk(cookie, errorCode = 0, replyType = NBD_REPLY_TYPE_OFFSET_DATA, flags = NBD_REPLY_FLAG_DONE, packet)

        else:

            # Send simple reply
            await connection.sendTransmissionSimpleReply(cookie, errorCode = 0, data)

    else:

        # Client wants to read data in chunks
        connection.log(fmt"Client requested a read of {requestLength} bytes in multiple chunks. TODO: Not supported yet.")
        await connection.sendTransmissionReply(cookie, NBD_ENOTSUP)


##
## Handles an async write request
proc handleWriteCommandImpl(connection : NBDConnection, commandFlags : uint16, commandType : uint16, cookie : uint64, requestOffset: uint64, requestLength : uint32, requestData : string = "") {.async.} =

    # Client wants to write data
    # connection.log(fmt"Client requested a write of {requestLength} bytes.")
    try:

        # Check if zeroes
        # if requestData.allZero:
        #     await connection.device.writeZeroes(requestOffset, requestLength)
        # else:
        await connection.device.write(requestOffset, requestData)

    except:
        connection.log(fmt"Failed to write data to the device. Offset: {requestOffset}, length: {requestLength}. Error: {getCurrentExceptionMsg()}")
        await connection.sendTransmissionReply(cookie, NBD_EIO)
        return

    # TODO: Flush?

    # Done
    await connection.sendTransmissionReply(cookie, errorCode = 0)


##
## Handle a single command
proc handleCommandImpl(connection : NBDConnection, commandFlags : uint16, commandType : uint16, cookie : uint64, requestOffset: uint64, requestLength : uint32, requestData : string) {.async.} =

    # Check command type
    if commandType == NBD_CMD_READ:
        
        # Handle read
        await handleReadCommandImpl(connection, commandFlags, commandType, cookie, requestOffset, requestLength, requestData)

    elif commandType == NBD_CMD_WRITE:

        # Client wants to write data
        await handleWriteCommandImpl(connection, commandFlags, commandType, cookie, requestOffset, requestLength, requestData)

    elif commandType == NBD_CMD_DISC:

        # Client wants to disconnect
        # Note: No reply to this message is sent
        connection.log(fmt"Client requested to disconnect.")
        raise newException(NBDDisconnect, "Client requested to disconnect.")

    elif commandType == NBD_CMD_FLUSH:

        # Client wants to flush
        # connection.log(fmt"Client requested a flush.")
        try:
            await connection.device.flush()
        except:
            connection.log(fmt"Failed to flush the device. Error: {getCurrentExceptionMsg()}")
            await connection.sendTransmissionReply(cookie, NBD_EIO)
            return

        # Done
        await connection.sendTransmissionReply(cookie, errorCode = 0)

    elif commandType == NBD_CMD_TRIM:

        # Not supported currently
        connection.log(fmt"Client requested a trim. Not implemented currently.")
        await connection.sendTransmissionReply(cookie, NBD_ENOTSUP)

    elif commandType == NBD_CMD_CACHE:

        # Not supported currently
        connection.log(fmt"Client requested a cache region. Not implemented currently.")
        await connection.sendTransmissionReply(cookie, NBD_ENOTSUP)

    elif commandType == NBD_CMD_WRITE_ZEROES:

        # Client wants to write zeroes
        # connection.log(fmt"Client requested a write of {requestLength} zero bytes.")
        try:
            await connection.device.writeZeroes(requestOffset, requestLength)
        except:
            connection.log(fmt"Failed to write zeroed data to the device. Offset: {requestOffset}, length: {requestLength}. Error: {getCurrentExceptionMsg()}")
            await connection.sendTransmissionReply(cookie, NBD_EIO)
            return

        # TODO: Flush?

        # Done
        await connection.sendTransmissionReply(cookie, errorCode = 0)

    elif commandType == NBD_CMD_BLOCK_STATUS:

        # TODO: The spec allows for multiple regions to be returned, but we're only returning one currently.

        # Log it
        connection.log(fmt"Client requested block status.")
        
        # Get block range requested by the client.
        # let requestOffsetEnd = requestOffset + requestLength
        # let addExtraBlock = requestOffsetEnd mod connection.device.info.blockSize.uint64 != 0
        # let startBlock = requestOffset div connection.device.info.blockSize.uint64
        # let endBlock = requestOffsetEnd div connection.device.info.blockSize.uint64 + (addExtraBlock ? 1 ! 0).uint64

        # Check if range is too big
        if requestLength > 1024*1024*16:
            connection.log(fmt"Client requested block status for a range too big.")
            await connection.sendTransmissionReply(cookie, NBD_EINVAL)
            return

        # Check if range is outside the device size
        if requestOffset + requestLength > connection.device.info.size:
            connection.log(fmt"Client requested block status for a range outside the device size.")
            await connection.sendTransmissionReply(cookie, NBD_EINVAL)
            return

        # Context ID for the block status
        let contextID = connection.metadataContexts.find("base:allocation")
        if contextID == -1:

            # The client is asking for data for contexts, but we don't have any.
            connection.log(fmt"Client has not negotiated support for metadata contexts, but requested block status.")
            await connection.sendTransmissionReply(cookie, NBD_EINVAL)
            return

        # Check if region is a hole
        var isHole = false
        var isZero = false
        try:
            isHole = await connection.device.regionIsHole(requestOffset, requestLength)
            if isHole: isZero = true
            else: isZero = await connection.device.regionIsZero(requestOffset, requestLength)
        except:
            connection.log(fmt"Failed to check if region is a hole. Offset: {requestOffset}, length: {requestLength}. Error: {getCurrentExceptionMsg()}")
            await connection.sendTransmissionReply(cookie, NBD_EIO)
            return

        # Create flags
        var regionFlags : uint32 = 0
        if isHole: regionFlags = regionFlags or NBD_STATE_HOLE
        if isZero: regionFlags = regionFlags or NBD_STATE_ZERO

        # Create output data
        var packet : string
        packet.add(contextID.uint32)
        packet.add(requestLength.uint32)
        packet.add(regionFlags.uint32)
        await connection.sendTransmissionReply(cookie, errorCode = 0, NBD_REPLY_TYPE_BLOCK_STATUS, packet)

    else:

        # Unknown command
        await connection.sendTransmissionReply(cookie, NBD_ENOTSUP)
        connection.log(fmt"Unknown command received from the client. type={commandType} flags={commandFlags} offset={requestOffset} length={requestLength}")



##
## Handle a single command
proc handleCommand(connection : NBDConnection, commandFlags : uint16, commandType : uint16, cookie : uint64, requestOffset: uint64, requestLength : uint32, requestData : string) {.async.} = 

    # Catch all uncaught errors
    # try:

    # Run it
    await handleCommandImpl(connection, commandFlags, commandType, cookie, requestOffset, requestLength, requestData)

    # except:

    #     # Bad error, close the connection
    #     connection.log(fmt"An error occurred while handling a command. Error: {getCurrentExceptionMsg()}")
    #     connection.socket.close()


##
## Handles the transmission phase of the connection
proc handleTransmissionPhase*(connection : NBDConnection) {.async.} =

    # Entering transmission phase
    var flags = ""
    if connection.structuredReplies: flags = flags & "structured-replies "
    for ctx in connection.metadataContexts: flags = flags & ctx & " "
    if flags == "": flags = "(no options)"
    connection.log(fmt"Entering transmission phase with: {flags}")

    # Run loop
    while not connection.socket.isClosed:

        # Receive magic header
        let magicHeader = await connection.socket.recvUint32()
        if magicHeader != NBD_REQUEST_MAGIC:
            raise newException(IOError, "Corrupted command received from the client. Expected NBD_REQUEST_MAGIC but got something else instead.")

        # Get command flags
        let commandFlags = await connection.socket.recvUint16()

        # Get type
        let commandType = await connection.socket.recvUint16()

        # Get cookie / handle
        let cookie = await connection.socket.recvUint64()

        # Get offset
        let requestOffset = await connection.socket.recvUint64()

        # Get length
        let requestLength = await connection.socket.recvUint32()

        # Get data for write requests
        var requestData : string
        if commandType == NBD_CMD_WRITE:
            if requestLength > NBDServerMaxChunkSize: raise newException(IOError, "Client requested a write of a chunk that is too big.")
            requestData = await connection.socket.recvFixedLengthData(requestLength.int)

        # No more reading needed! Handle the command
        # echo fmt"CMD flags={commandFlags} type={commandType} cookie={cookie} offset={requestOffset} length={requestLength} data={requestData.len}"
        asyncCheck handleCommand(connection, commandFlags, commandType, cookie, requestOffset, requestLength, requestData)