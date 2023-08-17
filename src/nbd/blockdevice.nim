import std/asyncdispatch
import std/times
import std/strformat
import stdx/sequtils
import stdx/strutils
import classes
import elvis
import ./nbd_classes

##
## Block states
type NBDBlockState* = enum

    ## We don't know this block state yet
    NBDBlockStateUnknown

    ## An unallocated block is essentially all zeroes that doesn't take up any space on the storage system
    NBDBlockStateUnallocated

    ## Data exists in permanent storage but hasn't been loaded yet
    NBDBlockStateUnloaded

    ## Data is loaded
    NBDBlockStateLoaded

##
## A single block on the device
class NBDBlock:

    ## Block offset in bytes
    var offset : uint64 = 0

    ## Block data, can be 0 length if the block hasn't been loaded into memory yet
    var data : string

    ## Write nonce, this increases each time the block is modified. This is used to check if
    ## a block was modified while it was being saved.
    var updateNonce = 0u

    ## Number of times this block was accessed
    var accessCounter = 0u

    ## Last time this block was accessed
    var lastAccess : float = cpuTime()

    ## Block state
    var state : NBDBlockState = NBDBlockStateUnallocated

    ## True if currently loading
    var isLoading = false

    ## True if currently saving
    var isSaving = false

    ## True if the block is dirty, ie hasn't been written back to permanent storage yet
    var isDirty = false




## For a range of bytes, get a list of block offsets
iterator blockOffsetsForRange(offset : uint64, length : uint, blockSize : uint) : uint64 =
    for offset1 in countup(offset, offset + length - 1, blockSize):
        yield offset1 - (offset1 mod blockSize)


