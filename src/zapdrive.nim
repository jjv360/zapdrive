import std/strformat
import std/asyncdispatch
import ./zapdrivenbdserver

when isMainModule:
    
    # Start server
    echo "Starting server..."
    var server = ZapDriveNBDServer().init(bindAddress = "0.0.0.0")  # TODO: Remove bind address
    echo fmt"Server is listening on {server.port}"

    # Keep app running as long as asyncdispatch is still doing things
    while hasPendingOperations():
        drain()

    # Finished
    echo "Server is shutting down..."