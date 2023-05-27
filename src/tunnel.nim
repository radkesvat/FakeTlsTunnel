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

        

proc ssl_connect(con: Connection, ip: string, port: int, sni: string){.async.} =
    wrapSocket(ssl_ctx, con.socket)

    var fc = 0
    while true:
        
        try:
            await con.socket.connect(ip, port.Port, sni = sni)
            break
        except :
            echo &"ssl connect error ! retry in {min(150,fc*50)} ms"
            await sleepAsync(min(150,fc*25))
            inc fc

                 
    print "ssl socket conencted"
    
    # let to_send = &"GET / HTTP/1.1\nHost: {sni}\nAccept: */*\n\n"

    # await socket.send(to_send)  [not required ...]

    con.socket.isSsl = false #now break it

    let rlen = 16*(2+rand(4)) 
    var random_trust_data: string
    random_trust_data.setLen(rlen)

    for i in 0..<rlen:
        random_trust_data[i] = rand(char.low .. char.high).char

    prepareMutation(random_trust_data)
    copyMem(unsafeAddr random_trust_data[0], unsafeAddr globals.sh1.uint32, 4)
    copyMem(unsafeAddr random_trust_data[4], unsafeAddr globals.sh2.uint32, 4)

    await con.socket.send(random_trust_data)
    con.trusted = TrustStatus.yes




proc processRemote(arg_remote: Connection) {.async.} =
        var remote = arg_remote
        var data = ""
        while not remote.isClosed:
           
            try:
                data = await remote.recv(globals.chunk_size+8)
                if globals.log_data_len: echo &"[processRemote] {data.len()} bytes from remote"
            except:
                break
   
            if data.len() == 0 :
                if globals.log_conn_destory: echo "[processRemote] closed connection to remote"
                context.outbound.close(remote)
                break

            try:
                var (cid, pack) = muxRead(data)
                if pack == "":
                    if  context.inbound.connections.hasKey(cid):
                        if globals.log_conn_destory: echo "[processRemote] Closing client: " ,cid
                        context.inbound.close(context.inbound.connections[cid])

                elif not context.inbound.connections.hasKey(cid):
                    if cid == 0:
                        echo "[processRemote] Fatal Error: dose not have key:  ", cid
                        quit(-1)
                
                else:
                    if not context.inbound.connections[cid].isClosed:
                        await context.inbound.connections[cid].send(pack)
                        if globals.log_data_len: echo &"[processRemote] {pack.len} bytes -> client "

            except:continue

proc createNewCon(){.async.}=
    var remote_con = newConnection(address = globals.next_route_addr,buffered=true)
    await ssl_connect(remote_con,globals.next_route_addr, globals.next_route_port, globals.final_target_domain)
    context.outbound.register(remote_con)
    if globals.log_conn_create:echo &"[createNewCon] created a new mux connection"
    asyncCheck processRemote(remote_con)


proc refillConnectionPool(){.async.}=
    while true:
        var count = globals.con_pool_size - context.outbound.connections.len()
        if count > 0:
            await createNewCon()

        else:break

proc processConnection(client: Connection) {.async.} =
    var client: Connection = client

    # var closed = false
    proc chooseRemote() {.async.}


    


    var remote: Connection


    proc chooseRemote() {.async.}=
        try:
            asyncCheck refillConnectionPool()
            remote = context.outbound.takeRandom()
            assert not remote.isClosed()
        except :
            await createNewCon()
            remote = context.outbound.takeRandom()
            assert not remote.isClosed()
            
    await chooseRemote()



    proc processClient() {.async.} =
        var data = ""
        proc close() {.async.} =
            if globals.log_conn_destory: echo &"[processClient] closed client socket {client.id}"
            context.inbound.close(client)
            var data_to_send = ""
            prepairTrustedSend(client.id, data_to_send)
            if  remote.isClosed:
                await chooseRemote()
            await remote.send data_to_send
            if globals.log_data_len: echo &"[processClient] client {client.id} sent {data_to_send.len} bytes -> Trusted Remote"

        while not client.isClosed:

            try:
                data = await client.recv(globals.chunk_size)
                if globals.log_data_len: echo &"[processClient] {data.len()} bytes from client {client.id}"
            except:
                # await close()
                break
            
            if data == "":
                await close()
                break

            if  remote.isClosed:
                await chooseRemote()
            try:
                prepairTrustedSend(client.id,data)
                await remote.send(data)
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


    await refillConnectionPool()
    echo &"Mode Tunnel:  {globals.self_ip}  <->  {globals.next_route_addr}  => {globals.final_target_domain}"
    asyncCheck start_server()