##
## A block-based device that stores data in blocks of a fixed size. Can be used as a base class for sparse devices.
## This class also handles memory and disk caching of blocks, and calling back to the subclass to load/save blocks.
class NBDBlockDevice of NBDDevice:

    ## Cached blocks
    var blockCache : seq[NBDBlock]

    ## Amount of data to keep in memory
    var desiredMemorySize : uint64 = 1024 * 1024 * 128

    ## Maximum amount of memory to retain before blocking
    var maximumMemorySize : uint64 = 1024 * 1024 * 512

    ## Maximum number of parallel block operations
    var maxParallelOperations = 10



    ## Block size in bytes
    method blockSize() : uint = 1024u * 1024u * 1u

    ## Check if a block exists in permanent storage
    method blockExists(offset : uint64) : Future[bool] {.async.} = raiseAssert("You must implement the blockExists() method in your subclass.")

    ## Read a block from permanent storage
    method readBlock(offset : uint64) : Future[string] {.async.} = raiseAssert("You must implement the readBlock() method in your subclass.")

    ## Write a block to permanent storage
    method writeBlock(offset : uint64, data : string) : Future[void] {.async.} = raiseAssert("You must implement the writeBlock() method in your subclass.")

    ## Delete a block from permanent storage
    method deleteBlock(offset : uint64) : Future[void] {.async.} = raiseAssert("You must implement the deleteBlock() method in your subclass.")


    ## Get and cache a block
    method getBlock(offset : uint64, loadData : bool = false) : Future[NBDBlock] {.async.} =

        # Ensure the alignment is correct
        var alignedOffset = offset - (offset mod this.blockSize)
        if alignedOffset != offset:
            raiseAssert("Requested a non-aligned block.")

        # Start the cleanup loop if needed
        asyncCheck this.startCleanupLoop()

        # Check if block is already cached
        var blk : NBDBlock = nil
        for b in this.blockCache:
            if b.offset == alignedOffset:
                blk = b
                break

        # Create if not found
        if blk == nil:

            # Create it
            blk = NBDBlock.init()
            blk.offset = alignedOffset
            blk.state = NBDBlockStateUnknown
            blk.lastAccess = cpuTime()
            this.blockCache.add(blk)

            # Check if the block exists, if that fails, then remove the block again
            try:
                blk.isLoading = true
                if await this.blockExists(alignedOffset):
                    blk.state = NBDBlockStateUnloaded
                else:
                    blk.state = NBDBlockStateUnallocated
            except:
                let idx = this.blockCache.find(blk)
                if idx != -1: this.blockCache.del(idx)
                raise getCurrentException()
            finally:
                blk.isLoading = false

        # If block is currently being loaded from another request, wait for it
        # Also wait until there's few enough pending operations
        while blk.isLoading or (blk.state == NBDBlockStateUnloaded and this.currentBlockOperations >= this.maxParallelOperations):
            await sleepAsync(1)

        # If block is unloaded, load it
        if loadData and blk.state == NBDBlockStateUnloaded:

            # Try load the data
            try:
                blk.isLoading = true
                let data = await this.readBlock(blk.offset)
                if data.len.uint64 != this.blockSize: raise newException(IOError, fmt"Wrong block size returned from readBlock(). Expected {this.blockSize} bytes, got {data.len} bytes.")
                blk.data = data
                blk.state = NBDBlockStateLoaded
                blk.isDirty = false
            except:
                blk.state = NBDBlockStateUnloaded
                blk.isDirty = false
                raise getCurrentException()
            finally:
                blk.isLoading = false

        # Sanity check: At this point, we should only ever have certain states
        if blk.isLoading: raiseAssert("Block is still loading, but it shouldn't be at this point.")
        if blk.state == NBDBlockStateUnknown: raiseAssert("Block is in unknown state, but it shouldn't be at this point.")
        if blk.state != NBDBlockStateLoaded and blk.data.len != 0: raiseAssert("Block is unloaded, but data was found.")
        if blk.state == NBDBlockStateLoaded and blk.data.len.uint64 != this.blockSize: raiseAssert("Block is loaded, but data is missing.")
        if loadData and blk.state == NBDBlockStateUnloaded: raiseAssert("Block was expected to be loaded at this point.")

        # Increment block stats
        blk.accessCounter += 1
        blk.lastAccess = cpuTime()
        
        # Done
        return blk


    ## Read data from the device
    method read(offset : uint64, length : uint32) : Future[string] {.async.} =
    
        # Create memory
        var data : string

        # Go through each block until data is filled
        var amountFilled = 0u
        for blockOffset in blockOffsetsForRange(offset, length, this.blockSize):

            # Get the block
            var blockInfo = await this.getBlock(blockOffset, loadData = true)
            
            # Check block range
            let blockDataStart = offset + amountFilled - blockInfo.offset
            let blockDataLen = min(length - amountFilled, this.blockSize - blockDataStart)
            let isEntireBlock = blockDataStart == 0 and blockDataLen == this.blockSize

            # Check if allocated
            if blockInfo.state == NBDBlockStateUnallocated:

                # Add zeroes
                data.add(newString(blockDataLen, filledWith = 0))
                amountFilled += blockDataLen
                continue

            # Copy data from the block
            if isEntireBlock:
                
                # We want the entire block, just add it directly
                data.add(blockInfo.data)
                amountFilled += blockDataLen

            else: 
                
                # We want only a part of the block, this must be the last one
                data.add(blockInfo.data[blockDataStart ..< blockDataStart + blockDataLen])
                amountFilled += blockDataLen

        # Done
        return data


    ## Write data to the device
    method write(offset : uint64, data : string) {.async.} =
    
        # Go through all data
        var amountFilled = 0u
        for blockOffset in blockOffsetsForRange(offset, data.len.uint, this.blockSize):

            # Get the block
            var blockInfo = await this.getBlock(blockOffset, loadData = false)
            
            # Check block range
            let blockDataStart = offset + amountFilled - blockInfo.offset
            let blockDataLen = min(data.len.uint - amountFilled, this.blockSize - blockDataStart)
            let isEntireBlock = blockDataStart == 0 and blockDataLen == this.blockSize

            # If the length is zero, stop
            if blockDataLen == 0:
                raiseAssert(fmt"Requested a block write of zero length! blockOffset={blockOffset} blockStart={blockDataStart} blockLen={blockDataLen}")

            # Special case: If this data covers the entire block, we don't even need to read the existing data, we can just overwrite it immediately
            if isEntireBlock:

                # Write data immediately, since it covers the whole block
                blockInfo.data = data[amountFilled ..< amountFilled + this.blockSize()]
                blockInfo.isDirty = true
                amountFilled += this.blockSize
                continue

            # If block is unloaded, load it
            blockInfo = await this.getBlock(blockOffset, loadData = true)

            # If block is unallocated, create zero data
            if blockInfo.state == NBDBlockStateUnallocated:
                blockInfo.data = newString(this.blockSize.int, filledWith = 0)
                blockInfo.isDirty = false
                blockInfo.state = NBDBlockStateLoaded

            # Sanity checks
            if blockInfo.state != NBDBlockStateLoaded: raiseAssert(fmt"Block in memory is in an invalid state! Expected it to be loaded, got {blockInfo.state}.")
            if blockInfo.data.len != this.blockSize.int: raiseAssert(fmt"Block in memory is the wrong size! Expected {this.blockSize} bytes, got {blockInfo.data.len} bytes. State is {blockInfo.state}.")

            # Copy region of source data into the block data
            blockInfo.data[blockDataStart ..< blockDataStart + blockDataLen] = data[amountFilled ..< amountFilled + blockDataLen]
            blockInfo.isDirty = true
            blockInfo.updateNonce += 1
            amountFilled += this.blockSize


    ## Write zero data to the device
    method writeZeroes(offset : uint64, length : uint32) {.async.} =
    
        # Go through all data
        var amountFilled = 0u
        for blockOffset in blockOffsetsForRange(offset, length.uint, this.blockSize):

            # Get the block
            var blockInfo = await this.getBlock(blockOffset, loadData = false)
            
            # Check block range
            let blockDataStart = offset + amountFilled - blockInfo.offset
            let blockDataLen = min(length.uint - amountFilled, this.blockSize - blockDataStart)
            let isEntireBlock = blockDataStart == 0 and blockDataLen == this.blockSize

            # If the length is zero, stop
            if blockDataLen == 0:
                raiseAssert(fmt"Requested a block write of zero length! blockOffset={blockOffset} blockStart={blockDataStart} blockLen={blockDataLen}")

            # Special case: If this data covers the entire block, we don't even need to read the existing data, we can just overwrite it immediately
            if isEntireBlock:

                # Unallocate block
                blockInfo.data = ""
                blockInfo.state = NBDBlockStateUnallocated
                blockInfo.isDirty = true
                amountFilled += this.blockSize
                continue

            # If block is unloaded, load it
            blockInfo = await this.getBlock(blockOffset, loadData = true)

            # If block is unallocated already, just stop
            if blockInfo.state == NBDBlockStateUnallocated:
                continue

            # Sanity checks
            if blockInfo.state != NBDBlockStateLoaded: raiseAssert(fmt"Block in memory is in an invalid state! Expected it to be loaded, got {blockInfo.state}.")
            if blockInfo.data.len != this.blockSize.int: raiseAssert(fmt"Block in memory is the wrong size! Expected {this.blockSize} bytes, got {blockInfo.data.len} bytes. State is {blockInfo.state}.")

            # Copy region of source data into the block data
            blockInfo.data[blockDataStart ..< blockDataStart + blockDataLen] = newString(blockDataLen, filledWith = 0)
            blockInfo.isDirty = true
            blockInfo.updateNonce += 1
            amountFilled += this.blockSize


    ## Check if region is a hole
    method regionIsHole(offset : uint64, length : uint32) : Future[bool] {.async.} =

        # Go through all blocks in this region
        for blockOffset in blockOffsetsForRange(offset, length, this.blockSize):

            # Get the block
            var blockInfo = await this.getBlock(blockOffset, loadData = false)

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
            var blockInfo = await this.getBlock(blockOffset, loadData = false)

            # Check if block is unallocated
            if blockInfo.state != NBDBlockStateUnallocated:
                continue

            # Check if data is in memory. If not, just return false. This is a slight optimization, in the case where
            # all the queried blocks are actually in memory right now. This way we don't have to read them from disk.
            # if it's not in memory, just return false even though it may actually be zeroes.
            if blockInfo.data.len == 0:
                return false

            # Check if block is all zeroes
            # TODO: Optimize this by using uint64 types and aligning it to 8 bytes
            for i in 0 ..< blockInfo.data.len:
                if blockInfo.data[i] != 0.char:
                    return false

        # All is zero
        return true


    ## Get the amount of data cached in memory
    method memoryInUse() : uint64 =
        var memoryInUse : uint64 = 0
        for b in this.blockCache:
            memoryInUse += b.data.len.uint64
        return memoryInUse


    ## True if we have any unstable blocks
    method hasUnstableBlocks() : bool =

        # True if we have dirty blocks
        if this.hasDirtyBlocks: return true

        # True if any blocks are actively loading
        var memoryInUse : uint64 = 0
        for blk in this.blockCache:
            memoryInUse += blk.data.len.uint64
            if blk.isLoading or blk.isSaving or blk.isDirty:
                return true

        # True if we're over memory usage, since those blocks will be removed soon
        if memoryInUse > this.desiredMemorySize:
            return true

        # Nothing unstable, server is steady
        return false


    ## Number of block operations in progress
    method currentBlockOperations() : int =
        var ops = 0
        for blk in this.blockCache:
            if blk.isLoading or blk.isSaving:
                ops += 1
        return ops


    ## True if there are dirty blocks
    method hasDirtyBlocks() : bool =
        for blk in this.blockCache:
            if blk.isDirty:
                return true
        return false


    ## Count number of unstable blocks
    method currentUnstableBlocks() : int =
        var ops = 0
        for blk in this.blockCache:
            if blk.isLoading or blk.isSaving or blk.isDirty:
                ops += 1
        return ops


    ## Count blocks with cached data
    method currentCachedBlocks() : int =
        var ops = 0
        for blk in this.blockCache:
            if blk.data.len > 0:
                ops += 1
        return ops


    ## Count blocks busy saving
    method currentSavingBlocks() : int =
        var ops = 0
        for blk in this.blockCache:
            if blk.isSaving:
                ops += 1
        return ops


    ## Count blocks busy loading
    method currentLoadingBlocks() : int =
        var ops = 0
        for blk in this.blockCache:
            if blk.isLoading:
                ops += 1
        return ops

    
    ## True if the cleanup loop is active
    var cleanupLoopRunning = false

    ## The cleanup loop runs constantly while the device is connected. It handles writing dirty blocks back to permanent storage.
    method startCleanupLoop() {.async.} =

        # Stop if already active
        if this.cleanupLoopRunning: return
        this.cleanupLoopRunning = true

        # Run loop
        # echo "[NBDBlockDevice] Cleanup loop started"
        while true:

            # Wait a bit so we don't end prematurely
            await sleepAsync(1)

            # Clean dirty blocks
            await this.cleanupDirtyBlocks()

            # Trim memory
            let isOverMemory = this.memoryInUse > this.desiredMemorySize
            if isOverMemory:
                await this.cleanupTrimMemory()

            # If there are no dirty blocks and data in memory is below the threshold, we can stop this loop
            if not this.hasUnstableBlocks:
                break

        # Done
        this.cleanupLoopRunning = false
        # echo "[NBDBlockDevice] Cleanup loop stopped"


    ## Cleanup a dirty block
    method cleanupDirtyBlocks() {.async.} =

        # Check if too many operations
        if this.currentBlockOperations >= this.maxParallelOperations:
            return

        # Get next dirty block
        var dirtyBlock : NBDBlock = nil
        for b in this.blockCache:
            if b.isDirty and not b.isSaving:
                dirtyBlock = b
                break

        # Stop if no dirty block found
        if dirtyBlock == nil:
            return

        # Save block in parallel
        asyncCheck this.saveDirtyBlock(dirtyBlock)


    ## Save a dirty block
    method saveDirtyBlock(dirtyBlock : NBDBlock) {.async.} =

        # Sanity check
        if not dirtyBlock.isDirty: return

        # Write block to permanent storage
        let allZero = dirtyBlock.state == NBDBlockStateUnallocated ? true ! dirtyBlock.data.allZero()
        let updateNonce = dirtyBlock.updateNonce
        try:

            # Write it
            dirtyBlock.isSaving = true
            if allZero:
                # echo "[NBDBlockDevice] Deleting zeroed dirty block: ", dirtyBlock.offset
                await this.deleteBlock(dirtyBlock.offset)
            else:
                # echo "[NBDBlockDevice] Writing dirty block: ", dirtyBlock.offset
                await this.writeBlock(dirtyBlock.offset, dirtyBlock.data)

        except:

            # On error, return so it can be tried again
            echo "[NBDBlockDevice] Error writing block to permanent storage: ", getCurrentExceptionMsg()
            return

        finally:

            # Mark as finished saving
            dirtyBlock.isSaving = false

        # If the nonce changed while we were writing, this block was modified again. It's still dirty.
        if dirtyBlock.updateNonce != updateNonce:
            return

        # Mark block as clean now, or unallocated if the block was deleted
        if allZero:
            dirtyBlock.state = NBDBlockStateUnallocated
            dirtyBlock.data = ""

        # Update access stats
        dirtyBlock.isDirty = false
        dirtyBlock.updateNonce += 1
        dirtyBlock.lastAccess = cpuTime()


    ## Removes the oldest block in memory
    method cleanupTrimMemory() {.async.} =

        # Find the oldest clean block
        var oldestBlock : NBDBlock = nil
        var oldestBlockIdx = 0
        for i, b in this.blockCache:
            if not b.isDirty and not b.isLoading and not b.isSaving:
                if oldestBlock == nil or b.lastAccess < oldestBlock.lastAccess:
                    oldestBlock = b
                    oldestBlockIdx = i

        # Stop if no clean blocks to remove
        if oldestBlock == nil:
            # echo "No trimmable blocks found..."
            return

        # Remove block from memory
        # echo "[NBDBlockDevice] Removing clean block from memory: ", oldestBlock.offset
        oldestBlock.data = ""
        oldestBlock.state = NBDBlockStateUnloaded
        
