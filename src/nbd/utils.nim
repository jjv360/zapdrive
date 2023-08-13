#
# Helper utiltities for networking, since I can't find anything in the system lib for this

import std/asyncnet
import std/asyncdispatch
import std/strutils
import std/sequtils

## Convert a byte array to a string ... Nim, why... why do you not have this?
## See: https://github.com/nim-lang/Nim/issues/14810
proc toString*(bytes: openarray[byte]): string =
    if bytes.len == 0: return ""
    result = newString(bytes.len)
    copyMem(result[0].addr, bytes[0].unsafeAddr, bytes.len)


## Convert a string to a byte array with no zero terminator
## TODO: Why doesn't `openarray` work here?
proc toBytes*(str: string): seq[uint8] =
    return str.toOpenArrayByte(0, str.len - 1).toSeq()


## Offset a raw pointer by a certain number of bytes
proc `+`*(a: pointer, b: int): pointer = 
    if b >= 0:
        return cast[pointer](cast[uint](a) + cast[uint](b))
    else:
        return cast[pointer](cast[uint](a) - cast[uint](-b))


## Convert a 16-bit integer to bytes
proc toBytes*(value : uint16, desiredEndianness : Endianness = bigEndian) : array[2, uint8] = 

    # Create buffer for the data
    var data : array[2, uint8]

    # Check endianness
    if desiredEndianness == littleEndian:
        data[0] = (value shr 0 and 0xFF).uint8
        data[1] = (value shr 8 and 0xFF).uint8
    else:
        data[0] = (value shr 8 and 0xFF).uint8
        data[1] = (value shr 0 and 0xFF).uint8

    # Return it
    return data


## Convert a 32-bit integer to bytes
proc toBytes*(value : uint32, desiredEndianness : Endianness = bigEndian) : array[4, uint8] = 

    # Create buffer for the data
    var data : array[4, uint8]

    # Check endianness
    if desiredEndianness == littleEndian:
        data[0] = (value shr 0 and 0xFF).uint8
        data[1] = (value shr 8 and 0xFF).uint8
        data[2] = (value shr 16 and 0xFF).uint8
        data[3] = (value shr 24 and 0xFF).uint8
    else:
        data[0] = (value shr 24 and 0xFF).uint8
        data[1] = (value shr 16 and 0xFF).uint8
        data[2] = (value shr 8 and 0xFF).uint8
        data[3] = (value shr 0 and 0xFF).uint8

    # Return it
    return data


## Convert a 64-bit integer to bytes
proc toBytes*(value : uint64, desiredEndianness : Endianness = bigEndian) : array[8, uint8] = 

    # Create buffer for the data
    var data : array[8, uint8]

    # Check endianness
    if desiredEndianness == littleEndian:
        data[0] = (value shr 0 and 0xFF).uint8
        data[1] = (value shr 8 and 0xFF).uint8
        data[2] = (value shr 16 and 0xFF).uint8
        data[3] = (value shr 24 and 0xFF).uint8
        data[4] = (value shr 32 and 0xFF).uint8
        data[5] = (value shr 40 and 0xFF).uint8
        data[6] = (value shr 48 and 0xFF).uint8
        data[7] = (value shr 56 and 0xFF).uint8
    else:
        data[0] = (value shr 56 and 0xFF).uint8
        data[1] = (value shr 48 and 0xFF).uint8
        data[2] = (value shr 40 and 0xFF).uint8
        data[3] = (value shr 32 and 0xFF).uint8
        data[4] = (value shr 24 and 0xFF).uint8
        data[5] = (value shr 16 and 0xFF).uint8
        data[6] = (value shr 8 and 0xFF).uint8
        data[7] = (value shr 0 and 0xFF).uint8

    # Return it
    return data


## Convert an array of bytes to a 16-bit integer
proc toUint16*(data : openarray[uint8], desiredEndianness : Endianness = bigEndian) : uint16 = 

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
proc toUint32*(data : openarray[uint8], desiredEndianness : Endianness = bigEndian) : uint32 = 

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
proc toUint64*(data : openarray[uint8], desiredEndianness : Endianness = bigEndian) : uint64 = 

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
proc add*(data : var seq[uint8], value : uint16, desiredEndianness : Endianness = bigEndian) =
    data.add(value.toBytes(desiredEndianness))
    

## Add a 32-bit integer to the data
proc add*(data : var seq[uint8], value : uint32, desiredEndianness : Endianness = bigEndian) =
    data.add(value.toBytes(desiredEndianness))


## Add a 64-bit integer to the data
proc add*(data : var seq[uint8], value : uint64, desiredEndianness : Endianness = bigEndian) =
    data.add(value.toBytes(desiredEndianness))


## Add bytes of a string to the data
proc add*(data : var seq[uint8], value : string) =
    data.add(value.toBytes())


## Send a packet to the socket
proc send*(socket : AsyncSocket, data : seq[uint8]) : Future[void] {.async.} =
    var dataPointer = addr data[0]
    await socket.send(dataPointer, data.len)
            

## Receive a fixed length of data from the socket. Note this is not efficient for large amounts of data, use `recv()` itself for that.
proc recvFixedLengthData*(socket : AsyncSocket, length : int) : Future[seq[uint8]] {.async.} =

    # Special case: If zero length, just immediately return a blank array
    if length == 0: 
        return @[]

    # Create data
    var data : seq[uint8]

    # Receive it
    var buffer : array[1024, uint8]
    var amountReceived = 0
    while amountReceived < length:

        # Receive batch of data
        var amt = await socket.recvInto(buffer.addr, min(length - amountReceived, buffer.len))
        if amt == 0: raise newException(IOError, "Connection closed unexpectedly.")

        # Add it and keep going
        data.add(buffer[0 ..< amt])
        amountReceived += amt

    # Convert to string
    return data
            

## Skip a fixed amount of bytes from the stream.
proc skip*(socket : AsyncSocket, length : uint64) {.async.} =

    # Receive it ... we still need to "receive" it, but we'll put it into a throwaway buffer so it doesn't use too much memory during skipping
    var buffer : array[1024*32, uint8]
    var amountReceived : uint64 = 0
    while amountReceived < length:

        # Receive batch of data
        var amt = await socket.recvInto(buffer.addr, min(length - amountReceived, buffer.len.uint64).int)
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
            

## Receive a fixed length string from the socket
proc recvFixedLengthString*(socket : AsyncSocket, length : int) : Future[string] {.async.} =

    # Receive it
    var data = await socket.recvFixedLengthData(length)

    # Convert to string
    return data.toString()


## Check if a seq is filled with zeroes
proc isZeroes*(data : seq[uint8]) : bool =
    for i in 0 ..< data.len:
        if data[i] != 0: return false
    return true