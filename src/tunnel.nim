import std/[asyncdispatch, nativesockets, strformat, strutils, net, tables, random]
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
        outbound: Connections

var context = TunnelConnectionPoolContext()
let ssl_ctx = newContext(verifyMode = CVerifyPeer)


proc ssl_connect(con: Connection, ip: string, port: int, sni: string){.async.} =
    wrapSocket(ssl_ctx, con.socket)
    con.isfakessl = true
    var fc = 0
    while true:
        if fc > 6:
            raise newException(ValueError, "Request Timed Out!")
        try:
            await con.socket.connect(ip, port.Port, sni = sni)
            break
        except:
            echo &"ssl connect error ! retry in {min(1000,fc*50)} ms"
            await sleepAsync(min(1000, fc*200))
            inc fc

    print "ssl socket conencted"

    # let to_send = &"GET / HTTP/1.1\nHost: {sni}\nAccept: */*\n\n"
    # await socket.send(to_send)  [not required ...]

    con.socket.isSsl = false #now break it

    let rlen = 16*(4+rand(4))
    var random_trust_data: string
    random_trust_data.setLen(rlen)

    for i in 0..<rlen:
        random_trust_data[i] = rand(char.low .. char.high).char

    prepareMutation(random_trust_data)
    copyMem(unsafeAddr random_trust_data[0], unsafeAddr globals.sh1.uint32, 4)
    copyMem(unsafeAddr random_trust_data[4], unsafeAddr globals.sh2.uint32, 4)
    copyMem(unsafeAddr random_trust_data[8], unsafeAddr con.port, 4)
    copyMem(unsafeAddr random_trust_data[12], unsafeAddr con.id, 4)

    await con.socket.send(random_trust_data)
    con.trusted = TrustStatus.yes


proc poolFrame(count: uint = 0){.gcsafe.} =
    proc create() =
        var con = newConnection(address = globals.next_route_addr)
        var fut = ssl_connect(con, globals.next_route_addr, globals.next_route_port, globals.final_target_domain)
        fut.addCallback(
            proc() {.gcsafe.} =
            if fut.failed:
                echo fut.error.msg
            else:
                if globals.log_conn_create: echo &"[createNewCon] registered a new connection to the pool"
                context.outbound.register con
        )


    var i = context.outbound.connections.len()
    while i.uint32 < (if count == 0: globals.pool_size else: count):
        try:
            create()
            inc i
        except:
            discard




proc processConnection(client: Connection) {.async.} =
    var client: Connection = client
    var remote: Connection

    var closed = false
    proc close() =
        if not closed:
            closed = true
            if globals.log_conn_destory: echo "[processRemote] closed client & remote"
            client.close()
            if not remote.isNil():
                remote.close()


    proc processRemote() {.async.} =
        var data = ""
        while not remote.isClosed:
            try:
                data = await remote.recv(globals.chunk_size)
                if globals.log_data_len: echo &"[processRemote] {data.len()} bytes from remote"
            except:
                break

            if data.len() == 0:
                break

            try:
                normalRead(data)
                if not client.isClosed:
                    await client.send(data)
                    if globals.log_data_len: echo &"[processRemote] {data.len} bytes -> client "

            except: break
        close()

    proc chooseRemote() {.async.} =
        remote = context.outbound.grab()
        if remote != nil:
            if globals.log_conn_create: echo &"[createNewCon][Succ] grabbed a connection"
            callSoon do: poolFrame()

            asyncCheck processRemote()
            return

        await sleepAsync(600)
        remote = context.outbound.grab()

        if remote != nil:
            if globals.log_conn_create: echo &"[createNewCon][Succ] grabbed a connection"
            callSoon do: poolFrame()
            asyncCheck processRemote()
        else:

            if globals.log_conn_destory: echo &"[createNewCon][Error] left without connection, closes forcefully."
            callSoon do: poolFrame(1)
            client.close()


    await chooseRemote()


    proc processClient() {.async.} =
        var data = ""

        while not client.isClosed:
            try:
                data = await client.recv(globals.chunk_size)
                if globals.log_data_len: echo &"[processClient] {data.len()} bytes from client {client.id}"
            except:
                break

            if data.len() == 0:
                break
            try:
                if not remote.isClosed:
                    normalSend(data)
                    await remote.send(data)
                    if globals.log_data_len: echo &"{data.len} bytes -> Remote"

            except: break
        close()
    try:
        asyncCheck processClient()
    except:
        print getCurrentExceptionMsg()




proc start*(){.async.} =
    var pbuf = newString(len = 16)

    proc start_server(){.async.} =

        context.listener = newConnection(address = "This Server")
        context.listener.socket.setSockOpt(OptReuseAddr, true)
        context.listener.socket.bindAddr(globals.listen_port.Port, globals.listen_addr)
        if globals.multi_port:
            globals.listen_port = getSockName(context.listener.socket.getFd().SocketHandle).int
            echo "Multi port mode !"
            globals.createIptablesRules()

        echo &"Started tcp server... {globals.listen_addr}:{globals.listen_port}"
        context.listener.socket.listen()

        while true:
            let (address, client) = await context.listener.socket.acceptAddr()
            var con = newConnection(client, address)
            if globals.multi_port:
                var origin_port:cushort
                var size = 16.SockLen
                if getSockOpt(con.socket.getFd().SocketHandle, cint(globals.SOL_IP), cint(globals.SO_ORIGINAL_DST),
                addr(pbuf[0]), addr(size)) < 0'i32:
                    echo "multiport failure getting origin port. !"
                    continue
                copyMem(addr origin_port,addr pbuf[2],2)
            
                if globals.log_conn_create: print "Connected client: ", address , " : ", origin_port
            else:
                if globals.log_conn_create: print "Connected client: ", address

            asyncCheck processConnection(con)

    poolFrame()
    await sleepAsync(1200)
    echo &"Mode Tunnel:  {globals.self_ip}  <->  {globals.next_route_addr}  => {globals.final_target_domain}"
    asyncCheck start_server()



