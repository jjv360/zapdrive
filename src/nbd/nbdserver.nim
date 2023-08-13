import std/asyncnet
import std/asyncdispatch
import std/strformat
import std/strutils
import classes
import ./nbd_classes
import ./utils
import ./constants
import ./logic_options
import ./logic_transmission


##
## This class creates a NBD server interface. It is used to createa  virtual block device which can be accessed by an NBD client driver.
class NBDServer:

    ## Server
    var serverSocket : AsyncSocket

    ## Active clients
    var clients : seq[NBDConnection]

    ## Constructor
    method start(port : int = 0, bindAddress : string = "127.0.0.1") =

        # Create server
        this.serverSocket = newAsyncSocket()
        this.serverSocket.setSockOpt(OptReusePort, true)

        # Check port
        if port == 0:

            # Attept to bind to the IANA-registered port, if fails fall back to any port
            try:
                this.serverSocket.bindAddr(Port(10809), bindAddress)
            except:
                this.serverSocket.bindAddr(Port(0), bindAddress)

        else:

            # Just use the port
            this.serverSocket.bindAddr(Port(port), bindAddress)

        # Start listening for connections
        this.serverSocket.listen()
        asyncCheck this.internalStart()


    ## The port the server is listening on
    method port() : int =
        if this.serverSocket == nil: return -1
        else: return this.serverSocket.getLocalAddr()[1].int


    ## Listen and accept connections
    method internalStart() {.async.} =

        # Do loop
        while true:

            # Accept a connection and process it
            var sock = await this.serverSocket.accept()
            asyncCheck this.internalHandleIncomingConnection(sock)


    ## Create a connection to a client. This can be overridden by subclasses.
    method createConnection() : NBDConnection = return NBDConnection.init()


    ## Get exported device list.
    method listDevices() : Future[seq[NBDDeviceInfo]] {.async.} = 
        return newSeq[NBDDeviceInfo](0)


    ## Open a block device
    method openDevice(deviceInfo : NBDDeviceInfo) : Future[NBDDevice] {.async.} =
        raise newException(IOError, "Device not found.")


    ## Handle a connection to a client
    method internalHandleIncomingConnection(sock : AsyncSocket) {.async.} =

        # Store connection
        var connection = this.createConnection()
        connection.socket = sock
        this.clients.add(connection)

        # Log it
        connection.log(fmt"Incoming connection from {connection.remoteAddress}")

        # Catch errors
        try:

            # Send connection event
            await connection.onConnectionStart()

            # Send the initial handshake
            var packet : seq[uint8]
            packet.add("NBDMAGIC")
            packet.add("IHAVEOPT")

            # Send handshake flags
            packet.add((NBD_FLAG_FIXED_NEWSTYLE).uint16)

            # Send packet
            await sock.send(packet)

            # Wait for client response
            var clientFlags = await sock.recvUint32()

            # Check that the client supports fixed newstyle
            if (clientFlags and NBD_FLAG_C_FIXED_NEWSTYLE) == 0:
                raise newException(IOError, "Client does not support fixed newstyle.")

            # Make sure the client didn't set NBD_FLAG_C_NO_ZEROES since we didn't set it
            if (clientFlags and NBD_FLAG_C_NO_ZEROES) != 0:
                connection.log("Warning: Client didn't respond with NBD_FLAG_C_NO_ZEROES")#raise newException(IOError, "Client set NBD_FLAG_C_NO_ZEROES but we didn't set it.")

            # Fail if any other bits are set
            if (clientFlags and not (NBD_FLAG_C_FIXED_NEWSTYLE or NBD_FLAG_C_NO_ZEROES)) != 0:
                raise newException(IOError, "Client set unknown flags.")

            # Handshake complete, now we can start option haggling
            connection.log("Processing client options...")
            var devices = await this.listDevices()
            var deviceInfo = await handleOptionHaggling(connection, devices)

            # Open device
            var device = await this.openDevice(deviceInfo)
            if device == nil:
                raise newException(IOError, "Device not found.")

            # Connect the device if needed
            if not device.connected:
                await device.connect()
                device.connected = true
            
            # Notify the connection
            await connection.onDeviceAccessStart(connection.device)

            # Start the connection
            connection.log(fmt"Opened device '{device.info.name}' successfully.")
            connection.device = device

            # Option haggling complete, now we're in transmission mode
            await handleTransmissionPhase(connection)

        except NBDDisconnect:

            # Soft disconnect from the client.
            connection.log(fmt"Client disconnected.")

        except: 
            
            # Error!
            connection.log(fmt"Error: {getCurrentExceptionMsg()}")
            await connection.onConnectionError(getCurrentException())

        # Close connection
        connection.log("Closing connection.")
        sock.close()

        # Remove from active clients
        var idx = this.clients.find(connection)
        if idx != -1: this.clients.del(idx)

        # Send close event
        await connection.onConnectionClose()


    
