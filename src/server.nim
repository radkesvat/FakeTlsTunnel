import std/[tables, parseutils, asyncdispatch, strformat, net, random,bitops]
import overrides/[asyncnet]
import times, print
from globals import nil


type
    Connections = object
        connections: Table[uint32, AsyncSocket]

    ServerConnectionPoolContext = object
        listener: AsyncSocket
        # inbound: Connections
        # outbound: Connections

var context = ServerConnectionPoolContext()

    

proc monitorData(data:string) : bool =
    try:
        if len(data) < 8:return false
        var sh1_c:uint32
        var sh2_c:uint32
        
        copyMem(unsafeAddr sh1_c, unsafeAddr data[0], 4)
        copyMem(unsafeAddr sh2_c, unsafeAddr data[4], 4)
        
        let chk1 = sh1_c == globals.sh1
        let chk2 = sh2_c == globals.sh2

        # echo "parse Uint: " &  $sh1_c  & " == " & $globals.sh1
        # echo "parse Uint: " &  $sh2_c  & " == " & $globals.sh2
        # print sh1_c ,  globals.sh1
        # print sh2_c ,  globals.sh2

        return chk1 and chk2
    except:
        return false



proc processConnection(client_addr: string, client: AsyncSocket) {.async.} =
    var remote: AsyncSocket

    proc remoteHasData() {.async.} 

    proc remoteTrusted(){.async.} =
        remote = newAsyncSocket(buffered = globals.socket_buffered)
        remote.setSockOpt(OptNoDelay, true)
        remote.trusted = TrustStatus.yes
        await remote.connect(globals.next_route_addr, globals.next_route_port.Port)
        if globals.log_conn_create: echo  "connected to ",globals.next_route_addr,":", $globals.next_route_port
        
    proc remoteUnTrusted(){.async.} =
        remote = newAsyncSocket(buffered = globals.socket_buffered)
        remote.setSockOpt(OptNoDelay, true)
        remote.trusted = TrustStatus.no
        await remote.connect(globals.final_target_ip, globals.final_target_port.Port)
        if globals.log_conn_create: echo  "connected to ",globals.final_target_ip,":", $globals.final_target_port



    try:
        await remoteUnTrusted()

    except :
        client.close()
        remote.close()
        return
    

    proc clientHasData() {.async.} =
        while not client.isClosed :

            var data = ""
            try:
                data = await client.recv(1400)
                if globals.log_data_len: echo &"{data.len()} bytes from client"

                
                if(client.trusted == TrustStatus.yes):
                    for i in 0..<data.len():
                        data[i] = chr(rotateRightBits(uint8(data[i]),4))
            except:
                continue


            if client.trusted == TrustStatus.pending:
                if monitorData(data):
                    client.trusted = TrustStatus.yes
                    print "Fake Handshake Complete !"
                    remote.close()
                    await remoteTrusted()
                    asyncCheck remoteHasData()
                    continue
                elif (epochTime().uint - client.creation_time) > globals.trust_time :
                    # echo "dislike client scoket"
                    client.trusted = TrustStatus.no

        
            if data == "":
                if globals.log_conn_destory: echo &"closed client  <-> remote"
                
                client.close()
                remote.close()
                break




            if not remote.isClosed: 
                try:
                    await remote.send(data)
                except:continue
                if globals.log_data_len: echo &"{data.len()}bytes -> remote"
       
                
                
    proc remoteHasData() {.async.} =
        while not remote.isClosed:
            var data = ""
            try:
                data = await remote.recv(1400)
                if globals.log_data_len: echo &"{data.len()}bytes from remote"
            except:
                continue


            
            if data == "" :
                if globals.log_conn_destory: echo &"closed client <-> remote"
                remote.close()
                client.close()
                break
            if(client.trusted == TrustStatus.yes):
                for i in 0..<data.len():
                    data[i] = rotateRightBits(uint8(data[i]),4).chr
            if not client.isClosed():
                
                try:
                    await client.send(data)
                except:continue

                if globals.log_data_len: echo &"Sent {data.len()} bytes -> client"

    try:
        asyncCheck clientHasData()
        asyncCheck remoteHasData()
    except:
        echo "[Server] root level exception"
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
            client.trusted = TrustStatus.pending
            asyncCheck processConnection(address, client)

   
    echo &"Mode Server:   {globals.listen_addr} <-> ({globals.final_target_domain} with ip {globals.final_target_ip})"
    asyncCheck start_server()
