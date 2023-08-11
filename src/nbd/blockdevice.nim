import std/asyncdispatch
import classes
import ./nbd_classes

##
## Block states
type NBDBlockState* = enum

    ## An unallocated block is essentially all zeroes that doesn't take up any space on the storage system
    NBDBlockStateUnallocated

    ## Data exists in permanent storage but hasn't been loaded yet
    NBDBlockStateUnloaded

    ## Data has been saved to storage and hasn't been touched since
    NBDBlockStateClean

    ## Data has not yet been written to storage
    NBDBlockStateDirty

##
## A single block on the device
class NBDBlock:

    ## Block offset in bytes
    var offset : uint64 = 0

    ## Block data, can be 0 length if the block hasn't been loaded into memory yet
    var data : seq[uint8]

    ## Block state
    var state : NBDBlockState = NBDBlockStateUnallocated


## For a range of bytes, get a list of block offsets
iterator blockOffsetsForRange(offset : uint64, length : uint, blockSize : uint) : uint64 =
    for offset1 in countup(offset, offset + length - 1, blockSize):
        yield offset1 - (offset1 mod blockSize)


##
## A block-based device that stores data in blocks of a fixed size. Can be used as a base class for sparse devices.
class NBDBlockDevice of NBDDevice:

    ## Cached blocks
    var blockCache : seq[NBDBlock]

    ## Block size in bytes
    method blockSize() : uint = 1024u * 1024u * 1u

    ## Check if a block exists in permanent storage
    method blockExists(offset : uint64) : Future[bool] {.async.} = raiseAssert("You must implement the blockExists() method in your subclass.")

    ## Read a block from permanent storage
    method readBlock(offset : uint64) : Future[seq[uint8]] {.async.} = raiseAssert("You must implement the readBlock() method in your subclass.")

    ## Write a block to permanent storage
    method writeBlock(offset : uint64, data : seq[uint8]) : Future[void] {.async.} = raiseAssert("You must implement the writeBlock() method in your subclass.")

    ## Delete a block from permanent storage
    method deleteBlock(offset : uint64) : Future[void] {.async.} = raiseAssert("You must implement the deleteBlock() method in your subclass.")


    ## Get and cache a block
    method getBlockFromCache(offset : uint64) : Future[NBDBlock] {.async.} =

        # Ensure the alignment is correct
        var alignedOffset = offset - (offset mod this.blockSize)
        if alignedOffset != offset:
            raiseAssert("Requested a non-aligned block.")

        # Check if block is already cached
        for blk in this.blockCache:
            if blk.offset == alignedOffset:
                return blk

        # Block not found, load into cache... First check if it exists
        if await this.blockExists(alignedOffset):

            # Block does exist... Add clean block to cache
            var blk = NBDBlock()
            blk.offset = alignedOffset
            blk.state = NBDBlockStateUnloaded
            this.blockCache.add(blk)
            return blk

        else:

            # Block doesn't exist... Add unallocated block to cache
            var blk = NBDBlock()
            blk.offset = alignedOffset
            blk.state = NBDBlockStateUnallocated
            this.blockCache.add(blk)
            return blk


    ## Read data from the device
    method read(offset : uint64, length : uint32) : Future[seq[uint8]] {.async.} =
    
        # Create memory
        var data : seq[uint8]

        # Go through each block until data is filled
        var amountFilled = 0u
        for blockOffset in blockOffsetsForRange(offset, length, this.blockSize):

            # Get the block
            var blockInfo = await this.getBlockFromCache(blockOffset)
            
            # Check block range
            let blockDataStart = offset + amountFilled - blockInfo.offset
            let blockDataLen = min(data.len.uint - amountFilled, this.blockSize)
            let isEntireBlock = blockDataStart == 0 and blockDataLen == this.blockSize

            # Check if allocated
            if blockInfo.state == NBDBlockStateUnallocated:

                # Add zeroes
                data.add(newSeq[uint8](blockDataLen))
                amountFilled += blockDataLen
                continue

            # If block is unloaded, load it
            if blockInfo.state == NBDBlockStateUnloaded:

                # Load block
                blockInfo.data = await this.readBlock(blockInfo.offset)
                blockInfo.state = NBDBlockStateClean

            # Copy data from the block
            if isEntireBlock:
                
                # We want the entire block, just add it directly
                data.add(blockInfo.data)
                amountFilled += blockDataLen

            else: 
                
                # We want only a part of the block, this must be the last one
                data.add(blockInfo.data[blockDataStart ..< blockDataLen])
                amountFilled += blockDataLen

        # Done
        return data


    ## Write data to the device
    method write(offset : uint64, data : seq[uint8]) {.async.} =
    
        # Go through all data
        var amountFilled = 0u
        for blockOffset in blockOffsetsForRange(offset, data.len.uint, this.blockSize):

            # Get the block
            var blockInfo = await this.getBlockFromCache(blockOffset)
            
            # Check block range
            let blockDataStart = offset + amountFilled - blockInfo.offset
            let blockDataLen = min(data.len.uint - amountFilled, this.blockSize)
            let isEntireBlock = blockDataStart == 0 and blockDataLen == this.blockSize

            # Special case: If this data covers the entire block, we don't even need to read the existing data, we can just overwrite it immediately
            if isEntireBlock:

                # Write data immediately, since it covers the whole block
                blockInfo.data = data[amountFilled ..< amountFilled + this.blockSize()]
                blockInfo.state = NBDBlockStateDirty
                amountFilled += this.blockSize
                continue

            # If block is unallocated, create zero data
            if blockInfo.state == NBDBlockStateUnallocated:
                blockInfo.data = newSeq[uint8](this.blockSize().int)
                blockInfo.state = NBDBlockStateDirty

            # If block is unloaded, load it
            if blockInfo.state == NBDBlockStateUnloaded:
                blockInfo.data = await this.readBlock(blockInfo.offset)
                blockInfo.state = NBDBlockStateDirty

            # Copy region of source data into the block data
            blockInfo.data[blockDataStart ..< blockDataStart + blockDataLen] = data[amountFilled ..< amountFilled + blockDataLen]
            blockInfo.state = NBDBlockStateDirty
            amountFilled += this.blockSize


    ## Check if region is a hole
    method regionIsHole(offset : uint64, length : uint32) : Future[bool] {.async.} =

        # Go through all blocks in this region
        for blockOffset in blockOffsetsForRange(offset, length, this.blockSize):

            # Get the block
            var blockInfo = await this.getBlockFromCache(blockOffset)

            # Check if block is allocated
            if blockInfo.state != NBDBlockStateUnallocated:
                return false

        # All blocks are unallocated
        return true


    ## Check for zeroes in the data
    method regionIsZero(offset : uint64, length : uint32) : Future[bool] {.async.} =

        # Go through all blocks in this region
        for blockOffset in blockOffsetsForRange(offset, length, this.blockSize):

            # Get the block
            var blockInfo = await this.getBlockFromCache(blockOffset)

            # Check if block is unallocated
            if blockInfo.state != NBDBlockStateUnallocated:
                continue

            # Check if data is in memory. If not, just return false. This is a slight optimization, in the case where
            # all the queried blocks are actually in memory right now. This way we don't have to read them from disk.
            # if it's not in memory, just return false even though it may actually be zeroes.
            if blockInfo.data.len == 0:
                return false

            # Check if block is all zeroes
            for i in 0 ..< blockInfo.data.len:
                if blockInfo.data[i] != 0:
                    return false

        # All is zero
        return true
