import std/[tables, parseutils, asyncdispatch, strformat,strutils,net, random,bitops]
import overrides/[asyncnet]
import times, print,connection,pipe
from globals import nil



type
    TunnelConnectionPoolContext = object
        listener: Connection 
        inbound: Connections
        outbound: Connections
        
var context = TunnelConnectionPoolContext()
let ssl_ctx = newContext(verifyMode = CVerifyPeer)

        

proc ssl_connect(con: Connection,cid:uint32, ip: string, port: int, sni: string){.async.} =
    # let socket = newAsyncSocket(buffered = globals.socket_buffered)
    wrapSocket(ssl_ctx, con.socket)
    # await socket.connect("jsonplaceholder.typicode.com",Port(443))

    while true:
        try:

            await con.socket.connect(ip, port.Port, sni = sni)

            break
        except :
            echo "ssl connect error !"
            # echo getCurrentExceptionMsg()
                 
    print "ssl socket conencted"
    
    let to_send = &"GET / HTTP/1.1\nHost: {sni}\nAccept: */*\n\n"

    # await socket.send(to_send)  [not required ...]

    con.socket.isSsl = false #now break it

    let rlen = 20 #you can change it to a random lenght, i didn't because im testing
    var random_trust_data: string
    random_trust_data.setLen(rlen)

    for i in 0..<rlen:
        random_trust_data[i] = rand(char.low .. char.high).char

    prepareMutation(random_trust_data)
    copyMem(unsafeAddr random_trust_data[0], unsafeAddr globals.sh1.uint32, 4)
    copyMem(unsafeAddr random_trust_data[4], unsafeAddr globals.sh2.uint32, 4)
    copyMem(unsafeAddr random_trust_data[8], unsafeAddr    cid, 4)

    # echo "sent junk trust data"
    # echo repr random_trust_data
    await con.socket.send(random_trust_data)
    # echo "sent trust data"
    con.trusted = TrustStatus.yes




proc processConnection(client: Connection) {.async.} =
    var client: Connection = client

    # var closed = false
    proc chooseRemote() {.async.}


    proc processRemote(arg_remote: Connection) {.async.} =
        var remote = arg_remote
        while not remote.isClosed:
            var data = ""
            try:
                data = await remote.recv(globals.chunk_size+8)
                # for i in 0..<data.len():
                #     data[i] = rotateLeftBits(uint8(data[i]),4).chr
                if globals.log_data_len: echo &"{data.len()} bytes from remote"
                # if data.len() != globals.chunk_size+8:
                #     continue 
            except:
                break
   
            if data == "" :
                # client.close()
                if globals.log_conn_destory: echo "closed mux connection to remote"
                context.outbound.close(remote)
                break

            # if not client.isClosed:

            try:
                var (cid, pack) = muxRead(data)
                if pack == "":
                    if globals.log_conn_destory: echo "Closing: " ,cid
                    context.inbound.close(context.inbound.connections[cid])

                elif not context.inbound.connections.hasKey(cid):
                    if cid == 0:
                        echo "Fatal Error: dose not have key:  ", cid
                        quit(-1)
                
                else:
                    if not context.inbound.connections[cid].isClosed:
                        await context.inbound.connections[cid].send(pack)
                        if globals.log_data_len: echo &"{pack.len} bytes -> client "

            except:continue



    var remote: Connection

    proc makecon(){.async.}=
        var remote_con = newConnection(address = globals.next_route_addr,buffered=true)
        await ssl_connect(remote_con,client.id, globals.next_route_addr, globals.next_route_port, globals.final_target_domain)
        context.outbound.register(remote_con)
        asyncCheck processRemote(remote_con)
    proc chooseRemote() {.async.}=

        try:
            remote = context.outbound.takeRandom()
            assert not remote.isClosed()
        except :
            if globals.log_conn_create:echo "creating 2 new mux connections"
            await makecon()
            await makecon()
            await chooseRemote()
            
    await chooseRemote()



    proc processClient() {.async.} =
        var data = ""

        while not client.isClosed:

            try:
                data = await client.recv(globals.chunk_size)
                if globals.log_data_len: echo &"{data.len()} bytes from client"
            except:
                context.inbound.close(client)
                var data_to_send = ""
                prepairTrustedSend(client.id, data_to_send)
                if  remote.isClosed:
                    await chooseRemote()
                await remote.sendF data_to_send
                break
            

            if data == "":
                if globals.log_conn_destory: echo &"closed  client socket {client.id}"
                context.inbound.close(client)
                var data_to_send = ""
                prepairTrustedSend(client.id, data_to_send)
                if  remote.isClosed:
                    await chooseRemote()
                await remote.sendF data_to_send
                if globals.log_data_len: echo &"{data_to_send.len} bytes -> Trusted Remote"

                break
            
            # for i in 0..<data.len():
            #     data[i] = rotateLeftBits(uint8(data[i]),4).chr

            if  remote.isClosed:
                await chooseRemote()
            
            try:
                prepairTrustedSend(client.id,data)
                await remote.sendF(data)
                if globals.log_data_len: echo &"{data.len} bytes -> Trusted Remote"

            except:continue


    try:
        asyncCheck processClient()
    except:
        print getCurrentExceptionMsg()


proc start*(){.async.} =
    proc start_server(){.async.} =
        
        context.listener = newConnection(address = "This Server")
        context.listener.socket.setSockOpt(OptReuseAddr, true)
        context.listener.socket.bindAddr(globals.listen_port.Port, globals.listen_addr)
        echo &"Started tcp server... {globals.listen_addr}:{globals.listen_port}"
        context.listener.socket.listen()

        while true:
            let (address, client) = await context.listener.socket.acceptAddr()
            var con = newConnection(client, address)
            context.inbound.register(con)
            if globals.log_conn_create: print "Connected client: ", address

            asyncCheck processConnection(con)



    echo &"Mode Tunnel:  {globals.self_ip}  <->  {globals.next_route_addr}  => {globals.final_target_domain}"
    asyncCheck start_server()
