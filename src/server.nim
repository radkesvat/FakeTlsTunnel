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



proc monitorData(data: string): bool =
    try:
        if len(data) < 8: return false
        var sh1_c: uint32
        var sh2_c: uint32

        copyMem(unsafeAddr sh1_c, unsafeAddr data[0], 4)
        copyMem(unsafeAddr sh2_c, unsafeAddr data[4], 4)

        let chk1 = sh1_c == globals.sh1
        let chk2 = sh2_c == globals.sh2

        return chk1 and chk2
    except:
        return false



proc processConnection(client_a: Connection) {.async.} =
    # var remote: Connection
    var client: Connection = client_a

    proc proccessRemote(remote_arg: Connection) {.async.}
    proc proccessClient() {.async.}

    proc remoteTrusted(id : uint32): Future[Connection]{.async.} =
        var new_remote = newConnection(address = globals.next_route_addr)
        new_remote.trusted = TrustStatus.yes
        if not context.outbound.connections.hasKey(id):
            new_remote.id = id
            context.outbound.register new_remote
            await new_remote.socket.connect(globals.next_route_addr, globals.next_route_port.Port)
            if globals.log_conn_create: echo "connected to ", globals.next_route_addr, ":", $globals.next_route_port
            return new_remote
        else:
            if context.outbound.connections[id].isClosed():
                context.outbound.close(context.outbound.connections[id])
                return await remoteTrusted(id)
            else:
                return context.outbound.connections[id]

    proc remoteUnTrusted(): Future[Connection]{.async.} =
        var new_remote = newConnection(address = globals.final_target_ip)
        new_remote.trusted = TrustStatus.no
        await new_remote.socket.connect(globals.final_target_ip, globals.final_target_port.Port)
        if globals.log_conn_create: echo "connected to ", globals.final_target_ip, ":", $globals.final_target_port
        return new_remote


    proc proccessRemote(remote_arg: Connection) {.async.} =
        var remote = remote_arg
        var data = ""
        while not remote.isClosed:
            try:
                data = await remote.recv(globals.chunk_size)
                if globals.log_data_len: echo &"[proccessRemote] {data.len()} bytes from remote"
            except:
                continue


            if client.isClosed():
                try:
                    client = context.inbound.takeRandom()
                    asyncCheck proccessClient()
                except:
                    if globals.log_conn_destory: echo "[proccessRemote] no mux client left, closing..."
                    remote.close()
                    break
                    
            if data == "":
                if globals.log_conn_destory: echo &"[proccessRemote] closed remote"
                if client.isTrusted():
                    context.outbound.close(remote)
                    var data_to_send = ""
                    prepairTrustedSend(remote.id, data_to_send)
                    await client.send(data_to_send)
                else:
                    remote.close()
                    client.close()
                break


            if client.isTrusted:
                try:
                    prepairTrustedSend(remote.id, data)
                    await client.send(data)
                    if globals.log_data_len: echo &"[proccessRemote] {data.len()} bytes -> Trusted client {remote.id}"

                except: continue
            else:
                if client.isClosed():
                    remote.close()
                    break
                await client.send(data)
                if globals.log_data_len: echo &"[proccessRemote] Sent {data.len()} bytes -> UnTrusted client"


    var untrusted_remote: Connection

    try:
        untrusted_remote = await remoteUnTrusted()
        asyncCheck proccessRemote(untrusted_remote)
    except:
        echo &"Warning! proccessRemote root level exception ?!"
        untrusted_remote.close()
        return



    proc proccessClient() {.async.} =
        while not client.isClosed:

            var data = ""
            try:
                data = await client.recv(globals.chunk_size+8)
                if globals.log_data_len: echo &"[proccessClient] {data.len()} bytes from client"

            except:
                continue

            if data == "":
                if client.isTrusted():
                    if globals.log_conn_destory: echo &"[proccessClient] closed inbound connection"
                    context.inbound.close(client)
                else:
                    if globals.log_conn_destory: echo &"[proccessClient] closed inbound & outbound connection"
                    untrusted_remote.close()
                    client.close()
                break

            if client.trusted == TrustStatus.pending:
                let trust = monitorData(data)
                if trust:
                    client.trusted = TrustStatus.yes
                    client.socket.setBuffered()
                    context.inbound.register(client)

                    print "Fake Handshake Complete !"
                    untrusted_remote.close()
                    # remote = await remoteTrusted(0)
                    # remote.id = 0
                    # context.outbound.register remote
                    # asyncCheck proccessRemote(remote)

                    continue
                elif (epochTime().uint - client.creation_time) > globals.trust_time:
                    echo "[proccessClient] non-client connection detected !  forwarding to real website."
                    client.trusted = TrustStatus.no





            try:
                if client.isTrusted():
                    
                    var (cid, pack) = muxRead(data)
                    if pack == "":
                        if context.outbound.connections.hasKey(cid):
                            context.outbound.close(context.outbound.connections[cid])
                            if globals.log_data_len: echo &"[proccessClient] closed outbound {cid}"
                        continue
                    if cid == 0:
                        if globals.log_data_len: echo "[proccessClient][Error] cid was 0"
                        # quit()
                        continue
                    if not context.outbound.connections.hasKey(cid):
                        var new_remote = await remoteTrusted(cid)
                        asyncCheck proccessRemote(new_remote)

                    await context.outbound.connections[cid].send(pack)
                    if globals.log_data_len: echo &"[proccessClient] {pack.len()} bytes -> Trusted remote {cid}"

                else:
                    if untrusted_remote.isClosed:
                        client.close()
                        break
                    await untrusted_remote.send(data)
                    if globals.log_data_len: echo &"[proccessClient] {data.len()}bytes -> UnTrusted remote"

            except:
                printEx()
                continue




    try:
        asyncCheck proccessClient()
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
