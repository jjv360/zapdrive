#
# Helper utiltities for networking, since I can't find anything in the system lib for this

import std/asyncnet
import std/asyncdispatch
import stdx/strutils


## Offset a raw pointer by a certain number of bytes
proc `+`*(a: pointer, b: int): pointer = 
    if b >= 0:
        return cast[pointer](cast[uint](a) + cast[uint](b))
    else:
        return cast[pointer](cast[uint](a) - cast[uint](-b))


## Convert a 16-bit integer to bytes
proc toBytes*(value : uint16, desiredEndianness : Endianness = bigEndian) : string = 

    # Create buffer for the data
    var data = newString(2)

    # Check endianness
    if desiredEndianness == littleEndian:
        data[0] = (value shr 0 and 0xFF).char
        data[1] = (value shr 8 and 0xFF).char
    else:
        data[0] = (value shr 8 and 0xFF).char
        data[1] = (value shr 0 and 0xFF).char

    # Return it
    return data


## Convert a 32-bit integer to bytes
proc toBytes*(value : uint32, desiredEndianness : Endianness = bigEndian) : string = 

    # Create buffer for the data
    var data = newString(4)

    # Check endianness
    if desiredEndianness == littleEndian:
        data[0] = (value shr 0 and 0xFF).char
        data[1] = (value shr 8 and 0xFF).char
        data[2] = (value shr 16 and 0xFF).char
        data[3] = (value shr 24 and 0xFF).char
    else:
        data[0] = (value shr 24 and 0xFF).char
        data[1] = (value shr 16 and 0xFF).char
        data[2] = (value shr 8 and 0xFF).char
        data[3] = (value shr 0 and 0xFF).char

    # Return it
    return data


## Convert a 64-bit integer to bytes
proc toBytes*(value : uint64, desiredEndianness : Endianness = bigEndian) : string = 

    # Create buffer for the data
    var data = newString(8)

    # Check endianness
    if desiredEndianness == littleEndian:
        data[0] = (value shr 0 and 0xFF).char
        data[1] = (value shr 8 and 0xFF).char
        data[2] = (value shr 16 and 0xFF).char
        data[3] = (value shr 24 and 0xFF).char
        data[4] = (value shr 32 and 0xFF).char
        data[5] = (value shr 40 and 0xFF).char
        data[6] = (value shr 48 and 0xFF).char
        data[7] = (value shr 56 and 0xFF).char
    else:
        data[0] = (value shr 56 and 0xFF).char
        data[1] = (value shr 48 and 0xFF).char
        data[2] = (value shr 40 and 0xFF).char
        data[3] = (value shr 32 and 0xFF).char
        data[4] = (value shr 24 and 0xFF).char
        data[5] = (value shr 16 and 0xFF).char
        data[6] = (value shr 8 and 0xFF).char
        data[7] = (value shr 0 and 0xFF).char

    # Return it
    return data


## Convert an array of bytes to a 16-bit integer
proc toUint16*(data : string, desiredEndianness : Endianness = bigEndian) : uint16 = 

    # Check length
    if data.len != 2: raise newException(ValueError, "Data must be exactly 2 bytes long.")

    # Check endianness
    if desiredEndianness == littleEndian:
        return (data[0].uint16 shl 0) or 
            (data[1].uint16 shl 8)
    else:
        return (data[0].uint16 shl 8) or 
            (data[1].uint16 shl 0)


## Convert an array of bytes to a 32-bit integer
proc toUint32*(data : string, desiredEndianness : Endianness = bigEndian) : uint32 = 

    # Check length
    if data.len != 4: raise newException(ValueError, "Data must be exactly 4 bytes long.")

    # Check endianness
    if desiredEndianness == littleEndian:
        return (data[0].uint32 shl 0) or 
            (data[1].uint32 shl 8) or 
            (data[2].uint32 shl 16) or 
            (data[3].uint32 shl 24)
    else:
        return (data[0].uint32 shl 24) or 
            (data[1].uint32 shl 16) or 
            (data[2].uint32 shl 8) or 
            (data[3].uint32 shl 0)


