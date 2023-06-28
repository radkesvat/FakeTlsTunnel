import std/[asyncdispatch, nativesockets, strformat, strutils, net, tables, random, endians]
import overrides/[asyncnet]
import times, print, connection, pipe
from globals import nil

when defined(windows):
    from winlean import getSockOpt
else:
    from posix import getSockOpt

type
    TunnelConnectionPoolContext = object
        listener: Connection
        inbound: Connections
        outbound: Table[uint32, Connections]

var context = TunnelConnectionPoolContext()
let ssl_ctx = newContext(verifyMode = CVerifyPeer)


proc sslConnect(con: Connection, ip: string, client_origin_port: uint32, sni: string){.async.} =
    wrapSocket(ssl_ctx, con.socket)
    con.isfakessl = true
    var fc = 0
    while true:
        if fc > 3:
            con.close()
            raise newException(ValueError, "[SslConnect] could not connect, all retires failed")
    
        var fut = con.socket.connect(ip, con.port.Port, sni = sni)
        var timeout = withTimeout(fut, 6000)
        yield timeout
        if timeout.failed():
            inc fc
            if globals.log_conn_error: echo timeout.error.msg
            if globals.log_conn_error: echo &"[SslConnect] retry in {min(1000,fc*200)} ms"
            await sleepAsync(min(1000, fc*200))
            continue
        if timeout.read() == true:
            break
        if timeout.read() == false:
            raise newException(ValueError, "[SslConnect] dial timed-out")
            
 

    if globals.log_conn_create: print "ssl socket conencted"

    # let to_send = &"GET / HTTP/1.1\nHost: {sni}\nAccept: */*\n\n"
    # await socket.send(to_send)  [not required ...]

    #now we use this socket as a normal tcp data transfer socket
    con.socket.isSsl = false

    #AES default chunk size is 16 so use a multple of 16
    let rlen = 16*(4+rand(4))
    var random_trust_data: string
    random_trust_data.setLen(rlen)

    prepareMutation(random_trust_data)
    copyMem(unsafeAddr random_trust_data[0], unsafeAddr globals.sh1.uint32, 4)
    copyMem(unsafeAddr random_trust_data[4], unsafeAddr globals.sh2.uint32, 4)
    if globals.multi_port:
        copyMem(unsafeAddr random_trust_data[8], unsafeAddr client_origin_port, 4)
    # copyMem(unsafeAddr random_trust_data[12], unsafeAddr con.id, 4)
    copyMem(unsafeAddr random_trust_data[12], unsafeAddr(globals.random_600[rand(250)]), rlen-12)


    await con.socket.send(random_trust_data)
            
    con.trusted = TrustStatus.yes


proc poolFrame(client_port: uint32, count: uint = 0){.gcsafe.} =
    proc create() =
        var con = newConnection()
        con.port = globals.next_route_port.uint32
        var fut = sslConnect(con, globals.next_route_addr, client_port, globals.final_target_domain)
        
        fut.addCallback(
            proc() {.gcsafe.} =      
                if fut.failed:
                    try:
                        con.close()
                    except:
                        if globals.log_conn_error: echo fut.error.msg
                else:
                    if globals.log_conn_create: echo &"[createNewCon] registered a new connection to the pool"
                    context.outbound[client_port].register con
        )

    if count == 0:
        var i = context.outbound[client_port].connections.len().uint

        if i < globals.pool_size div 2:
            create()
            create()
        elif i < globals.pool_size:
            create()

    else:
        for i in 0..count:
            create()




proc processConnection(client_a: Connection) {.async.} =
    var client: Connection = client_a
    var remote: Connection

    var closed = false
    proc close() =
        if not closed:
            closed = true
            if globals.log_conn_destory: echo "[processRemote] closed client & remote"
            if remote != nil:
                remote.close()
            
            client.close()


    proc processRemote() {.async.} =
        var data =  newStringOfCap(cap = 1500)

        while (not remote.isClosed) and (not client.isClosed):
            try:
                data = await remote.recv(globals.chunk_size)
                if globals.log_data_len: echo &"[processRemote] {data.len()} bytes from remote"

                if data.len() == 0:
                    break

                normalRead(data)
                if not client.isClosed:
                    await client.send(data)
                    if globals.log_data_len: echo &"[processRemote] {data.len} bytes -> client "

            except: break
        close()

    proc chooseRemote() {.async.} =
        if not context.outbound.hasKeyOrPut(client.port, Connections()):
            poolFrame(client.port, globals.pool_size)

        for i in 0..<16:
            remote = context.outbound[client.port].grab()

            if remote != nil: break
            await sleepAsync(100)

        if remote != nil:
            if globals.log_conn_create: echo &"[createNewCon][Succ] grabbed a connection"
            callSoon do: poolFrame(client.port)
            asyncCheck processRemote()
        else:
            if globals.log_conn_destory: echo &"[createNewCon][Error] left without connection, closes forcefully."
            callSoon do: poolFrame(client.port)
            client.close()



    proc processClient() {.async.} =
        var data =  newStringOfCap(cap = 1500)

        while (not client.isClosed) and (not remote.isClosed):
            try:
                data = await client.recv(globals.chunk_size)
                if globals.log_data_len: echo &"[processClient] {data.len()} bytes from client {client.id}"

                if data.len() == 0:
                    break

                if not remote.isClosed:
                    normalSend(data)
                    await remote.send(data)
                    if globals.log_data_len: echo &"{data.len} bytes -> Remote"

            except: break
        close()

    try:
        await chooseRemote()
        asyncCheck processClient()
    except:
        printEx()

proc start*(){.async.} =
    var pbuf = newString(len = 16)

    proc start_server(){.async.} =

        context.listener = newConnection()
        context.listener.socket.setSockOpt(OptReuseAddr, true)
        context.listener.socket.bindAddr(globals.listen_port.Port, globals.listen_addr)
        if globals.multi_port:
            globals.listen_port = getSockName(context.listener.socket.getFd().SocketHandle).uint32
            globals.createIptablesRules()

        echo &"Started tcp server... {globals.listen_addr}:{globals.listen_port}"
        context.listener.socket.listen()

        while true:
            let (address, client) = await context.listener.socket.acceptAddr()
            var con = newConnection(client)
            if globals.multi_port:
                var origin_port: cushort
                var size = 16.SockLen
                if getSockOpt(con.socket.getFd().SocketHandle, cint(globals.SOL_IP), cint(globals.SO_ORIGINAL_DST),
                addr(pbuf[0]), addr(size)) < 0'i32:
                    echo "multiport failure getting origin port. !"
                    continue
                bigEndian16(addr origin_port, addr pbuf[2])

                con.port = origin_port
                if globals.log_conn_create: print "Connected client: ", address, " : ", con.port
            else:
                con.port = globals.listen_port

                if globals.log_conn_create: print "Connected client: ", address

            asyncCheck processConnection(con)

    if not globals.multi_port:
        context.outbound[globals.listen_port] = Connections()
        poolFrame(globals.listen_port, globals.pool_size)

    await sleepAsync(2500)
    echo &"Mode Tunnel:  {globals.self_ip} <->  {globals.next_route_addr}  => {globals.final_target_domain}"
    asyncCheck start_server()



