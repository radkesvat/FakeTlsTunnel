import std/[tables, parseutils, asyncdispatch, strformat,strutils, net, random,bitops]
import overrides/[asyncnet]
import times, print
from globals import nil

type
    Connections = object
        connections: Table[uint32, AsyncSocket]

    TunnelConnectionPoolContext = object
        listener: AsyncSocket 

var context = TunnelConnectionPoolContext()
let ssl_ctx = newContext(verifyMode = CVerifyPeer)

        

proc ssl_connect(socket: AsyncSocket, ip: string, port: int, sni: string){.async.} =
    # let socket = newAsyncSocket(buffered = globals.socket_buffered)
    wrapSocket(ssl_ctx, socket)
    # await socket.connect("jsonplaceholder.typicode.com",Port(443))
    while true:
        try:
            await socket.connect(ip, port.Port, sni = sni)
            break
        except :
            echo "ssl connect error: "
            echo getCurrentExceptionMsg()
                 
    print "ssl socket conencted"
    
    let to_send = &"GET / HTTP/1.1\nHost: {sni}\nAccept: */*\n\n"

    # await socket.send(to_send)  [not required ...]

    socket.isSsl = false #now break it

    let rlen = 20 #you can change it to a random lenght, i didn't because im testing
    var random_trust_data: string
    random_trust_data.setLen(rlen)

    for i in 0..<rlen:
        random_trust_data[i] = rand(char.low .. char.high).char

    prepareMutation(random_trust_data)
    copyMem(unsafeAddr random_trust_data[0], unsafeAddr globals.sh1.uint32, 4)
    copyMem(unsafeAddr random_trust_data[4], unsafeAddr globals.sh2.uint32, 4)

   
    # echo "sent junk trust data"
    # echo repr random_trust_data
    await socket.send(random_trust_data)
    socket.trusted = TrustStatus.pending


proc processClient(client_addr: string, client: AsyncSocket) {.async.} =
    var remote: AsyncSocket

    var closed = false

    proc close() =
        if not closed:
            if globals.log_conn_destory: echo &"Closing:   {client_addr}  <->  {globals.self_ip}"

            closed = true
            client.close()
            remote.close()

    proc remoteHasData() {.async.} =
        while not client.isClosed and not remote.isClosed:
            var data = ""
            try:
                data = await remote.recv(1400)
                for i in 0..<data.len():
                    data[i] = rotateLeftBits(uint8(data[i]),4).chr
                if globals.log_data_len: echo &"{data.len()} bytes from remote"
            except:
                close()
                break
   
            if data == "" :
                client.close()
                remote.close()
                break

            if not client.isClosed:
                try:
                    await client.send(data)
                except:continue

                if globals.log_data_len: echo &"{globals.next_route_addr} bytes -> client "



    proc chooseRemote() {.async.}=
        remote = newAsyncSocket(buffered = globals.socket_buffered)
        remote.setSockOpt(OptNoDelay, true)
        await ssl_connect(remote, globals.next_route_addr, globals.next_route_port, globals.final_target_domain)
        asyncCheck remoteHasData()
        
    await chooseRemote()



    proc clientHasData() {.async.} =
        while not client.isClosed and not remote.isClosed:

            var data = ""
            try:
                data = await client.recv(1400)
                if globals.log_data_len: echo &"{data.len()} bytes from client"
            except:
                close()
                break
            

            if data == "":
                close()
                remote.close()
                break
            
            for i in 0..<data.len():
                data[i] = rotateLeftBits(uint8(data[i]),4).chr
                
            if not remote.isClosed:
                try:
                    
                    await remote.send(data)
                except:continue
                if globals.log_data_len: echo &"{client_addr} bytes -> {globals.next_route_addr}"


    try:
        asyncCheck clientHasData()
    except:
        print getCurrentExceptionMsg()


proc start*(){.async.} =
    proc start_server(){.async.} =
        context.listener = newAsyncSocket(buffered = globals.socket_buffered)
        context.listener.setSockOpt(OptReuseAddr, true)
        context.listener.setSockOpt(OptNoDelay, true)

        context.listener.bindAddr(globals.listen_port.Port, globals.listen_addr)
        echo &"Started tcp server... {globals.listen_addr}:{globals.listen_port}"
        context.listener.listen()

        while true:
            let (address, client) = await context.listener.acceptAddr()
            client.setSockOpt(OptNoDelay, true)

            if globals.log_conn_create: print "Connected client: ", address

            asyncCheck processClient(address, client)



    echo &"Mode Tunnel:  {globals.self_ip}  <->  {globals.next_route_addr}  => {globals.final_target_domain}"
    asyncCheck start_server()
