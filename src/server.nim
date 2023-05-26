import std/[tables, parseutils, asyncdispatch, strformat, random, bitops]
import overrides/[asyncnet]
import times, print, connection, pipe
from globals import nil


type
    ServerConnectionPoolContext = object
        listener: Connection
        inbound: Connections
        outbound: Connections



var context = ServerConnectionPoolContext()



proc monitorData(data: string): tuple[trust: bool, id: uint32] =
    try:
        if len(data) < 12: return (false, 0.uint32)
        var sh1_c: uint32
        var sh2_c: uint32
        var cid: uint32

        copyMem(unsafeAddr sh1_c, unsafeAddr data[0], 4)
        copyMem(unsafeAddr sh2_c, unsafeAddr data[4], 4)
        copyMem(unsafeAddr cid, unsafeAddr data[8], 4)

        let chk1 = sh1_c == globals.sh1
        let chk2 = sh2_c == globals.sh2

        return (chk1 and chk2, cid)
    except:
        return (false, 0.uint32)



proc processConnection(client_a: Connection) {.async.} =
    # var remote: Connection
    var client: Connection = client_a

    proc proccessRemote(remote: Connection) {.async.}
    proc proccessClient() {.async.}

    proc remoteTrusted(): Future[Connection]{.async.} =
        result = newConnection(address = globals.next_route_addr)
        result.trusted = TrustStatus.yes
        await result.socket.connect(globals.next_route_addr, globals.next_route_port.Port)
        if globals.log_conn_create: echo "connected to ", globals.next_route_addr, ":", $globals.next_route_port

    proc remoteUnTrusted(): Future[Connection]{.async.} =
        result = newConnection(address = globals.final_target_ip)
        result.trusted = TrustStatus.no
        await result.socket.connect(globals.final_target_ip, globals.final_target_port.Port)
        if globals.log_conn_create: echo "connected to ", globals.final_target_ip, ":", $globals.final_target_port



    proc proccessRemote(remote: Connection) {.async.} =
        var data = ""
        while not remote.isClosed:
            try:
                data = await remote.recv(globals.chunk_size)
                if globals.log_data_len: echo &"{data.len()}bytes from remote"
            except:
                continue


            if data == "":
                if globals.log_conn_destory: echo &"closed remote"
                if client.isTrusted():
                    context.outbound.close(remote)
                    var data_to_send = ""
                    prepairTrustedSend(remote.id, data_to_send)
                    await client.sendF data_to_send
                    if globals.log_conn_destory: echo &"told tunnel to close client {remote.id}"
                else:
                    remote.close()
                    client.close()
                break

            # if(client.trusted == TrustStatus.yes):
            #     for i in 0..<data.len():
            #         data[i] = rotateRightBits(uint8(data[i]), 4).chr

            if client.isTrusted:
                if client.isClosed():
                    try:
                        client = context.inbound.takeRandom()
                        asyncCheck proccessClient()
                    except:
                        if globals.log_conn_destory: echo "no mux client left, close."
                        remote.close()
                        break

                try:
                    prepairTrustedSend(remote.id, data)
                    await client.sendF(data)
                    if globals.log_data_len: echo &"Sent {data.len()} bytes -> Trusted client"

                except: continue
            else:
                if client.isClosed():
                    remote.close()
                    break
                await client.send(data)
                if globals.log_data_len: echo &"Sent {data.len()} bytes -> UnTrusted client"


    var remote: Connection

    try:
        remote = await remoteUnTrusted()
        asyncCheck proccessRemote(remote)
    except:
        if globals.log_conn_destory: echo &"closed tunnel <-> this server due to send error"
        client.close()
        remote.close()
        return





    proc proccessClient() {.async.} =
        while not client.isClosed:

            var data = ""
            try:
                data = await client.recv(globals.chunk_size+8)
                if globals.log_data_len: echo &"{data.len()} bytes from client"


                # if data.len<1000:
                #     echo data.repr
                # if(client.trusted == TrustStatus.yes):
                #     for i in 0..<data.len():
                #         data[i] = chr(rotateRightBits(uint8(data[i]), 4))
            except:
                continue


            if client.trusted == TrustStatus.pending:
                var (trust, cid) = monitorData(data)
                if trust:
                    client.trusted = TrustStatus.yes
                    client.socket.setBuffered()
                    # context.inbound.register client

                    print "Fake Handshake Complete !"
                    remote.close()
                    remote = await remoteTrusted()
                    remote.id = 0
                    context.outbound.register remote
                    asyncCheck proccessRemote(remote)

                    continue
                elif (epochTime().uint - client.creation_time) > globals.trust_time:
                    echo "gfw fake connection detected !"
                    client.trusted = TrustStatus.no


            if data == "":
                if remote.isTrusted():
                    if globals.log_conn_destory: echo &"closed mux connection to tunnel"
                    context.inbound.close(client)
                else:
                    if globals.log_conn_destory: echo &"closed full connection"

                    remote.close()
                    client.close()

                break


            try:
                if client.isTrusted():
                    if globals.mux:
                        var (cid, pack) = muxRead(data)

                        if pack == "":
                            if context.outbound.connections.hasKey(cid):
                                context.outbound.close(context.outbound.connections[cid])
                                if globals.log_data_len: echo &"closed this server <-> trusted remote {cid}"
                            continue
                        if cid == 0:
                            if globals.log_data_len: echo "was 0"
                            quit()

                        if not context.outbound.connections.hasKey(cid):
                            remote = await remoteTrusted()
                            remote.id = cid
                            context.outbound.register(remote)
                            asyncCheck proccessRemote(remote)


                        await context.outbound.connections[cid].send(pack)
                        if globals.log_data_len: echo &"{pack.len()} bytes -> Trusted remote"

                    else:
                        if remote.isClosed: continue
                        normalRead(data)
                        await remote.send(data)
                        if globals.log_data_len: echo &"{data.len()}bytes -> remote"

                else:
                    if remote.isClosed:
                        client.close()
                        break

                    await remote.send(data)
                    if globals.log_data_len: echo &"{data.len()}bytes -> remote"

            except:
                printEx()
                continue




    try:
        asyncCheck proccessClient()
        # asyncCheck remoteHasData()
    except:
        echo "[Server] root level exception"
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
            let con = newConnection(client, address)
            if globals.log_conn_create: print "Connected client: ", address
            asyncCheck processConnection(con)




    echo &"Mode Server:   {globals.listen_addr} <-> ({globals.final_target_domain} with ip {globals.final_target_ip})"
    asyncCheck start_server()