## Convert an array of bytes to a 64-bit integer
proc toUint64*(data : string, desiredEndianness : Endianness = bigEndian) : uint64 = 

    # Check length
    if data.len != 8: raise newException(ValueError, "Data must be exactly 8 bytes long.")

    # Check endianness
    if desiredEndianness == littleEndian:
        return (data[0].uint64 shl 0) or 
            (data[1].uint64 shl 8) or 
            (data[2].uint64 shl 16) or 
            (data[3].uint64 shl 24) or 
            (data[4].uint64 shl 32) or 
            (data[5].uint64 shl 40) or 
            (data[6].uint64 shl 48) or 
            (data[7].uint64 shl 56)
    else:
        return (data[0].uint64 shl 56) or 
            (data[1].uint64 shl 48) or 
            (data[2].uint64 shl 40) or 
            (data[3].uint64 shl 32) or 
            (data[4].uint64 shl 24) or 
            (data[5].uint64 shl 16) or 
            (data[6].uint64 shl 8) or 
            (data[7].uint64 shl 0)


## Add a 16-bit integer to the data
proc add*(data : var string, value : uint16, desiredEndianness : Endianness = bigEndian) =
    data.add(value.toBytes(desiredEndianness))
    

## Add a 32-bit integer to the data
proc add*(data : var string, value : uint32, desiredEndianness : Endianness = bigEndian) =
    data.add(value.toBytes(desiredEndianness))


## Add a 64-bit integer to the data
proc add*(data : var string, value : uint64, desiredEndianness : Endianness = bigEndian) =
    data.add(value.toBytes(desiredEndianness))
            

## Receive a fixed length of data from the socket. Note this is not efficient for large amounts of data, use `recv()` itself for that.
proc recvFixedLengthData*(socket : AsyncSocket, length : int) : Future[string] {.async.} =

    # Special case: If zero length, just immediately return a blank array
    if length == 0: 
        return ""

    # Create data
    var data : string

    # Receive it
    var buffer = newString(1024)
    var amountReceived = 0
    while amountReceived < length:

        # Receive batch of data
        var amt = await socket.recvInto(buffer[0].addr, min(length - amountReceived, buffer.len))
        if amt == 0: raise newException(IOError, "Connection closed unexpectedly.")

        # Add it and keep going
        data.add(buffer[0 ..< amt])
        amountReceived += amt

    # Convert to string
    return data
            

## Skip a fixed amount of bytes from the stream.
proc skip*(socket : AsyncSocket, length : uint64) {.async.} =

    # Receive it ... we still need to "receive" it, but we'll put it into a throwaway buffer so it doesn't use too much memory during skipping
    var buffer = newString(1024*32)
    var amountReceived : uint64 = 0
    while amountReceived < length:

        # Receive batch of data
        var amt = await socket.recvInto(buffer[0].addr, min(length - amountReceived, buffer.len.uint64).int)
        if amt == 0: raise newException(IOError, "Connection closed unexpectedly.")

        # Just keep going
        amountReceived += amt.uint64


## Receive a 16-bit integer from a socket
proc recvUint16*(socket : AsyncSocket, incomingEndianness : Endianness = bigEndian) : Future[uint16] {.async.} =
    
    # Receive it
    var data = await socket.recvFixedLengthData(2)
    return data.toUint16(incomingEndianness)


## Receive a 32-bit integer from a socket
proc recvUint32*(socket : AsyncSocket, incomingEndianness : Endianness = bigEndian) : Future[uint32] {.async.} =
    
    # Receive it
    var data = await socket.recvFixedLengthData(4)
    return data.toUint32(incomingEndianness)


## Receive a 64-bit integer from a socket
proc recvUint64*(socket : AsyncSocket, incomingEndianness : Endianness = bigEndian) : Future[uint64] {.async.} =
    
    # Receive it
    var data = await socket.recvFixedLengthData(8)
    return data.toUint64(incomingEndianness)
